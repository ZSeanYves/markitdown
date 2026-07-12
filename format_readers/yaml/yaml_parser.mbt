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
  let document = parse_yaml_document(text)
  let events : Array[YamlStructureEvent] = []
  match document.root {
    Some(root) =>
      append_yaml_structure_events(
        events,
        root,
        1,
        yaml_source_line_count(text),
        "/",
        0,
      )
    None => ()
  }
  { document, events }
}

///|
/// Parse a YAML-subset document into deterministic structure events without
/// constructing the source-native document tree.
pub fn parse_yaml_structure_events(
  text : String,
) -> Array[YamlStructureEvent] raise {
  parse_yaml_structure_document(text).events
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
  raw_content : String
  blank_lines_before : Int
}

///|
priv struct YamlAliasResolver {
  anchors : Map[String, YamlValue]
  mut anchor_count : Int
  mut alias_count : Int
}

///|
let yaml_anchor_marker_prefix : String = "\u{0000}yaml-anchor:"

///|
let yaml_alias_marker_prefix : String = "\u{0000}yaml-alias:"

///|
fn parse_yaml_document_with_profile(
  text : String,
  profile : YamlParseProfileReport?,
  profile_totals : YamlParseProfileTotals?,
) -> YamlDocument raise {
  let text_flags = yaml_scan_text_flags(text)
  let may_have_references = text_flags.0
  let document_texts = split_yaml_document_texts(
    text,
    may_contain_stream_control=Some(text_flags.1),
  )
  if document_texts.length() > 1 {
    let documents : Array[YamlValue] = []
    for document_text in document_texts {
      match
        parse_yaml_document_with_profile(document_text, None, profile_totals).root {
        Some(root) => documents.push(root)
        None => documents.push(YamlValue::Null)
      }
    }
    return { root: Some(YamlValue::Sequence(documents)) }
  }
  let text = if document_texts.length() == 1 { document_texts[0] } else { "" }
  let lines = prepare_yaml_lines(
    text,
    profile_totals,
    has_cr=if text_flags.1 { None } else { Some(text_flags.2) },
  )
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
  let doc = if may_have_references {
    let resolver = { anchors: Map([]), anchor_count: 0, alias_count: 0 }
    { root: Some(resolve_yaml_aliases(root, resolver)) }
  } else {
    { root: Some(root) }
  }
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
fn yaml_scan_text_flags(text : String) -> (Bool, Bool, Bool) {
  let mut may_have_references = false
  let mut may_contain_stream_control = false
  let mut has_cr = false
  let mut previous_was_angle = false
  let mut index = 0
  let mut at_line_start = true
  while index < text.length() {
    let unit = text.code_unit_at(index).to_int()
    if unit == 38 || unit == 42 || (unit == 60 && previous_was_angle) {
      may_have_references = true
    }
    if at_line_start && unit == 37 {
      may_contain_stream_control = true
    }
    if at_line_start && index + 2 < text.length() {
      let second = text.code_unit_at(index + 1).to_int()
      let third = text.code_unit_at(index + 2).to_int()
      if (unit == 45 && second == 45 && third == 45) ||
        (unit == 46 && second == 46 && third == 46) {
        may_contain_stream_control = true
      }
    }
    previous_was_angle = unit == 60
    if unit == 13 {
      has_cr = true
    }
    at_line_start = unit == 10 || unit == 13
    index += 1
  }
  (may_have_references, may_contain_stream_control, has_cr)
}

///|
fn split_yaml_document_texts(
  text : String,
  may_contain_stream_control? : Bool? = None,
) -> Array[String] raise {
  let has_stream_control = may_contain_stream_control.unwrap_or_else(fn() {
    yaml_may_contain_stream_control(text)
  })
  if !has_stream_control {
    return [text]
  }
  let normalized = text
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
  let lines = normalized.split("\n").to_array()
  let documents : Array[String] = []
  let current : Array[String] = []
  let mut saw_marker = false
  let mut closed = false
  for index in 0..<lines.length() {
    let line = lines[index].to_owned()
    let trimmed = line.trim().to_owned()
    if line.length() == trimmed.length() && trimmed.has_prefix("%") {
      raise ParseError(
        "YAML directives are unsupported at line " + (index + 1).to_string(),
      )
    }
    let marker = if line.length() == trimmed.length() {
      yaml_stream_marker(trimmed)
    } else {
      ""
    }
    if marker == "start" {
      saw_marker = true
      if yaml_document_lines_have_content(current) {
        documents.push(current.join("\n"))
      }
      current.clear()
      closed = false
      continue
    }
    if marker == "end" {
      saw_marker = true
      if yaml_document_lines_have_content(current) {
        documents.push(current.join("\n"))
      }
      current.clear()
      closed = true
      continue
    }
    if closed && trimmed != "" && !trimmed.has_prefix("#") {
      raise ParseError(
        "content after document end requires a new start marker at line " +
        (index + 1).to_string(),
      )
    }
    current.push(line)
  }
  if yaml_document_lines_have_content(current) {
    documents.push(current.join("\n"))
  }
  if !saw_marker {
    return [text]
  }
  documents
}

///|
fn yaml_may_contain_stream_control(text : String) -> Bool {
  yaml_scan_text_flags(text).1
}

///|
fn yaml_stream_marker(trimmed : String) -> String {
  if trimmed == "---" || trimmed.has_prefix("--- #") {
    "start"
  } else if trimmed == "..." || trimmed.has_prefix("... #") {
    "end"
  } else {
    ""
  }
}

///|
fn yaml_document_lines_have_content(lines : Array[String]) -> Bool {
  lines.any(line => {
    let trimmed = line.trim()
    trimmed != "" && !trimmed.has_prefix("#")
  })
}

///|
fn yaml_source_line_count(text : String) -> Int {
  if text == "" {
    0
  } else {
    let mut count = 1
    for ch in text {
      if ch == '\n' {
        count += 1
      }
    }
    count
  }
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
    let anchor_only = yaml_anchor_name_only(raw_value)
    let value = if anchor_only is Some(_) &&
      next < lines.length() &&
      (lines[next].indent > indent || has_sequence_child_at_same_indent) {
      let child_indent = lines[next].indent
      let (after, child) = parse_mapping_child_block(
        lines, next, child_indent, profile_totals,
      )
      next = after
      yaml_anchor_wrapper(anchor_only.unwrap(), child)
    } else if raw_value != "" {
      let (after, scalar) = parse_inline_or_block_scalar(
        lines,
        i,
        raw_value,
        line.indent,
        line.line_no,
        profile_totals,
      )
      next = after
      scalar
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
  match yaml_anchor_name_only(rest) {
    Some(name) => {
      if index + 1 < lines.length() && lines[index + 1].indent > indent {
        let child_indent = lines[index + 1].indent
        let (next, child) = parse_block(
          lines,
          index + 1,
          child_indent,
          profile_totals,
        )
        return (next, yaml_anchor_wrapper(name, child))
      }
      raise ParseError(
        "anchor requires a value at line " + line.line_no.to_string(),
      )
    }
    None => ()
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
      let anchor_only = yaml_anchor_name_only(raw_value)
      let first_value = if anchor_only is Some(_) &&
        next < lines.length() &&
        (lines[next].indent > indent || has_sequence_child_at_same_indent) {
        let child_indent = lines[next].indent
        let (after, child) = parse_mapping_child_block(
          lines, next, child_indent, profile_totals,
        )
        next = after
        yaml_anchor_wrapper(anchor_only.unwrap(), child)
      } else if raw_value != "" {
        let (after, scalar) = parse_inline_or_block_scalar(
          lines,
          index,
          raw_value,
          line.indent,
          line.line_no,
          profile_totals,
        )
        next = after
        scalar
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
  if key.has_prefix("&") || key.has_prefix("*") || key.has_prefix("!") {
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

  if trimmed.has_prefix("!!") {
    let value = parse_yaml_safe_core_tag(trimmed, line_no, profile_totals)
    yaml_parse_profile_add_elapsed(scalar_total, scalar_started)
    return value
  }

  if trimmed.has_prefix("*") {
    let name = yaml_reference_name(trimmed[1:].to_owned(), line_no, "alias")
    let value = YamlValue::String(yaml_alias_marker_prefix + name)
    yaml_parse_profile_add_elapsed(scalar_total, scalar_started)
    return value
  }

  if trimmed.has_prefix("&") {
    let split = trimmed.find(" ")
    let name = match split {
      Some(index) =>
        yaml_reference_name(trimmed[1:index].to_owned(), line_no, "anchor")
      None =>
        raise ParseError(
          "anchor requires a value at line " + line_no.to_string(),
        )
    }
    let raw = trimmed[split.unwrap() + 1:].trim().to_owned()
    if raw == "" {
      raise ParseError("anchor requires a value at line " + line_no.to_string())
    }
    let value = yaml_anchor_wrapper(
      name,
      parse_scalar_trimmed(raw, line_no, profile_totals),
    )
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

  if yaml_is_number_scalar(trimmed) {
    let value = YamlValue::Number(trimmed)
    yaml_parse_profile_add_elapsed(scalar_total, scalar_started)
    return value
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
  if trimmed.has_prefix("!") {
    raise ParseError(
      "general tags are unsupported at line " + line_no.to_string(),
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
fn yaml_anchor_name_only(text : String) -> String? raise {
  let trimmed = text.trim().to_owned()
  if !trimmed.has_prefix("&") || trimmed.contains(" ") {
    return None
  }
  Some(yaml_reference_name(trimmed[1:].to_owned(), 0, "anchor"))
}

///|
fn yaml_reference_name(
  name : String,
  line_no : Int,
  kind : String,
) -> String raise {
  if name == "" || name.length() > 128 {
    raise ParseError(
      "invalid " + kind + " name" + yaml_optional_line_suffix(line_no),
    )
  }
  for ch in name {
    let valid = (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '_' ||
      ch == '-'
    if !valid {
      raise ParseError(
        "invalid " + kind + " name" + yaml_optional_line_suffix(line_no),
      )
    }
  }
  name
}

///|
fn yaml_optional_line_suffix(line_no : Int) -> String {
  if line_no > 0 {
    " at line " + line_no.to_string()
  } else {
    ""
  }
}

///|
fn yaml_anchor_wrapper(name : String, value : YamlValue) -> YamlValue {
  YamlValue::Mapping([{ key: yaml_anchor_marker_prefix + name, value }])
}

///|
fn resolve_yaml_aliases(
  value : YamlValue,
  resolver : YamlAliasResolver,
) -> YamlValue raise {
  match value {
    YamlValue::String(text) =>
      if text.has_prefix(yaml_alias_marker_prefix) {
        resolver.alias_count += 1
        if resolver.alias_count > 1_024 {
          raise ParseError("YAML alias expansion budget exceeded")
        }
        let name = text[yaml_alias_marker_prefix.length():].to_owned()
        match resolver.anchors.get(name) {
          Some(target) => target
          None => raise ParseError("undefined YAML alias *" + name)
        }
      } else {
        value
      }
    YamlValue::Sequence(values) => {
      let resolved : Array[YamlValue] = []
      for item in values {
        resolved.push(resolve_yaml_aliases(item, resolver))
      }
      YamlValue::Sequence(resolved)
    }
    YamlValue::Mapping(members) => {
      if members.length() == 1 &&
        members[0].key.has_prefix(yaml_anchor_marker_prefix) {
        resolver.anchor_count += 1
        if resolver.anchor_count > 256 {
          raise ParseError("YAML anchor budget exceeded")
        }
        let name = members[0].key[yaml_anchor_marker_prefix.length():].to_owned()
        if resolver.anchors.get(name) is Some(_) {
          raise ParseError("duplicate YAML anchor &" + name)
        }
        let resolved = resolve_yaml_aliases(members[0].value, resolver)
        resolver.anchors.set(name, resolved)
        return resolved
      }
      resolve_yaml_mapping_members(members, resolver)
    }
    YamlValue::Number(_) | YamlValue::Bool(_) | YamlValue::Null => value
  }
}

///|
fn resolve_yaml_mapping_members(
  members : Array[YamlMember],
  resolver : YamlAliasResolver,
) -> YamlValue raise {
  let merged : Array[YamlMember] = []
  let explicit : Array[YamlMember] = []
  for entry in members {
    let resolved = resolve_yaml_aliases(entry.value, resolver)
    if entry.key == "<<" {
      append_yaml_merge_members(merged, resolved)
    } else {
      explicit.push({ key: entry.key, value: resolved })
    }
  }
  let explicit_keys : Map[String, Bool] = Map([])
  for entry in explicit {
    explicit_keys.set(entry.key, true)
  }
  let emitted : Map[String, Bool] = Map([])
  let out : Array[YamlMember] = []
  for entry in merged {
    if explicit_keys.get(entry.key) is None && emitted.get(entry.key) is None {
      out.push(entry)
      emitted.set(entry.key, true)
    }
  }
  out.append(explicit[:])
  YamlValue::Mapping(out)
}

///|
fn append_yaml_merge_members(
  out : Array[YamlMember],
  value : YamlValue,
) -> Unit raise {
  match value {
    YamlValue::Mapping(members) => out.append(members[:])
    YamlValue::Sequence(values) =>
      for item in values {
        match item {
          YamlValue::Mapping(members) => out.append(members[:])
          _ => raise ParseError("YAML merge sequence must contain mappings")
        }
      }
    _ => raise ParseError("YAML merge value must be a mapping or sequence")
  }
}

///|
fn parse_yaml_safe_core_tag(
  trimmed : String,
  line_no : Int,
  _profile_totals : YamlParseProfileTotals?,
) -> YamlValue raise {
  let split = match trimmed.find(" ") {
    Some(index) => index
    None =>
      raise ParseError(
        "safe core tag requires a scalar value at line " + line_no.to_string(),
      )
  }
  let tag = trimmed[:split].to_owned()
  let raw = trimmed[split + 1:].trim().to_owned()
  if raw == "" {
    raise ParseError(
      "safe core tag requires a scalar value at line " + line_no.to_string(),
    )
  }
  match tag {
    "!!str" =>
      if raw.has_prefix("\"") {
        YamlValue::String(parse_double_quoted_scalar(raw, line_no))
      } else if raw.has_prefix("'") {
        YamlValue::String(parse_single_quoted_scalar(raw, line_no))
      } else {
        YamlValue::String(raw)
      }
    "!!int" =>
      if yaml_is_integer_scalar(raw) {
        YamlValue::Number(raw)
      } else {
        raise ParseError("invalid !!int scalar at line " + line_no.to_string())
      }
    "!!float" =>
      if yaml_is_number_scalar(raw) {
        YamlValue::Number(raw)
      } else {
        raise ParseError(
          "invalid !!float scalar at line " + line_no.to_string(),
        )
      }
    "!!bool" =>
      if raw == "true" {
        YamlValue::Bool(true)
      } else if raw == "false" {
        YamlValue::Bool(false)
      } else {
        raise ParseError("invalid !!bool scalar at line " + line_no.to_string())
      }
    "!!null" =>
      if raw == "null" || raw == "~" {
        YamlValue::Null
      } else {
        raise ParseError("invalid !!null scalar at line " + line_no.to_string())
      }
    _ =>
      raise ParseError(
        "unsupported YAML tag " + tag + " at line " + line_no.to_string(),
      )
  }
}

///|
fn yaml_is_integer_scalar(text : String) -> Bool {
  if text == "" {
    return false
  }
  let chars = text.to_array()
  let mut index = if chars[0] == '-' || chars[0] == '+' { 1 } else { 0 }
  if index >= chars.length() {
    return false
  }
  while index < chars.length() {
    if chars[index] < '0' || chars[index] > '9' {
      return false
    }
    index += 1
  }
  true
}

///|
fn parse_inline_or_block_scalar(
  lines : Array[YamlLine],
  line_index : Int,
  raw_value : String,
  parent_indent : Int,
  line_no : Int,
  profile_totals : YamlParseProfileTotals?,
) -> (Int, YamlValue) raise {
  let trimmed = raw_value.trim().to_owned()
  if trimmed.has_prefix("|") || trimmed.has_prefix(">") {
    return parse_block_scalar(
      lines, line_index, trimmed, parent_indent, line_no,
    )
  }
  (line_index + 1, parse_scalar_trimmed(trimmed, line_no, profile_totals))
}

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
  (next, YamlValue::String(yaml_apply_block_scalar_chomping(styled, chomping)))
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
    YamlValue::Mapping(_) => "mapping"
    YamlValue::Sequence(_) => "sequence"
    YamlValue::String(_) => "string"
    YamlValue::Number(_) => "number"
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
    YamlValue::Number(text) =>
      events.push({
        kind: YamlStructureEventKind::NumberValue,
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

///|

///|
