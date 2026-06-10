///|
pub(all) enum PdfV2BlockKindHint {
  TextLike
  Unknown
  LowSignal
} derive(Eq)

///|
pub(all) struct PdfV2BlockCandidate {
  page_index : Int?
  block_index : Int
  text : String
  lines : Array[PdfV2LineCandidate]
  source_refs : Array[PdfV2SourceRef]
  decode_confidence : PdfV2TextDecodeConfidence
  geometry_confidence : PdfV2GeometryConfidence
  warnings : Array[PdfV2Warning]
  reason_tags : Array[String]
  merge_reason_tags : Array[String]
  break_reason_tags : Array[String]
  bbox : PdfV2BBox?
  writing_direction : PdfV2WritingDirection
  rotation : Double?
  block_kind_hint : PdfV2BlockKindHint
}

///|
pub(all) struct PdfV2BlockReconstructionOptions {
  max_blocks : Int
  max_lines_per_block : Int
  allow_source_order_merge : Bool
  allow_geometry_merge : Bool
  allow_vertical_gap_merge : Bool
}

///|
pub(all) struct PdfV2BlockReconstructionSummary {
  block_candidate_count : Int
  lines_grouped_count : Int
  block_break_count : Int
  block_geometry_missing_count : Int
  max_block_cap_hit : Bool
  warnings_count : Int
  risk_count : Int
}

///|
pub(all) struct PdfV2BlockReconstructionResult {
  blocks : Array[PdfV2BlockCandidate]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  summary : PdfV2BlockReconstructionSummary
}

///|
pub fn pdf_v2_default_block_reconstruction_options() -> PdfV2BlockReconstructionOptions {
  {
    max_blocks: 100000,
    max_lines_per_block: 128,
    allow_source_order_merge: true,
    allow_geometry_merge: false,
    allow_vertical_gap_merge: false,
  }
}

///|
fn pdf_v2_block_tags(
  first : Array[String],
  second : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  out.append(first)
  out.append(second)
  out
}

///|
fn pdf_v2_block_add_tag(tags : Array[String], tag : String) -> Array[String] {
  if tags.contains(tag) {
    tags
  } else {
    pdf_v2_block_tags(tags, [tag])
  }
}

///|
fn pdf_v2_effective_max_blocks(max_blocks : Int) -> Int {
  if max_blocks < 0 {
    0
  } else {
    max_blocks
  }
}

///|
fn pdf_v2_effective_max_lines_per_block(max_lines : Int) -> Int {
  if max_lines <= 0 {
    1
  } else {
    max_lines
  }
}

///|
fn pdf_v2_block_first_source_ref(line : PdfV2LineCandidate) -> PdfV2SourceRef? {
  if line.source_refs.length() == 0 {
    None
  } else {
    Some(line.source_refs[0])
  }
}

///|
fn pdf_v2_block_last_source_ref(line : PdfV2LineCandidate) -> PdfV2SourceRef? {
  if line.source_refs.length() == 0 {
    None
  } else {
    Some(line.source_refs[line.source_refs.length() - 1])
  }
}

///|
fn pdf_v2_block_source_order_compatible(
  left : PdfV2LineCandidate,
  right : PdfV2LineCandidate,
) -> Bool {
  let left_ref = pdf_v2_block_last_source_ref(left)
  let right_ref = pdf_v2_block_first_source_ref(right)
  match (left_ref, right_ref) {
    (Some(a), Some(b)) =>
      match (a.content_order_index, b.content_order_index) {
        (Some(x), Some(y)) => y > x
        _ =>
          a.page_index == b.page_index &&
          a.object_id == b.object_id &&
          a.stream_index == b.stream_index
      }
    _ => false
  }
}

///|
fn pdf_v2_block_bbox_overlaps_x(left : PdfV2BBox, right : PdfV2BBox) -> Bool {
  !(left.x1 < right.x0 || right.x1 < left.x0)
}

///|
fn pdf_v2_block_geometry_contradicts(
  left : PdfV2LineCandidate,
  right : PdfV2LineCandidate,
  options : PdfV2BlockReconstructionOptions,
) -> Bool {
  if options.allow_geometry_merge {
    return false
  }
  match (left.bbox, right.bbox) {
    (Some(a), Some(b)) => !pdf_v2_block_bbox_overlaps_x(a, b)
    _ => false
  }
}

///|
fn pdf_v2_block_has_line_break_tag(
  line : PdfV2LineCandidate,
  tag : String,
) -> Bool {
  line.break_reason_tags.contains(tag) || line.reason_tags.contains(tag)
}

