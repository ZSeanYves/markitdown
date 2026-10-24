///|
/// File and Atomic output share the existing missing-terminator rule. Stdout's
/// unconditional println contract intentionally remains a separate lifecycle.
fn cli_file_needs_lf(wrote_any : Bool, ends_with_lf : Bool) -> Bool {
  wrote_any && !ends_with_lf
}

///|
priv struct CliFileTail {
  source : @input.InputSource
  added_bytes : Int64
  confirmed : Ref[Bool]
  applied : Ref[Bool]
}

///|
fn admit_cli_file_tail(
  source : @input.InputSource,
  needed : Bool,
) -> Result[CliFileTail, CliFailure] {
  guard @input.input_source_budget_context(source) is Some(context) else {
    return Err(
      cli_failure(
        OutputFailure,
        "CLI file output requires its input session budget",
      ),
    )
  }
  if @input.input_source_failure(source) is Some(_) {
    return Err(cli_atomic_failure(source, "CLI file output source has failed"))
  }
  let added_bytes = if needed { 1L } else { 0L }
  match context.account.charge(OutputUtf8Bytes, added_bytes) {
    Ok(_) =>
      Ok({ source, added_bytes, confirmed: Ref(false), applied: Ref(false), })
    Err(error) => {
      let message = atomic_budget_error(source, error)
      Err(cli_atomic_failure(source, message))
    }
  }
}

///|
fn confirm_cli_file_tail(tail : CliFileTail) -> Unit {
  tail.confirmed.val = true
}

///|
/// Add only a transport LF actually accepted by the writer. Converter content,
/// metadata and body-size fields keep their original meanings. Refresh of
/// admitted/peak/current still comes from the original shared account.
fn apply_cli_file_tail(
  tail : CliFileTail,
  diagnostics : @core.Diagnostics,
) -> Result[Unit, CliFailure] {
  if tail.applied.val || !tail.confirmed.val {
    return Ok(())
  }
  if tail.added_bytes > 0L {
    guard diagnostics.metrics.get("budget_output_confirmed_utf8_bytes")
      is Some(previous) else {
      return Err(
        cli_failure(OutputFailure, "missing converter output confirmation"),
      )
    }
    let amount = @string.parse_int64(previous, base=10) catch {
      _ =>
        return Err(
          cli_failure(OutputFailure, "invalid converter output confirmation"),
        )
    }
    if amount < 0L || amount > 9223372036854775807L - tail.added_bytes {
      return Err(
        cli_failure(OutputFailure, "converter output confirmation overflow"),
      )
    }
    diagnostics.metrics.set(
      "budget_output_confirmed_utf8_bytes",
      (amount + tail.added_bytes).to_string(),
    )
  }
  tail.applied.val = true
  @convert.refresh_budget_diagnostics(tail.source, diagnostics)
  Ok(())
}

///|
priv struct CliAtomicOutput {
  sink : @convert.OutputSink
  wrote_any : Ref[Bool]
  tail : Ref[CliFileTail?]
}

///|
fn open_cli_atomic_output(owner : BudgetedAtomicWriter) -> CliAtomicOutput {
  let wrote_any = Ref(false)
  let ends_with_lf = Ref(false)
  let tail : Ref[CliFileTail?] = Ref(None)
  let sink = @convert.make_output_sink(
    fn(chunk) {
      match budgeted_atomic_write(owner, chunk) {
        Ok(_) => {
          if chunk != "" {
            wrote_any.val = true
            ends_with_lf.val = chunk.has_suffix("\n")
          }
          Ok(())
        }
        Err(message) => Err(message)
      }
    },
    fn() {
      if tail.val is Some(_) {
        return Err("CLI atomic output finished twice")
      }
      let admitted = match
        admit_cli_file_tail(
          owner.source,
          cli_file_needs_lf(wrote_any.val, ends_with_lf.val),
        ) {
        Ok(value) => value
        Err(failure) => return Err(failure.message)
      }
      tail.val = Some(admitted)
      if admitted.added_bytes > 0L {
        match budgeted_atomic_write(owner, "\n") {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
      confirm_cli_file_tail(admitted)
      Ok(())
    },
  )
  { sink, wrote_any, tail, }
}
