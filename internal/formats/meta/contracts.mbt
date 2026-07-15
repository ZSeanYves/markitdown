///|
pub struct ParserContractSpec {
  parser_name : String
  parser_mode : @parser.ParserMode
  streaming_granularity : @parser.StreamingGranularity
  large_route_granularity : @parser.StreamingGranularity?
  ir_input_kind : String
  large_route_ir_input_kind : String?
  required_metrics : Array[String]
  required_source_ref_fields : Array[String]
  required_source_ref_extra_keys : Array[String]
  guardrails : Array[String]
  policies : Array[String]
  foundations : Array[String]
  excluded_legacy_foundations : Array[String]
}

///|
fn profile_base_contract_spec(
  format : @input.DetectedFormat,
  parser_name : String,
  required_metrics : Array[String],
  required_source_ref_fields : Array[String],
  required_source_ref_extra_keys : Array[String],
  guardrails : Array[String],
  policies : Array[String],
  foundations : Array[String],
  excluded_legacy_foundations : Array[String],
) -> ParserContractSpec {
  let profile = format_route_profile(format)
  let canonical_granularity = match profile.canonical_parser_mode {
    DomAstModel => @parser.StreamingGranularity::None
    _ => profile.capability_granularity
  }
  make_parser_contract_spec(
    parser_name,
    profile.canonical_parser_mode,
    canonical_granularity,
    profile.canonical_ir_input_kind,
    required_metrics,
    required_source_ref_fields,
    required_source_ref_extra_keys,
    guardrails,
    policies,
    foundations,
    excluded_legacy_foundations,
    large_route_granularity=profile.large_route_granularity,
    large_route_ir_input_kind=profile.large_route_ir_input_kind,
  )
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
  required_source_ref_fields : Array[String],
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
    required_source_ref_fields,
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
pub fn product_parser_contract_specs() -> Array[ParserContractSpec] {
  [
    txt_parser_contract_spec(),
    csv_parser_contract_spec(),
    tsv_parser_contract_spec(),
    json_parser_contract_spec(),
    jsonl_parser_contract_spec(),
    ndjson_parser_contract_spec(),
    xml_parser_contract_spec(),
    yaml_parser_contract_spec(),
    toml_parser_contract_spec(),
    markdown_parser_contract_spec(),
    html_parser_contract_spec(),
    ipynb_parser_contract_spec(),
    srt_parser_contract_spec(),
    vtt_parser_contract_spec(),
    tex_parser_contract_spec(),
    rst_parser_contract_spec(),
    asciidoc_parser_contract_spec(),
    eml_parser_contract_spec(),
    zip_parser_contract_spec(),
    epub_parser_contract_spec(),
    odt_parser_contract_spec(),
    ods_parser_contract_spec(),
    odp_parser_contract_spec(),
    docx_parser_contract_spec(),
    pptx_parser_contract_spec(),
    xlsx_parser_contract_spec(),
    pdf_native_parser_contract_spec(),
    pdf_ocr_parser_contract_spec(),
    audio_parser_contract_spec(),
    image_ocr_parser_contract_spec(),
  ]
}

///|
pub fn product_parser_contract_spec_by_format(
  format : @input.DetectedFormat,
) -> ParserContractSpec? {
  match format {
    Txt => Some(txt_parser_contract_spec())
    Csv => Some(csv_parser_contract_spec())
    Tsv => Some(tsv_parser_contract_spec())
    Json => Some(json_parser_contract_spec())
    Jsonl => Some(jsonl_parser_contract_spec())
    Ndjson => Some(ndjson_parser_contract_spec())
    Xml => Some(xml_parser_contract_spec())
    Yaml => Some(yaml_parser_contract_spec())
    Toml => Some(toml_parser_contract_spec())
    Markdown => Some(markdown_parser_contract_spec())
    Html => Some(html_parser_contract_spec())
    Ipynb => Some(ipynb_parser_contract_spec())
    Srt => Some(srt_parser_contract_spec())
    Vtt => Some(vtt_parser_contract_spec())
    Tex => Some(tex_parser_contract_spec())
    Rst => Some(rst_parser_contract_spec())
    Asciidoc => Some(asciidoc_parser_contract_spec())
    Eml => Some(eml_parser_contract_spec())
    Zip => Some(zip_parser_contract_spec())
    Epub => Some(epub_parser_contract_spec())
    Odt => Some(odt_parser_contract_spec())
    Ods => Some(ods_parser_contract_spec())
    Odp => Some(odp_parser_contract_spec())
    Docx => Some(docx_parser_contract_spec())
    Pptx => Some(pptx_parser_contract_spec())
    Xlsx => Some(xlsx_parser_contract_spec())
    Pdf => Some(pdf_native_parser_contract_spec())
    Audio(_) => Some(audio_parser_contract_spec())
    Image(_) => Some(image_ocr_parser_contract_spec())
    Unknown => None
  }
}

///|
pub fn contract_profile_matches_spec(
  format : @input.DetectedFormat,
  spec : ParserContractSpec,
) -> Bool {
  let profile = format_route_profile(format)
  let canonical_match = spec.parser_mode == profile.canonical_parser_mode
  let large_route_match = match profile.large_route_parser_mode {
    Some(mode) => spec.parser_mode == mode
    None => false
  }
  if !canonical_match && !large_route_match {
    return false
  }
  if canonical_match {
    if spec.ir_input_kind != profile.canonical_ir_input_kind {
      return false
    }
    if spec.streaming_granularity != profile.capability_granularity {
      match spec.large_route_granularity {
        Some(value) if value == profile.capability_granularity => ()
        _ => return false
      }
    }
  } else {
    let expected_large_ir_input_kind = profile.large_route_ir_input_kind.unwrap_or(
      profile.canonical_ir_input_kind,
    )
    if spec.ir_input_kind != expected_large_ir_input_kind {
      return false
    }
    let expected_large_granularity = profile.large_route_granularity.unwrap_or(
      profile.capability_granularity,
    )
    if spec.streaming_granularity != expected_large_granularity {
      return false
    }
  }
  match (spec.large_route_granularity, profile.large_route_granularity) {
    (None, None) => ()
    (Some(left), Some(right)) if left == right => ()
    _ => return false
  }
  match (spec.large_route_ir_input_kind, profile.large_route_ir_input_kind) {
    (None, None) => ()
    (Some(left), Some(right)) if left == right => ()
    _ => return false
  }
  true
}

///|
pub fn line_event_parser_contract_spec(
  parser_name : String,
  format : @input.DetectedFormat,
  foundations : Array[String],
) -> ParserContractSpec {
  profile_base_contract_spec(
    format,
    parser_name,
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "builder_input_kind", "event_granularity", "event_semantics",
    ],
    ["line_start", "line_end"],
    [],
    [
      "streaming-event parser stays on the canonical product path", "renderer consumes event stream without markdown as an intermediate",
    ],
    [],
    foundations,
    @oxshared.parser_contract_required_foundation_exclusions(),
  )
}

