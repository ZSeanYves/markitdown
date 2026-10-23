// Vendored from moonbit-community/flate@0.8.5, revision
// 3cbcb5c8bde0b34117fd7980b9f41719f2b8f3d7. Apache-2.0.
// See LICENSE, NOTICE and UPSTREAM.md for exact source hashes and local changes.

///|
/// Outcome of one step of the streaming DEFLATE state machine.
///
/// The engine is runtime-agnostic: it moves bytes between an input view and an
/// output buffer and *suspends* by returning one of these, so any driver — a
/// synchronous loop or an async adapter — can resume it.
pub(all) enum Status {
  /// End of the DEFLATE stream was reached; the operation is complete.
  Done
  /// Input was exhausted mid-stream; supply more bytes and call again.
  NeedMoreInput
  /// The output buffer filled up; drain it and call again.
  NeedMoreOutput
} derive(Eq, Debug)

///|
pub extend Status with Eq::{not_equal, equal}

///|
pub extend Status with Debug::{to_repr}
