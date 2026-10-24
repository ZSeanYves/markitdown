///|
priv struct ParserStreamOwner {
  source : @input.InputSource
  session : @input.InputSession
  cleanup : @input.InputCleanupScope
  stream : ParseEventStream
  mutex : @async.Mutex
  mut closed : Bool
  mut inner_closed : Bool
  mut eof : Bool
  mut failure : String?
}

///|
fn stream_failure(state : ParserStreamOwner, message : String) -> String {
  match state.failure {
    Some(first) => first
    None => {
      let first = @input.input_source_error(state.source).unwrap_or(message)
      state.failure = Some(first)
      first
    }
  }
}

///|
/// Requires the stream mutex; no caller may close a handle under an awaiting
/// next/finish operation. Retrying cleanup never calls the inner close twice.
async fn close_parser_stream_locked(
  state : ParserStreamOwner,
) -> Result[Unit, String] noraise + nocancel {
  @async.protect_from_cancel(async fn() {
    state.closed = true
    if !state.inner_closed {
      state.inner_closed = true
      let result = (state.stream.close_stream)() catch {
        error => Err("parser stream close failed: " + error.to_string())
      }
      if result is Err(message) {
        @input.record_input_failure(state.source, message)
        ignore(stream_failure(state, message))
      }
    }
    ignore(@input.cleanup_input_scope(state.cleanup))
    if @input.input_source_error(state.source) is Some(message) {
      ignore(stream_failure(state, message))
    }
    @input.end_input_session(state.session)
    match state.failure {
      Some(message) => Err(message)
      None => Ok(())
    }
  }) catch {
    error => {
      let message = "parser stream cleanup failed: " + error.to_string()
      @input.record_input_failure(state.source, message)
      let message = stream_failure(state, message)
      @input.end_input_session(state.session)
      Err(message)
    }
  }
}

///|
async fn abort_parser_stream_locked(
  state : ParserStreamOwner,
) -> Unit noraise + nocancel {
  if state.failure is None {
    let message = "parser stream operation did not complete"
    @input.record_input_failure(state.source, message)
    ignore(stream_failure(state, message))
  }
  ignore(close_parser_stream_locked(state))
}

///|
async fn open_parser_stream_with_cleanup(
  open : async (@input.InputSource, ParseContext) -> Result[
    ParseEventStream?,
    String,
  ],
  source : @input.InputSource,
  context : ParseContext,
) -> Result[ParseEventStream?, String] {
  let source = match context.input_source {
    Some(parent) => @input.input_source_inherit_session(source, parent)
    None => source
  }
  let session = @input.begin_input_session(
    source,
    max_bytes=max_input_bytes(context),
  )
  let cleanup = @input.begin_input_cleanup_scope(session)
  let handed_off = Ref(false)
  defer (if !handed_off.val {
    ignore(@input.cleanup_input_scope(cleanup))
    @input.end_input_session(session)
  })
  let source = session.source
  let context = parse_context_with_input_source(context, source)
  if @input.input_source_error(source) is Some(message) {
    return Err(message)
  }
  let result = open(source, context)
  let stream = match result {
    Ok(Some(stream)) => stream
    other => {
      ignore(@input.cleanup_input_scope(cleanup))
      if @input.input_source_error(source) is Some(message) {
        return Err(message)
      }
      return other
    }
  }
  if @input.input_source_error(source) is Some(message) {
    ignore(stream.close())
    return Err(message)
  }
  let state : ParserStreamOwner = {
    source,
    session,
    cleanup,
    stream,
    mutex: Mutex(),
    closed: false,
    inner_closed: false,
    eof: false,
    failure: None,
  }
  handed_off.val = true
  Ok(
    Some({
      next: async fn() {
        state.mutex.acquire()
        defer state.mutex.release()
        let complete = Ref(false)
        defer (if !complete.val { abort_parser_stream_locked(state) })
        if state.closed {
          complete.val = true
          return Err(state.failure.unwrap_or("parser stream is closed"))
        }
        if @input.input_source_error(source) is Some(message) {
          let message = stream_failure(state, message)
          ignore(close_parser_stream_locked(state))
          complete.val = true
          return Err(message)
        }
        if state.eof {
          complete.val = true
          return Ok(None)
        }
        let result = (stream.next)()
        let result = match @input.input_source_error(source) {
          Some(message) => Err(message)
          None => result
        }
        match result {
          Err(message) => {
            let message = stream_failure(state, message)
            ignore(close_parser_stream_locked(state))
            complete.val = true
            Err(message)
          }
          Ok(event) => {
            if event is None {
              state.eof = true
            }
            complete.val = true
            Ok(event)
          }
        }
      },
      finish: async fn() {
        state.mutex.acquire()
        defer state.mutex.release()
        let complete = Ref(false)
        defer (if !complete.val { abort_parser_stream_locked(state) })
        if state.closed {
          complete.val = true
          return Err(state.failure.unwrap_or("parser stream is closed"))
        }
        if @input.input_source_error(source) is Some(message) {
          let message = stream_failure(state, message)
          ignore(close_parser_stream_locked(state))
          complete.val = true
          return Err(message)
        }
        let result = (stream.finish)()
        if result is Err(message) {
          ignore(stream_failure(state, message))
        }
        let closed = close_parser_stream_locked(state)
        complete.val = true
        match (result, closed) {
          (Err(message), _) => Err(state.failure.unwrap_or(message))
          (_, Err(message)) => Err(message)
          (Ok(summary), Ok(_)) => Ok(summary)
        }
      },
      close_stream: async fn() {
        @async.protect_from_cancel(async fn() {
          state.mutex.acquire()
          defer state.mutex.release()
          close_parser_stream_locked(state)
        })
      },
    }),
  )
}
