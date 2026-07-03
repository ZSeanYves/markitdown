///|
fn fill_toml_metrics(
  diagnostics : @core.Diagnostics,
  inspect : @dtoml.TomlInspectReport,
  text : String,
  document : @core.DocumentIR,
) -> Unit {
  diagnostics.metrics.set("root_kind", inspect.root_kind)
  diagnostics.metrics.set("table_count", inspect.table_count.to_string())
  diagnostics.metrics.set("block_count", document.blocks.length().to_string())
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("node_count", inspect.node_count.to_string())
  diagnostics.metrics.set("scalar_count", inspect.scalar_count.to_string())
  diagnostics.metrics.set("array_count", inspect.array_count.to_string())
  diagnostics.metrics.set(
    "table_like_count",
    inspect.table_like_count.to_string(),
  )
  diagnostics.metrics.set("max_depth_observed", inspect.max_depth.to_string())
  diagnostics.metrics.set("syntax_error_count", "0")
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
}

///|
fn lower_toml_document(
  doc : @dtoml.TomlDocument,
  source : @input.InputSource,
) -> @core.DocumentIR {
  let document = @core.empty_document_ir()
  if doc.root_members.length() > 0 {
    let root_blocks = lower_toml_members(doc.root_members, source, "/", false)
    document.blocks.append(root_blocks[:])
  }

  let array_base_paths : Map[String, Bool] = Map([])
  for table in doc.tables {
    if table.is_array_item {
      let base_path = toml_array_base_path(table.path)
      if array_base_paths.contains(base_path) {
        continue
      }
      array_base_paths.set(base_path, true)
      document.blocks.append(
        lower_toml_array_of_tables_group(doc.tables, source, base_path)[:],
      )
      continue
    }
    document.blocks.push(
      toml_heading_block(
        toml_display_path(table.path),
        toml_heading_level_for_path(table.path),
        toml_source_ref_from_path(
          source,
          table.path,
          Some(table.line_start),
          Some(table.line_end),
        ),
      ),
    )
    let child_blocks = lower_toml_members(
      table.members,
      source,
      table.path,
      true,
    )
    document.blocks.append(child_blocks[:])
  }

  if document.blocks.length() == 0 {
    document.blocks.push(
      @core.make_block(
        @core.BlockKind::Paragraph,
        "[empty document]",
        source_ref=toml_source_ref_from_path(source, "/", Some(1), Some(1)),
      ),
    )
  }
  document
}

///|
fn lower_toml_members(
  entries : Array[@dtoml.TomlMember],
  source : @input.InputSource,
  base_path : String,
  empty_is_table : Bool,
) -> Array[@core.CoreBlock] {
  let out : Array[@core.CoreBlock] = []
  let scalar_entries : Array[@dtoml.TomlMember] = []
  let complex_entries : Array[@dtoml.TomlMember] = []
  for entry in entries {
    if toml_value_can_fit_kv_table(entry.value) {
      scalar_entries.push(entry)
    } else {
      complex_entries.push(entry)
    }
  }
  if scalar_entries.length() > 0 {
    out.push(toml_table_block_from_members(scalar_entries, source, base_path))
  } else if entries.length() == 0 {
    out.push(
      @core.make_block(
        @core.BlockKind::Paragraph,
        if empty_is_table {
          "[empty table]"
        } else {
          "[empty document]"
        },
        source_ref=toml_source_ref_from_path(
          source,
          base_path,
          Some(1),
          Some(1),
        ),
      ),
    )
  }
  for entry in complex_entries {
    out.append(lower_toml_complex_entry(entry, source)[:])
  }
  out
}

