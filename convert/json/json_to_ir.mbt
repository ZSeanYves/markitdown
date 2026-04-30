///|
pub fn parse_json(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("json: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("json: read failed: " + e.to_string())
  }

  let text = @cor.utf8_bytes_to_string(bytes) catch {
    e => raise @cor.AppError("json: utf8 decode failed: " + e.to_string())
  }

  let value = parse_json_text(text)
  let doc = @cor.new_document()
  let src = @cor.basename(input_path)
  push_json_value(doc, value, src)
  doc
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
        @cor.Block::Table(object_rows(members)),
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
        match array_object_rows(values) {
          Some(rows) =>
            @cor.push_with_origin(doc, @cor.Block::Table(rows), origin)
          None =>
            @cor.push_with_origin(
              doc,
              @cor.Block::CodeBlock(stringify_json(value)),
              origin,
            )
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
        } else if !same_keys(keys, member_keys) {
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
fn same_keys(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
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
    _ => stringify_json(value)
  }
}

///|
fn scalar_text(value : JsonValue) -> String {
  match value {
    JsonValue::String(s) => s
    JsonValue::Number(n) => n
    JsonValue::Bool(b) => if b { "true" } else { "false" }
    JsonValue::Null => "null"
    _ => stringify_json(value)
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
