///|
pub fn parse_json(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  parse_json_with_profile(input_path, _out_dir, _max_heading).0
}

///|
pub fn parse_json_with_profile(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> (@cor.Document, JsonProfileReport?) raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("json: file not found: " + input_path)
  }

  let profile = if json_profile_enabled_for_run() {
    Some(new_json_profile_report(input_path))
  } else {
    None
  }
  let profile_enabled = match profile {
    Some(_) => true
    None => false
  }

  let read_started = @env.now()
  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("json: read failed: " + e.to_string())
  }
  json_profile_add_stage(
    profile,
    "json_file_read",
    @env.now() - read_started,
    match profile {
      Some(_) => Some("bytes=" + bytes.length().to_string())
      None => None
    },
  )

  let decode_started = @env.now()
  let text = @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise @cor.AppError("json: utf8 decode failed: " + input_path)
  }
  json_profile_add_stage(
    profile,
    "json_bytes_to_string",
    @env.now() - decode_started,
    match profile {
      Some(_) => Some("chars=" + text.length().to_string())
      None => None
    },
  )

  let parse_started = @env.now()
  let parsed = @dpjson.parse_json_document(text)
  let value = parsed.root
  json_profile_add_stage(
    profile,
    "json_parse_total",
    @env.now() - parse_started,
    match profile {
      Some(_) =>
        Some(
          "chars=" +
          text.length().to_string() +
          " root=" +
          @dpjson.json_value_kind(value),
        )
      None => None
    },
  )
  let doc = @cor.new_document()
  let src = @cor.basename(input_path)
  let lowering_started = @env.now()
  json_profile_begin(profile_enabled)
  push_json_value(doc, value, src)
  let (
    value_cell_stringify_calls,
    scalar_text_stringify_calls,
    uniform_table_rows_seen,
    uniform_table_columns_seen,
    nested_stringify_elapsed_ms,
    uniform_table_detect_elapsed_ms,
  ) = json_profile_finish()
  json_profile_add_stage(
    profile,
    "json_detect_uniform_table",
    uniform_table_detect_elapsed_ms,
    match profile {
      Some(_) =>
        Some(
          "rows=" +
          uniform_table_rows_seen.to_string() +
          " columns=" +
          uniform_table_columns_seen.to_string(),
        )
      None => None
    },
  )
  json_profile_add_stage(
    profile,
    "json_compact_stringify_nested",
    nested_stringify_elapsed_ms,
    match profile {
      Some(_) =>
        Some(
          "value_cell_calls=" +
          value_cell_stringify_calls.to_string() +
          " scalar_calls=" +
          scalar_text_stringify_calls.to_string(),
        )
      None => None
    },
  )
  json_profile_add_stage(
    profile,
    "json_lower_to_ir",
    @env.now() - lowering_started,
    match profile {
      Some(_) => Some("blocks=" + doc.blocks.val.length().to_string())
      None => None
    },
  )
  (doc, profile)
}

///|
fn push_json_value(
  doc : @cor.Document,
  value : @dpjson.JsonValue,
  src : String,
) -> Unit {
  let origin : @cor.Origin? = Some({
    source_name: Some(src),
    page: None,
    slide: None,
    sheet: None,
    block_index: Some(doc.blocks.val.length()),
    heading_path: None,
    line_start: None,
    line_end: None,
    row_index: None,
    column_index: None,
    object_ref: None,
    relationship_id: None,
    key_path: Some("$"),
  })

  match value {
    @dpjson.JsonValue::Object(members) =>
      @cor.push_with_origin(
        doc,
        @cor.Block::RichTable({
          rows: object_rows(members),
          header_rows: 1,
          hints: None,
        }),
        origin,
      )
    @dpjson.JsonValue::Array(values) =>
      if values.length() == 0 {
        @cor.push_with_origin(doc, @cor.Block::CodeBlock("[]"), origin)
      } else if is_array_of_scalars(values) {
        for v in values {
          let item_origin : @cor.Origin? = Some({
            source_name: Some(src),
            page: None,
            slide: None,
            sheet: None,
            block_index: Some(doc.blocks.val.length()),
            heading_path: None,
            line_start: None,
            line_end: None,
            row_index: None,
            column_index: None,
            object_ref: None,
            relationship_id: None,
            key_path: Some("$"),
          })
          @cor.push_with_origin(
            doc,
            @cor.Block::ListItem(false, 0, scalar_text(v)),
            item_origin,
          )
        }
      } else {
        let detect_started = @env.now()
        match array_object_rows(values) {
          Some(rows) => {
            profile_uniform_table_detect_elapsed_ms(
              @env.now() - detect_started,
              rows.length(),
              if rows.length() == 0 {
                0
              } else {
                rows[0].length()
              },
            )
            @cor.push_with_origin(
              doc,
              @cor.Block::RichTable({ rows, header_rows: 1, hints: None }),
              origin,
            )
          }
          None => {
            profile_uniform_table_detect_elapsed_ms(
              @env.now() - detect_started,
              0,
              0,
            )
            let stringify_started = @env.now()
            let text = stringify_json(value)
            profile_nested_stringify_elapsed_ms(@env.now() - stringify_started)
            @cor.push_with_origin(doc, @cor.Block::CodeBlock(text), origin)
          }
        }
      }
    @dpjson.JsonValue::String(s) =>
      @cor.push_with_origin(doc, @cor.Block::Paragraph(s), origin)
    @dpjson.JsonValue::Number(n) =>
      @cor.push_with_origin(doc, @cor.Block::Paragraph(n), origin)
    @dpjson.JsonValue::Bool(b) =>
      @cor.push_with_origin(
        doc,
        @cor.Block::Paragraph(if b { "true" } else { "false" }),
        origin,
      )
    @dpjson.JsonValue::Null =>
      @cor.push_with_origin(doc, @cor.Block::Paragraph("null"), origin)
  }
}

