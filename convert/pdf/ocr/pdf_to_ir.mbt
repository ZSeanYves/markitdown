///|
/// Convert OCR plain text into IR.
/// New strategy:
/// - Normalize line endings
/// - Split pages by formfeed \f
/// - Detect repeated header/footer noise across pages
/// - Strip page-level noise page by page
/// - Merge cleaned pages with an internal page-break marker
/// - Recover blocks once on the merged text
///
/// OCR path is kept independent from native PDF path because source signals differ:
/// OCR delivers flattened text with weaker geometry; reusing native heuristics
/// directly would reduce explainability and increase false structural recovery.

///|
fn dump_ocr_debug_stage(
  input_path : String,
  out_dir : String,
  stage : String,
  content : String,
) -> Unit {
  if out_dir == "" {
    return
  }
  let base = @cor.basename(input_path)
  let out = out_dir + "/" + base + ".pdf_ocr_debug." + stage + ".txt"
  @fs.write_string_to_file(out, content, encoding="utf8") catch {
    _ => ()
  }
}

///|
fn ocr_text_to_ir_document_with_debug(
  input_path : String,
  out_dir : String,
  text0 : String,
  pipeline_debug : Bool,
) -> @cor.Document {
  let text = @cor.normalize_text(text0)
  let doc = @cor.new_document()

  let pages : Array[String] = []
  for page_sv in text.split("\f") {
    let page = page_sv.to_owned()
    if page.trim() != "" {
      pages.push(page)
    }
  }

  if pages.length() == 0 {
    return doc
  }

  if pipeline_debug {
    dump_ocr_debug_stage(
      input_path,
      out_dir,
      "01_page_split",
      render_debug_pages("page_split", pages),
    )
  }

  let (head_keys, tail_keys) = detect_repeated_page_noise(pages)

  if pipeline_debug {
    let repeated_clean_pages : Array[String] = []
    for page in pages {
      repeated_clean_pages.push(
        strip_page_repeated_noise_only(page, head_keys, tail_keys),
      )
    }
    dump_ocr_debug_stage(
      input_path,
      out_dir,
      "02_repeated_cleanup",
      render_debug_pages("repeated_cleanup", repeated_clean_pages),
    )
  }

  let clean_pages : Array[String] = []
  let mut _page_idx = 0
  for page in pages {
    let clean_page = strip_page_noise(page, head_keys, tail_keys)
    if clean_page.trim() != "" {
      clean_pages.push(clean_page)

      let mut shown = 0
      for sv in clean_page.split("\n") {
        let line = sv.trim().to_owned()
        if line != "" {
          shown += 1
          if shown >= 8 {
            break
          }
        }
      }
    }
    _page_idx += 1
  }

  if pipeline_debug {
    dump_ocr_debug_stage(
      input_path,
      out_dir,
      "03_page_noise_cleanup",
      render_debug_pages("page_noise_cleanup", clean_pages),
    )
  }

  let blocks_before_merge : Array[PdfBlock] = []
  for page in clean_pages {
    for b in split_blocks_smart(page) {
      blocks_before_merge.push(b)
    }
  }
  if pipeline_debug {
    dump_ocr_debug_stage(
      input_path,
      out_dir,
      "04_blocks_before_cross_page_merge",
      render_ocr_blocks(blocks_before_merge),
    )
  }

  let merged = merge_clean_pages_with_breaks(clean_pages)
  let mut shown = 0
  for sv in merged.split("\n") {
    let line = sv.trim().to_owned()
    if line != "" {
      shown += 1
      if shown >= 15 {
        break
      }
    }
  }

  let blocks_after_merge = coalesce_loose_paragraph_blocks(
    split_blocks_smart(merged),
  )
  if pipeline_debug {
    dump_ocr_debug_stage(
      input_path,
      out_dir,
      "05_blocks_after_cross_page_merge",
      render_ocr_blocks(blocks_after_merge),
    )
  }

  let mut seen_h1 = false
  for b in blocks_after_merge {
    match b {
      PdfBlock::Heading(level, text) => {
        let out_level = normalize_heading_level_after_first_h1(
          seen_h1, level, text,
        )
        if out_level == 1 {
          seen_h1 = true
        }
        @cor.push(doc, @cor.Block::Heading(out_level, text))
      }
      PdfBlock::Paragraph(text) => @cor.push(doc, @cor.Block::Paragraph(text))
      PdfBlock::ListItem(ordered, level, text) =>
        @cor.push(doc, @cor.Block::ListItem(ordered, level, text))
    }
  }

  doc
}

///|
fn normalize_heading_level_after_first_h1(
  seen_h1 : Bool,
  level : Int,
  text : String,
) -> Int {
  if level != 1 {
    return level
  }

  if !seen_h1 {
    return 1
  }

  if guess_numbered_heading_level(text) == 1 || looks_like_heading_marker(text) {
    return 1
  }

  if looks_like_repeated_page_template_title(text) {
    return 2
  }

  1
}

