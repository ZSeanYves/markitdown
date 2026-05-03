///|
priv enum PdfNoiseDecisionStatus {
  Drop
  Keep
}

///|
priv struct PdfRepeatedEdgeNoiseIndex {
  repeated_heads : Array[String]
  repeated_tails : Array[String]
  repeated_head_prefixes : Array[String]
  repeated_tail_prefixes : Array[String]
}

///|
priv struct PdfEdgeNoiseEvidence {
  empty_text : Bool
  isolated_line : Bool
  top_edge : Bool
  bottom_edge : Bool
  near_page_margin : Bool
  outside_body_band : Bool
  small_height : Bool
  short_text : Bool
  repeated_across_pages : Bool
  same_text_same_edge : Bool
  same_prefix_same_edge : Bool
  page_count_pattern : Bool
  page_number_numeric : Bool
  page_number_roman : Bool
  page_number_with_label : Bool
  page_number_short_centered : Bool
  page_number_edge : Bool
  heading_like_but_repeated_edge : Bool
  link_or_annotation_nearby : Bool
  image_caption_guard : Bool
  body_like_guard : Bool
  long_sentence_guard : Bool
  two_column_guard : Bool
  core_page_number_candidate : Bool
  core_header_footer_candidate : Bool
  core_artifact_candidate : Bool
}

///|
priv struct PdfNoiseDecision {
  status : PdfNoiseDecisionStatus
  reason_tags : Array[String]
}

///|
fn build_repeated_edge_noise_index(
  doc : PdfConvertDocument,
) -> PdfRepeatedEdgeNoiseIndex {
  let head_count = Map::new()
  let tail_count = Map::new()
  let head_prefix_count = Map::new()
  let tail_prefix_count = Map::new()

  for page in doc.pages {
    let blocks = normalized_nonempty_blocks(page)
    let n = blocks.length()
    if n == 0 {
      continue
    }

    let head = blocks[0]
    let head_key = normalize_noise_key(head.text)
    if head_key != "" && is_repeated_noise_candidate_block(head) {
      let old = head_count.get(head_key) |> Option::unwrap_or(0)
      head_count.set(head_key, old + 1)

      let prefix = normalize_noise_prefix_key(head.text)
      if prefix != "" {
        let old_prefix = head_prefix_count.get(prefix) |> Option::unwrap_or(0)
        head_prefix_count.set(prefix, old_prefix + 1)
      }
    }

    let tail = blocks[n - 1]
    let tail_key = normalize_noise_key(tail.text)
    if tail_key != "" && is_repeated_noise_candidate_block(tail) {
      let old = tail_count.get(tail_key) |> Option::unwrap_or(0)
      tail_count.set(tail_key, old + 1)

      let prefix = normalize_noise_prefix_key(tail.text)
      if prefix != "" {
        let old_prefix = tail_prefix_count.get(prefix) |> Option::unwrap_or(0)
        tail_prefix_count.set(prefix, old_prefix + 1)
      }
    }
  }

  let page_n = doc.pages.length()
  let threshold = if page_n <= 2 { 2 } else { (page_n + 1) / 2 }

  {
    repeated_heads: collect_repeated_noise_keys(head_count, threshold),
    repeated_tails: collect_repeated_noise_keys(tail_count, threshold),
    repeated_head_prefixes: collect_repeated_noise_keys(
      head_prefix_count, threshold,
    ),
    repeated_tail_prefixes: collect_repeated_noise_keys(
      tail_prefix_count, threshold,
    ),
  }
}

///|
fn collect_repeated_noise_keys(
  counts : Map[String, Int],
  threshold : Int,
) -> Array[String] {
  let out : Array[String] = []

  for entry in counts {
    let (k, v) = entry
    if v >= threshold && k.length() <= 80 {
      out.push(k)
    }
  }

  out
}

