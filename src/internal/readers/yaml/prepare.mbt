///|
pub struct PreparedYamlDocument {
  prepared_source : @input.InputSource
  original_text : String
  document : YamlStructureDocument?
  inspect : YamlInspectReport?
  events : Array[YamlStructureEvent]?
  compact_sequence : YamlCompactSequenceSummary?
  parse_error : String?
}

///|
pub fn prepare_yaml_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedYamlDocument, String] {
  let text_payload = match @sourceio.read_source_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  match prepare_yaml_compact_sequence_summary(text_payload.text) {
    Some(compact) =>
      return Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        document: None,
        inspect: Some(compact.inspect),
        events: None,
        compact_sequence: Some(compact),
        parse_error: None,
      })
    None => ()
  }
  let structured = try
    parse_yaml_structure_document(text_payload.text) |> Ok
  catch {
    e => Err(e.to_string())
  }
  match structured {
    Ok(doc) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        document: Some(doc),
        inspect: Some(inspect_yaml_document(doc.document)),
        events: Some(doc.events),
        compact_sequence: None,
        parse_error: None,
      })
    Err(err) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        document: None,
        inspect: None,
        events: None,
        compact_sequence: None,
        parse_error: Some(err),
      })
  }
}
