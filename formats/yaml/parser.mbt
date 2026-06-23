///|
fn yaml_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::DomAstModel,
    true,
    @parser.StreamingGranularity::YamlStructure,
    false,
    true,
    false,
    true,
    false,
    true,
    true,
    true,
    false,
    true,
    false,
    true,
    true,
    true,
    true,
    false,
  )
}

///|
pub fn yaml_lite_parser() -> @parser.Parser {
  @parser.make_parser(
    "yaml_parser",
    @parser.ParserMode::DomAstModel,
    yaml_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_yaml_document_result(source, context)
    },
  )
}

///|
fn parse_yaml_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, String] {
  let text = match @input.read_input_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let diagnostics = @light_common.empty_parser_diagnostics(
    "yaml_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "yaml",
  )
  diagnostics.metrics.set("parser_name", "yaml_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @light_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "yaml")
  diagnostics.metrics.set(
    "requested_mode",
    @light_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "dom_ast_model")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "none")
  diagnostics.metrics.set("event_semantics", "dom_ast_model")
  diagnostics.metrics.set("streaming_fallback", "false")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  @light_common.apply_readiness_metrics(diagnostics, "yaml", "near_ready")

  let parsed = try @dyaml.parse_yaml_structure_document(text) |> Ok catch {
    e => Err(e.to_string())
  }
  match parsed {
    Ok(structured) => {
      let inspect = @dyaml.inspect_yaml_document(structured.document)
      let dom_limit_reached = yaml_dom_limit_reached(context, inspect)
      if dom_limit_reached {
        return Ok(
          yaml_streaming_parse_result(
            source,
            text,
            diagnostics,
            structured.document,
            inspect,
            structured.events,
          ),
        )
      }
      let document = lower_yaml_document(structured.document, source)
      yaml_fill_common_metrics(diagnostics, inspect, text, 0)
      diagnostics.metrics.set(
        "table_count",
        @light_common.count_blocks_by_kind(
          document.blocks,
          @core.BlockKind::Table,
        ).to_string(),
      )
      diagnostics.metrics.set(
        "block_count",
        document.blocks.length().to_string(),
      )
      diagnostics.pass_trace.push("parse:yaml_parser")
      let final_document = @core.document_with_diagnostics(
        document, diagnostics,
      )
      Ok(
        @parser.parse_result_with_document_capability(
          "yaml_parser",
          @parser.ParserMode::DomAstModel,
          final_document,
          diagnostics,
          yaml_parser_capability(),
        ),
      )
    }
    Err(err) => Ok(yaml_malformed_parse_result(source, text, diagnostics, err))
  }
}

///|
fn yaml_dom_limit_reached(
  context : @parser.ParseContext,
  inspect : @dyaml.YamlInspectReport,
) -> Bool {
  let node_limit = context.max_cells.unwrap_or(10000)
  let depth_limit = context.max_rows.unwrap_or(200)
  let text_limit = context.max_line_chars.unwrap_or(4000)
  inspect.node_count > node_limit ||
  inspect.max_depth > depth_limit ||
  text_limit <
  inspect.scalar_count * 2 + inspect.mapping_count + inspect.sequence_count
}

