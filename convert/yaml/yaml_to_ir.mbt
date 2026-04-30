///|
pub fn parse_yaml(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("yaml: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("yaml: read failed: " + e.to_string())
  }

  let text = @cor.utf8_bytes_to_string(bytes) catch {
    e => raise @cor.AppError("yaml: utf8 decode failed: " + e.to_string())
  }

  let doc = @cor.new_document()
  let src = @cor.basename(input_path)

  match parse_yaml_text(text) {
    Some(value) => push_yaml_value(doc, value, src)
    None => ()
  }

  doc
}

///|
fn push_yaml_value(
  doc : @cor.Document,
  value : YamlValue,
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
    YamlValue::Mapping(members) =>
      @cor.push_with_origin(
        doc,
        @cor.Block::Table(object_rows(members)),
        origin,
      )
    YamlValue::Sequence(values) =>
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
              @cor.Block::CodeBlock(stringify_yaml_block(value, 0)),
              origin,
            )
        }
      }
    YamlValue::String(s) =>
      @cor.push_with_origin(doc, @cor.Block::Paragraph(s), origin)
    YamlValue::Bool(b) =>
      @cor.push_with_origin(
        doc,
        @cor.Block::Paragraph(if b { "true" } else { "false" }),
        origin,
      )
    YamlValue::Null =>
      @cor.push_with_origin(doc, @cor.Block::Paragraph("null"), origin)
  }
}

///|
fn object_rows(members : Array[YamlMember]) -> Array[Array[String]] {
  let rows : Array[Array[String]] = [["Key", "Value"]]
  for entry in members {
    rows.push([entry.key, value_cell(entry.value)])
  }
  rows
}

///|
fn array_object_rows(values : Array[YamlValue]) -> Array[Array[String]]? {
  let mut keys : Array[String] = []
  let rows : Array[Array[String]] = []

  for i in 0..<values.length() {
    match values[i] {
      YamlValue::Mapping(members) => {
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
fn member_value_cell(members : Array[YamlMember], key : String) -> String {
  for entry in members {
    if entry.key == key {
      return value_cell(entry.value)
    }
  }
  ""
}

///|
fn is_array_of_scalars(values : Array[YamlValue]) -> Bool {
  for v in values {
    match v {
      YamlValue::String(_) | YamlValue::Bool(_) | YamlValue::Null => ()
      _ => return false
    }
  }
  true
}

///|
fn value_cell(value : YamlValue) -> String {
  match value {
    YamlValue::String(s) => s
    YamlValue::Bool(b) => if b { "true" } else { "false" }
    YamlValue::Null => "null"
    _ => stringify_yaml_inline(value)
  }
}

///|
fn scalar_text(value : YamlValue) -> String {
  match value {
    YamlValue::String(s) => s
    YamlValue::Bool(b) => if b { "true" } else { "false" }
    YamlValue::Null => "null"
    _ => stringify_yaml_inline(value)
  }
}

///|
fn stringify_yaml_inline(value : YamlValue) -> String {
  match value {
    YamlValue::Mapping(members) => {
      let parts : Array[String] = []
      for entry in members {
        parts.push(
          stringify_yaml_key(entry.key) +
          ": " +
          stringify_yaml_inline(entry.value),
        )
      }
      "{" + parts.join(", ") + "}"
    }
    YamlValue::Sequence(values) => {
      let parts : Array[String] = []
      for item in values {
        parts.push(stringify_yaml_inline(item))
      }
      "[" + parts.join(", ") + "]"
    }
    YamlValue::String(s) =>
      if needs_quotes(s) {
        quote_yaml_string(s)
      } else {
        s
      }
    YamlValue::Bool(b) => if b { "true" } else { "false" }
    YamlValue::Null => "null"
  }
}

///|
fn stringify_yaml_block(value : YamlValue, indent : Int) -> String {
  let prefix = "  ".repeat(indent)
  match value {
    YamlValue::Mapping(members) => {
      let lines : Array[String] = []
      for entry in members {
        match entry.value {
          YamlValue::String(_) | YamlValue::Bool(_) | YamlValue::Null =>
            lines.push(
              prefix +
              stringify_yaml_key(entry.key) +
              ": " +
              stringify_yaml_inline(entry.value),
            )
          _ => {
            lines.push(prefix + stringify_yaml_key(entry.key) + ":")
            lines.push(stringify_yaml_block(entry.value, indent + 1))
          }
        }
      }
      lines.join("\n")
    }
    YamlValue::Sequence(values) => {
      let lines : Array[String] = []
      for item in values {
        match item {
          YamlValue::String(_) | YamlValue::Bool(_) | YamlValue::Null =>
            lines.push(prefix + "- " + stringify_yaml_inline(item))
          _ => {
            lines.push(prefix + "-")
            lines.push(stringify_yaml_block(item, indent + 1))
          }
        }
      }
      lines.join("\n")
    }
    _ => stringify_yaml_inline(value)
  }
}

///|
fn stringify_yaml_key(key : String) -> String {
  if needs_quotes(key) {
    quote_yaml_string(key)
  } else {
    key
  }
}

///|
fn needs_quotes(text : String) -> Bool {
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
fn quote_yaml_string(text : String) -> String {
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
