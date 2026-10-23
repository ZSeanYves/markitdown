///|
pub struct PreparedZipArchive {
  prepared_source : @input.InputSource
  archive : @dzip.ZipArchive
  inspect : @dzip.ZipArchiveInspectReport
}

///|
pub async fn prepare_zip_from_source(
  source : @input.InputSource,
) -> Result[PreparedZipArchive, String] noraise {
  let budget_context = @input.input_source_budget_context(source)
  let archive = match @input.input_bytes(source) {
    Some(bytes) =>
      try @dzip.open_zip(bytes, budget_context?) |> Ok catch {
        e => Err(e.to_string())
      }
    None =>
      match @input.open_source_cursor(source) {
        Ok(cursor) => {
          let size = match @input.discover_source_size(cursor) {
            Ok(value) => value
            Err(message) => return Err(message)
          }
          if size > 2147483647L {
            return Err("ZIP source exceeds the supported 32-bit archive size")
          }
          try
            @dzip.open_zip_reader(
              size.to_int(),
              async fn(offset, length) {
                @input.source_cursor_read_at(cursor, offset.to_int64(), length~)
              },
              budget_context?,
            )
            |> Ok
          catch {
            e => Err(e.to_string())
          }
        }
        Err(err) => Err(err)
      }
  }
  match archive {
    Ok(value) => {
      @dzip.set_hard_failure_reporter(value, message => {
        @input.record_input_failure(source, message)
      })
      Ok({
        prepared_source: source,
        archive: value,
        inspect: @dzip.inspect_zip_archive(value),
      })
    }
    Err(err) => Err(err)
  }
}
