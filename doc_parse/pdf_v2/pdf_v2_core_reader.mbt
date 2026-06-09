///|
fn open_pdf_core_v2_scaffold_reader(
  bytes : Bytes,
  options : PdfV2CoreOpenOptions,
) -> PdfV2CoreDocument {
  let version = pdf_v2_probe_header_version(bytes)
  let source_ref = pdf_v2_source_ref_for_page(0)
  let warnings : Array[PdfV2Warning] = [
    pdf_v2_reader_base_removed_warning(version, source_ref),
  ]
  let risks : Array[PdfV2Risk] = [
    pdf_v2_reader_base_removed_risk(version, source_ref),
  ]
  let summary = pdf_v2_core_source_summary(bytes.length(), 0, true, options)
  {
    bytes_len: bytes.length(),
    version,
    page_count: 0,
    pages: [],
    objects: [],
    content_streams: [],
    text_events: [],
    capabilities: pdf_v2_core_capability_matrix(),
    warnings,
    risks,
    scanned_once: true,
    scan_boundary: options.scan_boundary,
    fallback_policy: options.fallback_policy,
    runtime_closure_policy: options.runtime_closure_policy,
    source_summary: summary,
  }
}

///|
fn pdf_v2_probe_header_version(bytes : Bytes) -> String? {
  let prefix = [0x25, 0x50, 0x44, 0x46, 0x2D] // %PDF-
  if bytes.length() < prefix.length() {
    return None
  }
  for i in 0..<prefix.length() {
    if bytes[i].to_int() != prefix[i] {
      return None
    }
  }
  let chars : Array[Char] = []
  let mut i = prefix.length()
  while i < bytes.length() {
    let value = bytes[i].to_int()
    if value == 0x0A || value == 0x0D || value == 0x20 || value == 0x09 {
      break
    }
    if !((value >= 0x30 && value <= 0x39) || value == 0x2E) {
      break
    }
    chars.push(bytes[i].to_char())
    i = i + 1
  }
  if chars.is_empty() {
    None
  } else {
    Some(String::from_array(chars))
  }
}