///|
pub fn row_event_parser_contract_spec(
  parser_name : String,
  format : @input.DetectedFormat,
  foundations : Array[String],
) -> ParserContractSpec {
  profile_base_contract_spec(
    format,
    parser_name,
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "builder_input_kind", "event_granularity", "event_semantics", "table_count",
    ],
    ["line_start", "line_end", "cell_range"],
    [],
    [
      "row streaming stays canonical", "table rendering remains shared-renderer owned",
    ],
    [],
    foundations,
    @oxshared.parser_contract_required_foundation_exclusions(),
  )
}

///|
pub fn record_event_parser_contract_spec(
  parser_name : String,
  format : @input.DetectedFormat,
  foundations : Array[String],
  required_source_ref_fields : Array[String],
  required_source_ref_extra_keys : Array[String],
  required_metrics : Array[String],
  policies? : Array[String] = [],
) -> ParserContractSpec {
  profile_base_contract_spec(
    format,
    parser_name,
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "builder_input_kind", "event_granularity", "event_semantics", ..required_metrics,
    ],
    ["line_start", "line_end", ..required_source_ref_fields],
    required_source_ref_extra_keys,
    [
      "record streaming stays canonical", "event stream remains the only public parse shape",
    ],
    policies,
    foundations,
    @oxshared.parser_contract_required_foundation_exclusions(),
  )
}

