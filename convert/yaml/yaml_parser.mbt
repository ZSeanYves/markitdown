///|
priv enum YamlValue {
  Mapping(Array[YamlMember])
  Sequence(Array[YamlValue])
  String(String)
  Bool(Bool)
  Null
}

///|
priv struct YamlMember {
  key : String
  value : YamlValue
}

///|
priv struct YamlLine {
  indent : Int
  content : String
  line_no : Int
}

///|
fn parse_yaml_text(text : String) -> YamlValue? raise {
  let lines = prepare_yaml_lines(text)
  if lines.length() == 0 {
    return None
  }

  let indent = lines[0].indent
  let (next, value) = parse_block(lines, 0, indent)
  if next < lines.length() {
    raise @cor.AppError(
      "yaml: unexpected trailing content at line " +
      lines[next].line_no.to_string(),
    )
  }
  Some(value)
}

///|
fn parse_block(
  lines : Array[YamlLine],
  start : Int,
  indent : Int,
) -> (Int, YamlValue) raise {
  if start >= lines.length() {
    raise @cor.AppError("yaml: unexpected end of input")
  }

  let line = lines[start]
  if line.indent != indent {
    raise @cor.AppError(
      "yaml: unexpected indentation at line " + line.line_no.to_string(),
    )
  }

  if is_sequence_item(line.content) {
    parse_sequence(lines, start, indent)
  } else {
    match split_mapping_entry(line.content) {
      Some(_) => parse_mapping(lines, start, indent)
      None => {
        if start + 1 < lines.length() && lines[start + 1].indent > indent {
          raise @cor.AppError(
            "yaml: scalar cannot own nested block at line " +
            line.line_no.to_string(),
          )
        }
        (start + 1, parse_scalar(line.content, line.line_no))
      }
    }
  }
}

///|
fn parse_mapping(
  lines : Array[YamlLine],
  start : Int,
  indent : Int,
) -> (Int, YamlValue) raise {
  let (next, members) = consume_mapping_members(lines, start, indent)
  (next, YamlValue::Mapping(members))
}

///|
fn consume_mapping_members(
  lines : Array[YamlLine],
  start : Int,
  indent : Int,
) -> (Int, Array[YamlMember]) raise {
  let members : Array[YamlMember] = []
  let mut i = start

  while i < lines.length() {
    let line = lines[i]
    if line.indent < indent {
      break
    }
    if line.indent > indent {
      raise @cor.AppError(
        "yaml: unexpected indentation at line " + line.line_no.to_string(),
      )
    }

    let (raw_key, raw_value) = match split_mapping_entry(line.content) {
      Some(parts) => parts
      None =>
        raise @cor.AppError(
          "yaml: expected mapping entry at line " + line.line_no.to_string(),
        )
    }

    let key = parse_key_text(raw_key, line.line_no)
    let mut next = i + 1
    let value = if raw_value != "" {
      parse_scalar(raw_value, line.line_no)
    } else if next < lines.length() && lines[next].indent > indent {
      let child_indent = lines[next].indent
      let (after, child) = parse_block(lines, next, child_indent)
      next = after
      child
    } else {
      YamlValue::Null
    }

    members.push({ key, value })
    i = next
  }

  (i, members)
}

///|
fn parse_sequence(
  lines : Array[YamlLine],
  start : Int,
  indent : Int,
) -> (Int, YamlValue) raise {
  let values : Array[YamlValue] = []
  let mut i = start

  while i < lines.length() {
    let line = lines[i]
    if line.indent < indent {
      break
    }
    if line.indent > indent {
      raise @cor.AppError(
        "yaml: unexpected indentation at line " + line.line_no.to_string(),
      )
    }
    if !is_sequence_item(line.content) {
      raise @cor.AppError(
        "yaml: expected sequence item at line " + line.line_no.to_string(),
      )
    }

    let (next, value) = parse_sequence_item(lines, i, indent)
    values.push(value)
    i = next
  }

  (i, YamlValue::Sequence(values))
}

///|
fn parse_sequence_item(
  lines : Array[YamlLine],
  index : Int,
  indent : Int,
) -> (Int, YamlValue) raise {
  let line = lines[index]
  let rest = sequence_item_rest(line.content)
  if rest == "" {
    if index + 1 < lines.length() && lines[index + 1].indent > indent {
      let child_indent = lines[index + 1].indent
      return parse_block(lines, index + 1, child_indent)
    }
    return (index + 1, YamlValue::Null)
  }

  match split_mapping_entry(rest) {
    Some((raw_key, raw_value)) => {
      let key = parse_key_text(raw_key, line.line_no)
      let members : Array[YamlMember] = []
      let mut next = index + 1
      let first_value = if raw_value != "" {
        parse_scalar(raw_value, line.line_no)
      } else if next < lines.length() && lines[next].indent > indent {
        let child_indent = lines[next].indent
        let (after, child) = parse_block(lines, next, child_indent)
        next = after
        child
      } else {
        YamlValue::Null
      }

      members.push({ key, value: first_value })

      if next < lines.length() && lines[next].indent > indent {
        let continuation_indent = lines[next].indent
        let (after, extra_members) = consume_mapping_members(
          lines, next, continuation_indent,
        )
        for entry in extra_members {
          members.push(entry)
        }
        next = after
      }

      (next, YamlValue::Mapping(members))
    }
    None => (index + 1, parse_scalar(rest, line.line_no))
  }
}

