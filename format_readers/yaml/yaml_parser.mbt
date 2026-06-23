///|
/// Parse a YAML-subset document into a source-native model.
///
/// This parser is intentionally conservative. Unsupported YAML features raise
/// hard parse errors instead of being converted into product policy.
pub fn parse_yaml_document(text : String) -> YamlDocument raise {
  parse_yaml_document_with_profile(text, None, None)
}

///|
/// Parse a YAML-subset document into a source-native model plus deterministic
/// structure events for next-native streaming lowering.
pub fn parse_yaml_structure_document(
  text : String,
) -> YamlStructureDocument raise {
  let lines = prepare_yaml_lines(text, None)
  if lines.length() == 0 {
    return { document: { root: None }, events: [] }
  }
  let indent = lines[0].indent
  let (next, root) = parse_block(lines, 0, indent, None)
  if next < lines.length() {
    raise ParseError(
      "unexpected trailing content at line " + lines[next].line_no.to_string(),
    )
  }
  let events : Array[YamlStructureEvent] = []
  append_yaml_structure_events(
    events,
    root,
    lines[0].line_no,
    lines[next - 1].line_no,
    "/",
    0,
  )
  { document: { root: Some(root) }, events }
}

///|
/// Benchmark-oriented profiled parse helper used for internal hotspot
/// attribution.
///
/// This does not change the source-native YAML subset model or converter
/// behavior.
pub fn profile_yaml_document(text : String) -> YamlProfiledDocument raise {
  let report = new_yaml_parse_profile_report()
  let totals = new_yaml_parse_profile_totals()
  let document = parse_yaml_document_with_profile(
    text,
    Some(report),
    Some(totals),
  )
  yaml_parse_profile_finish_totals(Some(report), Some(totals))
  { document, report }
}

///|
/// Classify a hard YAML parse failure into a stable error kind.
pub fn classify_yaml_error(err : YamlError) -> YamlErrorInfo {
  let detail = err.to_string().to_lower()
  let kind = if detail.contains("unexpected end of input") {
    YamlErrorKind::UnexpectedEnd
  } else if detail.contains("unexpected indentation") {
    YamlErrorKind::UnexpectedIndentation
  } else if detail.contains("unexpected trailing content") {
    YamlErrorKind::TrailingContent
  } else if detail.contains("empty key") {
    YamlErrorKind::EmptyKey
  } else if detail.contains("expected mapping entry") {
    YamlErrorKind::ExpectedMappingEntry
  } else if detail.contains("expected sequence item") {
    YamlErrorKind::ExpectedSequenceItem
  } else if detail.contains("unterminated double-quoted string") ||
    detail.contains("unterminated single-quoted string") {
    YamlErrorKind::UnterminatedQuotedScalar
  } else if detail.contains("invalid escape") {
    YamlErrorKind::InvalidEscape
  } else if detail.contains("tabs are unsupported") {
    YamlErrorKind::TabsUnsupported
  } else if detail.contains("multi-document markers are unsupported") {
    YamlErrorKind::MultiDocumentUnsupported
  } else if detail.contains("unsupported") {
    YamlErrorKind::UnsupportedFeature
  } else {
    YamlErrorKind::Unknown
  }
  { kind, detail: err.to_string() }
}

///|
priv struct YamlLine {
  indent : Int
  content : String
  line_no : Int
}

///|
fn parse_yaml_document_with_profile(
  text : String,
  profile : YamlParseProfileReport?,
  profile_totals : YamlParseProfileTotals?,
) -> YamlDocument raise {
  let lines = prepare_yaml_lines(text, profile_totals)
  if lines.length() == 0 {
    let build_started = yaml_parse_profile_stage_started(profile)
    let doc = { root: None }
    match profile {
      Some(_) =>
        yaml_parse_profile_stage_finished(
          profile,
          "build_document",
          build_started,
          Some("root=none"),
        )
      None => ()
    }
    return doc
  }

  let parse_started = yaml_parse_profile_stage_started(profile)
  let indent = lines[0].indent
  let (next, root) = parse_block(lines, 0, indent, profile_totals)
  if next < lines.length() {
    raise ParseError(
      "unexpected trailing content at line " + lines[next].line_no.to_string(),
    )
  }
  match profile {
    Some(_) =>
      yaml_parse_profile_stage_finished(
        profile,
        "parse_nodes",
        parse_started,
        Some("lines=" + lines.length().to_string()),
      )
    None => ()
  }

  let build_started = yaml_parse_profile_stage_started(profile)
  let doc = { root: Some(root) }
  match profile {
    Some(_) =>
      yaml_parse_profile_stage_finished(
        profile,
        "build_document",
        build_started,
        Some("root=" + yaml_value_kind(root)),
      )
    None => ()
  }
  doc
}