///|
fn collect_edge_noise_evidence(
  page : PdfConvertPage,
  block_index : Int,
  block : PdfConvertBlock,
  repeated : PdfRepeatedEdgeNoiseIndex,
) -> PdfEdgeNoiseEvidence {
  let text = block.text.trim().to_owned()
  let key = normalize_noise_key(text)
  let prefix = normalize_noise_prefix_key(text)
  let first_idx = first_nonempty_block_index(page)
  let last_idx = last_nonempty_block_index(page)
  let top_edge = is_top_edge_block(page, block)
  let bottom_edge = is_bottom_edge_block(page, block)
  let near_page_margin = is_near_page_margin(page, block)
  let outside_body_band = is_outside_body_band(page, block)
  let page_number_numeric = is_numeric_page_number_like(text)
  let page_number_roman = is_roman_page_number_like(text)
  let page_number_with_label = looks_like_simple_english_page_label(text) ||
    looks_like_simple_cjk_page_label(text)
  let page_count_pattern = looks_like_fraction_page_label(text) ||
    looks_like_dash_page_label(text)
  let page_number_like = page_number_numeric ||
    page_number_roman ||
    page_number_with_label ||
    page_count_pattern
  let repeated_head = first_idx >= 0 &&
    block_index == first_idx &&
    contains_string(repeated.repeated_heads, key)
  let repeated_tail = last_idx >= 0 &&
    block_index == last_idx &&
    contains_string(repeated.repeated_tails, key)
  let repeated_head_prefix = first_idx >= 0 &&
    block_index == first_idx &&
    prefix != "" &&
    contains_string(repeated.repeated_head_prefixes, prefix)
  let repeated_tail_prefix = last_idx >= 0 &&
    block_index == last_idx &&
    prefix != "" &&
    contains_string(repeated.repeated_tail_prefixes, prefix)
  let repeated_across_pages = repeated_head || repeated_tail
  let same_prefix_same_edge = repeated_head_prefix || repeated_tail_prefix
  let long_sentence_guard = ends_like_sentence(text) && count_words(text) >= 5
  let body_like_guard = long_sentence_guard ||
    count_words(text) >= 8 ||
    text.length() > 60 ||
    block.line_count >= 2
  let image_caption_guard = block.is_caption_candidate ||
    is_image_caption_guard(page, block)
  let two_column_guard = looks_like_two_column_edge_block(page, block, text)
  let heading_like_but_repeated_edge = repeated_across_pages &&
    (
      block.kind == PdfConvertBlockKind::Heading ||
      block.is_heading_candidate ||
      source_block_kind_is_heading_candidate(block.source_block_kind)
    )

  {
    empty_text: text == "",
    isolated_line: block.line_count == 1,
    top_edge,
    bottom_edge,
    near_page_margin,
    outside_body_band,
    small_height: @model.rect_height(block._bbox) <= 24.0,
    short_text: text.length() <= 40 && count_words(text) <= 6,
    repeated_across_pages,
    same_text_same_edge: repeated_across_pages,
    same_prefix_same_edge,
    page_count_pattern,
    page_number_numeric,
    page_number_roman,
    page_number_with_label,
    page_number_short_centered: page_number_like &&
    is_short_centered_block(page, block),
    page_number_edge: page_number_like && (top_edge || bottom_edge),
    heading_like_but_repeated_edge,
    link_or_annotation_nearby: is_annotation_near_block(page, block),
    image_caption_guard,
    body_like_guard,
    long_sentence_guard,
    two_column_guard,
    core_page_number_candidate: block.is_noise_candidate,
    core_header_footer_candidate: block.is_header_footer_candidate,
    core_artifact_candidate: block.is_artifact_candidate,
  }
}

///|
fn decide_noise_block(
  page : PdfConvertPage,
  block_index : Int,
  block : PdfConvertBlock,
  repeated : PdfRepeatedEdgeNoiseIndex,
) -> PdfNoiseDecision {
  let evidence = collect_edge_noise_evidence(page, block_index, block, repeated)

  if block.kind == PdfConvertBlockKind::Noise {
    return {
      status: PdfNoiseDecisionStatus::Drop,
      reason_tags: noise_drop_reason_tags(evidence, true),
    }
  }

  if evidence.empty_text {
    return { status: PdfNoiseDecisionStatus::Drop, reason_tags: ["empty_text"] }
  }

  if should_keep_edge_block_with_evidence(evidence) {
    return {
      status: PdfNoiseDecisionStatus::Keep,
      reason_tags: noise_keep_reason_tags(evidence),
    }
  }

  if should_drop_repeated_edge_block_with_evidence(evidence) {
    return {
      status: PdfNoiseDecisionStatus::Drop,
      reason_tags: noise_drop_reason_tags(evidence, false),
    }
  }

  {
    status: PdfNoiseDecisionStatus::Keep,
    reason_tags: noise_keep_reason_tags(evidence),
  }
}

