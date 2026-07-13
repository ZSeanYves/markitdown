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
  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let prepared_source = if @input.input_bytes(source) is Some(_) {
    source
  } else {
    @input.with_bytes_payload(source, bytes)
  }
  let document = try open_ods_document(bytes) |> Ok catch {
    err => Err(err.to_string())
  }
  match document {
    Ok(value) =>
      Ok({
        prepared_source,
        document: value,
        inspect: inspect_ods_document(value),
      })
    Err(err) => Err(err)
  }
}
