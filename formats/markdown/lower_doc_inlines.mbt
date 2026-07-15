///|
fn markdown_parse_rich_inlines(
  text : String,
  source_ref : @core.SourceRef,
  diagnostics : @core.Diagnostics,
  image_asset_index : Ref[Int],
  defined_footnotes : Map[String, Bool],
) -> MarkdownInlineParseResult {
  let out : Array[@core.CoreInline] = []
  let unsafe_link_count : Ref[Int] = { val: 0 }
  let chars = text.to_array()
  let mut i = 0
  let mut cursor = 0
  while i < chars.length() {
    if chars[i] == '!' && i + 1 < chars.length() && chars[i + 1] == '[' {
      match markdown_find_inline_link(chars, i + 1) {
        Some((label_end, path_start, path_end)) => {
          if cursor < i {
            out.push(
              @core.make_inline_text(text[cursor:i].to_owned(), source_ref~),
            )
          }
          let alt = text[i + 2:label_end].to_owned()
          let path = text[path_start + 1:path_end].to_owned()
          let normalized = markdown_image_output_path(path, image_asset_index)
          let inline = @core.make_inline_image(alt, normalized.0, source_ref~)
          inline.attrs.set("asset_id", normalized.1)
          match normalized.2 {
            Some(source_path) => inline.attrs.set("source_path", source_path)
            None => ()
          }
          if markdown_remote_href(path) {
            inline.attrs.set("remote", "true")
          }
          out.push(inline)
          cursor = path_end + 1
          i = cursor
          continue
        }
        None => ()
      }
    }
    if chars[i] == '[' {
      match markdown_find_footnote_reference(chars, i) {
        Some((label_end, label)) => {
          if cursor < i {
            out.push(
              @core.make_inline_text(text[cursor:i].to_owned(), source_ref~),
            )
          }
          if defined_footnotes.contains(label) {
            let marker = text[i:label_end + 1].to_owned()
            let inline = @core.make_inline_text(marker, source_ref~)
            let inline = @core.inline_with_attr(
              inline, "annotation_role", "note_ref",
            )
            let inline = @core.inline_with_attr(
              inline, "annotation_kind", "footnote",
            )
            let inline = @core.inline_with_attr(inline, "annotation_id", label)
            let inline = @core.inline_with_attr(
              inline, "annotation_marker", marker,
            )
            out.push(@core.inline_with_attr(inline, "render_literal", "true"))
          } else {
            out.push(@core.make_inline_text("^" + label, source_ref~))
          }
          cursor = label_end + 1
          i = cursor
          continue
        }
        None => ()
      }
      match markdown_find_inline_link(chars, i) {
        Some((label_end, path_start, path_end)) => {
          if cursor < i {
            out.push(
              @core.make_inline_text(text[cursor:i].to_owned(), source_ref~),
            )
          }
          let label = text[i + 1:label_end].to_owned()
          let href = text[path_start + 1:path_end].to_owned()
          let safe_href = markdown_safe_href(href)
          match safe_href {
            Some(value) =>
              out.push(@core.make_inline_link(label, value, source_ref~))
            None => {
              diagnostics.warnings.push("unsafe markdown link href dropped")
              diagnostics.degraded_features.push(
                "markdown_unsafe_link_text_only",
              )
              diagnostics.fallback_trace.push(
                "markdown unsafe link -> keep text, drop href",
              )
              out.push(@core.make_inline_text(label, source_ref~))
              unsafe_link_count.val += 1
            }
          }
          cursor = path_end + 1
          i = cursor
          continue
        }
        None => ()
      }
    }
    if chars[i] == '`' {
      match markdown_find_inline_code_end(chars, i) {
        Some(end) => {
          if cursor < i {
            out.push(
              @core.make_inline_text(text[cursor:i].to_owned(), source_ref~),
            )
          }
          out.push(
            @core.make_inline_code(text[i + 1:end].to_owned(), source_ref~),
          )
          cursor = end + 1
          i = cursor
          continue
        }
        None => ()
      }
    }
    i += 1
  }
  if cursor < text.length() {
    out.push(@core.make_inline_text(text[cursor:].to_owned(), source_ref~))
  }
  let rich_inlines = if markdown_inline_is_plain_text_only(out) &&
    unsafe_link_count.val == 0 {
    None
  } else {
    Some(out)
  }
  { rich_inlines, unsafe_link_count: unsafe_link_count.val }
}

