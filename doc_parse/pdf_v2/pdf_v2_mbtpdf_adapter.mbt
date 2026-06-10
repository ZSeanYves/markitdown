///|
fn pdf_v2_adapter_source_ref(
  page_index : Int?,
  object_id : String?,
  stream_index : Int?,
  op_index : Int?,
  content_order_index : Int?,
  kind : PdfV2SourceKind,
) -> PdfV2SourceRef {
  { page_index, object_id, stream_index, op_index, content_order_index, kind }
}

///|
fn pdf_v2_adapter_object_ref(object_number : Int) -> String {
  "\{object_number} 0 R"
}

///|
fn pdf_v2_adapter_stream_object_ref(stream : @pdf.PdfObject) -> String? {
  match stream {
    Indirect(i) => Some(pdf_v2_adapter_object_ref(i))
    _ => None
  }
}

///|
fn pdf_v2_adapter_warning(
  kind : PdfV2WarningKind,
  severity : PdfV2Severity,
  message : String,
  source_ref : PdfV2SourceRef,
  reason_tags : Array[String],
) -> PdfV2Warning {
  pdf_v2_warning(kind, severity, message, [source_ref], reason_tags)
}

///|
fn pdf_v2_adapter_risk(
  kind : PdfV2RiskKind,
  severity : PdfV2Severity,
  message : String,
  source_ref : PdfV2SourceRef,
  reason_tags : Array[String],
) -> PdfV2Risk {
  { kind, severity, message, source_refs: [source_ref], reason_tags }
}

///|
fn pdf_v2_adapter_error_result(
  kind : PdfV2WarningKind,
  risk_kind : PdfV2RiskKind,
  message : String,
  reason_tags : Array[String],
) -> PdfV2CoreOpenResult {
  let source_ref = pdf_v2_document_source_ref()
  let warning = pdf_v2_adapter_warning(
    kind,
    PdfV2Severity::Error,
    message,
    source_ref,
    reason_tags,
  )
  let risk = pdf_v2_adapter_risk(
    risk_kind,
    PdfV2Severity::Error,
    message,
    source_ref,
    reason_tags,
  )
  PdfV2CoreOpenResult::CoreOpenErr([warning], [risk], message)
}

///|
fn pdf_v2_adapter_read_error_result(message : String) -> PdfV2CoreOpenResult {
  let reason_tags = if message.contains("Encryption") ||
    message.contains("encryption") {
    ["mbtpdf_reader", "encrypted_or_restricted", "fail_closed", "no_fallback"]
  } else {
    ["mbtpdf_reader", "malformed", "fail_closed", "no_fallback"]
  }
  if reason_tags.contains("encrypted_or_restricted") {
    pdf_v2_adapter_error_result(
      PdfV2WarningKind::EncryptedOrRestricted,
      PdfV2RiskKind::EncryptedOrRestricted,
      "PDF v2 mbtpdf reader rejected encrypted or restricted input: " + message,
      reason_tags,
    )
  } else {
    pdf_v2_adapter_error_result(
      PdfV2WarningKind::MalformedObject,
      PdfV2RiskKind::Malformed,
      "PDF v2 mbtpdf reader failed closed: " + message,
      reason_tags,
    )
  }
}

///|
fn pdf_v2_adapter_page_limit(
  total_pages : Int,
  options : PdfV2CoreOpenOptions,
) -> Int {
  match options.max_pages {
    Some(limit) if limit <= 0 => 0
    Some(limit) if limit < total_pages => limit
    _ => total_pages
  }
}

///|
fn pdf_v2_adapter_push_capped_event(
  events : Array[PdfV2CoreEvent],
  event : PdfV2CoreEvent,
  options : PdfV2CoreOpenOptions,
  event_cap_hit : Ref[Bool],
) -> Bool {
  match options.max_events {
    Some(limit) if events.length() >= limit => {
      event_cap_hit.val = true
      false
    }
    _ => {
      events.push(event)
      true
    }
  }
}

///|
fn pdf_v2_adapter_bbox(pdf : @pdf.Pdf, object : @pdf.PdfObject) -> PdfV2BBox? {
  try {
    let (x0, y0, x1, y1) = pdf.parse_rectangle(object)
    Some({ x0, y0, x1, y1 })
  } catch {
    _ => None
  }
}

///|
fn pdf_v2_adapter_user_unit(pdf : @pdf.Pdf, page : @pdfpage.Page) -> Double? {
  match page.rest.lookup_immediate("/UserUnit") {
    Some(value) => Some(pdf.getnum(value)) catch { _ => None }
    None => None
  }
}

///|
fn pdf_v2_adapter_resources_present(resources : @pdf.PdfObject) -> Bool {
  match resources {
    Dictionary(entries) => entries.length() > 0
    Null => false
    _ => true
  }
}

///|
priv struct PdfV2AdapterFontResource {
  font_ref : String?
  font_object : @pdf.PdfObject?
  has_tounicode : Bool
}

///|
priv struct PdfV2AdapterTextState {
  font_name_or_ref : Ref[String?]
  font_ref : Ref[String?]
  font_object : Ref[@pdf.PdfObject?]
  font_has_tounicode : Ref[Bool]
  font_size : Ref[Double?]
  text_matrix : Ref[PdfV2TextMatrix?]
  line_matrix : Ref[PdfV2TextMatrix?]
  text_rendering_mode : Ref[Int?]
  char_spacing : Ref[Double?]
  word_spacing : Ref[Double?]
  horizontal_scaling : Ref[Double?]
  leading : Ref[Double?]
  rise : Ref[Double?]
}