///|
pub fn dom_ast_parser_contract_spec(
  parser_name : String,
  format : @input.DetectedFormat,
  foundations : Array[String],
  required_metrics : Array[String],
  required_source_ref_fields : Array[String],
  required_source_ref_extra_keys? : Array[String] = [],
  policies? : Array[String] = [],
) -> ParserContractSpec {
  profile_base_contract_spec(
    format,
    parser_name,
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "builder_input_kind", "event_granularity", "event_semantics", ..required_metrics,
    ],
    required_source_ref_fields,
    required_source_ref_extra_keys,
    [
      "dom-ast parser stays on the canonical product path", "renderer stays shared and source-format agnostic",
    ],
    policies,
    foundations,
    @oxshared.parser_contract_required_foundation_exclusions(),
  )
}

///|
pub fn block_stream_parser_contract_spec(
  parser_name : String,
  format : @input.DetectedFormat,
  foundations : Array[String],
  required_metrics : Array[String],
  required_source_ref_fields : Array[String],
  required_source_ref_extra_keys? : Array[String] = [],
  policies? : Array[String] = [],
) -> ParserContractSpec {
  profile_base_contract_spec(
    format,
    parser_name,
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "builder_input_kind", "event_granularity", "event_semantics", ..required_metrics,
    ],
    required_source_ref_fields,
    required_source_ref_extra_keys,
    [
      "block-stream parser stays on the canonical product path", "parse result public shape remains block_stream",
    ],
    policies,
    foundations,
    @oxshared.parser_contract_required_foundation_exclusions(),
  )
}

///|
pub fn package_with_block_large_route_contract_spec(
  parser_name : String,
  format : @input.DetectedFormat,
  foundations : Array[String],
  required_metrics : Array[String],
  required_source_ref_fields : Array[String],
  required_source_ref_extra_keys? : Array[String] = [],
  policies? : Array[String] = [],
) -> ParserContractSpec {
  profile_base_contract_spec(
    format,
    parser_name,
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "builder_input_kind", "event_granularity", "event_semantics", ..required_metrics,
    ],
    required_source_ref_fields,
    required_source_ref_extra_keys,
    [
      "package parser stays on the canonical product path", "large or explicit stream route may lower through block stream without changing parser family",
    ],
    policies,
    foundations,
    @oxshared.parser_contract_required_foundation_exclusions(),
  )
}

///|
pub fn container_parser_contract_spec(
  parser_name : String,
  format : @input.DetectedFormat,
  foundations : Array[String],
  required_metrics : Array[String],
  source_ref_extra_keys : Array[String],
  policies? : Array[String] = [],
) -> ParserContractSpec {
  profile_base_contract_spec(
    format,
    parser_name,
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "builder_input_kind", "event_granularity", "event_semantics", ..required_metrics,
    ],
    ["container_path", "entry_path", "entry_index", "entry_format"],
    source_ref_extra_keys,
    [
      "container parsing stays on the canonical product path", "container dispatch must go through the root registry",
    ],
    policies,
    foundations,
    @oxshared.parser_contract_required_foundation_exclusions(),
  )
}

///|
pub fn page_single_pass_parser_contract_spec(
  parser_name : String,
  format : @input.DetectedFormat,
  foundations : Array[String],
  required_metrics : Array[String],
  source_ref_extra_keys : Array[String],
  policies? : Array[String] = [],
) -> ParserContractSpec {
  profile_base_contract_spec(
    format,
    parser_name,
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "builder_input_kind", "event_granularity", "event_semantics", ..required_metrics,
    ],
    ["page"],
    source_ref_extra_keys,
    [
      "page-single-pass stays canonical for native text pdf-like documents", "layout/ocr route stays explicit and diagnostics-visible",
    ],
    policies,
    foundations,
    @oxshared.parser_contract_required_foundation_exclusions(),
  )
}

///|
pub fn docx_parser_contract_spec() -> ParserContractSpec {
  make_parser_contract_spec(
    @oxshared.docx_contract_parser_name(),
    @oxshared.docx_contract_mode(),
    @oxshared.docx_contract_granularity(),
    "document",
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "event_granularity", "event_semantics", "office_document_kind", "block_count",
      "asset_count", "ooxml_part_count", "relationship_count", "content_type_count",
    ],
    [
      "container_path", "entry_path", "entry_index", "entry_format", "inner_path",
      "relationship_id",
    ],
    [
      "part_name", "paragraph_index", "run_index", "relationship_id", "container_path",
      "entry_path", "inner_path",
    ],
    @oxshared.docx_contract_guardrails(),
    [],
    @oxshared.docx_contract_foundations(),
    ["old_core", "legacy_convert", "markdown_emitter", "main_cli_fallback"],
  )
}