///|
fn yaml_fill_common_metrics(
  diagnostics : @core.Diagnostics,
  inspect : @dyaml.YamlInspectReport,
  text : String,
  event_count : Int,
) -> Unit {
  diagnostics.metrics.set("root_kind", inspect.root_kind.unwrap_or("none"))
  diagnostics.metrics.set(
    "is_empty",
    @light_common.bool_string(inspect.is_empty),
  )
  diagnostics.metrics.set("mapping_count", inspect.mapping_count.to_string())
  diagnostics.metrics.set("sequence_count", inspect.sequence_count.to_string())
  diagnostics.metrics.set("scalar_count", inspect.scalar_count.to_string())
  diagnostics.metrics.set("node_count", inspect.node_count.to_string())
  diagnostics.metrics.set("max_depth_observed", inspect.max_depth.to_string())
  diagnostics.metrics.set("syntax_error_count", "0")
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set(
    "line_count",
    @light_common.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("event_count", event_count.to_string())
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
}

///|
fn lower_yaml_document(
  doc : @dyaml.YamlDocument,
  source : @input.InputSource,
) -> @core.DocumentIR {
  let document = @core.empty_document_ir()
  match doc.root {
    Some(root) =>
      for block in yaml_value_to_blocks(root, source, "/") {
        document.blocks.push(block)
      }
    None => ()
  }
  document
}

///|
fn yaml_value_to_blocks(
  value : @dyaml.YamlValue,
  source : @input.InputSource,
  path : String,
) -> Array[@core.CoreBlock] {
  match value {
    @dyaml.YamlValue::Mapping(members) =>
      [yaml_mapping_table_block(members, source, path)]
    @dyaml.YamlValue::Sequence(values) =>
      if values.length() == 0 {
        [yaml_code_block("[]", source, path)]
      } else if yaml_array_of_scalars(values) {
        [yaml_scalar_list_block(values, source, path)]
      } else {
        match yaml_array_object_rows(values) {
          Some(rows) => [yaml_table_block_from_rows(rows, source, path)]
          None =>
            [yaml_code_block(yaml_stringify_block(value, 0), source, path)]
        }
      }
    @dyaml.YamlValue::String(text) =>
      [
        @core.make_block(
          @core.BlockKind::Paragraph,
          text,
          source_ref=yaml_source_ref(source, path),
        ),
      ]
    @dyaml.YamlValue::Bool(value) =>
      [
        @core.make_block(
          @core.BlockKind::Paragraph,
          if value {
            "true"
          } else {
            "false"
          },
          source_ref=yaml_source_ref(source, path),
        ),
      ]
    @dyaml.YamlValue::Null =>
      [
        @core.make_block(
          @core.BlockKind::Paragraph,
          "null",
          source_ref=yaml_source_ref(source, path),
        ),
      ]
  }
}

///|
fn yaml_mapping_table_block(
  members : Array[@dyaml.YamlMember],
  source : @input.InputSource,
  path : String,
) -> @core.CoreBlock {
  let rows : Array[Array[String]] = [["Key", "Value"]]
  for entry in members {
    rows.push([entry.key, yaml_value_cell(entry.value)])
  }
  yaml_table_block_from_rows(rows, source, path)
}

///|
fn yaml_scalar_list_block(
  values : Array[@dyaml.YamlValue],
  source : @input.InputSource,
  path : String,
) -> @core.CoreBlock {
  let list = @core.make_block(
    @core.BlockKind::List,
    "",
    source_ref=yaml_source_ref(source, path),
  )
  for i in 0..<values.length() {
    let item_path = yaml_join_index(path, i)
    list.children.push(
      @core.block_with_attr(
        @core.make_block(
          @core.BlockKind::ListItem,
          yaml_scalar_text(values[i]),
          source_ref=yaml_source_ref(source, item_path),
        ),
        "ordered",
        "false",
      ),
    )
  }
  list
}

///|
fn yaml_array_object_rows(
  values : Array[@dyaml.YamlValue],
) -> Array[Array[String]]? {
  let mut keys : Array[String] = []
  let rows : Array[Array[String]] = []
  for i in 0..<values.length() {
    match values[i] {
      @dyaml.YamlValue::Mapping(members) => {
        let member_keys = members.map(fn(entry) { entry.key })
        if i == 0 {
          keys = member_keys
          rows.push(keys)
        } else if !yaml_same_key_set(keys, member_keys) {
          return None
        }
        rows.push(yaml_members_to_row(members, keys))
      }
      _ => return None
    }
  }
  if rows.length() == 0 {
    None
  } else {
    Some(rows)
  }
}

///|
fn yaml_members_to_row(
  members : Array[@dyaml.YamlMember],
  keys : Array[String],
) -> Array[String] {
  let row : Array[String] = []
  for key in keys {
    row.push(yaml_member_value_cell(members, key))
  }
  row
}

///|
fn yaml_member_value_cell(
  members : Array[@dyaml.YamlMember],
  key : String,
) -> String {
  for entry in members {
    if entry.key == key {
      return yaml_value_cell(entry.value)
    }
  }
  ""
}

///|
fn yaml_same_key_set(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for key in a {
    if !yaml_contains_key(b, key) {
      return false
    }
  }
  true
}

///|
fn yaml_contains_key(keys : Array[String], target : String) -> Bool {
  for key in keys {
    if key == target {
      return true
    }
  }
  false
}

///|
fn yaml_array_of_scalars(values : Array[@dyaml.YamlValue]) -> Bool {
  for value in values {
    match value {
      @dyaml.YamlValue::String(_)
      | @dyaml.YamlValue::Bool(_)
      | @dyaml.YamlValue::Null => ()
      _ => return false
    }
  }
  true
}

///|
fn yaml_value_cell(value : @dyaml.YamlValue) -> String {
  match value {
    @dyaml.YamlValue::String(text) => text
    @dyaml.YamlValue::Bool(value) => if value { "true" } else { "false" }
    @dyaml.YamlValue::Null => "null"
    _ => yaml_stringify_inline(value)
  }
}

///|
fn yaml_scalar_text(value : @dyaml.YamlValue) -> String {
  yaml_value_cell(value)
}

///|
fn yaml_stringify_inline(value : @dyaml.YamlValue) -> String {
  match value {
    @dyaml.YamlValue::Mapping(members) => {
      let parts : Array[String] = []
      for entry in members {
        parts.push(
          yaml_stringify_key(entry.key) +
          ": " +
          yaml_stringify_inline(entry.value),
        )
      }
      "{" + parts.join(", ") + "}"
    }
    @dyaml.YamlValue::Sequence(values) => {
      let parts : Array[String] = []
      for item in values {
        parts.push(yaml_stringify_inline(item))
      }
      "[" + parts.join(", ") + "]"
    }
    @dyaml.YamlValue::String(text) =>
      if yaml_needs_quotes(text) {
        yaml_quote_string(text)
      } else {
        text
      }
    @dyaml.YamlValue::Bool(value) => if value { "true" } else { "false" }
    @dyaml.YamlValue::Null => "null"
  }
}

///|
fn yaml_stringify_block(value : @dyaml.YamlValue, indent : Int) -> String {
  let prefix = "  ".repeat(indent)
  match value {
    @dyaml.YamlValue::Mapping(members) => {
      let lines : Array[String] = []
      for entry in members {
        match entry.value {
          @dyaml.YamlValue::String(_)
          | @dyaml.YamlValue::Bool(_)
          | @dyaml.YamlValue::Null =>
            lines.push(
              prefix +
              yaml_stringify_key(entry.key) +
              ": " +
              yaml_stringify_inline(entry.value),
            )
          _ => {
            lines.push(prefix + yaml_stringify_key(entry.key) + ":")
            lines.push(yaml_stringify_block(entry.value, indent + 1))
          }
        }
      }
      lines.join("\n")
    }
    @dyaml.YamlValue::Sequence(values) => {
      let lines : Array[String] = []
      for item in values {
        match item {
          @dyaml.YamlValue::String(_)
          | @dyaml.YamlValue::Bool(_)
          | @dyaml.YamlValue::Null =>
            lines.push(prefix + "- " + yaml_stringify_inline(item))
          _ => {
            lines.push(prefix + "-")
            lines.push(yaml_stringify_block(item, indent + 1))
          }
        }
      }
      lines.join("\n")
    }
    _ => yaml_stringify_inline(value)
  }
}

///|
fn yaml_stringify_key(key : String) -> String {
  if yaml_needs_quotes(key) {
    yaml_quote_string(key)
  } else {
    key
  }
}

///|
fn yaml_needs_quotes(text : String) -> Bool {
  if text == "" ||
    text == "true" ||
    text == "false" ||
    text == "null" ||
    text == "~" {
    return true
  }
  if text.has_prefix("-") {
    return true
  }
  for ch in text.to_array() {
    match ch {
      ' '
      | ':'
      | ','
      | '#'
      | '['
      | ']'
      | '{'
      | '}'
      | '"'
      | '\''
      | '\n'
      | '\r'
      | '\t' => return true
      _ => ()
    }
  }
  false
}

///|
fn yaml_quote_string(text : String) -> String {
  let out : Array[Char] = ['"']
  for ch in text.to_array() {
    match ch {
      '"' => {
        out.push('\\')
        out.push('"')
      }
      '\\' => {
        out.push('\\')
        out.push('\\')
      }
      '\n' => {
        out.push('\\')
        out.push('n')
      }
      '\r' => {
        out.push('\\')
        out.push('r')
      }
      '\t' => {
        out.push('\\')
        out.push('t')
      }
      _ => out.push(ch)
    }
  }
  out.push('"')
  String::from_array(out)
}

///|
fn yaml_table_block_from_rows(
  rows : Array[Array[String]],
  source : @input.InputSource,
  path : String,
) -> @core.CoreBlock {
  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=yaml_source_ref(source, path),
  )
  table.attrs.set("header_rows", "1")
  for row_index in 0..<rows.length() {
    let row_values = rows[row_index]
    let row_path = if row_index == 0 {
      path + "/header"
    } else {
      yaml_join_index(path, row_index - 1)
    }
    let row_ref = yaml_source_ref(source, row_path)
    let row = @core.make_block(
      @core.BlockKind::TableRow,
      row_values.join(" | "),
      source_ref=row_ref,
    )
    for col_index in 0..<row_values.length() {
      row.children.push(
        @core.make_block(
          @core.BlockKind::TableCell,
          row_values[col_index],
          source_ref=yaml_source_ref(
            source,
            row_path + "/col[" + col_index.to_string() + "]",
          ),
        ),
      )
    }
    table.children.push(row)
  }
  table
}

