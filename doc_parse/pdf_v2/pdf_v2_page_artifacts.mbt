///|
pub(all) enum PdfV2PageArtifactKind {
  HeaderLike
  FooterLike
  PageNumberLike
  RepeatedLineLike
  CaptionLike
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2PagePositionBand {
  Top
  Body
  Bottom
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2PageArtifactCandidate {
  kind : PdfV2PageArtifactKind
  normalized_text : String
  normalized_key : String
  raw_text_variants : Array[String]
  page_indices : Array[Int]
  repeat_count : Int
  position_band : PdfV2PagePositionBand
  page_coverage_ratio : Double
  first_page_index : Int?
  last_page_index : Int?
  page_number_like : Bool
  numbered_variant : Bool
  real_heading_risk : Bool
  table_header_body_risk : Bool
  confidence : Double
  reason_tags : Array[String]
  blockers : Array[String]
  source_refs : Array[PdfV2SourceRef]
}

///|
pub fn pdf_v2_build_page_artifact_candidates(
  model : PdfV2DocumentModel,
) -> Array[PdfV2PageArtifactCandidate] {
  let candidates : Array[PdfV2PageArtifactCandidate] = []
  let repeated = pdf_v2_page_artifact_repeated_lines(model)
  candidates.append(repeated)
  for page in model.pages {
    for line in page.lines {
      let normalized_text = line.text_signal.normalized_text
      let page_indices = match line.page_index {
        Some(index) => [index]
        None => [page.page_index]
      }
      let coverage = pdf_v2_page_artifact_page_coverage_ratio(
        page_indices,
        model.page_count,
      )
      let normalized_key = pdf_v2_page_artifact_variant_key(normalized_text)
      let numbered_variant = normalized_key !=
        normalized_text.to_lower().trim().to_owned()
      if line.text_signal.starts_with_page_number {
        candidates.push({
          kind: PdfV2PageArtifactKind::PageNumberLike,
          normalized_text,
          normalized_key,
          raw_text_variants: [normalized_text],
          page_indices,
          repeat_count: 1,
          position_band: pdf_v2_page_artifact_position_band(line, page),
          page_coverage_ratio: coverage,
          first_page_index: Some(page_indices[0]),
          last_page_index: Some(page_indices[page_indices.length() - 1]),
          page_number_like: true,
          numbered_variant,
          real_heading_risk: false,
          table_header_body_risk: false,
          confidence: 0.98,
          reason_tags: [
            "page_artifact_candidate", "parser_owned_page_artifact_candidate", "page_number_like",
            "edge_position_known", "candidate_suppression_ready",
          ],
          blockers: [],
          source_refs: line.source_refs,
        })
      } else if line.text_signal.starts_with_caption_marker {
        candidates.push({
          kind: PdfV2PageArtifactKind::CaptionLike,
          normalized_text,
          normalized_key,
          raw_text_variants: [normalized_text],
          page_indices,
          repeat_count: 1,
          position_band: pdf_v2_page_artifact_position_band(line, page),
          page_coverage_ratio: coverage,
          first_page_index: Some(page_indices[0]),
          last_page_index: Some(page_indices[page_indices.length() - 1]),
          page_number_like: false,
          numbered_variant,
          real_heading_risk: false,
          table_header_body_risk: true,
          confidence: 0.72,
          reason_tags: [
            "page_artifact_candidate", "parser_owned_page_artifact_candidate", "caption_like",
            "audit_only_candidate",
          ],
          blockers: ["caption_like_not_product_noise"],
          source_refs: line.source_refs,
        })
      }
    }
  }
  candidates
}

///|
fn pdf_v2_page_artifact_repeated_lines(
  model : PdfV2DocumentModel,
) -> Array[PdfV2PageArtifactCandidate] {
  let texts : Array[String] = []
  let keys : Array[String] = []
  let pages_by_text : Array[Array[Int]] = []
  let refs_by_text : Array[Array[PdfV2SourceRef]] = []
  let band_by_text : Array[PdfV2PagePositionBand] = []
  let body_seen_by_text : Array[Bool] = []
  let real_heading_risk_by_text : Array[Bool] = []
  let table_risk_by_text : Array[Bool] = []
  let page_number_like_by_text : Array[Bool] = []
  let top_page_number_pages : Array[Int] = []
  let bottom_page_number_pages : Array[Int] = []
  for page in model.pages {
    for line in page.lines {
      if !line.text_signal.starts_with_page_number {
        continue
      }
      match pdf_v2_page_artifact_position_band(line, page) {
        Top =>
          if !top_page_number_pages.contains(page.page_index) {
            top_page_number_pages.push(page.page_index)
          }
        Bottom =>
          if !bottom_page_number_pages.contains(page.page_index) {
            bottom_page_number_pages.push(page.page_index)
          }
        _ => ()
      }
    }
  }
  for page in model.pages {
    for line in page.lines {
      let t = line.text_signal.normalized_text
      if !pdf_v2_page_artifact_repetition_eligible(line.text_signal) {
        continue
      }
      let band = pdf_v2_page_artifact_position_band(line, page)
      let key = pdf_v2_page_artifact_variant_key(t)
      let mut found = -1
      for i in 0..<texts.length() {
        if texts[i] == t {
          found = i
          break
        }
      }
      if found < 0 {
        texts.push(t)
        keys.push(key)
        pages_by_text.push([page.page_index])
        refs_by_text.push(line.source_refs)
        band_by_text.push(band)
        body_seen_by_text.push(band == PdfV2PagePositionBand::Body)
        real_heading_risk_by_text.push(
          pdf_v2_page_artifact_real_heading_risk(line.text_signal, t),
        )
        table_risk_by_text.push(pdf_v2_page_artifact_table_header_body_risk(t))
        page_number_like_by_text.push(line.text_signal.starts_with_page_number)
      } else {
        if !pages_by_text[found].contains(page.page_index) {
          pages_by_text[found].push(page.page_index)
        }
        refs_by_text[found].append(line.source_refs)
        if band_by_text[found] == PdfV2PagePositionBand::Unknown &&
          band != PdfV2PagePositionBand::Unknown {
          band_by_text[found] = band
        }
        if band == PdfV2PagePositionBand::Body {
          body_seen_by_text[found] = true
        }
        if pdf_v2_page_artifact_real_heading_risk(line.text_signal, t) {
          real_heading_risk_by_text[found] = true
        }
        if pdf_v2_page_artifact_table_header_body_risk(t) {
          table_risk_by_text[found] = true
        }
        if line.text_signal.starts_with_page_number {
          page_number_like_by_text[found] = true
        }
      }
    }
  }
  let out : Array[PdfV2PageArtifactCandidate] = []
  for i in 0..<texts.length() {
    if pages_by_text[i].length() >= 2 && !body_seen_by_text[i] {
      let band = band_by_text[i]
      let kind = match band {
        Top => PdfV2PageArtifactKind::HeaderLike
        Bottom => PdfV2PageArtifactKind::FooterLike
        _ => PdfV2PageArtifactKind::RepeatedLineLike
      }
      let coverage = pdf_v2_page_artifact_page_coverage_ratio(
        pages_by_text[i],
        model.page_count,
      )
      let numbered_variant = keys[i] != texts[i].to_lower().trim().to_owned()
      let page_number_support = pdf_v2_page_artifact_page_number_support(
        pages_by_text[i],
        band,
        top_page_number_pages,
        bottom_page_number_pages,
      )
      let blockers = pdf_v2_page_artifact_repeated_blockers(
        band,
        real_heading_risk_by_text[i],
        page_number_support,
        table_risk_by_text[i],
      )
      let reason_tags = [
        "page_artifact_candidate", "parser_owned_page_artifact_candidate", "repeated_short_line",
      ]
      if band == PdfV2PagePositionBand::Top ||
        band == PdfV2PagePositionBand::Bottom {
        reason_tags.push("repeated_edge_evidence")
      }
      if page_number_support {
        reason_tags.push("page_number_support")
      }
      if numbered_variant {
        reason_tags.push("numbered_variant")
      }
      if page_number_like_by_text[i] {
        reason_tags.push("page_number_like")
      }
      if real_heading_risk_by_text[i] {
        reason_tags.push("real_heading_risk")
      }
      if table_risk_by_text[i] {
        reason_tags.push("table_header_body_risk")
      }
      let confidence = pdf_v2_page_artifact_repeated_confidence(
        band,
        pages_by_text[i].length(),
        model.page_count,
        page_number_like_by_text[i],
        numbered_variant,
        real_heading_risk_by_text[i],
        page_number_support,
        table_risk_by_text[i],
      )
      if pdf_v2_page_artifact_product_attachable({
          kind,
          normalized_text: texts[i],
          normalized_key: keys[i],
          raw_text_variants: [texts[i]],
          page_indices: pages_by_text[i],
          repeat_count: pages_by_text[i].length(),
          position_band: band,
          page_coverage_ratio: coverage,
          first_page_index: pdf_v2_page_artifact_first_page_index(
            pages_by_text[i],
          ),
          last_page_index: pdf_v2_page_artifact_last_page_index(
            pages_by_text[i],
          ),
          page_number_like: page_number_like_by_text[i],
          numbered_variant,
          real_heading_risk: real_heading_risk_by_text[i],
          table_header_body_risk: table_risk_by_text[i],
          confidence,
          reason_tags,
          blockers,
          source_refs: refs_by_text[i],
        }) {
        reason_tags.push("candidate_suppression_ready")
      } else {
        reason_tags.push("audit_only_candidate")
      }
      out.push({
        kind,
        normalized_text: texts[i],
        normalized_key: keys[i],
        raw_text_variants: [texts[i]],
        page_indices: pages_by_text[i],
        repeat_count: pages_by_text[i].length(),
        position_band: band,
        page_coverage_ratio: coverage,
        first_page_index: pdf_v2_page_artifact_first_page_index(
          pages_by_text[i],
        ),
        last_page_index: pdf_v2_page_artifact_last_page_index(pages_by_text[i]),
        page_number_like: page_number_like_by_text[i],
        numbered_variant,
        real_heading_risk: real_heading_risk_by_text[i],
        table_header_body_risk: table_risk_by_text[i],
        confidence,
        reason_tags,
        blockers,
        source_refs: refs_by_text[i],
      })
    }
  }
  out
}

///|
fn pdf_v2_page_artifact_repeated_confidence(
  band : PdfV2PagePositionBand,
  repeat_count : Int,
  page_count : Int,
  page_number_like : Bool,
  numbered_variant : Bool,
  real_heading_risk : Bool,
  page_number_support : Bool,
  table_risk : Bool,
) -> Double {
  if page_number_like {
    return 0.98
  }
  let mut confidence = if band == PdfV2PagePositionBand::Top ||
    band == PdfV2PagePositionBand::Bottom {
    0.88
  } else {
    0.82
  }
  let coverage = if page_count <= 0 {
    0.0
  } else {
    repeat_count.to_double() / page_count.to_double()
  }
  if coverage >= 0.66 || repeat_count >= 3 || page_count <= 2 {
    confidence = confidence + 0.02
  }
  if band == PdfV2PagePositionBand::Bottom {
    confidence = confidence + 0.02
  }
  if numbered_variant && page_number_support {
    confidence = confidence + 0.02
  }
  if real_heading_risk &&
    band == PdfV2PagePositionBand::Top &&
    !page_number_support {
    confidence = confidence - 0.08
  }
  if table_risk {
    confidence = confidence - 0.08
  }
  pdf_v2_page_artifact_clamp_confidence(confidence)
}

///|
fn pdf_v2_page_artifact_repetition_eligible(
  signal : PdfV2LineTextSignal,
) -> Bool {
  signal.normalized_text != "" &&
  signal.char_count >= 4 &&
  signal.char_count <= 80 &&
  !signal.starts_with_ordered_marker &&
  !signal.starts_with_unordered_marker &&
  !signal.starts_with_caption_marker &&
  !signal.ends_with_sentence_punctuation
}

///|
fn pdf_v2_page_artifact_position_band(
  line : PdfV2LineCandidate,
  page : PdfV2PageModel,
) -> PdfV2PagePositionBand {
  match line.bbox {
    Some(bbox) => {
      let height = page.media_box.y1 - page.media_box.y0
      if height <= 0.0 {
        return PdfV2PagePositionBand::Unknown
      }
      let top_cut = page.media_box.y1 - height * 0.15
      let bottom_cut = page.media_box.y0 + height * 0.15
      if bbox.y1 >= top_cut {
        PdfV2PagePositionBand::Top
      } else if bbox.y0 <= bottom_cut {
        PdfV2PagePositionBand::Bottom
      } else {
        PdfV2PagePositionBand::Body
      }
    }
    None => pdf_v2_page_artifact_source_order_band(line, page)
  }
}

///|
fn pdf_v2_page_artifact_source_order_band(
  line : PdfV2LineCandidate,
  page : PdfV2PageModel,
) -> PdfV2PagePositionBand {
  if page.blocks.length() == 0 {
    return PdfV2PagePositionBand::Unknown
  }
  let last_block_index = page.blocks.length() - 1
  for block_index in 0..<page.blocks.length() {
    let block = page.blocks[block_index]
    for line_offset in 0..<block.lines.length() {
      if block.lines[line_offset].line_index != line.line_index {
        continue
      }
      if block_index == 0 && line_offset <= 1 {
        return PdfV2PagePositionBand::Top
      }
      if block_index == last_block_index &&
        line_offset == block.lines.length() - 1 {
        return PdfV2PagePositionBand::Bottom
      }
      return PdfV2PagePositionBand::Unknown
    }
  }
  PdfV2PagePositionBand::Unknown
}

///|
fn pdf_v2_page_artifact_variant_key(text : String) -> String {
  let out = StringBuilder::new()
  let mut prev_space = false
  let mut prev_digit = false
  for ch in text.to_lower() {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if !prev_space {
        out.write_char(' ')
        prev_space = true
      }
      prev_digit = false
    } else if ch >= '0' && ch <= '9' {
      if !prev_digit {
        out.write_char('#')
        prev_digit = true
      }
      prev_space = false
    } else {
      out.write_char(ch)
      prev_space = false
      prev_digit = false
    }
  }
  out.to_string().trim().to_owned()
}

///|
fn pdf_v2_page_artifact_page_coverage_ratio(
  page_indices : Array[Int],
  page_count : Int,
) -> Double {
  if page_count <= 0 {
    0.0
  } else {
    page_indices.length().to_double() / page_count.to_double()
  }
}

///|
fn pdf_v2_page_artifact_first_page_index(page_indices : Array[Int]) -> Int? {
  if page_indices.length() == 0 {
    None
  } else {
    Some(page_indices[0])
  }
}

///|
fn pdf_v2_page_artifact_last_page_index(page_indices : Array[Int]) -> Int? {
  if page_indices.length() == 0 {
    None
  } else {
    Some(page_indices[page_indices.length() - 1])
  }
}

///|
fn pdf_v2_page_artifact_product_attachable(
  artifact : PdfV2PageArtifactCandidate,
) -> Bool {
  if artifact.kind == PdfV2PageArtifactKind::CaptionLike {
    return true
  }
  artifact.confidence >= 0.90 && artifact.blockers.length() == 0
}

///|
fn pdf_v2_page_artifact_real_heading_risk(
  signal : PdfV2LineTextSignal,
  text : String,
) -> Bool {
  signal.looks_like_title_line && pdf_v2_page_artifact_heading_shape(text)
}

///|
fn pdf_v2_page_artifact_heading_shape(text : String) -> Bool {
  pdf_v2_page_artifact_common_section_label(text) ||
  pdf_v2_page_artifact_section_phrase(text) ||
  pdf_v2_page_artifact_numbered_section(text) ||
  pdf_v2_page_artifact_cjk_section_title(text)
}

///|
fn pdf_v2_page_artifact_common_section_label(text : String) -> Bool {
  let lower = text.trim().to_owned().to_lower()
  lower == "abstract" ||
  lower == "introduction" ||
  lower == "background" ||
  lower == "method" ||
  lower == "methods" ||
  lower == "results" ||
  lower == "discussion" ||
  lower == "summary" ||
  lower == "details" ||
  lower == "conclusion" ||
  lower == "references"
}

///|
fn pdf_v2_page_artifact_section_phrase(text : String) -> Bool {
  let words = text.split(" ").to_array()
  if words.length() < 2 || words.length() > 5 {
    return false
  }
  let mut saw_section_noun = false
  let mut saw_context = false
  for raw in words {
    let word = raw.trim().to_owned().to_lower()
    if word == "" {
      continue
    }
    if word == "section" ||
      word == "sections" ||
      word == "chapter" ||
      word == "chapters" {
      saw_section_noun = true
    } else if word == "next" ||
      word == "new" ||
      word == "page" ||
      word == "part" ||
      word == "topic" ||
      pdf_v2_page_artifact_all_ascii_digits(word) {
      saw_context = true
    }
  }
  saw_section_noun && saw_context
}

///|
fn pdf_v2_page_artifact_numbered_section(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 5 || chars.length() > 48 {
    return false
  }
  if !pdf_v2_page_artifact_ascii_digit(chars[0]) {
    return false
  }
  let mut i = 0
  while i < chars.length() && pdf_v2_page_artifact_ascii_digit(chars[i]) {
    i = i + 1
  }
  if i >= chars.length() || chars[i] != '.' {
    return false
  }
  i = i + 1
  let mut saw_digit = false
  while i < chars.length() {
    if pdf_v2_page_artifact_ascii_digit(chars[i]) {
      saw_digit = true
      i = i + 1
    } else if chars[i] == '.' {
      i = i + 1
    } else {
      break
    }
  }
  saw_digit && i < chars.length()
}

///|
fn pdf_v2_page_artifact_cjk_section_title(text : String) -> Bool {
  text.has_prefix("第") &&
  (text.contains("章") || text.contains("节")) &&
  !text.contains("页")
}

///|
fn pdf_v2_page_artifact_table_header_body_risk(text : String) -> Bool {
  text.contains("|")
}

///|
fn pdf_v2_page_artifact_page_number_support(
  page_indices : Array[Int],
  band : PdfV2PagePositionBand,
  top_page_number_pages : Array[Int],
  bottom_page_number_pages : Array[Int],
) -> Bool {
  if band != PdfV2PagePositionBand::Top && band != PdfV2PagePositionBand::Bottom {
    return false
  }
  for page_index in page_indices {
    if band == PdfV2PagePositionBand::Top &&
      top_page_number_pages.contains(page_index) {
      return true
    }
    if band == PdfV2PagePositionBand::Bottom &&
      bottom_page_number_pages.contains(page_index) {
      return true
    }
  }
  false
}

///|
fn pdf_v2_page_artifact_repeated_blockers(
  band : PdfV2PagePositionBand,
  real_heading_risk : Bool,
  page_number_support : Bool,
  table_risk : Bool,
) -> Array[String] {
  let blockers : Array[String] = []
  if table_risk {
    blockers.push("table_header_body_risk")
  }
  if real_heading_risk &&
    band == PdfV2PagePositionBand::Top &&
    !page_number_support {
    blockers.push("real_heading_risk")
  }
  blockers
}

///|
fn pdf_v2_page_artifact_all_ascii_digits(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }
  for ch in t {
    if !pdf_v2_page_artifact_ascii_digit(ch) {
      return false
    }
  }
  true
}

///|
fn pdf_v2_page_artifact_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn pdf_v2_page_artifact_clamp_confidence(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}
