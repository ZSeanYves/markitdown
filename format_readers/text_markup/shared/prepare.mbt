///|
pub struct PreparedTextMarkupDocument {
  prepared_source : @input.InputSource
  original_text : String
  document : TextMarkupDocument
  inspect : TextMarkupInspectReport
}

///|
pub fn prepare_tex_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedTextMarkupDocument, String] {
  prepare_text_markup_from_source(source, TextMarkupFormat::Tex)
}

///|
pub fn prepare_rst_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedTextMarkupDocument, String] {
  prepare_text_markup_from_source(source, TextMarkupFormat::Rst)
}

///|
pub fn prepare_asciidoc_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedTextMarkupDocument, String] {
  prepare_text_markup_from_source(source, TextMarkupFormat::Asciidoc)
}

///|
fn prepare_text_markup_from_source(
  source : @input.InputSource,
  format : TextMarkupFormat,
) -> Result[PreparedTextMarkupDocument, String] {
  let text_payload = match @sourceio.read_source_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let document = parse_markup_document(text_payload.text, format)
  Ok({
    prepared_source: text_payload.prepared_source,
    original_text: text_payload.text,
    document,
    inspect: inspect_text_markup_document(document, text_payload.text),
  })
}
