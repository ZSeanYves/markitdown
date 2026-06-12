///|
pub(all) struct PdfV2TextFlowCandidate {
  page_index : Int?
  block_index : Int?
  flow_index : Int
  line_indices : Array[Int]
  text : String
  normalized_text : String
  original_lines : Array[String]
  normalized_lines : Array[String]
  line_signals : Array[PdfV2LineTextSignal]
  boundary_signal : PdfV2BlockBoundarySignal
  artifact_refs : Array[PdfV2PageArtifactCandidate]
  source_refs : Array[PdfV2SourceRef]
  reason_tags : Array[String]
}

///|
pub fn pdf_v2_build_text_flow_candidates(
  model : PdfV2DocumentModel,
) -> Array[PdfV2TextFlowCandidate] {
  let artifacts = pdf_v2_build_page_artifact_candidates(model)
  let out : Array[PdfV2TextFlowCandidate] = []
  let mut flow_index = 0
  for page in model.pages {
    let blocks = pdf_v2_text_flow_ordered_blocks(page.blocks)
    for block in blocks {
      let block_candidates = pdf_v2_text_flow_candidates_from_block(
        page, block, artifacts,
      )
      for candidate in block_candidates {
        out.push({ ..candidate, flow_index, })
        flow_index = flow_index + 1
      }
    }
  }
  out
}

///|
pub fn pdf_v2_text_flow_candidates_for_block(
  page : PdfV2PageModel,
  block : PdfV2BlockCandidate,
  artifacts : Array[PdfV2PageArtifactCandidate],
) -> Array[PdfV2TextFlowCandidate] {
  pdf_v2_text_flow_candidates_from_block(page, block, artifacts)
}

///|
fn pdf_v2_text_flow_candidates_from_block(
  page : PdfV2PageModel,
  block : PdfV2BlockCandidate,
  artifacts : Array[PdfV2PageArtifactCandidate],
) -> Array[PdfV2TextFlowCandidate] {
  let lines = pdf_v2_text_flow_ordered_lines(block.lines)
  let out : Array[PdfV2TextFlowCandidate] = []
  if lines.length() == 0 {
    if block.text.trim().to_owned() != "" {
      out.push(
        pdf_v2_text_flow_candidate_from_text(
          page,
          block,
          block.text,
          [],
          block.source_refs,
          block.boundary_signal,
          artifacts,
          ["text_flow_candidate", "block_text_only_candidate"],
        ),
      )
    }
    return out
  }
  if pdf_v2_text_flow_should_split_heading_body(block, lines) {
    out.push(
      pdf_v2_text_flow_candidate_from_lines(
        page,
        block,
        [lines[0]],
        block.boundary_signal,
        artifacts,
        [
          "text_flow_candidate", "heading_body_split", "heading_line_candidate",
          "structure_boundary_candidate", "title_body_boundary_candidate",
        ],
      ),
    )
    let rest : Array[PdfV2LineCandidate] = []
    for index = 1; index < lines.length(); index = index + 1 {
      rest.push(lines[index])
    }
    out.push(
      pdf_v2_text_flow_candidate_from_lines(
        page,
        block,
        rest,
        pdf_v2_build_block_boundary_signal(rest, block.reason_tags, block.bbox),
        artifacts,
        pdf_v2_text_flow_heading_body_rest_reason_tags(rest),
      ),
    )
    return out
  }
  let structure_candidates = pdf_v2_text_flow_structure_candidates(
    page, block, lines, artifacts,
  )
  if structure_candidates.length() > 0 {
    return structure_candidates
  }
  if lines.length() == 1 {
    let split = pdf_v2_text_flow_inline_list_candidates(
      page,
      block,
      lines[0],
      artifacts,
    )
    if split.length() > 1 {
      return split
    }
  }
  out.push(
    pdf_v2_text_flow_candidate_from_lines(
      page,
      block,
      lines,
      block.boundary_signal,
      artifacts,
      ["text_flow_candidate", "block_flow_candidate"],
    ),
  )
  out
}

///|
fn pdf_v2_text_flow_heading_body_rest_reason_tags(
  lines : Array[PdfV2LineCandidate],
) -> Array[String] {
  let tags : Array[String] = [
    "text_flow_candidate", "heading_body_split", "body_flow_candidate", "structure_boundary_candidate",
    "title_body_boundary_candidate",
  ]
  if lines.length() > 0 {
    let first = lines[0].text_signal
    if first.starts_with_ordered_marker || first.starts_with_unordered_marker {
      tags.push("list_marker_body_boundary_candidate")
    }
    if first.marker_candidate is Some(marker) &&
      marker.kind == PdfV2TextMarkerKind::HeadingMarker {
      tags.push("heading_list_boundary_candidate")
    }
  }
  tags
}