///|
fn should_drop_repeated_edge_block_with_evidence(
  evidence : PdfEdgeNoiseEvidence,
) -> Bool {
  strong_repeated_edge_drop(evidence) || strong_page_number_drop(evidence)
}

///|
fn should_keep_edge_block_with_evidence(
  evidence : PdfEdgeNoiseEvidence,
) -> Bool {
  evidence.body_like_guard ||
  evidence.long_sentence_guard ||
  evidence.image_caption_guard ||
  evidence.link_or_annotation_nearby ||
  evidence.two_column_guard
}

///|
fn strong_repeated_edge_drop(evidence : PdfEdgeNoiseEvidence) -> Bool {
  let edge_region = evidence.top_edge || evidence.bottom_edge
  let edge_repeated = edge_region &&
    evidence.outside_body_band &&
    evidence.short_text &&
    (
      evidence.same_text_same_edge ||
      (evidence.same_prefix_same_edge && evidence.page_count_pattern)
    )
  let repeated_footer_or_header = edge_region &&
    evidence.near_page_margin &&
    evidence.small_height &&
    evidence.short_text &&
    evidence.same_text_same_edge &&
    (evidence.bottom_edge || evidence.heading_like_but_repeated_edge)

  edge_repeated ||
  repeated_footer_or_header ||
  (
    evidence.heading_like_but_repeated_edge &&
    evidence.repeated_across_pages &&
    edge_region &&
    evidence.outside_body_band &&
    (evidence.same_text_same_edge || evidence.same_prefix_same_edge)
  )
}

///|
fn strong_page_number_drop(evidence : PdfEdgeNoiseEvidence) -> Bool {
  let edge_page_number = evidence.page_number_edge &&
    evidence.outside_body_band &&
    evidence.short_text

  (edge_page_number && evidence.page_number_numeric && evidence.bottom_edge) ||
  (
    edge_page_number &&
    evidence.page_number_short_centered &&
    evidence.bottom_edge
  ) ||
  (edge_page_number && evidence.page_number_with_label) ||
  (
    edge_page_number &&
    evidence.page_number_roman &&
    evidence.isolated_line &&
    (evidence.top_edge || evidence.bottom_edge)
  )
}

///|
fn noise_drop_reason_tags(
  evidence : PdfEdgeNoiseEvidence,
  from_noise_kind : Bool,
) -> Array[String] {
  let out : Array[String] = []

  if from_noise_kind {
    out.push("core_noise_kind")
  }
  push_edge_reason_tags(out, evidence)

  if out.is_empty() {
    out.push("drop_noise_block")
  }

  out
}

///|
fn noise_keep_reason_tags(evidence : PdfEdgeNoiseEvidence) -> Array[String] {
  let out : Array[String] = []

  if evidence.body_like_guard {
    out.push("body_like_guard")
  }
  if evidence.long_sentence_guard {
    out.push("long_sentence_guard")
  }
  if evidence.two_column_guard {
    out.push("two_column_guard")
  }
  if evidence.link_or_annotation_nearby {
    out.push("link_or_annotation_nearby")
  }
  if evidence.image_caption_guard {
    out.push("image_caption_guard")
  }
  if evidence.repeated_across_pages &&
    (evidence.top_edge || evidence.bottom_edge) {
    out.push("repeated_across_pages")
  }
  if (evidence.top_edge || evidence.bottom_edge) &&
    !evidence.repeated_across_pages {
    out.push("not_repeated_across_pages")
  }
  if !evidence.top_edge && !evidence.bottom_edge {
    out.push("not_edge_block")
  }
  if out.is_empty() {
    out.push("keep_content_block")
  }

  out
}