///|
fn looks_like_repeated_page_template_title(s : String) -> Bool {
  let t = s.trim().to_owned()
  let n = t.to_array().length()
  if n < 8 || n > 36 {
    return false
  }

  if !(t.contains("page ") || t.contains("Page ")) {
    return false
  }

  let mut has_digit = false
  for c in t.to_array() {
    if c >= '0' && c <= '9' {
      has_digit = true
      break
    }
  }
  has_digit
}

///|
fn coalesce_loose_paragraph_blocks(blocks : Array[PdfBlock]) -> Array[PdfBlock] {
  let out : Array[PdfBlock] = []
  for b in blocks {
    if out.length() == 0 {
      out.push(b)
      continue
    }

    let last_idx = out.length() - 1
    match (out[last_idx], b) {
      (PdfBlock::Paragraph(p), PdfBlock::Paragraph(c)) =>
        if can_soft_merge_paragraphs(p, c) {
          out[last_idx] = PdfBlock::Paragraph(append_line(p, c))
        } else {
          out.push(b)
        }
      _ => out.push(b)
    }
  }
  out
}

///|
fn can_soft_merge_paragraphs(prev : String, cur : String) -> Bool {
  let p = prev.trim().to_owned()
  let c = cur.trim().to_owned()
  if p == "" || c == "" {
    return false
  }

  if should_veto_short_independent_line_merge(p, c) {
    return false
  }

  if should_veto_lead_in_line_merge(p) {
    return false
  }

  if ends_like_sentence(p) {
    return false
  }

  if looks_like_label_token_line_start(c) {
    if should_allow_label_token_continuation_merge(p, c) {
      return true
    }
    return false
  }

  if looks_like_list_item_sentence(c) ||
    looks_like_side_marker_label_line(c) ||
    is_probable_page_number(c) {
    return false
  }

  true
}

///|
fn should_allow_label_token_continuation_merge(
  prev : String,
  cur : String,
) -> Bool {
  let p = prev.trim().to_owned()
  let c = cur.trim().to_owned()
  if p == "" || c == "" {
    return false
  }

  if ends_like_sentence(p) {
    return false
  }

  match last_char(p) {
    Some(ch) =>
      if ch == ',' ||
        ch == ':' ||
        ch == ';' ||
        ch == '，' ||
        ch == '：' ||
        ch == '；' {
        return false
      }
    None => return false
  }

  let parts : Array[String] = c
    .split(" ")
    .map(fn(sv) { sv.trim().to_owned() })
    .filter(fn(x) { x != "" })
    .iter()
    .collect()
  if parts.length() < 2 {
    return false
  }

  let tail = parts[1]
  match first_char(tail) {
    Some(ch) => if !(ch >= 'a' && ch <= 'z') { return false }
    None => return false
  }

  parts.length() <= 6 && c.to_array().length() <= 42
}

///|
fn should_veto_short_independent_line_merge(
  prev : String,
  cur : String,
) -> Bool {
  let p = prev.trim().to_owned()
  let c = cur.trim().to_owned()
  if p == "" || c == "" {
    return false
  }

  if p.contains(" ") || p.to_array().length() > 8 {
    return false
  }

  let mut has_alpha = false
  for ch in p.to_array() {
    if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') {
      has_alpha = true
      continue
    }
    return false
  }

  if !has_alpha {
    return false
  }

  !starts_like_new_block(c)
}

///|
fn should_veto_lead_in_line_merge(prev : String) -> Bool {
  let p = prev.trim().to_owned()
  if p == "" {
    return false
  }

  let cs = p.to_array()
  let n = cs.length()
  if n < 4 || n > 40 {
    return false
  }

  let last = cs[n - 1]
  if last != ',' && last != ':' {
    return false
  }

  let mut words = 0
  for sv in p.split(" ") {
    if sv.trim() != "" {
      words += 1
    }
  }
  if words > 4 {
    return false
  }

  true
}

///|
fn render_debug_pages(title : String, pages : Array[String]) -> String {
  let out : Array[String] = []
  out.push("# " + title)
  let mut i = 0
  for page in pages {
    i += 1
    out.push("")
    out.push("## page " + i.to_string())
    out.push(page)
  }
  out.join("\n")
}

///|
fn render_ocr_blocks(blocks : Array[PdfBlock]) -> String {
  let out : Array[String] = []
  let mut i = 0
  for b in blocks {
    i += 1
    match b {
      PdfBlock::Heading(level, text) =>
        out.push(
          i.to_string() + ". Heading(" + level.to_string() + "): " + text,
        )
      PdfBlock::Paragraph(text) =>
        out.push(i.to_string() + ". Paragraph: " + text)
      PdfBlock::ListItem(ordered, level, text) =>
        out.push(
          i.to_string() +
          ". ListItem(" +
          (if ordered { "ordered" } else { "unordered" }) +
          ", level=" +
          level.to_string() +
          "): " +
          text,
        )
    }
  }
  out.join("\n")
}
