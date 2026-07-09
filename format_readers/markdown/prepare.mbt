///|
pub struct PreparedMarkdownDocument {
  prepared_source : @input.InputSource
  original_text : String
  document : MarkdownDocument
  inspect : MarkdownInspectReport
}

///|
pub fn prepare_markdown_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedMarkdownDocument, String] {
  let text_payload = match @sourceio.read_source_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let document = scan_markdown_document(text_payload.text)
  Ok({
    prepared_source: text_payload.prepared_source,
    original_text: text_payload.text,
    document,
    inspect: inspect_markdown_document(document),
  })
}