///|
fn push_edge_reason_tags(
  out : Array[String],
  evidence : PdfEdgeNoiseEvidence,
) -> Unit {
  if evidence.top_edge {
    out.push("top_edge")
  }
  if evidence.bottom_edge {
    out.push("bottom_edge")
  }
  if evidence.near_page_margin {
    out.push("near_page_margin")
  }
  if evidence.outside_body_band {
    out.push("outside_body_band")
  }
  if evidence.small_height {
    out.push("small_height")
  }
  if evidence.short_text {
    out.push("short_text")
  }
  if evidence.repeated_across_pages {
    out.push("repeated_across_pages")
  }
  if evidence.same_text_same_edge {
    out.push("same_text_same_edge")
  }
  if evidence.same_prefix_same_edge {
    out.push("same_prefix_same_edge")
  }
  if evidence.page_count_pattern {
    out.push("page_count_pattern")
  }
  if evidence.page_number_numeric {
    out.push("page_number_numeric")
  }
  if evidence.page_number_roman {
    out.push("page_number_roman")
  }
  if evidence.page_number_with_label {
    out.push("page_number_with_label")
  }
  if evidence.page_number_short_centered {
    out.push("page_number_short_centered")
  }
  if evidence.page_number_edge {
    out.push("page_number_edge")
  }
  if evidence.heading_like_but_repeated_edge {
    out.push("heading_like_but_repeated_edge")
  }
  if evidence.core_page_number_candidate {
    out.push("core_page_number_candidate")
  }
  if evidence.core_header_footer_candidate {
    out.push("core_header_footer_candidate")
  }
  if evidence.core_artifact_candidate {
    out.push("core_artifact_candidate")
  }
}

///|
fn edge_reason_tags(evidence : PdfEdgeNoiseEvidence) -> Array[String] {
  let out : Array[String] = []
  push_edge_reason_tags(out, evidence)
  if evidence.two_column_guard {
    out.push("two_column_guard")
  }
  if evidence.body_like_guard {
    out.push("body_like_guard")
  }
  if evidence.image_caption_guard {
    out.push("image_caption_guard")
  }
  if evidence.link_or_annotation_nearby {
    out.push("link_or_annotation_nearby")
  }
  if evidence.long_sentence_guard {
    out.push("long_sentence_guard")
  }
  out
}

///|
fn render_pdf_noise_decision(
  page_index : Int,
  block_index : Int,
  decision : PdfNoiseDecision,
  text : String,
) -> String {
  "[pdf-noise] page=" +
  page_index.to_string() +
  " block=" +
  block_index.to_string() +
  " status=" +
  render_pdf_noise_status(decision.status) +
  " reason=" +
  render_noise_reason_tags(decision.reason_tags) +
  " text=\"" +
  text +
  "\""
}

///|
fn render_pdf_edge_evidence(
  page_index : Int,
  block_index : Int,
  evidence : PdfEdgeNoiseEvidence,
  text : String,
) -> String {
  "[pdf-edge] page=" +
  page_index.to_string() +
  " block=" +
  block_index.to_string() +
  " region=" +
  edge_region_str(evidence) +
  " reason=" +
  render_noise_reason_tags(edge_reason_tags(evidence)) +
  " text=\"" +
  text +
  "\""
}

///|
fn render_pdf_noise_status(status : PdfNoiseDecisionStatus) -> String {
  match status {
    PdfNoiseDecisionStatus::Drop => "drop"
    PdfNoiseDecisionStatus::Keep => "keep"
  }
}

///|
fn render_noise_reason_tags(reason_tags : Array[String]) -> String {
  if reason_tags.is_empty() {
    "none"
  } else {
    reason_tags.join("+")
  }
}

///|
fn edge_region_str(evidence : PdfEdgeNoiseEvidence) -> String {
  if evidence.top_edge && evidence.bottom_edge {
    "top_bottom_edge"
  } else if evidence.top_edge {
    "top_edge"
  } else if evidence.bottom_edge {
    "bottom_edge"
  } else {
    "body_band"
  }
}

///|
fn normalize_noise_prefix_key(s : String) -> String {
  let key = normalize_noise_key(s)
  if key == "" {
    return ""
  }

  let parts : Array[String] = []
  for sv in key.split(" ") {
    let t = sv.trim().to_owned()
    if t != "" {
      parts.push(t)
      if parts.length() >= 3 {
        break
      }
    }
  }

  if parts.length() >= 2 {
    return parts.join(" ")
  }

  if key.length() >= 12 {
    key[:12].to_owned()
  } else {
    ""
  }
}