///|
fn lower_toml_complex_entry(
  entry : @dtoml.TomlMember,
  source : @input.InputSource,
) -> Array[@core.CoreBlock] {
  let out : Array[@core.CoreBlock] = []
  let level = toml_heading_level_for_path(entry.path)
  out.push(
    toml_heading_block(
      entry.key,
      if level < 6 {
        level + 1
      } else {
        6
      },
      toml_source_ref_from_member(source, entry),
    ),
  )
  match entry.value {
    @dtoml.TomlValue::String(text) =>
      if text.contains("\n") {
        out.push(
          toml_code_block(
            text,
            source,
            entry.path,
            Some(entry.line_start),
            Some(entry.line_end),
            "text",
          ),
        )
      } else {
        out.push(
          @core.make_block(
            @core.BlockKind::Paragraph,
            text,
            source_ref=toml_source_ref_from_member(source, entry),
          ),
        )
      }
    @dtoml.TomlValue::Array(values) =>
      out.append(lower_toml_array_value(values, source, entry)[:])
    @dtoml.TomlValue::InlineTable(children)
    | @dtoml.TomlValue::Table(children) =>
      out.append(lower_toml_members(children, source, entry.path, true)[:])
    @dtoml.TomlValue::Integer(_)
    | @dtoml.TomlValue::Float(_)
    | @dtoml.TomlValue::Bool(_)
    | @dtoml.TomlValue::Datetime(_) =>
      out.push(
        @core.make_block(
          @core.BlockKind::Paragraph,
          toml_value_cell(entry.value),
          source_ref=toml_source_ref_from_member(source, entry),
        ),
      )
  }
  out
}

///|
fn lower_toml_array_value(
  values : Array[@dtoml.TomlValue],
  source : @input.InputSource,
  owner : @dtoml.TomlMember,
) -> Array[@core.CoreBlock] {
  if values.length() == 0 {
    return [
      @core.make_block(
        @core.BlockKind::Paragraph,
        "[]",
        source_ref=toml_source_ref_from_member(source, owner),
      ),
    ]
  }
  if toml_array_of_scalars(values) {
    return [toml_scalar_list_block(values, source, owner)]
  }
  match toml_inline_table_array_rows(values) {
    Some(rows) =>
      [
        toml_table_block_from_rows(
          rows,
          source,
          owner.path,
          Some(owner.line_start),
          Some(owner.line_end),
        ),
      ]
    None =>
      [
        toml_code_block(
          toml_stringify_value(owner.value),
          source,
          owner.path,
          Some(owner.line_start),
          Some(owner.line_end),
          "toml",
        ),
      ]
  }
}

///|
fn lower_toml_array_of_tables_group(
  tables : Array[@dtoml.TomlTable],
  source : @input.InputSource,
  base_path : String,
) -> Array[@core.CoreBlock] {
  let out : Array[@core.CoreBlock] = []
  let grouped = toml_collect_array_tables(tables, base_path)
  if grouped.length() == 0 {
    return out
  }
  out.push(
    toml_heading_block(
      toml_display_path(base_path),
      toml_heading_level_for_path(base_path),
      toml_source_ref_from_path(
        source,
        base_path,
        Some(grouped[0].line_start),
        Some(grouped[grouped.length() - 1].line_end),
      ),
    ),
  )
  match toml_array_tables_as_rows(grouped) {
    Some(rows) =>
      out.push(
        toml_table_block_from_rows(
          rows,
          source,
          base_path,
          Some(grouped[0].line_start),
          Some(grouped[grouped.length() - 1].line_end),
        ),
      )
    None => {
      let base_level = toml_heading_level_for_path(base_path)
      for i in 0..<grouped.length() {
        let table = grouped[i]
        out.push(
          toml_heading_block(
            "Item " + (i + 1).to_string(),
            if base_level < 6 {
              base_level + 1
            } else {
              6
            },
            toml_source_ref_from_path(
              source,
              table.path,
              Some(table.line_start),
              Some(table.line_end),
            ),
          ),
        )
        let child_blocks = lower_toml_members(
          table.members,
          source,
          table.path,
          true,
        )
        out.append(child_blocks[:])
      }
    }
  }
  out
}