///|
pub fn pptx_parser_contract_spec() -> ParserContractSpec {
  make_parser_contract_spec(
    @oxshared.pptx_contract_parser_name(),
    @oxshared.pptx_contract_mode(),
    @oxshared.pptx_contract_granularity(),
    "document",
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "event_granularity", "event_semantics", "office_document_kind", "block_count",
      "asset_count", "pptx_slide_count", "pptx_hidden_slide_count", "pptx_shape_count",
      "pptx_notes_count", "pptx_comment_count", "pptx_reading_order_strategy",
    ],
    [
      "container_path", "entry_path", "entry_index", "entry_format", "inner_path",
      "slide", "shape_id", "relationship_id",
    ],
    @oxshared.pptx_contract_source_ref_extra_keys(),
    @oxshared.pptx_contract_guardrails(),
    [
      ..@oxshared.pptx_contract_slide_policy(),
      ..@oxshared.pptx_contract_placeholder_policy(),
      ..@oxshared.pptx_contract_reading_order_policy(),
      ..@oxshared.pptx_contract_notes_policy(),
      ..@oxshared.pptx_contract_relationship_policy(),
      ..@oxshared.pptx_contract_asset_policy(),
    ],
    @oxshared.pptx_contract_foundations(),
    @oxshared.pptx_contract_excluded_runtime_foundations(),
  )
}

///|
pub fn xlsx_parser_contract_spec() -> ParserContractSpec {
  make_parser_contract_spec(
    @oxshared.xlsx_contract_parser_name(),
    @oxshared.xlsx_contract_mode(),
    @oxshared.xlsx_contract_granularity(),
    "document",
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "event_granularity", "event_semantics", "office_document_kind", "block_count",
      "asset_count", "xlsx_sheet_count", "xlsx_hidden_sheet_count", "xlsx_row_count",
      "xlsx_cell_count", "xlsx_formula_count", "xlsx_workbook_part",
    ],
    [
      "container_path", "entry_path", "entry_index", "entry_format", "inner_path",
      "sheet", "cell_range", "relationship_id",
    ],
    @oxshared.xlsx_contract_source_ref_extra_keys(),
    @oxshared.xlsx_contract_guardrails(),
    [
      ..@oxshared.xlsx_contract_formula_policy(),
      ..@oxshared.xlsx_contract_sheet_policy(),
      ..@oxshared.xlsx_contract_relationship_policy(),
      ..@oxshared.xlsx_contract_asset_policy(),
    ],
    @oxshared.xlsx_contract_foundations(),
    @oxshared.xlsx_contract_excluded_runtime_foundations(),
    large_route_granularity=Some(@oxshared.xlsx_contract_large_granularity()),
    large_route_ir_input_kind=Some(
      @oxshared.xlsx_contract_large_ir_input_kind(),
    ),
  )
}

///|
pub fn txt_parser_contract_spec() -> ParserContractSpec {
  line_event_parser_contract_spec("txt_parser", Txt, ["format_readers/text"])
}

///|
pub fn csv_parser_contract_spec() -> ParserContractSpec {
  row_event_parser_contract_spec("csv_parser", Csv, [
    "format_readers/delimited/csv", "format_readers/delimited/shared",
  ])
}

///|
pub fn tsv_parser_contract_spec() -> ParserContractSpec {
  row_event_parser_contract_spec("tsv_parser", Tsv, [
    "format_readers/delimited/tsv", "format_readers/delimited/shared",
  ])
}

///|
pub fn json_parser_contract_spec() -> ParserContractSpec {
  dom_ast_parser_contract_spec(
    "json_parser",
    Json,
    ["format_readers/json"],
    [
      "root_kind", "table_count", "image_count", "asset_count", "block_count", "syntax_error_count",
    ],
    ["json_pointer"],
    required_source_ref_extra_keys=[],
    policies=[
      "small and balanced json stays dom-ast-first", "large or explicit stream json may expose json_structure event stream without changing parser family",
    ],
  )
}

