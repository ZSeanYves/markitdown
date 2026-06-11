///|
pub(all) enum PdfV2GeometryConfidence {
  High
  Medium
  Low
  Unknown
  Failed
} derive(Eq)

///|
pub(all) struct PdfV2CharCandidate {
  page_index : Int?
  char_index_in_show : Int
  raw_code : Int?
  raw_bytes : String
  unicode : String?
  text : String?
  glyph_name : String?
  font_ref : String?
  font_name : String?
  font_size : Double?
  advance_width : Double?
  position : PdfV2TextMatrix?
  bbox : PdfV2BBox?
  source_ref : PdfV2SourceRef
  decode_confidence : PdfV2TextDecodeConfidence
  geometry_confidence : PdfV2GeometryConfidence
  reason_tags : Array[String]
  warnings : Array[PdfV2Warning]
}

///|
pub(all) struct PdfV2CharReconstructionSummary {
  char_candidate_count : Int
  decoded_char_count : Int
  failed_char_count : Int
  unknown_decode_count : Int
  geometry_missing_count : Int
  font_cache_hits : Int
  font_cache_misses : Int
  span_candidate_count : Int
  chars_grouped_count : Int
  span_break_count : Int
  span_geometry_missing_count : Int
  max_span_cap_hit : Bool
  line_candidate_count : Int
  spans_grouped_count : Int
  line_break_count : Int
  line_geometry_missing_count : Int
  max_line_cap_hit : Bool
  block_candidate_count : Int
  lines_grouped_count : Int
  block_break_count : Int
  block_geometry_missing_count : Int
  max_block_cap_hit : Bool
  warnings_count : Int
  risk_count : Int
  max_chars : Int
  max_chars_hit : Bool
}

///|
pub(all) struct PdfV2CharReconstructionResult {
  char_candidates : Array[PdfV2CharCandidate]
  font_cache : PdfV2FontCache
  summary : PdfV2CharReconstructionSummary
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
}

///|
pub fn pdf_v2_default_max_char_candidates() -> Int {
  100000
}

///|
pub fn pdf_v2_empty_reconstruction_summary() -> PdfV2CharReconstructionSummary {
  {
    char_candidate_count: 0,
    decoded_char_count: 0,
    failed_char_count: 0,
    unknown_decode_count: 0,
    geometry_missing_count: 0,
    font_cache_hits: 0,
    font_cache_misses: 0,
    span_candidate_count: 0,
    chars_grouped_count: 0,
    span_break_count: 0,
    span_geometry_missing_count: 0,
    max_span_cap_hit: false,
    line_candidate_count: 0,
    spans_grouped_count: 0,
    line_break_count: 0,
    line_geometry_missing_count: 0,
    max_line_cap_hit: false,
    block_candidate_count: 0,
    lines_grouped_count: 0,
    block_break_count: 0,
    block_geometry_missing_count: 0,
    max_block_cap_hit: false,
    warnings_count: 0,
    risk_count: 0,
    max_chars: 0,
    max_chars_hit: false,
  }
}

///|
fn pdf_v2_reconstruction_tags(
  first : Array[String],
  second : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  out.append(first)
  out.append(second)
  out
}

///|
fn pdf_v2_reconstruction_add_tag(
  tags : Array[String],
  tag : String,
) -> Array[String] {
  if tags.contains(tag) {
    tags
  } else {
    pdf_v2_reconstruction_tags(tags, [tag])
  }
}

///|
fn pdf_v2_reconstruction_source_matches(
  text_show : PdfV2TextShowFact,
  glyph : PdfV2GlyphCandidateFact,
) -> Bool {
  text_show.source_ref.page_index == glyph.source_ref.page_index &&
  text_show.source_ref.object_id == glyph.source_ref.object_id &&
  text_show.source_ref.stream_index == glyph.source_ref.stream_index &&
  text_show.source_ref.op_index == glyph.source_ref.op_index
}

///|
fn pdf_v2_effective_max_chars(max_chars : Int) -> Int {
  if max_chars < 0 {
    0
  } else {
    max_chars
  }
}

///|
fn pdf_v2_char_geometry_warning(source_ref : PdfV2SourceRef) -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::DecodeIssue,
    PdfV2Severity::Info,
    "PDF v2 char candidate geometry is unavailable",
    [source_ref],
    ["glyph_geometry_unavailable", "geometry_confidence_unknown"],
  )
}

///|
fn pdf_v2_char_cap_warning(
  source_ref : PdfV2SourceRef,
  max_chars : Int,
) -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::PerformanceCap,
    PdfV2Severity::Warning,
    "PDF v2 char candidate reconstruction stopped at max_chars=\{max_chars}",
    [source_ref],
    ["max_chars", "performance_cap", "char_reconstruction_cap"],
  )
}

///|
fn pdf_v2_char_cap_risk(
  source_ref : PdfV2SourceRef,
  max_chars : Int,
) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::PerformanceCapReached,
    severity: PdfV2Severity::Warning,
    message: "PDF v2 char candidate reconstruction stopped at max_chars=\{max_chars}",
    source_refs: [source_ref],
    reason_tags: ["max_chars", "performance_cap", "char_reconstruction_cap"],
  }
}

