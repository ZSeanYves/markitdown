///|
/// Final PDF stage: project convert blocks/images into unified IR.
///
/// Important contract notes:
/// - text blocks and image blocks are emitted in page object reading order
/// - `Origin` / `AssetOrigin` are lightweight provenance only
/// - image nearby caption recovery is conservative; ambiguous matches are skipped
///   rather than forcing low-confidence pairings
priv enum PdfIrHeadingRole {
  DocumentTitle
  SectionHeading
  NotHeading
}

///|
const DEBUG_TO_IR = false

///|
fn rebuild_page_objects(page : PdfConvertPage) -> PdfConvertPage {
  let objects = build_page_objects(page.blocks, page.images)
  {
    _page_index: page._page_index,
    lines: page.lines,
    blocks: page.blocks,
    images: page.images,
    objects,
  }
}

///|
fn convert_pdf_blocks_to_ir(
  doc : PdfConvertDocument,
  max_heading : Int,
  source_name : String,
) -> @cor.Document {
  let out = @cor.new_document()
  let has_document_title = detect_document_title_presence_for_ir(doc)

  for page in doc.pages {
    // Caption inference is performed page-local on mixed text/image objects.
    // We keep consumed caption indices to avoid duplicating caption text as paragraph.
    let (page_image_captions, consumed_caption_block_indices) = infer_page_image_nearby_captions(
      page,
    )
    let mut page_image_idx = 0
    for i = 0; i < page.objects.length(); i = i + 1 {
      match page.objects[i] {
        PdfConvertPageObject::TextBlock(block) => {
          if consumed_caption_block_indices.contains(block.block_index) {
            continue
          }
          let prev = find_prev_text_block_in_objects(page.objects, i)
          let next = find_next_text_block_in_objects(page.objects, i)

          emit_text_block_to_ir(
            out,
            source_name,
            page._page_index,
            block,
            prev,
            next,
            has_document_title,
            max_heading,
          )
        }
        PdfConvertPageObject::Image(image) => {
          if image.path.trim() == "" {
            continue
          }
          let nearby_caption = if page_image_idx < page_image_captions.length() {
            page_image_captions[page_image_idx]
          } else {
            None
          }
          page_image_idx += 1

          let origin : @cor.Origin = {
            source_name: Some(source_name),
            page: Some(page._page_index + 1),
            slide: None,
            sheet: None,
            block_index: Some(out.blocks.val.length()),
            heading_path: None,
          }

          @cor.push_with_origin(
            out,
            @cor.Block::ImageBlock({
              path: image.path,
              alt_text: image.alt_text,
              title: None,
              caption: nearby_caption,
              origin: Some(origin),
            }),
            Some(origin),
          )

          @cor.set_asset_origin(out, image.path, {
            source_name: Some(source_name),
            page: Some(page._page_index + 1),
            slide: None,
            sheet: None,
            origin_id: Some(image.source_image_id),
            nearby_caption,
          })
        }
      }
    }
  }

  out
}

///|
fn infer_page_image_nearby_captions(
  page : PdfConvertPage,
) -> (Array[String?], Map[Int, Bool]) {
  let out : Array[String?] = []
  let consumed_block_indices : Map[Int, Bool] = Map::new()
  for _ in page.images {
    out.push(None)
  }

  if page.images.length() != 1 {
    return (out, consumed_block_indices)
  }

  let candidates : Array[(Int, String)] = []
  for block in page.blocks {
    let t = block.text.trim().to_string()
    if t == "" {
      continue
    }
    if looks_like_figure_or_table_caption_for_ir(t) {
      candidates.push((block.block_index, t))
    }
  }

  if candidates.length() == 1 {
    let (block_index, caption) = candidates[0]
    out[0] = Some(caption)
    consumed_block_indices.set(block_index, true)
  }

  (out, consumed_block_indices)
}

///|
fn find_prev_text_block_in_objects(
  objects : Array[PdfConvertPageObject],
  index : Int,
) -> PdfConvertBlock? {
  let mut i = index - 1
  while i >= 0 {
    match objects[i] {
      PdfConvertPageObject::TextBlock(block) => return Some(block)
      PdfConvertPageObject::Image(_) => ()
    }

    if i == 0 {
      break
    }
    i = i - 1
  }

  None
}