///|
fn markdown_inline_is_plain_text_only(
  inlines : Array[@core.CoreInline],
) -> Bool {
  if inlines.length() == 0 {
    return true
  }
  for inline in inlines {
    if inline.kind != Text {
      return false
    }
    if inline.attrs.length() > 0 {
      return false
    }
  }
  true
}

///|
fn markdown_footnote_definition_labels(text : String) -> Array[String] {
  let out : Array[String] = []
  for line in text.split("\n").to_array() {
    let trimmed = line.trim().to_owned()
    if trimmed.has_prefix("[^") {
      match markdown_parse_footnote_definition_line(trimmed) {
        Some((label, _)) => out.push(label)
        None => ()
      }
    }
  }
  out
}

///|
fn markdown_footnote_definition_head(
  block : @dmd.MarkdownBlock,
) -> (String, String)? {
  let lines = block.raw_text.split("\n").to_array()
  if lines.length() == 0 {
    return None
  }
  markdown_parse_footnote_definition_line(lines[0].trim().to_owned())
}

///|
fn markdown_parse_footnote_definition_line(line : String) -> (String, String)? {
  if !line.has_prefix("[^") {
    return None
  }
  let chars = line.to_array()
  let mut i = 2
  let label : Array[Char] = []
  while i < chars.length() {
    if chars[i] == ']' {
      if label.length() == 0 || i + 1 >= chars.length() || chars[i + 1] != ':' {
        return None
      }
      let body = if i + 2 < line.length() {
        line[i + 2:].trim().to_owned()
      } else {
        ""
      }
      return Some((String::from_array(label), body))
    }
    if chars[i] == '\n' || chars[i] == '[' {
      return None
    }
    label.push(chars[i])
    i += 1
  }
  None
}