///|
fn is_numeric_page_number_like(text : String) -> Bool {
  let t = text.trim().to_owned()
  t != "" && t.length() <= 4 && all_ascii_digits(t)
}

///|
fn is_roman_page_number_like(text : String) -> Bool {
  let t = text.trim().to_upper()
  if t == "" || t.length() > 6 {
    return false
  }

  let mut has_roman = false
  for ch in t {
    match ch {
      'I' | 'V' | 'X' | 'L' | 'C' | 'D' | 'M' => has_roman = true
      _ => return false
    }
  }
  has_roman
}

///|
fn is_short_centered_block(
  page : PdfConvertPage,
  block : PdfConvertBlock,
) -> Bool {
  match effective_page_box(page) {
    Some(box) => {
      let page_center = (box.x0 + box.x1) / 2.0
      let block_center = (block._bbox.x0 + block._bbox.x1) / 2.0
      abs_noise_f64(page_center - block_center) <= 40.0 &&
      count_words(block.text.trim().to_owned()) <= 3
    }
    None => false
  }
}

///|
fn is_near_page_margin(page : PdfConvertPage, block : PdfConvertBlock) -> Bool {
  if is_top_edge_block(page, block) || is_bottom_edge_block(page, block) {
    return true
  }

  match effective_page_box(page) {
    Some(box) =>
      block._bbox.x0 <= box.x0 + 24.0 || block._bbox.x1 >= box.x1 - 24.0
    None => false
  }
}

///|
fn is_outside_body_band(page : PdfConvertPage, block : PdfConvertBlock) -> Bool {
  match effective_page_box(page) {
    Some(box) => {
      let h = page_box_height(box)
      if h <= 0.0 {
        return false
      }
      let center_y = (block._bbox.y0 + block._bbox.y1) / 2.0
      center_y >= box.y1 - h * 0.18 || center_y <= box.y0 + h * 0.18
    }
    None => false
  }
}

///|
fn is_annotation_near_block(
  page : PdfConvertPage,
  block : PdfConvertBlock,
) -> Bool {
  for annotation in page.annotations {
    if rects_overlap_or_near(block._bbox, annotation._bbox, 8.0) {
      return true
    }
  }
  false
}

///|
fn is_image_caption_guard(
  page : PdfConvertPage,
  block : PdfConvertBlock,
) -> Bool {
  for image in page.images {
    if rects_overlap_or_near(block._bbox, image._bbox, 18.0) {
      return true
    }
  }
  false
}

///|
fn looks_like_two_column_edge_block(
  page : PdfConvertPage,
  block : PdfConvertBlock,
  text : String,
) -> Bool {
  match effective_page_box(page) {
    Some(box) => {
      let page_w = max_noise_f64(page_box_width(box), 1.0)
      let block_w = max_noise_f64(@model.rect_width(block._bbox), 0.0)
      let page_center = (box.x0 + box.x1) / 2.0
      let block_center = (block._bbox.x0 + block._bbox.x1) / 2.0
      let centered = abs_noise_f64(page_center - block_center) <= 40.0
      (is_top_edge_block(page, block) || is_bottom_edge_block(page, block)) &&
      block_w <= page_w * 0.35 &&
      !centered &&
      looks_like_side_marker_label_line(text)
    }
    None => false
  }
}

///|
fn rects_overlap_or_near(
  a : @model.PdfRect,
  b : @model.PdfRect,
  pad : Double,
) -> Bool {
  let x_overlap = a.x0 <= b.x1 + pad && a.x1 + pad >= b.x0
  let y_overlap = a.y0 <= b.y1 + pad && a.y1 + pad >= b.y0
  x_overlap && y_overlap
}

///|
fn source_block_kind_is_heading_candidate(
  kind : @model.PdfTextBlockKind,
) -> Bool {
  match kind {
    @model.PdfTextBlockKind::HeadingCandidate => true
    _ => false
  }
}

///|
fn page_box_width(box : @model.PdfRect) -> Double {
  box.x1 - box.x0
}

///|
fn abs_noise_f64(v : Double) -> Double {
  if v < 0.0 {
    -v
  } else {
    v
  }
}

///|
fn max_noise_f64(a : Double, b : Double) -> Double {
  if a >= b {
    a
  } else {
    b
  }
}