///|
fn pdf_v2_block_has_hard_line_break(line : PdfV2LineCandidate) -> Bool {
  pdf_v2_block_has_line_break_tag(line, "source_ref_discontinuity") ||
  pdf_v2_block_has_line_break_tag(line, "failed_decode_boundary") ||
  pdf_v2_block_has_line_break_tag(line, "geometry_contradiction") ||
  pdf_v2_block_has_line_break_tag(line, "max_lines_cap")
}

///|
fn pdf_v2_block_break_reasons(
  current : Array[PdfV2LineCandidate],
  next : PdfV2LineCandidate,
  options : PdfV2BlockReconstructionOptions,
) -> Array[String] {
  if current.length() == 0 {
    return []
  }
  let last = current[current.length() - 1]
  let mut reasons : Array[String] = []
  if last.page_index != next.page_index {
    reasons = pdf_v2_block_add_tag(reasons, "page_change")
  }
  if pdf_v2_block_has_line_break_tag(last, "text_object_boundary") ||
    pdf_v2_block_has_line_break_tag(next, "text_object_boundary") {
    reasons = pdf_v2_block_add_tag(reasons, "text_object_boundary")
  }
  if pdf_v2_block_has_line_break_tag(last, "explicit_block_boundary") ||
    pdf_v2_block_has_line_break_tag(next, "explicit_block_boundary") {
    reasons = pdf_v2_block_add_tag(reasons, "explicit_block_boundary")
  }
  if !options.allow_source_order_merge ||
    !pdf_v2_block_source_order_compatible(last, next) {
    reasons = pdf_v2_block_add_tag(reasons, "source_ref_discontinuity")
  }
  if pdf_v2_block_has_hard_line_break(last) {
    reasons = pdf_v2_block_add_tag(reasons, "hard_line_break_boundary")
  }
  if last.decode_confidence == PdfV2TextDecodeConfidence::Failed ||
    next.decode_confidence == PdfV2TextDecodeConfidence::Failed {
    reasons = pdf_v2_block_add_tag(reasons, "failed_decode_boundary")
  }
  if pdf_v2_block_geometry_contradicts(last, next, options) {
    reasons = pdf_v2_block_add_tag(reasons, "geometry_contradiction")
  }
  if current.length() >=
    pdf_v2_effective_max_lines_per_block(options.max_lines_per_block) {
    reasons = pdf_v2_block_add_tag(reasons, "max_lines_per_block")
  }
  reasons
}

///|
fn pdf_v2_block_merge_reasons(
  lines : Array[PdfV2LineCandidate],
  options : PdfV2BlockReconstructionOptions,
) -> Array[String] {
  let mut reasons : Array[String] = []
  if lines.length() > 1 {
    if options.allow_source_order_merge {
      reasons = pdf_v2_block_add_tag(reasons, "source_order_merge")
      reasons = pdf_v2_block_add_tag(reasons, "compatible_source_order")
    }
    reasons = pdf_v2_block_add_tag(reasons, "same_page")
  }
  for line in lines {
    if pdf_v2_block_has_line_break_tag(line, "explicit_line_move") {
      reasons = pdf_v2_block_add_tag(reasons, "explicit_line_move_source_order")
    }
    if line.bbox is None {
      reasons = pdf_v2_block_add_tag(
        reasons, "geometry_unavailable_source_order",
      )
    }
  }
  if options.allow_vertical_gap_merge {
    reasons = pdf_v2_block_add_tag(reasons, "vertical_gap_merge_allowed")
  }
  reasons
}

///|
fn pdf_v2_block_text(lines : Array[PdfV2LineCandidate]) -> String {
  let parts : Array[String] = []
  for line in lines {
    parts.push(line.text)
  }
  parts.join("\n")
}

///|
fn pdf_v2_block_source_refs(
  lines : Array[PdfV2LineCandidate],
) -> Array[PdfV2SourceRef] {
  let refs : Array[PdfV2SourceRef] = []
  for line in lines {
    refs.append(line.source_refs)
  }
  refs
}

///|
fn pdf_v2_block_warning_source_refs(
  source_refs : Array[PdfV2SourceRef],
) -> Array[PdfV2SourceRef] {
  if source_refs.length() == 0 {
    [pdf_v2_document_source_ref()]
  } else {
    source_refs
  }
}

///|
fn pdf_v2_block_geometry_warning(
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::DecodeIssue,
    PdfV2Severity::Info,
    "PDF v2 block candidate geometry is unavailable",
    pdf_v2_block_warning_source_refs(source_refs),
    ["block_geometry_unavailable", "geometry_confidence_unknown"],
  )
}

