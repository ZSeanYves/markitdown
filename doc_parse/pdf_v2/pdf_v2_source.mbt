///|
pub(all) enum PdfV2SourceEventKind {
  PageStart
  ContentStream
  TextOp
  Glyph
  GraphicsOp
  Image
  Vector
  Annotation
  Form
  Resource
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2TextOp {
  operator : String
  raw_text : String?
  font_ref : String?
  font_size : Double?
  source_ref : PdfV2SourceRef
}

///|
pub(all) struct PdfV2Glyph {
  unicode : String
  raw_bytes : Bytes?
  bbox : PdfV2Rect
  origin : PdfV2Point
  font_name : String?
  font_size : Double?
  decode_confidence : Double?
  source_ref : PdfV2SourceRef
}

///|
pub(all) struct PdfV2GraphicsOp {
  operator : String
  bbox : PdfV2Rect?
  source_ref : PdfV2SourceRef
}

///|
pub(all) struct PdfV2UnknownSource {
  raw_kind : String
  message : String
  recoverable : Bool
  source_ref : PdfV2SourceRef
}

///|
pub(all) enum PdfV2SourceEvent {
  PageStart(Int)
  ContentStream(String, PdfV2SourceRef)
  TextOp(PdfV2TextOp)
  Glyph(PdfV2Glyph)
  GraphicsOp(PdfV2GraphicsOp)
  Image(PdfV2Image)
  Vector(PdfV2Vector)
  Annotation(PdfV2Annotation)
  Form(PdfV2Form)
  Resource(String, PdfV2SourceRef)
  Unknown(PdfV2UnknownSource)
}

///|
pub(all) struct PdfV2SourcePage {
  page_index : Int
  boxes : PdfV2PageBoxes
  rotation : Int
  user_unit : Double?
  events : Array[PdfV2SourceEvent]
  source_refs : Array[PdfV2SourceRef]
  warnings : Array[PdfV2Warning]
}

///|
pub(all) struct PdfV2SourceDocument {
  core_bytes_len : Int
  pages : Array[PdfV2SourcePage]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  scanned_once : Bool
}

///|
pub fn parse_pdf_v2_source(core : PdfV2CoreDocument) -> PdfV2SourceDocument {
  let pages : Array[PdfV2SourcePage] = []
  for page in core.pages {
    pages.push({
      page_index: page.page_index,
      boxes: page.boxes,
      rotation: page.rotation,
      user_unit: page.user_unit,
      events: [PdfV2SourceEvent::PageStart(page.page_index)],
      source_refs: [pdf_v2_source_ref_for_page(page.page_index)],
      warnings: [],
    })
  }
  {
    core_bytes_len: core.bytes_len,
    pages,
    warnings: core.warnings,
    risks: core.risks,
    scanned_once: core.scanned_once,
  }
}
