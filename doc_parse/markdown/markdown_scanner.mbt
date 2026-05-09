///|
pub fn scan_markdown_document(text : String) -> MarkdownDocument {
  let normalized = normalize_markdown_source(text)
  let lines = split_markdown_lines(normalized)
  let blocks : Array[MarkdownBlock] = []
  let issues : Array[MarkdownValidationIssue] = []
  let mut frontmatter : MarkdownFrontmatter? = None
  let mut i = 0

  match consume_markdown_frontmatter(lines) {
    Some((parsed, next_index, frontmatter_issues)) => {
      frontmatter = Some(parsed)
      for issue in frontmatter_issues {
        issues.push(issue)
      }
      i = next_index
    }
    None => ()
  }

  while i < lines.length() {
    let line = lines[i]
    let trimmed = line.trim().to_owned()
    let line_no = i + 1

    if trimmed == "" {
      blocks.push({
        kind: MarkdownBlockKind::BlankLine,
        line_start: line_no,
        line_end: line_no,
        raw_text: line,
        fenced_code: None,
      })
      i += 1
      continue
    }

    match parse_markdown_fence_open(line) {
      Some(open_fence) => {
        let raw_lines : Array[String] = [line]
        let mut j = i + 1
        let mut closed = false
        while j < lines.length() {
          raw_lines.push(lines[j])
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
          issues.push({
            kind: MarkdownValidationIssueKind::UnclosedFence,
            severity: MarkdownValidationSeverity::Warning,
            line_start: Some(line_no),
            line_end: Some(i + raw_lines.length()),
            message: "fenced code block is not closed",
          })
        }
        blocks.push({
          kind: MarkdownBlockKind::FencedCode,
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
      None => ()
    }

    if can_start_setext_heading(lines, i) {
      blocks.push({
        kind: MarkdownBlockKind::HeadingSetext,
        line_start: line_no,
        line_end: line_no + 1,
        raw_text: line + "\n" + lines[i + 1],
        fenced_code: None,
      })
      i += 2
      continue
    }

    let kind = classify_markdown_line_kind(line)
    if kind != MarkdownBlockKind::ParagraphLike {
      blocks.push({
        kind,
        line_start: line_no,
        line_end: line_no,
        raw_text: line,
        fenced_code: None,
      })
      i += 1
      continue
    }

    let raw_lines : Array[String] = [line]
    let mut j = i + 1
    while j < lines.length() {
      if should_end_markdown_paragraph(lines, j) {
        break
      }
      raw_lines.push(lines[j])
      j += 1
    }
    blocks.push({
      kind: MarkdownBlockKind::ParagraphLike,
      line_start: line_no,
      line_end: i + raw_lines.length(),
      raw_text: raw_lines.join("\n"),
      fenced_code: None,
    })
    i = j
  }

  {
    source_length: normalized.to_array().length(),
    line_count: lines.length(),
    blocks,
    frontmatter,
    issues,
  }
}

///|
fn normalize_markdown_source(text : String) -> String {
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
  let line : Array[Char] = []
  for ch in text.to_array() {
    if ch == '\n' {
      out.push(String::from_array(line))
      line.clear()
    } else {
      line.push(ch)
    }
  }

  if line.length() > 0 || !text.has_suffix("\n") {
    out.push(String::from_array(line))
  }
  out
}

///|
fn consume_markdown_frontmatter(
  lines : Array[String],
) -> (MarkdownFrontmatter, Int, Array[MarkdownValidationIssue])? {
  if lines.length() == 0 {
    return None
  }

  let marker = lines[0].trim().to_owned()
  let kind = match marker {
    "---" => Some(MarkdownFrontmatterKind::Yaml)
    "+++" => Some(MarkdownFrontmatterKind::Toml)
    _ => None
  }

  match kind {
    None => None
    Some(frontmatter_kind) => {
      let body : Array[String] = []
      let issues : Array[MarkdownValidationIssue] = []
      let mut i = 1
      while i < lines.length() {
        if lines[i].trim() == marker {
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
        body.push(lines[i])
        i += 1
      }

      issues.push({
        kind: MarkdownValidationIssueKind::UnclosedFrontmatter,
        severity: MarkdownValidationSeverity::Warning,
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
fn parse_markdown_fence_open(line : String) -> MarkdownFencedCodeInfo? {
  let trimmed = trim_markdown_left(line)
  let chars = trimmed.to_array()
  if chars.length() < 3 {
    return None
  }

  let fence_char = chars[0]
  if !(fence_char == '`' || fence_char == '~') {
    return None
  }

  let mut i = 0
  while i < chars.length() && chars[i] == fence_char {
    i += 1
  }
  if i < 3 {
    return None
  }

  let info = trimmed[i:].trim().to_owned()
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
  line : String,
  fence_char : Char,
  fence_length : Int,
) -> Bool {
  let trimmed = trim_markdown_left(line)
  let chars = trimmed.to_array()
  if chars.length() < fence_length {
    return false
  }

  let mut i = 0
  while i < chars.length() && chars[i] == fence_char {
    i += 1
  }

  i >= fence_length && trimmed[i:].trim() == ""
}

///|
fn can_start_setext_heading(lines : Array[String], index : Int) -> Bool {
  if index + 1 >= lines.length() {
    return false
  }
  let current = lines[index].trim().to_owned()
  current != "" &&
  classify_markdown_line_kind(lines[index]) == MarkdownBlockKind::ParagraphLike &&
  is_markdown_setext_underline(lines[index + 1])
}

///|
fn is_markdown_setext_underline(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() < 3 {
    return false
  }

  let marker = chars[0]
  if !(marker == '=' || marker == '-') {
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
fn classify_markdown_line_kind(line : String) -> MarkdownBlockKind {
  if is_markdown_atx_heading(line) {
    MarkdownBlockKind::HeadingAtx
  } else if is_markdown_list_item(line) {
    MarkdownBlockKind::ListItem
  } else if is_markdown_blockquote(line) {
    MarkdownBlockKind::BlockQuote
  } else if is_markdown_thematic_break(line) {
    MarkdownBlockKind::ThematicBreak
  } else if is_markdown_html_block_candidate(line) {
    MarkdownBlockKind::HtmlBlockCandidate
  } else if is_markdown_table_like_row(line) {
    MarkdownBlockKind::TableLikeRow
  } else {
    MarkdownBlockKind::ParagraphLike
  }
}

///|
fn should_end_markdown_paragraph(lines : Array[String], index : Int) -> Bool {
  let line = lines[index]
  if line.trim() == "" {
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
  kind != MarkdownBlockKind::ParagraphLike
}

///|
fn is_markdown_atx_heading(line : String) -> Bool {
  let trimmed = trim_markdown_left(line)
  let chars = trimmed.to_array()
  if chars.length() == 0 || chars[0] != '#' {
    return false
  }

  let mut i = 0
  while i < chars.length() && chars[i] == '#' {
    i += 1
  }
  if i == 0 || i > 6 {
    return false
  }
  i == chars.length() || chars[i] == ' ' || chars[i] == '\t'
}

///|
fn is_markdown_list_item(line : String) -> Bool {
  let trimmed = trim_markdown_left(line)
  if trimmed.has_prefix("- ") ||
    trimmed.has_prefix("* ") ||
    trimmed.has_prefix("+ ") {
    return true
  }

  let chars = trimmed.to_array()
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
fn is_markdown_blockquote(line : String) -> Bool {
  trim_markdown_left(line).has_prefix(">")
}

///|
fn is_markdown_thematic_break(line : String) -> Bool {
  let chars = line.to_array().filter(fn(ch) { ch != ' ' && ch != '\t' })
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
fn is_markdown_table_like_row(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  trimmed != "" && trimmed.contains("|")
}

///|
fn is_markdown_html_block_candidate(line : String) -> Bool {
  let trimmed = trim_markdown_left(line)
  if !trimmed.has_prefix("<") {
    return false
  }
  let chars = trimmed.to_array()
  if chars.length() < 2 {
    return false
  }

  let next = chars[1]
  (next >= 'A' && next <= 'Z') ||
  (next >= 'a' && next <= 'z') ||
  next == '/' ||
  next == '!' ||
  next == '?'
}

///|
fn trim_markdown_left(line : String) -> String {
  let chars = line.to_array()
  let mut i = 0
  while i < chars.length() && (chars[i] == ' ' || chars[i] == '\t') {
    i += 1
  }
  line[i:].to_owned()
}