///|
fn markdown_next_non_blank_block_index(
  blocks : Array[@dmd.MarkdownBlock],
  start : Int,
) -> Int? {
  let mut i = start
  while i < blocks.length() {
    if blocks[i].kind != BlankLine {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn markdown_block_belongs_to_footnote_definition(
  block : @dmd.MarkdownBlock,
) -> Bool {
  match block.kind {
    ListItem => markdown_list_indent(block.raw_text) >= 4
    BlockQuote => block.raw_text.has_prefix("    ")
    ParagraphLike =>
      block.raw_text.has_prefix("    ") ||
      (
        block.raw_text.contains("\n") &&
        !block.raw_text.trim().to_owned().has_prefix("[^")
      )
    _ => false
  }
}

///|
fn markdown_take_first_footnote_body_line(tail : String) -> (String?, String) {
  let lines = tail.split("\n").to_array()
  let mut i = 0
  while i < lines.length() {
    let line = lines[i].to_owned()
    if line.trim() == "" {
      i += 1
      continue
    }
    let body = markdown_strip_footnote_body_indent(line)
    let remainder_lines : Array[String] = []
    if i + 1 < lines.length() {
      let mut j = i + 1
      while j < lines.length() {
        remainder_lines.push(lines[j].to_owned())
        j += 1
      }
    }
    let remainder = if remainder_lines.length() == 0 {
      ""
    } else {
      "\n" + remainder_lines.join("\n")
    }
    return (Some(body), remainder)
  }
  (None, "")
}

///|
fn markdown_strip_footnote_body_indent(line : String) -> String {
  if line.has_prefix("    ") {
    line[4:].trim().to_owned()
  } else if line.has_prefix("\t") {
    line[1:].trim().to_owned()
  } else {
    line.trim().to_owned()
  }
}

///|
fn markdown_normalize_footnote_references(
  text : String,
  defined_footnotes : Map[String, Bool],
) -> String {
  if !markdown_may_have_footnote_reference(text) {
    return text
  }
  let chars = text.to_array()
  let out = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '[' {
      match markdown_find_footnote_reference(chars, i) {
        Some((label_end, label)) => {
          let is_definition = label_end + 1 < chars.length() &&
            chars[label_end + 1] == ':'
          if defined_footnotes.contains(label) || is_definition {
            out.write_string(text[i:label_end + 1].to_owned())
          } else {
            out.write_char('^')
            out.write_string(label)
          }
          i = label_end + 1
          continue
        }
        None => ()
      }
    }
    out.write_char(chars[i])
    i += 1
  }
  out.to_string()
}

///|
fn markdown_may_have_footnote_reference(text : String) -> Bool {
  text.contains("[^")
}

///|
fn markdown_may_have_rich_inline_markup(text : String) -> Bool {
  text.contains("[") || text.contains("!") || text.contains("`")
}

///|
fn markdown_find_footnote_reference(
  chars : Array[Char],
  start : Int,
) -> (Int, String)? {
  if start + 3 >= chars.length() ||
    chars[start] != '[' ||
    chars[start + 1] != '^' {
    return None
  }
  let mut i = start + 2
  let label : Array[Char] = []
  while i < chars.length() {
    if chars[i] == ']' {
      if label.length() == 0 {
        return None
      }
      return Some((i, String::from_array(label)))
    }
    if chars[i] == '\n' || chars[i] == '[' {
      return None
    }
    label.push(chars[i])
    i += 1
  }
  None
}

///|
fn markdown_find_inline_link(
  chars : Array[Char],
  start : Int,
) -> (Int, Int, Int)? {
  let mut label_end : Int? = None
  let mut path_start : Int? = None
  let mut i = start
  while i < chars.length() {
    if chars[i] == ']' {
      label_end = Some(i)
      if i + 1 < chars.length() && chars[i + 1] == '(' {
        path_start = Some(i + 1)
        break
      }
      return None
    }
    i += 1
  }
  match (label_end, path_start) {
    (Some(end), Some(path_open)) => {
      let mut j = path_open + 1
      let mut depth = 0
      while j < chars.length() {
        if chars[j] == '(' {
          depth += 1
        } else if chars[j] == ')' {
          if depth == 0 {
            return Some((end, path_open, j))
          }
          depth -= 1
        }
        j += 1
      }
      None
    }
    _ => None
  }
}

///|
fn markdown_find_inline_code_end(chars : Array[Char], start : Int) -> Int? {
  let mut i = start + 1
  while i < chars.length() {
    if chars[i] == '`' {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn markdown_safe_href(href : String) -> String? {
  let trimmed = href.trim().to_owned()
  let lowered = trimmed.to_lower()
  if lowered.has_prefix("javascript:") ||
    lowered.has_prefix("vbscript:") ||
    lowered.has_prefix("data:") ||
    lowered.has_prefix("file:") {
    None
  } else {
    Some(trimmed)
  }
}

///|
fn markdown_remote_href(href : String) -> Bool {
  let lowered = href.trim().to_owned().to_lower()
  lowered.has_prefix("http://") || lowered.has_prefix("https://")
}

///|
fn markdown_image_output_path(
  path : String,
  image_asset_index : Ref[Int],
) -> (String, String, String?) {
  let trimmed = path.trim().to_owned()
  if markdown_remote_href(trimmed) || !markdown_safe_local_image_src(trimmed) {
    image_asset_index.val += 1
    return (
      trimmed,
      "markdown-image-" + image_asset_index.val.to_string(),
      None,
    )
  }
  let src = markdown_strip_query_and_hash(trimmed)
  image_asset_index.val += 1
  (
    "assets/image" +
    markdown_two_digit(image_asset_index.val) +
    "." +
    markdown_image_ext_from_src(src),
    "markdown-image-" + image_asset_index.val.to_string(),
    Some(src),
  )
}

///|
fn markdown_safe_local_image_src(src : String) -> Bool {
  if src == "" ||
    src.has_prefix("/") ||
    src.has_prefix("\\") ||
    src.contains("..") ||
    src.contains(":") {
    return false
  }
  true
}

///|
fn markdown_strip_query_and_hash(src : String) -> String {
  let chars = src.to_array()
  let mut end = chars.length()
  for i in 0..<chars.length() {
    if chars[i] == '?' || chars[i] == '#' {
      end = i
      break
    }
  }
  src[:end].to_owned()
}

///|
fn markdown_image_ext_from_src(src : String) -> String {
  let trimmed = src.trim().to_owned().to_lower()
  let chars = trimmed.to_array()
  let mut last_dot = -1
  for i in 0..<chars.length() {
    if chars[i] == '.' {
      last_dot = i
    }
  }
  if last_dot >= 0 && last_dot + 1 < trimmed.length() {
    trimmed[last_dot + 1:].to_owned()
  } else {
    "png"
  }
}

///|
fn markdown_two_digit(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn markdown_html_contains_unsafe_tag(text : String) -> Bool {
  let lowered = text.to_lower()
  lowered.contains("<script") || lowered.contains("<style")
}

///|
fn markdown_source_ref_with_path(
  source_ref : @core.SourceRef,
  markdown_path : String,
) -> @core.SourceRef {
  @core.source_ref_with_markdown_path(
    source_ref,
    source_ref.file_id,
    source_ref.format,
    Some(markdown_path),
  )
}

///|
fn markdown_source_ref_from_lines(
  source : @input.InputSource,
  line_start : Int,
  line_end : Int,
  base_source_ref? : @core.SourceRef? = None,
) -> @core.SourceRef {
  match base_source_ref {
    Some(base) =>
      @core.source_ref_with_lines(
        base,
        base.file_id,
        base.format,
        Some(line_start),
        Some(line_end),
      )
    None =>
      @core.source_ref_with_lines(
        @core.empty_source_ref(),
        Some(source.source_name),
        Some("markdown"),
        Some(line_start),
        Some(line_end),
      )
  }
}

///|
fn markdown_annotate_paths_and_report(
  blocks : Array[@core.CoreBlock],
) -> (Array[@core.CoreBlock], MarkdownBlockReport) {
  let heading_index : Ref[Int] = { val: 0 }
  let paragraph_index : Ref[Int] = { val: 0 }
  let list_index : Ref[Int] = { val: 0 }
  let table_index : Ref[Int] = { val: 0 }
  let code_index : Ref[Int] = { val: 0 }
  let quote_index : Ref[Int] = { val: 0 }
  let raw_index : Ref[Int] = { val: 0 }
  let report = markdown_new_block_report_accumulator()
  (
    blocks.map(block => {
      markdown_annotate_single_block_path(
        block, heading_index, paragraph_index, list_index, table_index, code_index,
        quote_index, raw_index, "/", report, 0,
      )
    }),
    markdown_block_report_from_accumulator(report),
  )
}

///|
fn markdown_annotate_single_block_path(
  block : @core.CoreBlock,
  heading_index : Ref[Int],
  paragraph_index : Ref[Int],
  list_index : Ref[Int],
  table_index : Ref[Int],
  code_index : Ref[Int],
  quote_index : Ref[Int],
  raw_index : Ref[Int],
  prefix : String,
  report : MarkdownBlockReportAccumulator,
  list_depth : Int,
) -> @core.CoreBlock {
  let source_ref = block.source_ref.unwrap_or(@core.empty_source_ref())
  let path = if source_ref.markdown_path is Some(_) {
    source_ref.markdown_path.unwrap_or("/")
  } else {
    markdown_generated_path_for_block(
      block, heading_index, paragraph_index, list_index, table_index, code_index,
      quote_index, raw_index, prefix,
    )
  }
  let next_source_ref = @core.source_ref_with_markdown_path(
    source_ref,
    source_ref.file_id,
    source_ref.format,
    Some(path),
  )
  markdown_accumulate_single_block_report(block, report, list_depth)
  let children = if block.children.length() > 0 {
    let child_prefix = path
    let out : Array[@core.CoreBlock] = []
    for i in 0..<block.children.length() {
      let child = block.children[i]
      let child_ref = child.source_ref.unwrap_or(@core.empty_source_ref())
      let child_path = child_prefix + "/item[" + i.to_string() + "]"
      let child_source_ref = @core.source_ref_with_markdown_path(
        child_ref,
        child_ref.file_id,
        child_ref.format,
        Some(child_path),
      )
      let annotated_child = markdown_annotate_single_block_path(
        { ..child, source_ref: Some(child_source_ref) },
        heading_index,
        paragraph_index,
        list_index,
        table_index,
        code_index,
        quote_index,
        raw_index,
        child_path + "/",
        report,
        if block.kind == List {
          list_depth + 1
        } else {
          list_depth
        },
      )
      out.push(annotated_child)
    }
    out
  } else {
    block.children
  }
  { ..block, source_ref: Some(next_source_ref), children }
}

///|
fn markdown_generated_path_for_block(
  block : @core.CoreBlock,
  heading_index : Ref[Int],
  paragraph_index : Ref[Int],
  list_index : Ref[Int],
  table_index : Ref[Int],
  code_index : Ref[Int],
  quote_index : Ref[Int],
  raw_index : Ref[Int],
  prefix : String,
) -> String {
  match block.kind {
    Heading => {
      let index = heading_index.val
      heading_index.val += 1
      prefix + "heading[" + index.to_string() + "]"
    }
    Paragraph => {
      let index = paragraph_index.val
      paragraph_index.val += 1
      prefix + "paragraph[" + index.to_string() + "]"
    }
    List => {
      let index = list_index.val
      list_index.val += 1
      prefix + "list[" + index.to_string() + "]"
    }
    Table => {
      let index = table_index.val
      table_index.val += 1
      prefix + "table[" + index.to_string() + "]"
    }
    Code => {
      let index = code_index.val
      code_index.val += 1
      prefix + "code[" + index.to_string() + "]"
    }
    BlockQuote => {
      let index = quote_index.val
      quote_index.val += 1
      prefix + "blockquote[" + index.to_string() + "]"
    }
    Raw => {
      let existing = block.attrs.get("raw_kind").unwrap_or("raw")
      let index = raw_index.val
      raw_index.val += 1
      prefix + existing + "[" + index.to_string() + "]"
    }
    Image => {
      let index = paragraph_index.val
      paragraph_index.val += 1
      prefix + "image[" + index.to_string() + "]"
    }
    _ => prefix + "block[0]"
  }
}

///|
fn markdown_source_ref(
  block : @dmd.MarkdownBlock,
  source : @input.InputSource,
  base_source_ref? : @core.SourceRef? = None,
) -> @core.SourceRef {
  markdown_source_ref_from_lines(
    source,
    block.line_start,
    block.line_end,
    base_source_ref~,
  )
}

///|
fn markdown_heading_level(text : String) -> Int {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  let mut level = 0
  while level < chars.length() && chars[level] == '#' {
    level += 1
  }
  @fshared.clamp_int(level, 1, 6)
}

///|
fn markdown_setext_heading_level(text : String) -> Int {
  let lines = text.split("\n").to_array()
  if lines.length() < 2 {
    return 1
  }
  let underline = lines[1].trim().to_owned()
  if underline.has_prefix("=") {
    1
  } else {
    2
  }
}

///|
fn markdown_list_is_ordered(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  let mut saw_digit = false
  for ch in chars {
    if ch >= '0' && ch <= '9' {
      saw_digit = true
      continue
    }
    if (ch == '.' || ch == ')') && saw_digit {
      return true
    }
    return false
  }
  false
}

///|
fn parse_markdown_image(text : String) -> (String, String)? {
  let trimmed = text.trim().to_owned()
  if !trimmed.has_prefix("![") || !trimmed.has_suffix(")") {
    return None
  }
  let chars = trimmed.to_array()
  let mut alt_end : Int? = None
  let mut path_start : Int? = None
  for i in 0..<chars.length() {
    if chars[i] == ']' && alt_end is None {
      alt_end = Some(i)
    } else if chars[i] == '(' && path_start is None {
      path_start = Some(i)
    }
  }
  match (alt_end, path_start) {
    (Some(alt_index), Some(path_index)) =>
      if path_index > alt_index && alt_index >= 2 {
        Some(
          (
            trimmed[2:alt_index].to_owned(),
            trimmed[path_index + 1:trimmed.length() - 1].to_owned(),
          ),
        )
      } else {
        None
      }
    _ => None
  }
}

///|
fn markdown_frontmatter_kind_name(
  kind : @dmd.MarkdownFrontmatterKind,
) -> String {
  match kind {
    Yaml => "yaml"
    Toml => "toml"
    Unknown => "unknown"
  }
}

///|
fn strip_fence_block_content(text : String) -> String {
  let lines = text.split("\n").to_array()
  if lines.length() < 2 {
    return text
  }
  let inner : Array[String] = []
  for i in 1..<lines.length() {
    if i == lines.length() - 1 && lines[i].trim().has_prefix("```") {
      ()
    } else {
      inner.push(lines[i].to_owned())
    }
  }
  inner.join("\n")
}

///|
fn strip_markdown_heading(text : String) -> String {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  let mut i = 0
  while i < chars.length() && chars[i] == '#' {
    i += 1
  }
  trimmed[i:].trim().to_owned()
}

///|
fn strip_setext_heading(text : String) -> String {
  text.split("\n").to_array()[0].trim().to_owned()
}

///|
fn strip_markdown_list_marker(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed.has_prefix("- ") ||
    trimmed.has_prefix("* ") ||
    trimmed.has_prefix("+ ") {
    return trimmed[2:].trim().to_owned()
  }
  let chars = trimmed.to_array()
  for i in 0..<chars.length() {
    if chars[i] == '.' || chars[i] == ')' {
      return trimmed[i + 1:].trim().to_owned()
    }
  }
  trimmed
}

///|
fn strip_markdown_blockquote(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed.has_prefix(">") {
    trimmed[1:].trim().to_owned()
  } else {
    trimmed
  }
}
