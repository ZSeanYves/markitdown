///|
pub(all) struct PdfV2LayoutRegion {
  id : String
  kind : PdfV2LayoutRegionKind
  bbox : PdfV2Rect
  confidence : Double
  source : PdfV2DecisionSource
  member_block_ids : Array[String]
  member_object_ids : Array[String]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2ReadingOrder {
  page_index : Int
  ordered_block_ids : Array[String]
  confidence : Double
  source : PdfV2DecisionSource
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2CrossPageBoundary {
  left_page_index : Int
  right_page_index : Int
  left_block_id : String?
  right_block_id : String?
  hint : PdfV2BoundaryHint
  confidence : Double
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2LayoutOptions {
  deterministic_rules_enabled : Bool
  model_hints_enabled : Bool
}

///|
pub(all) struct PdfV2LayoutPageResult {
  page_index : Int
  regions : Array[PdfV2LayoutRegion]
  reading_order : PdfV2ReadingOrder
  risks : Array[PdfV2Risk]
}

///|
pub(all) struct PdfV2LayoutResult {
  pages : Array[PdfV2LayoutPageResult]
  cross_page_boundaries : Array[PdfV2CrossPageBoundary]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
}

///|
pub fn default_pdf_v2_layout_options() -> PdfV2LayoutOptions {
  { deterministic_rules_enabled: true, model_hints_enabled: false }
}

///|
pub fn recover_pdf_v2_layout(
  model : PdfV2TextModel,
  options : PdfV2LayoutOptions,
) -> PdfV2LayoutResult {
  let pages : Array[PdfV2LayoutPageResult] = []
  for page in model.pages {
    let block_ids : Array[String] = []
    for block in page.blocks {
      block_ids.push(block.id)
    }
    pages.push({
      page_index: page.page_index,
      regions: [],
      reading_order: {
        page_index: page.page_index,
        ordered_block_ids: block_ids,
        confidence: if options.deterministic_rules_enabled {
          1.0
        } else {
          0.0
        },
        source: PdfV2DecisionSource::Scaffold,
        reason_tags: ["scaffold_reading_order"],
      },
      risks: [],
    })
  }
  let warnings = [
    pdf_v2_scaffold_warning(
      "pdf_v2 layout recovery scaffold emits parser-owned no-op facts",
    ),
  ]
  if options.model_hints_enabled {
    warnings.push({
      kind: PdfV2WarningKind::ExternalModelUnavailable,
      severity: PdfV2Severity::Info,
      capability: None,
      message: "layout_recovery model hints requested but no runtime model artifact is wired",
      source_ref: None,
      source_refs: [],
      object_ref: None,
      page_index: None,
      reason_tags: ["layout_recovery_model_unavailable", "scaffold"],
      recoverability: PdfV2Recoverability::Recoverable,
    })
  }
  { pages, cross_page_boundaries: [], warnings, risks: model.risks }
}