///|
fn pdf_v2_text_flow_structure_candidates(
  page : PdfV2PageModel,
  block : PdfV2BlockCandidate,
  lines : Array[PdfV2LineCandidate],
  artifacts : Array[PdfV2PageArtifactCandidate],
) -> Array[PdfV2TextFlowCandidate] {
  let out : Array[PdfV2TextFlowCandidate] = []
  let mut current : Array[PdfV2LineCandidate] = []
  let mut current_reason_tags : Array[String] = []
  let mut current_structure_tags : Array[String] = []
  let mut saw_structure = false
  for i in 0..<lines.length() {
    let line = lines[i]
    let signal = line.text_signal
    let starts_structure = pdf_v2_text_flow_line_starts_structure_boundary(
      current, line,
    )
    if starts_structure && current.length() > 0 {
      out.push(
        pdf_v2_text_flow_candidate_from_lines(
          page,
          block,
          current,
          pdf_v2_build_block_boundary_signal(
            current,
            block.reason_tags,
            block.bbox,
          ),
          artifacts,
          pdf_v2_text_flow_structure_reason_tags(
            current_reason_tags, current_structure_tags,
          ),
        ),
      )
      current = []
      current_reason_tags = []
      current_structure_tags = []
      saw_structure = true
    }
    if current.length() == 0 {
      current_reason_tags = [
        "text_flow_candidate", "structure_boundary_candidate", "parser_layout_backed",
      ]
      current_structure_tags = pdf_v2_text_flow_structure_reason_tags_for_line(
        signal,
        i,
        lines.length(),
      )
    } else {
      current_structure_tags = pdf_v2_text_flow_structure_reason_tags(
        current_structure_tags,
        pdf_v2_text_flow_structure_reason_tags_for_transition(
          current[current.length() - 1].text_signal,
          signal,
        ),
      )
    }
    current.push(line)
  }
  if current.length() > 0 {
    out.push(
      pdf_v2_text_flow_candidate_from_lines(
        page,
        block,
        current,
        pdf_v2_build_block_boundary_signal(
          current,
          block.reason_tags,
          block.bbox,
        ),
        artifacts,
        pdf_v2_text_flow_structure_reason_tags(
          current_reason_tags, current_structure_tags,
        ),
      ),
    )
  }
  if saw_structure {
    out
  } else {
    []
  }
}

///|
fn pdf_v2_text_flow_line_starts_structure_boundary(
  current : Array[PdfV2LineCandidate],
  line : PdfV2LineCandidate,
) -> Bool {
  if current.length() == 0 {
    return false
  }
  let signal = line.text_signal
  if signal.marker_candidate is Some(_) ||
    signal.starts_with_ordered_marker ||
    signal.starts_with_unordered_marker {
    return true
  }
  if signal.looks_like_title_line {
    let previous = current[current.length() - 1].text_signal
    return previous.ends_with_sentence_punctuation ||
      previous.starts_with_page_number ||
      previous.looks_like_noise_line
  }
  false
}

///|
fn pdf_v2_text_flow_structure_reason_tags(
  base : Array[String],
  structure : Array[String],
) -> Array[String] {
  let tags : Array[String] = []
  for tag in base {
    if !tags.contains(tag) {
      tags.push(tag)
    }
  }
  for tag in structure {
    if !tags.contains(tag) {
      tags.push(tag)
    }
  }
  tags
}

///|
fn pdf_v2_text_flow_structure_reason_tags_for_line(
  signal : PdfV2LineTextSignal,
  line_index : Int,
  line_count : Int,
) -> Array[String] {
  let tags : Array[String] = ["structure_boundary_candidate"]
  if signal.looks_like_title_line {
    tags.push("title_body_boundary_candidate")
  }
  if signal.marker_candidate is Some(marker) &&
    marker.kind == PdfV2TextMarkerKind::HeadingMarker {
    tags.push("heading_list_boundary_candidate")
  }
  if signal.starts_with_ordered_marker || signal.starts_with_unordered_marker {
    tags.push("list_marker_body_boundary_candidate")
  }
  if line_index == 0 && line_count > 1 {
    tags.push("parser_layout_backed")
  }
  tags
}

