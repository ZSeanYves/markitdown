///|
/// Allocate an exclusive named 0600 regular file in the SDK's new 0700
/// directory. The short construction/rollback phase is cancellation-shielded.
/// The returned owner must be put in an async close defer before the next await.
/// No full-input buffer or path-reopen adapter is created here.
pub async fn TempOwner::create(
  account : @budget.Budget,
  capacity~ : Int64,
  report_failure~ : (TempFailure) -> Unit = fn(_) {  },
) -> Result[TempOwner, TempFailure] noraise {
  create_with_ops(account, capacity~, report_failure~, ops=native_ops())
}

///|
async fn create_with_ops(
  account : @budget.Budget,
  capacity~ : Int64,
  report_failure~ : (TempFailure) -> Unit,
  ops~ : TempOps,
) -> Result[TempOwner, TempFailure] noraise {
  // A failed/closed shared account has priority even over a local invalid cap.
  match account.reserve(TemporaryBytes, 0L) {
    Err(error) => {
      let failure = Budget(error)
      report_failure(failure)
      return Err(failure)
    }
    Ok(_) => ()
  }
  if capacity < 0L {
    let failure = Budget(InvalidLimit(Resident(TemporaryBytes), capacity))
    report_failure(failure)
    return Err(failure)
  }
  @async.protect_from_cancel(async fn() {
    let directory = (ops.directory)() catch {
      error => {
        let failure = Io(stage="create directory", message=error.to_string())
        report_failure(failure)
        return Err(failure)
      }
    }
    let state : TempState = {
      identity: Ref(false),
      mutex: Mutex(),
      account,
      capacity,
      directory,
      path: directory + "/payload",
      handle: None,
      committed: 0L,
      reserved: 0L,
      is_sealed: false,
      closing: false,
      closed: false,
      sdk_close_completed: true,
      file_removed: true,
      directory_removed: false,
      first_failure: None,
      cleanup_failures: [],
      leases: [],
      report: report_failure,
      ops,
    }
    let owner = { state, }
    let published = Ref(false)
    defer (if !published.val { ignore(owner.close()) })
    let handle = (ops.open)(state.path) catch {
      error => {
        // No returned File means there is no creation/identity proof. Never
        // unlink this name on a guessed errno, even inside our private dir.
        ignore(
          latch(
            state,
            Io(
              stage="create file",
              message=state.path + ": " + error.to_string(),
            ),
          ),
        )
        return Err(state.first_failure.unwrap())
      }
    }
    state.handle = Some(handle)
    state.sdk_close_completed = false
    state.file_removed = false
    if !(handle.kind() is Regular) {
      ignore(latch(state, State("temporary store is not a regular file")))
      return Err(state.first_failure.unwrap())
    }
    if health(state) is Some(error) {
      return Err(error)
    }
    published.val = true
    Ok(owner)
  }) catch {
    error => {
      let failure = Io(
        stage="construct temporary store",
        message=error.to_string(),
      )
      report_failure(failure)
      Err(failure)
    }
  }
}

///|
/// Seal only after all prior appends completed. Reads do not replay raw source.
pub async fn TempOwner::seal(
  self : TempOwner,
) -> Result[Unit, TempFailure] noraise {
  let state = self.state
  state.mutex.acquire()
  defer state.mutex.release()
  if health(state) is Some(error) {
    return Err(error)
  }
  state.is_sealed = true
  Ok(())
}

///|
/// Select a validated range only from a sealed, fully committed owner.
pub fn TempOwner::range(
  self : TempOwner,
  start : Int64,
  length : Int64,
) -> Result[TempRange, TempFailure] {
  let state = self.state
  if health(state) is Some(error) {
    return Err(error)
  }
  if !state.is_sealed {
    return Err(State("temporary store is not sealed"))
  }
  if start < 0L ||
    length < 0L ||
    start > state.committed ||
    length > state.committed - start {
    return Err(State("temporary range is outside committed storage"))
  }
  Ok({ identity: state.identity, start, length, })
}
