// Contract-only helpers for root package ownership guards.
// These helpers are intentionally not registered in `builtin_registry()`.

///|
pub fn docx_parser_contract_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::DocumentModel,
    false,
    @parser.StreamingGranularity::DocxBlock,
    true,
    false,
    false,
    false,
    false,
    true,
    true,
    true,
    false,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
  )
}

///|
pub fn docx_parser_contract() -> @parser.Parser {
  let capability = docx_parser_contract_capability()
  @parser.make_parser(
    @shared.docx_contract_parser_name(),
    @shared.docx_contract_mode(),
    capability,
    fn(
      source : @input.InputSource,
      _context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      let diagnostics = @core.diagnostics_with_input(
        @core.diagnostics_with_parser(
          @core.empty_diagnostics(),
          Some(@shared.docx_contract_parser_name()),
          Some(@parser.mode_name(@shared.docx_contract_mode())),
        ),
        Some(docx_contract_input_kind_name(source.kind)),
        Some("docx"),
      )
      diagnostics.warnings.push(
        "docx parser contract helper mirrors the DOCX product boundary without becoming the runtime parser",
      )
      diagnostics.degraded_features.push("docx_contract_helper_only")
      diagnostics.metrics.set(
        "parser_name",
        @shared.docx_contract_parser_name(),
      )
      diagnostics.metrics.set("parser_mode", "document_model")
      diagnostics.metrics.set("effective_mode", "document_model")
      diagnostics.metrics.set("detected_format", "docx")
      diagnostics.metrics.set("ir_input_kind", "document")
      diagnostics.metrics.set("event_granularity", "docx_block")
      diagnostics.metrics.set("office_document_kind", "docx")
      diagnostics.metrics.set("legacy_runtime_dependency", "none")
      diagnostics.metrics.set("legacy_convert_dependency", "none")
      diagnostics.metrics.set("legacy_fallback", "forbidden")
      diagnostics.metrics.set("runtime_exposed", "true")
      Ok(
        @parser.parse_result_with_document_capability(
          @shared.docx_contract_parser_name(),
          @shared.docx_contract_mode(),
          @core.document_with_diagnostics(
            @core.empty_document_ir(),
            diagnostics,
          ),
          diagnostics,
          capability,
        ),
      )
    },
  )
}

///|
fn docx_contract_input_kind_name(kind : @input.InputKind) -> String {
  match kind {
    @input.InputKind::Path => "path"
    @input.InputKind::Text => "text"
    @input.InputKind::Bytes => "bytes"
  }
}

///|
pub fn pptx_parser_contract_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::PresentationModel,
    false,
    @parser.StreamingGranularity::PptxSlide,
    true,
    false,
    false,
    false,
    false,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
  )
}

///|
pub fn pptx_parser_contract() -> @parser.Parser {
  let capability = pptx_parser_contract_capability()
  @parser.make_parser(
    @shared.pptx_contract_parser_name(),
    @shared.pptx_contract_mode(),
    capability,
    fn(
      source : @input.InputSource,
      _context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      let diagnostics = @core.diagnostics_with_input(
        @core.diagnostics_with_parser(
          @core.empty_diagnostics(),
          Some(@shared.pptx_contract_parser_name()),
          Some(@parser.mode_name(@shared.pptx_contract_mode())),
        ),
        Some(pptx_contract_input_kind_name(source.kind)),
        Some("pptx"),
      )
      diagnostics.warnings.push(
        "pptx parser contract helper mirrors the PPTX product boundary without becoming the runtime parser",
      )
      diagnostics.degraded_features.push("pptx_contract_helper_only")
      diagnostics.metrics.set(
        "parser_name",
        @shared.pptx_contract_parser_name(),
      )
      diagnostics.metrics.set("parser_mode", "presentation_model")
      diagnostics.metrics.set("effective_mode", "presentation_model")
      diagnostics.metrics.set("detected_format", "pptx")
      diagnostics.metrics.set("ir_input_kind", "document")
      diagnostics.metrics.set("event_granularity", "pptx_slide")
      diagnostics.metrics.set("office_document_kind", "pptx")
      diagnostics.metrics.set("legacy_runtime_dependency", "none")
      diagnostics.metrics.set("legacy_convert_dependency", "none")
      diagnostics.metrics.set("legacy_fallback", "forbidden")
      diagnostics.metrics.set("runtime_exposed", "false")
      diagnostics.metrics.set("resource_limit_hit", "false")
      diagnostics.metrics.set("pptx_slide_count", "0")
      diagnostics.metrics.set("pptx_hidden_slide_count", "0")
      diagnostics.metrics.set("pptx_shape_count", "0")
      diagnostics.metrics.set("pptx_text_box_count", "0")
      diagnostics.metrics.set("pptx_placeholder_count", "0")
      diagnostics.metrics.set("pptx_table_count", "0")
      diagnostics.metrics.set("pptx_image_count", "0")
      diagnostics.metrics.set("pptx_notes_count", "0")
      diagnostics.metrics.set("pptx_layout_count", "0")
      diagnostics.metrics.set("pptx_master_count", "0")
      diagnostics.metrics.set("pptx_theme_count", "0")
      diagnostics.metrics.set("pptx_resolved_placeholder_count", "0")
      diagnostics.metrics.set("pptx_unresolved_placeholder_count", "0")
      diagnostics.metrics.set("pptx_comment_count", "0")
      diagnostics.metrics.set("pptx_external_media_count", "0")
      diagnostics.metrics.set(
        "pptx_reading_order_strategy", "placeholder_then_geometry",
      )
      diagnostics.metrics.set("fallback_count", "0")
      diagnostics.metrics.set("warning_count", "1")
      diagnostics.metrics.set("error_count", "0")
      diagnostics.metrics.set("issue_count", "1")
      Ok(
        @parser.parse_result_with_document_capability(
          @shared.pptx_contract_parser_name(),
          @shared.pptx_contract_mode(),
          @core.document_with_diagnostics(
            @core.empty_document_ir(),
            diagnostics,
          ),
          diagnostics,
          capability,
        ),
      )
    },
  )
}