///|
fn find_next_text_block_in_objects(
  objects : Array[PdfConvertPageObject],
  index : Int,
) -> PdfConvertBlock? {
  let mut i = index + 1
  while i < objects.length() {
    match objects[i] {
      PdfConvertPageObject::TextBlock(block) => return Some(block)
      PdfConvertPageObject::Image(_) => ()
    }
    i = i + 1
  }

  None
}

///|
fn emit_text_block_to_ir(
  out : @cor.Document,
  source_name : String,
  _page_index : Int,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
  has_document_title : Bool,
  max_heading : Int,
) -> Unit {
  let text = block.text.trim().to_string()
  if text == "" {
    return
  }

  if DEBUG_TO_IR {
    println(
      "[to-ir/input] page=" +
      _page_index.to_string() +
      " block=" +
      block.block_index.to_string() +
      " kind=" +
      debug_block_kind_for_ir(block.kind) +
      " heading_candidate=" +
      block.is_heading_candidate.to_string() +
      " text=\"" +
      text +
      "\"",
    )
  }

  match block.kind {
    PdfConvertBlockKind::Noise => ()
    PdfConvertBlockKind::Heading => {
      let heading_text = normalize_heading_text_for_ir(text)
      let (role, depth) = decide_heading_role_and_depth_for_ir(
        heading_text, block, prev, next,
      )

      if DEBUG_TO_IR {
        println(
          "[to-ir/heading] page=" +
          _page_index.to_string() +
          " block=" +
          block.block_index.to_string() +
          " role=" +
          debug_heading_role_for_ir(role) +
          " depth=" +
          depth.to_string() +
          " text=\"" +
          heading_text +
          "\"",
        )
      }

      match role {
        PdfIrHeadingRole::NotHeading =>
          @cor.push_with_origin(
            out,
            @cor.Block::Paragraph(heading_text),
            Some({
              source_name: Some(source_name),
              page: Some(_page_index + 1),
              slide: None,
              sheet: None,
              block_index: Some(out.blocks.val.length()),
              heading_path: None,
            }),
          )
        PdfIrHeadingRole::DocumentTitle =>
          @cor.push_with_origin(
            out,
            @cor.Block::Heading(
              clamp_heading_level(1, max_heading),
              heading_text,
            ),
            Some({
              source_name: Some(source_name),
              page: Some(_page_index + 1),
              slide: None,
              sheet: None,
              block_index: Some(out.blocks.val.length()),
              heading_path: None,
            }),
          )
        PdfIrHeadingRole::SectionHeading => {
          let level = map_section_depth_to_heading_level_for_ir(
            depth, has_document_title, max_heading,
          )
          @cor.push_with_origin(
            out,
            @cor.Block::Heading(level, heading_text),
            Some({
              source_name: Some(source_name),
              page: Some(_page_index + 1),
              slide: None,
              sheet: None,
              block_index: Some(out.blocks.val.length()),
              heading_path: None,
            }),
          )
        }
      }
    }
    PdfConvertBlockKind::Paragraph => {
      let pt = text.trim().to_string()
      match try_parse_bullet_list_item_for_ir(pt) {
        Some(item_text) =>
          @cor.push_with_origin(
            out,
            @cor.Block::ListItem(false, 0, item_text),
            Some({
              source_name: Some(source_name),
              page: Some(_page_index + 1),
              slide: None,
              sheet: None,
              block_index: Some(out.blocks.val.length()),
              heading_path: None,
            }),
          )
        None =>
          @cor.push_with_origin(
            out,
            @cor.Block::Paragraph(pt),
            Some({
              source_name: Some(source_name),
              page: Some(_page_index + 1),
              slide: None,
              sheet: None,
              block_index: Some(out.blocks.val.length()),
              heading_path: None,
            }),
          )
      }
    }
  }
}

