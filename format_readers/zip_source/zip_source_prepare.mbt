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
  let bytes_payload = match @sourceio.read_source_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let archive = try @dzip.open_zip(bytes_payload.bytes) |> Ok catch {
    e => Err(e.to_string())
  }
  match archive {
    Ok(value) =>
      Ok({
        prepared_source: bytes_payload.prepared_source,
        archive: value,
        inspect: @dzip.inspect_zip_archive(value),
      })
    Err(err) => Err(err)
  }
}
