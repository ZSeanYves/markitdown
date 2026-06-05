///|
/// Markdown passthrough converter entrypoint.
///
/// Design boundary:
/// - reads UTF-8 markdown bytes
/// - preserves original body for final markdown emission
/// - only performs conservative block splitting for metadata sidecar summary
pub fn parse_markdown(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("markdown: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("markdown: read failed: " + e.to_string())
  }

  let raw = @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise @cor.AppError("markdown: utf8 decode failed")
  }
  let text = normalize_markdown_source(raw)

  let doc = @cor.new_document()
  let src = @cor.basename(input_path)
  let scanned_source = @dpmd.scan_markdown_document(text)
  let normalized = normalize_markdown_footnotes(text, src, scanned_source)
  let output_text = match normalized {
    Some(result) => {
      for note in result.note_definitions {
        @cor.push_note_definition(doc, note)
      }
      result.normalized_markdown
    }
    None => text
  }
  @cor.set_passthrough_markdown(doc, output_text)

  let scanned = match normalized {
    Some(_) => @dpmd.scan_markdown_document(output_text)
    None => scanned_source
  }
  let inline_cache_by_line = match normalized {
    Some(result) => result.inline_cache_by_line
    None => []
  }
  let definition_start_lines = collect_markdown_footnote_definition_start_lines(
    scanned,
  )
  let resolved_note_ids = match normalized {
    Some(result) => result.resolved_note_ids
    None => Map([])
  }

  for block in scanner_backed_markdown_blocks(scanned) {
    let block_value = upgrade_scanner_backed_markdown_block(
      block,
      scanned,
      definition_start_lines,
      inline_cache_by_line,
      resolved_note_ids,
    )
    @cor.push_with_origin(
      doc,
      block_value,
      Some({
        source_name: Some(src),
        page: None,
        slide: None,
        sheet: None,
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
        line_start: Some(block.line_start),
        line_end: Some(block.line_end),
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: None,
        key_path: None,
      }),
    )
  }

  doc
}

