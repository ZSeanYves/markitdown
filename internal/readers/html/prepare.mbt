///|
pub struct PreparedHtmlDocument {
  prepared_source : @input.InputSource
  original_text : String
  normalized_text : String
  document : HtmlDocument?
  inspect : HtmlInspectReport?
  events : Array[HtmlTokenEvent]?
  event_summary : HtmlTokenEventSummary?
  parse_error : String?
}

///|
pub async fn prepare_html_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedHtmlDocument, String] {
  let text_payload = match @sourceio.read_source_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let normalized = normalize_html_token_source(text_payload.text)
  if text_payload.text.length() <= 256_000 {
    // One lexer supplies DOM tokens and event offsets. Tokens stay local;
    // only the prepared DOM and its events survive this call.
    let analysis = try analyze_normalized_html_source(normalized) |> Ok catch {
      error => Err(error.to_string())
    }
    return Ok({
      prepared_source: text_payload.prepared_source,
      original_text: text_payload.text,
      normalized_text: normalized,
      document: analysis.to_option().map(value => value.document),
      inspect: analysis
      .to_option()
      .map(value => inspect_html_document(value.document)),
      events: analysis.to_option().map(value => value.events),
      event_summary: None,
      // Preserve the two old scanner error messages without scanning twice.
      parse_error: match analysis {
        Ok(_) => None
        Err(error) => Some(error + "; " + error)
      },
    })
  }
  // Retain the compact route and the existing threshold. Large inputs do
  // not gain a complete DOM or complete event array through this reuse.
  let summary = try scan_html_event_summary(normalized) |> Ok catch {
    error => Err(error.to_string())
  }
  let skipped = "html DOM preparation skipped above the block-stream limit"
  Ok({
    prepared_source: text_payload.prepared_source,
    original_text: text_payload.text,
    normalized_text: normalized,
    document: None,
    inspect: None,
    events: None,
    event_summary: summary.to_option(),
    parse_error: Some(
      match summary {
        Ok(_) => skipped
        Err(error) => skipped + "; " + error
      },
    ),
  })
}
