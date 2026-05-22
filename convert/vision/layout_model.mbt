///|
pub enum OcrLayoutBlockKind {
  Paragraph
  TableLike
  Heading
  ListItem
  Noise
  Unknown
} derive(Eq)

///|
pub struct OcrLayoutBlock {
  kind : OcrLayoutBlockKind
  text : String
  bbox : VisionBBox
  confidence : Double
  line_indices : Array[Int]
  reasons : Array[String]
}

///|
pub struct OcrLayoutPage {
  page_index : Int
  blocks : Array[OcrLayoutBlock]
  warnings : Array[String]
}

///|
pub fn make_unknown_ocr_layout_block(
  text : String,
  line_indices : Array[Int],
  reasons : Array[String],
) -> OcrLayoutBlock {
  {
    kind: OcrLayoutBlockKind::Unknown,
    text,
    bbox: unknown_bbox(),
    confidence: -1.0,
    line_indices,
    reasons,
  }
}

///|
pub fn ocr_layout_block_line_count(block : OcrLayoutBlock) -> Int {
  block.line_indices.length()
}

///|
pub fn ocr_layout_page_block_count(page : OcrLayoutPage) -> Int {
  page.blocks.length()
}

///|
pub fn ocr_layout_page_text(page : OcrLayoutPage) -> String {
  let blocks : Array[String] = []
  for block in page.blocks {
    let text = block.text.trim().to_owned()
    if text != "" {
      blocks.push(text)
    }
  }
  blocks.join("\n\n")
}
