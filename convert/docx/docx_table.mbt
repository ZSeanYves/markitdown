///|
fn scan_paragraph(
  p_xml : String,
  rel_ctx : DocxRelationshipContext,
  asset_by_target : Map[String, String],
  styles : DocxStyles,
  numbering : DocxNumbering,
  max_heading : Int,
  ledger : DocxReferenceLedger?,
) -> Array[@cor.Block] {
  let out : Array[@cor.Block] = []
  let visible_xml = strip_docx_text_box_content_xml(
    strip_docx_deleted_revision_xml(p_xml),
  )

  // 1) 标题级别：优先 styles.xml，失败再 fallback
  let level = read_heading_level(visible_xml, styles, max_heading)

  // 2) 图片 embed（常见：<a:blip r:embed="rId5">）
  match read_docx_image_context(visible_xml, rel_ctx, asset_by_target) {
    Some(img) =>
      out.push(
        @cor.Block::ImageBlock({
          path: img.asset_path,
          alt_text: img.alt_text,
          title: img.title,
          caption: None,
          origin: None,
        }),
      )
    None => ()
  }

  // 3) 段落文本
  let scan = scan_docx_inline_text(visible_xml, rel_ctx, ledger)
  let inlines = scan.inlines
  let text = scan.text
  if @cor.is_blank(text) {
    return out
  }

  if level > 0 {
    if inlines.length() > 0 {
      out.push(@cor.Block::RichHeading(level, inlines))
    } else {
      out.push(@cor.Block::Heading(level, text))
    }
    return out
  }

  match read_paragraph_list_info(visible_xml) {
    Some(info) =>
      match resolve_list_kind(numbering, info) {
        Some(kind) => return emit_list_block(out, inlines, text, info, kind)
        None => ()
      }
    None => ()
  }

  match read_style_linked_list_info(visible_xml, styles) {
    Some(info) =>
      match resolve_list_kind(numbering, info) {
        Some(kind) => return emit_list_block(out, inlines, text, info, kind)
        None => ()
      }
    None => ()
  }

  // numbering.xml 缺失或未命中时，仍保留旧兜底
  if paragraph_is_list_item(visible_xml) {
    let fallback_ordered = style_or_text_looks_ordered_list(visible_xml, text)
    let fallback_level = fallback_list_level(visible_xml, styles)
    if inlines.length() > 0 {
      out.push(
        @cor.Block::RichListItem(fallback_ordered, fallback_level, inlines),
      )
    } else {
      out.push(@cor.Block::ListItem(fallback_ordered, fallback_level, text))
    }
    return out
  }

  if paragraph_is_blockquote(visible_xml, styles) {
    out.push(@cor.Block::BlockQuote(text))
    return out
  }

  if paragraph_is_codeblock(visible_xml, styles, text) {
    out.push(@cor.Block::CodeBlock(text))
    return out
  }

  if inlines.length() > 0 {
    out.push(@cor.Block::RichParagraph(inlines))
  } else {
    out.push(@cor.Block::Paragraph(text))
  }
  out
}

///|
fn emit_list_block(
  out : Array[@cor.Block],
  inlines : Array[@cor.Inline],
  text : String,
  info : ParagraphListInfo,
  kind : ListKind,
) -> Array[@cor.Block] {
  let ordered = match kind {
    Bullet => false
    Ordered => true
  }

  let list_level = if info.ilvl < 0 { 0 } else { info.ilvl }
  if inlines.length() > 0 {
    out.push(@cor.Block::RichListItem(ordered, list_level, inlines))
  } else {
    out.push(@cor.Block::ListItem(ordered, list_level, text))
  }
  out
}

