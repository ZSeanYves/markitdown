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
    @parser_common.bool_string(inspect.is_empty),
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
    @parser_common.count_physical_lines(text).to_string(),
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
fn yaml_generic_block_events(
  yaml_events : Array[@dyaml.YamlStructureEvent],
  source : @input.InputSource,
) -> Array[@core.CoreEvent] {
  let out : Array[@core.CoreEvent] = []
  let cursor = { events: yaml_events, index: 0 }
  yaml_append_value_events(out, cursor, source, "/")
  out
}

///|
priv struct YamlEventCursor {
  events : Array[@dyaml.YamlStructureEvent]
  mut index : Int
}

///|
fn yaml_append_value_events(
  out : Array[@core.CoreEvent],
  cursor : YamlEventCursor,
  source : @input.InputSource,
  path : String,
) -> Unit {
  if cursor.index >= cursor.events.length() {
    return
  }
  let event = cursor.events[cursor.index]
  match event.kind {
    @dyaml.YamlStructureEventKind::MappingStart => {
      cursor.index += 1
      let rows : Array[Array[String]] = [["Key", "Value"]]
      let row_refs : Array[@core.SourceRef] = [
        yaml_event_source_ref(
          source,
          event.source.path,
          event.source.line_start,
          event.source.line_end,
        ),
      ]
      while cursor.index < cursor.events.length() {
        let next = cursor.events[cursor.index]
        match next.kind {
          @dyaml.YamlStructureEventKind::Key => {
            let key = next.text.unwrap_or("")
            let member_path = next.source.path
            cursor.index += 1
            let value = yaml_event_value_summary(cursor, source, member_path)
            rows.push([key, value.0])
            row_refs.push(value.1)
          }
          @dyaml.YamlStructureEventKind::MappingEnd => {
            cursor.index += 1
            yaml_append_table_events(out, rows, row_refs, source, path)
            return
          }
          _ => cursor.index += 1
        }
      }
    }
    @dyaml.YamlStructureEventKind::SequenceStart => {
      cursor.index += 1
      let values : Array[(String, @core.SourceRef)] = []
      let table_rows : Array[Array[String]] = []
      let table_refs : Array[@core.SourceRef] = []
      let mut header_keys : Array[String]? = None
      let mut can_render_table = true
      let mut item_index = 0
      while cursor.index < cursor.events.length() {
        let next = cursor.events[cursor.index]
        match next.kind {
          @dyaml.YamlStructureEventKind::SequenceEnd => {
            cursor.index += 1
            if can_render_table && table_rows.length() > 1 {
              yaml_append_table_events(
                out, table_rows, table_refs, source, path,
              )
            } else if values.length() > 0 {
              yaml_append_list_events(out, values, source, path)
            } else {
              yaml_append_paragraph_events(
                out,
                "[]",
                yaml_event_source_ref(
                  source,
                  path,
                  event.source.line_start,
                  event.source.line_end,
                ),
              )
            }
            return
          }
          _ => {
            let item_path = yaml_join_index(path, item_index)
            let mut consumed_as_table_row = false
            if can_render_table {
              match yaml_collect_mapping_row(cursor, source, item_path) {
                Some(value) => {
                  consumed_as_table_row = true
                  match header_keys {
                    Some(keys) =>
                      if !yaml_same_key_set(keys, value.0) {
                        can_render_table = false
                      }
                    None => {
                      header_keys = Some(value.0)
                      table_rows.push(value.0)
                    }
                  }
                  if can_render_table {
                    table_rows.push(value.1)
                    table_refs.push(value.2)
                  }
                }
                None => can_render_table = false
              }
            }
            if consumed_as_table_row {
              let row_ref = if table_refs.length() > 0 {
                table_refs[table_refs.length() - 1]
              } else {
                yaml_source_ref(source, item_path)
              }
              values.push(("{...}", row_ref))
            } else {
              values.push(yaml_event_value_summary(cursor, source, item_path))
            }
            item_index += 1
          }
        }
      }
    }
    @dyaml.YamlStructureEventKind::StringValue
    | @dyaml.YamlStructureEventKind::BoolValue
    | @dyaml.YamlStructureEventKind::NullValue => {
      yaml_append_paragraph_events(
        out,
        event.text.unwrap_or(""),
        yaml_event_source_ref(
          source,
          event.source.path,
          event.source.line_start,
          event.source.line_end,
        ),
      )
      cursor.index += 1
    }
    @dyaml.YamlStructureEventKind::Key
    | @dyaml.YamlStructureEventKind::MappingEnd
    | @dyaml.YamlStructureEventKind::SequenceEnd => cursor.index += 1
  }
}