///|
fn pdf_v2_block_cap_warning(
  source_ref : PdfV2SourceRef,
  max_blocks : Int,
) -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::PerformanceCap,
    PdfV2Severity::Warning,
    "PDF v2 block candidate reconstruction stopped at max_blocks=\{max_blocks}",
    [source_ref],
    [
      "max_blocks", "max_blocks_cap", "performance_cap", "block_reconstruction_cap",
    ],
  )
}

///|
fn pdf_v2_block_cap_risk(
  source_ref : PdfV2SourceRef,
  max_blocks : Int,
) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::PerformanceCapReached,
    severity: PdfV2Severity::Warning,
    message: "PDF v2 block candidate reconstruction stopped at max_blocks=\{max_blocks}",
    source_refs: [source_ref],
    reason_tags: [
      "max_blocks", "max_blocks_cap", "performance_cap", "block_reconstruction_cap",
    ],
  }
}

///|
fn pdf_v2_block_decode_risk(
  source_refs : Array[PdfV2SourceRef],
  reason_tags : Array[String],
) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::DecodeLowConfidence,
    severity: PdfV2Severity::Warning,
    message: "PDF v2 block candidate decode confidence is not reliable",
    source_refs: pdf_v2_block_warning_source_refs(source_refs),
    reason_tags,
  }
}

///|
fn pdf_v2_block_warnings(
  lines : Array[PdfV2LineCandidate],
  geometry_warning : PdfV2Warning,
) -> Array[PdfV2Warning] {
  let warnings : Array[PdfV2Warning] = []
  for line in lines {
    warnings.append(line.warnings)
  }
  warnings.push(geometry_warning)
  warnings
}

///|
fn pdf_v2_block_bbox(lines : Array[PdfV2LineCandidate]) -> PdfV2BBox? {
  if lines.length() == 0 {
    return None
  }
  let first_bbox = match lines[0].bbox {
    Some(value) => value
    None => return None
  }
  let mut x0 = first_bbox.x0
  let mut y0 = first_bbox.y0
  let mut x1 = first_bbox.x1
  let mut y1 = first_bbox.y1
  for index = 1; index < lines.length(); index = index + 1 {
    match lines[index].bbox {
      Some(value) => {
        if value.x0 < x0 {
          x0 = value.x0
        }
        if value.y0 < y0 {
          y0 = value.y0
        }
        if value.x1 > x1 {
          x1 = value.x1
        }
        if value.y1 > y1 {
          y1 = value.y1
        }
      }
      None => return None
    }
  }
  Some({ x0, y0, x1, y1 })
}

///|
fn pdf_v2_block_decode_confidence(
  lines : Array[PdfV2LineCandidate],
) -> PdfV2TextDecodeConfidence {
  if lines.length() == 0 {
    return PdfV2TextDecodeConfidence::Unknown
  }
  let mut confidence = lines[0].decode_confidence
  for index = 1; index < lines.length(); index = index + 1 {
    if confidence == PdfV2TextDecodeConfidence::Failed ||
      lines[index].decode_confidence == PdfV2TextDecodeConfidence::Failed {
      confidence = PdfV2TextDecodeConfidence::Failed
    } else if confidence == PdfV2TextDecodeConfidence::Unknown ||
      lines[index].decode_confidence == PdfV2TextDecodeConfidence::Unknown {
      confidence = PdfV2TextDecodeConfidence::Unknown
    } else if lines[index].decode_confidence != confidence {
      confidence = PdfV2TextDecodeConfidence::Low
    }
  }
  confidence
}

///|
fn pdf_v2_block_writing_direction(
  lines : Array[PdfV2LineCandidate],
) -> PdfV2WritingDirection {
  if lines.length() == 0 {
    return PdfV2WritingDirection::Unknown
  }
  let direction = lines[0].writing_direction
  for index = 1; index < lines.length(); index = index + 1 {
    if lines[index].writing_direction != direction {
      return PdfV2WritingDirection::Unknown
    }
  }
  direction
}

///|
fn pdf_v2_block_rotation(lines : Array[PdfV2LineCandidate]) -> Double? {
  if lines.length() == 0 {
    return None
  }
  let rotation = lines[0].rotation
  for index = 1; index < lines.length(); index = index + 1 {
    if lines[index].rotation != rotation {
      return None
    }
  }
  rotation
}

