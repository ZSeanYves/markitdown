///|
/// Provider identity and runtime metadata attached to OCR results.
pub struct OcrProviderInfo {
  name : String
  version : String?
  language : String?
  diagnostics : Array[String]
}

///|
/// One OCR word token plus optional geometry and confidence.
pub struct OcrWord {
  word_index : Int
  text : String
  bbox : @core.BBox?
  confidence : Double?
}

///|
/// One OCR line recovered from the provider output.
///
/// `text` is the normalized line text, while `words` preserves token-level
/// segmentation when the provider exposes it.
pub struct OcrLine {
  line_index : Int
  text : String
  words : Array[OcrWord]
  bbox : @core.BBox?
  confidence : Double?
}

///|
/// One OCR block consisting of one or more lines.
pub struct OcrBlock {
  block_index : Int
  lines : Array[OcrLine]
  bbox : @core.BBox?
  confidence : Double?
}

///|
/// OCR result for a single page or image.
///
/// `provider` can be repeated per page for convenience, even when the document
/// also records the same top-level provider identity.
pub struct OcrPageModel {
  page_index : Int
  width : Double?
  height : Double?
  blocks : Array[OcrBlock]
  provider : OcrProviderInfo?
  diagnostics : Array[String]
}

///|
/// OCR result for an entire input document or image batch.
pub struct OcrDocumentModel {
  pages : Array[OcrPageModel]
  provider : OcrProviderInfo?
  diagnostics : Array[String]
}

///|
/// Construct one provider info record.
pub fn make_ocr_provider_info(
  name : String,
  version? : String? = None,
  language? : String? = None,
  diagnostics? : Array[String] = [],
) -> OcrProviderInfo {
  { name, version, language, diagnostics }
}

///|
/// Construct one OCR word token.
pub fn make_ocr_word(
  word_index : Int,
  text : String,
  bbox? : @core.BBox? = None,
  confidence? : Double? = None,
) -> OcrWord {
  { word_index, text, bbox, confidence }
}

///|
/// Construct one OCR line.
pub fn make_ocr_line(
  line_index : Int,
  text : String,
  words? : Array[OcrWord] = [],
  bbox? : @core.BBox? = None,
  confidence? : Double? = None,
) -> OcrLine {
  { line_index, text, words, bbox, confidence }
}

///|
/// Construct one OCR block.
pub fn make_ocr_block(
  block_index : Int,
  lines? : Array[OcrLine] = [],
  bbox? : @core.BBox? = None,
  confidence? : Double? = None,
) -> OcrBlock {
  { block_index, lines, bbox, confidence }
}

///|
/// Return an empty OCR document model with optional provider metadata.
pub fn empty_ocr_document_model(
  provider? : OcrProviderInfo? = None,
  diagnostics? : Array[String] = [],
) -> OcrDocumentModel {
  { pages: [], provider, diagnostics }
}

///|
/// Return an empty OCR page model for `page_index`.
pub fn empty_ocr_page_model(
  page_index : Int,
  provider? : OcrProviderInfo? = None,
  diagnostics? : Array[String] = [],
) -> OcrPageModel {
  { page_index, width: None, height: None, blocks: [], provider, diagnostics }
}

///|
/// Count how many pages are present in one OCR document model.
pub fn ocr_document_page_count(document : OcrDocumentModel) -> Int {
  document.pages.length()
}

///|
/// Count how many top-level blocks are present in one OCR page.
pub fn ocr_page_block_count(page : OcrPageModel) -> Int {
  page.blocks.length()
}
