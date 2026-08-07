///|
/// Scan Markdown source into a lightweight raw block inventory.
///
/// This scanner always succeeds by design. Ambiguities and malformed fences are
/// reported as validation issues instead of hard parse errors.
pub fn scan_markdown_document(text : String) -> MarkdownDocument {
  scan_markdown_document_with_profile(text, None, None)
}

///|
/// Benchmark-oriented profiled scan helper used for internal hotspot
/// attribution.
///
/// This does not turn the lightweight scanner into a full Markdown parser or
/// change converter behavior.
pub fn profile_markdown_document(text : String) -> MarkdownProfiledDocument {
  let report = new_markdown_parse_profile_report()
  let totals = new_markdown_parse_profile_totals()
  let document = scan_markdown_document_with_profile(
    text,
    Some(report),
    Some(totals),
  )
  markdown_parse_profile_finish_totals(Some(report), Some(totals))
  { document, report }
}

///|
fn scan_markdown_document_with_profile(
  text : String,
  profile : MarkdownParseProfileReport?,
  profile_totals : MarkdownParseProfileTotals?,
) -> MarkdownDocument {
  let normalize_started = markdown_parse_profile_stage_started(profile)
  let normalized = normalize_markdown_source(text)
  let lines = build_markdown_line_views(split_markdown_lines(normalized))
  match profile {
    Some(_) =>
      markdown_parse_profile_stage_finished(
        profile,
        "normalize_lines",
        normalize_started,
        Some("lines=" + lines.length().to_string()),
      )
    None => ()
  }
  let blocks : Array[MarkdownBlock] = []
  let issues : Array[MarkdownValidationIssue] = []
  let mut frontmatter : MarkdownFrontmatter? = None
  let mut i = 0

  let frontmatter_started = markdown_parse_profile_stage_started(profile)
  match consume_markdown_frontmatter(lines) {
    Some((parsed, next_index, frontmatter_issues)) => {
      frontmatter = Some(parsed)
      for issue in frontmatter_issues {
        let issue_started = match profile_totals {
          Some(_) => @env.now()
          None => 0
        }
        issues.push(issue)
        let issue_total = match profile_totals {
          Some(totals) => Some(totals.validation_issues_elapsed_ms)
          None => None
        }
        markdown_parse_profile_add_elapsed(issue_total, issue_started)
      }
      i = next_index
    }
    None => ()
  }
  match profile {
    Some(_) => {
      let has_frontmatter = match frontmatter {
        Some(_) => "true"
        None => "false"
      }
      markdown_parse_profile_stage_finished(
        profile,
        "frontmatter",
        frontmatter_started,
        Some("has_frontmatter=" + has_frontmatter),
      )
    }
    None => ()
  }

  let scan_started = markdown_parse_profile_stage_started(profile)
  while i < lines.length() {
    let line = lines[i]
    let line_no = i + 1

    if markdown_line_is_blank(line) {
      blocks.push({
        kind: BlankLine,
        line_start: line_no,
        line_end: line_no,
        raw_text: line.raw,
        fenced_code: None,
      })
      i += 1
      continue
    }

    let fence_started = match profile_totals {
      Some(_) => @env.now()
      None => 0
    }
    let fence_total = match profile_totals {
      Some(totals) => Some(totals.fence_scan_elapsed_ms)
      None => None
    }
    match parse_markdown_fence_open(line) {
      Some(open_fence) => {
        markdown_parse_profile_add_elapsed(fence_total, fence_started)
        let raw_lines : Array[String] = [line.raw]
        let mut j = i + 1
        let mut closed = false
        while j < lines.length() {
          raw_lines.push(lines[j].raw)
          if is_markdown_fence_close(
              lines[j],
              open_fence.fence_char,
              open_fence.fence_length,
            ) {
            closed = true
            j += 1
            break
          }
          j += 1
        }
        if !closed {
          let issue_started = match profile_totals {
            Some(_) => @env.now()
            None => 0
          }
          issues.push({
            kind: UnclosedFence,
            severity: Warning,
            line_start: Some(line_no),
            line_end: Some(i + raw_lines.length()),
            message: "fenced code block is not closed",
          })
          let issue_total = match profile_totals {
            Some(totals) => Some(totals.validation_issues_elapsed_ms)
            None => None
          }
          markdown_parse_profile_add_elapsed(issue_total, issue_started)
        }
        blocks.push({
          kind: FencedCode,
          line_start: line_no,
          line_end: i + raw_lines.length(),
          raw_text: raw_lines.join("\n"),
          fenced_code: Some({
            fence_char: open_fence.fence_char,
            fence_length: open_fence.fence_length,
            info_string: open_fence.info_string,
            closed,
          }),
        })
        i = j
        continue
      }
      None => markdown_parse_profile_add_elapsed(fence_total, fence_started)
    }

    let classify_started = match profile_totals {
      Some(_) => @env.now()
      None => 0
    }
    let classify_total = match profile_totals {
      Some(totals) => Some(totals.block_classify_elapsed_ms)
      None => None
    }
    if can_start_setext_heading(lines, i) {
      markdown_parse_profile_add_elapsed(classify_total, classify_started)
      blocks.push({
        kind: HeadingSetext,
        line_start: line_no,
        line_end: line_no + 1,
        raw_text: line.raw + "\n" + lines[i + 1].raw,
        fenced_code: None,
      })
      i += 2
      continue
    }

    let kind = classify_markdown_line_kind(line)
    markdown_parse_profile_add_elapsed(classify_total, classify_started)
    if kind != ParagraphLike {
      blocks.push({
        kind,
        line_start: line_no,
        line_end: line_no,
        raw_text: line.raw,
        fenced_code: None,
      })
      i += 1
      continue
    }

    let raw_lines : Array[String] = [line.raw]
    let mut j = i + 1
    while j < lines.length() {
      if should_end_markdown_paragraph(lines, j) {
        break
      }
      raw_lines.push(lines[j].raw)
      j += 1
    }
    blocks.push({
      kind: ParagraphLike,
      line_start: line_no,
      line_end: i + raw_lines.length(),
      raw_text: raw_lines.join("\n"),
      fenced_code: None,
    })
    i = j
  }
  match profile {
    Some(_) =>
      markdown_parse_profile_stage_finished(
        profile,
        "scan_lines",
        scan_started,
        Some("blocks=" + blocks.length().to_string()),
      )
    None => ()
  }

  let build_started = markdown_parse_profile_stage_started(profile)
  let doc = {
    source_length: count_markdown_source_chars(normalized),
    line_count: lines.length(),
    blocks,
    frontmatter,
    issues,
  }
  match profile {
    Some(_) =>
      markdown_parse_profile_stage_finished(
        profile,
        "build_document",
        build_started,
        Some("issues=" + doc.issues.length().to_string()),
      )
    None => ()
  }
  doc
}

