///|
pub(all) struct PdfV2SpanCandidate {
  page_index : Int?
  span_index : Int
  text : String
  chars : Array[PdfV2CharCandidate]
  font_ref : String?
  font_name : String?
  font_size : Double?
  decode_confidence : PdfV2TextDecodeConfidence
  geometry_confidence : PdfV2GeometryConfidence
  source_refs : Array[PdfV2SourceRef]
  warnings : Array[PdfV2Warning]
  reason_tags : Array[String]
  merge_reason_tags : Array[String]
  break_reason_tags : Array[String]
  bbox : PdfV2BBox?
}

///|
pub(all) struct PdfV2SpanReconstructionOptions {
  max_spans : Int
  max_chars_per_span : Int
  allow_tj_spacing_merge : Bool
}

///|
pub(all) struct PdfV2SpanReconstructionSummary {
  span_candidate_count : Int
  chars_grouped_count : Int
  span_break_count : Int
  span_geometry_missing_count : Int
  max_span_cap_hit : Bool
  warnings_count : Int
  risk_count : Int
}

///|
pub(all) struct PdfV2SpanReconstructionResult {
  spans : Array[PdfV2SpanCandidate]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  summary : PdfV2SpanReconstructionSummary
}

///|
pub fn pdf_v2_default_span_reconstruction_options() -> PdfV2SpanReconstructionOptions {
  { max_spans: 100000, max_chars_per_span: 256, allow_tj_spacing_merge: false }
}

///|
fn pdf_v2_span_tags(
  first : Array[String],
  second : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  out.append(first)
  out.append(second)
  out
}

///|
fn pdf_v2_span_option_string_eq(a : String?, b : String?) -> Bool {
  match (a, b) {
    (Some(x), Some(y)) => x == y
    (None, None) => true
    _ => false
  }
}

///|
fn pdf_v2_span_option_double_eq(a : Double?, b : Double?) -> Bool {
  match (a, b) {
    (Some(x), Some(y)) => x == y
    (None, None) => true
    _ => false
  }
}

///|
fn pdf_v2_same_text_show_source(
  left : PdfV2SourceRef,
  right : PdfV2SourceRef,
) -> Bool {
  left.page_index == right.page_index &&
  left.object_id == right.object_id &&
  left.stream_index == right.stream_index &&
  left.op_index == right.op_index
}

///|
fn pdf_v2_span_has_tag(tags : Array[String], tag : String) -> Bool {
  tags.contains(tag)
}

///|
fn pdf_v2_char_has_tj_spacing_boundary(ch : PdfV2CharCandidate) -> Bool {
  pdf_v2_span_has_tag(ch.reason_tags, "spacing_adjustment_present")
}

///|
fn pdf_v2_effective_max_spans(max_spans : Int) -> Int {
  if max_spans < 0 {
    0
  } else {
    max_spans
  }
}

///|
fn pdf_v2_effective_max_chars_per_span(max_chars : Int) -> Int {
  if max_chars <= 0 {
    1
  } else {
    max_chars
  }
}

///|
fn pdf_v2_span_geometry_warning(
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::DecodeIssue,
    PdfV2Severity::Info,
    "PDF v2 span candidate geometry is unavailable",
    source_refs,
    ["span_geometry_unavailable", "geometry_confidence_unknown"],
  )
}

///|
fn pdf_v2_span_cap_warning(
  source_ref : PdfV2SourceRef,
  max_spans : Int,
) -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::PerformanceCap,
    PdfV2Severity::Warning,
    "PDF v2 span candidate reconstruction stopped at max_spans=\{max_spans}",
    [source_ref],
    ["max_spans", "performance_cap", "span_reconstruction_cap"],
  )
}

///|
fn pdf_v2_span_cap_risk(
  source_ref : PdfV2SourceRef,
  max_spans : Int,
) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::PerformanceCapReached,
    severity: PdfV2Severity::Warning,
    message: "PDF v2 span candidate reconstruction stopped at max_spans=\{max_spans}",
    source_refs: [source_ref],
    reason_tags: ["max_spans", "performance_cap", "span_reconstruction_cap"],
  }
}

