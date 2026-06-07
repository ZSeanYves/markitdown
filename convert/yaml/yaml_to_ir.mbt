///|
pub fn parse_yaml(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  parse_yaml_with_profile(input_path, _out_dir, _max_heading).0
}

///|
pub fn parse_yaml_with_profile(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> (@cor.Document, YamlProfileReport?) raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("yaml: file not found: " + input_path)
  }

  let profile = if yaml_profile_enabled() {
    Some(new_yaml_profile_report(input_path))
  } else {
    None
  }
  yaml_profile_set_active(profile)
  defer yaml_profile_set_active(None)

  let read_started = match profile {
    Some(_) => @env.now()
    None => 0
  }
  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("yaml: read failed: " + e.to_string())
  }
  yaml_profile_add_stage(
    profile,
    "yaml_file_read",
    match profile {
      Some(_) => @env.now() - read_started
      None => 0
    },
    match profile {
      Some(_) => Some("bytes=" + bytes.length().to_string())
      None => None
    },
  )

  let decode_started = match profile {
    Some(_) => @env.now()
    None => 0
  }
  let raw = decode_yaml_utf8_text(bytes) catch {
    e => raise @cor.AppError("yaml: utf8 decode failed: " + e.to_string())
  }
  yaml_profile_add_stage(
    profile,
    "yaml_bytes_to_string",
    match profile {
      Some(_) => @env.now() - decode_started
      None => 0
    },
    match profile {
      Some(_) => Some("chars=" + raw.length().to_string())
      None => None
    },
  )

  let doc = @cor.new_document()
  let src = @cor.basename(input_path)

  let parse_started = match profile {
    Some(_) => @env.now()
    None => 0
  }
  let parsed = @dpyaml.parse_yaml_document(raw)
  match parsed.root {
    Some(value) => {
      let lower_started = match profile {
        Some(_) => @env.now()
        None => 0
      }
      push_yaml_value_with_profile(doc, value, src)
      yaml_profile_add_stage(
        profile,
        "yaml_to_ir",
        match profile {
          Some(_) => @env.now() - lower_started
          None => 0
        },
        match profile {
          Some(_) => Some("blocks=" + doc.blocks.val.length().to_string())
          None => None
        },
      )
    }
    None => ()
  }
  yaml_profile_add_stage(
    profile,
    "yaml_parse_model",
    match profile {
      Some(_) => @env.now() - parse_started
      None => 0
    },
    match profile {
      Some(_) => Some("blocks=" + doc.blocks.val.length().to_string())
      None => None
    },
  )

  (doc, profile)
}

///|
fn decode_yaml_utf8_text(bytes : Bytes) -> String raise {
  let decoded = @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise @cor.Utf8DecodeError("yaml: invalid utf8")
  }

  if !contains_non_bmp_char(decoded) {
    return decoded
  }

  let out = StringBuilder::new()
  for ch in decoded.to_array() {
    let cp = ch.to_int()
    if cp > 0xFFFF {
      out.write_string("&#" + cp.to_string() + ";")
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn contains_non_bmp_char(text : String) -> Bool {
  for ch in text.to_array() {
    if ch.to_int() > 0xFFFF {
      return true
    }
  }
  false
}

///|
fn push_yaml_value_with_profile(
  doc : @cor.Document,
  value : @dpyaml.YamlValue,
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
    @dpyaml.YamlValue::Mapping(members) => {
      let profile_active = yaml_profile_active_enabled()
      let detect_started = if profile_active { @env.now() } else { 0 }
      let rows = object_rows(members)
      if profile_active {
        yaml_profile_add_active_stage(
          "yaml_detect_table",
          @env.now() - detect_started,
          Some("kind=mapping rows=" + rows.length().to_string()),
        )
      }
      @cor.push_with_origin(
        doc,
        @cor.Block::RichTable({ rows, header_rows: 1, hints: None }),
        origin,
      )
    }
    @dpyaml.YamlValue::Sequence(values) =>
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
        let profile_active = yaml_profile_active_enabled()
        let detect_started = if profile_active { @env.now() } else { 0 }
        match array_object_rows(values) {
          Some(rows) => {
            if profile_active {
              yaml_profile_add_active_stage(
                "yaml_detect_table",
                @env.now() - detect_started,
                Some("kind=sequence_table rows=" + rows.length().to_string()),
              )
            }
            @cor.push_with_origin(
              doc,
              @cor.Block::RichTable({ rows, header_rows: 1, hints: None }),
              origin,
            )
          }
          None => {
            if profile_active {
              yaml_profile_add_active_stage(
                "yaml_detect_table",
                @env.now() - detect_started,
                Some("kind=sequence_fallback"),
              )
            }
            @cor.push_with_origin(
              doc,
              @cor.Block::CodeBlock(stringify_yaml_block(value, 0)),
              origin,
            )
          }
        }
      }
    @dpyaml.YamlValue::String(s) =>
      @cor.push_with_origin(doc, @cor.Block::Paragraph(s), origin)
    @dpyaml.YamlValue::Bool(b) =>
      @cor.push_with_origin(
        doc,
        @cor.Block::Paragraph(if b { "true" } else { "false" }),
        origin,
      )
    @dpyaml.YamlValue::Null =>
      @cor.push_with_origin(doc, @cor.Block::Paragraph("null"), origin)
  }
}

