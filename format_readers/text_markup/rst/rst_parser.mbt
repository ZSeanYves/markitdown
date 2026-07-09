///|
pub type TextMarkupBlock = @shared.TextMarkupBlock

///|
pub type TextMarkupBlockKind = @shared.TextMarkupBlockKind

///|
pub type TextMarkupDocument = @shared.TextMarkupDocument

///|
pub type TextMarkupFormat = @shared.TextMarkupFormat

///|
pub type TextMarkupInline = @shared.TextMarkupInline

///|
pub type TextMarkupInlineKind = @shared.TextMarkupInlineKind

///|
pub type TextMarkupInspectReport = @shared.TextMarkupInspectReport

///|
pub type TextMarkupTable = @shared.TextMarkupTable

///|
pub fn inspect_text_markup_document(
  doc : TextMarkupDocument,
  original_text : String,
) -> TextMarkupInspectReport {
  @shared.inspect_text_markup_document(doc, original_text)
}

///|
pub fn parse_rst_document(text : String) -> TextMarkupDocument {
  @shared.parse_rst_document(text)
}

///|
pub fn parse_text_markup_inlines(
  text : String,
  format : TextMarkupFormat,
) -> Array[TextMarkupInline] {
  @shared.parse_text_markup_inlines(text, format)
}

///|
pub fn parse_text_markup_table(
  block : TextMarkupBlock,
  format : TextMarkupFormat,
) -> TextMarkupTable? {
  @shared.parse_text_markup_table(block, format)
}

///|
pub fn prepare_rst_document_from_source(
  source : @input.InputSource,
) -> Result[@shared.PreparedTextMarkupDocument, String] {
  @shared.prepare_rst_document_from_source(source)
}
