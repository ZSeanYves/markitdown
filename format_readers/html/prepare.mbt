///|
pub struct PreparedHtmlDocument {
  prepared_source : @input.InputSource
  original_text : String
  normalized_text : String
  document : HtmlDocument?
  inspect : HtmlInspectReport?
  events : Array[HtmlTokenEvent]?
  parse_error : String?
}

///|
pub fn prepare_html_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedHtmlDocument, String] {
  let text_payload = match @sourceio.read_source_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let normalized = normalize_html_token_source(text_payload.text)
  let scanned = try tokenize_html_events(text_payload.text) |> Ok catch {
    e => Err(e.to_string())
  }
  // Inputs above the product DOM character limit are routed through the
  // token-backed block stream. Avoid retaining an unused DOM beside events.
  let document : Result[HtmlDocument, String] = if text_payload.text.length() >
    256_000 {
    Err("html DOM preparation skipped above the block-stream limit")
  } else {
    try parse_html_document(text_payload.text) |> Ok catch {
      e => Err(e.to_string())
    }
  }
  Ok({
    prepared_source: text_payload.prepared_source,
    original_text: text_payload.text,
    normalized_text: normalized,
    document: match document {
      Ok(doc) => Some(doc)
      Err(_) => None
    },
    inspect: match document {
      Ok(doc) => Some(inspect_html_document(doc))
      Err(_) => None
    },
    events: match scanned {
      Ok(events) => Some(events)
      Err(_) => None
    },
    parse_error: match (document, scanned) {
      (Err(doc_err), Err(scan_err)) => Some(doc_err + "; " + scan_err)
      (Err(doc_err), _) => Some(doc_err)
      (_, Err(scan_err)) => Some(scan_err)
      _ => None
    },
  })
}