///|
fn pdf_v2_text_flow_structure_reason_tags_for_transition(
  left : PdfV2LineTextSignal,
  right : PdfV2LineTextSignal,
) -> Array[String] {
  let tags : Array[String] = ["structure_boundary_candidate"]
  if left.looks_like_title_line &&
    (
      right.starts_with_ordered_marker ||
      right.starts_with_unordered_marker ||
      right.looks_like_title_line
    ) {
    tags.push("title_body_boundary_candidate")
  }
  if right.marker_candidate is Some(marker) &&
    marker.kind == PdfV2TextMarkerKind::HeadingMarker {
    tags.push("heading_list_boundary_candidate")
  }
  if right.starts_with_ordered_marker || right.starts_with_unordered_marker {
    tags.push("list_marker_body_boundary_candidate")
  }
  tags
}

///|
fn pdf_v2_text_flow_should_split_heading_body(
  block : PdfV2BlockCandidate,
  lines : Array[PdfV2LineCandidate],
) -> Bool {
  if lines.length() < 2 {
    return false
  }
  let first = lines[0].text_signal
  first.looks_like_title_line &&
  block.boundary_signal.heading_candidate_score >= 0.80 &&
  pdf_v2_text_flow_has_following_body(lines)
}

///|
fn pdf_v2_text_flow_has_following_body(
  lines : Array[PdfV2LineCandidate],
) -> Bool {
  for index = 1; index < lines.length(); index = index + 1 {
    let signal = lines[index].text_signal
    if signal.ends_with_sentence_punctuation ||
      signal.starts_with_ordered_marker ||
      signal.starts_with_unordered_marker ||
      signal.char_count >= 24 ||
      signal.word_count >= 5 {
      return true
    }
  }
  false
}

///|
fn pdf_v2_text_flow_inline_list_candidates(
  page : PdfV2PageModel,
  block : PdfV2BlockCandidate,
  line : PdfV2LineCandidate,
  artifacts : Array[PdfV2PageArtifactCandidate],
) -> Array[PdfV2TextFlowCandidate] {
  let parts = pdf_v2_text_flow_split_bullet_runs(
    line.text_signal.normalized_text,
  )
  let out : Array[PdfV2TextFlowCandidate] = []
  if parts.length() <= 1 {
    return out
  }
  for part in parts {
    let t = part.trim().to_owned()
    if t == "" {
      continue
    }
    out.push(
      pdf_v2_text_flow_candidate_from_text(
        page,
        block,
        t,
        [line.line_index],
        line.source_refs,
        pdf_v2_build_block_boundary_signal([line], block.reason_tags, line.bbox),
        artifacts,
        [
          "text_flow_candidate", "inline_list_split", "structure_boundary_candidate",
          "list_marker_body_boundary_candidate",
        ],
      ),
    )
  }
  out
}

///|
fn pdf_v2_text_flow_split_bullet_runs(text : String) -> Array[String] {
  let chars = text.to_array()
  let out : Array[String] = []
  let mut current = StringBuilder::new()
  let mut saw_bullet = false
  let mut i = 0
  while i < chars.length() {
    let is_bullet = chars[i] == '•' &&
      i + 1 < chars.length() &&
      chars[i + 1] == ' '
    if is_bullet {
      let value = current.to_string().trim().to_owned()
      if value != "" {
        out.push(value)
      }
      current = StringBuilder::new()
      current.write_char(chars[i])
      current.write_char(' ')
      saw_bullet = true
      i = i + 2
    } else {
      current.write_char(chars[i])
      i = i + 1
    }
  }
  let final_value = current.to_string().trim().to_owned()
  if final_value != "" {
    out.push(final_value)
  }
  if saw_bullet {
    out
  } else {
    []
  }
}

