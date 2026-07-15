///|
pub struct PreparedOdtDocument {
  prepared_source : @input.InputSource
  document : OdtDocument
  inspect : OdtInspectReport
}

///|
pub fn prepare_odt_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedOdtDocument, String] {
  let prepared = match @zsource.prepare_zip_from_source(source) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let document = try @shared.open_odt_archive(prepared.archive) |> Ok catch {
    err => Err(err.to_string())
  }
  match document {
    Ok(value) =>
      Ok({
        prepared_source: prepared.prepared_source,
        document: value,
        inspect: inspect_odt_document(value),
      })
    Err(err) => Err(err)
  }
}
