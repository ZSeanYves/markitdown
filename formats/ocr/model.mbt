///|
pub struct OcrProviderInfo {
  name : String
  version : String?
  language : String?
  diagnostics : Array[String]
}

///|
pub struct OcrWord {
  word_index : Int
  text : String
  bbox : @core.BBox?
  confidence : Double?
}

///|
pub struct OcrLine {
  line_index : Int
  text : String
  words : Array[OcrWord]
  bbox : @core.BBox?
  confidence : Double?
}

///|
pub struct OcrBlock {
  block_index : Int
  lines : Array[OcrLine]
  bbox : @core.BBox?
  confidence : Double?
}

///|
pub struct OcrPageModel {
  page_index : Int
  width : Double?
  height : Double?
  blocks : Array[OcrBlock]
  provider : OcrProviderInfo?
  diagnostics : Array[String]
}

///|
pub struct OcrDocumentModel {
  pages : Array[OcrPageModel]
  provider : OcrProviderInfo?
  diagnostics : Array[String]
}

///|
pub fn make_ocr_provider_info(
  name : String,
  version? : String? = None,
  language? : String? = None,
  diagnostics? : Array[String] = [],
) -> OcrProviderInfo {
  { name, version, language, diagnostics }
}

///|
pub fn make_ocr_word(
  word_index : Int,
  text : String,
  bbox? : @core.BBox? = None,
  confidence? : Double? = None,
) -> OcrWord {
  { word_index, text, bbox, confidence }
}

///|
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
pub fn make_ocr_block(
  block_index : Int,
  lines? : Array[OcrLine] = [],
  bbox? : @core.BBox? = None,
  confidence? : Double? = None,
) -> OcrBlock {
  { block_index, lines, bbox, confidence }
}

///|
pub fn empty_ocr_document_model(
  provider? : OcrProviderInfo? = None,
  diagnostics? : Array[String] = [],
) -> OcrDocumentModel {
  { pages: [], provider, diagnostics }
}

///|
pub fn empty_ocr_page_model(
  page_index : Int,
  provider? : OcrProviderInfo? = None,
  diagnostics? : Array[String] = [],
) -> OcrPageModel {
  { page_index, width: None, height: None, blocks: [], provider, diagnostics }
}

///|
pub fn ocr_document_page_count(document : OcrDocumentModel) -> Int {
  document.pages.length()
}

///|
pub fn ocr_page_block_count(page : OcrPageModel) -> Int {
  page.blocks.length()
}
