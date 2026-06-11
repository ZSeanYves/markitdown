///|
pub(all) struct PdfV2BlockBoundarySignal {
  line_count : Int
  first_line_text : String
  last_line_text : String
  vertical_gap_before : Double?
  vertical_gap_after : Double?
  indent_profile : String?
  font_size_relation_to_page : String?
  heading_candidate_score : Double
  list_candidate_score : Double
  continuation_candidate_score : Double
  artifact_candidate_score : Double
  boundary_confidence : Double
  reason_tags : Array[String]
}

///|
pub fn pdf_v2_build_block_boundary_signal(
  lines : Array[PdfV2LineCandidate],
  block_reason_tags : Array[String],
  bbox : PdfV2BBox?,
) -> PdfV2BlockBoundarySignal {
  let line_count = lines.length()
  let first_line_text = if line_count > 0 {
    lines[0].text_signal.normalized_text
  } else {
    ""
  }
  let last_line_text = if line_count > 0 {
    lines[line_count - 1].text_signal.normalized_text
  } else {
    ""
  }
  let heading_score = pdf_v2_block_heading_score(lines)
  let list_score = pdf_v2_block_list_score(lines)
  let continuation_score = pdf_v2_block_continuation_score(lines)
  let artifact_score = pdf_v2_block_artifact_score(lines)
  {
    line_count,
    first_line_text,
    last_line_text,
    vertical_gap_before: None,
    vertical_gap_after: None,
    indent_profile: pdf_v2_block_indent_profile(lines),
    font_size_relation_to_page: None,
    heading_candidate_score: heading_score,
    list_candidate_score: list_score,
    continuation_candidate_score: continuation_score,
    artifact_candidate_score: artifact_score,
    boundary_confidence: if bbox is None {
      0.45
    } else {
      0.65
    },
    reason_tags: pdf_v2_block_boundary_reason_tags(
      block_reason_tags, heading_score, list_score, continuation_score, artifact_score,
      bbox,
    ),
  }
}

///|
pub fn pdf_v2_empty_block_boundary_signal() -> PdfV2BlockBoundarySignal {
  {
    line_count: 0,
    first_line_text: "",
    last_line_text: "",
    vertical_gap_before: None,
    vertical_gap_after: None,
    indent_profile: None,
    font_size_relation_to_page: None,
    heading_candidate_score: 0.0,
    list_candidate_score: 0.0,
    continuation_candidate_score: 0.0,
    artifact_candidate_score: 0.0,
    boundary_confidence: 0.0,
    reason_tags: ["block_boundary_signal_empty"],
  }
}

///|
fn pdf_v2_block_heading_score(lines : Array[PdfV2LineCandidate]) -> Double {
  if lines.length() == 0 {
    return 0.0
  }
  let first = lines[0].text_signal
  if first.looks_like_noise_line ||
    first.starts_with_ordered_marker ||
    first.starts_with_unordered_marker ||
    first.starts_with_caption_marker ||
    first.starts_with_page_number {
    return 0.0
  }
  if first.looks_like_title_line {
    if lines.length() > 1 && pdf_v2_block_following_body(lines) {
      0.88
    } else {
      0.72
    }
  } else {
    0.0
  }
}

///|
fn pdf_v2_block_list_score(lines : Array[PdfV2LineCandidate]) -> Double {
  if lines.length() == 0 {
    return 0.0
  }
  let first = lines[0].text_signal
  if first.starts_with_ordered_marker || first.starts_with_unordered_marker {
    0.92
  } else {
    0.0
  }
}

///|
fn pdf_v2_block_continuation_score(lines : Array[PdfV2LineCandidate]) -> Double {
  if lines.length() < 2 {
    return 0.0
  }
  let first = lines[0].text_signal
  let last = lines[lines.length() - 1].text_signal
  if first.looks_like_noise_line ||
    first.starts_with_ordered_marker ||
    first.starts_with_unordered_marker ||
    first.looks_like_title_line {
    return 0.0
  }
  if !last.ends_with_sentence_punctuation {
    0.62
  } else {
    0.50
  }
}

///|
fn pdf_v2_block_artifact_score(lines : Array[PdfV2LineCandidate]) -> Double {
  if lines.length() == 0 {
    return 1.0
  }
  let mut max_score = 0.0
  for line in lines {
    if line.text_signal.starts_with_page_number {
      max_score = 0.96
    } else if line.text_signal.looks_like_noise_line && max_score < 0.72 {
      max_score = 0.72
    }
  }
  max_score
}

///|
fn pdf_v2_block_following_body(lines : Array[PdfV2LineCandidate]) -> Bool {
  for index = 1; index < lines.length(); index = index + 1 {
    let signal = lines[index].text_signal
    if signal.normalized_text == "" {
      continue
    }
    if signal.starts_with_ordered_marker || signal.starts_with_unordered_marker {
      return true
    }
    if signal.ends_with_sentence_punctuation ||
      signal.char_count >= 24 ||
      signal.word_count >= 5 {
      return true
    }
  }
  false
}

///|
fn pdf_v2_block_indent_profile(lines : Array[PdfV2LineCandidate]) -> String? {
  if lines.length() == 0 {
    return None
  }
  let parts : Array[String] = []
  for line in lines {
    parts.push(pdf_v2_block_leading_space_count(line.text).to_string())
  }
  Some(parts.join(","))
}

///|
fn pdf_v2_block_leading_space_count(text : String) -> Int {
  let mut count = 0
  for ch in text {
    if ch == ' ' {
      count = count + 1
    } else if ch == '\t' {
      count = count + 2
    } else {
      break
    }
  }
  count
}

///|
fn pdf_v2_block_boundary_reason_tags(
  base_tags : Array[String],
  heading_score : Double,
  list_score : Double,
  continuation_score : Double,
  artifact_score : Double,
  bbox : PdfV2BBox?,
) -> Array[String] {
  let tags : Array[String] = [
    "block_boundary_signal", "parser_owned_block_boundary_signal",
  ]
  for tag in base_tags {
    if !tags.contains(tag) {
      tags.push(tag)
    }
  }
  if heading_score >= 0.70 {
    tags.push("heading_boundary_candidate")
  }
  if list_score >= 0.70 {
    tags.push("list_boundary_candidate")
  }
  if continuation_score >= 0.50 {
    tags.push("continuation_boundary_candidate")
  }
  if artifact_score >= 0.70 {
    tags.push("artifact_boundary_candidate")
  }
  if bbox is None {
    tags.push("boundary_geometry_unavailable")
  }
  tags
}