///|
priv struct PdfV2AdapterDecodedGlyph {
  glyph_name : String?
  unicode_candidate : String?
}

///|
priv struct PdfV2AdapterDecodeResult {
  decoded_text : String?
  confidence : PdfV2TextDecodeConfidence
  glyphs : Array[PdfV2AdapterDecodedGlyph]
  reason_tags : Array[String]
  warnings : Array[PdfV2Warning]
}

///|
fn pdf_v2_adapter_empty_text_state() -> PdfV2AdapterTextState {
  {
    font_name_or_ref: { val: None },
    font_ref: { val: None },
    font_object: { val: None },
    font_has_tounicode: { val: false },
    font_size: { val: None },
    text_matrix: { val: None },
    line_matrix: { val: None },
    text_rendering_mode: { val: None },
    char_spacing: { val: None },
    word_spacing: { val: None },
    horizontal_scaling: { val: None },
    leading: { val: None },
    rise: { val: None },
  }
}

///|
fn pdf_v2_adapter_matrix(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
) -> PdfV2TextMatrix {
  { a, b, c, d, e, f }
}

///|
fn pdf_v2_adapter_char_string(ch : Char) -> String {
  String::from_array([ch])
}

///|
fn pdf_v2_adapter_tags(
  base : Array[String],
  extra : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  out.append(base)
  out.append(extra)
  out
}

///|
fn pdf_v2_adapter_first_some(a : String?, b : String?) -> String? {
  match a {
    Some(_) => a
    None => b
  }
}

///|
fn pdf_v2_adapter_text_state_fact(
  state : PdfV2AdapterTextState,
  source_ref : PdfV2SourceRef,
  confidence : PdfV2TextDecodeConfidence,
  reason_tags : Array[String],
) -> PdfV2TextStateFact {
  {
    font_name_or_ref: state.font_name_or_ref.val,
    font_size: state.font_size.val,
    text_matrix: state.text_matrix.val,
    line_matrix: state.line_matrix.val,
    text_rendering_mode: state.text_rendering_mode.val,
    char_spacing: state.char_spacing.val,
    word_spacing: state.word_spacing.val,
    horizontal_scaling: state.horizontal_scaling.val,
    leading: state.leading.val,
    rise: state.rise.val,
    source_ref,
    confidence,
    reason_tags,
  }
}

///|
fn pdf_v2_adapter_core_event(
  kind : PdfV2CoreEventKind,
  source_ref : PdfV2SourceRef,
  reason_tags : Array[String],
) -> PdfV2CoreEvent {
  {
    kind,
    page_index: source_ref.page_index,
    text: None,
    bbox: None,
    object_ref: source_ref.object_id,
    source_ref,
    reason_tags,
    warnings: [],
    text_state: None,
    text_show: None,
    glyph_candidate: None,
  }
}

///|
fn pdf_v2_adapter_located_source_ref(
  page_index : Int,
  item : @pdfops.LocatedOp,
  object_ref : String?,
  content_order_index : Int,
  kind : PdfV2SourceKind,
) -> PdfV2SourceRef {
  pdf_v2_adapter_source_ref(
    Some(page_index),
    object_ref,
    Some(item.source_stream_index),
    Some(item.source_op_index),
    Some(content_order_index),
    kind,
  )
}

///|
fn pdf_v2_adapter_font_resource(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  font_name : String,
) -> PdfV2AdapterFontResource {
  match pdf.lookup_direct("/Font", resources) {
    Some(fonts) =>
      match fonts.lookup_immediate(font_name) {
        Some(font_obj) => {
          let direct = pdf.direct(font_obj)
          {
            font_ref: match font_obj {
              Indirect(n) => Some(pdf_v2_adapter_object_ref(n))
              _ => Some(font_name)
            },
            font_object: Some(direct),
            has_tounicode: pdf.lookup_direct("/ToUnicode", direct) is Some(_),
          }
        }
        None =>
          { font_ref: Some(font_name), font_object: None, has_tounicode: false }
      }
    None =>
      { font_ref: Some(font_name), font_object: None, has_tounicode: false }
  }
}

///|
fn pdf_v2_adapter_codepoints_to_utf8(codepoints : Array[Int]) -> String? {
  (@pdftext.PdfTextUtil::new().utf8_of_codepoints(codepoints) |> Some) catch {
    _ => None
  }
}