///|
fn count_markdown_source_chars(text : String) -> Int {
  text.length()
}

///|
priv struct MarkdownLineView {
  raw : String
  left_trim_index : Int
  trimmed_end_index : Int
}

///|
fn build_markdown_line_views(lines : Array[String]) -> Array[MarkdownLineView] {
  let out : Array[MarkdownLineView] = []
  for line in lines {
    let (left_trim_index, trimmed_end_index) = markdown_trim_bounds(line)
    out.push({ raw: line, left_trim_index, trimmed_end_index })
  }
  out
}

///|
fn markdown_trim_bounds(line : String) -> (Int, Int) {
  let chars = line.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && markdown_char_is_inline_space(chars[start]) {
    start += 1
  }
  while end > start && markdown_char_is_inline_space(chars[end - 1]) {
    end -= 1
  }
  (start, end)
}

///|
fn markdown_char_is_inline_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t'
}

///|
fn markdown_line_is_blank(line : MarkdownLineView) -> Bool {
  line.left_trim_index >= line.trimmed_end_index
}

///|
fn markdown_line_trimmed(line : MarkdownLineView) -> String {
  if markdown_line_is_blank(line) {
    ""
  } else {
    line.raw[line.left_trim_index:line.trimmed_end_index].to_owned()
  }
}

///|
fn markdown_line_left_trimmed(line : MarkdownLineView) -> String {
  if line.left_trim_index == 0 {
    line.raw
  } else {
    line.raw[line.left_trim_index:].to_owned()
  }
}

