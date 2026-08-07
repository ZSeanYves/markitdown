///|
pub struct PreparedTomlDocument {
  prepared_source : @input.InputSource
  original_text : String
  document : TomlDocument?
  inspect : TomlInspectReport?
  fast_array_table : TomlFastArrayTable?
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
  let fast = prepare_fast_array_table_suffix(text_payload.text)
  let parse_text = match fast {
    Some((prefix, _)) => prefix
    None => text_payload.text
  }
  let parsed = try parse_toml_document(parse_text) |> Ok catch {
    e => Err(e.to_string())
  }
  match parsed {
    Ok(doc) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        document: Some(doc),
        inspect: Some(
          match fast {
            Some((_, tail)) => inspect_toml_document_with_fast_array(doc, tail)
            None => inspect_toml_document(doc)
          },
        ),
        fast_array_table: fast.map(item => item.1),
        parse_error: None,
      })
    Err(err) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        document: None,
        inspect: None,
        fast_array_table: None,
        parse_error: Some(err),
      })
  }
}
