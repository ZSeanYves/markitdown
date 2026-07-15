///|
pub struct PreparedOdpDocument {
  prepared_source : @input.InputSource
  document : OdpDocument
  inspect : OdpInspectReport
}

///|
pub fn prepare_odp_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedOdpDocument, String] {
  let prepared = match @zsource.prepare_zip_from_source(source) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let document = try @shared.open_odp_archive(prepared.archive) |> Ok catch {
    err => Err(err.to_string())
  }
  match document {
    Ok(value) =>
      Ok({
        prepared_source: prepared.prepared_source,
        document: value,
        inspect: inspect_odp_document(value),
      })
    Err(err) => Err(err)
  }
}
