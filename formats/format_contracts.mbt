///|
pub struct ParserContractSpec {
  parser_name : String
  parser_mode : @parser.ParserMode
  streaming_granularity : @parser.StreamingGranularity
  large_route_granularity : @parser.StreamingGranularity?
  ir_input_kind : String
  large_route_ir_input_kind : String?
  required_metrics : Array[String]
  required_source_ref_extra_keys : Array[String]
  guardrails : Array[String]
  policies : Array[String]
  foundations : Array[String]
  excluded_legacy_foundations : Array[String]
}

///|
pub fn parser_contract_spec_matches_parser(
  spec : ParserContractSpec,
  parser : @parser.Parser,
) -> Bool {
  if spec.parser_name != parser.name {
    return false
  }
  if spec.parser_mode != parser.mode {
    return false
  }
  let actual = parser.capability.streaming_granularity
  if actual == spec.streaming_granularity {
    return true
  }
  match spec.large_route_granularity {
    Some(value) => actual == value
    None => false
  }
}

///|
pub fn make_parser_contract_spec(
  parser_name : String,
  parser_mode : @parser.ParserMode,
  streaming_granularity : @parser.StreamingGranularity,
  ir_input_kind : String,
  required_metrics : Array[String],
  required_source_ref_extra_keys : Array[String],
  guardrails : Array[String],
  policies : Array[String],
  foundations : Array[String],
  excluded_legacy_foundations : Array[String],
  large_route_granularity? : @parser.StreamingGranularity? = None,
  large_route_ir_input_kind? : String? = None,
) -> ParserContractSpec {
  {
    parser_name,
    parser_mode,
    streaming_granularity,
    large_route_granularity,
    ir_input_kind,
    large_route_ir_input_kind,
    required_metrics,
    required_source_ref_extra_keys,
    guardrails,
    policies,
    foundations,
    excluded_legacy_foundations,
  }
}

///|
pub fn office_parser_contract_specs() -> Array[ParserContractSpec] {
  [
    docx_parser_contract_spec(),
    pptx_parser_contract_spec(),
    xlsx_parser_contract_spec(),
  ]
}

///|
pub fn docx_parser_contract_spec() -> ParserContractSpec {
  make_parser_contract_spec(
    @shared.docx_contract_parser_name(),
    @shared.docx_contract_mode(),
    @shared.docx_contract_granularity(),
    "document",
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "event_granularity", "event_semantics", "office_document_kind", "block_count",
      "asset_count", "ooxml_part_count", "relationship_count", "content_type_count",
    ],
    [
      "part_name", "paragraph_index", "run_index", "relationship_id", "container_path",
      "entry_path", "inner_path",
    ],
    @shared.docx_contract_guardrails(),
    [],
    @shared.docx_contract_foundations(),
    ["old_core", "legacy_convert", "markdown_emitter", "main_cli_fallback"],
  )
}

///|
pub fn pptx_parser_contract_spec() -> ParserContractSpec {
  make_parser_contract_spec(
    @shared.pptx_contract_parser_name(),
    @shared.pptx_contract_mode(),
    @shared.pptx_contract_granularity(),
    "document",
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "event_granularity", "event_semantics", "office_document_kind", "block_count",
      "asset_count", "pptx_slide_count", "pptx_hidden_slide_count", "pptx_shape_count",
      "pptx_notes_count", "pptx_comment_count", "pptx_reading_order_strategy",
    ],
    @shared.pptx_contract_source_ref_extra_keys(),
    @shared.pptx_contract_guardrails(),
    [
      ..@shared.pptx_contract_slide_policy(),
      ..@shared.pptx_contract_placeholder_policy(),
      ..@shared.pptx_contract_reading_order_policy(),
      ..@shared.pptx_contract_notes_policy(),
      ..@shared.pptx_contract_relationship_policy(),
      ..@shared.pptx_contract_asset_policy(),
    ],
    @shared.pptx_contract_foundations(),
    @shared.pptx_contract_excluded_runtime_foundations(),
  )
}

///|
pub fn xlsx_parser_contract_spec() -> ParserContractSpec {
  make_parser_contract_spec(
    @shared.xlsx_contract_parser_name(),
    @shared.xlsx_contract_mode(),
    @shared.xlsx_contract_granularity(),
    "document",
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "event_granularity", "event_semantics", "office_document_kind", "block_count",
      "asset_count", "xlsx_sheet_count", "xlsx_hidden_sheet_count", "xlsx_row_count",
      "xlsx_cell_count", "xlsx_formula_count", "xlsx_workbook_part",
    ],
    @shared.xlsx_contract_source_ref_extra_keys(),
    @shared.xlsx_contract_guardrails(),
    [
      ..@shared.xlsx_contract_formula_policy(),
      ..@shared.xlsx_contract_sheet_policy(),
      ..@shared.xlsx_contract_relationship_policy(),
      ..@shared.xlsx_contract_asset_policy(),
    ],
    @shared.xlsx_contract_foundations(),
    @shared.xlsx_contract_excluded_runtime_foundations(),
    large_route_granularity=Some(@shared.xlsx_contract_large_granularity()),
    large_route_ir_input_kind=Some(@shared.xlsx_contract_large_ir_input_kind()),
  )
}
