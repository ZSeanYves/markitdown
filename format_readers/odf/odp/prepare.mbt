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
  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let prepared_source = if source.bytes is Some(_) {
    source
  } else {
    @input.with_bytes_payload(source, bytes)
  }
  let document = try open_odp_document(bytes) |> Ok catch {
    err => Err(err.to_string())
  }
  match document {
    Ok(value) =>
      Ok({
        prepared_source,
        document: value,
        inspect: inspect_odp_document(value),
      })
    Err(err) => Err(err)
  }
}