///|
fn pdf_v2_adapter_decode_text(
  pdf : @pdf.Pdf,
  state : PdfV2AdapterTextState,
  raw_text : String,
  source_ref : PdfV2SourceRef,
) -> PdfV2AdapterDecodeResult {
  let warnings : Array[PdfV2Warning] = []
  let reason_tags : Array[String] = ["text_show", "glyph_candidate"]
  match state.font_object.val {
    None => {
      warnings.push(
        pdf_v2_adapter_warning(
          PdfV2WarningKind::DecodeIssue,
          PdfV2Severity::Warning,
          "PDF v2 text show has no resolved font resource",
          source_ref,
          ["missing_font_resource", "decode_confidence_unknown"],
        ),
      )
      {
        decoded_text: None,
        confidence: PdfV2TextDecodeConfidence::Unknown,
        glyphs: [],
        reason_tags: pdf_v2_adapter_tags(reason_tags, ["missing_font_resource"]),
        warnings,
      }
    }
    Some(font_object) => {
      let decode_result : Result[Array[(String, Array[Int])], Error] = try
        @pdftext.PdfText::new(pdf)
        .text_extractor_of_font(font_object)
        .glyphnames_and_codepoints_of_text(raw_text)
        |> Ok
      catch {
        err => Err(err)
      }
      match decode_result {
        Ok(pairs) => {
          let decoded_parts : Array[String] = []
          let glyphs : Array[PdfV2AdapterDecodedGlyph] = []
          for pair in pairs {
            let unicode = pdf_v2_adapter_codepoints_to_utf8(pair.1)
            match unicode {
              Some(text) => decoded_parts.push(text)
              None => ()
            }
            glyphs.push({ glyph_name: Some(pair.0), unicode_candidate: unicode })
          }
          let confidence = if state.font_has_tounicode.val {
            PdfV2TextDecodeConfidence::High
          } else {
            warnings.push(
              pdf_v2_adapter_warning(
                PdfV2WarningKind::DecodeIssue,
                PdfV2Severity::Info,
                "PDF v2 text show has no ToUnicode map; decoded text is a font-encoding candidate",
                source_ref,
                ["missing_tounicode", "font_encoding_candidate"],
              ),
            )
            PdfV2TextDecodeConfidence::Medium
          }
          warnings.push(
            pdf_v2_adapter_warning(
              PdfV2WarningKind::DecodeIssue,
              PdfV2Severity::Info,
              "PDF v2 glyph candidate geometry is not available yet",
              source_ref,
              ["glyph_geometry_unavailable"],
            ),
          )
          {
            decoded_text: Some(decoded_parts.join("")),
            confidence,
            glyphs,
            reason_tags: if state.font_has_tounicode.val {
              pdf_v2_adapter_tags(reason_tags, ["tounicode_or_font_decode"])
            } else {
              pdf_v2_adapter_tags(reason_tags, [
                "missing_tounicode", "font_encoding_candidate",
              ])
            },
            warnings,
          }
        }
        Err(err) => {
          warnings.push(
            pdf_v2_adapter_warning(
              PdfV2WarningKind::DecodeIssue,
              PdfV2Severity::Warning,
              "PDF v2 text decode failed: " + err.to_string(),
              source_ref,
              ["decode_failed", "unsupported_font_encoding"],
            ),
          )
          {
            decoded_text: None,
            confidence: PdfV2TextDecodeConfidence::Failed,
            glyphs: [],
            reason_tags: pdf_v2_adapter_tags(reason_tags, [
              "decode_failed", "unsupported_font_encoding",
            ]),
            warnings,
          }
        }
      }
    }
  }
}

///|
fn pdf_v2_adapter_tj_text_segments(obj : @pdf.PdfObject) -> Array[String] {
  match obj {
    Array(items) => {
      let segments : Array[String] = []
      for item in items {
        match item {
          String(text) => segments.push(text)
          _ => ()
        }
      }
      segments
    }
    String(text) => [text]
    _ => []
  }
}

///|
fn pdf_v2_adapter_tj_has_spacing(obj : @pdf.PdfObject) -> Bool {
  match obj {
    Array(items) => {
      for item in items {
        match item {
          Integer(_) | Real(_) => return true
          _ => ()
        }
      }
      false
    }
    _ => false
  }
}

///|
fn pdf_v2_adapter_raw_text_for_show(
  kind : PdfV2TextShowOperatorKind,
  raw_text : String,
  tj_object : @pdf.PdfObject?,
) -> String {
  match kind {
    TJ =>
      match tj_object {
        Some(obj) => obj.to_string()
        None => raw_text
      }
    _ => raw_text
  }
}

///|
fn pdf_v2_adapter_text_show_reason_tags(
  base : Array[String],
  kind : PdfV2TextShowOperatorKind,
  has_spacing_adjustment : Bool,
) -> Array[String] {
  let op_tag = match kind {
    Tj => "operator_Tj"
    TJ => "operator_TJ"
    SingleQuote => "operator_quote"
    DoubleQuote => "operator_double_quote"
    UnknownTextShow => "operator_unknown_text_show"
  }
  let extra = if has_spacing_adjustment {
    [op_tag, "spacing_adjustment_present"]
  } else {
    [op_tag]
  }
  pdf_v2_adapter_tags(base, extra)
}

///|
fn pdf_v2_adapter_emit_text_state_event(
  state : PdfV2AdapterTextState,
  source_ref : PdfV2SourceRef,
  events : Array[PdfV2CoreEvent],
  options : PdfV2CoreOpenOptions,
  event_cap_hit : Ref[Bool],
  kind : PdfV2CoreEventKind,
  reason_tags : Array[String],
  warnings : Array[PdfV2Warning],
) -> Unit {
  let event_reason_tags = pdf_v2_adapter_tags(reason_tags, [
    "text_state_incomplete",
  ])
  let fact = pdf_v2_adapter_text_state_fact(
    state,
    source_ref,
    PdfV2TextDecodeConfidence::Unknown,
    event_reason_tags,
  )
  let event : PdfV2CoreEvent = {
    kind,
    page_index: source_ref.page_index,
    text: state.font_name_or_ref.val,
    bbox: None,
    object_ref: source_ref.object_id,
    source_ref,
    reason_tags: event_reason_tags,
    warnings,
    text_state: Some(fact),
    text_show: None,
    glyph_candidate: None,
  }
  let _ = pdf_v2_adapter_push_capped_event(
    events, event, options, event_cap_hit,
  )
}

