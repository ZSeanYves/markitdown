///|
pub(all) enum PdfV2DecodeConfidence {
  High
  Medium
  Low
  Failed
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2TextRiskKind {
  MissingToUnicode
  UnknownFontEncoding
  GlyphDecodeLowConfidence
  LigatureExpansionRisk
  CompatibilityGlyphRisk
  WritingDirectionUnknown
  BboxMissingOrInvalid
  ContentOrderGap
  LineGroupingUncertain
  BlockGroupingUncertain
  LowSignalTextPage
} derive(Eq)

///|
pub(all) struct PdfV2TextRisk {
  kind : PdfV2TextRiskKind
  risk : @pdfv2.PdfV2Risk
}

///|
pub(all) struct PdfV2TextReconstructionOptions {
  fail_closed : Bool
  emit_empty_source_warning : Bool
  synthesize_single_block_per_text_event : Bool
}

///|
pub(all) struct PdfV2TextReconstructionSummary {
  page_count : Int
  glyph_count : Int
  char_count : Int
  span_count : Int
  line_count : Int
  block_count : Int
  low_confidence_count : Int
  failed_decode_count : Int
  warning_count : Int
  risk_count : Int
  source_event_count : Int
  source_diagnostic_event_count : Int
  scanned_once : Bool
  one_pass_required : Bool
  legacy_fallback_allowed : Bool
  convert_raw_reparse_allowed : Bool
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2FontStyle {
  font_name : String?
  font_family : String?
  font_size : Double?
  style_flags : Array[String]
  fill_color : @pdfv2.PdfV2Color?
  stroke_color : @pdfv2.PdfV2Color?
}

///|
pub(all) struct PdfV2Glyph {
  text : String
  raw_bytes : Bytes?
  decoded_unicode : String?
  bbox : @pdfv2.PdfV2Rect
  origin : @pdfv2.PdfV2Point
  quad : @pdfv2.PdfV2Quad?
  advance_width : Double?
  glyph_width : Double?
  font : PdfV2FontStyle
  rotation : Int
  writing_direction : @pdfv2.PdfV2WritingDirection
  page_index : Int
  object_ref : String?
  content_order_index : Int?
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  decode_confidence : PdfV2DecodeConfidence
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2Char {
  text : String
  bbox : @pdfv2.PdfV2Rect
  origin : @pdfv2.PdfV2Point
  quad : @pdfv2.PdfV2Quad?
  font : PdfV2FontStyle
  rotation : Int
  writing_direction : @pdfv2.PdfV2WritingDirection
  page_index : Int
  object_ref : String?
  content_order_index : Int?
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  decode_confidence : PdfV2DecodeConfidence
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2Span {
  id : String
  text : String
  bbox : @pdfv2.PdfV2Rect
  chars : Array[PdfV2Char]
  font : PdfV2FontStyle
  rotation : Int
  writing_direction : @pdfv2.PdfV2WritingDirection
  page_index : Int
  object_refs : Array[String]
  content_order_start : Int?
  content_order_end : Int?
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  decode_confidence : PdfV2DecodeConfidence
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2Line {
  id : String
  text : String
  bbox : @pdfv2.PdfV2Rect
  spans : Array[PdfV2Span]
  baseline_y : Double?
  line_height : Double?
  indent_left : Double?
  indent_right : Double?
  gap_before : Double?
  gap_after : Double?
  dominant_font : String?
  dominant_font_size : Double?
  writing_direction : @pdfv2.PdfV2WritingDirection
  page_index : Int
  object_refs : Array[String]
  content_order_start : Int?
  content_order_end : Int?
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  decode_confidence : PdfV2DecodeConfidence
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) enum PdfV2TextCandidateFactKind {
  ListMarkerCandidate
  CaptionPrefixCandidate
  HeadingShapeCandidate
  TableCellShapeCandidate
  PageNumberShapeCandidate
  HeaderFooterPositionCandidate
  WrappedLineCandidate
  SameParagraphCandidate
} derive(Eq)

///|
pub(all) struct PdfV2TextCandidateFact {
  kind : PdfV2TextCandidateFactKind
  text : String
  confidence : Double
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2ListMarkerCandidate {
  marker_text : String
  confidence : Double
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2CaptionPrefixCandidate {
  prefix_text : String
  confidence : Double
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2HeadingShapeCandidate {
  text : String
  font_size_delta : Double?
  confidence : Double
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2TextBlock {
  id : String
  text : String
  bbox : @pdfv2.PdfV2Rect
  lines : Array[PdfV2Line]
  dominant_font : String?
  dominant_font_size : Double?
  writing_direction : @pdfv2.PdfV2WritingDirection
  page_index : Int
  object_refs : Array[String]
  content_order_start : Int?
  content_order_end : Int?
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  decode_confidence : PdfV2DecodeConfidence
  candidate_facts : Array[PdfV2TextCandidateFact]
  list_marker_candidates : Array[PdfV2ListMarkerCandidate]
  caption_prefix_candidates : Array[PdfV2CaptionPrefixCandidate]
  heading_shape_candidates : Array[PdfV2HeadingShapeCandidate]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2TextPage {
  page_index : Int
  blocks : Array[PdfV2TextBlock]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
}

///|
pub(all) struct PdfV2TextModel {
  summary : PdfV2TextReconstructionSummary
  pages : Array[PdfV2TextPage]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
}

///|
pub fn default_pdf_v2_text_reconstruction_options() -> PdfV2TextReconstructionOptions {
  {
    fail_closed: true,
    emit_empty_source_warning: true,
    synthesize_single_block_per_text_event: true,
  }
}

///|
pub fn build_pdf_v2_text_model_from_source(
  source : @source_event.PdfV2SourceDocument,
  options : PdfV2TextReconstructionOptions,
) -> PdfV2TextModel {
  let pages : Array[PdfV2TextPage] = []
  let warnings = source.warnings
  let risks = source.risks
  let mut glyph_count = 0
  let mut char_count = 0
  let mut span_count = 0
  let mut line_count = 0
  let mut block_count = 0
  let mut low_confidence_count = 0
  let mut failed_decode_count = 0
  for source_page in source.pages {
    let page_blocks : Array[PdfV2TextBlock] = []
    let page_warnings = source_page.warnings
    let page_risks = source_page.risks
    for event in source_page.events {
      match event.text_payload {
        Some(payload) => {
          let block = block_from_payload(event, payload, page_blocks.length())
          page_blocks.push(block)
          glyph_count = glyph_count + 1
          char_count = char_count + 1
          span_count = span_count + 1
          line_count = line_count + 1
          block_count = block_count + 1
          if block.decode_confidence == PdfV2DecodeConfidence::Low {
            low_confidence_count = low_confidence_count + 1
          }
          if block.decode_confidence == PdfV2DecodeConfidence::Failed {
            failed_decode_count = failed_decode_count + 1
          }
        }
        None => ()
      }
    }
    pages.push({
      page_index: source_page.page_index,
      blocks: page_blocks,
      warnings: page_warnings,
      risks: page_risks,
    })
  }
  let all_warnings = if block_count == 0 && options.emit_empty_source_warning {
    warnings +
    [
      @pdfv2.pdf_v2_scaffold_warning(
        "pdf_v2 text reconstruction consumed source events but found no text payloads",
      ),
    ]
  } else {
    warnings
  }
  let all_risks = if block_count == 0 && options.fail_closed {
    risks +
    [
      @pdfv2.risk_low_signal_document(
        "text reconstruction produced an empty text model",
      ),
    ]
  } else {
    risks
  }
  {
    summary: {
      page_count: pages.length(),
      glyph_count,
      char_count,
      span_count,
      line_count,
      block_count,
      low_confidence_count,
      failed_decode_count,
      warning_count: all_warnings.length(),
      risk_count: all_risks.length(),
      source_event_count: source.summary.event_count,
      source_diagnostic_event_count: source.summary.diagnostic_event_count,
      scanned_once: source.summary.scanned_once,
      one_pass_required: source.summary.one_pass_required,
      legacy_fallback_allowed: source.summary.legacy_fallback_allowed,
      convert_raw_reparse_allowed: source.summary.convert_raw_reparse_allowed,
      reason_tags: ["source_events_only", "no_pdf_reparse", "fail_closed"],
    },
    pages,
    warnings: all_warnings,
    risks: all_risks,
  }
}

///|
pub fn list_marker_candidate(
  marker_text : String,
  confidence : Double,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
) -> PdfV2ListMarkerCandidate {
  {
    marker_text,
    confidence,
    source_refs,
    reason_tags: ["list_marker_candidate", "parser_shape_fact"],
  }
}

///|
pub fn caption_prefix_candidate(
  prefix_text : String,
  confidence : Double,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
) -> PdfV2CaptionPrefixCandidate {
  {
    prefix_text,
    confidence,
    source_refs,
    reason_tags: ["caption_prefix_candidate", "parser_shape_fact"],
  }
}

///|
pub fn heading_shape_candidate(
  text : String,
  font_size_delta : Double?,
  confidence : Double,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
) -> PdfV2HeadingShapeCandidate {
  {
    text,
    font_size_delta,
    confidence,
    source_refs,
    reason_tags: ["heading_shape_candidate", "parser_shape_fact"],
  }
}

///|
fn block_from_payload(
  event : @source_event.PdfV2SourceEvent,
  payload : @source_event.PdfV2SourceTextPayload,
  index : Int,
) -> PdfV2TextBlock {
  let source_refs = event_source_refs(event)
  let bbox = match payload.bbox {
    Some(bbox) => bbox
    None => @pdfv2.pdf_v2_default_rect()
  }
  let origin = match payload.origin {
    Some(origin) => origin
    None => @pdfv2.pdf_v2_default_point()
  }
  let font : PdfV2FontStyle = {
    font_name: payload.font_name,
    font_family: payload.font_family,
    font_size: payload.font_size,
    style_flags: payload.style_flags,
    fill_color: payload.fill_color,
    stroke_color: payload.stroke_color,
  }
  let confidence = decode_confidence_from_payload(payload)
  let warnings = event.diagnostics.warnings +
    warnings_for_payload(event, payload)
  let risks = event.diagnostics.risks + risks_for_payload(event, payload)
  let glyph : PdfV2Glyph = {
    text: payload.text,
    raw_bytes: payload.raw_bytes,
    decoded_unicode: payload.decoded_unicode,
    bbox,
    origin,
    quad: payload.quad,
    advance_width: payload.advance_width,
    glyph_width: payload.glyph_width,
    font,
    rotation: payload.rotation,
    writing_direction: payload.writing_direction,
    page_index: event_page_index(event),
    object_ref: event.object_ref,
    content_order_index: payload.content_order_index,
    source_refs,
    decode_confidence: confidence,
    warnings,
    risks,
    reason_tags: payload.reason_tags,
  }
  let char = char_from_glyph(glyph)
  let span = span_from_char("span_" + index.to_string(), char)
  let line = line_from_span("line_" + index.to_string(), span)
  block_from_line("block_" + index.to_string(), line)
}

///|
fn char_from_glyph(glyph : PdfV2Glyph) -> PdfV2Char {
  {
    text: glyph.text,
    bbox: glyph.bbox,
    origin: glyph.origin,
    quad: glyph.quad,
    font: glyph.font,
    rotation: glyph.rotation,
    writing_direction: glyph.writing_direction,
    page_index: glyph.page_index,
    object_ref: glyph.object_ref,
    content_order_index: glyph.content_order_index,
    source_refs: glyph.source_refs,
    decode_confidence: glyph.decode_confidence,
    warnings: glyph.warnings,
    risks: glyph.risks,
    reason_tags: glyph.reason_tags,
  }
}

///|
fn span_from_char(id : String, char : PdfV2Char) -> PdfV2Span {
  {
    id,
    text: char.text,
    bbox: char.bbox,
    chars: [char],
    font: char.font,
    rotation: char.rotation,
    writing_direction: char.writing_direction,
    page_index: char.page_index,
    object_refs: object_refs_from_option(char.object_ref),
    content_order_start: char.content_order_index,
    content_order_end: char.content_order_index,
    source_refs: char.source_refs,
    decode_confidence: char.decode_confidence,
    warnings: char.warnings,
    risks: char.risks,
    reason_tags: char.reason_tags,
  }
}

///|
fn line_from_span(id : String, span : PdfV2Span) -> PdfV2Line {
  {
    id,
    text: span.text,
    bbox: span.bbox,
    spans: [span],
    baseline_y: Some(span.bbox.y1),
    line_height: Some(span.bbox.y1 - span.bbox.y0),
    indent_left: Some(span.bbox.x0),
    indent_right: None,
    gap_before: None,
    gap_after: None,
    dominant_font: span.font.font_name,
    dominant_font_size: span.font.font_size,
    writing_direction: span.writing_direction,
    page_index: span.page_index,
    object_refs: span.object_refs,
    content_order_start: span.content_order_start,
    content_order_end: span.content_order_end,
    source_refs: span.source_refs,
    decode_confidence: span.decode_confidence,
    warnings: span.warnings,
    risks: span.risks,
    reason_tags: span.reason_tags,
  }
}

///|
fn block_from_line(id : String, line : PdfV2Line) -> PdfV2TextBlock {
  let candidate_facts = candidate_facts_for_line(line)
  {
    id,
    text: line.text,
    bbox: line.bbox,
    lines: [line],
    dominant_font: line.dominant_font,
    dominant_font_size: line.dominant_font_size,
    writing_direction: line.writing_direction,
    page_index: line.page_index,
    object_refs: line.object_refs,
    content_order_start: line.content_order_start,
    content_order_end: line.content_order_end,
    source_refs: line.source_refs,
    decode_confidence: line.decode_confidence,
    candidate_facts,
    list_marker_candidates: list_candidates_for_line(line),
    caption_prefix_candidates: caption_candidates_for_line(line),
    heading_shape_candidates: heading_candidates_for_line(line),
    warnings: line.warnings,
    risks: line.risks,
    reason_tags: line.reason_tags,
  }
}

///|
fn candidate_facts_for_line(line : PdfV2Line) -> Array[PdfV2TextCandidateFact] {
  let facts : Array[PdfV2TextCandidateFact] = []
  if line.text == "-" || line.text == "*" || line.text == "1." {
    facts.push({
      kind: PdfV2TextCandidateFactKind::ListMarkerCandidate,
      text: line.text,
      confidence: 0.80,
      source_refs: line.source_refs,
      reason_tags: ["list_marker_candidate", "parser_shape_fact"],
    })
  }
  if line.text == "Figure" || line.text == "Table" {
    facts.push({
      kind: PdfV2TextCandidateFactKind::CaptionPrefixCandidate,
      text: line.text,
      confidence: 0.70,
      source_refs: line.source_refs,
      reason_tags: ["caption_prefix_candidate", "parser_shape_fact"],
    })
  }
  facts
}

///|
fn list_candidates_for_line(
  line : PdfV2Line,
) -> Array[PdfV2ListMarkerCandidate] {
  if line.text == "-" || line.text == "*" || line.text == "1." {
    [list_marker_candidate(line.text, 0.80, line.source_refs)]
  } else {
    []
  }
}

///|
fn caption_candidates_for_line(
  line : PdfV2Line,
) -> Array[PdfV2CaptionPrefixCandidate] {
  if line.text == "Figure" || line.text == "Table" {
    [caption_prefix_candidate(line.text, 0.70, line.source_refs)]
  } else {
    []
  }
}

///|
fn heading_candidates_for_line(
  line : PdfV2Line,
) -> Array[PdfV2HeadingShapeCandidate] {
  match line.dominant_font_size {
    Some(font_size) =>
      if font_size >= 16.0 {
        [
          heading_shape_candidate(
            line.text,
            Some(font_size - 12.0),
            0.65,
            line.source_refs,
          ),
        ]
      } else {
        []
      }
    None => []
  }
}

///|
fn decode_confidence_from_payload(
  payload : @source_event.PdfV2SourceTextPayload,
) -> PdfV2DecodeConfidence {
  match payload.decode_confidence {
    Some(value) =>
      if value >= 0.90 {
        PdfV2DecodeConfidence::High
      } else if value >= 0.60 {
        PdfV2DecodeConfidence::Medium
      } else if value > 0.0 {
        PdfV2DecodeConfidence::Low
      } else {
        PdfV2DecodeConfidence::Failed
      }
    None => PdfV2DecodeConfidence::Unknown
  }
}

///|
fn warnings_for_payload(
  event : @source_event.PdfV2SourceEvent,
  payload : @source_event.PdfV2SourceTextPayload,
) -> Array[@pdfv2.PdfV2Warning] {
  let warnings : Array[@pdfv2.PdfV2Warning] = []
  if decode_confidence_from_payload(payload) == PdfV2DecodeConfidence::Low {
    warnings.push(
      @pdfv2.pdf_v2_warning_for_context(
        @pdfv2.PdfV2WarningKind::GlyphDecodeLowConfidence,
        @pdfv2.PdfV2Severity::Warning,
        @pdfv2.pdf_v2_diagnostic_context(
          @pdfv2.PdfV2CoreCapabilityKind::GlyphDecode,
          event.source_ref,
          event.object_ref,
          event.page_index,
          [],
        ),
        "low-confidence text decode retained in text reconstruction",
        ["glyph_decode_low_confidence", "text_retained"],
        @pdfv2.PdfV2Recoverability::RecoverableWithLoss,
      ),
    )
  }
  if payload.writing_direction == @pdfv2.PdfV2WritingDirection::Unknown {
    warnings.push(
      @pdfv2.pdf_v2_warning_for_context(
        @pdfv2.PdfV2WarningKind::LowSignal,
        @pdfv2.PdfV2Severity::Warning,
        @pdfv2.pdf_v2_diagnostic_context(
          @pdfv2.PdfV2CoreCapabilityKind::GlyphDecode,
          event.source_ref,
          event.object_ref,
          event.page_index,
          [],
        ),
        "writing direction is unknown",
        ["writing_direction_unknown"],
        @pdfv2.PdfV2Recoverability::Recoverable,
      ),
    )
  }
  warnings
}

///|
fn risks_for_payload(
  event : @source_event.PdfV2SourceEvent,
  payload : @source_event.PdfV2SourceTextPayload,
) -> Array[@pdfv2.PdfV2Risk] {
  let risks : Array[@pdfv2.PdfV2Risk] = []
  if decode_confidence_from_payload(payload) == PdfV2DecodeConfidence::Low {
    risks.push(
      @pdfv2.risk_glyph_decode_low_confidence(
        event.source_ref,
        event.object_ref,
      ),
    )
  }
  if decode_confidence_from_payload(payload) == PdfV2DecodeConfidence::Failed {
    risks.push(
      @pdfv2.pdf_v2_risk_for_context(
        @pdfv2.PdfV2RiskKind::DecodeFailure,
        @pdfv2.PdfV2RiskSeverity::Error,
        @pdfv2.pdf_v2_diagnostic_context(
          @pdfv2.PdfV2CoreCapabilityKind::GlyphDecode,
          event.source_ref,
          event.object_ref,
          event.page_index,
          [],
        ),
        "text decode failed and was retained as a failed-decode fact",
        ["failed_decode", "text_retained"],
        @pdfv2.PdfV2Recoverability::RecoverableWithLoss,
      ),
    )
  }
  risks
}

///|
fn event_source_refs(
  event : @source_event.PdfV2SourceEvent,
) -> Array[@pdfv2.PdfV2SourceRef] {
  match event.source_ref {
    Some(source_ref) => [source_ref]
    None => []
  }
}

///|
fn event_page_index(event : @source_event.PdfV2SourceEvent) -> Int {
  match event.page_index {
    Some(page_index) => page_index
    None => 0
  }
}

///|
fn object_refs_from_option(object_ref : String?) -> Array[String] {
  match object_ref {
    Some(object_ref) => [object_ref]
    None => []
  }
}
