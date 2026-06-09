///|
pub(all) struct PdfV2Metadata {
  title : String?
  author : String?
  subject : String?
  keywords : Array[String]
  creator : String?
  producer : String?
}

///|
pub(all) struct PdfV2SourceSummary {
  core_bytes_len : Int
  page_count : Int
  warning_count : Int
  risk_count : Int
  scanned_once : Bool
}

///|
pub(all) struct PdfV2Page {
  page_index : Int
  page_label : String?
  boxes : PdfV2PageBoxes
  rotation : Int
  user_unit : Double?
  text_blocks : Array[PdfV2TextBlock]
  images : Array[PdfV2Image]
  vectors : Array[PdfV2Vector]
  annotations : Array[PdfV2Annotation]
  forms : Array[PdfV2Form]
  layout_regions : Array[PdfV2LayoutRegion]
  reading_order : PdfV2ReadingOrder
  risks : Array[PdfV2Risk]
  warnings : Array[PdfV2Warning]
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2DocumentModel {
  metadata : PdfV2Metadata
  source_summary : PdfV2SourceSummary
  pages : Array[PdfV2Page]
  outlines : Array[PdfV2OutlineItem]
  destinations : Array[PdfV2Destination]
  cross_page_boundaries : Array[PdfV2CrossPageBoundary]
  risks : Array[PdfV2Risk]
  warnings : Array[PdfV2Warning]
}

///|
pub fn pdf_v2_empty_metadata() -> PdfV2Metadata {
  {
    title: None,
    author: None,
    subject: None,
    keywords: [],
    creator: None,
    producer: None,
  }
}

///|
pub fn build_pdf_v2_document_model(
  source : PdfV2SourceDocument,
  text : PdfV2TextModel,
  layout : PdfV2LayoutResult,
) -> PdfV2DocumentModel {
  let pages : Array[PdfV2Page] = []
  for i = 0; i < text.pages.length(); i = i + 1 {
    let text_page = text.pages[i]
    let source_page = find_source_page(source.pages, text_page.page_index)
    let layout_page = find_layout_page(layout.pages, text_page.page_index)
    pages.push({
      page_index: text_page.page_index,
      page_label: None,
      boxes: match source_page {
        Some(page) => page.boxes
        None => pdf_v2_default_boxes()
      },
      rotation: match source_page {
        Some(page) => page.rotation
        None => 0
      },
      user_unit: match source_page {
        Some(page) => page.user_unit
        None => None
      },
      text_blocks: text_page.blocks,
      images: [],
      vectors: [],
      annotations: [],
      forms: [],
      layout_regions: match layout_page {
        Some(page) => page.regions
        None => []
      },
      reading_order: match layout_page {
        Some(page) => page.reading_order
        None =>
          {
            page_index: text_page.page_index,
            ordered_block_ids: [],
            confidence: 0.0,
            source: PdfV2DecisionSource::Scaffold,
            reason_tags: ["missing_layout_result"],
          }
      },
      risks: match layout_page {
        Some(page) => page.risks
        None => []
      },
      warnings: text_page.warnings,
      source_refs: match source_page {
        Some(page) => page.source_refs
        None => []
      },
    })
  }
  let warnings = source.warnings + text.warnings + layout.warnings
  let risks = source.risks + text.risks + layout.risks
  {
    metadata: pdf_v2_empty_metadata(),
    source_summary: {
      core_bytes_len: source.core_bytes_len,
      page_count: pages.length(),
      warning_count: warnings.length(),
      risk_count: risks.length(),
      scanned_once: source.scanned_once,
    },
    pages,
    outlines: [],
    destinations: [],
    cross_page_boundaries: layout.cross_page_boundaries,
    risks,
    warnings,
  }
}

///|
fn find_source_page(
  pages : Array[PdfV2SourcePage],
  page_index : Int,
) -> PdfV2SourcePage? {
  for page in pages {
    if page.page_index == page_index {
      return Some(page)
    }
  }
  None
}

///|
fn find_layout_page(
  pages : Array[PdfV2LayoutPageResult],
  page_index : Int,
) -> PdfV2LayoutPageResult? {
  for page in pages {
    if page.page_index == page_index {
      return Some(page)
    }
  }
  None
}

///|
pub fn pdf_v2_empty_document_model() -> PdfV2DocumentModel {
  {
    metadata: pdf_v2_empty_metadata(),
    source_summary: {
      core_bytes_len: 0,
      page_count: 0,
      warning_count: 0,
      risk_count: 0,
      scanned_once: true,
    },
    pages: [],
    outlines: [],
    destinations: [],
    cross_page_boundaries: [],
    risks: [],
    warnings: [],
  }
}