///|
fn read_docx_image_context(
  p_xml : String,
  rel_ctx : DocxRelationshipContext,
  asset_by_target : Map[String, String],
) -> DocxImageContext? {
  match read_attr_value(p_xml, "r:embed=\"") {
    Some(rid) => {
      let target = lookup_doc_relationship_target(rel_ctx, rid)
      if target == "" {
        return None
      }

      let asset_path = rid_to_asset_path(target, asset_by_target)
      if asset_path == "" {
        return None
      }

      Some({
        asset_path,
        alt_text: string_opt_or(
          first_docx_image_attr(p_xml, "descr"),
          Some("image"),
        ),
        title: first_docx_image_attr(p_xml, "title"),
      })
    }
    None => None
  }
}

///|
fn first_docx_image_attr(p_xml : String, attr_name : String) -> String? {
  string_opt_or(
    read_attr_value_in_first_tag(p_xml, "<wp:docPr", attr_name),
    read_attr_value_in_first_tag(p_xml, "<pic:cNvPr", attr_name),
  )
}

///|
fn read_attr_value_in_first_tag(
  block : String,
  tag_prefix : String,
  attr_name : String,
) -> String? {
  let chars = block.to_array()
  let start = find_sub(chars, 0, tag_prefix)
  if start < 0 {
    return None
  }

  let end_ = find_sub(chars, start, ">")
  if end_ < 0 {
    return None
  }

  let tag = profiled_slice_to_string(chars, start, end_ + 1)
  normalize_optional_docx_image_attr(read_attr_value_in_tag(tag, attr_name))
}