///|
fn normalize_markdown_source(text : String) -> String {
  if !text.has_prefix("\u{FEFF}") && !text.contains("\r") {
    return text
  }
  let chars = text.to_array()
  let out : Array[Char] = []
  let mut i = 0

  if chars.length() > 0 && chars[0] == '\u{FEFF}' {
    i = 1
  }

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
fn split_markdown_lines(text : String) -> Array[String] {
  if text == "" {
    return []
  }

  let out : Array[String] = []
  let line_views = text.split("\n").to_array()
  let limit = if text.has_suffix("\n") {
    line_views.length() - 1
  } else {
    line_views.length()
  }
  for index in 0..<limit {
    out.push(line_views[index].to_owned())
  }
  out
}

///|
fn consume_markdown_frontmatter(
  lines : Array[MarkdownLineView],
) -> (MarkdownFrontmatter, Int, Array[MarkdownValidationIssue])? {
  if lines.length() == 0 {
    return None
  }

  let marker = markdown_line_trimmed(lines[0])
  let kind = match marker {
    "---" => Some(MarkdownFrontmatterKind::Yaml)
    "+++" => Some(Toml)
    _ => None
  }

  match kind {
    None => None
    Some(frontmatter_kind) => {
      let body : Array[String] = []
      let issues : Array[MarkdownValidationIssue] = []
      let mut i = 1
      while i < lines.length() {
        if markdown_line_trimmed(lines[i]) == marker {
          return Some(
            (
              {
                kind: frontmatter_kind,
                line_start: 1,
                line_end: i + 1,
                content: body.join("\n"),
                closed: true,
              },
              i + 1,
              issues,
            ),
          )
        }
        body.push(lines[i].raw)
        i += 1
      }

      issues.push({
        kind: UnclosedFrontmatter,
        severity: Warning,
        line_start: Some(1),
        line_end: Some(lines.length()),
        message: "frontmatter block is not closed",
      })
      Some(
        (
          {
            kind: frontmatter_kind,
            line_start: 1,
            line_end: lines.length(),
            content: body.join("\n"),
            closed: false,
          },
          lines.length(),
          issues,
        ),
      )
    }
  }
}

///|
fn parse_markdown_fence_open(
  line : MarkdownLineView,
) -> MarkdownFencedCodeInfo? {
  let chars = line.raw.to_array()
  let start = line.left_trim_index
  if chars.length() - start < 3 {
    return None
  }

  let fence_char = chars[start]
  if !(fence_char == '`' || fence_char == '~') {
    return None
  }

  let mut i = 0
  while start + i < chars.length() && chars[start + i] == fence_char {
    i += 1
  }
  if i < 3 {
    return None
  }

  let info = markdown_trimmed_substring(line.raw, start + i, chars.length())
  Some({
    fence_char,
    fence_length: i,
    info_string: if info == "" {
      None
    } else {
      Some(info)
    },
    closed: true,
  })
}

///|
fn is_markdown_fence_close(
  line : MarkdownLineView,
  fence_char : Char,
  fence_length : Int,
) -> Bool {
  let chars = line.raw.to_array()
  let start = line.left_trim_index
  if chars.length() - start < fence_length {
    return false
  }

  let mut i = 0
  while start + i < chars.length() && chars[start + i] == fence_char {
    i += 1
  }

  i >= fence_length &&
  markdown_trimmed_substring(line.raw, start + i, chars.length()) == ""
}

///|
fn can_start_setext_heading(
  lines : Array[MarkdownLineView],
  index : Int,
) -> Bool {
  if index + 1 >= lines.length() {
    return false
  }
  !markdown_line_is_blank(lines[index]) &&
  classify_markdown_line_kind(lines[index]) == ParagraphLike &&
  is_markdown_setext_underline(lines[index + 1])
}

///|
fn is_markdown_setext_underline(line : MarkdownLineView) -> Bool {
  let chars = line.raw.to_array()
  let start = line.left_trim_index
  let end = line.trimmed_end_index
  if end - start < 3 {
    return false
  }

  let marker = chars[start]
  if !(marker == '=' || marker == '-') {
    return false
  }

  let mut i = start
  while i < end {
    if chars[i] != marker {
      return false
    }
    i += 1
  }
  true
}

///|
fn classify_markdown_line_kind(line : MarkdownLineView) -> MarkdownBlockKind {
  if is_markdown_atx_heading(line) {
    HeadingAtx
  } else if is_markdown_list_item(line) {
    ListItem
  } else if is_markdown_blockquote(line) {
    BlockQuote
  } else if is_markdown_thematic_break(line) {
    ThematicBreak
  } else if is_markdown_html_block_candidate(line) {
    HtmlBlockCandidate
  } else if is_markdown_table_like_row(line) {
    TableLikeRow
  } else {
    ParagraphLike
  }
}

///|
fn should_end_markdown_paragraph(
  lines : Array[MarkdownLineView],
  index : Int,
) -> Bool {
  let line = lines[index]
  if markdown_line_is_blank(line) {
    return true
  }
  match parse_markdown_fence_open(line) {
    Some(_) => return true
    None => ()
  }
  if can_start_setext_heading(lines, index) {
    return true
  }

  let kind = classify_markdown_line_kind(line)
  kind != ParagraphLike
}

///|
fn is_markdown_atx_heading(line : MarkdownLineView) -> Bool {
  let chars = line.raw.to_array()
  let start = line.left_trim_index
  if start >= chars.length() || chars[start] != '#' {
    return false
  }

  let mut i = 0
  while start + i < chars.length() && chars[start + i] == '#' {
    i += 1
  }
  if i == 0 || i > 6 {
    return false
  }
  start + i == chars.length() ||
  chars[start + i] == ' ' ||
  chars[start + i] == '\t'
}

///|
fn is_markdown_list_item(line : MarkdownLineView) -> Bool {
  let left_trimmed = markdown_line_left_trimmed(line)
  if left_trimmed.has_prefix("- ") ||
    left_trimmed.has_prefix("* ") ||
    left_trimmed.has_prefix("+ ") {
    return true
  }

  let chars = left_trimmed.to_array()
  let mut i = 0
  while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
    i += 1
  }
  if i == 0 || i + 1 >= chars.length() {
    return false
  }
  (chars[i] == '.' || chars[i] == ')') &&
  (chars[i + 1] == ' ' || chars[i + 1] == '\t')
}

