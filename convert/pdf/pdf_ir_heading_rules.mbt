///|
/// Final PDF IR heading role, depth, and normalization rules.
///
/// These helpers stay package-local because they depend on convert-layer block
/// classification while guarding the final unified IR emission.
fn debug_heading_role_for_ir(role : PdfIrHeadingRole) -> String {
  match role {
    PdfIrHeadingRole::DocumentTitle => "DocumentTitle"
    PdfIrHeadingRole::SectionHeading => "SectionHeading"
  }
}

///|
/// 是否存在“文档主标题”。
///
/// 这里必须非常保守：
/// - 只看首页前部
/// - 只看 heading block
/// - 不能是显式 section marker / 常见 section label
/// - 必须真的更像 sample/report/title，而不是正文小节
fn detect_document_title_presence_for_ir(doc : PdfConvertDocument) -> Bool {
  if doc.pages.length() == 0 {
    return false
  }

  let page = doc.pages[0]
  for i = 0; i < page.blocks.length(); i = i + 1 {
    let block = page.blocks[i]

    if block.kind != PdfConvertBlockKind::Heading {
      continue
    }

    if block.block_index > 2 {
      break
    }

    let t = block.text.trim().to_owned()
    if t == "" || should_never_emit_heading(t) {
      continue
    }

    let prev = if i > 0 { Some(page.blocks[i - 1]) } else { None }
    let next = if i + 1 < page.blocks.length() {
      Some(page.blocks[i + 1])
    } else {
      None
    }

    if looks_like_document_title_role_for_ir(t, block, prev, next) {
      return true
    }
  }

  false
}

///|
fn decide_heading_role_and_depth_for_ir(
  text : String,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
) -> (PdfIrHeadingRole, Int) {
  let role = classify_heading_role_for_ir(text, block, prev, next)
  match role {
    PdfIrHeadingRole::SectionHeading => {
      let depth = infer_section_depth_for_ir(text)
      (role, if depth > 0 { depth } else { 1 })
    }
    PdfIrHeadingRole::DocumentTitle => (role, 0)
  }
}

///|
fn classify_heading_role_for_ir(
  text : String,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
) -> PdfIrHeadingRole {
  let t = text.trim().to_owned()
  if looks_like_document_title_role_for_ir(t, block, prev, next) {
    return PdfIrHeadingRole::DocumentTitle
  }

  // `pdf_classify` is the final "is this a heading?" boundary. At this
  // stage we only decide whether an already-classified Heading is the document
  // title or a section heading.
  PdfIrHeadingRole::SectionHeading
}

///|
/// 结构深度：先算相对深度，不直接映射 H1/H2/H3。
///
/// depth=1:
/// - 第一章 / Chapter / 一、 / 1.
/// depth=2:
/// - 第一节 / 1.1 / （一）
/// depth=3:
/// - 1.1.1 / （1） / 1)
fn infer_section_depth_for_ir(text : String) -> Int {
  let t = text.trim().to_owned()
  if t == "" {
    return 0
  }

  // 章级
  if t.has_prefix("第一章") ||
    t.has_prefix("第二章") ||
    t.has_prefix("第三章") ||
    t.has_prefix("第四章") ||
    t.has_prefix("第五章") ||
    t.has_prefix("Chapter ") ||
    t.has_prefix("CHAPTER ") ||
    t.has_prefix("一、") ||
    t.has_prefix("二、") ||
    t.has_prefix("三、") ||
    t.has_prefix("四、") ||
    t.has_prefix("五、") {
    return 1
  }

  // 节级（中文“第一节”）
  if t.has_prefix("第一节") ||
    t.has_prefix("第二节") ||
    t.has_prefix("第三节") ||
    t.has_prefix("第四节") ||
    t.has_prefix("第五节") {
    return 2
  }

  let dots = count_prefix_dots_in_heading_number_for_ir(t)
  if dots >= 2 {
    return 3
  }
  if dots == 1 {
    return 2
  }

  if starts_with_top_level_number_for_ir(t) {
    return 1
  }

  if t.has_prefix("（一）") ||
    t.has_prefix("（二）") ||
    t.has_prefix("（三）") ||
    t.has_prefix("（四）") ||
    t.has_prefix("（五）") {
    return 2
  }

  if starts_with_parenthesized_digit_item_for_ir(t) ||
    starts_with_digit_paren_item_for_ir(t) {
    return 3
  }

  0
}