///|
fn normalize_optional_docx_image_attr(value : String?) -> String? {
  match value {
    Some(raw) => {
      let trimmed = @cor.trim_string(raw)
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
fn string_opt_or(primary : String?, fallback : String?) -> String? {
  match primary {
    Some(_) => primary
    None => fallback
  }
}

///|
fn read_heading_level(
  p_xml : String,
  styles : DocxStyles,
  max_heading : Int,
) -> Int {
  match read_pstyle_value(p_xml) {
    Some(v) => {
      let level = heading_level_of(styles, v, max_heading)
      if level > 0 {
        return level
      }

      // fallback：兼容旧样例 / styles.xml 缺失
      let legacy = legacy_heading_level(v)
      if legacy < 1 {
        0
      } else if legacy > max_heading {
        max_heading
      } else {
        legacy
      }
    }
    None => 0
  }
}

///|
fn scan_table_block(tbl_xml : String) -> Array[Array[String]] {
  let chars = strip_docx_deleted_revision_xml(tbl_xml).to_array()
  let mut i = 0
  let rows : Array[Array[String]] = []

  while true {
    let tr1 = find_exact_open_tag(chars, i, wtr_open_tag_chars)
    if tr1 < 0 {
      break
    }
    let tr2 = find_sub(chars, tr1, ">")
    if tr2 < 0 {
      break
    }
    let tr3 = find_matching_docx_element_close(
      chars, tr1, wtr_open_tag_chars, wtr_close_tag_chars,
    )
    if tr3 < 0 {
      break
    }

    let tr_inner = profiled_slice_to_string(chars, tr2 + 1, tr3)
    let tr_chars = tr_inner.to_array()

    let mut j = 0
    let cells : Array[String] = []

    while true {
      let tc1 = find_exact_open_tag(tr_chars, j, wtc_open_tag_chars)
      if tc1 < 0 {
        break
      }

      let tc2 = find_sub(tr_chars, tc1, ">")
      if tc2 < 0 {
        break
      }

      let tc3 = find_matching_docx_element_close(
        tr_chars, tc1, wtc_open_tag_chars, wtc_close_tag_chars,
      )
      if tc3 < 0 {
        break
      }

      let tc_inner = profiled_slice_to_string(tr_chars, tc2 + 1, tc3)

      // 只从 tc_inner 里抽 w:t
      let cell_text = collect_tc_text(tc_inner)
      //println("[DBG] cell_text=" + cell_text)
      //println("[DBG] cell_len=" + cell_text.length().to_string())

      cells.push(cell_text)

      // 游标推进："</w:tc>" 长度 7
      j = tc3 + 7
    }

    if cells.length() > 0 {
      rows.push(cells)
    }

    // "</w:tr>" 长度 7
    i = tr3 + 7
  }

  rows
}

///|
fn read_style_linked_list_info(
  p_xml : String,
  styles : DocxStyles,
) -> ParagraphListInfo? {
  match read_pstyle_value(p_xml) {
    Some(style_id) => style_list_info_of(styles, style_id)
    None => None
  }
}

///|
/// code-like paragraph v1:
/// 1) 优先按段落样式识别
/// 2) 否则在“多行 + 明显代码 token”时保守识别
fn paragraph_is_codeblock(
  p_xml : String,
  styles : DocxStyles,
  text : String,
) -> Bool {
  match read_pstyle_value(p_xml) {
    Some(style_id) =>
      if style_is_code_like(styles, style_id) {
        true
      } else {
        text_is_code_like(text)
      }
    None => text_is_code_like(text)
  }
}

///|
fn style_is_code_like(styles : DocxStyles, style_id : String) -> Bool {
  if code_name_like(style_id) {
    return true
  }

  match style_name_of(styles, style_id) {
    Some(name) => code_name_like(name)
    None => false
  }
}

///|
/// 只匹配比较明确的 code-like 命名
fn code_name_like(s : String) -> Bool {
  let raw = trim_ascii_spaces(s)
  let t = ascii_lower(raw)

  t == "code" ||
  t == "codeblock" ||
  t == "code block" ||
  t == "source" ||
  t == "sourcecode" ||
  t == "source code" ||
  t == "preformatted" ||
  t == "pre" ||
  t == "programlisting" ||
  t.contains("code") ||
  t.contains("source") ||
  t.contains("preformatted") ||
  t.contains("programlisting") ||
  raw.contains("代码") ||
  raw.contains("源码")
}

///|
/// fallback：只有在“多行 + 明显代码 token”时才认
fn text_is_code_like(text : String) -> Bool {
  let t = text.replace(old="\r\n", new="\n").replace(old="\r", new="\n")

  if !t.contains("\n") {
    return false
  }

  let lower = ascii_lower(t)

  t.contains("{") ||
  t.contains("}") ||
  t.contains("(") ||
  t.contains(")") ||
  t.contains(";") ||
  t.contains("=>") ||
  t.contains("->") ||
  t.contains(" = ") ||
  lower.contains("let ") ||
  lower.contains("fn ") ||
  lower.contains("if ") ||
  lower.contains("else") ||
  lower.contains("return") ||
  lower.contains("const ") ||
  lower.contains("var ") ||
  lower.contains("class ") ||
  lower.contains("def ")
}

///|
/// MVP: 只要段落里出现 numPr / ilvl / numId，就先视为列表项
fn paragraph_is_list_item(p_xml : String) -> Bool {
  p_xml.contains("<w:numPr") ||
  p_xml.contains("<w:ilvl") ||
  p_xml.contains("<w:numId")
}

///|
fn fallback_list_level(p_xml : String, styles : DocxStyles) -> Int {
  match read_style_linked_list_info(p_xml, styles) {
    Some(info) => if info.ilvl < 0 { 0 } else { info.ilvl }
    None =>
      match read_pstyle_value(p_xml) {
        Some(style_id) => {
          let level = ordered_list_level_from_style(style_id)
          if level >= 0 {
            level
          } else {
            0
          }
        }
        None => 0
      }
  }
}

///|
fn style_or_text_looks_ordered_list(p_xml : String, text : String) -> Bool {
  match read_pstyle_value(p_xml) {
    Some(style_id) =>
      if ordered_list_style_like(style_id) {
        true
      } else {
        ordered_list_text_like(text)
      }
    None => ordered_list_text_like(text)
  }
}

///|
fn ordered_list_style_like(style_id : String) -> Bool {
  ordered_list_level_from_style(style_id) >= 0
}

///|
fn ordered_list_level_from_style(style_id : String) -> Int {
  let t = ascii_lower(trim_ascii_spaces(style_id))
  if t == "listparagraph" || t == "list paragraph" {
    return -1
  }
  if t.contains("listparagraph") || t.contains("list paragraph") {
    return -1
  }
  if t.contains("listbullet") || t.contains("list bullet") {
    return -1
  }

  let keys : Array[(String, Int)] = [
    ("listnumber", 0),
    ("list number", 0),
    ("listnumber2", 1),
    ("list number 2", 1),
    ("listnumber3", 2),
    ("list number 3", 2),
    ("listnumber4", 3),
    ("list number 4", 3),
    ("listnumber5", 4),
    ("list number 5", 4),
  ]

  for entry in keys {
    let (pat, level) = entry
    if t == pat || t.contains(pat) {
      return level
    }
  }
  -1
}

///|
fn ordered_list_text_like(text : String) -> Bool {
  let t = trim_ascii_spaces(text)
  if t.length() < 2 {
    return false
  }

  let chars = t.to_array()
  let mut i = 0
  let mut digit_count = 0
  while i < chars.length() {
    let c = chars[i]
    if c >= '0' && c <= '9' {
      digit_count += 1
      i += 1
      continue
    }
    break
  }

  if digit_count == 0 || i >= chars.length() {
    return false
  }

  let marker = chars[i]
  if marker != '.' && marker != ')' {
    return false
  }

  i += 1
  if i >= chars.length() {
    return false
  }
  chars[i] == ' ' || chars[i] == '\t'
}

///|
fn read_pstyle_value(p_xml : String) -> String? {
  let chars = p_xml.to_array()

  let p1 = find_sub(chars, 0, "<w:pStyle")
  if p1 < 0 {
    return None
  }

  let p2 = find_sub(chars, p1, ">")
  if p2 < 0 {
    return None
  }

  let tag = profiled_slice_to_string(chars, p1, p2 + 1)

  match read_attr_value_in_tag(tag, "w:val") {
    Some(v) => Some(v)
    None => None
  }
}

///|
fn legacy_heading_level(v : String) -> Int {
  if v == "Heading1" || v == "2" {
    1
  } else if v == "Heading2" || v == "3" {
    2
  } else if v == "Heading3" || v == "4" {
    3
  } else if v == "Heading4" || v == "5" {
    4
  } else if v == "Heading5" || v == "6" {
    5
  } else if v == "Heading6" || v == "7" {
    6
  } else {
    0
  }
}

///|
/// v1: 仅按段落样式判断是否为引用块，尽量保守，避免误判正文
fn paragraph_is_blockquote(p_xml : String, styles : DocxStyles) -> Bool {
  match read_pstyle_value(p_xml) {
    Some(style_id) => style_is_blockquote(styles, style_id)
    None => false
  }
}

///|
/// 根据 styleId / style name 判断是否属于 quote-like 段落
fn style_is_blockquote(styles : DocxStyles, style_id : String) -> Bool {
  if quote_name_like(style_id) {
    return true
  }

  match style_name_of(styles, style_id) {
    Some(name) => quote_name_like(name)
    None => false
  }
}

///|
/// 只匹配比较明确的引用类命名；先保守一点，后面再扩
fn quote_name_like(s : String) -> Bool {
  let t = ascii_lower(trim_ascii_spaces(s))

  t == "quote" ||
  t == "blockquote" ||
  t == "block quote" ||
  t == "citation" ||
  t == "epigraph" ||
  t.contains("quote") ||
  t.contains("blockquote") ||
  t.contains("citation") ||
  t.contains("epigraph") ||
  s.contains("引文") ||
  s.contains("引用")
}

///|
fn trim_ascii_spaces(s : String) -> String {
  let cs = s.to_array()
  let mut l = 0
  let mut r = cs.length()

  while l < r {
    let c = cs[l]
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      l = l + 1
    } else {
      break
    }
  }

  while r > l {
    let c = cs[r - 1]
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      r = r - 1
    } else {
      break
    }
  }

  String::from_array(cs[l:r].to_owned())
}
