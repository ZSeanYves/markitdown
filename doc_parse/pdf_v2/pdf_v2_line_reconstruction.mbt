///|
pub(all) struct PdfV2LineCandidate {
  page_index : Int?
  line_index : Int
  text : String
  spans : Array[PdfV2SpanCandidate]
  source_refs : Array[PdfV2SourceRef]
  decode_confidence : PdfV2TextDecodeConfidence
  geometry_confidence : PdfV2GeometryConfidence
  warnings : Array[PdfV2Warning]
  reason_tags : Array[String]
  merge_reason_tags : Array[String]
  break_reason_tags : Array[String]
  bbox : PdfV2BBox?
  baseline : Double?
  writing_direction : PdfV2WritingDirection
  rotation : Double?
}

///|
pub(all) struct PdfV2LineReconstructionOptions {
  max_lines : Int
  max_spans_per_line : Int
  allow_source_order_merge : Bool
  allow_geometry_merge : Bool
}

///|
pub(all) struct PdfV2LineReconstructionSummary {
  line_candidate_count : Int
  spans_grouped_count : Int
  line_break_count : Int
  line_geometry_missing_count : Int
  max_line_cap_hit : Bool
  warnings_count : Int
  risk_count : Int
}

///|
pub(all) struct PdfV2LineReconstructionResult {
  lines : Array[PdfV2LineCandidate]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  summary : PdfV2LineReconstructionSummary
}

///|
pub fn pdf_v2_default_line_reconstruction_options() -> PdfV2LineReconstructionOptions {
  {
    max_lines: 100000,
    max_spans_per_line: 64,
    allow_source_order_merge: true,
    allow_geometry_merge: false,
  }
}

///|
fn pdf_v2_line_tags(
  first : Array[String],
  second : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  out.append(first)
  out.append(second)
  out
}

///|
fn pdf_v2_line_has_tag(tags : Array[String], tag : String) -> Bool {
  tags.contains(tag)
}

///|
fn pdf_v2_effective_max_lines(max_lines : Int) -> Int {
  if max_lines < 0 {
    0
  } else {
    max_lines
  }
}

///|
fn pdf_v2_effective_max_spans_per_line(max_spans : Int) -> Int {
  if max_spans <= 0 {
    1
  } else {
    max_spans
  }
}

///|
fn pdf_v2_line_first_source_ref(span : PdfV2SpanCandidate) -> PdfV2SourceRef? {
  if span.source_refs.length() == 0 {
    None
  } else {
    Some(span.source_refs[0])
  }
}

///|
fn pdf_v2_line_last_source_ref(span : PdfV2SpanCandidate) -> PdfV2SourceRef? {
  if span.source_refs.length() == 0 {
    None
  } else {
    Some(span.source_refs[span.source_refs.length() - 1])
  }
}