///|
fn pdf_v2_block_kind_hint(
  text : String,
  decode_confidence : PdfV2TextDecodeConfidence,
) -> PdfV2BlockKindHint {
  if text.length() == 0 {
    PdfV2BlockKindHint::LowSignal
  } else {
    match decode_confidence {
      Failed => PdfV2BlockKindHint::LowSignal
      Unknown => PdfV2BlockKindHint::Unknown
      _ => PdfV2BlockKindHint::TextLike
    }
  }
}

///|
fn pdf_v2_make_block_candidate(
  lines : Array[PdfV2LineCandidate],
  block_index : Int,
  options : PdfV2BlockReconstructionOptions,
  break_reason_tags : Array[String],
) -> PdfV2BlockCandidate {
  let source_refs = pdf_v2_block_source_refs(lines)
  let text = pdf_v2_block_text(lines)
  let bbox = pdf_v2_block_bbox(lines)
  let geometry_confidence = if bbox is None {
    PdfV2GeometryConfidence::Unknown
  } else {
    PdfV2GeometryConfidence::Low
  }
  let geometry_warning = pdf_v2_block_geometry_warning(source_refs)
  let merge_reason_tags = pdf_v2_block_merge_reasons(lines, options)
  let mut reason_tags = pdf_v2_block_tags(
    [
      "block_candidate", "source_order_block_candidate", "parser_owned_reconstruction",
    ],
    merge_reason_tags,
  )
  reason_tags = pdf_v2_block_tags(reason_tags, break_reason_tags)
  if bbox is None {
    reason_tags = pdf_v2_block_tags(reason_tags, ["block_geometry_unavailable"])
  }
  let decode_confidence = pdf_v2_block_decode_confidence(lines)
  {
    page_index: if lines.length() > 0 {
      lines[0].page_index
    } else {
      None
    },
    block_index,
    text,
    lines,
    source_refs,
    decode_confidence,
    geometry_confidence,
    warnings: pdf_v2_block_warnings(lines, geometry_warning),
    reason_tags,
    merge_reason_tags,
    break_reason_tags,
    bbox,
    writing_direction: pdf_v2_block_writing_direction(lines),
    rotation: pdf_v2_block_rotation(lines),
    block_kind_hint: pdf_v2_block_kind_hint(text, decode_confidence),
  }
}

///|
fn pdf_v2_block_lines_grouped(blocks : Array[PdfV2BlockCandidate]) -> Int {
  let mut count = 0
  for block in blocks {
    count = count + block.lines.length()
  }
  count
}

///|
fn pdf_v2_block_geometry_missing_count(
  blocks : Array[PdfV2BlockCandidate],
) -> Int {
  let mut count = 0
  for block in blocks {
    if block.bbox is None {
      count = count + 1
    }
  }
  count
}