///|
fn yaml_code_block(
  text : String,
  source : @input.InputSource,
  path : String,
) -> @core.CoreBlock {
  @core.make_block(
    @core.BlockKind::Code,
    text,
    source_ref=yaml_source_ref(source, path),
  )
}

///|
fn yaml_source_ref(
  source : @input.InputSource,
  path : String,
) -> @core.SourceRef {
  @core.source_ref_with_yaml_path(
    @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("yaml"),
      Some(1),
      Some(1),
    ),
    Some(source.source_name),
    Some("yaml"),
    Some(path),
  )
}

///|
fn yaml_join_index(parent : String, index : Int) -> String {
  parent + "[" + index.to_string() + "]"
}

///|
fn yaml_streaming_parse_result(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  document : @dyaml.YamlDocument,
  inspect : @dyaml.YamlInspectReport,
  yaml_events : Array[@dyaml.YamlStructureEvent],
) -> @parser.ParseResult {
  ignore(yaml_events)
  let lowered = lower_yaml_document(document, source)
  let events = @pipeline.blocks_to_event_stream(lowered.blocks)
  diagnostics.metrics.set("parser_mode", "streaming_event")
  diagnostics.metrics.set("effective_mode", "streaming_event")
  diagnostics.metrics.set("ir_input_kind", "event_stream")
  diagnostics.metrics.set("streaming_fallback", "true")
  diagnostics.metrics.set("resource_limit_hit", "true")
  diagnostics.metrics.set("dom_limit_reached", "true")
  yaml_fill_common_metrics(diagnostics, inspect, text, events.length())
  diagnostics.metrics.set(
    "table_count",
    @light_common.count_blocks_by_kind(lowered.blocks, @core.BlockKind::Table).to_string(),
  )
  diagnostics.metrics.set("block_count", lowered.blocks.length().to_string())
  diagnostics.metrics.set("event_granularity", "yaml_structure")
  diagnostics.metrics.set("event_semantics", "yaml_structure_event_stream")
  diagnostics.pass_trace.push("parse:yaml_parser")
  @parser.parse_result_with_events_capability(
    "yaml_parser",
    @parser.ParserMode::StreamingEvent,
    events,
    diagnostics,
    yaml_parser_capability(),
  )
}