///|
fn yaml_event_value_summary(
  cursor : YamlEventCursor,
  source : @input.InputSource,
  path : String,
) -> (String, @core.SourceRef) {
  let event = cursor.events[cursor.index]
  match event.kind {
    @dyaml.YamlStructureEventKind::StringValue
    | @dyaml.YamlStructureEventKind::BoolValue
    | @dyaml.YamlStructureEventKind::NullValue => {
      cursor.index += 1
      (
        event.text.unwrap_or(""),
        yaml_event_source_ref(
          source,
          path,
          event.source.line_start,
          event.source.line_end,
        ),
      )
    }
    @dyaml.YamlStructureEventKind::MappingStart => {
      let start = event.source
      let mut depth = 0
      while cursor.index < cursor.events.length() {
        let next = cursor.events[cursor.index]
        match next.kind {
          @dyaml.YamlStructureEventKind::MappingStart => depth += 1
          @dyaml.YamlStructureEventKind::MappingEnd => {
            depth -= 1
            if depth == 0 {
              cursor.index += 1
              return (
                "{...}",
                yaml_event_source_ref(
                  source,
                  path,
                  start.line_start,
                  next.source.line_end,
                ),
              )
            }
          }
          _ => ()
        }
        cursor.index += 1
      }
      (
        "{...}",
        yaml_event_source_ref(source, path, start.line_start, start.line_end),
      )
    }
    @dyaml.YamlStructureEventKind::SequenceStart => {
      let start = event.source
      let mut depth = 0
      while cursor.index < cursor.events.length() {
        let next = cursor.events[cursor.index]
        match next.kind {
          @dyaml.YamlStructureEventKind::SequenceStart => depth += 1
          @dyaml.YamlStructureEventKind::SequenceEnd => {
            depth -= 1
            if depth == 0 {
              cursor.index += 1
              return (
                "[...]",
                yaml_event_source_ref(
                  source,
                  path,
                  start.line_start,
                  next.source.line_end,
                ),
              )
            }
          }
          _ => ()
        }
        cursor.index += 1
      }
      (
        "[...]",
        yaml_event_source_ref(source, path, start.line_start, start.line_end),
      )
    }
    _ => {
      cursor.index += 1
      (
        "",
        yaml_event_source_ref(
          source,
          path,
          event.source.line_start,
          event.source.line_end,
        ),
      )
    }
  }
}

///|
fn yaml_collect_mapping_row(
  cursor : YamlEventCursor,
  source : @input.InputSource,
  path : String,
) -> (Array[String], Array[String], @core.SourceRef)? {
  if cursor.index >= cursor.events.length() {
    return None
  }
  let start = cursor.events[cursor.index]
  match start.kind {
    @dyaml.YamlStructureEventKind::MappingStart => ()
    _ => return None
  }
  let keys : Array[String] = []
  let values : Array[String] = []
  cursor.index += 1
  let mut row_end = start.source.line_end
  while cursor.index < cursor.events.length() {
    let next = cursor.events[cursor.index]
    match next.kind {
      @dyaml.YamlStructureEventKind::Key => {
        let key = next.text.unwrap_or("")
        let member_path = next.source.path
        cursor.index += 1
        let value = yaml_event_value_summary(cursor, source, member_path)
        keys.push(key)
        values.push(value.0)
        row_end = value.1.line_end.unwrap_or(row_end)
      }
      @dyaml.YamlStructureEventKind::MappingEnd => {
        cursor.index += 1
        return Some(
          (
            keys,
            values,
            yaml_event_source_ref(
              source,
              path,
              start.source.line_start,
              next.source.line_end,
            ),
          ),
        )
      }
      _ => return None
    }
  }
  None
}

///|
fn yaml_append_table_events(
  out : Array[@core.CoreEvent],
  rows : Array[Array[String]],
  row_refs : Array[@core.SourceRef],
  source : @input.InputSource,
  path : String,
) -> Unit {
  let base_ref = if row_refs.length() > 0 {
    let first = row_refs[0]
    let last = row_refs[row_refs.length() - 1]
    @core.source_ref_with_lines(
      first,
      first.file_id,
      first.format,
      first.line_start,
      last.line_end,
    )
  } else {
    yaml_source_ref(source, path)
  }
  let block_ref = yaml_generic_block_ref(base_ref, @core.BlockKind::Table, [
    ("header_rows", "1"),
    ("table_column_count", rows[0].length().to_string()),
  ])
  out.push({
    kind: @core.EventKind::StartBlock(@core.BlockKind::Table),
    text: "table",
    source_ref: Some(block_ref),
  })
  for row_index in 0..<rows.length() {
    let row_ref = if row_index < row_refs.length() {
      row_refs[row_index]
    } else {
      yaml_source_ref(source, path)
    }
    for cell_index in 0..<rows[row_index].length() {
      out.push({
        kind: @core.EventKind::Cell,
        text: rows[row_index][cell_index],
        source_ref: Some(
          @core.source_ref_with_cell_range(
            row_ref,
            Some(source.source_name),
            Some("yaml"),
            Some(
              "R" +
              (row_index + 1).to_string() +
              "C" +
              (cell_index + 1).to_string(),
            ),
          ),
        ),
      })
    }
    out.push({
      kind: @core.EventKind::RowBreak,
      text: "",
      source_ref: Some(row_ref),
    })
  }
  out.push({
    kind: @core.EventKind::EndBlock(@core.BlockKind::Table),
    text: "",
    source_ref: Some(block_ref),
  })
}