///|
fn pdf_v2_reader_base_removed_warning(
  version : String?,
  source_ref : PdfV2SourceRef,
) -> PdfV2Warning {
  let header_tag = match version {
    Some(_) => "pdf_header_recognized"
    None => "pdf_header_missing_or_malformed"
  }
  pdf_v2_warning_for_context(
    PdfV2WarningKind::PartialCapability,
    PdfV2Severity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::ObjectGraph,
      Some(source_ref),
      None,
      Some(0),
      [],
    ),
    "PDF v2 self-written core reader base has been removed; mbtpdf-backed base is planned",
    [
      "self_written_core_removed", "mbtpdf_backend_planned", "reader_scaffold_only",
      header_tag, "fail_closed", "no_fallback",
    ],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
priv struct PdfV2PerfTextState {
  mut in_text : Bool
  mut current_font_name : String?
  mut current_font_size : Double?
  mut current_extractor : @mbtpdf_text.TextExtractor?
  mut current_font_warnings : Array[PdfV2Warning]
  mut current_font_risks : Array[PdfV2Risk]
  mut text_object_id : Int
  mut content_order_index : Int
  mut text_x : Double
  mut text_y : Double
  mut leading : Double
  mut tm_a : Double
  mut tm_b : Double
  mut tm_c : Double
  mut tm_d : Double
  mut tm_e : Double
  mut tm_f : Double
}

///|
priv struct PdfV2PerfDecodedText {
  text : String
  confidence : Double
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
}

///|
priv struct PdfV2PerfFontLookup {
  extractor : @mbtpdf_text.TextExtractor?
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
}

///|
priv struct PdfV2PerfPageExtract {
  content_streams : Array[PdfV2CoreContentStream]
  text_events : Array[PdfV2CoreTextEvent]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
}

///|
fn open_pdf_core_v2_perf_reader(
  bytes : Bytes,
  options : PdfV2CoreOpenOptions,
) -> PdfV2CoreDocument {
  let version = pdf_v2_probe_header_version(bytes)
  let source_ref = pdf_v2_source_ref_for_page(0)
  if version is None {
    return pdf_v2_perf_fail_closed_document(
      bytes,
      options,
      version,
      PdfV2CoreCapabilityKind::ObjectGraph,
      "PDF header is missing or malformed",
      ["pdf_header_missing_or_malformed", "mbtpdf_backend_active"],
      source_ref,
    )
  }
  let input = @mbtpdf_io.Input::of_bytes(
    bytes.to_array(),
    source="pdf_v2_perf_bytes",
  )
  try
    @mbtpdf_pdfe.with_silenced_logs(fn() raise {
      @mbtpdf_read.PdfRead::new(error_on_malformed=true, logger=_ => ()).pdf_of_input_lazy(
        None,
        None,
        input,
      )
    })
  catch {
    err =>
      return pdf_v2_perf_fail_closed_document(
        bytes,
        options,
        version,
        PdfV2CoreCapabilityKind::ObjectGraph,
        "mbtpdf lazy PDF open failed: " + err.to_string(),
        ["mbtpdf_open_failed", "fail_closed", "no_fallback"],
        source_ref,
      )
  } noraise {
    pdf => pdf_v2_perf_document_from_mbtpdf(bytes, options, version, pdf)
  }
}

///|
fn pdf_v2_perf_document_from_mbtpdf(
  bytes : Bytes,
  options : PdfV2CoreOpenOptions,
  header_version : String?,
  pdf : @mbtpdf_pdf.Pdf,
) -> PdfV2CoreDocument {
  try
    @mbtpdf_pdfe.with_silenced_logs(fn() raise {
      @mbtpdf_page.PdfPageDoc::new(pdf).pages_of_pagetree()
    })
  catch {
    err =>
      return pdf_v2_perf_fail_closed_document(
        bytes,
        options,
        header_version,
        PdfV2CoreCapabilityKind::PageTree,
        "mbtpdf page tree traversal failed: " + err.to_string(),
        ["mbtpdf_page_tree_failed", "fail_closed", "no_fallback"],
        pdf_v2_source_ref_for_page(0),
      )
  } noraise {
    mbt_pages => {
      let warnings : Array[PdfV2Warning] = [
        pdf_v2_perf_backend_active_warning(header_version),
      ]
      let risks : Array[PdfV2Risk] = []
      let objects = pdf_v2_perf_collect_objects(pdf)
      let page_refs = pdf_v2_perf_page_reference_numbers(pdf, warnings)
      let pages : Array[PdfV2CorePage] = []
      let content_streams : Array[PdfV2CoreContentStream] = []
      let text_events : Array[PdfV2CoreTextEvent] = []
      for page_index = 0
          page_index < mbt_pages.length()
          page_index = page_index + 1 {
        let page = mbt_pages[page_index]
        let page_object_ref = if page_index < page_refs.length() {
          Some(pdf_v2_perf_object_ref(page_refs[page_index]))
        } else {
          None
        }
        let stream_refs = pdf_v2_perf_stream_refs_for_page(page, page_index)
        pages.push({
          page_index,
          boxes: pdf_v2_perf_page_boxes(pdf, page),
          rotation: page.rotate.to_int(),
          user_unit: None,
          object_ref: page_object_ref,
          content_stream_refs: stream_refs,
        })
        let extracted = pdf_v2_perf_extract_page(
          pdf, page, page_index, page_object_ref,
        )
        content_streams.append(extracted.content_streams)
        text_events.append(extracted.text_events)
        warnings.append(extracted.warnings)
        risks.append(extracted.risks)
      }
      let summary = pdf_v2_core_source_summary(
        bytes.length(),
        pages.length(),
        true,
        options,
      )
      {
        bytes_len: bytes.length(),
        version: Some(pdf.major.to_string() + "." + pdf.minor.to_string()),
        page_count: pages.length(),
        pages,
        objects,
        content_streams,
        text_events,
        capabilities: pdf_v2_core_capability_matrix(),
        warnings,
        risks,
        scanned_once: true,
        scan_boundary: options.scan_boundary,
        fallback_policy: options.fallback_policy,
        runtime_closure_policy: options.runtime_closure_policy,
        source_summary: summary,
      }
    }
  }
}

///|
fn pdf_v2_perf_collect_objects(pdf : @mbtpdf_pdf.Pdf) -> Array[PdfV2CoreObject] {
  let objects : Array[PdfV2CoreObject] = []
  pdf.objiter_gen(fn(object_number, generation, obj) {
    objects.push(pdf_v2_perf_core_object(pdf, object_number, generation, obj))
  })
  objects
}

///|
fn pdf_v2_perf_core_object(
  pdf : @mbtpdf_pdf.Pdf,
  object_number : Int,
  generation : Int,
  obj : @mbtpdf_pdf.PdfObject,
) -> PdfV2CoreObject {
  let object_ref = pdf_v2_perf_object_ref(object_number)
  let direct = pdf.direct(obj)
  {
    object_ref,
    object_number,
    generation,
    kind: pdf_v2_perf_object_kind(pdf, direct),
    raw: direct.to_string(),
    dictionary: pdf_v2_perf_dictionary_string(direct),
    stream_ref: if direct is @mbtpdf_pdf.PdfObject::Stream(_) {
      Some(object_ref + " stream")
    } else {
      None
    },
  }
}

///|
fn pdf_v2_perf_object_kind(
  pdf : @mbtpdf_pdf.Pdf,
  obj : @mbtpdf_pdf.PdfObject,
) -> PdfV2CoreObjectKind {
  match pdf.lookup_direct("/Type", obj) {
    Some(@mbtpdf_pdf.PdfObject::Name(name)) =>
      if name.equal_string_bytes("/Catalog") {
        PdfV2CoreObjectKind::Catalog
      } else if name.equal_string_bytes("/Pages") {
        PdfV2CoreObjectKind::Pages
      } else if name.equal_string_bytes("/Page") {
        PdfV2CoreObjectKind::Page
      } else if name.equal_string_bytes("/Font") {
        PdfV2CoreObjectKind::Font
      } else if obj is @mbtpdf_pdf.PdfObject::Stream(_) {
        PdfV2CoreObjectKind::Stream
      } else {
        PdfV2CoreObjectKind::Other
      }
    _ =>
      if obj is @mbtpdf_pdf.PdfObject::Stream(_) {
        PdfV2CoreObjectKind::Stream
      } else {
        PdfV2CoreObjectKind::Other
      }
  }
}

///|
fn pdf_v2_perf_dictionary_string(obj : @mbtpdf_pdf.PdfObject) -> String? {
  match obj {
    @mbtpdf_pdf.PdfObject::Dictionary(_) => Some(obj.to_string())
    @mbtpdf_pdf.PdfObject::Stream(r) => {
      let (dict, _) = r.val
      Some(dict.to_string())
    }
    _ => None
  }
}

///|
fn pdf_v2_perf_page_reference_numbers(
  pdf : @mbtpdf_pdf.Pdf,
  warnings : Array[PdfV2Warning],
) -> Array[Int] {
  pdf.page_reference_numbers() catch {
    err => {
      warnings.push(
        pdf_v2_warning_for_context(
          PdfV2WarningKind::MalformedObject,
          PdfV2Severity::Warning,
          pdf_v2_diagnostic_context(
            PdfV2CoreCapabilityKind::PageTree,
            None,
            None,
            None,
            [],
          ),
          "mbtpdf page object reference lookup failed: " + err.to_string(),
          ["mbtpdf_page_refs_failed", "source_ref_partial"],
          PdfV2Recoverability::RecoverableWithLoss,
        ),
      )
      []
    }
  }
}

///|
fn pdf_v2_perf_extract_page(
  pdf : @mbtpdf_pdf.Pdf,
  page : @mbtpdf_page.Page,
  page_index : Int,
  page_object_ref : String?,
) -> PdfV2PerfPageExtract {
  let content_streams = pdf_v2_perf_content_streams_for_page(
    pdf,
    page,
    page_index,
    true,
    [],
    [],
  )
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  let text_events : Array[PdfV2CoreTextEvent] = []
  try
    @mbtpdf_pdfe.with_silenced_logs(fn() raise {
      @mbtpdf_ops.Op::parse_operators_with_source(
        pdf,
        page.resources,
        page.content,
      )
    })
  catch {
    err => {
      let failed_streams = pdf_v2_perf_content_streams_for_page(
        pdf,
        page,
        page_index,
        false,
        [
          pdf_v2_perf_stream_decode_warning(
            "mbtpdf content stream operator parse/decode failed: " +
            err.to_string(),
            pdf_v2_source_ref_for_page(page_index),
            page_object_ref,
          ),
        ],
        [
          pdf_v2_perf_stream_decode_risk(
            "mbtpdf content stream operator parse/decode failed",
            pdf_v2_source_ref_for_page(page_index),
            page_object_ref,
          ),
        ],
      )
      for stream in failed_streams {
        warnings.append(stream.warnings)
        risks.append(stream.risks)
      }
      { content_streams: failed_streams, text_events, warnings, risks }
    }
  } noraise {
    ops => {
      let text_extract = pdf_v2_perf_text_events_from_ops(
        pdf,
        page.resources,
        ops,
        page_index,
        page_object_ref,
      )
      text_events.append(text_extract.text_events)
      warnings.append(text_extract.warnings)
      risks.append(text_extract.risks)
      { content_streams, text_events, warnings, risks }
    }
  }
}

///|
fn pdf_v2_perf_text_events_from_ops(
  pdf : @mbtpdf_pdf.Pdf,
  resources : @mbtpdf_pdf.PdfObject,
  ops : Array[@mbtpdf_ops.LocatedOp],
  page_index : Int,
  page_object_ref : String?,
) -> PdfV2PerfPageExtract {
  let state = Ref(pdf_v2_perf_default_text_state())
  let text_reader = @mbtpdf_text.PdfText::new(pdf)
  let extractor_cache : Map[String, @mbtpdf_text.TextExtractor] = Map([])
  let text_events : Array[PdfV2CoreTextEvent] = []
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  fn source_ref_for_located(
    located : @mbtpdf_ops.LocatedOp,
    content_order_index : Int?,
  ) -> PdfV2SourceRef {
    {
      page_index,
      object_ref: pdf_v2_perf_object_ref_from_option(located.source_object_ref),
      stream_index: Some(located.source_stream_index),
      op_index: Some(located.source_op_index),
      content_order_index,
      text_object_id: Some(state.val.text_object_id),
    }
  }

  fn lookup_font(font_name : String, located : @mbtpdf_ops.LocatedOp) -> Unit {
    let source_ref = source_ref_for_located(located, None)
    let lookup = pdf_v2_perf_lookup_text_extractor(
      pdf, text_reader, resources, font_name, extractor_cache, page_index, source_ref,
    )
    state.val.current_font_name = Some(font_name)
    state.val.current_extractor = lookup.extractor
    state.val.current_font_warnings = lookup.warnings
    state.val.current_font_risks = lookup.risks
  }

  fn append_text_event(
    operator : String,
    raw_text : String,
    located : @mbtpdf_ops.LocatedOp,
  ) -> Unit {
    if !state.val.in_text {
      let source_ref = source_ref_for_located(located, None)
      warnings.push(
        pdf_v2_warning_for_context(
          PdfV2WarningKind::MalformedObject,
          PdfV2Severity::Warning,
          pdf_v2_diagnostic_context(
            PdfV2CoreCapabilityKind::TextOperator,
            Some(source_ref),
            source_ref.object_ref,
            Some(page_index),
            [],
          ),
          "text-showing operator appears outside BT/ET",
          ["malformed_text_object", "text_operator", "no_silent_loss"],
          PdfV2Recoverability::RecoverableWithLoss,
        ),
      )
      return
    }
    let order = state.val.content_order_index
    state.val.content_order_index = order + 1
    let source_ref = source_ref_for_located(located, Some(order))
    let object_ref = pdf_v2_perf_first_string(
      source_ref.object_ref,
      page_object_ref,
    )
    let decoded = pdf_v2_perf_decode_text(
      state.val.current_extractor,
      raw_text,
      source_ref,
      object_ref,
    )
    let event_warnings = state.val.current_font_warnings + decoded.warnings
    let event_risks = state.val.current_font_risks + decoded.risks
    let stream_ref = pdf_v2_perf_stream_ref(
      page_index,
      located.source_stream_index,
      located.source_object_ref,
    )
    text_events.push({
      id: "pdf_v2_perf_text_" + page_index.to_string() + "_" + order.to_string(),
      page_index,
      content_order_index: order,
      object_ref,
      stream_ref: Some(stream_ref),
      stream_index: Some(located.source_stream_index),
      op_index: Some(located.source_op_index),
      text_object_id: Some(state.val.text_object_id),
      operator,
      text: decoded.text,
      raw_bytes: Some(Bytes::from_array(@mbtpdf_io.bytes_of_string(raw_text))),
      font_name: state.val.current_font_name,
      font_size: state.val.current_font_size,
      origin: Some({ x: state.val.text_x, y: state.val.text_y }),
      text_matrix: [
        state.val.tm_a,
        state.val.tm_b,
        state.val.tm_c,
        state.val.tm_d,
        state.val.tm_e,
        state.val.tm_f,
      ],
      decode_confidence: decoded.confidence,
      warnings: event_warnings,
      risks: event_risks,
      source_ref,
      reason_tags: [
        "mbtpdf_backend_active", "source_event_text_operator", "lazy_stream_decode",
        "batch_glyph_decode", "no_fallback",
      ] +
      decoded.reason_tags,
    })
  }

  for located in ops {
    match located.op {
      @mbtpdf_ops.Op::OpBT => {
        state.val.in_text = true
        state.val.text_object_id = state.val.text_object_id + 1
        pdf_v2_perf_reset_text_geometry(state)
      }
      @mbtpdf_ops.Op::OpET => {
        state.val.in_text = false
        state.val.current_extractor = None
      }
      @mbtpdf_ops.Op::OpTf(name, size) =>
        if state.val.in_text {
          state.val.current_font_size = Some(size)
          lookup_font(name, located)
        }
      @mbtpdf_ops.Op::OpTd(tx, ty) =>
        if state.val.in_text {
          pdf_v2_perf_move_text_matrix(state, tx, ty)
        }
      @mbtpdf_ops.Op::OpTD(tx, ty) =>
        if state.val.in_text {
          state.val.leading = -ty
          pdf_v2_perf_move_text_matrix(state, tx, ty)
        }
      @mbtpdf_ops.Op::OpTm(m) =>
        if state.val.in_text {
          state.val.tm_a = m.a
          state.val.tm_b = m.b
          state.val.tm_c = m.c
          state.val.tm_d = m.d
          state.val.tm_e = m.e
          state.val.tm_f = m.f
          pdf_v2_perf_sync_origin_from_text_matrix(state)
        }
      @mbtpdf_ops.Op::OpTStar =>
        if state.val.in_text {
          pdf_v2_perf_move_text_matrix(state, 0.0, -state.val.leading)
        }
      @mbtpdf_ops.Op::OpTj(value) => append_text_event("Tj", value, located)
      @mbtpdf_ops.Op::OpTJ(obj) =>
        append_text_event("TJ", pdf_v2_perf_text_from_tj_array(obj), located)
      @mbtpdf_ops.Op::OpSingleQuote(value) => {
        if state.val.in_text {
          pdf_v2_perf_move_text_matrix(state, 0.0, -state.val.leading)
        }
        append_text_event("'", value, located)
      }
      @mbtpdf_ops.Op::OpDoubleQuote(_, _, value) => {
        if state.val.in_text {
          pdf_v2_perf_move_text_matrix(state, 0.0, -state.val.leading)
        }
        append_text_event("\"", value, located)
      }
      @mbtpdf_ops.Op::OpUnknown(name) => {
        let source_ref = source_ref_for_located(located, None)
        warnings.push(
          pdf_v2_warning_for_context(
            PdfV2WarningKind::PartialCapability,
            PdfV2Severity::Warning,
            pdf_v2_diagnostic_context(
              PdfV2CoreCapabilityKind::GraphicsOperator,
              Some(source_ref),
              source_ref.object_ref,
              Some(page_index),
              [name],
            ),
            "unsupported or unknown content stream operator",
            ["unsupported_operator", "mbtpdf_operator", "no_fallback"],
            PdfV2Recoverability::RecoverableWithLoss,
          ),
        )
      }
      _ => ()
    }
  }
  { content_streams: [], text_events, warnings, risks }
}

///|
fn pdf_v2_perf_decode_text(
  extractor : @mbtpdf_text.TextExtractor?,
  raw_text : String,
  source_ref : PdfV2SourceRef,
  object_ref : String?,
) -> PdfV2PerfDecodedText {
  match extractor {
    Some(ext) => {
      let warnings : Array[PdfV2Warning] = []
      let risks : Array[PdfV2Risk] = []
      try ext.glyphnames_and_codepoints_of_text(raw_text) catch {
        err =>
          pdf_v2_perf_low_confidence_text(
            raw_text,
            source_ref,
            object_ref,
            "mbtpdf glyph decode failed: " + err.to_string(),
          )
      } noraise {
        pairs => {
          let builder = StringBuilder::new()
          let mut confidence = 1.0
          for pair in pairs {
            let part = @mbtpdf_text.PdfTextUtil::new().utf8_of_codepoints(
              pair.1,
            ) catch {
              _ => {
                confidence = 0.60
                pair.0
              }
            }
            builder.write_string(pdf_v2_perf_sanitize_text(part))
          }
          {
            text: builder.to_string(),
            confidence,
            warnings,
            risks,
            reason_tags: ["mbtpdf_text_extractor", "glyph_decode"],
          }
        }
      }
    }
    None =>
      pdf_v2_perf_low_confidence_text(
        raw_text, source_ref, object_ref, "font extractor is unavailable; raw text retained",
      )
  }
}

///|
fn pdf_v2_perf_low_confidence_text(
  raw_text : String,
  source_ref : PdfV2SourceRef,
  object_ref : String?,
  message : String,
) -> PdfV2PerfDecodedText {
  let warning = pdf_v2_warning_for_context(
    PdfV2WarningKind::GlyphDecodeLowConfidence,
    PdfV2Severity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::GlyphDecode,
      Some(source_ref),
      object_ref,
      Some(source_ref.page_index),
      [],
    ),
    message,
    ["glyph_decode_low_confidence", "text_retained", "no_fallback"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
  {
    text: pdf_v2_perf_sanitize_text(raw_text),
    confidence: 0.45,
    warnings: [warning],
    risks: [risk_glyph_decode_low_confidence(Some(source_ref), object_ref)],
    reason_tags: ["glyph_decode_low_confidence", "text_retained"],
  }
}

///|
fn pdf_v2_perf_lookup_text_extractor(
  pdf : @mbtpdf_pdf.Pdf,
  text_reader : @mbtpdf_text.PdfText,
  resources : @mbtpdf_pdf.PdfObject,
  font_name : String,
  cache : Map[String, @mbtpdf_text.TextExtractor],
  page_index : Int,
  source_ref : PdfV2SourceRef,
) -> PdfV2PerfFontLookup {
  if cache.get(font_name) is Some(extractor) {
    return { extractor: Some(extractor), warnings: [], risks: [] }
  }
  let font_resource = make_resource_ref(
    PdfV2ResourceKind::Font,
    font_name,
    page_index,
    source_ref.object_ref,
    Some(source_ref),
  )
  match pdf.lookup_direct("/Font", resources) {
    Some(fonts) =>
      match pdf.lookup_direct(font_name, fonts) {
        Some(font_obj) =>
          try text_reader.text_extractor_of_font(font_obj) catch {
            _ => {
              let warning = if pdf_v2_perf_type0_missing_tounicode(
                  pdf, font_obj,
                ) {
                warn_to_unicode_missing_or_malformed(font_resource).warning
              } else {
                warn_unknown_font_encoding(font_resource).warning
              }
              return {
                extractor: None,
                warnings: [warning],
                risks: [
                  risk_glyph_decode_low_confidence(
                    Some(source_ref),
                    source_ref.object_ref,
                  ),
                ],
              }
            }
          } noraise {
            extractor => {
              cache.set(font_name, extractor)
              let warnings = if pdf_v2_perf_type0_missing_tounicode(
                  pdf, font_obj,
                ) {
                [warn_to_unicode_missing_or_malformed(font_resource).warning]
              } else {
                []
              }
              { extractor: Some(extractor), warnings, risks: [] }
            }
          }
        None => {
          let warning = warn_missing_font_resource(font_resource).warning
          {
            extractor: None,
            warnings: [warning],
            risks: [
              risk_glyph_decode_low_confidence(
                Some(source_ref),
                source_ref.object_ref,
              ),
            ],
          }
        }
      }
    None => {
      let warning = warn_missing_font_resource(font_resource).warning
      {
        extractor: None,
        warnings: [warning],
        risks: [
          risk_glyph_decode_low_confidence(
            Some(source_ref),
            source_ref.object_ref,
          ),
        ],
      }
    }
  }
}

///|
fn pdf_v2_perf_type0_missing_tounicode(
  pdf : @mbtpdf_pdf.Pdf,
  font_obj : @mbtpdf_pdf.PdfObject,
) -> Bool {
  let direct = pdf.direct(font_obj)
  match pdf.lookup_direct("/Subtype", direct) {
    Some(@mbtpdf_pdf.PdfObject::Name(name)) =>
      name.equal_string_bytes("/Type0") &&
      pdf.lookup_direct("/ToUnicode", direct) is None
    _ => false
  }
}

///|
fn pdf_v2_perf_content_streams_for_page(
  pdf : @mbtpdf_pdf.Pdf,
  page : @mbtpdf_page.Page,
  page_index : Int,
  decode_supported : Bool,
  inherited_warnings : Array[PdfV2Warning],
  inherited_risks : Array[PdfV2Risk],
) -> Array[PdfV2CoreContentStream] {
  let streams : Array[PdfV2CoreContentStream] = []
  for stream_index = 0
      stream_index < page.content.length()
      stream_index = stream_index + 1 {
    let content = page.content[stream_index]
    let object_number = pdf_v2_perf_indirect_number(content)
    let object_ref = pdf_v2_perf_object_ref_from_option(object_number)
    let source_ref = {
      page_index,
      object_ref,
      stream_index: Some(stream_index),
      op_index: None,
      content_order_index: None,
      text_object_id: None,
    }
    streams.push({
      stream_ref: pdf_v2_perf_stream_ref(
        page_index, stream_index, object_number,
      ),
      object_ref,
      page_index,
      stream_index,
      raw_bytes: None,
      decoded_text: None,
      filter_names: pdf_v2_perf_filter_names(pdf, content),
      decode_supported,
      warnings: inherited_warnings,
      risks: inherited_risks,
      source_ref,
    })
  }
  streams
}

///|
fn pdf_v2_perf_stream_refs_for_page(
  page : @mbtpdf_page.Page,
  page_index : Int,
) -> Array[String] {
  let refs : Array[String] = []
  for stream_index = 0
      stream_index < page.content.length()
      stream_index = stream_index + 1 {
    refs.push(
      pdf_v2_perf_stream_ref(
        page_index,
        stream_index,
        pdf_v2_perf_indirect_number(page.content[stream_index]),
      ),
    )
  }
  refs
}

///|
fn pdf_v2_perf_filter_names(
  pdf : @mbtpdf_pdf.Pdf,
  stream : @mbtpdf_pdf.PdfObject,
) -> Array[String] {
  let direct = pdf.direct(stream)
  match pdf.lookup_direct("/Filter", direct) {
    Some(@mbtpdf_pdf.PdfObject::Name(name)) => [name.to_string_bytes()]
    Some(@mbtpdf_pdf.PdfObject::Array(values)) => {
      let names : Array[String] = []
      for value in values {
        match pdf.direct(value) {
          @mbtpdf_pdf.PdfObject::Name(name) =>
            names.push(name.to_string_bytes())
          _ => names.push("unknown_filter")
        }
      }
      names
    }
    Some(_) => ["malformed_filter"]
    None => []
  }
}

///|
fn pdf_v2_perf_page_boxes(
  pdf : @mbtpdf_pdf.Pdf,
  page : @mbtpdf_page.Page,
) -> PdfV2PageBoxes {
  let defaults = pdf_v2_default_boxes()
  {
    media_box: match pdf_v2_perf_rect_from_object(pdf, page.mediabox) {
      Some(rect) => rect
      None => defaults.media_box
    },
    crop_box: match page.cropbox {
      Some(crop) => pdf_v2_perf_rect_from_object(pdf, crop)
      None => None
    },
    bleed_box: None,
    trim_box: None,
    art_box: None,
  }
}

///|
fn pdf_v2_perf_rect_from_object(
  pdf : @mbtpdf_pdf.Pdf,
  obj : @mbtpdf_pdf.PdfObject,
) -> PdfV2Rect? {
  try pdf.parse_rectangle(obj) catch {
    _ => None
  } noraise {
    (x0, y0, x1, y1) => Some({ x0, y0, x1, y1 })
  }
}

///|
fn pdf_v2_perf_default_text_state() -> PdfV2PerfTextState {
  {
    in_text: false,
    current_font_name: None,
    current_font_size: None,
    current_extractor: None,
    current_font_warnings: [],
    current_font_risks: [],
    text_object_id: 0,
    content_order_index: 0,
    text_x: 0.0,
    text_y: 0.0,
    leading: 0.0,
    tm_a: 1.0,
    tm_b: 0.0,
    tm_c: 0.0,
    tm_d: 1.0,
    tm_e: 0.0,
    tm_f: 0.0,
  }
}

///|
fn pdf_v2_perf_reset_text_geometry(state : Ref[PdfV2PerfTextState]) -> Unit {
  state.val.text_x = 0.0
  state.val.text_y = 0.0
  state.val.leading = 0.0
  state.val.tm_a = 1.0
  state.val.tm_b = 0.0
  state.val.tm_c = 0.0
  state.val.tm_d = 1.0
  state.val.tm_e = 0.0
  state.val.tm_f = 0.0
}

///|
fn pdf_v2_perf_move_text_matrix(
  state : Ref[PdfV2PerfTextState],
  dx : Double,
  dy : Double,
) -> Unit {
  state.val.tm_e = state.val.tm_e + dx
  state.val.tm_f = state.val.tm_f + dy
  pdf_v2_perf_sync_origin_from_text_matrix(state)
}

///|
fn pdf_v2_perf_sync_origin_from_text_matrix(
  state : Ref[PdfV2PerfTextState],
) -> Unit {
  state.val.text_x = state.val.tm_e
  state.val.text_y = state.val.tm_f
}

///|
fn pdf_v2_perf_text_from_tj_array(obj : @mbtpdf_pdf.PdfObject) -> String {
  match obj {
    @mbtpdf_pdf.PdfObject::Array(values) => {
      let builder = StringBuilder::new()
      for value in values {
        match value {
          @mbtpdf_pdf.PdfObject::String(text) => builder.write_string(text)
          _ => ()
        }
      }
      builder.to_string()
    }
    @mbtpdf_pdf.PdfObject::String(text) => text
    _ => ""
  }
}

///|
fn pdf_v2_perf_sanitize_text(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text {
    let code = ch.to_int()
    if code < 0x20 && ch != '\n' && ch != '\r' && ch != '\t' {
      out.write_char(' ')
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn pdf_v2_perf_indirect_number(obj : @mbtpdf_pdf.PdfObject) -> Int? {
  match obj {
    @mbtpdf_pdf.PdfObject::Indirect(number) => Some(number)
    _ => None
  }
}

///|
fn pdf_v2_perf_object_ref(number : Int) -> String {
  number.to_string() + " 0 R"
}

///|
fn pdf_v2_perf_object_ref_from_option(number : Int?) -> String? {
  match number {
    Some(number) => Some(pdf_v2_perf_object_ref(number))
    None => None
  }
}

///|
fn pdf_v2_perf_first_string(primary : String?, fallback : String?) -> String? {
  match primary {
    Some(value) => Some(value)
    None => fallback
  }
}

///|
fn pdf_v2_perf_stream_ref(
  page_index : Int,
  stream_index : Int,
  object_number : Int?,
) -> String {
  match object_number {
    Some(number) =>
      pdf_v2_perf_object_ref(number) + " stream " + stream_index.to_string()
    None =>
      "page_" + page_index.to_string() + "_stream_" + stream_index.to_string()
  }
}

///|
fn pdf_v2_perf_backend_active_warning(version : String?) -> PdfV2Warning {
  let header_tag = match version {
    Some(_) => "pdf_header_recognized"
    None => "pdf_header_missing_or_malformed"
  }
  pdf_v2_warning_for_context(
    PdfV2WarningKind::PartialCapability,
    PdfV2Severity::Info,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::ObjectGraph,
      None,
      None,
      None,
      [],
    ),
    "PDF v2 perf reader uses mbtpdf-backed lazy core base",
    [
      "self_written_core_removed", "mbtpdf_backend_active", "lazy_stream_decode",
      "batch_glyph_decode", header_tag, "no_fallback",
    ],
    PdfV2Recoverability::Recoverable,
  )
}

///|
fn pdf_v2_perf_stream_decode_warning(
  message : String,
  source_ref : PdfV2SourceRef,
  object_ref : String?,
) -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::DecodeFailure,
    PdfV2Severity::Error,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::ContentStream,
      Some(source_ref),
      object_ref,
      Some(source_ref.page_index),
      [],
    ),
    message,
    ["mbtpdf_stream_decode_failed", "fail_closed", "no_fallback"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
fn pdf_v2_perf_stream_decode_risk(
  reason : String,
  source_ref : PdfV2SourceRef,
  object_ref : String?,
) -> PdfV2Risk {
  pdf_v2_risk_for_context(
    PdfV2RiskKind::DecodeFailure,
    PdfV2RiskSeverity::Error,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::ContentStream,
      Some(source_ref),
      object_ref,
      Some(source_ref.page_index),
      [],
    ),
    reason,
    ["mbtpdf_stream_decode_failed", "abstain_candidate", "no_fallback"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
fn pdf_v2_perf_fail_closed_document(
  bytes : Bytes,
  options : PdfV2CoreOpenOptions,
  version : String?,
  capability : PdfV2CoreCapabilityKind,
  message : String,
  reason_tags : Array[String],
  source_ref : PdfV2SourceRef,
) -> PdfV2CoreDocument {
  let warning = pdf_v2_warning_for_context(
    PdfV2WarningKind::MalformedObject,
    PdfV2Severity::Error,
    pdf_v2_diagnostic_context(capability, Some(source_ref), None, None, []),
    message,
    reason_tags +
    [
      "self_written_core_removed", "mbtpdf_backend_active", "fail_closed", "no_fallback",
    ],
    PdfV2Recoverability::RecoverableWithLoss,
  )
  let risk = pdf_v2_risk_for_context(
    PdfV2RiskKind::MalformedObject,
    PdfV2RiskSeverity::Error,
    pdf_v2_diagnostic_context(capability, Some(source_ref), None, None, []),
    message,
    reason_tags + ["abstain_candidate", "no_fallback"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
  let summary = pdf_v2_core_source_summary(bytes.length(), 0, true, options)
  {
    bytes_len: bytes.length(),
    version,
    page_count: 0,
    pages: [],
    objects: [],
    content_streams: [],
    text_events: [],
    capabilities: pdf_v2_core_capability_matrix(),
    warnings: [warning],
    risks: [risk],
    scanned_once: true,
    scan_boundary: options.scan_boundary,
    fallback_policy: options.fallback_policy,
    runtime_closure_policy: options.runtime_closure_policy,
    source_summary: summary,
  }
}

///|
fn pdf_v2_reader_base_removed_risk(
  version : String?,
  source_ref : PdfV2SourceRef,
) -> PdfV2Risk {
  let header_tag = match version {
    Some(_) => "pdf_header_recognized"
    None => "pdf_header_missing_or_malformed"
  }
  pdf_v2_risk_for_context(
    PdfV2RiskKind::PartialCapability,
    PdfV2RiskSeverity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::ObjectGraph,
      Some(source_ref),
      None,
      Some(0),
      [],
    ),
    "PDF v2 core reader is scaffold-only until the mbtpdf-backed performance base is integrated",
    [
      "self_written_core_removed", "mbtpdf_backend_planned", "reader_scaffold_only",
      header_tag, "abstain_candidate", "no_fallback",
    ],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}