///|
fn pdf_v2_adapter_emit_text_show_event(
  pdf : @pdf.Pdf,
  state : PdfV2AdapterTextState,
  source_ref : PdfV2SourceRef,
  raw_kind : PdfV2TextShowOperatorKind,
  raw_text : String,
  tj_object : @pdf.PdfObject?,
  has_spacing_adjustment : Bool,
  events : Array[PdfV2CoreEvent],
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  options : PdfV2CoreOpenOptions,
  event_cap_hit : Ref[Bool],
  content_order : Ref[Int],
) -> Unit {
  let decoded = pdf_v2_adapter_decode_text(pdf, state, raw_text, source_ref)
  for warning in decoded.warnings {
    warnings.push(warning)
  }
  match decoded.confidence {
    Unknown | Failed =>
      risks.push(
        pdf_v2_adapter_risk(
          PdfV2RiskKind::DecodeLowConfidence,
          PdfV2Severity::Warning,
          "PDF v2 text show decode confidence is not sufficient for reconstruction",
          source_ref,
          decoded.reason_tags,
        ),
      )
    _ => ()
  }
  let reason_tags = pdf_v2_adapter_text_show_reason_tags(
    decoded.reason_tags,
    raw_kind,
    has_spacing_adjustment,
  )
  let fact : PdfV2TextShowFact = {
    raw_operator_kind: raw_kind,
    raw_bytes_or_string: pdf_v2_adapter_raw_text_for_show(
      raw_kind, raw_text, tj_object,
    ),
    decoded_text: decoded.decoded_text,
    font_ref: pdf_v2_adapter_first_some(
      state.font_ref.val,
      state.font_name_or_ref.val,
    ),
    font_size: state.font_size.val,
    text_matrix_snapshot: state.text_matrix.val,
    source_ref,
    decode_confidence: decoded.confidence,
    warnings: decoded.warnings,
    reason_tags,
  }
  let event : PdfV2CoreEvent = {
    kind: PdfV2CoreEventKind::TextShow,
    page_index: source_ref.page_index,
    text: decoded.decoded_text,
    bbox: None,
    object_ref: source_ref.object_id,
    source_ref,
    reason_tags,
    warnings: decoded.warnings,
    text_state: None,
    text_show: Some(fact),
    glyph_candidate: None,
  }
  let _ = pdf_v2_adapter_push_capped_event(
    events, event, options, event_cap_hit,
  )

  let raw_chars = raw_text.to_array()
  for index = 0; index < raw_chars.length(); index = index + 1 {
    let ch = raw_chars[index]
    let glyph_source_ref = pdf_v2_adapter_source_ref(
      source_ref.page_index,
      source_ref.object_id,
      source_ref.stream_index,
      source_ref.op_index,
      Some(content_order.val),
      PdfV2SourceKind::Glyph,
    )
    content_order.val = content_order.val + 1
    let decoded_glyph = decoded.glyphs.get(index)
    let unicode_candidate = match decoded_glyph {
      Some(value) => value.unicode_candidate
      None => None
    }
    let glyph_name = match decoded_glyph {
      Some(value) => value.glyph_name
      None => None
    }
    let glyph_tags = pdf_v2_adapter_tags(reason_tags, [
      "glyph_candidate", "glyph_geometry_unavailable",
    ])
    let glyph_fact : PdfV2GlyphCandidateFact = {
      raw_code: Some(ch.to_int()),
      raw_bytes: pdf_v2_adapter_char_string(ch),
      unicode_candidate,
      glyph_name,
      font_ref: pdf_v2_adapter_first_some(
        state.font_ref.val,
        state.font_name_or_ref.val,
      ),
      advance_width: None,
      text_position: state.text_matrix.val,
      bbox: None,
      decode_confidence: decoded.confidence,
      source_ref: glyph_source_ref,
      reason_tags: glyph_tags,
    }
    let glyph_event : PdfV2CoreEvent = {
      kind: PdfV2CoreEventKind::GlyphCandidate,
      page_index: glyph_source_ref.page_index,
      text: unicode_candidate,
      bbox: None,
      object_ref: glyph_source_ref.object_id,
      source_ref: glyph_source_ref,
      reason_tags: glyph_tags,
      warnings: [],
      text_state: None,
      text_show: None,
      glyph_candidate: Some(glyph_fact),
    }
    let _ = pdf_v2_adapter_push_capped_event(
      events, glyph_event, options, event_cap_hit,
    )
  }
}

///|
fn pdf_v2_adapter_text_state_source_ref(
  page_index : Int,
  item : @pdfops.LocatedOp,
  object_ref : String?,
  content_order : Ref[Int],
  kind : PdfV2SourceKind,
) -> PdfV2SourceRef {
  let source_ref = pdf_v2_adapter_located_source_ref(
    page_index,
    item,
    object_ref,
    content_order.val,
    kind,
  )
  content_order.val = content_order.val + 1
  source_ref
}