///|
fn try_parse_bullet_list_item_for_ir(text : String) -> String? {
  let t = text.trim().to_string()
  if t == "" {
    return None
  }

  if t.has_prefix("•") {
    let body = t[1:].trim().to_string()
    if body != "" {
      return Some(body)
    }
  }

  if t.has_prefix("- ") || t.has_prefix("* ") {
    let body = t[2:].trim().to_string()
    if body != "" {
      return Some(body)
    }
  }

  None
}

///|
fn debug_block_kind_for_ir(kind : PdfConvertBlockKind) -> String {
  match kind {
    PdfConvertBlockKind::Heading => "Heading"
    PdfConvertBlockKind::Paragraph => "Paragraph"
    PdfConvertBlockKind::Noise => "Noise"
  }
}

///|
fn debug_heading_role_for_ir(role : PdfIrHeadingRole) -> String {
  match role {
    PdfIrHeadingRole::DocumentTitle => "DocumentTitle"
    PdfIrHeadingRole::SectionHeading => "SectionHeading"
    PdfIrHeadingRole::NotHeading => "NotHeading"
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

    let t = block.text.trim().to_string()
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
    _ => (role, 0)
  }
}

///|
fn classify_heading_role_for_ir(
  text : String,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
) -> PdfIrHeadingRole {
  let t = text.trim().to_string()
  if t == "" {
    return PdfIrHeadingRole::NotHeading
  }
  if split_non_empty_words_for_ir(t).length() <= 1 &&
    t.to_array().length() <= 3 &&
    !block.is_heading_candidate {
    return PdfIrHeadingRole::NotHeading
  }

  if looks_like_document_title_role_for_ir(t, block, prev, next) {
    return PdfIrHeadingRole::DocumentTitle
  }

  // 上游已经判成 heading 的块，先保住。
  // 这里只保留少数特别硬的黑名单。
  if block.is_heading_candidate || block.kind == PdfConvertBlockKind::Heading {
    if looks_like_figure_or_table_caption_for_ir(t) ||
      looks_like_side_marker_label_line_for_ir(t) ||
      looks_like_list_item_sentence_for_ir(t) ||
      looks_like_list_intro_line_for_ir(t) ||
      looks_like_intro_phrase_for_ir(t) {
      return PdfIrHeadingRole::NotHeading
    }
    return PdfIrHeadingRole::SectionHeading
  }

  if looks_like_heading_negative_for_ir(t) {
    return PdfIrHeadingRole::NotHeading
  }

  if looks_like_section_heading_role_for_ir(t, block, prev, next) {
    return PdfIrHeadingRole::SectionHeading
  }

  PdfIrHeadingRole::NotHeading
}

///|
/// 文档主标题：非常保守。
///
/// 关键思想：
/// - 不能是常见正文节标题
/// - 不能是显式编号 section
/// - 必须在首页前部
/// - 要么像 sample/report/test 这类文档标题
/// - 要么是明显的英文/中英混合/压缩命题型主标题
fn looks_like_document_title_role_for_ir(
  text : String,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  // 常见 section label 不当文档标题
  if looks_like_common_section_label_for_ir(t) {
    return false
  }

  // 显式 section depth 一律视为正文结构，不是 document title
  if infer_section_depth_for_ir(t) > 0 {
    return false
  }

  // 必须在首页前部
  if block._page_index != 0 || block.block_index > 2 {
    return false
  }

  if block.line_count > 2 {
    return false
  }

  if !looks_like_strong_document_title_for_ir(t) {
    return false
  }

  // 文档标题有两种典型来源：
  // 1) 词表型：report/pipeline/test/sample 等
  // 2) 压缩标题短语：Cross-page should merge / Heading vs Short Sentence
  // 3) 中英混合项目标题
  let title_shape = looks_like_document_title_phrase_for_ir(t) ||
    looks_like_mixed_document_title_for_ir(t) ||
    looks_like_compact_predicative_title_for_ir(t)

  // 版面/上下文辅助：更大字号 or 后续像正文
  let layout_support = is_visually_larger_than_neighbors(prev, block, next) ||
    next_block_looks_like_body_for_h1(next)

  title_shape || layout_support
}

