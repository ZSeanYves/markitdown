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
    Some("bytes=" + bytes.length().to_string()),
  )

  let decode_started = @env.now()
  let text = @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise @cor.AppError("json: utf8 decode failed: " + input_path)
  }
  json_profile_add_stage(
    profile,
    "json_bytes_to_string",
    @env.now() - decode_started,
    Some("chars=" + text.length().to_string()),
  )

  let normalize_started = @env.now()
  let normalized = normalize_json_source(text)
  json_profile_add_stage(
    profile,
    "json_normalize_source",
    @env.now() - normalize_started,
    Some("chars=" + normalized.length().to_string()),
  )

  let value = if profile_enabled {
    parse_json_text_profiled(normalized, profile)
  } else {
    parse_json_text(normalized)
  }
  let doc = @cor.new_document()
  let src = @cor.basename(input_path)
  let lowering_started = @env.now()
  json_profile_begin(profile_enabled)
  push_json_value(doc, value, src)
  let lowering_profile = json_profile_finish()
  json_profile_add_stage(
    profile,
    "json_detect_uniform_table",
    lowering_profile.uniform_table_detect_elapsed_ms,
    Some(
      "rows=" +
      lowering_profile.uniform_table_rows_seen.to_string() +
      " columns=" +
      lowering_profile.uniform_table_columns_seen.to_string(),
    ),
  )
  json_profile_add_stage(
    profile,
    "json_compact_stringify_nested",
    lowering_profile.nested_stringify_elapsed_ms,
    Some(
      "value_cell_calls=" +
      lowering_profile.value_cell_stringify_calls.to_string() +
      " scalar_calls=" +
      lowering_profile.scalar_text_stringify_calls.to_string(),
    ),
  )
  json_profile_add_stage(
    profile,
    "json_lower_to_ir",
    @env.now() - lowering_started,
    Some("blocks=" + doc.blocks.val.length().to_string()),
  )
  (doc, profile)
}

///|
fn normalize_json_source(text : String) -> String {
  let without_bom = if text.length() > 0 && text[0] == '\u{FEFF}' {
    text[1:].to_owned()
  } else {
    text
  }
  let out : Array[Char] = []
  let chars = without_bom.to_array()
  let mut i = 0

  while i < chars.length() {
    if chars[i] == '\r' {
      out.push('\n')
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i += 2
      } else {
        i += 1
      }
    } else {
      out.push(chars[i])
      i += 1
    }
  }

  String::from_array(out)
}

///|
fn push_json_value(
  doc : @cor.Document,
  value : JsonValue,
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
    JsonValue::Object(members) =>
      @cor.push_with_origin(
        doc,
        @cor.Block::RichTable({ rows: object_rows(members), header_rows: 1 }),
        origin,
      )
    JsonValue::Array(values) =>
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
              @cor.Block::RichTable({ rows, header_rows: 1 }),
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
    JsonValue::String(s) =>
      @cor.push_with_origin(doc, @cor.Block::Paragraph(s), origin)
    JsonValue::Number(n) =>
      @cor.push_with_origin(doc, @cor.Block::Paragraph(n), origin)
    JsonValue::Bool(b) =>
      @cor.push_with_origin(
        doc,
        @cor.Block::Paragraph(if b { "true" } else { "false" }),
        origin,
      )
    JsonValue::Null =>
      @cor.push_with_origin(doc, @cor.Block::Paragraph("null"), origin)
  }
}

///|
fn object_rows(members : Array[JsonMember]) -> Array[Array[String]] {
  let rows : Array[Array[String]] = [["Key", "Value"]]
  for entry in members {
    rows.push([entry.key, value_cell(entry.value)])
  }
  rows
}

///|
fn array_object_rows(values : Array[JsonValue]) -> Array[Array[String]]? {
  let mut keys : Array[String] = []
  let rows : Array[Array[String]] = []

  for i in 0..<values.length() {
    match values[i] {
      JsonValue::Object(members) => {
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
fn member_value_cell(members : Array[JsonMember], key : String) -> String {
  for entry in members {
    if entry.key == key {
      return value_cell(entry.value)
    }
  }
  ""
}

///|
fn is_array_of_scalars(values : Array[JsonValue]) -> Bool {
  for v in values {
    match v {
      JsonValue::String(_)
      | JsonValue::Number(_)
      | JsonValue::Bool(_)
      | JsonValue::Null => ()
      _ => return false
    }
  }
  true
}

///|
fn value_cell(value : JsonValue) -> String {
  match value {
    JsonValue::String(s) => s
    JsonValue::Number(n) => n
    JsonValue::Bool(b) => if b { "true" } else { "false" }
    JsonValue::Null => "null"
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
fn scalar_text(value : JsonValue) -> String {
  match value {
    JsonValue::String(s) => s
    JsonValue::Number(n) => n
    JsonValue::Bool(b) => if b { "true" } else { "false" }
    JsonValue::Null => "null"
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
fn stringify_json(value : JsonValue) -> String {
  match value {
    JsonValue::Object(members) => {
      let parts : Array[String] = []
      for entry in members {
        parts.push(
          quote_json_string(entry.key) + ":" + stringify_json(entry.value),
        )
      }
      "{" + parts.join(",") + "}"
    }
    JsonValue::Array(values) => {
      let parts : Array[String] = []
      for v in values {
        parts.push(stringify_json(v))
      }
      "[" + parts.join(",") + "]"
    }
    JsonValue::String(s) => quote_json_string(s)
    JsonValue::Number(n) => n
    JsonValue::Bool(b) => if b { "true" } else { "false" }
    JsonValue::Null => "null"
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
