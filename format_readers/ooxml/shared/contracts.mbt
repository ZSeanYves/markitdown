///|
pub fn office_parser_modes() -> Array[@parser.ParserMode] {
  [@parser.ParserMode::PackageSinglePass]
}

///|
pub fn office_streaming_granularities() -> Array[@parser.StreamingGranularity] {
  [
    @parser.StreamingGranularity::DocxBlock,
    @parser.StreamingGranularity::PptxSlide,
    @parser.StreamingGranularity::XlsxSheet,
    @parser.StreamingGranularity::XlsxRow,
  ]
}

///|
pub fn docx_contract_parser_name() -> String {
  "docx_parser_contract"
}

///|
pub fn docx_contract_mode() -> @parser.ParserMode {
  @parser.ParserMode::PackageSinglePass
}

///|
pub fn docx_contract_granularity() -> @parser.StreamingGranularity {
  @parser.StreamingGranularity::DocxBlock
}

///|
pub fn docx_contract_ir_input_kind() -> String {
  "document"
}

///|
pub fn docx_contract_foundations() -> Array[String] {
  ["format_readers/ooxml/docx", "format_readers/ooxml/package"]
}

///|
pub fn docx_contract_guardrails() -> Array[String] {
  [
    "DOCX is restored on the current main CLI", "PackageSinglePass / IRInput::Document / docx_block",
    "format_readers/ooxml/package + format_readers/ooxml/docx foundation", "no old core",
    "no legacy convert", "no markdown emitter", "no main CLI fallback", "assets stay output-boundary only",
  ]
}

///|
pub fn pptx_contract_parser_name() -> String {
  "pptx_parser_contract"
}

///|
pub fn pptx_contract_mode() -> @parser.ParserMode {
  @parser.ParserMode::PackageSinglePass
}

///|
pub fn pptx_contract_granularity() -> @parser.StreamingGranularity {
  @parser.StreamingGranularity::PptxSlide
}

///|
pub fn pptx_contract_ir_input_kind() -> String {
  "document"
}

///|
pub fn pptx_contract_foundations() -> Array[String] {
  ["format_readers/ooxml/package", "format_readers/ooxml/pptx"]
}

///|
pub fn pptx_contract_excluded_runtime_foundations() -> Array[String] {
  ["convert/pptx", "old_core", "legacy_dispatcher", "markdown_emitter"]
}

///|
pub fn pptx_contract_guardrails() -> Array[String] {
  [
    "PPTX is restored on the current main CLI", "PackageSinglePass / IRInput::Document / pptx_slide",
    "format_readers/ooxml/package + format_readers/ooxml/pptx foundation", "no old core",
    "no legacy convert", "no markdown emitter", "no main CLI fallback", "slide order follows presentation.xml",
    "placeholder inheritance is slide -> layout -> master -> geometry inference",
    "assets stay output-boundary only", "TargetMode=External is no-fetch",
  ]
}

///|
pub fn pptx_contract_source_ref_extra_keys() -> Array[String] {
  [
    "slide_index", "slide_id", "slide_part", "layout_part", "master_part", "theme_part",
    "shape_id", "shape_name", "shape_type", "placeholder_type", "placeholder_idx",
    "reading_order_index", "notes_part", "comment_id", "part_name", "relationship_id",
    "paragraph_index", "run_index",
  ]
}

///|
pub fn pptx_contract_slide_policy() -> Array[String] {
  [
    "slide order is derived from presentation.xml and slide relationship ids", "hidden slides remain explicit semantic units with diagnostics-first visibility policy",
    "slide part resolution is package-local only", "missing slide relationships fail closed with diagnostics",
  ]
}

///|
pub fn pptx_contract_placeholder_policy() -> Array[String] {
  [
    "placeholder inheritance resolves through slide, layout, then master", "placeholder type/index stays observable through source_ref extras",
    "unresolved placeholders stay diagnosed rather than silently flattened", "geometry/name inference is last-resort only",
  ]
}

///|
pub fn pptx_contract_reading_order_policy() -> Array[String] {
  [
    "reading order uses placeholder hints before geometry heuristics", "geometry heuristics stay bounded and diagnostics-visible",
    "legacy reading-order fallback is forbidden", "reading-order strategy remains observable in diagnostics metrics",
  ]
}