///|
fn parse_block(
  lines : Array[YamlLine],
  start : Int,
  indent : Int,
  profile_totals : YamlParseProfileTotals?,
) -> (Int, YamlValue) raise {
  if start >= lines.length() {
    raise ParseError("unexpected end of input")
  }

  let line = lines[start]
  if line.indent != indent {
    raise ParseError(
      "unexpected indentation at line " + line.line_no.to_string(),
    )
  }

  if is_sequence_item(line.content) {
    parse_sequence(lines, start, indent, profile_totals)
  } else if line.content.has_prefix("[") || line.content.has_prefix("{") {
    if start + 1 < lines.length() && lines[start + 1].indent > indent {
      raise ParseError(
        "scalar cannot own nested block at line " + line.line_no.to_string(),
      )
    }
    (
      start + 1,
      parse_scalar_trimmed(line.content, line.line_no, profile_totals),
    )
  } else {
    match split_mapping_entry(line.content) {
      Some(_) => parse_mapping(lines, start, indent, profile_totals)
      None => {
        if start + 1 < lines.length() && lines[start + 1].indent > indent {
          raise ParseError(
            "scalar cannot own nested block at line " + line.line_no.to_string(),
          )
        }
        (
          start + 1,
          parse_scalar_trimmed(line.content, line.line_no, profile_totals),
        )
      }
    }
  }
}

///|
fn parse_mapping(
  lines : Array[YamlLine],
  start : Int,
  indent : Int,
  profile_totals : YamlParseProfileTotals?,
) -> (Int, YamlValue) raise {
  let mapping_started = match profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let mapping_total = match profile_totals {
    Some(totals) => Some(totals.parse_mapping_elapsed_ms)
    None => None
  }
  let (next, members) = consume_mapping_members(
    lines, start, indent, profile_totals,
  )
  let value = (next, YamlValue::Mapping(members))
  yaml_parse_profile_add_elapsed(mapping_total, mapping_started)
  value
}