///|
fn pdf_v2_line_source_order_compatible(
  left : PdfV2SpanCandidate,
  right : PdfV2SpanCandidate,
) -> Bool {
  let left_ref = pdf_v2_line_last_source_ref(left)
  let right_ref = pdf_v2_line_first_source_ref(right)
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
fn pdf_v2_line_bbox_overlaps_y(left : PdfV2BBox, right : PdfV2BBox) -> Bool {
  !(left.y1 < right.y0 || right.y1 < left.y0)
}

///|
fn pdf_v2_line_geometry_contradicts(
  left : PdfV2SpanCandidate,
  right : PdfV2SpanCandidate,
  options : PdfV2LineReconstructionOptions,
) -> Bool {
  if options.allow_geometry_merge {
    return false
  }
  match (left.bbox, right.bbox) {
    (Some(a), Some(b)) => !pdf_v2_line_bbox_overlaps_y(a, b)
    _ => false
  }
}

///|
fn pdf_v2_line_break_reasons(
  current : Array[PdfV2SpanCandidate],
  next : PdfV2SpanCandidate,
  options : PdfV2LineReconstructionOptions,
) -> Array[String] {
  if current.length() == 0 {
    return []
  }
  let last = current[current.length() - 1]
  let reasons : Array[String] = []
  if last.page_index != next.page_index {
    reasons.push("page_change")
  }
  if pdf_v2_line_has_tag(last.break_reason_tags, "text_object_boundary") ||
    pdf_v2_line_has_tag(next.reason_tags, "text_object_boundary") {
    reasons.push("text_object_boundary")
  }
  if pdf_v2_line_has_tag(last.break_reason_tags, "explicit_line_move") ||
    pdf_v2_line_has_tag(next.reason_tags, "explicit_line_move") {
    reasons.push("explicit_line_move")
  }
  if !options.allow_source_order_merge ||
    !pdf_v2_line_source_order_compatible(last, next) {
    reasons.push("source_ref_discontinuity")
  }
  if last.decode_confidence == PdfV2TextDecodeConfidence::Failed ||
    next.decode_confidence == PdfV2TextDecodeConfidence::Failed {
    reasons.push("failed_decode_boundary")
  }
  if pdf_v2_line_geometry_contradicts(last, next, options) {
    reasons.push("geometry_contradiction")
  }
  if current.length() >=
    pdf_v2_effective_max_spans_per_line(options.max_spans_per_line) {
    reasons.push("max_spans_per_line")
  }
  reasons
}

///|
fn pdf_v2_line_merge_reasons(
  spans : Array[PdfV2SpanCandidate],
  options : PdfV2LineReconstructionOptions,
) -> Array[String] {
  let reasons : Array[String] = []
  if spans.length() > 1 {
    if options.allow_source_order_merge {
      reasons.push("source_order_merge")
      reasons.push("compatible_source_order")
    }
    reasons.push("same_page")
  }
  for span in spans {
    if span.bbox is None {
      reasons.push("geometry_unavailable_source_order")
      break
    }
  }
  reasons
}

///|
fn pdf_v2_line_text(spans : Array[PdfV2SpanCandidate]) -> String {
  let parts : Array[String] = []
  for span in spans {
    parts.push(span.text)
  }
  parts.join("")
}

///|
fn pdf_v2_line_source_refs(
  spans : Array[PdfV2SpanCandidate],
) -> Array[PdfV2SourceRef] {
  let refs : Array[PdfV2SourceRef] = []
  for span in spans {
    refs.append(span.source_refs)
  }
  refs
}

///|
fn pdf_v2_line_warning_source_refs(
  source_refs : Array[PdfV2SourceRef],
) -> Array[PdfV2SourceRef] {
  if source_refs.length() == 0 {
    [pdf_v2_document_source_ref()]
  } else {
    source_refs
  }
}

///|
fn pdf_v2_line_geometry_warning(
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::DecodeIssue,
    PdfV2Severity::Info,
    "PDF v2 line candidate geometry is unavailable",
    pdf_v2_line_warning_source_refs(source_refs),
    ["line_geometry_unavailable", "geometry_confidence_unknown"],
  )
}

///|
fn pdf_v2_line_cap_warning(
  source_ref : PdfV2SourceRef,
  max_lines : Int,
) -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::PerformanceCap,
    PdfV2Severity::Warning,
    "PDF v2 line candidate reconstruction stopped at max_lines=\{max_lines}",
    [source_ref],
    ["max_lines", "max_lines_cap", "performance_cap", "line_reconstruction_cap"],
  )
}

///|
fn pdf_v2_line_cap_risk(
  source_ref : PdfV2SourceRef,
  max_lines : Int,
) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::PerformanceCapReached,
    severity: PdfV2Severity::Warning,
    message: "PDF v2 line candidate reconstruction stopped at max_lines=\{max_lines}",
    source_refs: [source_ref],
    reason_tags: [
      "max_lines", "max_lines_cap", "performance_cap", "line_reconstruction_cap",
    ],
  }
}

///|
fn pdf_v2_line_decode_risk(
  source_refs : Array[PdfV2SourceRef],
  reason_tags : Array[String],
) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::DecodeLowConfidence,
    severity: PdfV2Severity::Warning,
    message: "PDF v2 line candidate decode confidence is not reliable",
    source_refs: pdf_v2_line_warning_source_refs(source_refs),
    reason_tags,
  }
}

///|
fn pdf_v2_line_warnings(
  spans : Array[PdfV2SpanCandidate],
  geometry_warning : PdfV2Warning,
) -> Array[PdfV2Warning] {
  let warnings : Array[PdfV2Warning] = []
  for span in spans {
    warnings.append(span.warnings)
  }
  warnings.push(geometry_warning)
  warnings
}

