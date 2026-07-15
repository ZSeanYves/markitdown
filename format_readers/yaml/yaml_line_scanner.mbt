///|
fn prepare_yaml_lines(
  text : String,
  profile_totals : YamlParseProfileTotals?,
  has_cr? : Bool? = None,
) -> Array[YamlLine] raise {
  let raw_lines = collect_yaml_raw_lines(text, profile_totals, has_cr~)

  let scan_started = match profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let lines : Array[YamlLine] = []
  let mut blank_lines_before = 0
  for i in 0..<raw_lines.length() {
    match prepare_yaml_line(raw_lines[i], i + 1, i == 0) {
      Some(line) => {
        lines.push({ ..line, blank_lines_before, })
        blank_lines_before = 0
      }
      None => if raw_lines[i].trim() == "" { blank_lines_before += 1 }
    }
  }
  let scan_total = match profile_totals {
    Some(totals) => Some(totals.scan_lines_elapsed_ms)
    None => None
  }
  yaml_parse_profile_add_elapsed(scan_total, scan_started)

  normalize_single_document_markers(lines)
}

///|
fn normalize_single_document_markers(
  lines : Array[YamlLine],
) -> Array[YamlLine] raise {
  let normalized : Array[YamlLine] = []
  let mut saw_content = false
  let mut saw_start_marker = false
  let mut saw_end_marker = false

  for i in 0..<lines.length() {
    let line = lines[i]
    if is_yaml_document_start_marker(line) {
      if saw_end_marker {
        raise ParseError(
          "multi-document markers are unsupported at line " +
          line.line_no.to_string(),
        )
      }
      if saw_content {
        if i == lines.length() - 1 {
          continue
        }
        raise ParseError(
          "multi-document markers are unsupported at line " +
          line.line_no.to_string(),
        )
      }
      if saw_start_marker {
        raise ParseError(
          "multi-document markers are unsupported at line " +
          line.line_no.to_string(),
        )
      }
      saw_start_marker = true
      continue
    }

    if is_yaml_document_end_marker(line) {
      if saw_end_marker || (!saw_content && !saw_start_marker) {
        raise ParseError(
          "multi-document markers are unsupported at line " +
          line.line_no.to_string(),
        )
      }
      saw_end_marker = true
      continue
    }

    if saw_end_marker {
      raise ParseError(
        "multi-document markers are unsupported at line " +
        line.line_no.to_string(),
      )
    }

    saw_content = true
    normalized.push(line)
  }

  normalized
}

///|
fn is_yaml_document_start_marker(line : YamlLine) -> Bool {
  line.indent == 0 && line.content == "---"
}

///|
fn is_yaml_document_end_marker(line : YamlLine) -> Bool {
  line.indent == 0 && line.content == "..."
}

///|
fn collect_yaml_raw_lines(
  text : String,
  profile_totals : YamlParseProfileTotals?,
  has_cr? : Bool? = None,
) -> Array[String] {
  let normalize_started = match profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let raw_lines : Array[String] = []
  if !has_cr.unwrap_or_else(fn() { text.contains("\r") }) {
    for line in text.split("\n") {
      raw_lines.push(line.to_owned())
    }
    let normalize_total = match profile_totals {
      Some(totals) => Some(totals.normalize_lines_elapsed_ms)
      None => None
    }
    yaml_parse_profile_add_elapsed(normalize_total, normalize_started)
    return raw_lines
  }
  let chars = text.to_array()
  let mut current : Array[Char] = []
  let mut i = 0

  while i < chars.length() {
    let ch = chars[i]
    if ch == '\r' {
      raw_lines.push(String::from_array(current))
      current = []
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i += 2
      } else {
        i += 1
      }
      continue
    }
    if ch == '\n' {
      raw_lines.push(String::from_array(current))
      current = []
      i += 1
      continue
    }
    current.push(ch)
    i += 1
  }

  raw_lines.push(String::from_array(current))
  let normalize_total = match profile_totals {
    Some(totals) => Some(totals.normalize_lines_elapsed_ms)
    None => None
  }
  yaml_parse_profile_add_elapsed(normalize_total, normalize_started)
  raw_lines
}

///|
fn prepare_yaml_line(
  raw_line : String,
  line_no : Int,
  is_first_line : Bool,
) -> YamlLine? raise {
  let raw = if is_first_line { strip_bom(raw_line) } else { raw_line }
  if raw.contains("\t") {
    raise ParseError(
      "tabs are unsupported for indentation at line " + line_no.to_string(),
    )
  }
  let mut indent = 0
  while indent < raw.length() && raw.code_unit_at(indent).to_int() == 32 {
    indent += 1
  }
  let body = raw[indent:]
  let needs_inline_comment_scan = body.contains("#")
  let content = if needs_inline_comment_scan {
    strip_inline_comment(body.to_owned()).trim().to_owned()
  } else {
    trim_right_spaces(body)
  }
  if content == "" {
    return None
  }
  if indent != 0 && (content == "---" || content == "...") {
    raise ParseError(
      "multi-document markers are unsupported at line " + line_no.to_string(),
    )
  }

  Some({ indent, content, line_no, raw_content: raw, blank_lines_before: 0 })
}

///|
fn strip_bom(line : String) -> String {
  if line.length() > 0 && line[0] == '\u{FEFF}' {
    line[1:].to_owned()
  } else {
    line
  }
}

