///|
fn registry_fixture_parser(name : String, mode : ParserMode) -> Parser {
  make_parser(name, mode, parser_capability(false, false, true), fn(_, _) {
    Ok(
      parse_result_with_document(
        name,
        mode,
        @core.empty_document_ir(),
        @core.empty_diagnostics(),
      ),
    )
  })
}

///|
async test "parser registry preserves default and selects newest mode override" {
  let registry = empty_registry()
  registry_register(
    registry,
    Txt,
    registry_fixture_parser("default", DomAstModel),
  )
  registry_register(
    registry,
    Txt,
    registry_fixture_parser("stream-old", BlockStreaming),
  )
  registry_register(
    registry,
    Txt,
    registry_fixture_parser("stream-new", BlockStreaming),
  )
  assert_eq(registry_lookup(registry, Txt).unwrap().name, "default")
  assert_true(registry_lookup(registry, Pdf) is None)
  let source = @input.input_from_text("fixture")
  assert_eq(
    registry_parse(registry, source, new_parse_context(Txt)).unwrap().parser_name,
    "default",
  )
  let context = {
    ..new_parse_context(Txt),
    requested_mode: Some(BlockStreaming),
  }
  assert_eq(
    registry_parse(registry, source, context).unwrap().parser_name,
    "stream-new",
  )
  assert_eq(
    registry_parse(registry, source, {
      ..context,
      requested_mode: Some(StreamingEvent),
    }).unwrap().parser_name,
    "default",
  )
}

///|
async test "parser registry reports missing formats and absent pull contracts" {
  let registry = empty_registry()
  let source = @input.input_from_text("fixture")
  let context = new_parse_context(Json)
  assert_true(
    registry_parse(registry, source, context)
    is Err("no parser registered for format: json"),
  )
  assert_true(
    registry_open_event_stream(registry, source, context)
    is Err("no parser registered for format: json"),
  )
  registry_register(
    registry,
    Json,
    registry_fixture_parser("buffered", DomAstModel),
  )
  assert_true(
    registry_open_event_stream(registry, source, context).unwrap() is None,
  )
  assert_eq(registry_key(Markdown), "markdown")
}

///|
async test "parser dispatch waits for an asynchronous implementation" {
  let sequence : Array[String] = []
  let registry = empty_registry()
  registry_register(
    registry,
    Txt,
    make_parser("suspending", DomAstModel, default_parser_capability(), async fn(
      _,
      _,
    ) {
      sequence.push("start")
      @async.sleep(1)
      sequence.push("complete")
      Ok(
        parse_result_with_document(
          "suspending",
          DomAstModel,
          @core.empty_document_ir(),
          @core.empty_diagnostics(),
        ),
      )
    }),
  )
  let result = registry_parse(
    registry,
    @input.input_from_text("fixture"),
    new_parse_context(Txt),
  ).unwrap()
  assert_eq(result.parser_name, "suspending")
  assert_eq(sequence, ["start", "complete"])
}

///|
async test "parser pull open next and finish share the async protocol" {
  let sequence : Array[String] = []
  let registry = empty_registry()
  let remaining = Ref(true)
  registry_register(
    registry,
    Txt,
    make_parser(
      "pull",
      StreamingEvent,
      default_parser_capability(),
      fn(_, _) { Err("buffered parse must not run") },
      open_stream=Some(async fn(_, _) {
        @async.sleep(1)
        sequence.push("open")
        Ok(
          Some(
            make_parse_event_stream(
              async fn() {
                @async.sleep(1)
                if remaining.val {
                  remaining.val = false
                  sequence.push("event")
                  Ok(
                    Some({
                      kind: @core.EventKind::TextLine,
                      text: "body",
                      source_ref: None,
                    }),
                  )
                } else {
                  sequence.push("eof")
                  Ok(None)
                }
              },
              async fn() {
                @async.sleep(1)
                sequence.push("finish")
                Ok(
                  parse_stream_summary(
                    "pull",
                    StreamingEvent,
                    default_parser_capability(),
                    @core.empty_diagnostics(),
                  ),
                )
              },
            ),
          ),
        )
      }),
    ),
  )
  let stream = registry_open_event_stream(
      registry,
      @input.input_from_text("fixture"),
      new_parse_context(Txt),
    )
    .unwrap()
    .unwrap()
  assert_eq(sequence, ["open"])
  assert_eq((stream.next)().unwrap().unwrap().text, "body")
  assert_true((stream.next)().unwrap() is None)
  assert_eq((stream.finish)().unwrap().parser_name, "pull")
  assert_eq(sequence, ["open", "event", "eof", "finish"])
}

///|
async test "registry preserves asynchronous parse and stream errors" {
  let registry = empty_registry()
  registry_register(
    registry,
    Txt,
    make_parser(
      "failure",
      StreamingEvent,
      default_parser_capability(),
      async fn(_, _) {
        @async.sleep(1)
        Err("parse failure")
      },
      open_stream=Some(async fn(_, _) {
        @async.sleep(1)
        Err("open failure")
      }),
    ),
  )
  let source = @input.input_from_text("fixture")
  let context = new_parse_context(Txt)
  assert_true(registry_parse(registry, source, context) is Err("parse failure"))
  assert_true(
    registry_open_event_stream(registry, source, context) is Err("open failure"),
  )
  let stream = make_parse_event_stream(
    async fn() {
      @async.sleep(1)
      Err("next failure")
    },
    async fn() {
      @async.sleep(1)
      Err("finish failure")
    },
  )
  assert_true((stream.next)() is Err("next failure"))
  assert_true((stream.finish)() is Err("finish failure"))
}

///|
async test "registry cancellation crosses the single async parser boundary" {
  let completed = Ref(false)
  let registry = empty_registry()
  registry_register(
    registry,
    Txt,
    make_parser("cancel", DomAstModel, default_parser_capability(), async fn(
      _,
      _,
    ) {
      @async.sleep(1000)
      completed.val = true
      Ok(
        parse_result_with_document(
          "cancel",
          DomAstModel,
          @core.empty_document_ir(),
          @core.empty_diagnostics(),
        ),
      )
    }),
  )
  let outcome = @async.with_timeout_opt(5, async fn() {
    registry_parse(
      registry,
      @input.input_from_text("fixture"),
      new_parse_context(Txt),
    )
  })
  assert_true(outcome is None)
  assert_true(!completed.val)
}
