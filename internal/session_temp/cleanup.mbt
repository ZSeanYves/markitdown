///|
fn cleanup_error(state : TempState, stage : String, message : String) -> Unit {
  let error = Io(stage~, message~)
  state.cleanup_failures.push(error)
  ignore(latch(state, error))
}

///|
/// Invoke the SDK's standard close exactly once, after all IO borrowers left
/// the same mutex. SDK close invalidates its aliases but hides kernel errors;
/// completion here makes no stronger native-close observability claim.
fn take_and_close(state : TempState) -> Unit {
  match state.handle {
    None => ()
    Some(handle) => {
      state.handle = None
      (state.ops.close)(handle)
      state.sdk_close_completed = true
    }
  }
}

///|
/// Whether SDK close returned and both owned names were confirmed removed.
/// This is cleanup completion, not conversion success: close/failure still
/// preserve an earlier operation error after all resources have been cleaned.
/// The SDK does not expose kernel close errors, so this adds no such claim.
/// Cleanup callbacks can report that original error once and retire only when
/// this status is true; an incomplete deletion remains eligible for retry.
pub fn TempOwner::cleanup_complete(self : TempOwner) -> Bool {
  let state = self.state
  state.sdk_close_completed && state.file_removed && state.directory_removed
}

///|
/// Mandatory before final successful conversion/Sink.finish, with the same
/// call in an async defer for failures/cancellation. Idempotent; close is never
/// repeated on a borrowed File descriptor whose number the OS may have reused.
pub async fn TempOwner::close(
  self : TempOwner,
) -> Result[Unit, TempFailure] noraise + nocancel {
  let state = self.state
  @async.protect_from_cancel(async fn() {
    state.mutex.acquire()
    defer state.mutex.release()
    if state.closed {
      return match state.first_failure {
        Some(error) => Err(error)
        None => Ok(())
      }
    }
    if state.first_failure is None && state.account.failure() is Some(error) {
      ignore(latch(state, Budget(error)))
    }
    state.closing = true
    state.identity.val = true
    take_and_close(state)
    // Named deletion errors are observable and must never become success.
    if !state.file_removed {
      try (state.ops.remove)(state.path) catch {
        @os_error.OSError(_) as error if error.is_ENOENT() =>
          state.file_removed = true
        error => cleanup_error(state, "remove", error.to_string())
      } noraise {
        _ => state.file_removed = true
      }
    }
    if state.file_removed && !state.directory_removed {
      try (state.ops.rmdir)(state.directory) catch {
        @os_error.OSError(_) as error if error.is_ENOENT() =>
          state.directory_removed = true
        error => cleanup_error(state, "rmdir", error.to_string())
      } noraise {
        _ => state.directory_removed = true
      }
    }
    if state.sdk_close_completed && state.file_removed {
      for lease in state.leases {
        lease.release()
      }
      state.leases.clear()
      state.reserved = 0L
    }
    // A failed remove/rmdir remains retryable, without regaining a File alias
    // or pretending the SDK's hidden close error became observable.
    state.closed = state.file_removed && state.directory_removed
    match state.first_failure {
      Some(error) => Err(error)
      None => Ok(())
    }
  }) catch {
    error => {
      cleanup_error(state, "cleanup", error.to_string())
      Err(state.first_failure.unwrap())
    }
  }
}
