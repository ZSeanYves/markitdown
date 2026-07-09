///|
pub struct PreparedTomlDocument {
  prepared_source : @input.InputSource
  original_text : String
  document : TomlDocument?
  inspect : TomlInspectReport?
  parse_error : String?
}

///|
pub fn prepare_toml_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedTomlDocument, String] {
  let text_payload = match @sourceio.read_source_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let parsed = try parse_toml_document(text_payload.text) |> Ok catch {
    e => Err(e.to_string())
  }
  match parsed {
    Ok(doc) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        document: Some(doc),
        inspect: Some(inspect_toml_document(doc)),
        parse_error: None,
      })
    Err(err) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        document: None,
        inspect: None,
        parse_error: Some(err),
      })
  }
}