///|
pub fn jsonl_parser_contract_spec() -> ParserContractSpec {
  record_event_parser_contract_spec(
    "jsonl_parser",
    Jsonl,
    ["format_readers/json"],
    ["json_pointer"],
    [],
    [
      "record_count", "invalid_record_count", "block_count", "event_count", "record_count_emitted",
    ],
  )
}

///|
pub fn ndjson_parser_contract_spec() -> ParserContractSpec {
  record_event_parser_contract_spec(
    "ndjson_parser",
    Ndjson,
    ["format_readers/json"],
    ["json_pointer"],
    [],
    [
      "record_count", "invalid_record_count", "block_count", "event_count", "record_count_emitted",
    ],
  )
}

///|
pub fn xml_parser_contract_spec() -> ParserContractSpec {
  dom_ast_parser_contract_spec(
    "xml_parser",
    Xml,
    ["format_readers/xml"],
    [
      "element_count", "attribute_count", "table_count", "image_count", "asset_count",
      "validation_issue_count", "warning_count", "error_count", "block_count", "syntax_error_count",
    ],
    ["line_start", "line_end"],
    policies=[
      "xml canonical route is dom-ast-model", "large or explicit stream xml may expose xml_structure event stream without changing parser family",
    ],
  )
}

///|
pub fn yaml_parser_contract_spec() -> ParserContractSpec {
  dom_ast_parser_contract_spec(
    "yaml_parser",
    Yaml,
    ["format_readers/yaml"],
    [
      "resource_limit_hit", "dom_limit_reached", "warning_count", "degraded_feature_count",
      "fallback_count",
    ],
    ["yaml_path", "line_start", "line_end"],
    required_source_ref_extra_keys=[],
    policies=[
      "yaml canonical route is dom-ast-model", "large or explicit stream yaml may expose yaml_structure event stream without changing parser family",
    ],
  )
}

///|
pub fn toml_parser_contract_spec() -> ParserContractSpec {
  dom_ast_parser_contract_spec(
    "toml_parser",
    Toml,
    ["format_readers/toml"],
    [
      "root_kind", "table_count", "scalar_count", "array_count", "table_like_count",
      "max_depth_observed", "warning_count", "degraded_feature_count", "fallback_count",
      "block_count",
    ],
    ["line_start", "line_end"],
    required_source_ref_extra_keys=["toml_path"],
    policies=[
      "toml stays dom-ast-model only", "toml comments are not editor-roundtrip guaranteed",
    ],
  )
}

///|
pub fn markdown_parser_contract_spec() -> ParserContractSpec {
  make_parser_contract_spec(
    "markdown_parser",
    DomAstModel,
    MarkdownBlock,
    "document",
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "builder_input_kind", "event_granularity", "event_semantics", "block_count",
      "paragraph_count", "list_count", "table_count", "link_count", "image_count",
      "raw_html_count", "asset_count", "heading_count", "warning_count", "error_count",
    ],
    ["markdown_path", "line_start", "line_end"],
    [],
    [
      "dom-ast parser stays on the canonical product path", "renderer stays shared and source-format agnostic",
    ],
    [
      "markdown canonical route is dom-ast-model with block-inventory diagnostics",
      "large or explicit stream markdown lowers through block streaming inside the same parser family",
    ],
    ["format_readers/markdown"],
    @oxshared.parser_contract_required_foundation_exclusions(),
    large_route_granularity=Some(MarkdownBlock),
    large_route_ir_input_kind=Some("block_stream"),
  )
}

///|
pub fn html_parser_contract_spec() -> ParserContractSpec {
  dom_ast_parser_contract_spec(
    "html_parser",
    Html,
    ["format_readers/html"],
    [
      "block_count", "asset_count", "char_count", "scope_source", "selected_content_root",
      "readability_mode", "noise_repeated_boilerplate_count", "boilerplate_skipped_block_count",
      "warning_count", "degraded_feature_count", "fallback_count",
    ],
    ["html_path", "line_start", "line_end"],
    required_source_ref_extra_keys=[],
    policies=[
      "html canonical route is dom-ast-model with readability-hybrid lowering", "large or explicit stream html lowers through html token structure block streaming",
    ],
  )
}