///|
fn pdf_v2_char_decode_risk(
  source_ref : PdfV2SourceRef,
  reason_tags : Array[String],
) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::DecodeLowConfidence,
    severity: PdfV2Severity::Warning,
    message: "PDF v2 char candidate decode confidence is not reliable",
    source_refs: [source_ref],
    reason_tags,
  }
}

///|
fn pdf_v2_profile_for_font_key(
  font_cache : PdfV2FontCache,
  font_key : String,
) -> PdfV2DecodeProfile? {
  for profile in font_cache.decode_profiles {
    if pdf_v2_font_key(profile.font_ref, profile.font_name) == font_key {
      return Some(profile)
    }
  }
  None
}

///|
fn pdf_v2_candidate_warnings(
  show : PdfV2TextShowFact?,
  geometry_warning : PdfV2Warning,
) -> Array[PdfV2Warning] {
  let warnings : Array[PdfV2Warning] = []
  match show {
    Some(value) =>
      for warning in value.warnings {
        warnings.push(warning)
      }
    None => ()
  }
  warnings.push(geometry_warning)
  warnings
}

///|
fn pdf_v2_line_boundary_tags_from_event(
  event : PdfV2CoreEvent,
  emitted_candidate : Bool,
  pending_tags : Array[String],
) -> Array[String] {
  if !emitted_candidate {
    return pending_tags
  }
  let mut tags = pending_tags
  match event.kind {
    TextObjectBegin | TextObjectEnd =>
      tags = pdf_v2_reconstruction_add_tag(tags, "text_object_boundary")
    TextState =>
      if event.reason_tags.contains("operator_TStar") ||
        event.reason_tags.contains("operator_Td") ||
        event.reason_tags.contains("operator_TD") ||
        event.reason_tags.contains("operator_Tm") {
        tags = pdf_v2_reconstruction_add_tag(tags, "explicit_line_move")
      }
    _ => ()
  }
  tags
}

///|
fn pdf_v2_candidate_decode_confidence(
  glyph : PdfV2GlyphCandidateFact,
  sanitized_text : String?,
  sanitize_tags : Array[String],
) -> PdfV2TextDecodeConfidence {
  match glyph.decode_confidence {
    High | Medium =>
      if glyph.unicode_candidate is Some(_) && sanitized_text is None {
        PdfV2TextDecodeConfidence::Low
      } else if sanitize_tags.contains("control_byte_dropped") ||
        sanitize_tags.contains("nul_byte_dropped") ||
        sanitize_tags.contains("invalid_unicode_suppressed") {
        PdfV2TextDecodeConfidence::Low
      } else {
        glyph.decode_confidence
      }
    _ => glyph.decode_confidence
  }
}

///|
fn pdf_v2_candidate_geometry_confidence(
  glyph : PdfV2GlyphCandidateFact,
) -> PdfV2GeometryConfidence {
  if glyph.bbox is Some(_) && glyph.advance_width is Some(_) {
    PdfV2GeometryConfidence::Medium
  } else {
    PdfV2GeometryConfidence::Unknown
  }
}

///|
fn pdf_v2_candidate_position(
  glyph : PdfV2GlyphCandidateFact,
  geometry_confidence : PdfV2GeometryConfidence,
) -> PdfV2TextMatrix? {
  match geometry_confidence {
    High | Medium | Low => glyph.text_position
    Unknown | Failed => None
  }
}