///|
fn is_markdown_blockquote(line : MarkdownLineView) -> Bool {
  let chars = line.raw.to_array()
  line.left_trim_index < chars.length() && chars[line.left_trim_index] == '>'
}

///|
fn is_markdown_thematic_break(line : MarkdownLineView) -> Bool {
  let chars = line.raw.to_array().filter(fn(ch) { ch != ' ' && ch != '\t' })
  if chars.length() < 3 {
    return false
  }

  let marker = chars[0]
  if !(marker == '-' || marker == '*' || marker == '_') {
    return false
  }

  for ch in chars {
    if ch != marker {
      return false
    }
  }
  true
}

///|
fn is_markdown_table_like_row(line : MarkdownLineView) -> Bool {
  !markdown_line_is_blank(line) && line.raw.contains("|")
}

///|
fn is_markdown_html_block_candidate(line : MarkdownLineView) -> Bool {
  let chars = line.raw.to_array()
  let start = line.left_trim_index
  if start >= chars.length() || chars[start] != '<' {
    return false
  }
  if start + 1 >= chars.length() {
    return false
  }

  let next = chars[start + 1]
  (next >= 'A' && next <= 'Z') ||
  (next >= 'a' && next <= 'z') ||
  next == '/' ||
  next == '!' ||
  next == '?'
}

///|
fn markdown_trimmed_substring(text : String, start : Int, end : Int) -> String {
  if start >= end {
    return ""
  }
  let chars = text.to_array()
  let mut next_start = start
  let mut next_end = end
  while next_start < next_end &&
        markdown_char_is_inline_space(chars[next_start]) {
    next_start += 1
  }
  while next_end > next_start &&
        markdown_char_is_inline_space(chars[next_end - 1]) {
    next_end -= 1
  }
  if next_start >= next_end {
    ""
  } else {
    text[next_start:next_end].to_owned()
  }
}