///|
fn toml_scalar_list_block(
  values : Array[@dtoml.TomlValue],
  source : @input.InputSource,
  owner : @dtoml.TomlMember,
) -> @core.CoreBlock {
  let list = @core.make_block(
    @core.BlockKind::List,
    "",
    source_ref=toml_source_ref_from_member(source, owner),
  )
  for i in 0..<values.length() {
    list.children.push(
      @core.block_with_attr(
        @core.make_block(
          @core.BlockKind::ListItem,
          toml_value_cell(values[i]),
          source_ref=toml_source_ref_from_path(
            source,
            owner.path + "/" + i.to_string(),
            Some(owner.line_start),
            Some(owner.line_end),
          ),
        ),
        "ordered",
        "false",
      ),
    )
  }
  list
}

///|
fn toml_table_block_from_members(
  entries : Array[@dtoml.TomlMember],
  source : @input.InputSource,
  path : String,
) -> @core.CoreBlock {
  let rows : Array[Array[String]] = [["Key", "Value"]]
  for entry in entries {
    rows.push([entry.key, toml_value_cell(entry.value)])
  }
  toml_table_block_from_rows(
    rows,
    source,
    path,
    Some(entries[0].line_start),
    Some(entries[entries.length() - 1].line_end),
  )
}

///|
fn toml_table_block_from_rows(
  rows : Array[Array[String]],
  source : @input.InputSource,
  path : String,
  line_start : Int?,
  line_end : Int?,
) -> @core.CoreBlock {
  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=toml_source_ref_from_path(source, path, line_start, line_end),
  )
  table.attrs.set("header_rows", "1")
  for row_index in 0..<rows.length() {
    let row_values = rows[row_index]
    let row = @core.make_block(
      @core.BlockKind::TableRow,
      row_values.join(" | "),
      source_ref=toml_source_ref_from_path(
        source,
        path + "/row[" + row_index.to_string() + "]",
        line_start,
        line_end,
      ),
    )
    for col_index in 0..<row_values.length() {
      row.children.push(
        @core.make_block(
          @core.BlockKind::TableCell,
          row_values[col_index],
          source_ref=toml_source_ref_from_path(
            source,
            path +
            "/row[" +
            row_index.to_string() +
            "]/col[" +
            col_index.to_string() +
            "]",
            line_start,
            line_end,
          ),
        ),
      )
    }
    table.children.push(row)
  }
  table
}

///|
fn toml_heading_block(
  text : String,
  level : Int,
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  let heading = @core.make_block(@core.BlockKind::Heading, text, source_ref~)
  heading.attrs.set("level", level.to_string())
  heading
}

///|
fn toml_source_ref_from_member(
  source : @input.InputSource,
  entry : @dtoml.TomlMember,
) -> @core.SourceRef {
  toml_source_ref_from_path(
    source,
    entry.path,
    Some(entry.line_start),
    Some(entry.line_end),
  )
}

///|
fn toml_source_ref_from_path(
  source : @input.InputSource,
  path : String,
  line_start : Int?,
  line_end : Int?,
) -> @core.SourceRef {
  let base = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("toml"),
    line_start,
    line_end,
  )
  @core.source_ref_with_extra(base, "toml_path", path)
}

///|
fn toml_code_block(
  text : String,
  source : @input.InputSource,
  path : String,
  line_start : Int?,
  line_end : Int?,
  info : String,
) -> @core.CoreBlock {
  let block = @core.make_block(
    @core.BlockKind::Code,
    text,
    source_ref=toml_source_ref_from_path(source, path, line_start, line_end),
  )
  block.attrs.set("info", info)
  block
}