///|
fn parse_key_text(raw_key : String, line_no : Int) -> String raise {
  let key = raw_key.trim().to_owned()
  if key == "" {
    raise @cor.AppError("yaml: empty key at line " + line_no.to_string())
  }
  if key.has_prefix("[") || key.has_prefix("{") || key.has_prefix("?") {
    raise @cor.AppError(
      "yaml: complex keys are unsupported at line " + line_no.to_string(),
    )
  }

  if key.has_prefix("\"") {
    parse_double_quoted_scalar(key, line_no)
  } else if key.has_prefix("'") {
    parse_single_quoted_scalar(key, line_no)
  } else {
    key
  }
}

///|
fn parse_scalar(text : String, line_no : Int) -> YamlValue raise {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return YamlValue::String("")
  }

  if trimmed == "true" {
    return YamlValue::Bool(true)
  }
  if trimmed == "false" {
    return YamlValue::Bool(false)
  }
  if trimmed == "null" || trimmed == "~" {
    return YamlValue::Null
  }

  if trimmed.has_prefix("|") || trimmed.has_prefix(">") {
    raise @cor.AppError(
      "yaml: block scalars are unsupported at line " + line_no.to_string(),
    )
  }
  if trimmed.has_prefix("{") || trimmed.has_prefix("[") {
    raise @cor.AppError(
      "yaml: flow style is unsupported at line " + line_no.to_string(),
    )
  }
  if trimmed.has_prefix("&") ||
    trimmed.has_prefix("*") ||
    trimmed.has_prefix("!") {
    raise @cor.AppError(
      "yaml: anchors, aliases, and tags are unsupported at line " +
      line_no.to_string(),
    )
  }

  if trimmed.has_prefix("\"") {
    return YamlValue::String(parse_double_quoted_scalar(trimmed, line_no))
  }
  if trimmed.has_prefix("'") {
    return YamlValue::String(parse_single_quoted_scalar(trimmed, line_no))
  }

  YamlValue::String(trimmed)
}

///|
fn parse_double_quoted_scalar(text : String, line_no : Int) -> String raise {
  let chars = text.to_array()
  if chars.length() < 2 || chars[0] != '"' || chars[chars.length() - 1] != '"' {
    raise @cor.AppError(
      "yaml: unterminated double-quoted string at line " + line_no.to_string(),
    )
  }

  let out : Array[Char] = []
  let mut i = 1
  while i + 1 < chars.length() {
    let ch = chars[i]
    if ch == '\\' {
      if i + 1 >= chars.length() - 1 {
        raise @cor.AppError(
          "yaml: invalid escape at line " + line_no.to_string(),
        )
      }
      let esc = chars[i + 1]
      match esc {
        '"' => out.push('"')
        '\\' => out.push('\\')
        'n' => out.push('\n')
        'r' => out.push('\r')
        't' => out.push('\t')
        _ => out.push(esc)
      }
      i += 2
      continue
    }
    out.push(ch)
    i += 1
  }

  String::from_array(out)
}

///|
fn parse_single_quoted_scalar(text : String, line_no : Int) -> String raise {
  let chars = text.to_array()
  if chars.length() < 2 || chars[0] != '\'' || chars[chars.length() - 1] != '\'' {
    raise @cor.AppError(
      "yaml: unterminated single-quoted string at line " + line_no.to_string(),
    )
  }

  let out : Array[Char] = []
  let mut i = 1
  while i + 1 < chars.length() {
    let ch = chars[i]
    if ch == '\'' && i + 1 < chars.length() - 1 && chars[i + 1] == '\'' {
      out.push('\'')
      i += 2
      continue
    }
    out.push(ch)
    i += 1
  }

  String::from_array(out)
}

///|
fn prepare_yaml_lines(text : String) -> Array[YamlLine] raise {
  let normalized = text
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
  let raw_lines : Array[String] = normalized
    .split("\n")
    .map(fn(line) { line.to_owned() })
    .iter()
    .collect()

  let lines : Array[YamlLine] = []
  for i in 0..<raw_lines.length() {
    let raw = if i == 0 { strip_bom(raw_lines[i]) } else { raw_lines[i] }
    if contains_tab(raw) {
      raise @cor.AppError(
        "yaml: tabs are unsupported for indentation at line " +
        (i + 1).to_string(),
      )
    }

    let indent = leading_spaces(raw)
    let content = strip_inline_comment(raw[indent:].to_owned())
      .trim()
      .to_owned()
    if content == "" {
      continue
    }
    if content == "---" || content == "..." {
      raise @cor.AppError(
        "yaml: multi-document markers are unsupported at line " +
        (i + 1).to_string(),
      )
    }

    lines.push({ indent, content, line_no: i + 1 })
  }

  lines
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
fn contains_tab(line : String) -> Bool {
  for ch in line.to_array() {
    if ch == '\t' {
      return true
    }
  }
  false
}

///|
fn leading_spaces(line : String) -> Int {
  let chars = line.to_array()
  let mut i = 0
  while i < chars.length() && chars[i] == ' ' {
    i += 1
  }
  i
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
      let key = content[:index].to_owned()
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