///|
fn yaml_malformed_parse_result(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  err : String,
) -> @parser.ParseResult {
  let source_ref = @core.source_ref_with_lines(
    @core.source_ref_with_yaml_path(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("yaml"),
      Some("/"),
    ),
    Some(source.source_name),
    Some("yaml"),
    Some(1),
    Some(@light_common.count_physical_lines(text)),
  )
  let block = @core.make_block(@core.BlockKind::Raw, text, source_ref~)
  block.attrs.set("raw_kind", "yaml_fail_closed")
  block.attrs.set("info", "yaml")
  diagnostics.warnings.push("yaml parse warning: " + err)
  diagnostics.degraded_features.push("yaml_fail_closed")
  diagnostics.fallback_trace.push("yaml parse failed -> raw block fallback")
  diagnostics.metrics.set("parser_name", "yaml_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @light_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "yaml")
  diagnostics.metrics.set("requested_mode", "default")
  diagnostics.metrics.set("effective_mode", "dom_ast_model")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "none")
  diagnostics.metrics.set("event_semantics", "yaml_dom_ast_model_failed_closed")
  diagnostics.metrics.set("streaming_fallback", "false")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  diagnostics.metrics.set("root_kind", "none")
  diagnostics.metrics.set(
    "is_empty",
    @light_common.bool_string(text.trim() == ""),
  )
  diagnostics.metrics.set("syntax_error_count", "1")
  diagnostics.metrics.set(
    "line_count",
    @light_common.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("mapping_count", "0")
  diagnostics.metrics.set("sequence_count", "0")
  diagnostics.metrics.set("scalar_count", "0")
  diagnostics.metrics.set("node_count", "0")
  diagnostics.metrics.set("max_depth_observed", "0")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("block_count", "1")
  diagnostics.metrics.set("event_count", "0")
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.pass_trace.push("parse:yaml_parser")
  let document = @core.empty_document_ir()
  document.blocks.push(block)
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    "yaml_parser",
    @parser.ParserMode::DomAstModel,
    final_document,
    diagnostics,
    yaml_parser_capability(),
  )
}