///|
fn yaml_append_list_events(
  out : Array[@core.CoreEvent],
  values : Array[(String, @core.SourceRef)],
  source : @input.InputSource,
  path : String,
) -> Unit {
  let list_ref = yaml_generic_block_ref(
    yaml_source_ref(source, path),
    @core.BlockKind::List,
    [("ordered", "false")],
  )
  out.push({
    kind: @core.EventKind::StartBlock(@core.BlockKind::List),
    text: "",
    source_ref: Some(list_ref),
  })
  for value in values {
    let item_ref = yaml_generic_block_ref(value.1, @core.BlockKind::ListItem, [
      ("ordered", "false"),
      ("literal", "true"),
    ])
    out.push({
      kind: @core.EventKind::StartBlock(@core.BlockKind::ListItem),
      text: value.0,
      source_ref: Some(item_ref),
    })
    out.push({
      kind: @core.EventKind::EndBlock(@core.BlockKind::ListItem),
      text: "",
      source_ref: Some(item_ref),
    })
  }
  out.push({
    kind: @core.EventKind::EndBlock(@core.BlockKind::List),
    text: "",
    source_ref: Some(list_ref),
  })
}

///|
fn yaml_append_paragraph_events(
  out : Array[@core.CoreEvent],
  text : String,
  source_ref : @core.SourceRef,
) -> Unit {
  let block_ref = yaml_generic_block_ref(
    source_ref,
    @core.BlockKind::Paragraph,
    [("literal", "true")],
  )
  out.push({
    kind: @core.EventKind::StartBlock(@core.BlockKind::Paragraph),
    text,
    source_ref: Some(block_ref),
  })
  out.push({
    kind: @core.EventKind::EndBlock(@core.BlockKind::Paragraph),
    text: "",
    source_ref: Some(block_ref),
  })
}

///|
fn yaml_event_source_ref(
  source : @input.InputSource,
  path : String,
  line_start : Int,
  line_end : Int,
) -> @core.SourceRef {
  @core.source_ref_with_lines(
    yaml_source_ref(source, path),
    Some(source.source_name),
    Some("yaml"),
    Some(line_start),
    Some(line_end),
  )
}

///|
fn yaml_generic_block_ref(
  source_ref : @core.SourceRef,
  kind : @core.BlockKind,
  attrs : Array[(String, String)],
) -> @core.SourceRef {
  let next = source_ref
  next.extra.set("ir_event_encoding", "generic_block")
  next.extra.set("ir_block_kind", @core.block_kind_name(kind))
  for entry in attrs {
    next.extra.set("ir_block_attr_" + entry.0, entry.1)
  }
  next
}

///|
fn count_yaml_event_tables(events : Array[@core.CoreEvent]) -> Int {
  let mut count = 0
  for event in events {
    if event.kind == @core.EventKind::StartBlock(@core.BlockKind::Table) {
      count += 1
    }
  }
  count
}

///|
fn count_yaml_event_blocks(events : Array[@core.CoreEvent]) -> Int {
  let mut count = 0
  for event in events {
    match event.kind {
      @core.EventKind::StartBlock(_) => count += 1
      _ => ()
    }
  }
  count
}

///|
fn yaml_streaming_parse_result(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  inspect : @dyaml.YamlInspectReport,
  yaml_events : Array[@dyaml.YamlStructureEvent],
) -> @parser.ParseResult {
  let events = yaml_generic_block_events(yaml_events, source)
  diagnostics.metrics.set("parser_mode", "streaming_event")
  diagnostics.metrics.set("effective_mode", "streaming_event")
  diagnostics.metrics.set("ir_input_kind", "event_stream")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  yaml_fill_common_metrics(diagnostics, inspect, text, events.length())
  diagnostics.metrics.set(
    "table_count",
    count_yaml_event_tables(events).to_string(),
  )
  diagnostics.metrics.set(
    "block_count",
    count_yaml_event_blocks(events).to_string(),
  )
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
    Some(@parser_common.count_physical_lines(text)),
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
    @parser_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "yaml")
  diagnostics.metrics.set("requested_mode", "default")
  diagnostics.metrics.set("effective_mode", "dom_ast_model")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "none")
  diagnostics.metrics.set("event_semantics", "yaml_dom_ast_model_failed_closed")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  diagnostics.metrics.set("root_kind", "none")
  diagnostics.metrics.set(
    "is_empty",
    @parser_common.bool_string(text.trim() == ""),
  )
  diagnostics.metrics.set("syntax_error_count", "1")
  diagnostics.metrics.set(
    "line_count",
    @parser_common.count_physical_lines(text).to_string(),
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
