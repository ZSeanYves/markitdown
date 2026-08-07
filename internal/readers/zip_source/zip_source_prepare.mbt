///|
pub struct PreparedZipArchive {
  prepared_source : @input.InputSource
  archive : @dzip.ZipArchive
  inspect : @dzip.ZipArchiveInspectReport
}

///|
pub fn prepare_zip_from_source(
  source : @input.InputSource,
) -> Result[PreparedZipArchive, String] {
  let prepared_source : Ref[@input.InputSource] = Ref(source)
  let archive = match @input.input_bytes(source) {
    Some(bytes) =>
      try @dzip.open_zip(bytes) |> Ok catch {
        e => Err(e.to_string())
      }
    None =>
      match @input.open_source_cursor(source) {
        Ok(cursor) =>
          match cursor.size {
            Some(size) =>
              try
                @dzip.open_zip_reader(size.to_int(), fn(offset, length) {
                  @input.source_cursor_read_at(
                    cursor,
                    offset.to_int64(),
                    length~,
                  )
                })
                |> Ok
              catch {
                e => Err(e.to_string())
              }
            None => {
              let bytes_payload = match @sourceio.read_source_bytes(source) {
                Ok(payload) => payload
                Err(err) => return Err(err)
              }
              prepared_source.val = bytes_payload.prepared_source
              try @dzip.open_zip(bytes_payload.bytes) |> Ok catch {
                e => Err(e.to_string())
              }
            }
          }
        Err(err) => Err(err)
      }
  }
  match archive {
    Ok(value) =>
      Ok({
        prepared_source: prepared_source.val,
        archive: value,
        inspect: @dzip.inspect_zip_archive(value),
      })
    Err(err) => Err(err)
  }
}
