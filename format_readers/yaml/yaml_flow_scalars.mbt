///|
fn parse_block_scalar(
  lines : Array[YamlLine],
  line_index : Int,
  header : String,
  parent_indent : Int,
  line_no : Int,
) -> (Int, YamlValue) raise {
  let style = header[0]
  let stripped = header[1:].trim().to_owned()
  if stripped != "" {
    if stripped == "-" || stripped == "+" {
      ()
    } else if stripped.length() == 1 && stripped[0] >= '1' && stripped[0] <= '9' {
      ()
    } else if stripped.length() == 2 &&
      (
        (
          (stripped[0] >= '1' && stripped[0] <= '9') &&
          (stripped[1] == '-' || stripped[1] == '+')
        ) ||
        (
          (stripped[1] >= '1' && stripped[1] <= '9') &&
          (stripped[0] == '-' || stripped[0] == '+')
        )
      ) {
      ()
    } else {
      raise ParseError(
        "unsupported block scalar header at line " + line_no.to_string(),
      )
    }
  }
  let mut explicit_indent : Int? = None
  let mut chomping = 'c'
  for ch in stripped {
    if ch >= '1' && ch <= '9' {
      explicit_indent = Some(ch.to_int() - '0'.to_int())
    } else if ch == '+' || ch == '-' {
      chomping = ch
    }
  }
  let (next, text) = collect_block_scalar_lines(
    lines,
    line_index + 1,
    parent_indent,
    explicit_indent,
  )
  let styled = if style == '>' {
    yaml_fold_block_scalar_lines(text)
  } else {
    text
  }
  (next, String(yaml_apply_block_scalar_chomping(styled, chomping)))
}

///|
fn collect_block_scalar_lines(
  lines : Array[YamlLine],
  start : Int,
  parent_indent : Int,
  explicit_indent : Int?,
) -> (Int, String) {
  if start >= lines.length() {
    return (start, "")
  }
  let mut scalar_indent : Int? = explicit_indent.map(fn(value) {
    parent_indent + value
  })
  let parts : Array[String] = []
  let mut i = start
  while i < lines.length() {
    let line = lines[i]
    for _ in 0..<line.blank_lines_before {
      parts.push("")
    }
    if line.indent <= parent_indent {
      break
    }
    if scalar_indent is None {
      scalar_indent = Some(line.indent)
    }
    let effective_indent = scalar_indent.unwrap_or(line.indent)
    if line.indent < effective_indent {
      break
    }
    let strip = effective_indent
    let raw = if line.raw_content.length() <= strip {
      ""
    } else {
      line.raw_content[strip:].to_owned()
    }
    parts.push(raw)
    i += 1
  }
  (i, parts.join("\n"))
}

///|
fn yaml_apply_block_scalar_chomping(text : String, chomping : Char) -> String {
  if text == "" {
    return ""
  }
  let mut end = text.length()
  while end > 0 && text[end - 1] == '\n' {
    end -= 1
  }
  let body = text[:end].to_owned()
  match chomping {
    '-' => body
    '+' => text + "\n"
    _ => body + "\n"
  }
}

///|
fn yaml_fold_block_scalar_lines(text : String) -> String {
  let lines = text.split("\n").to_array()
  if lines.length() == 0 {
    return ""
  }
  let out = StringBuilder::new()
  let mut previous_blank = false
  for i in 0..<lines.length() {
    let line = lines[i].to_owned()
    let blank = line.trim() == ""
    if i > 0 {
      if blank || previous_blank {
        out.write_char('\n')
      } else {
        out.write_char(' ')
      }
    }
    out.write_string(line)
    previous_blank = blank
  }
  out.to_string()
}

///|
fn yaml_is_number_scalar(text : String) -> Bool {
  if text == "" {
    return false
  }
  let chars = text.to_array()
  let mut i = 0
  if chars[0] == '-' || chars[0] == '+' {
    if chars.length() == 1 {
      return false
    }
    i = 1
  }
  let mut saw_digit = false
  let mut saw_dot = false
  while i < chars.length() {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      saw_digit = true
      i += 1
      continue
    }
    if ch == '.' && !saw_dot {
      saw_dot = true
      i += 1
      continue
    }
    return false
  }
  saw_digit
}

///|
fn parse_flow_value(
  text : String,
  line_no : Int,
  profile_totals : YamlParseProfileTotals?,
) -> YamlValue raise {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    raise ParseError("empty flow value at line " + line_no.to_string())
  }
  parse_scalar_trimmed(trimmed, line_no, profile_totals)
}