///|
fn pdf_v2_span_decode_risk(
  source_refs : Array[PdfV2SourceRef],
  reason_tags : Array[String],
) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::DecodeLowConfidence,
    severity: PdfV2Severity::Warning,
    message: "PDF v2 span candidate decode confidence is not reliable",
    source_refs,
    reason_tags,
  }
}

///|
fn pdf_v2_span_break_reasons(
  current : Array[PdfV2CharCandidate],
  next : PdfV2CharCandidate,
  options : PdfV2SpanReconstructionOptions,
) -> Array[String] {
  if current.length() == 0 {
    return []
  }
  let last = current[current.length() - 1]
  let reasons : Array[String] = []
  if last.page_index != next.page_index {
    reasons.push("page_change")
  }
  if !pdf_v2_same_text_show_source(last.source_ref, next.source_ref) {
    reasons.push("source_ref_change")
  }
  if !pdf_v2_span_option_string_eq(last.font_ref, next.font_ref) ||
    !pdf_v2_span_option_string_eq(last.font_name, next.font_name) ||
    !pdf_v2_span_option_double_eq(last.font_size, next.font_size) {
    reasons.push("font_change")
  }
  if last.decode_confidence == PdfV2TextDecodeConfidence::Failed ||
    next.decode_confidence == PdfV2TextDecodeConfidence::Failed {
    reasons.push("failed_decode_boundary")
  } else if last.decode_confidence != next.decode_confidence {
    reasons.push("confidence_change")
  }
  if last.geometry_confidence != next.geometry_confidence {
    reasons.push("geometry_confidence_change")
  }
  if current.length() >=
    pdf_v2_effective_max_chars_per_span(options.max_chars_per_span) {
    reasons.push("max_chars_per_span")
  }
  if !options.allow_tj_spacing_merge &&
    (
      pdf_v2_char_has_tj_spacing_boundary(last) ||
      pdf_v2_char_has_tj_spacing_boundary(next)
    ) {
    reasons.push("tj_spacing_boundary")
  }
  reasons
}

///|
fn pdf_v2_span_merge_reasons(
  chars : Array[PdfV2CharCandidate],
  options : PdfV2SpanReconstructionOptions,
) -> Array[String] {
  let reasons : Array[String] = []
  if chars.length() > 1 {
    reasons.push("same_font")
    reasons.push("same_text_show")
    reasons.push("same_decode_confidence")
    reasons.push("same_geometry_confidence")
  }
  if options.allow_tj_spacing_merge {
    for ch in chars {
      if pdf_v2_char_has_tj_spacing_boundary(ch) {
        reasons.push("tj_spacing_boundary")
        break
      }
    }
  }
  reasons
}

///|
fn pdf_v2_span_text(chars : Array[PdfV2CharCandidate]) -> String {
  let parts : Array[String] = []
  for ch in chars {
    match ch.text {
      Some(value) => parts.push(value)
      None => parts.push(ch.raw_bytes)
    }
  }
  parts.join("")
}

///|
fn pdf_v2_span_source_refs(
  chars : Array[PdfV2CharCandidate],
) -> Array[PdfV2SourceRef] {
  let refs : Array[PdfV2SourceRef] = []
  for ch in chars {
    refs.push(ch.source_ref)
  }
  refs
}

///|
fn pdf_v2_span_warnings(
  chars : Array[PdfV2CharCandidate],
  geometry_warning : PdfV2Warning,
) -> Array[PdfV2Warning] {
  let warnings : Array[PdfV2Warning] = []
  for ch in chars {
    for warning in ch.warnings {
      warnings.push(warning)
    }
  }
  warnings.push(geometry_warning)
  warnings
}

