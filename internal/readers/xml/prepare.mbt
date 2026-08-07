///|
pub struct PreparedXmlText {
  prepared_source : @input.InputSource
  original_text : String
  normalized_text : String
  tokens : Array[XmlToken]?
  parse_error : String?
}

///|
pub fn prepare_xml_from_source(
  source : @input.InputSource,
) -> Result[PreparedXmlText, String] {
  let text_payload = match @sourceio.read_xml_source_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let normalized = normalize_xml_text_for_next(text_payload.text)
  let tokens = try parse_xml_structure_tokens(normalized) |> Ok catch {
    e => Err(e.to_string())
  }
  match tokens {
    Ok(value) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        normalized_text: normalized,
        tokens: Some(value),
        parse_error: None,
      })
    Err(err) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        normalized_text: normalized,
        tokens: None,
        parse_error: Some(err),
      })
  }
}

///|
fn normalize_xml_text_for_next(text : String) -> String {
  if !text.has_prefix("\u{FEFF}") {
    return text
  }
  let chars = text.to_array()
  if chars.length() <= 1 {
    return ""
  }
  let out : Array[Char] = []
  for i in 1..<chars.length() {
    out.push(chars[i])
  }
  String::from_array(out)
}
