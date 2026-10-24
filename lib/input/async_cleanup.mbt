///|
/// Cleanup ownership is independent of Path/account ownership: a library
/// conversion may borrow a CLI's synchronous InputSession yet be the first
/// async boundary capable of draining temporary resources before success.
pub struct InputCleanupScope {
  priv source : InputSource
  priv state : InputCleanupState
  priv owner : Bool
}

///|
priv struct InputCleanupState {
  mutex : @async.Mutex
  mut callbacks : Array[async () -> Result[Unit, InputFailure]]
  mut draining : Bool
  mut drained : Bool
  mut failed : Bool
}

///|
fn new_cleanup_state(drained : Bool) -> InputCleanupState {
  { mutex: Mutex(), callbacks: [], draining: false, drained, failed: false, }
}

///|
/// Install an async cleanup capability. Immediately defer cleanup_input_scope
/// before the next await; keep end_input_session in an earlier (later-running)
/// defer. Existing active scopes are borrowed and never prematurely drained.
pub fn begin_input_cleanup_scope(session : InputSession) -> InputCleanupScope {
  let source = session.source
  let state = source.session.unwrap()
  if state.closed.val {
    // A failed named deletion may be retried after ordinary Path/account
    // shutdown. This capability is cleanup-only; registration still rejects
    // a closed/failed source and leases remain releasable after Budget.close.
    if state.cleanup.val is Some(cleanup) && !cleanup.drained {
      return { source, state: cleanup, owner: true, }
    }
    record_input_failure(source, "input session is closed")
    return { source, state: new_cleanup_state(true), owner: false, }
  }
  match state.cleanup.val {
    Some(cleanup) if !cleanup.drained => {
      if cleanup.draining {
        record_input_failure(source, "input asynchronous cleanup is draining")
      }
      { source, state: cleanup, owner: cleanup.failed, }
    }
    _ => {
      let cleanup = new_cleanup_state(false)
      state.cleanup.val = Some(cleanup)
      { source, state: cleanup, owner: true, }
    }
  }
}

///|
/// Register only after the creator has an async cleanup guard. Callback Err
/// means cleanup is still incomplete and must remain retryable; operation
/// errors must already be reported to the session at their original phase.
/// Callbacks must not recursively drain their own scope.
pub fn register_input_temporary_cleanup(
  source : InputSource,
  cleanup : async () -> Result[Unit, InputFailure],
) -> Result[Unit, InputFailure] {
  if input_source_failure(source) is Some(error) {
    return Err(error)
  }
  guard source.session is Some(state) else {
    return Err(InputError("temporary cleanup requires an input session"))
  }
  let error = if state.closed.val {
    Some(InputError("input session is closed"))
  } else {
    match state.account.reserve(TemporaryBytes, 0L) {
      Err(error) => Some(BudgetFailure(error))
      Ok(_) => None
    }
  }
  if error is Some(error) {
    record_source_failure(source, error)
    return Err(input_source_failure(source).unwrap())
  }
  match state.cleanup.val {
    Some(scope) if !scope.draining && !scope.drained => {
      scope.callbacks.push(cleanup)
      Ok(())
    }
    _ => {
      let error = InputError(
        "temporary cleanup requires an active async cleanup scope",
      )
      record_source_failure(source, error)
      Err(input_source_failure(source).unwrap())
    }
  }
}

///|
fn cleanup_scope_result(source : InputSource) -> Result[Unit, InputFailure] {
  match input_source_failure(source) {
    Some(error) => Err(error)
    None => Ok(())
  }
}

///|
/// Drain under cancellation protection, serializing concurrent callers. All
/// callbacks are attempted despite an earlier error. Completed callbacks are
/// retired, failed callbacks retained for a later best-effort cleanup retry.
/// An earlier hard input/budget error still wins even when cleanup succeeds.
pub async fn cleanup_input_scope(
  scope : InputCleanupScope,
) -> Result[Unit, InputFailure] noraise + nocancel {
  if !scope.owner {
    return cleanup_scope_result(scope.source)
  }
  let state = scope.state
  @async.protect_from_cancel(async fn() {
    state.mutex.acquire()
    defer state.mutex.release()
    if !state.drained {
      state.draining = true
      defer {
        state.draining = false
      }
      let pending = state.callbacks
      state.callbacks = []
      for callback in pending {
        let result = callback() catch {
          error =>
            Err(InputError("temporary cleanup failed: " + error.to_string()))
        }
        match result {
          Ok(_) => ()
          Err(error) => {
            record_source_failure(scope.source, error)
            state.callbacks.push(callback)
          }
        }
      }
      state.drained = state.callbacks.is_empty()
      state.failed = !state.drained
    }
    cleanup_scope_result(scope.source)
  }) catch {
    error => {
      record_input_failure(
        scope.source,
        "temporary cleanup failed: " + error.to_string(),
      )
      cleanup_scope_result(scope.source)
    }
  }
}