///|
fn pptx_contract_input_kind_name(kind : @input.InputKind) -> String {
  match kind {
    @input.InputKind::Path => "path"
    @input.InputKind::Text => "text"
    @input.InputKind::Bytes => "bytes"
  }
}

///|
pub fn xlsx_parser_contract_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::WorkbookModel,
    false,
    @parser.StreamingGranularity::XlsxSheet,
    true,
    false,
    false,
    false,
    false,
    true,
    true,
    true,
    false,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
  )
}

///|
pub fn xlsx_parser_contract() -> @parser.Parser {
  let capability = xlsx_parser_contract_capability()
  @parser.make_parser(
    @shared.xlsx_contract_parser_name(),
    @shared.xlsx_contract_mode(),
    capability,
    fn(
      source : @input.InputSource,
      _context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      let diagnostics = @core.diagnostics_with_input(
        @core.diagnostics_with_parser(
          @core.empty_diagnostics(),
          Some(@shared.xlsx_contract_parser_name()),
          Some(@parser.mode_name(@shared.xlsx_contract_mode())),
        ),
        Some(xlsx_contract_input_kind_name(source.kind)),
        Some("xlsx"),
      )
      diagnostics.warnings.push(
        "xlsx parser contract helper mirrors the XLSX product boundary without becoming the runtime parser",
      )
      diagnostics.degraded_features.push("xlsx_contract_helper_only")
      diagnostics.metrics.set(
        "parser_name",
        @shared.xlsx_contract_parser_name(),
      )
      diagnostics.metrics.set("parser_mode", "workbook_model")
      diagnostics.metrics.set("effective_mode", "workbook_model")
      diagnostics.metrics.set("detected_format", "xlsx")
      diagnostics.metrics.set("ir_input_kind", "document")
      diagnostics.metrics.set("event_granularity", "xlsx_sheet")
      diagnostics.metrics.set("office_document_kind", "xlsx")
      diagnostics.metrics.set("legacy_runtime_dependency", "none")
      diagnostics.metrics.set("legacy_convert_dependency", "none")
      diagnostics.metrics.set("legacy_fallback", "forbidden")
      diagnostics.metrics.set("runtime_exposed", "true")
      diagnostics.metrics.set("resource_limit_hit", "false")
      diagnostics.metrics.set("external_link_count", "0")
      diagnostics.metrics.set("xlsx_sheet_count", "0")
      diagnostics.metrics.set("xlsx_hidden_sheet_count", "0")
      diagnostics.metrics.set("xlsx_very_hidden_sheet_count", "0")
      diagnostics.metrics.set("xlsx_row_count", "0")
      diagnostics.metrics.set("xlsx_cell_count", "0")
      diagnostics.metrics.set("xlsx_non_empty_cell_count", "0")
      diagnostics.metrics.set("xlsx_merged_cell_count", "0")
      diagnostics.metrics.set("xlsx_formula_count", "0")
      diagnostics.metrics.set("xlsx_shared_formula_count", "0")
      diagnostics.metrics.set("xlsx_array_formula_count", "0")
      diagnostics.metrics.set("xlsx_shared_string_count", "0")
      diagnostics.metrics.set("xlsx_style_count", "0")
      diagnostics.metrics.set("xlsx_drawing_count", "0")
      diagnostics.metrics.set("xlsx_image_count", "0")
      diagnostics.metrics.set("fallback_count", "0")
      diagnostics.metrics.set("warning_count", "1")
      diagnostics.metrics.set("error_count", "0")
      diagnostics.metrics.set("issue_count", "1")
      Ok(
        @parser.parse_result_with_document_capability(
          @shared.xlsx_contract_parser_name(),
          @shared.xlsx_contract_mode(),
          @core.document_with_diagnostics(
            @core.empty_document_ir(),
            diagnostics,
          ),
          diagnostics,
          capability,
        ),
      )
    },
  )
}

///|
fn xlsx_contract_input_kind_name(kind : @input.InputKind) -> String {
  match kind {
    @input.InputKind::Path => "path"
    @input.InputKind::Text => "text"
    @input.InputKind::Bytes => "bytes"
  }
}