///|
pub fn ipynb_parser_contract_spec() -> ParserContractSpec {
  dom_ast_parser_contract_spec(
    "ipynb_parser",
    Ipynb,
    ["format_readers/ipynb", "format_readers/json"],
    [
      "nbformat", "nbformat_minor", "cell_count", "markdown_cell_count", "code_cell_count",
      "raw_cell_count", "output_count", "stream_output_count", "display_data_count",
      "execute_result_count", "error_output_count", "attachment_count", "asset_count",
      "block_count", "max_cell_source_chars", "max_output_text_chars", "warning_count",
      "degraded_feature_count", "fallback_count",
    ],
    ["json_pointer"],
    required_source_ref_extra_keys=["ipynb_cell_index", "ipynb_cell_kind"],
    policies=[
      "ipynb is notebook-typed, never downgraded to plain unordered json semantics",
      "large or explicit stream ipynb lowers through notebook cell/output-group block streaming",
    ],
  )
}

///|
pub fn srt_parser_contract_spec() -> ParserContractSpec {
  make_parser_contract_spec(
    "srt_parser",
    StreamingEvent,
    Record,
    "event_stream",
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "builder_input_kind", "event_granularity", "event_semantics", "cue_count",
      "note_count", "style_count", "region_count", "multiline_cue_count", "line_count",
      "char_count", "block_count", "event_count", "warning_count", "fallback_count",
    ],
    ["line_start", "line_end", "time_start", "time_end"],
    ["subtitle_cue_index"],
    [
      "subtitle cue stream stays canonical", "time range source refs are first-class fields rather than extra metadata",
    ],
    [],
    ["format_readers/subtitles/srt", "format_readers/subtitles/shared"],
    @oxshared.parser_contract_required_foundation_exclusions(),
  )
}

///|
pub fn vtt_parser_contract_spec() -> ParserContractSpec {
  make_parser_contract_spec(
    "vtt_parser",
    StreamingEvent,
    Record,
    "event_stream",
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "builder_input_kind", "event_granularity", "event_semantics", "cue_count",
      "note_count", "style_count", "region_count", "multiline_cue_count", "line_count",
      "char_count", "block_count", "event_count", "warning_count", "fallback_count",
    ],
    ["line_start", "line_end", "time_start", "time_end"],
    ["subtitle_cue_index"],
    [
      "subtitle cue stream stays canonical", "time range source refs are first-class fields rather than extra metadata",
    ],
    [],
    ["format_readers/subtitles/vtt", "format_readers/subtitles/shared"],
    @oxshared.parser_contract_required_foundation_exclusions(),
  )
}

///|
pub fn tex_parser_contract_spec() -> ParserContractSpec {
  dom_ast_parser_contract_spec(
    "tex_parser",
    Tex,
    ["format_readers/text_markup/tex", "format_readers/text_markup/shared"],
    [
      "block_count", "heading_count", "code_count", "table_count", "raw_count", "line_count",
      "char_count", "asset_count", "warning_count", "degraded_feature_count", "fallback_count",
    ],
    ["line_start", "line_end"],
    policies=[
      "tex uses typed semantic inventory rather than full editor ast", "include and macro boundaries are diagnosed but not executed",
    ],
  )
}

///|
pub fn rst_parser_contract_spec() -> ParserContractSpec {
  dom_ast_parser_contract_spec(
    "rst_parser",
    Rst,
    ["format_readers/text_markup/rst", "format_readers/text_markup/shared"],
    [
      "block_count", "heading_count", "code_count", "table_count", "raw_count", "line_count",
      "char_count", "asset_count", "warning_count", "degraded_feature_count", "fallback_count",
    ],
    ["line_start", "line_end"],
    policies=[
      "rst uses typed semantic inventory rather than full editor ast", "directive and include boundaries are diagnosed but not executed",
    ],
  )
}

///|
pub fn asciidoc_parser_contract_spec() -> ParserContractSpec {
  dom_ast_parser_contract_spec(
    "asciidoc_parser",
    Asciidoc,
    ["format_readers/text_markup/asciidoc", "format_readers/text_markup/shared"],
    [
      "block_count", "heading_count", "code_count", "table_count", "raw_count", "line_count",
      "char_count", "asset_count", "warning_count", "degraded_feature_count", "fallback_count",
    ],
    ["line_start", "line_end"],
    policies=[
      "asciidoc uses typed semantic inventory rather than full editor ast", "include and attribute-heavy directives are diagnosed but not executed",
    ],
  )
}