///|
fn consume_mapping_members(
  lines : Array[YamlLine],
  start : Int,
  indent : Int,
  profile_totals : YamlParseProfileTotals?,
) -> (Int, Array[YamlMember]) raise {
  let members : Array[YamlMember] = []
  let mut i = start

  while i < lines.length() {
    let line = lines[i]
    if line.indent < indent {
      break
    }
    if line.indent > indent {
      raise ParseError(
        "unexpected indentation at line " + line.line_no.to_string(),
      )
    }

    let (raw_key, raw_value) = match split_mapping_entry(line.content) {
      Some(parts) => parts
      None =>
        raise ParseError(
          "expected mapping entry at line " + line.line_no.to_string(),
        )
    }

    let key = parse_key_text(raw_key, line.line_no)
    let mut next = i + 1
    let has_sequence_child_at_same_indent = next < lines.length() &&
      lines[next].indent == indent &&
      is_sequence_item(lines[next].content)
    let value = if raw_value != "" {
      parse_scalar_trimmed(raw_value, line.line_no, profile_totals)
    } else if next < lines.length() &&
      (lines[next].indent > indent || has_sequence_child_at_same_indent) {
      let child_indent = lines[next].indent
      let (after, child) = parse_mapping_child_block(
        lines, next, child_indent, profile_totals,
      )
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
fn parse_mapping_child_block(
  lines : Array[YamlLine],
  start : Int,
  indent : Int,
  profile_totals : YamlParseProfileTotals?,
) -> (Int, YamlValue) raise {
  if start < lines.length() && is_sequence_item(lines[start].content) {
    parse_sequence_mapping_child(lines, start, indent, profile_totals)
  } else {
    parse_block(lines, start, indent, profile_totals)
  }
}

///|
fn parse_sequence(
  lines : Array[YamlLine],
  start : Int,
  indent : Int,
  profile_totals : YamlParseProfileTotals?,
) -> (Int, YamlValue) raise {
  let sequence_started = match profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let sequence_total = match profile_totals {
    Some(totals) => Some(totals.parse_sequence_elapsed_ms)
    None => None
  }
  let values : Array[YamlValue] = []
  let mut i = start

  while i < lines.length() {
    let line = lines[i]
    if line.indent < indent {
      break
    }
    if line.indent > indent {
      raise ParseError(
        "unexpected indentation at line " + line.line_no.to_string(),
      )
    }
    if !is_sequence_item(line.content) {
      raise ParseError(
        "expected sequence item at line " + line.line_no.to_string(),
      )
    }

    let (next, value) = parse_sequence_item(lines, i, indent, profile_totals)
    values.push(value)
    i = next
  }

  let value = (i, YamlValue::Sequence(values))
  yaml_parse_profile_add_elapsed(sequence_total, sequence_started)
  value
}

///|
fn parse_sequence_mapping_child(
  lines : Array[YamlLine],
  start : Int,
  indent : Int,
  profile_totals : YamlParseProfileTotals?,
) -> (Int, YamlValue) raise {
  let sequence_started = match profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let sequence_total = match profile_totals {
    Some(totals) => Some(totals.parse_sequence_elapsed_ms)
    None => None
  }
  let values : Array[YamlValue] = []
  let mut i = start

  while i < lines.length() {
    let line = lines[i]
    if line.indent < indent {
      break
    }
    if line.indent > indent {
      raise ParseError(
        "unexpected indentation at line " + line.line_no.to_string(),
      )
    }
    if !is_sequence_item(line.content) {
      break
    }

    let (next, value) = parse_sequence_item(lines, i, indent, profile_totals)
    values.push(value)
    i = next
  }

  let value = (i, YamlValue::Sequence(values))
  yaml_parse_profile_add_elapsed(sequence_total, sequence_started)
  value
}

///|
fn parse_sequence_item(
  lines : Array[YamlLine],
  index : Int,
  indent : Int,
  profile_totals : YamlParseProfileTotals?,
) -> (Int, YamlValue) raise {
  let line = lines[index]
  let rest = sequence_item_rest(line.content)
  if rest == "" {
    if index + 1 < lines.length() && lines[index + 1].indent > indent {
      let child_indent = lines[index + 1].indent
      return parse_block(lines, index + 1, child_indent, profile_totals)
    }
    return (index + 1, YamlValue::Null)
  }
  if rest.has_prefix("[") || rest.has_prefix("{") {
    return (index + 1, parse_scalar_trimmed(rest, line.line_no, profile_totals))
  }

  match split_mapping_entry(rest) {
    Some((raw_key, raw_value)) => {
      let key = parse_key_text(raw_key, line.line_no)
      let members : Array[YamlMember] = []
      let mut next = index + 1
      let has_sequence_child_at_same_indent = next < lines.length() &&
        lines[next].indent == indent &&
        is_sequence_item(lines[next].content)
      let first_value = if raw_value != "" {
        parse_scalar_trimmed(raw_value, line.line_no, profile_totals)
      } else if next < lines.length() &&
        (lines[next].indent > indent || has_sequence_child_at_same_indent) {
        let child_indent = lines[next].indent
        let (after, child) = parse_mapping_child_block(
          lines, next, child_indent, profile_totals,
        )
        next = after
        child
      } else {
        YamlValue::Null
      }

      members.push({ key, value: first_value })

      if next < lines.length() && lines[next].indent > indent {
        let continuation_indent = lines[next].indent
        let (after, extra_members) = consume_mapping_members(
          lines, next, continuation_indent, profile_totals,
        )
        for entry in extra_members {
          members.push(entry)
        }
        next = after
      }
      (next, YamlValue::Mapping(members))
    }
    None =>
      (index + 1, parse_scalar_trimmed(rest, line.line_no, profile_totals))
  }
}

///|
fn parse_key_text(raw_key : String, line_no : Int) -> String raise {
  let key = raw_key
  if key == "" {
    raise ParseError("empty key at line " + line_no.to_string())
  }
  if key.has_prefix("[") || key.has_prefix("{") || key.has_prefix("?") {
    raise ParseError(
      "complex keys are unsupported at line " + line_no.to_string(),
    )
  }
  if key == "<<" ||
    key.has_prefix("&") ||
    key.has_prefix("*") ||
    key.has_prefix("!") {
    raise ParseError(
      "anchors, aliases, and tags are unsupported at line " +
      line_no.to_string(),
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
fn parse_scalar_trimmed(
  trimmed : String,
  line_no : Int,
  profile_totals : YamlParseProfileTotals?,
) -> YamlValue raise {
  let scalar_started = match profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let scalar_total = match profile_totals {
    Some(totals) => Some(totals.parse_scalar_elapsed_ms)
    None => None
  }
  if trimmed == "" {
    let value = YamlValue::String("")
    yaml_parse_profile_add_elapsed(scalar_total, scalar_started)
    return value
  }

  if trimmed == "true" {
    let value = YamlValue::Bool(true)
    yaml_parse_profile_add_elapsed(scalar_total, scalar_started)
    return value
  }
  if trimmed == "false" {
    let value = YamlValue::Bool(false)
    yaml_parse_profile_add_elapsed(scalar_total, scalar_started)
    return value
  }
  if trimmed == "null" || trimmed == "~" {
    let value = YamlValue::Null
    yaml_parse_profile_add_elapsed(scalar_total, scalar_started)
    return value
  }

  if trimmed.has_prefix("|") || trimmed.has_prefix(">") {
    raise ParseError(
      "block scalars are unsupported at line " + line_no.to_string(),
    )
  }
  if trimmed.has_prefix("[") {
    let value = parse_flow_sequence(trimmed, line_no, profile_totals)
    yaml_parse_profile_add_elapsed(scalar_total, scalar_started)
    return value
  }
  if trimmed.has_prefix("{") {
    let value = parse_flow_mapping(trimmed, line_no, profile_totals)
    yaml_parse_profile_add_elapsed(scalar_total, scalar_started)
    return value
  }
  if trimmed.has_prefix("&") ||
    trimmed.has_prefix("*") ||
    trimmed.has_prefix("!") {
    raise ParseError(
      "anchors, aliases, and tags are unsupported at line " +
      line_no.to_string(),
    )
  }

  if trimmed.has_prefix("\"") {
    let value = YamlValue::String(parse_double_quoted_scalar(trimmed, line_no))
    yaml_parse_profile_add_elapsed(scalar_total, scalar_started)
    return value
  }
  if trimmed.has_prefix("'") {
    let value = YamlValue::String(parse_single_quoted_scalar(trimmed, line_no))
    yaml_parse_profile_add_elapsed(scalar_total, scalar_started)
    return value
  }

  let value = YamlValue::String(trimmed)
  yaml_parse_profile_add_elapsed(scalar_total, scalar_started)
  value
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
    return YamlValue::Sequence(values)
  }

  let parts = split_flow_items(inner, line_no)
  for part in parts {
    values.push(parse_flow_value(part, line_no, profile_totals))
  }
  YamlValue::Sequence(values)
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
    return YamlValue::Mapping(members)
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
  YamlValue::Mapping(members)
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

///|
fn prepare_yaml_lines(
  text : String,
  profile_totals : YamlParseProfileTotals?,
) -> Array[YamlLine] raise {
  let raw_lines = collect_yaml_raw_lines(text, profile_totals)

  let scan_started = match profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let lines : Array[YamlLine] = []
  for i in 0..<raw_lines.length() {
    match prepare_yaml_line(raw_lines[i], i + 1, i == 0) {
      Some(line) => lines.push(line)
      None => ()
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
) -> Array[String] {
  let normalize_started = match profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let chars = text.to_array()
  let raw_lines : Array[String] = []
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
  let chars = raw.to_array()
  let mut indent = 0
  let mut in_leading_indent = true
  let mut needs_inline_comment_scan = false

  for ch in chars {
    if ch == '\t' {
      raise ParseError(
        "tabs are unsupported for indentation at line " + line_no.to_string(),
      )
    }
    if in_leading_indent && ch == ' ' {
      indent += 1
      continue
    }
    in_leading_indent = false
    if ch == '#' || ch == '\'' || ch == '"' {
      needs_inline_comment_scan = true
    }
  }

  let body = raw[indent:]
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

  Some({ indent, content, line_no })
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
    YamlValue::Mapping(_) => "mapping"
    YamlValue::Sequence(_) => "sequence"
    YamlValue::String(_) => "string"
    YamlValue::Bool(_) => "bool"
    YamlValue::Null => "null"
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
    YamlValue::Mapping(members) => {
      events.push({
        kind: YamlStructureEventKind::MappingStart,
        text: None,
        source: { line_start, line_end, path, depth },
      })
      for entry in members {
        let member_path = yaml_member_path(path, entry.key)
        events.push({
          kind: YamlStructureEventKind::Key,
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
        kind: YamlStructureEventKind::MappingEnd,
        text: None,
        source: { line_start, line_end, path, depth },
      })
    }
    YamlValue::Sequence(values) => {
      events.push({
        kind: YamlStructureEventKind::SequenceStart,
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
        kind: YamlStructureEventKind::SequenceEnd,
        text: None,
        source: { line_start, line_end, path, depth },
      })
    }
    YamlValue::String(text) =>
      events.push({
        kind: YamlStructureEventKind::StringValue,
        text: Some(text),
        source: { line_start, line_end, path, depth },
      })
    YamlValue::Bool(value) =>
      events.push({
        kind: YamlStructureEventKind::BoolValue,
        text: Some(if value { "true" } else { "false" }),
        source: { line_start, line_end, path, depth },
      })
    YamlValue::Null =>
      events.push({
        kind: YamlStructureEventKind::NullValue,
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