///|
/// 正文节标题：
/// - 显式编号优先
/// - 常见 section label
/// - section-like 形态
/// - 短而独立的 heading，也可视作 section
fn looks_like_section_heading_role_for_ir(
  text : String,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  _next : PdfConvertBlock?,
) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if infer_section_depth_for_ir(t) > 0 {
    return true
  }

  if looks_like_common_section_label_for_ir(t) {
    return true
  }
  if looks_like_page_prefixed_section_heading_for_ir(t) {
    return true
  }

  if has_short_heading_layout_signal_for_ir(t, block, prev) {
    return true
  }

  if looks_like_section_title_for_ir(t) {
    // 避免把明显文档主标题也吞进 section
    if looks_like_document_title_phrase_for_ir(t) ||
      looks_like_mixed_document_title_for_ir(t) ||
      looks_like_compact_predicative_title_for_ir(t) {
      return false
    }

    return true
  }

  false
}

///|
/// heading 黑名单。
fn looks_like_heading_negative_for_ir(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return true
  }

  looks_like_list_item_sentence_for_ir(t) ||
  looks_like_intro_phrase_for_ir(t) ||
  looks_like_list_intro_line_for_ir(t) ||
  looks_like_figure_or_table_caption_for_ir(t) ||
  looks_like_side_marker_label_line_for_ir(t) ||
  is_probable_page_number_for_ir(t) ||
  looks_like_complete_statement_for_ir(t)
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
  let t = text.trim().to_string()
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
fn looks_like_page_prefixed_section_heading_for_ir(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  let words = split_non_empty_words_for_ir(t)
  if words.length() < 4 || words.length() > 6 {
    return false
  }

  if ascii_lower_for_ir(words[0]) != "page" {
    return false
  }

  if !all_ascii_digits_for_ir(words[1]) {
    return false
  }

  // 至少还要有两个正文词，避免把 Page 2 当页码标签
  true
}

///|
fn all_ascii_digits_for_ir(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  for c in t.to_array() {
    if c < '0' || c > '9' {
      return false
    }
  }

  true
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
  let t = text.trim().to_string()

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
fn starts_with_numbered_heading_for_ir(s : String) -> Bool {
  let t = s.trim().to_string()
  let cs = t.to_array()
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
    if c == '.' {
      i += 1
      continue
    }
    break
  }

  if !has_digit || i >= n {
    return false
  }

  let c = cs[i]
  if c == ' ' || c == '、' || c == ')' || c == '）' {
    return true
  }

  c == '.' && i + 1 < n && cs[i + 1] == ' '
}

///|
fn looks_like_heading_marker_for_ir(s : String) -> Bool {
  let t = s.trim().to_string()
  t.has_prefix("第") ||
  t.has_prefix("Chapter") ||
  t.has_prefix("CHAPTER") ||
  t.has_prefix("Section") ||
  t.has_prefix("SECTION") ||
  t.has_prefix("一、") ||
  t.has_prefix("二、") ||
  t.has_prefix("三、") ||
  t.has_prefix("四、") ||
  t.has_prefix("五、") ||
  t.has_prefix("（一）") ||
  t.has_prefix("（二）") ||
  t.has_prefix("（三）") ||
  starts_with_numbered_heading_for_ir(t)
}

///|
/// 英文标题形态。
fn looks_like_english_title_for_ir(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) {
    return false
  }

  if looks_like_figure_or_table_caption_for_ir(t) {
    return false
  }

  if looks_like_intro_phrase_for_ir(t) {
    return false
  }

  if looks_like_list_intro_line_for_ir(t) {
    return false
  }

  let words : Array[String] = []
  for sv in t.split(" ") {
    let w = sv.to_string().trim().to_string()
    if w != "" {
      words.push(w)
    }
  }

  if words.length() == 0 || words.length() > 8 {
    return false
  }

  let mut latin_words = 0
  let mut good_caps = 0

  for w in words {
    if starts_with_latin_for_ir(w) {
      latin_words += 1
      match first_char_for_ir(w) {
        Some(c) => if c >= 'A' && c <= 'Z' { good_caps += 1 }
        None => ()
      }
    }
  }

  if words.length() == 1 {
    return latin_words == 1 && good_caps == 1
  }

  latin_words >= 2 && good_caps >= 2
}