///|
fn object_rows(members : Array[@dpyaml.YamlMember]) -> Array[Array[String]] {
  let rows : Array[Array[String]] = [["Key", "Value"]]
  for entry in members {
    rows.push([entry.key, value_cell(entry.value)])
  }
  rows
}

///|
fn array_object_rows(
  values : Array[@dpyaml.YamlValue],
) -> Array[Array[String]]? {
  let mut keys : Array[String] = []
  let rows : Array[Array[String]] = []

  for i in 0..<values.length() {
    match values[i] {
      @dpyaml.YamlValue::Mapping(members) => {
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
fn member_value_cell(
  members : Array[@dpyaml.YamlMember],
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
fn is_array_of_scalars(values : Array[@dpyaml.YamlValue]) -> Bool {
  for v in values {
    match v {
      @dpyaml.YamlValue::String(_)
      | @dpyaml.YamlValue::Bool(_)
      | @dpyaml.YamlValue::Null => ()
      _ => return false
    }
  }
  true
}

///|
fn value_cell(value : @dpyaml.YamlValue) -> String {
  match value {
    @dpyaml.YamlValue::String(s) => s
    @dpyaml.YamlValue::Bool(b) => if b { "true" } else { "false" }
    @dpyaml.YamlValue::Null => "null"
    _ => stringify_yaml_inline(value)
  }
}

///|
fn scalar_text(value : @dpyaml.YamlValue) -> String {
  match value {
    @dpyaml.YamlValue::String(s) => s
    @dpyaml.YamlValue::Bool(b) => if b { "true" } else { "false" }
    @dpyaml.YamlValue::Null => "null"
    _ => stringify_yaml_inline(value)
  }
}

///|
fn stringify_yaml_inline(value : @dpyaml.YamlValue) -> String {
  match value {
    @dpyaml.YamlValue::Mapping(members) => {
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
    @dpyaml.YamlValue::Sequence(values) => {
      let parts : Array[String] = []
      for item in values {
        parts.push(stringify_yaml_inline(item))
      }
      "[" + parts.join(", ") + "]"
    }
    @dpyaml.YamlValue::String(s) =>
      if needs_quotes(s) {
        quote_yaml_string(s)
      } else {
        s
      }
    @dpyaml.YamlValue::Bool(b) => if b { "true" } else { "false" }
    @dpyaml.YamlValue::Null => "null"
  }
}

///|
fn stringify_yaml_block(value : @dpyaml.YamlValue, indent : Int) -> String {
  let prefix = "  ".repeat(indent)
  match value {
    @dpyaml.YamlValue::Mapping(members) => {
      let lines : Array[String] = []
      for entry in members {
        match entry.value {
          @dpyaml.YamlValue::String(_)
          | @dpyaml.YamlValue::Bool(_)
          | @dpyaml.YamlValue::Null =>
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
    @dpyaml.YamlValue::Sequence(values) => {
      let lines : Array[String] = []
      for item in values {
        match item {
          @dpyaml.YamlValue::String(_)
          | @dpyaml.YamlValue::Bool(_)
          | @dpyaml.YamlValue::Null =>
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