///|
pub fn pptx_contract_notes_policy() -> Array[String] {
  [
    "speaker notes remain attached per slide", "comments remain metadata-first and slide-scoped",
    "missing notes/comments parts are diagnosed", "notes/comments never trigger external fetch",
  ]
}

///|
pub fn pptx_contract_relationship_policy() -> Array[String] {
  [
    "relationship target resolution is package-local by default", "TargetMode=External is no-fetch",
    "missing targets are diagnosed", "relationship traversal outside package-safe normalized boundaries is forbidden",
    "unsupported embedded/chart/media relationships remain diagnostics-first",
  ]
}

///|
pub fn pptx_contract_asset_policy() -> Array[String] {
  [
    "internal slide media stays package-local only", "materialization only happens at the CLI/output boundary",
    "parser/orchestrator file writes are forbidden", "charts smartart ole and embedded binaries remain reference-only or unsupported diagnostics",
  ]
}

///|
pub fn xlsx_contract_parser_name() -> String {
  "xlsx_parser_contract"
}

///|
pub fn xlsx_contract_mode() -> @parser.ParserMode {
  @parser.ParserMode::PackageSinglePass
}

///|
pub fn xlsx_contract_granularity() -> @parser.StreamingGranularity {
  @parser.StreamingGranularity::XlsxSheet
}

///|
pub fn xlsx_contract_large_granularity() -> @parser.StreamingGranularity {
  @parser.StreamingGranularity::XlsxRow
}

///|
pub fn xlsx_contract_ir_input_kind() -> String {
  "document"
}

///|
pub fn xlsx_contract_large_ir_input_kind() -> String {
  "block_stream"
}

///|
pub fn xlsx_contract_foundations() -> Array[String] {
  ["format_readers/ooxml/package", "format_readers/ooxml/shared"]
}

///|
pub fn xlsx_contract_excluded_runtime_foundations() -> Array[String] {
  ["convert/xlsx", "old_core"]
}

///|
pub fn xlsx_contract_guardrails() -> Array[String] {
  [
    "XLSX is restored on the current main CLI", "PackageSinglePass / IRInput::Document / xlsx_sheet",
    "future large path = BlockStreaming / BlockStream / xlsx_row", "format_readers/ooxml/shared now owns the shared XLSX semantic scaffold",
    "no old core", "no legacy convert", "no markdown emitter", "no main CLI fallback",
    "assets stay output-boundary only", "formulas are preserved and never executed",
    "external links are no-fetch",
  ]
}

///|
pub fn xlsx_contract_source_ref_extra_keys() -> Array[String] {
  [
    "sheet_name", "sheet_id", "sheet_visibility", "cell_ref", "cell_range", "row_index",
    "column_index", "formula_ref", "shared_string_index", "style_id", "merge_range",
    "relationship_id", "part_name",
  ]
}

///|
pub fn xlsx_contract_formula_policy() -> Array[String] {
  [
    "formula text is preserved", "formula evaluation is forbidden", "cached value may be used when present",
    "external formula links are not fetched", "volatile functions are not evaluated",
  ]
}

///|
pub fn xlsx_contract_sheet_policy() -> Array[String] {
  [
    "visible sheets are future first-scope input", "hidden sheets require explicit diagnostics policy",
    "very hidden sheets require explicit diagnostics policy", "large sheets are bounded and defer to future xlsx_row block streaming",
  ]
}

///|
pub fn xlsx_contract_relationship_policy() -> Array[String] {
  [
    "relationship target resolution is package-local by default", "TargetMode=External is no-fetch",
    "external links are diagnostics/metadata only", "missing targets are diagnosed",
    "relationship traversal outside package-safe normalized boundaries is forbidden",
  ]
}

///|
pub fn xlsx_contract_asset_policy() -> Array[String] {
  [
    "drawing/image relationships stay package-local only", "materialization only happens at the CLI/output boundary",
    "parser/orchestrator file writes are forbidden", "assets stay reference-only until output policy opts in",
  ]
}