///|
/// 更像“压缩命题标题短语”。
/// 例如：
/// - Cross-page should merge
/// - Cross-page should NOT merge
/// - Heading vs Short Sentence
fn looks_like_compact_predicative_title_for_ir(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) ||
    looks_like_figure_or_table_caption_for_ir(t) ||
    looks_like_intro_phrase_for_ir(t) ||
    looks_like_list_intro_line_for_ir(t) ||
    looks_like_list_item_sentence_for_ir(t) ||
    is_probable_page_number_for_ir(t) ||
    looks_like_side_marker_label_line_for_ir(t) {
    return false
  }

  let words = split_non_empty_words_for_ir(t)
  if words.length() < 2 || words.length() > 6 {
    return false
  }

  let first = ascii_lower_for_ir(strip_edge_punct_for_ir(words[0]))
  if first == "this" || first == "the" || first == "a" || first == "an" {
    return false
  }

  let mut has_vs = false
  let mut has_modal = false
  let mut has_latin = false

  for w in words {
    let lw = ascii_lower_for_ir(strip_edge_punct_for_ir(w))
    if lw == "vs" {
      has_vs = true
    }
    if lw == "should" ||
      lw == "must" ||
      lw == "can" ||
      lw == "will" ||
      lw == "may" {
      has_modal = true
    }
    if starts_with_latin_for_ir(w) {
      has_latin = true
    }
  }

  if !has_latin {
    return false
  }

  if has_vs {
    return true
  }

  if has_modal &&
    words.length() <= 5 &&
    !looks_like_complete_statement_for_ir(t) {
    return true
  }

  false
}

///|
/// 更像完整正文句，而不是标题。
fn looks_like_complete_statement_for_ir(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) {
    return true
  }

  if looks_like_figure_or_table_caption_for_ir(t) ||
    looks_like_intro_phrase_for_ir(t) ||
    looks_like_list_intro_line_for_ir(t) ||
    looks_like_list_item_sentence_for_ir(t) {
    return false
  }

  let words = split_non_empty_words_for_ir(t)
  if words.length() <= 3 {
    return false
  }

  let mut stop_hits = 0
  let mut verb_hits = 0
  let mut clause_hits = 0

  for w in words {
    let lw = ascii_lower_for_ir(strip_edge_punct_for_ir(w))
    if lw == "" {
      continue
    }

    if is_statement_stopword_for_ir(lw) {
      stop_hits += 1
    }
    if is_statement_verb_for_ir(lw) {
      verb_hits += 1
    }
    if is_statement_clause_marker_for_ir(lw) {
      clause_hits += 1
    }
  }

  if words.length() >= 8 && (stop_hits >= 2 || verb_hits >= 1) {
    return true
  }

  if clause_hits >= 1 && words.length() >= 6 {
    return true
  }

  let first = ascii_lower_for_ir(strip_edge_punct_for_ir(words[0]))
  if (first == "this" || first == "the" || first == "a" || first == "an") &&
    words.length() >= 5 &&
    verb_hits >= 1 {
    return true
  }

  false
}

///|
/// section-like 标题形态。
fn looks_like_section_title_for_ir(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) {
    return false
  }

  if looks_like_complete_statement_for_ir(t) {
    return false
  }

  if looks_like_figure_or_table_caption_for_ir(t) {
    return false
  }

  if looks_like_intro_phrase_for_ir(t) {
    return false
  }

  if looks_like_list_intro_line_for_ir(t) {
    return false
  }

  if looks_like_list_item_sentence_for_ir(t) {
    return false
  }

  if looks_like_side_marker_label_line_for_ir(t) {
    return false
  }

  if is_probable_page_number_for_ir(t) {
    return false
  }

  looks_like_english_title_for_ir(t) ||
  looks_like_compact_cjk_heading_for_ir(t) ||
  looks_like_heading_marker_for_ir(t)
}

