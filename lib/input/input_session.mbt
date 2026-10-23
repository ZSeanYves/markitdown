///|
priv struct InputSessionState {
  cursors : Map[String, SourceCursor]
  closed : Ref[Bool]
  max_bytes : Int64
  failure : Ref[InputFailure?]
  open_mutex : @async.Mutex
  account : @budget.Budget
  retained_leases : Array[@budget.BudgetLease]
}

///|
/// One conversion's owned Path handles. Nested conversion helpers borrow the
/// existing session; only its outer owner releases those handles.
pub struct InputSession {
  source : InputSource
  priv owner : Bool
}

///|
pub(all) enum ResourceLimitKind {
  SingleAssetBytes
  TotalAssetBytes
} derive(Eq)

///|
pub extend ResourceLimitKind with Eq::{equal, not_equal}

///|
pub struct ResourceLimitFailure {
  kind : ResourceLimitKind
  observed : Int64
  limit : Int64
}

///|
pub fn make_resource_limit_failure(
  kind : ResourceLimitKind,
  observed : Int64,
  limit : Int64,
) -> ResourceLimitFailure {
  { kind, observed, limit, }
}

///|
pub(all) enum InputFailure {
  InputError(String)
  ResourceLimit(ResourceLimitFailure)
  BudgetFailure(@budget.BudgetError)
}

///|
fn input_failure_message(failure : InputFailure) -> String {
  match failure {
    InputError(message) => message
    BudgetFailure(error) => @budget.budget_error_message(error)
    ResourceLimit(failure) => {
      let kind = match failure.kind {
        SingleAssetBytes => "single_asset_bytes"
        TotalAssetBytes => "total_asset_bytes"
      }
      "resource limit exceeded: " +
      kind +
      "; observed=" +
      failure.observed.to_string() +
      "; limit=" +
      failure.limit.to_string()
    }
  }
}

///|
pub fn begin_input_session(
  source : InputSource,
  max_bytes? : Int64,
  budget? : @budget.Budget,
) -> InputSession {
  let max_bytes = effective_input_byte_limit(source, max_bytes)
  let bounded = {
    ..input_source_with_reader_limit(source, max_bytes),
    byte_limit: Some(max_bytes),
  }
  match source.session {
    Some(state) => {
      if state.closed.val {
        record_input_failure(source, "input session is closed")
      }
      if budget is Some(_) {
        record_input_failure(
          source, "nested input session cannot replace its conversion budget",
        )
      }
      { source: bounded, owner: false, }
    }
    None =>
      {
        source: {
          ..bounded,
          session: Some({
            cursors: Map([]),
            closed: Ref(false),
            max_bytes,
            failure: Ref(None),
            open_mutex: @async.Mutex(),
            account: match budget {
              Some(account) => account
              None =>
                @budget.Budget::new(@budget.BudgetLimits::measurement_only())
            },
            retained_leases: [],
          }),
        },
        owner: true,
      }
  }
}

///|
/// Input failures cannot be cleared by a format's recoverable syntax fallback.
pub fn input_session_error(session : InputSession) -> String? {
  input_source_error(session.source)
}

///|
/// Inspect a hard input failure before attempting a recoverable syntax or
/// encoding fallback. The original callback error text remains intact.
pub fn input_source_error(source : InputSource) -> String? {
  input_source_failure(source).map(input_failure_message)
}

///|
pub fn input_source_failure(source : InputSource) -> InputFailure? {
  source.session.bind(fn(state) {
    match state.failure.val {
      Some(first) => Some(first)
      None => state.account.failure().map(error => BudgetFailure(error))
    }
  })
}

///|
/// Record errors where their concrete type is still known, before optional
/// syntax recovery can convert them to an empty value or a diagnostic.
pub fn record_input_failure(source : InputSource, message : String) -> Unit {
  match source.session.bind(state => state.account.failure()) {
    Some(error) => record_source_failure(source, BudgetFailure(error))
    None => record_source_failure(source, InputError(message))
  }
}

///|
pub fn record_input_budget_failure(
  source : InputSource,
  error : @budget.BudgetError,
) -> Unit {
  record_source_failure(source, BudgetFailure(error))
}

///|
pub fn input_source_budget_context(
  source : InputSource,
) -> @budget.BudgetContext? {
  source.session.map(fn(state) {
    @budget.BudgetContext::new(state.account, fn(kind, bytes) {
      match state.account.reserve(kind, bytes) {
        Ok(lease) => {
          if bytes > 0L {
            state.retained_leases.push(lease)
          }
          Ok(())
        }
        Err(error) => {
          record_input_budget_failure(source, error)
          Err(error)
        }
      }
    })
  })
}

///|
/// A child retains its own representation and raw-byte ceiling. Only shared
/// ownership/failure/budget state comes from its parent.
pub fn input_source_inherit_session(
  child : InputSource,
  parent : InputSource,
) -> InputSource {
  match parent.session {
    None => child
    Some(parent_state) =>
      match child.session {
        None => { ..child, session: parent.session, }
        Some(child_state) if physical_equal(
            child_state.closed,
            parent_state.closed,
          ) => child
        Some(child_state) => {
          match input_source_failure(child) {
            Some(failure) => record_source_failure(parent, failure)
            None =>
              record_input_failure(
                parent,
                if child_state.closed.val {
                  "cannot inherit a closed child input session"
                } else {
                  "cannot replace an existing child input session"
                },
              )
          }
          record_input_failure(
            child,
            if child_state.closed.val {
              "cannot inherit a closed child input session"
            } else {
              "cannot replace an existing child input session"
            },
          )
          child
        }
      }
  }
}

///|
pub fn record_input_resource_failure(
  source : InputSource,
  failure : ResourceLimitFailure,
) -> Unit {
  record_source_failure(source, ResourceLimit(failure))
}

///|
fn record_source_failure(source : InputSource, failure : InputFailure) -> Unit {
  match source.session {
    Some(state) if state.failure.val is None =>
      state.failure.val = Some(
        match state.account.failure() {
          Some(error) => BudgetFailure(error)
          None => failure
        },
      )
    _ => ()
  }
}

///|
/// Logical bytes returned by a read or zero-copy view, including repeats.
/// This is independent from the original physical input extent.
fn charge_source_read_traffic(
  source : InputSource,
  bytes : Int64,
) -> Result[Unit, String] {
  match source.session {
    Some(state) =>
      match state.account.charge(ReadTrafficBytes, bytes) {
        Ok(_) => Ok(())
        Err(error) => {
          record_input_budget_failure(source, error)
          Err(@budget.budget_error_message(error))
        }
      }
    None => Ok(())
  }
}

///|
fn[T] record_input_result(
  source : InputSource,
  result : Result[T, String],
) -> Result[T, String] {
  match result {
    Err(message) => record_input_failure(source, message)
    Ok(_) => ()
  }
  result
}

///|
/// Idempotent synchronous cleanup, also safe in async cancellation defers.
pub fn end_input_session(session : InputSession) -> Unit {
  if !session.owner {
    return
  }
  match session.source.session {
    Some(state) if !state.closed.val => {
      state.closed.val = true
      for _, cursor in state.cursors {
        source_cursor_close(cursor)
      }
      state.cursors.clear()
      for lease in state.retained_leases {
        lease.release()
      }
      state.retained_leases.clear()
      match state.account.close() {
        Ok(_) => ()
        Err(error) => record_input_budget_failure(session.source, error)
      }
    }
    _ => ()
  }
}

///|
fn close_cursor_if_unowned(source : InputSource, cursor : SourceCursor) -> Unit {
  if source.session is None {
    source_cursor_close(cursor)
  }
}