///|
pub fn eml_parser_contract_spec() -> ParserContractSpec {
  block_stream_parser_contract_spec(
    "eml_parser",
    Eml,
    ["format_readers/eml"],
    [
      "part_count", "attachment_count", "inline_image_count", "nested_message_count",
      "max_depth_observed", "max_part_chars", "asset_count", "block_count", "warning_count",
      "degraded_feature_count", "fallback_count",
    ],
    [],
    required_source_ref_extra_keys=["eml_json_pointer", "eml_mime_type"],
    policies=[
      "eml canonical route is block-streaming over mime parts", "typed attachment recursion stays registry-owned and budget-guarded",
    ],
  )
}

///|
pub fn zip_parser_contract_spec() -> ParserContractSpec {
  container_parser_contract_spec(
    "zip_container_parser",
    Zip,
    ["format_readers/zip", "container"],
    [
      "manifest_seen", "resource_limit_hit", "container_entry_count", "selected_entry_count",
      "skipped_entry_count", "unsupported_entry_count", "asset_count", "total_uncompressed_bytes",
      "max_compression_ratio_observed", "path_traversal_count", "unsupported_compression_count",
    ],
    [],
    policies=@container.container_dispatch_guardrails(),
  )
}

///|
pub fn epub_parser_contract_spec() -> ParserContractSpec {
  make_parser_contract_spec(
    "epub_parser",
    PackageSinglePass,
    EpubSpineItem,
    "block_stream",
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "builder_input_kind", "event_granularity", "event_semantics", "manifest_seen",
      "resource_limit_hit", "nav_seen", "ncx_seen", "cover_candidate_seen", "missing_manifest_item_count",
      "missing_spine_item_count", "external_resource_count", "spine_item_count",
      "asset_count",
    ],
    ["container_path", "entry_path", "entry_index", "entry_format"],
    [],
    [
      "package parser stays on the canonical product path", "explicit stream epub switches to container-recursive archive-entry traversal without changing the root format contract",
    ],
    [
      "epub canonical route is package-single-pass by spine order", "explicit stream epub uses container-recursive path with archive-entry granularity",
    ],
    ["format_readers/epub", "format_readers/html", "container"],
    @oxshared.parser_contract_required_foundation_exclusions(),
    large_route_granularity=Some(ArchiveEntry),
    large_route_ir_input_kind=Some("block_stream"),
  )
}

///|
pub fn odt_parser_contract_spec() -> ParserContractSpec {
  package_with_block_large_route_contract_spec(
    "odt_parser",
    Odt,
    ["format_readers/odf/odt", "format_readers/odf/shared"],
    [
      "office_document_kind", "format_family", "resource_limit_hit", "syntax_error_count",
      "warning_count", "degraded_feature_count", "fallback_count", "asset_count",
      "table_count", "image_count", "heading_count", "paragraph_count", "list_item_count",
      "code_block_count", "raw_block_count", "package_mimetype", "content_path",
      "archive_bytes", "block_count",
    ],
    ["container_path", "entry_path", "entry_format", "line_start", "line_end"],
    required_source_ref_extra_keys=[],
    policies=[
      "odt canonical route is package-single-pass", "explicit stream or large odt lowers as block stream without changing odf foundation family",
    ],
  )
}

///|
pub fn ods_parser_contract_spec() -> ParserContractSpec {
  package_with_block_large_route_contract_spec(
    "ods_parser",
    Ods,
    ["format_readers/odf/ods", "format_readers/odf/shared"],
    [
      "office_document_kind", "format_family", "resource_limit_hit", "syntax_error_count",
      "warning_count", "degraded_feature_count", "fallback_count", "asset_count",
      "sheet_count", "visible_sheet_count", "hidden_sheet_count", "row_count", "cell_count",
      "max_sheet_rows", "max_sheet_cols", "package_mimetype", "content_path", "archive_bytes",
      "block_count",
    ],
    ["container_path", "entry_path", "entry_format", "sheet"],
    required_source_ref_extra_keys=[],
    policies=[
      "ods canonical route is package-single-pass", "explicit stream or large ods lowers as row block stream without changing odf foundation family",
    ],
  )
}