///|
fn looks_like_compact_cjk_heading_for_ir(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) {
    return false
  }

  if contains_sentence_punct_inside_for_ir(t) {
    return false
  }

  if looks_like_list_item_sentence_for_ir(t) {
    return false
  }

  if looks_like_figure_or_table_caption_for_ir(t) {
    return false
  }

  if looks_like_list_intro_line_for_ir(t) {
    return false
  }

  if starts_with_latin_for_ir(t) {
    return false
  }

  let n = t.to_array().length()
  if n < 2 || n > 12 {
    return false
  }

  if t.contains(" ") {
    return false
  }

  for c in t.to_array() {
    if !is_cjkish_for_ir(c) {
      return false
    }
  }

  true
}

///|
fn looks_like_strong_document_title_for_ir(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if is_probable_page_number_for_ir(t) ||
    looks_like_side_marker_label_line_for_ir(t) ||
    ends_like_sentence_for_heading(t) ||
    looks_like_list_item_sentence_for_ir(t) ||
    looks_like_figure_or_table_caption_for_ir(t) ||
    looks_like_intro_phrase_for_ir(t) ||
    looks_like_list_intro_line_for_ir(t) {
    return false
  }

  // 文档主标题不接受显式 section 编号。
  if infer_section_depth_for_ir(t) > 0 {
    return false
  }

  let n = t.to_array().length()
  if n < 4 || n > 80 {
    return false
  }

  looks_like_english_title_for_ir(t) ||
  looks_like_compact_cjk_heading_for_ir(t) ||
  looks_like_mixed_document_title_for_ir(t) ||
  looks_like_compact_predicative_title_for_ir(t)
}

///|
fn looks_like_mixed_document_title_for_ir(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) ||
    looks_like_list_item_sentence_for_ir(t) ||
    looks_like_figure_or_table_caption_for_ir(t) ||
    looks_like_intro_phrase_for_ir(t) ||
    looks_like_list_intro_line_for_ir(t) {
    return false
  }

  let n = t.to_array().length()
  if n < 6 || n > 50 {
    return false
  }

  let words : Array[String] = []
  for sv in t.split(" ") {
    let w = sv.to_string().trim().to_string()
    if w != "" {
      words.push(w)
    }
  }

  if words.length() < 2 || words.length() > 10 {
    return false
  }

  let mut has_latin = false
  let mut has_non_latin = false
  let mut good_caps = 0
  for w in words {
    if starts_with_latin_for_ir(w) {
      has_latin = true
      match first_char_for_ir(w) {
        Some(c) => if c >= 'A' && c <= 'Z' { good_caps += 1 }
        None => ()
      }
    } else {
      has_non_latin = true
    }
  }

  has_latin && has_non_latin && good_caps >= 1
}

///|
fn looks_like_document_title_phrase_for_ir(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if looks_like_common_section_label_for_ir(t) {
    return false
  }

  let words = split_non_empty_words_for_ir(t)
  if words.length() < 2 || words.length() > 10 {
    return false
  }

  let lt = ascii_lower_for_ir(t)
  lt.contains("report") ||
  lt.contains("pipeline") ||
  lt.contains("test") ||
  lt.contains("sample") ||
  lt.contains("mvp") ||
  lt.contains("markitdown") ||
  lt.contains("moonbit")
}

///|
/// 常见 section 标题词表。
fn looks_like_common_section_label_for_ir(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  let lt = ascii_lower_for_ir(t)
  if lt == "introduction" ||
    lt == "method" ||
    lt == "methods" ||
    lt == "background" ||
    lt == "summary" ||
    lt == "details" ||
    lt == "conclusion" ||
    lt == "next section" ||
    lt == "related work" ||
    lt == "discussion" ||
    lt == "results" {
    return true
  }

  if t == "技术路线" ||
    t == "研究内容" ||
    t == "研究方法" ||
    t == "研究目标" ||
    t == "研究背景" ||
    t == "项目概述" ||
    t == "总结" ||
    t == "结论" ||
    t == "下一节" {
    return true
  }

  false
}