///|
fn pdf_v2_line_bbox(spans : Array[PdfV2SpanCandidate]) -> PdfV2BBox? {
  if spans.length() == 0 {
    return None
  }
  let first_bbox = match spans[0].bbox {
    Some(value) => value
    None => return None
  }
  let mut x0 = first_bbox.x0
  let mut y0 = first_bbox.y0
  let mut x1 = first_bbox.x1
  let mut y1 = first_bbox.y1
  for index = 1; index < spans.length(); index = index + 1 {
    match spans[index].bbox {
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
fn pdf_v2_line_decode_confidence(
  spans : Array[PdfV2SpanCandidate],
) -> PdfV2TextDecodeConfidence {
  if spans.length() == 0 {
    return PdfV2TextDecodeConfidence::Unknown
  }
  let mut confidence = spans[0].decode_confidence
  for index = 1; index < spans.length(); index = index + 1 {
    if confidence == PdfV2TextDecodeConfidence::Failed ||
      spans[index].decode_confidence == PdfV2TextDecodeConfidence::Failed {
      confidence = PdfV2TextDecodeConfidence::Failed
    } else if confidence == PdfV2TextDecodeConfidence::Unknown ||
      spans[index].decode_confidence == PdfV2TextDecodeConfidence::Unknown {
      confidence = PdfV2TextDecodeConfidence::Unknown
    } else if spans[index].decode_confidence != confidence {
      confidence = PdfV2TextDecodeConfidence::Low
    }
  }
  confidence
}

///|
fn pdf_v2_make_line_candidate(
  spans : Array[PdfV2SpanCandidate],
  line_index : Int,
  options : PdfV2LineReconstructionOptions,
  break_reason_tags : Array[String],
) -> PdfV2LineCandidate {
  let source_refs = pdf_v2_line_source_refs(spans)
  let bbox = pdf_v2_line_bbox(spans)
  let baseline : Double? = None
  let geometry_confidence = if bbox is None || baseline is None {
    PdfV2GeometryConfidence::Unknown
  } else {
    PdfV2GeometryConfidence::Low
  }
  let geometry_warning = pdf_v2_line_geometry_warning(source_refs)
  let merge_reason_tags = pdf_v2_line_merge_reasons(spans, options)
  let mut reason_tags = pdf_v2_line_tags(
    [
      "line_candidate", "source_order_line_candidate", "parser_owned_reconstruction",
    ],
    merge_reason_tags,
  )
  reason_tags = pdf_v2_line_tags(reason_tags, break_reason_tags)
  if bbox is None || baseline is None {
    reason_tags = pdf_v2_line_tags(reason_tags, ["line_geometry_unavailable"])
  }
  {
    page_index: if spans.length() > 0 {
      spans[0].page_index
    } else {
      None
    },
    line_index,
    text: pdf_v2_line_text(spans),
    spans,
    source_refs,
    decode_confidence: pdf_v2_line_decode_confidence(spans),
    geometry_confidence,
    warnings: pdf_v2_line_warnings(spans, geometry_warning),
    reason_tags,
    merge_reason_tags,
    break_reason_tags,
    bbox,
    baseline,
    writing_direction: PdfV2WritingDirection::Unknown,
    rotation: None,
  }
}

///|
fn pdf_v2_line_spans_grouped(lines : Array[PdfV2LineCandidate]) -> Int {
  let mut count = 0
  for line in lines {
    count = count + line.spans.length()
  }
  count
}

///|
fn pdf_v2_line_geometry_missing_count(lines : Array[PdfV2LineCandidate]) -> Int {
  let mut count = 0
  for line in lines {
    if line.bbox is None || line.baseline is None {
      count = count + 1
    }
  }
  count
}

///|
fn pdf_v2_line_result_summary(
  lines : Array[PdfV2LineCandidate],
  line_break_count : Int,
  max_line_cap_hit : Bool,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> PdfV2LineReconstructionSummary {
  {
    line_candidate_count: lines.length(),
    spans_grouped_count: pdf_v2_line_spans_grouped(lines),
    line_break_count,
    line_geometry_missing_count: pdf_v2_line_geometry_missing_count(lines),
    max_line_cap_hit,
    warnings_count: warnings.length(),
    risk_count: risks.length(),
  }
}

///|
fn pdf_v2_merge_line_reconstruction_summary(
  reconstruction_summary : PdfV2CharReconstructionSummary,
  line_summary : PdfV2LineReconstructionSummary,
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
    line_candidate_count: line_summary.line_candidate_count,
    spans_grouped_count: line_summary.spans_grouped_count,
    line_break_count: line_summary.line_break_count,
    line_geometry_missing_count: line_summary.line_geometry_missing_count,
    max_line_cap_hit: line_summary.max_line_cap_hit,
    warnings_count: reconstruction_summary.warnings_count +
    line_summary.warnings_count,
    risk_count: reconstruction_summary.risk_count + line_summary.risk_count,
    max_chars: reconstruction_summary.max_chars,
    max_chars_hit: reconstruction_summary.max_chars_hit,
  }
}

///|
fn pdf_v2_line_first_source_or_document(
  span : PdfV2SpanCandidate,
) -> PdfV2SourceRef {
  match pdf_v2_line_first_source_ref(span) {
    Some(value) => value
    None => pdf_v2_document_source_ref()
  }
}

///|
pub fn pdf_v2_reconstruct_line_candidates(
  spans : Array[PdfV2SpanCandidate],
  options : PdfV2LineReconstructionOptions,
) -> PdfV2LineReconstructionResult {
  let lines : Array[PdfV2LineCandidate] = []
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  let mut current : Array[PdfV2SpanCandidate] = []
  let mut line_break_count = 0
  let mut max_line_cap_hit = false
  let effective_max_lines = pdf_v2_effective_max_lines(options.max_lines)

  for span in spans {
    if current.length() == 0 {
      current.push(span)
      continue
    }
    let break_reasons = pdf_v2_line_break_reasons(current, span, options)
    if break_reasons.length() == 0 {
      current.push(span)
    } else {
      if lines.length() >= effective_max_lines {
        max_line_cap_hit = true
        let source_ref = pdf_v2_line_first_source_or_document(span)
        warnings.push(pdf_v2_line_cap_warning(source_ref, effective_max_lines))
        risks.push(pdf_v2_line_cap_risk(source_ref, effective_max_lines))
        current = []
        break
      }
      let line_break_reasons = if lines.length() + 1 >= effective_max_lines {
        pdf_v2_line_tags(break_reasons, ["max_lines_cap"])
      } else {
        break_reasons
      }
      let line = pdf_v2_make_line_candidate(
        current,
        lines.length(),
        options,
        line_break_reasons,
      )
      if line.decode_confidence == PdfV2TextDecodeConfidence::Failed ||
        line.decode_confidence == PdfV2TextDecodeConfidence::Unknown {
        risks.push(pdf_v2_line_decode_risk(line.source_refs, line.reason_tags))
      }
      if line.bbox is None || line.baseline is None {
        warnings.push(pdf_v2_line_geometry_warning(line.source_refs))
      }
      lines.push(line)
      line_break_count = line_break_count + 1
      current = [span]
      if lines.length() >= effective_max_lines {
        max_line_cap_hit = true
        let source_ref = pdf_v2_line_first_source_or_document(span)
        warnings.push(pdf_v2_line_cap_warning(source_ref, effective_max_lines))
        risks.push(pdf_v2_line_cap_risk(source_ref, effective_max_lines))
        current = []
        break
      }
    }
  }

  if current.length() > 0 && !max_line_cap_hit {
    if lines.length() >= effective_max_lines {
      max_line_cap_hit = true
      let source_ref = pdf_v2_line_first_source_or_document(current[0])
      warnings.push(pdf_v2_line_cap_warning(source_ref, effective_max_lines))
      risks.push(pdf_v2_line_cap_risk(source_ref, effective_max_lines))
    } else {
      let line = pdf_v2_make_line_candidate(current, lines.length(), options, [])
      if line.decode_confidence == PdfV2TextDecodeConfidence::Failed ||
        line.decode_confidence == PdfV2TextDecodeConfidence::Unknown {
        risks.push(pdf_v2_line_decode_risk(line.source_refs, line.reason_tags))
      }
      if line.bbox is None || line.baseline is None {
        warnings.push(pdf_v2_line_geometry_warning(line.source_refs))
      }
      lines.push(line)
    }
  }

  {
    lines,
    warnings,
    risks,
    summary: pdf_v2_line_result_summary(
      lines, line_break_count, max_line_cap_hit, warnings, risks,
    ),
  }
}