///|
fn toml_malformed_parse_result(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  err : String,
  capability : @parser.ParserCapability,
) -> @parser.ParseResult {
  let block = toml_code_block(
    text,
    source,
    "/",
    Some(1),
    Some(@fshared.count_physical_lines(text)),
    "toml",
  )
  diagnostics.warnings.push("toml parse warning: " + err)
  diagnostics.degraded_features.push("toml_raw_fenced_fallback")
  diagnostics.fallback_trace.push("toml parse failed -> raw fenced block")
  diagnostics.metrics.set("root_kind", "document")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("block_count", "1")
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("node_count", "0")
  diagnostics.metrics.set("scalar_count", "0")
  diagnostics.metrics.set("array_count", "0")
  diagnostics.metrics.set("table_like_count", "0")
  diagnostics.metrics.set("max_depth_observed", "0")
  diagnostics.metrics.set("syntax_error_count", "1")
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.pass_trace.push("parse:toml_parser")
  let document = @core.document_from_blocks([block])
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    "toml_parser",
    @parser.ParserMode::DomAstModel,
    final_document,
    diagnostics,
    capability,
  )
}

///|
fn toml_value_can_fit_kv_table(value : @dtoml.TomlValue) -> Bool {
  match value {
    @dtoml.TomlValue::String(text) => !text.contains("\n")
    @dtoml.TomlValue::Integer(_)
    | @dtoml.TomlValue::Float(_)
    | @dtoml.TomlValue::Bool(_)
    | @dtoml.TomlValue::Datetime(_) => true
    @dtoml.TomlValue::InlineTable(entries) =>
      toml_inline_table_inlineable(entries)
    @dtoml.TomlValue::Table(entries) => toml_inline_table_inlineable(entries)
    @dtoml.TomlValue::Array(values) =>
      values.length() == 0 ||
      toml_array_of_scalars(values) ||
      toml_inline_table_array_rows(values) is Some(_)
  }
}

///|
fn toml_value_cell(value : @dtoml.TomlValue) -> String {
  match value {
    @dtoml.TomlValue::String(text) => text
    @dtoml.TomlValue::Integer(text) => text
    @dtoml.TomlValue::Float(text) => text
    @dtoml.TomlValue::Bool(value) => if value { "true" } else { "false" }
    @dtoml.TomlValue::Datetime(text) => text
    @dtoml.TomlValue::InlineTable(entries) => toml_inline_table_text(entries)
    @dtoml.TomlValue::Table(entries) => toml_inline_table_text(entries)
    @dtoml.TomlValue::Array(values) =>
      if values.length() == 0 {
        "[]"
      } else if toml_array_of_scalars(values) {
        "[" + values.map(fn(item) { toml_value_cell(item) }).join(", ") + "]"
      } else {
        toml_array_summary(values)
      }
  }
}

///|
fn toml_inline_table_text(entries : Array[@dtoml.TomlMember]) -> String {
  let parts : Array[String] = []
  for entry in entries {
    parts.push(entry.key + " = " + toml_value_cell(entry.value))
  }
  "{ " + parts.join(", ") + " }"
}

///|
fn toml_inline_table_inlineable(entries : Array[@dtoml.TomlMember]) -> Bool {
  for entry in entries {
    if !toml_value_can_fit_kv_table(entry.value) {
      return false
    }
  }
  true
}

///|
fn toml_array_of_scalars(values : Array[@dtoml.TomlValue]) -> Bool {
  for value in values {
    match value {
      @dtoml.TomlValue::String(_)
      | @dtoml.TomlValue::Integer(_)
      | @dtoml.TomlValue::Float(_)
      | @dtoml.TomlValue::Bool(_)
      | @dtoml.TomlValue::Datetime(_) => ()
      _ => return false
    }
  }
  true
}

///|
fn toml_inline_table_array_rows(
  values : Array[@dtoml.TomlValue],
) -> Array[Array[String]]? {
  let rows : Array[Array[String]] = []
  let mut keys : Array[String] = []
  for i in 0..<values.length() {
    let entries = match values[i] {
      @dtoml.TomlValue::InlineTable(items) => items
      @dtoml.TomlValue::Table(items) => items
      _ => return None
    }
    let next_keys = entries.map(fn(item) { item.key })
    if i == 0 {
      keys = next_keys
      rows.push(keys)
    } else if !toml_same_key_set(keys, next_keys) {
      return None
    }
    let row : Array[String] = []
    for key in keys {
      row.push(toml_member_value_cell(entries, key))
    }
    rows.push(row)
  }
  if rows.length() == 0 {
    None
  } else {
    Some(rows)
  }
}