///|
pub fn odp_parser_contract_spec() -> ParserContractSpec {
  package_with_block_large_route_contract_spec(
    "odp_parser",
    Odp,
    ["format_readers/odf/odp", "format_readers/odf/shared"],
    [
      "office_document_kind", "format_family", "resource_limit_hit", "syntax_error_count",
      "warning_count", "degraded_feature_count", "fallback_count", "asset_count",
      "slide_count", "heading_count", "paragraph_count", "list_item_count", "table_count",
      "image_count", "notes_count", "raw_block_count", "package_mimetype", "content_path",
      "archive_bytes", "block_count",
    ],
    ["container_path", "entry_path", "entry_format", "slide"],
    required_source_ref_extra_keys=[],
    policies=[
      "odp canonical route is package-single-pass", "explicit stream or large odp lowers as slide block stream without changing odf foundation family",
    ],
  )
}

///|
pub fn pdf_native_parser_contract_spec() -> ParserContractSpec {
  page_single_pass_parser_contract_spec(
    "pdf_native_parser",
    Pdf,
    ["formats/pdf/native"],
    [
      "page_count", "table_count", "image_count", "asset_count", "pdf_native_backend",
      "pdf_native_text_baseline", "pdf_header_footer_removed_count", "pdf_table_reconstruction_table_count",
      "warning_count", "error_count", "fallback_count",
    ],
    [],
    policies=[
      "pdf native route is page-single-pass and text-first", "ocr and accurate layout stay explicit alternate routes",
    ],
  )
}

///|
pub fn pdf_ocr_parser_contract_spec() -> ParserContractSpec {
  make_parser_contract_spec(
    "pdf_accurate_layout_parser",
    LayoutTwoStage,
    Page,
    "document",
    [
      "page_count", "table_count", "image_count", "asset_count", "pdf_native_backend",
      "pdf_native_text_baseline", "pdf_ocr_used", "ocr_provider_status", "pdf_page_route_summary",
      "pdf_raster_backend", "warning_count", "error_count", "fallback_count",
    ],
    ["page"],
    [],
    [
      "accurate pdf route reuses native document facts and only overlays ocr where needed",
      "productized uri links and scoped single-page tables stay on the shared document pipeline",
    ],
    [
      "accurate pdf route is the explicit layout-two-stage alternate route", "born-digital accurate output must be a semantic superset of balanced native output",
    ],
    ["formats/pdf/native", "formats/ocr"],
    @oxshared.parser_contract_required_foundation_exclusions(),
  )
}

///|
pub fn image_ocr_parser_contract_spec() -> ParserContractSpec {
  make_parser_contract_spec(
    "image_ocr_parser",
    LayoutTwoStage,
    Page,
    "document",
    [
      "parser_name", "parser_mode", "detected_format", "ir_input_kind", "ocr_provider_wired",
      "ocr_provider_status", "provider_invoked", "block_count", "image_count", "asset_count",
    ],
    ["page", "bbox"],
    [],
    [
      "image ocr remains explicit and diagnostics-first", "ocr runtime execution is provider-owned and not implied by ordinary text formats",
    ],
    [],
    ["formats/ocr"],
    @oxshared.parser_contract_required_foundation_exclusions(),
  )
}

///|
pub fn audio_parser_contract_spec() -> ParserContractSpec {
  make_parser_contract_spec(
    "audio_parser",
    MediaPipeline,
    None,
    "document",
    [
      "parser_name", "parser_mode", "effective_mode", "detected_format", "ir_input_kind",
      "builder_input_kind", "event_granularity", "event_semantics", "audio_backend_transport",
      "audio_backend_name", "audio_backend_version", "audio_duration_ms", "audio_sample_rate_hz",
      "audio_channel_count", "audio_codec", "audio_language", "audio_segment_count",
      "block_count", "warning_count", "degraded_feature_count", "fallback_count",
    ],
    ["time_start", "time_end"],
    ["audio_segment_id", "audio_start_ms", "audio_end_ms"],
    [
      "audio media pipeline stays transcript-only in P0", "segment time boundaries are first-class source ref fields and chunking anchors",
    ],
    ["accurate audio intentionally degrades to balanced backend during P0"],
    ["formats/audio"],
    @oxshared.parser_contract_required_foundation_exclusions(),
  )
}