///|
fn object_rows(members : Array[@dpjson.JsonMember]) -> Array[Array[String]] {
  let rows : Array[Array[String]] = [["Key", "Value"]]
  for entry in members {
    rows.push([entry.key, value_cell(entry.value)])
  }
  rows
}

///|
fn array_object_rows(
  values : Array[@dpjson.JsonValue],
) -> Array[Array[String]]? {
  let mut keys : Array[String] = []
  let rows : Array[Array[String]] = []

  for i in 0..<values.length() {
    match values[i] {
      @dpjson.JsonValue::Object(members) => {
        let member_keys = members.map(fn(m) { m.key })
        if i == 0 {
          keys = member_keys
          rows.push(keys)
        } else if !same_key_set(keys, member_keys) {
          return None
        }

        let row : Array[String] = []
        for key in keys {
          row.push(member_value_cell(members, key))
        }
        rows.push(row)
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
fn same_key_set(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for key in a {
    if !contains_key(b, key) {
      return false
    }
  }
  true
}

///|
fn contains_key(keys : Array[String], target : String) -> Bool {
  for key in keys {
    if key == target {
      return true
    }
  }
  false
}

///|
fn member_value_cell(
  members : Array[@dpjson.JsonMember],
  key : String,
) -> String {
  for entry in members {
    if entry.key == key {
      return value_cell(entry.value)
    }
  }
  ""
}

///|
fn is_array_of_scalars(values : Array[@dpjson.JsonValue]) -> Bool {
  for v in values {
    match v {
      @dpjson.JsonValue::String(_)
      | @dpjson.JsonValue::Number(_)
      | @dpjson.JsonValue::Bool(_)
      | @dpjson.JsonValue::Null => ()
      _ => return false
    }
  }
  true
}

///|
fn value_cell(value : @dpjson.JsonValue) -> String {
  match value {
    @dpjson.JsonValue::String(s) => s
    @dpjson.JsonValue::Number(n) => n
    @dpjson.JsonValue::Bool(b) => if b { "true" } else { "false" }
    @dpjson.JsonValue::Null => "null"
    _ => {
      profile_value_cell_stringify_call()
      let started = @env.now()
      let text = stringify_json(value)
      profile_nested_stringify_elapsed_ms(@env.now() - started)
      text
    }
  }
}

///|
fn scalar_text(value : @dpjson.JsonValue) -> String {
  match value {
    @dpjson.JsonValue::String(s) => s
    @dpjson.JsonValue::Number(n) => n
    @dpjson.JsonValue::Bool(b) => if b { "true" } else { "false" }
    @dpjson.JsonValue::Null => "null"
    _ => {
      profile_scalar_text_stringify_call()
      let started = @env.now()
      let text = stringify_json(value)
      profile_nested_stringify_elapsed_ms(@env.now() - started)
      text
    }
  }
}

///|
fn json_profile_enabled_for_run() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_JSON") {
    Some(raw) => {
      let value = raw.trim().to_lower()
      value == "1" || value == "true" || value == "yes" || value == "on"
    }
    None => false
  }
}

///|
fn stringify_json(value : @dpjson.JsonValue) -> String {
  match value {
    @dpjson.JsonValue::Object(members) => {
      let parts : Array[String] = []
      for entry in members {
        parts.push(
          quote_json_string(entry.key) + ":" + stringify_json(entry.value),
        )
      }
      "{" + parts.join(",") + "}"
    }
    @dpjson.JsonValue::Array(values) => {
      let parts : Array[String] = []
      for v in values {
        parts.push(stringify_json(v))
      }
      "[" + parts.join(",") + "]"
    }
    @dpjson.JsonValue::String(s) => quote_json_string(s)
    @dpjson.JsonValue::Number(n) => n
    @dpjson.JsonValue::Bool(b) => if b { "true" } else { "false" }
    @dpjson.JsonValue::Null => "null"
  }
}

///|
fn quote_json_string(s : String) -> String {
  let out : Array[Char] = ['"']
  for ch in s.to_array() {
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