///|
fn toml_array_tables_as_rows(
  tables : Array[@dtoml.TomlTable],
) -> Array[Array[String]]? {
  let rows : Array[Array[String]] = []
  let mut keys : Array[String] = []
  for i in 0..<tables.length() {
    let next_keys = tables[i].members.map(fn(item) { item.key })
    if i == 0 {
      keys = next_keys
      rows.push(keys)
    } else if !toml_same_key_set(keys, next_keys) {
      return None
    }
    let row : Array[String] = []
    for key in keys {
      row.push(toml_member_value_cell(tables[i].members, key))
    }
    rows.push(row)
  }
  if rows.length() == 0 {
    None
  } else {
    Some(rows)
  }
}

///|
fn toml_member_value_cell(
  entries : Array[@dtoml.TomlMember],
  key : String,
) -> String {
  for entry in entries {
    if entry.key == key {
      return toml_value_cell(entry.value)
    }
  }
  ""
}

///|
fn toml_same_key_set(left : Array[String], right : Array[String]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for key in left {
    if !right.contains(key) {
      return false
    }
  }
  true
}

///|
fn toml_collect_array_tables(
  tables : Array[@dtoml.TomlTable],
  base_path : String,
) -> Array[@dtoml.TomlTable] {
  let out : Array[@dtoml.TomlTable] = []
  for table in tables {
    if table.is_array_item && toml_array_base_path(table.path) == base_path {
      out.push(table)
    }
  }
  out
}

///|
fn toml_array_base_path(path : String) -> String {
  match path.split_once("[") {
    Some((head, _)) => head.to_owned()
    None => path
  }
}

///|
fn toml_heading_level_for_path(path : String) -> Int {
  let depth = toml_path_depth(path)
  if depth <= 1 {
    1
  } else if depth >= 6 {
    6
  } else {
    depth
  }
}

///|
fn toml_display_path(path : String) -> String {
  let normalized = toml_array_base_path(path)
  if normalized == "/" {
    "Root"
  } else {
    let parts : Array[String] = []
    for part in normalized.split("/").to_array() {
      if part != "" {
        parts.push(part.to_owned())
      }
    }
    parts.join(".")
  }
}

///|
fn toml_path_depth(path : String) -> Int {
  if path == "/" || path == "" {
    return 1
  }
  let mut depth = 0
  for part in path.split("/").to_array() {
    if part != "" {
      depth += 1
    }
  }
  if depth == 0 {
    1
  } else {
    depth
  }
}

///|
fn toml_array_summary(values : Array[@dtoml.TomlValue]) -> String {
  let mut table_like_count = 0
  for value in values {
    match value {
      @dtoml.TomlValue::InlineTable(_) | @dtoml.TomlValue::Table(_) =>
        table_like_count += 1
      _ => ()
    }
  }
  if table_like_count == values.length() {
    "array[" + values.length().to_string() + "] of tables"
  } else {
    "array[" + values.length().to_string() + "]"
  }
}

///|
fn toml_stringify_value(value : @dtoml.TomlValue) -> String {
  match value {
    @dtoml.TomlValue::String(text) => toml_quote_string(text)
    @dtoml.TomlValue::Integer(text) => text
    @dtoml.TomlValue::Float(text) => text
    @dtoml.TomlValue::Bool(value) => if value { "true" } else { "false" }
    @dtoml.TomlValue::Datetime(text) => text
    @dtoml.TomlValue::Array(values) =>
      "[" + values.map(fn(item) { toml_stringify_value(item) }).join(", ") + "]"
    @dtoml.TomlValue::InlineTable(entries) => toml_inline_table_text(entries)
    @dtoml.TomlValue::Table(entries) => toml_inline_table_text(entries)
  }
}

///|
fn toml_quote_string(text : String) -> String {
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
