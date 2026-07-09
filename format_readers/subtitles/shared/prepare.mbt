///|
pub struct PreparedSubtitleDocument {
  prepared_source : @input.InputSource
  original_text : String
  document : SubtitleDocument?
  inspect : SubtitleInspectReport?
  format_name : String
  parse_error : String?
}

///|
pub fn prepare_srt_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedSubtitleDocument, String] {
  prepare_subtitle_from_source(source, "srt")
}

///|
pub fn prepare_vtt_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedSubtitleDocument, String] {
  prepare_subtitle_from_source(source, "vtt")
}

///|
fn prepare_subtitle_from_source(
  source : @input.InputSource,
  format_name : String,
) -> Result[PreparedSubtitleDocument, String] {
  let text_payload = match @sourceio.read_source_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let parsed = if format_name == "vtt" {
    try parse_vtt_document(text_payload.text) |> Ok catch {
      e => Err(e.to_string())
    }
  } else {
    try parse_srt_document(text_payload.text) |> Ok catch {
      e => Err(e.to_string())
    }
  }
  match parsed {
    Ok(document) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        document: Some(document),
        inspect: Some(inspect_subtitle_document(document)),
        format_name,
        parse_error: None,
      })
    Err(err) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        document: None,
        inspect: None,
        format_name,
        parse_error: Some(err),
      })
  }
}
