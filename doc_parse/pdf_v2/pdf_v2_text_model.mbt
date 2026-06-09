///|
pub(all) struct PdfV2FontRun {
  font_name : String?
  font_size : Double?
  is_bold : Bool
  is_italic : Bool
  is_monospace : Bool
}

///|
pub(all) struct PdfV2Char {
  text : String
  bbox : PdfV2Rect
  origin : PdfV2Point
  font : PdfV2FontRun?
  decode_confidence : Double?
  source_ref : PdfV2SourceRef
}

///|
pub(all) struct PdfV2Span {
  id : String
  text : String
  bbox : PdfV2Rect
  font_name : String?
  font_size : Double?
  style_flags : Array[String]
  color : PdfV2Color?
  chars : Array[PdfV2Char]
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2Line {
  id : String
  text : String
  bbox : PdfV2Rect
  spans : Array[PdfV2Span]
  baseline_y : Double?
  line_height : Double?
  indent_left : Double?
  indent_right : Double?
  gap_before : Double?
  gap_after : Double?
  wrapped_candidate : Bool
  continuation_candidate : Bool
  list_marker : PdfV2ListMarker?
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2LayoutHint {
  label : String
  confidence : Double
  source : PdfV2DecisionSource
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2TextBlock {
  id : String
  page_index : Int
  text : String
  bbox : PdfV2Rect
  lines : Array[PdfV2Line]
  dominant_font : String?
  dominant_font_size : Double?
  writing_direction : PdfV2WritingDirection
  geometry_features : Map[String, Double]
  text_shape_features : Map[String, Double]
  layout_hints : Array[PdfV2LayoutHint]
  classifier_ready_features : Map[String, Double]
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2TextPage {
  page_index : Int
  blocks : Array[PdfV2TextBlock]
  warnings : Array[PdfV2Warning]
}

///|
pub(all) struct PdfV2TextModel {
  pages : Array[PdfV2TextPage]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
}

///|
pub fn build_pdf_v2_text_model(source : PdfV2SourceDocument) -> PdfV2TextModel {
  let pages : Array[PdfV2TextPage] = []
  for page in source.pages {
    pages.push({ page_index: page.page_index, blocks: [], warnings: [] })
  }
  {
    pages,
    warnings: [
      pdf_v2_scaffold_warning(
        "pdf_v2 text reconstruction scaffold preserves boundaries but does not group glyphs yet",
      ),
    ],
    risks: source.risks,
  }
}

///|
pub fn pdf_v2_make_scaffold_block(
  page_index : Int,
  id : String,
  text : String,
) -> PdfV2TextBlock {
  let bbox = pdf_v2_default_rect()
  {
    id,
    page_index,
    text,
    bbox,
    lines: [],
    dominant_font: None,
    dominant_font_size: None,
    writing_direction: PdfV2WritingDirection::Unknown,
    geometry_features: Map([]),
    text_shape_features: Map([]),
    layout_hints: [],
    classifier_ready_features: Map([]),
    source_refs: [pdf_v2_source_ref_for_page(page_index)],
  }
}