///|
fn starts_with_parenthesized_digit_item_for_ir(text : String) -> Bool {
  let cs = text.to_array()
  if cs.length() < 3 {
    return false
  }

  cs[0] == '（' && cs[1] >= '0' && cs[1] <= '9' && cs[2] == '）'
}

///|
fn starts_with_digit_paren_item_for_ir(text : String) -> Bool {
  let cs = text.to_array()
  if cs.length() < 2 {
    return false
  }

  cs[0] >= '0' && cs[0] <= '9' && (cs[1] == ')' || cs[1] == '）')
}

///|
fn map_section_depth_to_heading_level_for_ir(
  depth : Int,
  has_document_title : Bool,
  max_heading : Int,
) -> Int {
  let base_section_level = if has_document_title { 2 } else { 1 }
  let safe_depth = if depth <= 0 { 1 } else { depth }
  clamp_heading_level(base_section_level + safe_depth - 1, max_heading)
}

///|
/// 即使上游标了 Heading，这些也不应在 IR 层发成 heading。
fn should_never_emit_heading(text : String) -> Bool {
  let t = text.trim().to_owned()

  if t == "" {
    return true
  }

  if looks_like_colon_label(t) {
    return true
  }

  if @text.looks_like_intro_phrase(t) {
    return true
  }

  if @text.looks_like_figure_or_table_caption(t) {
    return true
  }

  if looks_like_bullet_item(t) {
    return true
  }

  if looks_like_numbered_body_sentence(t) {
    return true
  }

  false
}

///|
fn count_prefix_dots_in_heading_number_for_ir(s : String) -> Int {
  let cs = s.to_array()
  let n = cs.length()
  let mut i = 0
  let mut saw_digit = false
  let mut dots = 0

  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      saw_digit = true
      i += 1
      continue
    }
    if c == '.' {
      dots += 1
      i += 1
      continue
    }
    break
  }

  if saw_digit {
    dots
  } else {
    0
  }
}

///|
fn starts_with_top_level_number_for_ir(s : String) -> Bool {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return false
  }

  let mut i = 0
  let mut has_digit = false
  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    break
  }

  if !has_digit || i >= n {
    return false
  }

  let c = cs[i]
  c == ' ' || c == '、' || c == ')' || c == '）' || c == '.'
}

///|
fn clamp_heading_level(level : Int, max_heading : Int) -> Int {
  if max_heading <= 0 {
    return 1
  }
  if level < 1 {
    return 1
  }
  if level > max_heading {
    return max_heading
  }
  level
}

///|
/// heading 输出前做最小规范化：
/// - 当前只修中文章节标题里的缺失空格
fn normalize_heading_text_for_ir(text : String) -> String {
  let t = text.trim().to_owned()
  if t == "" {
    return t
  }

  normalize_cjk_chapter_heading_spacing(t)
}

///|
/// 在“章 / 节”后面补一个空格：
/// - 第一章项目概述 -> 第一章 项目概述
/// - 第二章技术路线 -> 第二章 技术路线
/// - 第三节方法 -> 第三节 方法
fn normalize_cjk_chapter_heading_spacing(text : String) -> String {
  let arr = text.to_array()
  if arr.is_empty() {
    return text
  }

  let mut out = ""
  let mut i = 0

  while i < arr.length() {
    let ch = arr[i]
    out = out + ch.to_string()

    if should_insert_space_after_cjk_heading_marker(arr, i) {
      out = out + " "
    }

    i = i + 1
  }

  out
}

///|
fn should_insert_space_after_cjk_heading_marker(
  arr : Array[Char],
  index : Int,
) -> Bool {
  let ch = arr[index]

  if ch != '章' && ch != '节' {
    return false
  }

  if index + 1 >= arr.length() {
    return false
  }

  let next = arr[index + 1]

  if next == ' ' {
    return false
  }

  is_cjk_char(next)
}