///|
fn pdf_v2_adapter_add_text_events_for_op(
  pdf : @pdf.Pdf,
  page_index : Int,
  page : @pdfpage.Page,
  item : @pdfops.LocatedOp,
  object_ref : String?,
  state : PdfV2AdapterTextState,
  events : Array[PdfV2CoreEvent],
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  options : PdfV2CoreOpenOptions,
  event_cap_hit : Ref[Bool],
  content_order : Ref[Int],
) -> Unit {
  match item.op {
    OpBT => {
      state.text_matrix.val = Some(pdf_v2_identity_text_matrix())
      state.line_matrix.val = Some(pdf_v2_identity_text_matrix())
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_state_event(
        state,
        source_ref,
        events,
        options,
        event_cap_hit,
        PdfV2CoreEventKind::TextObjectBegin,
        ["text_object_begin", "operator_BT"],
        [],
      )
    }
    OpET => {
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_state_event(
        state,
        source_ref,
        events,
        options,
        event_cap_hit,
        PdfV2CoreEventKind::TextObjectEnd,
        ["text_object_end", "operator_ET"],
        [],
      )
    }
    OpTf(font_name, font_size) => {
      let resource = pdf_v2_adapter_font_resource(
        pdf,
        page.resources,
        font_name,
      )
      state.font_name_or_ref.val = Some(font_name)
      state.font_ref.val = resource.font_ref
      state.font_object.val = resource.font_object
      state.font_has_tounicode.val = resource.has_tounicode
      state.font_size.val = Some(font_size)
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      let event_warnings : Array[PdfV2Warning] = []
      if resource.font_object is None {
        let warning = pdf_v2_adapter_warning(
          PdfV2WarningKind::DecodeIssue,
          PdfV2Severity::Warning,
          "PDF v2 font resource is missing for text state",
          source_ref,
          ["missing_font_resource", "operator_Tf"],
        )
        warnings.push(warning)
        event_warnings.push(warning)
        risks.push(
          pdf_v2_adapter_risk(
            PdfV2RiskKind::DecodeLowConfidence,
            PdfV2Severity::Warning,
            "PDF v2 text state cannot resolve selected font",
            source_ref,
            ["missing_font_resource", "operator_Tf"],
          ),
        )
      }
      pdf_v2_adapter_emit_text_state_event(
        state,
        source_ref,
        events,
        options,
        event_cap_hit,
        PdfV2CoreEventKind::FontUse,
        ["font_use", "operator_Tf"],
        event_warnings,
      )
    }
    OpTc(value) => {
      state.char_spacing.val = Some(value)
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_state_event(
        state,
        source_ref,
        events,
        options,
        event_cap_hit,
        PdfV2CoreEventKind::TextState,
        ["text_state", "operator_Tc"],
        [],
      )
    }
    OpTw(value) => {
      state.word_spacing.val = Some(value)
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_state_event(
        state,
        source_ref,
        events,
        options,
        event_cap_hit,
        PdfV2CoreEventKind::TextState,
        ["text_state", "operator_Tw"],
        [],
      )
    }
    OpTz(value) => {
      state.horizontal_scaling.val = Some(value)
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_state_event(
        state,
        source_ref,
        events,
        options,
        event_cap_hit,
        PdfV2CoreEventKind::TextState,
        ["text_state", "operator_Tz"],
        [],
      )
    }
    OpTL(value) => {
      state.leading.val = Some(value)
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_state_event(
        state,
        source_ref,
        events,
        options,
        event_cap_hit,
        PdfV2CoreEventKind::TextState,
        ["text_state", "operator_TL"],
        [],
      )
    }
    OpTr(value) => {
      state.text_rendering_mode.val = Some(value)
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_state_event(
        state,
        source_ref,
        events,
        options,
        event_cap_hit,
        PdfV2CoreEventKind::TextState,
        ["text_state", "operator_Tr"],
        [],
      )
    }
    OpTs(value) => {
      state.rise.val = Some(value)
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_state_event(
        state,
        source_ref,
        events,
        options,
        event_cap_hit,
        PdfV2CoreEventKind::TextState,
        ["text_state", "operator_Ts"],
        [],
      )
    }
    OpTd(tx, ty) => {
      let matrix = pdf_v2_adapter_matrix(1.0, 0.0, 0.0, 1.0, tx, ty)
      state.text_matrix.val = Some(matrix)
      state.line_matrix.val = Some(matrix)
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_state_event(
        state,
        source_ref,
        events,
        options,
        event_cap_hit,
        PdfV2CoreEventKind::TextState,
        ["text_state", "operator_Td"],
        [],
      )
    }
    OpTD(tx, ty) => {
      state.leading.val = Some(0.0 - ty)
      let matrix = pdf_v2_adapter_matrix(1.0, 0.0, 0.0, 1.0, tx, ty)
      state.text_matrix.val = Some(matrix)
      state.line_matrix.val = Some(matrix)
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_state_event(
        state,
        source_ref,
        events,
        options,
        event_cap_hit,
        PdfV2CoreEventKind::TextState,
        ["text_state", "operator_TD"],
        [],
      )
    }
    OpTm(matrix) => {
      let text_matrix = pdf_v2_adapter_matrix(
        matrix.a,
        matrix.b,
        matrix.c,
        matrix.d,
        matrix.e,
        matrix.f,
      )
      state.text_matrix.val = Some(text_matrix)
      state.line_matrix.val = Some(text_matrix)
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_state_event(
        state,
        source_ref,
        events,
        options,
        event_cap_hit,
        PdfV2CoreEventKind::TextState,
        ["text_state", "operator_Tm"],
        [],
      )
    }
    OpTStar => {
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_state_event(
        state,
        source_ref,
        events,
        options,
        event_cap_hit,
        PdfV2CoreEventKind::TextState,
        ["text_state", "operator_TStar", "text_position_not_recomputed"],
        [],
      )
    }
    OpTj(text) => {
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_show_event(
        pdf,
        state,
        source_ref,
        PdfV2TextShowOperatorKind::Tj,
        text,
        None,
        false,
        events,
        warnings,
        risks,
        options,
        event_cap_hit,
        content_order,
      )
    }
    OpTJ(obj) => {
      let segments = pdf_v2_adapter_tj_text_segments(obj)
      let raw_text = segments.join("")
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_show_event(
        pdf,
        state,
        source_ref,
        PdfV2TextShowOperatorKind::TJ,
        raw_text,
        Some(obj),
        pdf_v2_adapter_tj_has_spacing(obj),
        events,
        warnings,
        risks,
        options,
        event_cap_hit,
        content_order,
      )
    }
    OpSingleQuote(text) => {
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_show_event(
        pdf,
        state,
        source_ref,
        PdfV2TextShowOperatorKind::SingleQuote,
        text,
        None,
        false,
        events,
        warnings,
        risks,
        options,
        event_cap_hit,
        content_order,
      )
    }
    OpDoubleQuote(word, char, text) => {
      state.word_spacing.val = Some(word)
      state.char_spacing.val = Some(char)
      let source_ref = pdf_v2_adapter_text_state_source_ref(
        page_index,
        item,
        object_ref,
        content_order,
        PdfV2SourceKind::TextOp,
      )
      pdf_v2_adapter_emit_text_show_event(
        pdf,
        state,
        source_ref,
        PdfV2TextShowOperatorKind::DoubleQuote,
        text,
        None,
        true,
        events,
        warnings,
        risks,
        options,
        event_cap_hit,
        content_order,
      )
    }
    _ => ()
  }
}