///|
/// 后继 block 像正文：有助于文档主标题判定。
fn next_block_looks_like_body_for_h1(next : PdfConvertBlock?) -> Bool {
  match next {
    None => false
    Some(b) => {
      let t = b.text.trim().to_string()
      if t == "" {
        return false
      }

      b.kind == PdfConvertBlockKind::Paragraph ||
      ends_like_sentence_for_heading(t) ||
      looks_like_list_item_sentence_for_ir(t)
    }
  }
}

///|
/// 很短、独立、像标题形态的块，可视作 section heading 正向信号。
fn has_short_heading_layout_signal_for_ir(
  text : String,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if looks_like_complete_statement_for_ir(t) ||
    looks_like_list_item_sentence_for_ir(t) ||
    looks_like_intro_phrase_for_ir(t) ||
    looks_like_list_intro_line_for_ir(t) ||
    looks_like_figure_or_table_caption_for_ir(t) ||
    looks_like_side_marker_label_line_for_ir(t) ||
    is_probable_page_number_for_ir(t) {
    return false
  }

  if !looks_like_short_heading_text_for_ir(t) {
    return false
  }

  let mut score = 0

  if block.line_count <= 2 {
    score += 1
  }

  if block.is_heading_candidate {
    score += 1
  }

  match prev {
    None => score += 2
    Some(p) => if p.kind != PdfConvertBlockKind::Paragraph { score += 1 }
  }

  score >= 3
}

///|
fn looks_like_short_heading_text_for_ir(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if looks_like_compact_cjk_heading_for_ir(t) {
    return true
  }

  let words = split_non_empty_words_for_ir(t)
  if words.length() >= 1 && words.length() <= 5 {
    if looks_like_english_title_for_ir(t) ||
      looks_like_compact_predicative_title_for_ir(t) {
      return true
    }
  }

  false
}

///|
fn split_non_empty_words_for_ir(text : String) -> Array[String] {
  let out : Array[String] = []
  for sv in text.split(" ") {
    let w = sv.to_string().trim().to_string()
    if w != "" {
      out.push(w)
    }
  }
  out
}

///|
fn ascii_lower_for_ir(text : String) -> String {
  let mut out = ""
  for c in text.to_array() {
    if c >= 'A' && c <= 'Z' {
      let d = c.to_int() - 'A'.to_int() + 'a'.to_int()
      out = out + Int::unsafe_to_char(d).to_string()
    } else {
      out = out + c.to_string()
    }
  }
  out
}

///|
fn strip_edge_punct_for_ir(text : String) -> String {
  let cs = text.to_array()
  if cs.length() == 0 {
    return text
  }

  let mut start = 0
  let mut end_ = cs.length()

  while start < end_ && is_simple_edge_punct_for_ir(cs[start]) {
    start += 1
  }

  while end_ > start && is_simple_edge_punct_for_ir(cs[end_ - 1]) {
    end_ -= 1
  }

  let mut out = ""
  let mut i = start
  while i < end_ {
    out = out + cs[i].to_string()
    i += 1
  }
  out
}

///|
fn is_simple_edge_punct_for_ir(c : Char) -> Bool {
  c == '"' ||
  c == '\'' ||
  c == '(' ||
  c == ')' ||
  c == '[' ||
  c == ']' ||
  c == '{' ||
  c == '}' ||
  c == ',' ||
  c == '.' ||
  c == ':' ||
  c == ';' ||
  c == '!' ||
  c == '?' ||
  c == '“' ||
  c == '”' ||
  c == '‘' ||
  c == '’' ||
  c == '（' ||
  c == '）'
}

///|
fn is_statement_stopword_for_ir(word : String) -> Bool {
  word == "this" ||
  word == "the" ||
  word == "a" ||
  word == "an" ||
  word == "that" ||
  word == "these" ||
  word == "those" ||
  word == "it" ||
  word == "its" ||
  word == "their" ||
  word == "his" ||
  word == "her"
}