///|
fn parse_flow_sequence(
  text : String,
  line_no : Int,
  profile_totals : YamlParseProfileTotals?,
) -> YamlValue raise {
  let chars = text.to_array()
  if chars.length() < 2 || chars[0] != '[' {
    raise ParseError("malformed flow sequence at line " + line_no.to_string())
  }
  if chars[chars.length() - 1] != ']' {
    raise ParseError("malformed flow sequence at line " + line_no.to_string())
  }

  let end = chars.length() - 1
  let inner = text[1:end].to_owned().trim().to_owned()
  let values : Array[YamlValue] = []
  if inner == "" {
    return Sequence(values)
  }

  let parts = split_flow_items(inner, line_no)
  for part in parts {
    values.push(parse_flow_value(part, line_no, profile_totals))
  }
  Sequence(values)
}

///|
fn parse_flow_mapping(
  text : String,
  line_no : Int,
  profile_totals : YamlParseProfileTotals?,
) -> YamlValue raise {
  let chars = text.to_array()
  if chars.length() < 2 || chars[0] != '{' {
    raise ParseError("malformed flow mapping at line " + line_no.to_string())
  }
  if chars[chars.length() - 1] != '}' {
    raise ParseError("malformed flow mapping at line " + line_no.to_string())
  }

  let end = chars.length() - 1
  let inner = text[1:end].to_owned().trim().to_owned()
  let members : Array[YamlMember] = []
  if inner == "" {
    return Mapping(members)
  }

  let parts = split_flow_items(inner, line_no)
  for part in parts {
    let colon = find_flow_mapping_colon(part, line_no)
    let raw_key = part[:colon].trim().to_owned()
    let raw_value = part[colon + 1:].trim().to_owned()
    if raw_value == "" {
      raise ParseError("empty flow value at line " + line_no.to_string())
    }
    let key = parse_key_text(raw_key, line_no)
    members.push({
      key,
      value: parse_flow_value(raw_value, line_no, profile_totals),
    })
  }
  Mapping(members)
}

///|
fn split_flow_items(text : String, line_no : Int) -> Array[String] raise {
  let chars = text.to_array()
  let items : Array[String] = []
  let mut start = 0
  let mut i = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
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

    match ch {
      '\'' => {
        in_single = true
        i += 1
        continue
      }
      '"' => {
        in_double = true
        i += 1
        continue
      }
      '[' => bracket_depth += 1
      ']' => {
        bracket_depth -= 1
        if bracket_depth < 0 {
          raise ParseError(
            "malformed flow sequence at line " + line_no.to_string(),
          )
        }
      }
      '{' => brace_depth += 1
      '}' => {
        brace_depth -= 1
        if brace_depth < 0 {
          raise ParseError(
            "malformed flow mapping at line " + line_no.to_string(),
          )
        }
      }
      ',' =>
        if bracket_depth == 0 && brace_depth == 0 {
          let item = text[start:i].trim().to_owned()
          if item == "" {
            raise ParseError(
              "malformed flow collection at line " + line_no.to_string(),
            )
          }
          items.push(item)
          start = i + 1
        }
      _ => ()
    }
    i += 1
  }

  if in_single || in_double || bracket_depth != 0 || brace_depth != 0 {
    raise ParseError("malformed flow collection at line " + line_no.to_string())
  }
  let item = text[start:].trim().to_owned()
  if item == "" {
    raise ParseError("malformed flow collection at line " + line_no.to_string())
  }
  items.push(item)
  items
}

///|
fn find_flow_mapping_colon(text : String, line_no : Int) -> Int raise {
  let chars = text.to_array()
  let mut i = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
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

    match ch {
      '\'' => {
        in_single = true
        i += 1
        continue
      }
      '"' => {
        in_double = true
        i += 1
        continue
      }
      '[' => bracket_depth += 1
      ']' => {
        bracket_depth -= 1
        if bracket_depth < 0 {
          raise ParseError(
            "malformed flow sequence at line " + line_no.to_string(),
          )
        }
      }
      '{' => brace_depth += 1
      '}' => {
        brace_depth -= 1
        if brace_depth < 0 {
          raise ParseError(
            "malformed flow mapping at line " + line_no.to_string(),
          )
        }
      }
      ':' => if bracket_depth == 0 && brace_depth == 0 { return i }
      _ => ()
    }
    i += 1
  }

  raise ParseError("malformed flow mapping at line " + line_no.to_string())
}

///|
fn parse_double_quoted_scalar(text : String, line_no : Int) -> String raise {
  let chars = text.to_array()
  if chars.length() < 2 || chars[0] != '"' || chars[chars.length() - 1] != '"' {
    raise ParseError(
      "unterminated double-quoted string at line " + line_no.to_string(),
    )
  }

  let out : Array[Char] = []
  let mut i = 1
  while i + 1 < chars.length() {
    let ch = chars[i]
    if ch == '\\' {
      if i + 1 >= chars.length() - 1 {
        raise ParseError("invalid escape at line " + line_no.to_string())
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
    raise ParseError(
      "unterminated single-quoted string at line " + line_no.to_string(),
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