///|
fn pdf_v2_block_result_summary(
  blocks : Array[PdfV2BlockCandidate],
  block_break_count : Int,
  max_block_cap_hit : Bool,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> PdfV2BlockReconstructionSummary {
  {
    block_candidate_count: blocks.length(),
    lines_grouped_count: pdf_v2_block_lines_grouped(blocks),
    block_break_count,
    block_geometry_missing_count: pdf_v2_block_geometry_missing_count(blocks),
    max_block_cap_hit,
    warnings_count: warnings.length(),
    risk_count: risks.length(),
  }
}

///|
fn pdf_v2_merge_block_reconstruction_summary(
  reconstruction_summary : PdfV2CharReconstructionSummary,
  block_summary : PdfV2BlockReconstructionSummary,
) -> PdfV2CharReconstructionSummary {
  {
    char_candidate_count: reconstruction_summary.char_candidate_count,
    decoded_char_count: reconstruction_summary.decoded_char_count,
    failed_char_count: reconstruction_summary.failed_char_count,
    unknown_decode_count: reconstruction_summary.unknown_decode_count,
    geometry_missing_count: reconstruction_summary.geometry_missing_count,
    font_cache_hits: reconstruction_summary.font_cache_hits,
    font_cache_misses: reconstruction_summary.font_cache_misses,
    span_candidate_count: reconstruction_summary.span_candidate_count,
    chars_grouped_count: reconstruction_summary.chars_grouped_count,
    span_break_count: reconstruction_summary.span_break_count,
    span_geometry_missing_count: reconstruction_summary.span_geometry_missing_count,
    max_span_cap_hit: reconstruction_summary.max_span_cap_hit,
    line_candidate_count: reconstruction_summary.line_candidate_count,
    spans_grouped_count: reconstruction_summary.spans_grouped_count,
    line_break_count: reconstruction_summary.line_break_count,
    line_geometry_missing_count: reconstruction_summary.line_geometry_missing_count,
    max_line_cap_hit: reconstruction_summary.max_line_cap_hit,
    block_candidate_count: block_summary.block_candidate_count,
    lines_grouped_count: block_summary.lines_grouped_count,
    block_break_count: block_summary.block_break_count,
    block_geometry_missing_count: block_summary.block_geometry_missing_count,
    max_block_cap_hit: block_summary.max_block_cap_hit,
    warnings_count: reconstruction_summary.warnings_count +
    block_summary.warnings_count,
    risk_count: reconstruction_summary.risk_count + block_summary.risk_count,
    max_chars: reconstruction_summary.max_chars,
    max_chars_hit: reconstruction_summary.max_chars_hit,
  }
}

///|
fn pdf_v2_block_first_source_or_document(
  line : PdfV2LineCandidate,
) -> PdfV2SourceRef {
  match pdf_v2_block_first_source_ref(line) {
    Some(value) => value
    None => pdf_v2_document_source_ref()
  }
}

///|
pub fn pdf_v2_reconstruct_block_candidates(
  lines : Array[PdfV2LineCandidate],
  options : PdfV2BlockReconstructionOptions,
) -> PdfV2BlockReconstructionResult {
  let blocks : Array[PdfV2BlockCandidate] = []
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  let mut current : Array[PdfV2LineCandidate] = []
  let mut block_break_count = 0
  let mut max_block_cap_hit = false
  let effective_max_blocks = pdf_v2_effective_max_blocks(options.max_blocks)

  for line in lines {
    if current.length() == 0 {
      current.push(line)
      continue
    }
    let break_reasons = pdf_v2_block_break_reasons(current, line, options)
    if break_reasons.length() == 0 {
      current.push(line)
    } else {
      if blocks.length() >= effective_max_blocks {
        max_block_cap_hit = true
        let source_ref = pdf_v2_block_first_source_or_document(line)
        warnings.push(
          pdf_v2_block_cap_warning(source_ref, effective_max_blocks),
        )
        risks.push(pdf_v2_block_cap_risk(source_ref, effective_max_blocks))
        current = []
        break
      }
      let block_break_reasons = if blocks.length() + 1 >= effective_max_blocks {
        pdf_v2_block_tags(break_reasons, ["max_blocks_cap"])
      } else {
        break_reasons
      }
      let block = pdf_v2_make_block_candidate(
        current,
        blocks.length(),
        options,
        block_break_reasons,
      )
      if block.decode_confidence == PdfV2TextDecodeConfidence::Failed ||
        block.decode_confidence == PdfV2TextDecodeConfidence::Unknown {
        risks.push(
          pdf_v2_block_decode_risk(block.source_refs, block.reason_tags),
        )
      }
      if block.bbox is None {
        warnings.push(pdf_v2_block_geometry_warning(block.source_refs))
      }
      blocks.push(block)
      block_break_count = block_break_count + 1
      current = [line]
      if blocks.length() >= effective_max_blocks {
        max_block_cap_hit = true
        let source_ref = pdf_v2_block_first_source_or_document(line)
        warnings.push(
          pdf_v2_block_cap_warning(source_ref, effective_max_blocks),
        )
        risks.push(pdf_v2_block_cap_risk(source_ref, effective_max_blocks))
        current = []
        break
      }
    }
  }

  if current.length() > 0 && !max_block_cap_hit {
    if blocks.length() >= effective_max_blocks {
      max_block_cap_hit = true
      let source_ref = pdf_v2_block_first_source_or_document(current[0])
      warnings.push(pdf_v2_block_cap_warning(source_ref, effective_max_blocks))
      risks.push(pdf_v2_block_cap_risk(source_ref, effective_max_blocks))
    } else {
      let block = pdf_v2_make_block_candidate(
        current,
        blocks.length(),
        options,
        [],
      )
      if block.decode_confidence == PdfV2TextDecodeConfidence::Failed ||
        block.decode_confidence == PdfV2TextDecodeConfidence::Unknown {
        risks.push(
          pdf_v2_block_decode_risk(block.source_refs, block.reason_tags),
        )
      }
      if block.bbox is None {
        warnings.push(pdf_v2_block_geometry_warning(block.source_refs))
      }
      blocks.push(block)
    }
  }

  {
    blocks,
    warnings,
    risks,
    summary: pdf_v2_block_result_summary(
      blocks, block_break_count, max_block_cap_hit, warnings, risks,
    ),
  }
}
