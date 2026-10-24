///|
/// Private infrastructure package; no default capacity and no public facade.
/// Cancellation remains an independent async control channel.
pub(all) enum TempFailure {
  Budget(@budget.BudgetError)
  Io(stage~ : String, message~ : String)
  State(String)
} derive(Eq)

///|
pub extend TempFailure with Eq::{equal, not_equal}

///|
/// An opaque range of one sealed owner, using half-open physical byte offsets.
/// No path or borrowed SDK handle is returned to a consumer.
pub struct TempRange {
  priv identity : Ref[Bool]
  priv start : Int64
  length : Int64
}

///|
pub struct TempOwner {
  priv state : TempState
}

///|
priv struct TempState {
  identity : Ref[Bool]
  mutex : @async.Mutex
  account : @budget.Budget
  capacity : Int64
  directory : String
  path : String
  mut handle : @fs.File?
  mut committed : Int64
  mut reserved : Int64
  mut is_sealed : Bool
  mut closing : Bool
  mut closed : Bool
  mut sdk_close_completed : Bool
  // True also covers a file name whose ownership was never acquired.
  mut file_removed : Bool
  mut directory_removed : Bool
  mut first_failure : TempFailure?
  cleanup_failures : Array[TempFailure]
  leases : Array[@budget.BudgetLease]
  report : (TempFailure) -> Unit
  ops : TempOps
}

///|
/// Kept private: whitebox failure injection never changes the production API.
/// No File, descriptor or callback is exposed outside this package.
priv struct TempOps {
  directory : async () -> String
  open : async (String) -> @fs.File
  read : async (@fs.File, FixedArray[Byte], Int32, Int32, Int64) -> Int32
  write : async (@fs.File, BytesView) -> Int32
  close : (@fs.File) -> Unit
  remove : async (String) -> Unit
  rmdir : async (String) -> Unit
}

///|
fn native_ops() -> TempOps {
  {
    directory: async fn() { @fs.tmpdir(prefix="markitdown-input") },
    open: async fn(path) {
      @fs.open(path, mode=ReadWrite, create_mode=CreateNew, permission=0o600)
    },
    read: async fn(handle, buffer, offset, length, position) {
      handle.read_at(buffer, offset~, len=length, position~)
    },
    write: async fn(handle, bytes) {
      // SDK write_at discards pwrite's positive short count. write_once keeps
      // the actual count and advances the exclusive File's write offset.
      handle.write_once(
        bytes.data(),
        offset=bytes.start_offset(),
        len=bytes.length(),
      )
    },
    close: fn(handle) { handle.close() },
    remove: async fn(path) { @fs.remove(path) },
    rmdir: async fn(path) { @fs.rmdir(path) },
  }
}

///|
fn latch(state : TempState, error : TempFailure) -> TempFailure {
  match state.first_failure {
    Some(first) => first
    None => {
      let first = match state.account.failure() {
        Some(budget_error) => Budget(budget_error)
        None => error
      }
      state.first_failure = Some(first)
      (state.report)(first)
      first
    }
  }
}

///|
fn health(state : TempState) -> TempFailure? {
  match state.first_failure {
    Some(error) => Some(error)
    None =>
      match state.account.reserve(TemporaryBytes, 0L) {
        Err(error) => Some(latch(state, Budget(error)))
        Ok(_) if state.closing || state.closed =>
          Some(State("temporary store is closed"))
        Ok(_) => None
      }
  }
}

///|
pub fn TempOwner::failure(self : TempOwner) -> TempFailure? {
  match self.state.first_failure {
    Some(error) => Some(error)
    None => self.state.account.failure().map(error => Budget(error))
  }
}

///|
pub fn TempOwner::length(self : TempOwner) -> Int64 {
  self.state.committed
}