///|
fn pdf_v2_span_bbox(chars : Array[PdfV2CharCandidate]) -> PdfV2BBox? {
  if chars.length() == 0 {
    return None
  }
  let first_bbox = match chars[0].bbox {
    Some(value) => value
    None => return None
  }
  let mut x0 = first_bbox.x0
  let mut y0 = first_bbox.y0
  let mut x1 = first_bbox.x1
  let mut y1 = first_bbox.y1
  for index = 1; index < chars.length(); index = index + 1 {
    match chars[index].bbox {
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
fn pdf_v2_span_geometry_confidence(
  chars : Array[PdfV2CharCandidate],
  bbox : PdfV2BBox?,
) -> PdfV2GeometryConfidence {
  if bbox is None {
    PdfV2GeometryConfidence::Unknown
  } else if chars.length() == 0 {
    PdfV2GeometryConfidence::Unknown
  } else {
    chars[0].geometry_confidence
  }
}

///|
fn pdf_v2_span_decode_confidence(
  chars : Array[PdfV2CharCandidate],
) -> PdfV2TextDecodeConfidence {
  if chars.length() == 0 {
    return PdfV2TextDecodeConfidence::Unknown
  }
  let mut confidence = chars[0].decode_confidence
  for index = 1; index < chars.length(); index = index + 1 {
    if chars[index].decode_confidence != confidence {
      confidence = PdfV2TextDecodeConfidence::Low
    }
    if chars[index].decode_confidence == PdfV2TextDecodeConfidence::Failed ||
      confidence == PdfV2TextDecodeConfidence::Failed {
      confidence = PdfV2TextDecodeConfidence::Failed
    }
  }
  confidence
}

///|
fn pdf_v2_make_span_candidate(
  chars : Array[PdfV2CharCandidate],
  span_index : Int,
  options : PdfV2SpanReconstructionOptions,
  break_reason_tags : Array[String],
) -> PdfV2SpanCandidate {
  let source_refs = pdf_v2_span_source_refs(chars)
  let bbox = pdf_v2_span_bbox(chars)
  let geometry_confidence = pdf_v2_span_geometry_confidence(chars, bbox)
  let geometry_warning = pdf_v2_span_geometry_warning(source_refs)
  let merge_reason_tags = pdf_v2_span_merge_reasons(chars, options)
  let mut reason_tags = pdf_v2_span_tags(
    ["span_candidate", "parser_owned_reconstruction"],
    merge_reason_tags,
  )
  reason_tags = pdf_v2_span_tags(reason_tags, break_reason_tags)
  if bbox is None {
    reason_tags = pdf_v2_span_tags(reason_tags, ["span_geometry_unavailable"])
  }
  {
    page_index: if chars.length() > 0 {
      chars[0].page_index
    } else {
      None
    },
    span_index,
    text: pdf_v2_span_text(chars),
    chars,
    font_ref: if chars.length() > 0 {
      chars[0].font_ref
    } else {
      None
    },
    font_name: if chars.length() > 0 {
      chars[0].font_name
    } else {
      None
    },
    font_size: if chars.length() > 0 {
      chars[0].font_size
    } else {
      None
    },
    decode_confidence: pdf_v2_span_decode_confidence(chars),
    geometry_confidence,
    source_refs,
    warnings: pdf_v2_span_warnings(chars, geometry_warning),
    reason_tags,
    merge_reason_tags,
    break_reason_tags,
    bbox,
  }
}

///|
fn pdf_v2_span_chars_grouped(spans : Array[PdfV2SpanCandidate]) -> Int {
  let mut count = 0
  for span in spans {
    count = count + span.chars.length()
  }
  count
}

///|
fn pdf_v2_span_geometry_missing_count(spans : Array[PdfV2SpanCandidate]) -> Int {
  let mut count = 0
  for span in spans {
    if span.bbox is None {
      count = count + 1
    }
  }
  count
}

///|
fn pdf_v2_span_result_summary(
  spans : Array[PdfV2SpanCandidate],
  span_break_count : Int,
  max_span_cap_hit : Bool,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> PdfV2SpanReconstructionSummary {
  {
    span_candidate_count: spans.length(),
    chars_grouped_count: pdf_v2_span_chars_grouped(spans),
    span_break_count,
    span_geometry_missing_count: pdf_v2_span_geometry_missing_count(spans),
    max_span_cap_hit,
    warnings_count: warnings.length(),
    risk_count: risks.length(),
  }
}

///|
fn pdf_v2_merge_reconstruction_summaries(
  char_summary : PdfV2CharReconstructionSummary,
  span_summary : PdfV2SpanReconstructionSummary,
) -> PdfV2CharReconstructionSummary {
  {
    char_candidate_count: char_summary.char_candidate_count,
    decoded_char_count: char_summary.decoded_char_count,
    failed_char_count: char_summary.failed_char_count,
    unknown_decode_count: char_summary.unknown_decode_count,
    geometry_missing_count: char_summary.geometry_missing_count,
    font_cache_hits: char_summary.font_cache_hits,
    font_cache_misses: char_summary.font_cache_misses,
    span_candidate_count: span_summary.span_candidate_count,
    chars_grouped_count: span_summary.chars_grouped_count,
    span_break_count: span_summary.span_break_count,
    span_geometry_missing_count: span_summary.span_geometry_missing_count,
    max_span_cap_hit: span_summary.max_span_cap_hit,
    warnings_count: char_summary.warnings_count + span_summary.warnings_count,
    risk_count: char_summary.risk_count + span_summary.risk_count,
    max_chars: char_summary.max_chars,
    max_chars_hit: char_summary.max_chars_hit,
  }
}

///|
pub fn pdf_v2_reconstruct_span_candidates(
  chars : Array[PdfV2CharCandidate],
  options : PdfV2SpanReconstructionOptions,
) -> PdfV2SpanReconstructionResult {
  let spans : Array[PdfV2SpanCandidate] = []
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  let mut current : Array[PdfV2CharCandidate] = []
  let mut span_break_count = 0
  let mut max_span_cap_hit = false
  let effective_max_spans = pdf_v2_effective_max_spans(options.max_spans)

  for ch in chars {
    if current.length() == 0 {
      current.push(ch)
      continue
    }
    let break_reasons = pdf_v2_span_break_reasons(current, ch, options)
    if break_reasons.length() == 0 {
      current.push(ch)
    } else {
      if spans.length() >= effective_max_spans {
        max_span_cap_hit = true
        risks.push(pdf_v2_span_cap_risk(ch.source_ref, effective_max_spans))
        warnings.push(
          pdf_v2_span_cap_warning(ch.source_ref, effective_max_spans),
        )
        current = []
        break
      }
      let span = pdf_v2_make_span_candidate(
        current,
        spans.length(),
        options,
        break_reasons,
      )
      if span.decode_confidence == PdfV2TextDecodeConfidence::Failed ||
        span.decode_confidence == PdfV2TextDecodeConfidence::Unknown {
        risks.push(pdf_v2_span_decode_risk(span.source_refs, span.reason_tags))
      }
      if span.bbox is None {
        warnings.push(pdf_v2_span_geometry_warning(span.source_refs))
      }
      spans.push(span)
      span_break_count = span_break_count + 1
      current = [ch]
    }
  }

  if current.length() > 0 && !max_span_cap_hit {
    if spans.length() >= effective_max_spans {
      max_span_cap_hit = true
      let source_ref = current[0].source_ref
      risks.push(pdf_v2_span_cap_risk(source_ref, effective_max_spans))
      warnings.push(pdf_v2_span_cap_warning(source_ref, effective_max_spans))
    } else {
      let span = pdf_v2_make_span_candidate(current, spans.length(), options, [])
      if span.decode_confidence == PdfV2TextDecodeConfidence::Failed ||
        span.decode_confidence == PdfV2TextDecodeConfidence::Unknown {
        risks.push(pdf_v2_span_decode_risk(span.source_refs, span.reason_tags))
      }
      if span.bbox is None {
        warnings.push(pdf_v2_span_geometry_warning(span.source_refs))
      }
      spans.push(span)
    }
  }

  {
    spans,
    warnings,
    risks,
    summary: pdf_v2_span_result_summary(
      spans, span_break_count, max_span_cap_hit, warnings, risks,
    ),
  }
}