///|
fn normalize_markdown_source(text : String) -> String {
  let without_bom = if text.length() > 0 && text[0] == '\u{FEFF}' {
    text[1:].to_owned()
  } else {
    text
  }
  let out : Array[Char] = []
  let chars = without_bom.to_array()
  let mut i = 0

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
priv struct MarkdownFootnoteDefinitionDraft {
  note_id : String
  body : String
  line_start : Int
  line_end : Int
}

///|
priv struct MarkdownFootnoteNormalization {
  normalized_markdown : String
  inline_cache_by_line : Array[MarkdownInlineScanResult?]
  note_definitions : Array[@cor.NoteDefinition]
  resolved_note_ids : Map[String, Bool]
}

///|
priv struct MarkdownInlineScanResult {
  inlines : Array[@cor.Inline]
  normalized_text : String
  found_note_ref : Bool
}

///|
priv struct ScannerBackedMarkdownBlock {
  block : @cor.Block
  line_start : Int
  line_end : Int
}

///|
fn normalize_markdown_footnotes(
  text : String,
  source_name : String,
  scanned : @dpmd.MarkdownDocument,
) -> MarkdownFootnoteNormalization? {
  let lines = markdown_lines(text)
  let definition_starts : Map[Int, Int] = {}
  let definitions : Array[MarkdownFootnoteDefinitionDraft] = []
  let resolved_note_ids : Map[String, Bool] = {}
  let body_inline_cache : Array[MarkdownInlineScanResult?] = []
  let body_lines : Array[String] = []
  let mutable_normal_line_allowed = markdown_normal_line_allowance(scanned)
  let mut has_note_ref = false
  let mut i = 0

  while i < lines.length() {
    if !markdown_line_is_normal_allowed(mutable_normal_line_allowed, i) {
      i += 1
      continue
    }
    match parse_markdown_footnote_definition(lines, i) {
      Some((definition, next_index)) => {
        definition_starts[i] = next_index
        definitions.push(definition)
        resolved_note_ids[definition.note_id] = true
        i = next_index
      }
      None => i += 1
    }
  }

  i = 0
  while i < lines.length() {
    match definition_starts.get(i) {
      Some(next_index) => i = next_index
      None => {
        if markdown_line_is_normal_allowed(mutable_normal_line_allowed, i) {
          let scan = scan_markdown_note_inlines(lines[i], resolved_note_ids)
          if scan.found_note_ref {
            has_note_ref = true
          }
          body_lines.push(scan.normalized_text)
          body_inline_cache.push(Some(scan))
        } else {
          body_lines.push(lines[i])
          body_inline_cache.push(None)
        }
        i += 1
      }
    }
  }

  if definitions.length() == 0 && !has_note_ref {
    return None
  }

  trim_trailing_blank_markdown_lines(body_lines, body_inline_cache)
  let note_definitions = markdown_note_definitions_from_drafts(
    definitions, source_name,
  )
  let normalized_lines = render_markdown_footnote_normalized_lines(
    body_lines, definitions,
  )
  let inline_cache_by_line = normalized_markdown_inline_cache_lines(
    body_inline_cache, definitions,
  )
  let normalized_markdown = normalized_lines.join("\n")
  Some({
    normalized_markdown,
    inline_cache_by_line,
    note_definitions,
    resolved_note_ids,
  })
}

///|
fn scanner_backed_markdown_blocks(
  scanned : @dpmd.MarkdownDocument,
) -> Array[ScannerBackedMarkdownBlock] {
  let out : Array[ScannerBackedMarkdownBlock] = []
  match scanned.frontmatter {
    Some(frontmatter) =>
      out.push({
        block: @cor.Block::Paragraph(frontmatter_raw_text(frontmatter)),
        line_start: frontmatter.line_start,
        line_end: frontmatter.line_end,
      })
    None => ()
  }

  let mut i = 0
  while i < scanned.blocks.length() {
    let current = scanned.blocks[i]
    if current.kind == @dpmd.MarkdownBlockKind::BlankLine {
      i += 1
      continue
    }
    if current.kind == @dpmd.MarkdownBlockKind::FencedCode {
      out.push({
        block: @cor.Block::CodeBlock(current.raw_text),
        line_start: current.line_start,
        line_end: current.line_end,
      })
      i += 1
      continue
    }

    let chunk_lines : Array[String] = [current.raw_text]
    let line_start = current.line_start
    let mut line_end = current.line_end
    i += 1

    while i < scanned.blocks.length() {
      let candidate = scanned.blocks[i]
      if candidate.kind == @dpmd.MarkdownBlockKind::BlankLine ||
        candidate.kind == @dpmd.MarkdownBlockKind::FencedCode ||
        candidate.line_start != line_end + 1 {
        break
      }
      chunk_lines.push(candidate.raw_text)
      line_end = candidate.line_end
      i += 1
    }

    out.push({
      block: @cor.Block::Paragraph(chunk_lines.join("\n")),
      line_start,
      line_end,
    })
  }

  out
}

///|
fn upgrade_scanner_backed_markdown_block(
  block : ScannerBackedMarkdownBlock,
  scanned : @dpmd.MarkdownDocument,
  definition_start_lines : Map[Int, Bool],
  inline_cache_by_line : Array[MarkdownInlineScanResult?],
  resolved_note_ids : Map[String, Bool],
) -> @cor.Block {
  match block.block {
    @cor.Block::Paragraph(text) => {
      let start_index = block.line_start - 1
      if definition_start_lines.contains(start_index) ||
        !markdown_block_lines_are_normal(
          scanned,
          block.line_start,
          block.line_end,
        ) {
        return block.block
      }

      match
        rich_paragraph_from_markdown_inline_cache(
          inline_cache_by_line,
          block.line_start,
          block.line_end,
        ) {
        Some(inlines) => return @cor.Block::RichParagraph(inlines)
        None => ()
      }

      let scan = scan_markdown_note_inlines(text, resolved_note_ids)
      if scan.found_note_ref {
        @cor.Block::RichParagraph(scan.inlines)
      } else {
        block.block
      }
    }
    _ => block.block
  }
}

///|
fn markdown_lines(text : String) -> Array[String] {
  text.split("\n").map(fn(line) { line.to_owned() }).iter().collect()
}

///|
fn markdown_lines_from_scanner(
  scanned : @dpmd.MarkdownDocument,
) -> Array[String] {
  if scanned.line_count == 0 {
    return []
  }

  let lines : Array[String] = []
  for _ in 0..<scanned.line_count {
    lines.push("")
  }

  match scanned.frontmatter {
    Some(frontmatter) =>
      assign_markdown_block_lines(lines, frontmatter.line_start, frontmatter.line_end, markdown_lines(frontmatter_raw_text(frontmatter)))
    None => ()
  }

  for block in scanned.blocks {
    assign_markdown_block_lines(
      lines,
      block.line_start,
      block.line_end,
      markdown_lines(block.raw_text),
    )
  }

  lines
}

///|
fn assign_markdown_block_lines(
  lines : Array[String],
  line_start : Int,
  line_end : Int,
  block_lines : Array[String],
) -> Unit {
  if line_start < 1 || line_end < line_start {
    return
  }

  let mut line_no = line_start
  let mut i = 0
  while line_no <= line_end && i < block_lines.length() && line_no <= lines.length() {
    lines[line_no - 1] = block_lines[i]
    line_no += 1
    i += 1
  }
}

///|
fn frontmatter_raw_text(frontmatter : @dpmd.MarkdownFrontmatter) -> String {
  let marker = match frontmatter.kind {
    @dpmd.MarkdownFrontmatterKind::Toml => "+++"
    _ => "---"
  }
  if frontmatter.closed {
    if frontmatter.content == "" {
      marker + "\n" + marker
    } else {
      marker + "\n" + frontmatter.content + "\n" + marker
    }
  } else if frontmatter.content == "" {
    marker
  } else {
    marker + "\n" + frontmatter.content
  }
}

///|
fn markdown_normal_line_allowance(
  scanned : @dpmd.MarkdownDocument,
) -> Array[Bool] {
  let out : Array[Bool] = []
  for _ in 0..<scanned.line_count {
    out.push(true)
  }

  match scanned.frontmatter {
    Some(frontmatter) =>
      mark_markdown_line_range_false(
        out,
        frontmatter.line_start,
        frontmatter.line_end,
      )
    None => ()
  }

  for block in scanned.blocks {
    match block.kind {
      @dpmd.MarkdownBlockKind::FencedCode =>
        mark_markdown_line_range_false(out, block.line_start, block.line_end)
      _ => ()
    }
  }

  let mut i = 0
  while i < scanned.blocks.length() {
    let block = scanned.blocks[i]
    if block.kind == @dpmd.MarkdownBlockKind::BlankLine ||
      block.kind == @dpmd.MarkdownBlockKind::FencedCode {
      i += 1
      continue
    }

    let chunk_start = block.line_start
    let mut chunk_end = block.line_end
    let mut has_html_candidate =
      block.kind == @dpmd.MarkdownBlockKind::HtmlBlockCandidate
    i += 1

    while i < scanned.blocks.length() {
      let candidate = scanned.blocks[i]
      if candidate.kind == @dpmd.MarkdownBlockKind::BlankLine ||
        candidate.kind == @dpmd.MarkdownBlockKind::FencedCode ||
        candidate.line_start != chunk_end + 1 {
        break
      }
      if candidate.kind == @dpmd.MarkdownBlockKind::HtmlBlockCandidate {
        has_html_candidate = true
      }
      chunk_end = candidate.line_end
      i += 1
    }

    if has_html_candidate {
      mark_markdown_line_range_false(out, chunk_start, chunk_end)
    }
  }

  out
}

///|
fn mark_markdown_line_range_false(
  lines : Array[Bool],
  line_start : Int,
  line_end : Int,
) -> Unit {
  if line_start < 1 || line_end < line_start {
    return
  }
  let mut i = line_start - 1
  while i < line_end && i < lines.length() {
    lines[i] = false
    i += 1
  }
}

///|
fn markdown_line_is_normal_allowed(lines : Array[Bool], index : Int) -> Bool {
  index >= 0 && index < lines.length() && lines[index]
}

///|
fn parse_markdown_footnote_definition(
  lines : Array[String],
  start : Int,
) -> (MarkdownFootnoteDefinitionDraft, Int)? {
  if start < 0 || start >= lines.length() {
    return None
  }

  match parse_markdown_footnote_definition_head(lines[start]) {
    Some((note_id, first_body)) => {
      let body_lines : Array[String] = [first_body]
      let mut i = start + 1
      while i < lines.length() {
        if lines[i].trim() == "" &&
          i + 1 < lines.length() &&
          is_markdown_footnote_continuation_line(lines[i + 1]) {
          body_lines.push("")
          i += 1
          continue
        }
        if is_markdown_footnote_continuation_line(lines[i]) {
          body_lines.push(strip_markdown_footnote_continuation(lines[i]))
          i += 1
          continue
        }
        break
      }
      let body = body_lines.join("\n").trim().to_owned()
      Some(({ note_id, body, line_start: start + 1, line_end: i }, i))
    }
    None => None
  }
}

///|
fn parse_markdown_footnote_definition_head(line : String) -> (String, String)? {
  let chars = line.to_array()
  let mut i = 0
  let mut leading_spaces = 0
  while i < chars.length() && chars[i] == ' ' && leading_spaces < 4 {
    leading_spaces += 1
    i += 1
  }
  if leading_spaces >= 4 || i + 3 >= chars.length() {
    return None
  }
  if chars[i] != '[' || chars[i + 1] != '^' {
    return None
  }
  let id_start = i + 2
  let mut id_end = id_start
  while id_end < chars.length() && is_markdown_note_id_char(chars[id_end]) {
    id_end += 1
  }
  if id_end == id_start ||
    id_end + 1 >= chars.length() ||
    chars[id_end] != ']' ||
    chars[id_end + 1] != ':' {
    return None
  }

  let note_id = String::from_array(chars[id_start:id_end])
  let mut body_start = id_end + 2
  while body_start < chars.length() &&
        (chars[body_start] == ' ' || chars[body_start] == '\t') {
    body_start += 1
  }
  let body = String::from_array(chars[body_start:]).trim().to_owned()
  Some((note_id, body))
}

///|
fn is_markdown_footnote_continuation_line(line : String) -> Bool {
  line.has_prefix("    ") || line.has_prefix("\t")
}

///|
fn strip_markdown_footnote_continuation(line : String) -> String {
  if line.has_prefix("    ") {
    line[4:].to_owned()
  } else if line.has_prefix("\t") {
    line[1:].to_owned()
  } else {
    line
  }
}

///|
fn scan_markdown_note_inlines(
  text : String,
  resolved_note_ids : Map[String, Bool],
) -> MarkdownInlineScanResult {
  let chars = text.to_array()
  let rendered = StringBuilder::new()
  let pending_text : Array[Char] = []
  let inlines : Array[@cor.Inline] = []
  let mut i = 0
  let mut code_tick_len = 0
  let mut found_note_ref = false

  fn flush_pending_text(
    pending_text : Array[Char],
    rendered : StringBuilder,
    inlines : Array[@cor.Inline],
  ) -> Unit {
    if pending_text.length() == 0 {
      return
    }
    let text = String::from_array(pending_text)
    pending_text.clear()
    rendered.write_string(text)
    inlines.push(@cor.Inline::Text(text))
  }

  while i < chars.length() {
    if chars[i] == '\n' {
      flush_pending_text(pending_text, rendered, inlines)
      rendered.write_string("\n")
      inlines.push(@cor.Inline::Break)
      i += 1
      continue
    }

    if chars[i] == '`' {
      let tick_len = count_markdown_repeated_char(chars, i, '`')
      for _j in 0..<tick_len {
        pending_text.push('`')
      }
      if code_tick_len == 0 {
        code_tick_len = tick_len
      } else if code_tick_len == tick_len {
        code_tick_len = 0
      }
      i += tick_len
      continue
    }

    if code_tick_len == 0 &&
      !markdown_char_is_escaped(chars, i) &&
      chars[i] == '[' {
      match parse_markdown_note_ref(chars, i) {
        Some((next_index, note_id)) => {
          flush_pending_text(pending_text, rendered, inlines)
          let note = make_markdown_note_ref(
            note_id,
            resolved_note_ids.contains(note_id),
          )
          inlines.push(@cor.Inline::NoteRef(note))
          rendered.write_string(render_markdown_note_ref(note))
          found_note_ref = true
          i = next_index
          continue
        }
        None => ()
      }
    }

    pending_text.push(chars[i])
    i += 1
  }

  flush_pending_text(pending_text, rendered, inlines)
  { inlines, normalized_text: rendered.to_string(), found_note_ref }
}

///|
fn parse_markdown_note_ref(chars : Array[Char], start : Int) -> (Int, String)? {
  if start + 3 >= chars.length() ||
    chars[start] != '[' ||
    chars[start + 1] != '^' {
    return None
  }
  let id_start = start + 2
  let mut i = id_start
  while i < chars.length() && is_markdown_note_id_char(chars[i]) {
    i += 1
  }
  if i == id_start || i >= chars.length() || chars[i] != ']' {
    return None
  }
  Some((i + 1, String::from_array(chars[id_start:i])))
}

///|
fn make_markdown_note_ref(note_id : String, resolved : Bool) -> @cor.NoteRef {
  {
    note_id,
    marker: note_id,
    kind: @cor.NoteKind::Footnote,
    source_kind: @cor.NoteSourceKind::MarkdownFootnoteRef,
    confidence: @cor.NoteConfidence::High,
    body_status: if resolved {
      @cor.NoteBodyStatus::Resolved
    } else {
      @cor.NoteBodyStatus::Missing
    },
  }
}

///|
fn render_markdown_note_ref(note : @cor.NoteRef) -> String {
  if note.body_status == @cor.NoteBodyStatus::Resolved &&
    note.note_id.trim() != "" {
    return "[^" + note.note_id.trim().to_owned() + "]"
  }
  let marker = note.marker.trim().to_owned()
  if marker == "" {
    ""
  } else if marker.has_prefix("^") {
    marker
  } else {
    "^" + marker
  }
}

///|
fn markdown_note_definitions_from_drafts(
  definitions : Array[MarkdownFootnoteDefinitionDraft],
  source_name : String,
) -> Array[@cor.NoteDefinition] {
  let out : Array[@cor.NoteDefinition] = []
  for definition in definitions {
    out.push({
      note_id: definition.note_id,
      marker: definition.note_id,
      kind: @cor.NoteKind::Footnote,
      blocks: if definition.body == "" {
        []
      } else {
        [@cor.Block::Paragraph(definition.body)]
      },
      placement: @cor.NotePlacement::DocumentEnd,
      source_kind: @cor.NoteSourceKind::MarkdownFootnoteBody,
      body_status: @cor.NoteBodyStatus::Resolved,
      origin: Some({
        source_name: Some(source_name),
        page: None,
        slide: None,
        sheet: None,
        block_index: None,
        heading_path: None,
        line_start: Some(definition.line_start),
        line_end: Some(definition.line_end),
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: None,
        key_path: None,
      }),
    })
  }
  out
}

///|
fn render_markdown_footnote_normalized_lines(
  body_lines : Array[String],
  definitions : Array[MarkdownFootnoteDefinitionDraft],
) -> Array[String] {
  let out : Array[String] = []
  out.append(body_lines)

  if definitions.length() > 0 {
    if body_lines.length() > 0 {
      out.push("")
    }
    out.append(markdown_footnote_definition_lines(definitions))
  }

  out
}

///|
fn collect_markdown_footnote_definition_start_lines(
  scanned : @dpmd.MarkdownDocument,
) -> Map[Int, Bool] {
  let out : Map[Int, Bool] = {}
  let allowed = markdown_normal_line_allowance(scanned)
  let lines = markdown_lines_from_scanner(scanned)
  for i in 0..<lines.length() {
    if markdown_line_is_normal_allowed(allowed, i) &&
      parse_markdown_footnote_definition_head(lines[i]) is Some(_) {
      out[i] = true
    }
  }
  out
}

///|
fn markdown_block_lines_are_normal(
  scanned : @dpmd.MarkdownDocument,
  line_start : Int,
  line_end : Int,
) -> Bool {
  if line_start < 1 || line_end < line_start {
    return false
  }
  let allowed = markdown_normal_line_allowance(scanned)
  let mut i = line_start - 1
  while i < line_end && i < allowed.length() {
    if !allowed[i] {
      return false
    }
    i += 1
  }
  true
}

///|
fn trim_trailing_blank_markdown_lines(
  lines : Array[String],
  inline_cache_by_line : Array[MarkdownInlineScanResult?],
) -> Unit {
  while lines.length() > 0 && lines[lines.length() - 1].trim() == "" {
    ignore(lines.pop())
    if inline_cache_by_line.length() > 0 {
      ignore(inline_cache_by_line.pop())
    }
  }
}

///|
fn markdown_footnote_definition_lines(
  definitions : Array[MarkdownFootnoteDefinitionDraft],
) -> Array[String] {
  let out : Array[String] = []
  for i in 0..<definitions.length() {
    let definition = definitions[i]
    let body_lines = if definition.body == "" {
      [""]
    } else {
      definition.body
      .replace(old="\r\n", new="\n")
      .replace(old="\r", new="\n")
      .split("\n")
      .map(fn(line) { line.to_owned() })
      .iter()
      .collect()
    }

    out.push("[^" + definition.note_id + "]: " + body_lines[0])
    for j in 1..<body_lines.length() {
      if body_lines[j] == "" {
        out.push("")
      } else {
        out.push("    " + body_lines[j])
      }
    }
    if i + 1 < definitions.length() {
      out.push("")
    }
  }
  out
}

///|
fn normalized_markdown_inline_cache_lines(
  body_inline_cache : Array[MarkdownInlineScanResult?],
  definitions : Array[MarkdownFootnoteDefinitionDraft],
) -> Array[MarkdownInlineScanResult?] {
  let out : Array[MarkdownInlineScanResult?] = []
  out.append(body_inline_cache)

  if definitions.length() > 0 {
    if body_inline_cache.length() > 0 {
      out.push(None)
    }
    for _line in markdown_footnote_definition_lines(definitions) {
      out.push(None)
    }
  }

  out
}

///|
fn rich_paragraph_from_markdown_inline_cache(
  inline_cache_by_line : Array[MarkdownInlineScanResult?],
  line_start : Int,
  line_end : Int,
) -> Array[@cor.Inline]? {
  if line_start < 1 || line_end < line_start {
    return None
  }

  let out : Array[@cor.Inline] = []
  let mut found_note_ref = false
  let mut i = line_start - 1
  while i < line_end {
    if i >= inline_cache_by_line.length() {
      return None
    }

    match inline_cache_by_line[i] {
      Some(scan) => {
        if i > line_start - 1 {
          out.push(@cor.Inline::Break)
        }
        out.append(scan.inlines)
        if scan.found_note_ref {
          found_note_ref = true
        }
      }
      None => return None
    }
    i += 1
  }

  if found_note_ref {
    Some(out)
  } else {
    None
  }
}

///|
fn count_markdown_repeated_char(
  chars : Array[Char],
  start : Int,
  ch : Char,
) -> Int {
  let mut i = start
  while i < chars.length() && chars[i] == ch {
    i += 1
  }
  i - start
}

///|
fn markdown_char_is_escaped(chars : Array[Char], index : Int) -> Bool {
  if index <= 0 {
    return false
  }
  let mut slash_count = 0
  let mut i = index - 1
  while true {
    if chars[i] != '\\' {
      break
    }
    slash_count += 1
    if i == 0 {
      break
    }
    i -= 1
  }
  slash_count % 2 == 1
}

///|
fn is_markdown_note_id_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '_' ||
  ch == '-'
}