///|
fn is_statement_verb_for_ir(word : String) -> Bool {
  word == "is" ||
  word == "are" ||
  word == "was" ||
  word == "were" ||
  word == "be" ||
  word == "been" ||
  word == "being" ||
  word == "has" ||
  word == "have" ||
  word == "had" ||
  word == "does" ||
  word == "do" ||
  word == "did"
}

///|
fn is_statement_clause_marker_for_ir(word : String) -> Bool {
  word == "because" ||
  word == "which" ||
  word == "when" ||
  word == "where" ||
  word == "while" ||
  word == "although" ||
  word == "though" ||
  word == "since" ||
  word == "if"
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
fn ends_like_sentence_for_heading(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？") ||
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("；") ||
  t.has_suffix(";") ||
  t.has_suffix("：") ||
  t.has_suffix(":")
}

///|
fn looks_like_list_item_sentence_for_ir(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if t.has_prefix("- ") || t.has_prefix("* ") || t.has_prefix("• ") {
    return true
  }

  let cs = t.to_array()
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

  if has_digit && i + 1 < n {
    let c = cs[i]
    if (c == '.' || c == '、' || c == ')' || c == '）') && cs[i + 1] == ' ' {
      return true
    }
  }

  false
}

///|
fn looks_like_figure_or_table_caption_for_ir(text : String) -> Bool {
  @text.looks_like_figure_or_table_caption(text)
}

///|
fn looks_like_intro_phrase_for_ir(text : String) -> Bool {
  @text.looks_like_intro_phrase(text)
}

///|
fn looks_like_list_intro_line_for_ir(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if !t.has_suffix(":") && !t.has_suffix("：") {
    return false
  }

  t.to_array().length() <= 30
}

///|
fn looks_like_side_marker_label_line_for_ir(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" || !t.contains(" ") || !t.contains("-") {
    return false
  }

  let mut first = ""
  for sv in t.split(" ") {
    let w = sv.to_string().trim().to_string()
    if w != "" {
      first = w
      break
    }
  }
  if first == "" {
    return false
  }

  if first.has_prefix("LEFT-") || first.has_prefix("RIGHT-") {
    return true
  }

  let mut has_upper = false
  for c in first.to_array() {
    let ok = (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-'
    if !ok {
      return false
    }
    if c >= 'A' && c <= 'Z' {
      has_upper = true
    }
  }

  has_upper && first.contains("-")
}

///|
fn is_probable_page_number_for_ir(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if is_probable_page_number_like(t) {
    return true
  }

  t.contains("第") && t.contains("页")
}

///|
fn starts_with_latin_for_ir(s : String) -> Bool {
  match first_char_for_ir(s) {
    Some(c) => (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
    None => false
  }
}

///|
fn first_char_for_ir(s : String) -> Char? {
  let cs = s.to_array()
  if cs.length() == 0 {
    return None
  }
  Some(cs[0])
}

///|
fn contains_sentence_punct_inside_for_ir(s : String) -> Bool {
  let cs = s.to_array()
  let n = cs.length()
  if n <= 2 {
    return false
  }

  let mut i = 1
  while i + 1 < n {
    let c = cs[i]
    if c == '。' ||
      c == '！' ||
      c == '？' ||
      c == '.' ||
      c == '!' ||
      c == '?' ||
      c == '；' ||
      c == ';' ||
      c == '：' ||
      c == ':' {
      return true
    }
    i = i + 1
  }

  false
}

///|
fn is_cjkish_for_ir(c : Char) -> Bool {
  is_cjk_char(c) || c == '（' || c == '）' || c == '《' || c == '》'
}

///|
/// heading 输出前做最小规范化：
/// - 当前只修中文章节标题里的缺失空格
fn normalize_heading_text_for_ir(text : String) -> String {
  let t = text.trim().to_string()
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

///|
/// 常见 CJK 统一表意文字范围 + 扩展 A + 兼容表意文字。
fn is_cjk_char(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn is_digit_char(ch : Char) -> Bool {
  let code = ch.to_int()
  code >= 0x30 && code <= 0x39
}