///|
pub fn pdf_v2_reconstruct_char_candidates(
  events : Array[PdfV2CoreEvent],
  font_cache : PdfV2FontCache,
  max_chars : Int,
) -> PdfV2CharReconstructionResult {
  let effective_max = pdf_v2_effective_max_chars(max_chars)
  let candidates : Array[PdfV2CharCandidate] = []
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  let mut active_font_name : String? = None
  let mut current_show : PdfV2TextShowFact? = None
  let mut char_index = 0
  let mut decoded_count = 0
  let mut failed_count = 0
  let mut unknown_count = 0
  let mut geometry_missing_count = 0
  let mut max_hit = false
  let mut cap_source_ref : PdfV2SourceRef? = None
  let mut emitted_candidate = false
  let mut pending_line_boundary_tags : Array[String] = []

  for event in events {
    pending_line_boundary_tags = pdf_v2_line_boundary_tags_from_event(
      event, emitted_candidate, pending_line_boundary_tags,
    )
    match event.text_state {
      Some(fact) =>
        if event.kind == PdfV2CoreEventKind::FontUse {
          active_font_name = fact.font_name_or_ref
        }
      None => ()
    }
    match event.text_show {
      Some(fact) => {
        current_show = Some(fact)
        char_index = 0
      }
      None => ()
    }
    match event.glyph_candidate {
      Some(glyph) => {
        if candidates.length() >= effective_max {
          max_hit = true
          match cap_source_ref {
            Some(_) => ()
            None => cap_source_ref = Some(glyph.source_ref)
          }
          continue
        }
        let show = match current_show {
          Some(value) if pdf_v2_reconstruction_source_matches(value, glyph) =>
            Some(value)
          _ => None
        }
        let font_ref = match glyph.font_ref {
          Some(value) => Some(value)
          None =>
            match show {
              Some(value) => value.font_ref
              None => None
            }
        }
        let font_key = pdf_v2_font_key(font_ref, active_font_name)
        let profile = pdf_v2_profile_for_font_key(font_cache, font_key)
        let profile_tags = match profile {
          Some(value) => value.reason_tags
          None => ["font_cache_profile_missing"]
        }
        let show_tags = match show {
          Some(value) => value.reason_tags
          None => []
        }
        let mut reason_tags = pdf_v2_reconstruction_tags(
          show_tags,
          glyph.reason_tags,
        )
        reason_tags = pdf_v2_reconstruction_tags(reason_tags, profile_tags)
        reason_tags = pdf_v2_reconstruction_tags(reason_tags, [
          "char_candidate", "parser_owned_reconstruction",
        ])
        reason_tags = pdf_v2_reconstruction_tags(
          reason_tags, pending_line_boundary_tags,
        )
        pending_line_boundary_tags = []
        let geometry_confidence = pdf_v2_candidate_geometry_confidence(glyph)
        if geometry_confidence == PdfV2GeometryConfidence::Unknown {
          reason_tags = pdf_v2_reconstruction_tags(reason_tags, [
            "glyph_geometry_unavailable",
          ])
          geometry_missing_count = geometry_missing_count + 1
        }
        let geometry_warning = pdf_v2_char_geometry_warning(glyph.source_ref)
        let candidate_warnings = pdf_v2_candidate_warnings(
          show, geometry_warning,
        )
        warnings.push(geometry_warning)
        let (text, sanitize_tags, sanitize_warnings) = pdf_v2_sanitize_candidate_char_text(
          glyph.unicode_candidate,
          glyph.source_ref,
        )
        if sanitize_tags.length() > 0 {
          reason_tags = pdf_v2_reconstruction_tags(reason_tags, sanitize_tags)
          candidate_warnings.append(sanitize_warnings)
          warnings.append(sanitize_warnings)
        }
        let decode_confidence = pdf_v2_candidate_decode_confidence(
          glyph, text, sanitize_tags,
        )
        match glyph.decode_confidence {
          Failed => {
            failed_count = failed_count + 1
            risks.push(pdf_v2_char_decode_risk(glyph.source_ref, reason_tags))
          }
          Unknown => {
            unknown_count = unknown_count + 1
            risks.push(pdf_v2_char_decode_risk(glyph.source_ref, reason_tags))
          }
          _ => ()
        }
        match text {
          Some(_) => decoded_count = decoded_count + 1
          None => ()
        }
        let font_size = match show {
          Some(value) => value.font_size
          None => None
        }
        let candidate : PdfV2CharCandidate = {
          page_index: glyph.source_ref.page_index,
          char_index_in_show: char_index,
          raw_code: glyph.raw_code,
          raw_bytes: glyph.raw_bytes,
          unicode: glyph.unicode_candidate,
          text,
          glyph_name: glyph.glyph_name,
          font_ref,
          font_name: active_font_name,
          font_size,
          advance_width: glyph.advance_width,
          position: pdf_v2_candidate_position(glyph, geometry_confidence),
          bbox: glyph.bbox,
          source_ref: glyph.source_ref,
          decode_confidence,
          geometry_confidence,
          reason_tags,
          warnings: candidate_warnings,
        }
        candidates.push(candidate)
        emitted_candidate = true
        char_index = char_index + 1
      }
      None => ()
    }
  }

  if max_hit {
    let source_ref = match cap_source_ref {
      Some(value) => value
      None => pdf_v2_document_source_ref()
    }
    warnings.push(pdf_v2_char_cap_warning(source_ref, effective_max))
    risks.push(pdf_v2_char_cap_risk(source_ref, effective_max))
  }

  let summary : PdfV2CharReconstructionSummary = {
    char_candidate_count: candidates.length(),
    decoded_char_count: decoded_count,
    failed_char_count: failed_count,
    unknown_decode_count: unknown_count,
    geometry_missing_count,
    font_cache_hits: font_cache.cache_hits,
    font_cache_misses: font_cache.cache_misses,
    span_candidate_count: 0,
    chars_grouped_count: 0,
    span_break_count: 0,
    span_geometry_missing_count: 0,
    max_span_cap_hit: false,
    line_candidate_count: 0,
    spans_grouped_count: 0,
    line_break_count: 0,
    line_geometry_missing_count: 0,
    max_line_cap_hit: false,
    block_candidate_count: 0,
    lines_grouped_count: 0,
    block_break_count: 0,
    block_geometry_missing_count: 0,
    max_block_cap_hit: false,
    warnings_count: warnings.length(),
    risk_count: risks.length(),
    max_chars: effective_max,
    max_chars_hit: max_hit,
  }
  { char_candidates: candidates, font_cache, summary, warnings, risks }
}