///|
fn pdf_v2_text_flow_candidate_from_lines(
  page : PdfV2PageModel,
  block : PdfV2BlockCandidate,
  lines : Array[PdfV2LineCandidate],
  boundary_signal : PdfV2BlockBoundarySignal,
  artifacts : Array[PdfV2PageArtifactCandidate],
  reason_tags : Array[String],
) -> PdfV2TextFlowCandidate {
  let original_lines : Array[String] = []
  let normalized_lines : Array[String] = []
  let line_signals : Array[PdfV2LineTextSignal] = []
  let line_indices : Array[Int] = []
  let source_refs : Array[PdfV2SourceRef] = []
  for line in lines {
    original_lines.push(line.text)
    normalized_lines.push(line.text_signal.normalized_text)
    line_signals.push(line.text_signal)
    line_indices.push(line.line_index)
    source_refs.append(line.source_refs)
  }
  let text = original_lines.join("\n")
  let normalized_text = normalized_lines.join("\n").trim().to_owned()
  pdf_v2_text_flow_candidate(
    page,
    block,
    line_indices,
    text,
    normalized_text,
    original_lines,
    normalized_lines,
    line_signals,
    boundary_signal,
    pdf_v2_text_flow_matching_artifacts(
      artifacts,
      page.page_index,
      normalized_text,
    ),
    source_refs,
    reason_tags,
  )
}

///|
fn pdf_v2_text_flow_candidate_from_text(
  page : PdfV2PageModel,
  block : PdfV2BlockCandidate,
  text : String,
  line_indices : Array[Int],
  source_refs : Array[PdfV2SourceRef],
  boundary_signal : PdfV2BlockBoundarySignal,
  artifacts : Array[PdfV2PageArtifactCandidate],
  reason_tags : Array[String],
) -> PdfV2TextFlowCandidate {
  let signal = pdf_v2_build_line_text_signal(
    text,
    block.decode_confidence,
    source_refs,
    reason_tags,
  )
  pdf_v2_text_flow_candidate(
    page,
    block,
    line_indices,
    text,
    signal.normalized_text,
    [text],
    [signal.normalized_text],
    [signal],
    boundary_signal,
    pdf_v2_text_flow_matching_artifacts(
      artifacts,
      page.page_index,
      signal.normalized_text,
    ),
    source_refs,
    reason_tags,
  )
}

///|
fn pdf_v2_text_flow_candidate(
  page : PdfV2PageModel,
  block : PdfV2BlockCandidate,
  line_indices : Array[Int],
  text : String,
  normalized_text : String,
  original_lines : Array[String],
  normalized_lines : Array[String],
  line_signals : Array[PdfV2LineTextSignal],
  boundary_signal : PdfV2BlockBoundarySignal,
  artifact_refs : Array[PdfV2PageArtifactCandidate],
  source_refs : Array[PdfV2SourceRef],
  reason_tags : Array[String],
) -> PdfV2TextFlowCandidate {
  {
    page_index: Some(page.page_index),
    block_index: Some(block.block_index),
    flow_index: 0,
    line_indices,
    text,
    normalized_text,
    original_lines,
    normalized_lines,
    line_signals,
    boundary_signal,
    artifact_refs,
    source_refs,
    reason_tags: pdf_v2_text_flow_reason_tags(reason_tags, artifact_refs),
  }
}

///|
fn pdf_v2_text_flow_matching_artifacts(
  artifacts : Array[PdfV2PageArtifactCandidate],
  page_index : Int,
  normalized_text : String,
) -> Array[PdfV2PageArtifactCandidate] {
  let out : Array[PdfV2PageArtifactCandidate] = []
  let t = normalized_text.trim().to_owned()
  for artifact in artifacts {
    if artifact.normalized_text == t &&
      artifact.page_indices.contains(page_index) {
      out.push(artifact)
    }
  }
  out
}

///|
fn pdf_v2_text_flow_reason_tags(
  base : Array[String],
  artifacts : Array[PdfV2PageArtifactCandidate],
) -> Array[String] {
  let out : Array[String] = ["parser_owned_text_flow_candidate"]
  for tag in base {
    if !out.contains(tag) {
      out.push(tag)
    }
  }
  if artifacts.length() > 0 {
    out.push("page_artifact_fact_attached")
  }
  out
}

///|
fn pdf_v2_text_flow_ordered_blocks(
  blocks : Array[PdfV2BlockCandidate],
) -> Array[PdfV2BlockCandidate] {
  let ordered : Array[PdfV2BlockCandidate] = []
  ordered.append(blocks)
  ordered.sort_by(fn(a, b) { a.block_index - b.block_index })
  ordered
}

///|
fn pdf_v2_text_flow_ordered_lines(
  lines : Array[PdfV2LineCandidate],
) -> Array[PdfV2LineCandidate] {
  let ordered : Array[PdfV2LineCandidate] = []
  ordered.append(lines)
  ordered.sort_by(fn(a, b) { a.line_index - b.line_index })
  ordered
}