///|
fn pdf_v2_adapter_page_ref(
  page_index : Int,
  page_object : Int?,
) -> PdfV2SourceRef {
  pdf_v2_adapter_source_ref(
    Some(page_index),
    page_object.map(pdf_v2_adapter_object_ref),
    None,
    None,
    None,
    PdfV2SourceKind::Page,
  )
}

///|
fn pdf_v2_adapter_page_fact(
  pdf : @pdf.Pdf,
  page_index : Int,
  page : @pdfpage.Page,
  page_ref : PdfV2SourceRef,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> PdfV2CorePageFact {
  let media_box = match pdf_v2_adapter_bbox(pdf, page.mediabox) {
    Some(box) => box
    None => {
      let message = "PDF v2 adapter could not parse page MediaBox"
      warnings.push(
        pdf_v2_adapter_warning(
          PdfV2WarningKind::MalformedObject,
          PdfV2Severity::Warning,
          message,
          page_ref,
          ["page_fact", "mediabox", "malformed"],
        ),
      )
      risks.push(
        pdf_v2_adapter_risk(
          PdfV2RiskKind::Malformed,
          PdfV2Severity::Warning,
          message,
          page_ref,
          ["page_fact", "mediabox", "malformed"],
        ),
      )
      pdf_v2_empty_bbox()
    }
  }
  let crop_box = match page.cropbox {
    Some(crop) => pdf_v2_adapter_bbox(pdf, crop)
    None => None
  }
  {
    page_index,
    page_label: None,
    media_box,
    crop_box,
    rotate: page.rotate.to_int(),
    user_unit: pdf_v2_adapter_user_unit(pdf, page),
    resources_present: pdf_v2_adapter_resources_present(page.resources),
    source_ref: page_ref,
  }
}

///|
fn pdf_v2_adapter_add_cap_warning(
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  message : String,
  reason_tags : Array[String],
) -> Unit {
  let source_ref = pdf_v2_document_source_ref()
  warnings.push(
    pdf_v2_adapter_warning(
      PdfV2WarningKind::PerformanceCap,
      PdfV2Severity::Warning,
      message,
      source_ref,
      reason_tags,
    ),
  )
  risks.push(
    pdf_v2_adapter_risk(
      PdfV2RiskKind::PerformanceCapReached,
      PdfV2Severity::Warning,
      message,
      source_ref,
      reason_tags,
    ),
  )
}

///|
fn pdf_v2_adapter_add_encryption_warning(
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Unit {
  let source_ref = pdf_v2_document_source_ref()
  let message = "PDF v2 adapter opened encrypted or restricted PDF metadata"
  warnings.push(
    pdf_v2_adapter_warning(
      PdfV2WarningKind::EncryptedOrRestricted,
      PdfV2Severity::Warning,
      message,
      source_ref,
      ["mbtpdf_reader", "encrypted_or_restricted", "no_fallback"],
    ),
  )
  risks.push(
    pdf_v2_adapter_risk(
      PdfV2RiskKind::EncryptedOrRestricted,
      PdfV2Severity::Warning,
      message,
      source_ref,
      ["mbtpdf_reader", "encrypted_or_restricted", "no_fallback"],
    ),
  )
}

///|
fn pdf_v2_adapter_add_stream_events(
  page_index : Int,
  page : @pdfpage.Page,
  events : Array[PdfV2CoreEvent],
  options : PdfV2CoreOpenOptions,
  event_cap_hit : Ref[Bool],
  content_order : Ref[Int],
) -> Unit {
  for stream_index = 0
      stream_index < page.content.length()
      stream_index = stream_index + 1 {
    let stream = page.content[stream_index]
    let source_ref = pdf_v2_adapter_source_ref(
      Some(page_index),
      pdf_v2_adapter_stream_object_ref(stream),
      Some(stream_index),
      None,
      Some(content_order.val),
      PdfV2SourceKind::ContentStream,
    )
    content_order.val = content_order.val + 1
    let _ = pdf_v2_adapter_push_capped_event(
      events,
      pdf_v2_adapter_core_event(
        PdfV2CoreEventKind::ContentStreamBegin,
        source_ref,
        ["content_stream", "begin", "mbtpdf"],
      ),
      options,
      event_cap_hit,
    )
  }
}

///|
fn pdf_v2_adapter_add_stream_end_events(
  page_index : Int,
  page : @pdfpage.Page,
  events : Array[PdfV2CoreEvent],
  options : PdfV2CoreOpenOptions,
  event_cap_hit : Ref[Bool],
  content_order : Ref[Int],
) -> Unit {
  for stream_index = 0
      stream_index < page.content.length()
      stream_index = stream_index + 1 {
    let stream = page.content[stream_index]
    let source_ref = pdf_v2_adapter_source_ref(
      Some(page_index),
      pdf_v2_adapter_stream_object_ref(stream),
      Some(stream_index),
      None,
      Some(content_order.val),
      PdfV2SourceKind::ContentStream,
    )
    content_order.val = content_order.val + 1
    let _ = pdf_v2_adapter_push_capped_event(
      events,
      pdf_v2_adapter_core_event(
        PdfV2CoreEventKind::ContentStreamEnd,
        source_ref,
        ["content_stream", "end", "mbtpdf"],
      ),
      options,
      event_cap_hit,
    )
  }
}

///|
fn pdf_v2_adapter_add_located_ops(
  pdf : @pdf.Pdf,
  page_index : Int,
  page : @pdfpage.Page,
  events : Array[PdfV2CoreEvent],
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  options : PdfV2CoreOpenOptions,
  event_cap_hit : Ref[Bool],
  content_order : Ref[Int],
) -> Unit {
  if page.content.length() == 0 {
    return
  }
  let located_result : Result[Array[@pdfops.LocatedOp], Error] = try
    @pdfops.Op::parse_operators_with_source(pdf, page.resources, page.content)
    |> Ok
  catch {
    err => Err(err)
  }
  match located_result {
    Ok(located) => {
      let text_state = pdf_v2_adapter_empty_text_state()
      for item in located {
        let object_ref = item.source_object_ref.map(pdf_v2_adapter_object_ref)
        let source_ref = pdf_v2_adapter_located_source_ref(
          page_index,
          item,
          object_ref,
          content_order.val,
          PdfV2SourceKind::Unknown,
        )
        content_order.val = content_order.val + 1
        let event : PdfV2CoreEvent = {
          kind: PdfV2CoreEventKind::Unknown,
          page_index: Some(page_index),
          text: None,
          bbox: None,
          object_ref,
          source_ref,
          reason_tags: ["raw_op", "unknown_mapping", "mbtpdf_located_op"],
          warnings: [],
          text_state: None,
          text_show: None,
          glyph_candidate: None,
        }
        let _ = pdf_v2_adapter_push_capped_event(
          events, event, options, event_cap_hit,
        )
        pdf_v2_adapter_add_text_events_for_op(
          pdf, page_index, page, item, object_ref, text_state, events, warnings,
          risks, options, event_cap_hit, content_order,
        )
      }
    }
    Err(err) => {
      let source_ref = pdf_v2_adapter_source_ref(
        Some(page_index),
        None,
        None,
        None,
        Some(content_order.val),
        PdfV2SourceKind::Malformed,
      )
      content_order.val = content_order.val + 1
      let message = "PDF v2 adapter could not parse page content operators: " +
        err.to_string()
      let warning = pdf_v2_adapter_warning(
        PdfV2WarningKind::MalformedObject,
        PdfV2Severity::Warning,
        message,
        source_ref,
        ["content_ops", "malformed", "mbtpdf"],
      )
      warnings.push(warning)
      risks.push(
        pdf_v2_adapter_risk(
          PdfV2RiskKind::Malformed,
          PdfV2Severity::Warning,
          message,
          source_ref,
          ["content_ops", "malformed", "mbtpdf"],
        ),
      )
      let event : PdfV2CoreEvent = {
        kind: PdfV2CoreEventKind::Malformed,
        page_index: Some(page_index),
        text: None,
        bbox: None,
        object_ref: None,
        source_ref,
        reason_tags: ["content_ops", "malformed", "mbtpdf"],
        warnings: [warning],
        text_state: None,
        text_show: None,
        glyph_candidate: None,
      }
      let _ = pdf_v2_adapter_push_capped_event(
        events, event, options, event_cap_hit,
      )
    }
  }
}

///|
fn pdf_v2_adapter_core_from_pdf(
  pdf : @pdf.Pdf,
  reader : @pdfread.PdfRead,
  options : PdfV2CoreOpenOptions,
) -> PdfV2CoreOpenResult {
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  match reader.what_encryption(pdf) {
    Some(_) if options.fail_on_encrypted => {
      let source_ref = pdf_v2_document_source_ref()
      let message = "PDF v2 adapter fail_on_encrypted rejected encrypted PDF"
      let warning = pdf_v2_adapter_warning(
        PdfV2WarningKind::EncryptedOrRestricted,
        PdfV2Severity::Error,
        message,
        source_ref,
        ["mbtpdf_reader", "encrypted_or_restricted", "fail_closed"],
      )
      let risk = pdf_v2_adapter_risk(
        PdfV2RiskKind::EncryptedOrRestricted,
        PdfV2Severity::Error,
        message,
        source_ref,
        ["mbtpdf_reader", "encrypted_or_restricted", "fail_closed"],
      )
      return PdfV2CoreOpenResult::CoreOpenErr([warning], [risk], message)
    }
    Some(_) => pdf_v2_adapter_add_encryption_warning(warnings, risks)
    None => ()
  }

  let page_doc = @pdfpage.PdfPageDoc::new(pdf)
  let pages_result : Result[Array[@pdfpage.Page], Error] = try
    page_doc.pages_of_pagetree() |> Ok
  catch {
    err => Err(err)
  }
  let pages = match pages_result {
    Ok(items) => items
    Err(err) => {
      let message = "PDF v2 adapter failed to read page tree: " +
        err.to_string()
      return pdf_v2_adapter_error_result(
        PdfV2WarningKind::MalformedObject,
        PdfV2RiskKind::ObjectGraphIssue,
        message,
        ["page_tree", "malformed", "fail_closed", "no_fallback"],
      )
    }
  }

  let page_limit = pdf_v2_adapter_page_limit(pages.length(), options)
  if page_limit < pages.length() {
    pdf_v2_adapter_add_cap_warning(
      warnings,
      risks,
      "PDF v2 adapter stopped at max_pages=\{page_limit} of \{pages.length()} pages",
      ["max_pages", "performance_cap", "no_fallback"],
    )
  }

  let page_facts : Array[PdfV2CorePageFact] = []
  let events : Array[PdfV2CoreEvent] = []
  let event_cap_hit : Ref[Bool] = { val: false }
  let content_order : Ref[Int] = { val: 0 }
  for page_index = 0; page_index < page_limit; page_index = page_index + 1 {
    let page = pages[page_index]
    let page_object = page_doc.page_object_number(page_index + 1) catch {
      _ => None
    }
    let page_ref = pdf_v2_adapter_page_ref(page_index, page_object)
    page_facts.push(
      pdf_v2_adapter_page_fact(pdf, page_index, page, page_ref, warnings, risks),
    )
    let page_begin_ref = pdf_v2_adapter_source_ref(
      page_ref.page_index,
      page_ref.object_id,
      page_ref.stream_index,
      page_ref.op_index,
      Some(content_order.val),
      page_ref.kind,
    )
    content_order.val = content_order.val + 1
    let _ = pdf_v2_adapter_push_capped_event(
      events,
      pdf_v2_adapter_core_event(PdfV2CoreEventKind::PageBegin, page_begin_ref, [
        "page", "begin", "mbtpdf",
      ]),
      options,
      event_cap_hit,
    )
    pdf_v2_adapter_add_stream_events(
      page_index, page, events, options, event_cap_hit, content_order,
    )
    pdf_v2_adapter_add_located_ops(
      pdf, page_index, page, events, warnings, risks, options, event_cap_hit, content_order,
    )
    pdf_v2_adapter_add_stream_end_events(
      page_index, page, events, options, event_cap_hit, content_order,
    )
    let page_end_ref = pdf_v2_adapter_source_ref(
      page_ref.page_index,
      page_ref.object_id,
      page_ref.stream_index,
      page_ref.op_index,
      Some(content_order.val),
      page_ref.kind,
    )
    content_order.val = content_order.val + 1
    let _ = pdf_v2_adapter_push_capped_event(
      events,
      pdf_v2_adapter_core_event(PdfV2CoreEventKind::PageEnd, page_end_ref, [
        "page", "end", "mbtpdf",
      ]),
      options,
      event_cap_hit,
    )
  }

  if event_cap_hit.val {
    let max_events = match options.max_events {
      Some(limit) => limit
      None => events.length()
    }
    pdf_v2_adapter_add_cap_warning(
      warnings,
      risks,
      "PDF v2 adapter stopped at max_events=\{max_events}",
      ["max_events", "performance_cap", "no_fallback"],
    )
  }

  let core : PdfV2CoreDocument = {
    page_count: page_facts.length(),
    capabilities: pdf_v2_core_supported_capabilities(),
    page_facts,
    warnings,
    risks,
    source_summary: pdf_v2_source_summary(
      events.length(),
      page_facts.length(),
      warnings.length(),
      risks.length(),
    ),
  }
  PdfV2CoreOpenResult::CoreOpenOk(core, events)
}

///|
fn pdf_v2_open_core_document_from_bytes(
  bytes : Bytes,
  source : String,
  options : PdfV2CoreOpenOptions,
) -> PdfV2CoreOpenResult {
  let input = @pdfio.Input::of_bytes(bytes.to_array(), source~)
  let reader = @pdfread.PdfRead::new(error_on_malformed=true, logger=_ => ())
  let pdf_result : Result[@pdf.Pdf, Error] = try
    @pdfe.with_silenced_logs(fn() raise {
      reader.pdf_of_input(None, None, input)
    })
    |> Ok
  catch {
    err => Err(err)
  }
  match pdf_result {
    Ok(pdf) => pdf_v2_adapter_core_from_pdf(pdf, reader, options)
    Err(err) => pdf_v2_adapter_read_error_result(err.to_string())
  }
}

///|
pub fn pdf_v2_open_core_document_from_path(
  path : String,
  options : PdfV2CoreOpenOptions,
) -> PdfV2CoreOpenResult {
  if !@fs.path_exists(path) {
    return pdf_v2_adapter_error_result(
      PdfV2WarningKind::MalformedObject,
      PdfV2RiskKind::ObjectGraphIssue,
      "PDF v2 adapter input path does not exist: " + path,
      ["path", "missing", "fail_closed", "no_fallback"],
    )
  }
  let bytes_result : Result[Bytes, Error] = try
    @fs.read_file_to_bytes(path) |> Ok
  catch {
    err => Err(err)
  }
  match bytes_result {
    Ok(bytes) => pdf_v2_open_core_document_from_bytes(bytes, path, options)
    Err(err) =>
      pdf_v2_adapter_error_result(
        PdfV2WarningKind::MalformedObject,
        PdfV2RiskKind::ObjectGraphIssue,
        "PDF v2 adapter could not read input path: " + err.to_string(),
        ["path", "read_error", "fail_closed", "no_fallback"],
      )
  }
}

///|
pub fn pdf_v2_open_source_document_from_path(
  path : String,
  options : PdfV2CoreOpenOptions,
) -> PdfV2SourceOpenResult {
  match pdf_v2_open_core_document_from_path(path, options) {
    CoreOpenOk(core, events) =>
      PdfV2SourceOpenResult::SourceOpenOk(
        pdf_v2_source_document_from_core(core, events),
      )
    CoreOpenErr(warnings, risks, message) =>
      PdfV2SourceOpenResult::SourceOpenErr(warnings, risks, message)
  }
}