///|
fn trim_right_spaces(text : StringView) -> String {
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 && chars[end - 1] == ' ' {
    end -= 1
  }
  if end == chars.length() {
    text.to_owned()
  } else {
    text[:end].to_owned()
  }
}

///|
fn strip_inline_comment(line : String) -> String {
  let chars = line.to_array()
  let out : Array[Char] = []
  let mut i = 0
  let mut in_single = false
  let mut in_double = false

  while i < chars.length() {
    let ch = chars[i]

    if in_single {
      out.push(ch)
      if ch == '\'' {
        if i + 1 < chars.length() && chars[i + 1] == '\'' {
          out.push(chars[i + 1])
          i += 2
          continue
        }
        in_single = false
      }
      i += 1
      continue
    }

    if in_double {
      out.push(ch)
      if ch == '\\' && i + 1 < chars.length() {
        out.push(chars[i + 1])
        i += 2
        continue
      }
      if ch == '"' {
        in_double = false
      }
      i += 1
      continue
    }

    if ch == '\'' {
      in_single = true
      out.push(ch)
      i += 1
      continue
    }
    if ch == '"' {
      in_double = true
      out.push(ch)
      i += 1
      continue
    }
    if ch == '#' && (i == 0 || chars[i - 1] == ' ') {
      break
    }

    out.push(ch)
    i += 1
  }

  String::from_array(out)
}

///|
fn split_mapping_entry(content : String) -> (String, String)? {
  match find_mapping_colon(content) {
    Some(index) => {
      let key = content[:index].trim().to_owned()
      let value = content[index + 1:].trim().to_owned()
      Some((key, value))
    }
    None => None
  }
}

///|
fn find_mapping_colon(content : String) -> Int? {
  let chars = content.to_array()
  let mut i = 0
  let mut in_single = false
  let mut in_double = false

  while i < chars.length() {
    let ch = chars[i]

    if in_single {
      if ch == '\'' {
        if i + 1 < chars.length() && chars[i + 1] == '\'' {
          i += 2
          continue
        }
        in_single = false
      }
      i += 1
      continue
    }

    if in_double {
      if ch == '\\' && i + 1 < chars.length() {
        i += 2
        continue
      }
      if ch == '"' {
        in_double = false
      }
      i += 1
      continue
    }

    if ch == '\'' {
      in_single = true
      i += 1
      continue
    }
    if ch == '"' {
      in_double = true
      i += 1
      continue
    }

    if ch == ':' && (i + 1 == chars.length() || chars[i + 1] == ' ') {
      return Some(i)
    }
    i += 1
  }

  None
}

///|
fn is_sequence_item(content : String) -> Bool {
  let chars = content.to_array()
  chars.length() > 0 &&
  chars[0] == '-' &&
  (chars.length() == 1 || chars[1] == ' ')
}

///|
fn sequence_item_rest(content : String) -> String {
  if content == "-" {
    ""
  } else {
    content[2:].trim().to_owned()
  }
}

///|
/// Return a stable human-readable kind label for a parsed YAML value.
pub fn yaml_value_kind(value : YamlValue) -> String {
  match value {
    Mapping(_) => "mapping"
    Sequence(_) => "sequence"
    String(_) => "string"
    Number(_) => "number"
    Bool(_) => "bool"
    Null => "null"
  }
}

///|
fn append_yaml_structure_events(
  events : Array[YamlStructureEvent],
  value : YamlValue,
  line_start : Int,
  line_end : Int,
  path : String,
  depth : Int,
) -> Unit {
  match value {
    Mapping(members) => {
      events.push({
        kind: MappingStart,
        text: None,
        source: { line_start, line_end, path, depth },
      })
      for entry in members {
        let member_path = yaml_member_path(path, entry.key)
        events.push({
          kind: Key,
          text: Some(entry.key),
          source: { line_start, line_end, path: member_path, depth: depth + 1 },
        })
        append_yaml_structure_events(
          events,
          entry.value,
          line_start,
          line_end,
          member_path,
          depth + 1,
        )
      }
      events.push({
        kind: MappingEnd,
        text: None,
        source: { line_start, line_end, path, depth },
      })
    }
    Sequence(values) => {
      events.push({
        kind: SequenceStart,
        text: None,
        source: { line_start, line_end, path, depth },
      })
      for i in 0..<values.length() {
        append_yaml_structure_events(
          events,
          values[i],
          line_start,
          line_end,
          yaml_index_path(path, i),
          depth + 1,
        )
      }
      events.push({
        kind: SequenceEnd,
        text: None,
        source: { line_start, line_end, path, depth },
      })
    }
    String(text) =>
      events.push({
        kind: StringValue,
        text: Some(text),
        source: { line_start, line_end, path, depth },
      })
    Number(text) =>
      events.push({
        kind: NumberValue,
        text: Some(text),
        source: { line_start, line_end, path, depth },
      })
    Bool(value) =>
      events.push({
        kind: BoolValue,
        text: Some(if value { "true" } else { "false" }),
        source: { line_start, line_end, path, depth },
      })
    Null =>
      events.push({
        kind: NullValue,
        text: Some("null"),
        source: { line_start, line_end, path, depth },
      })
  }
}

///|
fn yaml_member_path(parent : String, key : String) -> String {
  if parent == "/" {
    "/" + key
  } else {
    parent + "/" + key
  }
}

///|
fn yaml_index_path(parent : String, index : Int) -> String {
  parent + "[" + index.to_string() + "]"
}

///|

///|
