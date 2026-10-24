///|
/// CLI-local output owner. Parser cleanup stays in its own earlier phase.
/// Exactly one growing credit is held for possible file growth, including an
/// admitted chunk whose write later fails or accepts only a short prefix.
priv struct BudgetedAtomicWriter {
  writer : AtomicFileWriter
  source : @input.InputSource
  account : @budget.Budget
  credit : Ref[@budget.BudgetLease?]
  terminal : Ref[Bool]
}

///|
fn atomic_budget_error(
  source : @input.InputSource,
  error : @budget.BudgetError,
) -> String {
  @input.record_input_budget_failure(source, error)
  @input.input_source_error(source).unwrap_or(
    @budget.budget_error_message(error),
  )
}

///|
fn cli_atomic_failure(
  source : @input.InputSource,
  fallback : String,
) -> CliFailure {
  match @input.input_source_failure(source) {
    Some(BudgetFailure(LimitExceeded(dimension, used~, requested~, limit~))) =>
      cli_failure(
        ResourceFailure,
        @convert.ConvertError::ResourceLimitExceeded(
          kind=@budget.budget_dimension_name(dimension),
          observed=used + requested,
          limit~,
        ).to_string(),
      )
    Some(ResourceLimit(_)) =>
      cli_failure(
        ResourceFailure,
        @input.input_source_error(source).unwrap_or(fallback),
      )
    Some(InputError(message)) => cli_failure(ConversionFailure, message)
    Some(BudgetFailure(error)) =>
      cli_failure(ConversionFailure, @budget.budget_error_message(error))
    None => cli_failure(OutputFailure, fallback)
  }
}

///|
fn open_budgeted_atomic_writer(
  source : @input.InputSource,
  limits : @convert.ResourceLimits,
  output_path : String,
) -> Result[BudgetedAtomicWriter, CliFailure] {
  guard @input.input_source_budget_context(source) is Some(context) else {
    return Err(
      cli_failure(
        OutputFailure,
        "atomic output requires its input session budget",
      ),
    )
  }
  if @input.input_source_failure(source) is Some(_) {
    return Err(cli_atomic_failure(source, "atomic source has already failed"))
  }
  if limits.max_temporary_bytes is Some(capacity) {
    if capacity < 0L {
      return Err(
        cli_failure(UsageFailure, "temporary capacity must be nonnegative"),
      )
    }
    match context.account.tighten_resident_limit(TemporaryBytes, capacity) {
      Ok(_) => ()
      Err(error) => {
        let message = atomic_budget_error(source, error)
        return Err(cli_atomic_failure(source, message))
      }
    }
  }
  // This is after same-ledger admission configuration, before any writer open.
  match open_atomic_file_writer(output_path) {
    Ok(writer) =>
      Ok({
        writer,
        source,
        account: context.account,
        credit: Ref(None),
        terminal: Ref(false),
      })
    Err(message) => Err(cli_atomic_failure(source, message))
  }
}

///|
fn budgeted_atomic_write(
  owner : BudgetedAtomicWriter,
  chunk : String,
) -> Result[Unit, String] {
  if @input.input_source_error(owner.source) is Some(message) {
    return Err(message)
  }
  if atomic_writer_status_ffi(owner.writer) != 0 {
    return Err(atomic_file_writer_error_message(owner.writer))
  }
  if owner.terminal.val {
    return Err("atomic output owner is closed")
  }
  let size = match @input.validated_text_utf8_size(chunk) {
    Ok(size) => size
    Err(_) => {
      ignore(atomic_writer_invalid_encoding_ffi(owner.writer))
      return Err(atomic_file_writer_error_message(owner.writer))
    }
  }
  if size > 0L {
    let grown = match owner.credit.val {
      Some(credit) => credit.grow(size)
      None =>
        match owner.account.reserve(TemporaryBytes, size) {
          Ok(credit) => {
            owner.credit.val = Some(credit)
            Ok(())
          }
          Err(error) => Err(error)
        }
    }
    match grown {
      Ok(_) => ()
      Err(error) => return Err(atomic_budget_error(owner.source, error))
    }
  }
  let working = match owner.account.reserve(WorkingBytes, size) {
    Ok(lease) => lease
    Err(error) => return Err(atomic_budget_error(owner.source, error))
  }
  defer working.release()
  // Only the bounded UTF8 encoder payload is included in this Working scope;
  // stdio/allocator/path buffers remain explicitly separate.
  atomic_file_writer_write(owner.writer, chunk)
}

///|
fn refund_reclaimed_atomic_credit(owner : BudgetedAtomicWriter) -> Unit {
  if atomic_writer_reclamation_certain_ffi(owner.writer) {
    if owner.credit.val is Some(credit) {
      credit.release()
    }
    owner.credit.val = None
  }
}

///|
fn budgeted_atomic_abort(owner : BudgetedAtomicWriter) -> Result[Unit, String] {
  owner.terminal.val = true
  let result = atomic_file_writer_abort(owner.writer)
  refund_reclaimed_atomic_credit(owner)
  result
}

///|
fn budgeted_atomic_commit(owner : BudgetedAtomicWriter) -> Result[Unit, String] {
  if @input.input_source_error(owner.source) is Some(message) {
    return Err(message)
  }
  owner.terminal.val = true
  let result = atomic_file_writer_commit(owner.writer)
  // Confirmed rename transfers ownership to final output. Unknown close never
  // passes the C reclamation predicate, even if a later unlink removes its name.
  refund_reclaimed_atomic_credit(owner)
  result
}

///|
fn cli_abort_budgeted_atomic_failure(
  owner : BudgetedAtomicWriter,
  original : CliFailure,
) -> CliFailure {
  owner.terminal.val = true
  let result = cli_abort_atomic_failure(owner.writer, original)
  refund_reclaimed_atomic_credit(owner)
  result
}
