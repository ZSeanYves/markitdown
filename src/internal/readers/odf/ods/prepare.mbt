///|
pub struct PreparedOdsDocument {
  prepared_source : @input.InputSource
  document : OdsDocument
  inspect : OdsInspectReport
}

///|
pub fn prepare_ods_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedOdsDocument, String] {
  let prepared = match @zsource.prepare_zip_from_source(source) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let document = try @shared.open_ods_archive(prepared.archive) |> Ok catch {
    err => Err(err.to_string())
  }
  match document {
    Ok(value) =>
      Ok({
        prepared_source: prepared.prepared_source,
        document: value,
        inspect: inspect_ods_document(value),
      })
    Err(err) => Err(err)
  }
}
