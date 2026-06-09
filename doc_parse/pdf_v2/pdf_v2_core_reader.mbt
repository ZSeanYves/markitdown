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
  mut current_tounicode : PdfV2PerfToUnicodeMap?
  mut current_font_warnings : Array[PdfV2Warning]
  mut current_font_risks : Array[PdfV2Risk]
  mut current_font_reason_tags : Array[String]
  mut text_object_id : Int
  mut content_order_index : Int
  mut text_x : Double
  mut text_y : Double
  mut leading : Double
  mut char_spacing : Double
  mut word_spacing : Double
  mut horizontal_scaling : Double
  mut rendering_mode : Int
  mut text_rise : Double
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
priv struct PdfV2PerfToUnicodeMap {
  map : Map[String, String]
  code_lengths : Array[Int]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
  malformed : Bool
}

///|
priv struct PdfV2PerfCodespaceParse {
  next_index : Int
  malformed : Bool
}

///|
priv struct PdfV2PerfFontFacts {
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
}

///|
priv struct PdfV2PerfFontLookup {
  extractor : @mbtpdf_text.TextExtractor?
  tounicode : PdfV2PerfToUnicodeMap?
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
}

///|
priv struct PdfV2PerfDiagnostics {
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
}

///|
priv struct PdfV2PerfInstrumentation {
  mut decoded_stream_count : Int
  mut decoded_stream_total_bytes : Int
  mut max_decoded_stream_bytes : Int
  mut content_stream_count : Int
  mut page_count : Int
  mut text_event_count : Int
  mut glyph_or_char_count : Int
  mut decode_failure_count : Int
}

///|
priv struct PdfV2PerfPageExtract {
  content_streams : Array[PdfV2CoreContentStream]
  text_events : Array[PdfV2CoreTextEvent]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  instrumentation : PdfV2PerfInstrumentation
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
    err => {
      let encrypted_tags = if pdf_v2_perf_bytes_contain_ascii(bytes, "/Encrypt") {
        ["encrypted_pdf_detected", "encrypted_pdf_unsupported"]
      } else {
        []
      }
      return pdf_v2_perf_fail_closed_document(
        bytes,
        options,
        version,
        if encrypted_tags.is_empty() {
          PdfV2CoreCapabilityKind::ObjectGraph
        } else {
          PdfV2CoreCapabilityKind::EncryptionMetadata
        },
        "mbtpdf lazy PDF open failed: " + err.to_string(),
        encrypted_tags + ["mbtpdf_open_failed", "fail_closed", "no_fallback"],
        source_ref,
      )
    }
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
  if pdf.saved_encryption is Some(_) ||
    pdf.lookup_direct("/Encrypt", pdf.trailerdict) is Some(_) {
    return pdf_v2_perf_fail_closed_document(
      bytes,
      options,
      header_version,
      PdfV2CoreCapabilityKind::EncryptionMetadata,
      "encrypted PDF detected by mbtpdf; PDF v2 perf reader fails closed",
      ["encrypted_pdf_detected", "encrypted_pdf_unsupported"],
      pdf_v2_source_ref_for_page(0),
    )
  }
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
      let structure = pdf_v2_perf_document_structure_diagnostics(pdf, objects)
      warnings.append(structure.warnings)
      risks.append(structure.risks)
      let page_refs = pdf_v2_perf_page_reference_numbers(pdf, warnings)
      let pages : Array[PdfV2CorePage] = []
      let content_streams : Array[PdfV2CoreContentStream] = []
      let text_events : Array[PdfV2CoreTextEvent] = []
      let mut instrumentation = pdf_v2_perf_empty_instrumentation()
      instrumentation.page_count = mbt_pages.length()
      for page_index = 0
          page_index < mbt_pages.length()
          page_index = page_index + 1 {
        let page = mbt_pages[page_index]
        let page_object_number = if page_index < page_refs.length() {
          Some(page_refs[page_index])
        } else {
          None
        }
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
          pdf, page, page_index, page_object_number, page_object_ref,
        )
        content_streams.append(extracted.content_streams)
        text_events.append(extracted.text_events)
        warnings.append(extracted.warnings)
        risks.append(extracted.risks)
        instrumentation = pdf_v2_perf_merge_instrumentation(
          instrumentation,
          extracted.instrumentation,
        )
      }
      instrumentation.text_event_count = text_events.length()
      instrumentation.glyph_or_char_count = pdf_v2_perf_text_event_char_count(
        text_events,
      )
      warnings.push(pdf_v2_perf_instrumentation_warning(instrumentation))
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
  page_object_number : Int?,
  page_object_ref : String?,
) -> PdfV2PerfPageExtract {
  let page_source_ref = pdf_v2_source_ref_for_page(page_index)
  let static_diagnostics = pdf_v2_perf_page_static_resource_diagnostics(
    pdf, page, page_index, page_object_number, page_object_ref,
  )
  let instrumentation = pdf_v2_perf_empty_instrumentation()
  instrumentation.content_stream_count = page.content.length()
  let stream_diagnostics = pdf_v2_perf_stream_filter_diagnostics(
    pdf, page, page_index, page_object_ref, true,
  )
  let content_streams = pdf_v2_perf_content_streams_for_page(
    pdf,
    page,
    page_index,
    true,
    stream_diagnostics.warnings,
    stream_diagnostics.risks,
  )
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  warnings.append(static_diagnostics.warnings)
  warnings.append(stream_diagnostics.warnings)
  risks.append(static_diagnostics.risks)
  risks.append(stream_diagnostics.risks)
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
            page_source_ref,
            page_object_ref,
          ),
        ],
        [
          pdf_v2_perf_stream_decode_risk(
            "mbtpdf content stream operator parse/decode failed", page_source_ref,
            page_object_ref,
          ),
        ],
      )
      for stream in failed_streams {
        warnings.append(stream.warnings)
        risks.append(stream.risks)
      }
      instrumentation.decode_failure_count = page.content.length()
      {
        content_streams: failed_streams,
        text_events,
        warnings,
        risks,
        instrumentation,
      }
    }
  } noraise {
    ops => {
      let op_diagnostics = pdf_v2_perf_page_op_resource_diagnostics(
        pdf,
        page.resources,
        ops,
        page_index,
        page_object_ref,
      )
      warnings.append(op_diagnostics.warnings)
      risks.append(op_diagnostics.risks)
      instrumentation.decoded_stream_count = page.content.length()
      instrumentation.decoded_stream_total_bytes = pdf_v2_perf_decoded_stream_total_bytes(
        pdf, page,
      )
      instrumentation.max_decoded_stream_bytes = pdf_v2_perf_max_decoded_stream_bytes(
        pdf, page,
      )
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
      { content_streams, text_events, warnings, risks, instrumentation }
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
    state.val.current_tounicode = lookup.tounicode
    state.val.current_font_warnings = lookup.warnings
    state.val.current_font_risks = lookup.risks
    state.val.current_font_reason_tags = lookup.reason_tags
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
      state.val.current_tounicode,
      raw_text,
      source_ref,
      object_ref,
    )
    let positioning_warning = pdf_v2_perf_positioning_detail_warning(
      source_ref,
      object_ref,
      state.val,
    )
    let event_warnings = state.val.current_font_warnings +
      decoded.warnings +
      [positioning_warning]
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
      state.val.current_font_reason_tags +
      pdf_v2_perf_text_state_reason_tags(state.val) +
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
        state.val.current_tounicode = None
      }
      @mbtpdf_ops.Op::OpTf(name, size) =>
        if state.val.in_text {
          state.val.current_font_size = Some(size)
          lookup_font(name, located)
        }
      @mbtpdf_ops.Op::OpTc(value) =>
        if state.val.in_text {
          state.val.char_spacing = value
        }
      @mbtpdf_ops.Op::OpTw(value) =>
        if state.val.in_text {
          state.val.word_spacing = value
        }
      @mbtpdf_ops.Op::OpTz(value) =>
        if state.val.in_text {
          state.val.horizontal_scaling = value
        }
      @mbtpdf_ops.Op::OpTL(value) =>
        if state.val.in_text {
          state.val.leading = value
        }
      @mbtpdf_ops.Op::OpTr(value) =>
        if state.val.in_text {
          state.val.rendering_mode = value
        }
      @mbtpdf_ops.Op::OpTs(value) =>
        if state.val.in_text {
          state.val.text_rise = value
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
      @mbtpdf_ops.Op::OpDoubleQuote(word_spacing, char_spacing, value) => {
        if state.val.in_text {
          state.val.word_spacing = word_spacing
          state.val.char_spacing = char_spacing
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
  {
    content_streams: [],
    text_events,
    warnings,
    risks,
    instrumentation: pdf_v2_perf_empty_instrumentation(),
  }
}

///|
fn pdf_v2_perf_decode_text(
  extractor : @mbtpdf_text.TextExtractor?,
  tounicode : PdfV2PerfToUnicodeMap?,
  raw_text : String,
  source_ref : PdfV2SourceRef,
  object_ref : String?,
) -> PdfV2PerfDecodedText {
  match tounicode {
    Some(cmap) =>
      return pdf_v2_perf_decode_text_with_tounicode(
        cmap, raw_text, source_ref, object_ref,
      )
    None => ()
  }
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
          let used_fallback = Ref(false)
          for pair in pairs {
            let part = @mbtpdf_text.PdfTextUtil::new().utf8_of_codepoints(
              pair.1,
            ) catch {
              _ => {
                confidence = 0.60
                used_fallback.val = true
                pair.0
              }
            }
            builder.write_string(pdf_v2_perf_sanitize_text(part))
          }
          let decode_reason_tags = if used_fallback.val {
            [
              "mbtpdf_text_extractor", "glyph_decode", "glyph_decode_best_effort",
            ]
          } else {
            ["mbtpdf_text_extractor", "glyph_decode"]
          }
          {
            text: builder.to_string(),
            confidence,
            warnings,
            risks,
            reason_tags: decode_reason_tags,
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
fn pdf_v2_perf_decode_text_with_tounicode(
  cmap : PdfV2PerfToUnicodeMap,
  raw_text : String,
  source_ref : PdfV2SourceRef,
  object_ref : String?,
) -> PdfV2PerfDecodedText {
  let decoded = StringBuilder::new()
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  let tags : Array[String] = [
    "decode_source_tounicode", "tonyfettes_unicode_helper", "tonyfettes_encoding_utf16be",
  ]
  tags.append(cmap.reason_tags)
  let bytes = @mbtpdf_io.int_array_of_bytes(
    @mbtpdf_io.bytes_of_string(raw_text),
  )
  let lengths = pdf_v2_perf_tounicode_decode_lengths(cmap, bytes.length())
  let mut i = 0
  let mut confidence = if cmap.malformed { 0.72 } else { 0.98 }
  let mut unmapped = false
  while i < bytes.length() {
    let mut matched = false
    for length in lengths {
      if !matched && length > 0 && i + length <= bytes.length() {
        let key = pdf_v2_perf_bytes_key(bytes, i, length)
        match cmap.map.get(key) {
          Some(value) => {
            decoded.write_string(pdf_v2_perf_sanitize_text(value))
            i = i + length
            matched = true
          }
          None => ()
        }
      }
    }
    if !matched {
      let fallback_length = pdf_v2_perf_tounicode_fallback_length(
        lengths,
        bytes.length() - i,
      )
      decoded.write_string(
        pdf_v2_perf_sanitize_text(
          pdf_v2_perf_raw_bytes_text(bytes, i, fallback_length),
        ),
      )
      i = i + fallback_length
      confidence = if confidence > 0.55 { 0.55 } else { confidence }
      unmapped = true
    }
  }
  if unmapped {
    warnings.push(
      pdf_v2_perf_warning(
        PdfV2WarningKind::GlyphDecodeLowConfidence,
        PdfV2Severity::Warning,
        PdfV2CoreCapabilityKind::GlyphDecode,
        Some(source_ref),
        object_ref,
        Some(source_ref.page_index),
        "ToUnicode map did not cover every text code; raw text was retained for unmapped bytes",
        [
          "tounicode_unmapped_code", "glyph_decode_low_confidence", "text_retained",
        ],
        PdfV2Recoverability::RecoverableWithLoss,
      ),
    )
    risks.push(risk_glyph_decode_low_confidence(Some(source_ref), object_ref))
    tags.push("tounicode_unmapped_code")
    tags.push("glyph_decode_low_confidence")
    tags.push("text_retained")
  }
  if cmap.malformed {
    tags.push("bad_tounicode_handled")
  }
  {
    text: decoded.to_string(),
    confidence,
    warnings: cmap.warnings + warnings,
    risks: cmap.risks + risks,
    reason_tags: tags,
  }
}

///|
fn pdf_v2_perf_tounicode_decode_lengths(
  cmap : PdfV2PerfToUnicodeMap,
  remaining : Int,
) -> Array[Int] {
  let lengths = if cmap.code_lengths.length() == 0 {
    [1]
  } else {
    cmap.code_lengths.copy()
  }
  lengths.sort_by(fn(a, b) { b.compare(a) })
  let out : Array[Int] = []
  for length in lengths {
    if length > 0 && length <= remaining && !out.contains(length) {
      out.push(length)
    }
  }
  if out.is_empty() {
    [1]
  } else {
    out
  }
}

///|
fn pdf_v2_perf_tounicode_fallback_length(
  lengths : Array[Int],
  remaining : Int,
) -> Int {
  if remaining <= 0 {
    return 1
  }
  for length in lengths {
    if length > 0 && length <= remaining {
      return length
    }
  }
  1
}

///|
fn pdf_v2_perf_raw_bytes_text(
  bytes : Array[Int],
  start : Int,
  length : Int,
) -> String {
  let end = if start + length > bytes.length() {
    bytes.length()
  } else {
    start + length
  }
  let out : Array[Int] = []
  for i in start..<end {
    out.push(bytes[i])
  }
  @mbtpdf_io.string_of_int_array(out)
}

///|
fn pdf_v2_perf_bytes_key(
  bytes : Array[Int],
  start : Int,
  length : Int,
) -> String {
  pdf_v2_perf_raw_bytes_text(bytes, start, length)
}

///|
fn pdf_v2_perf_build_tounicode_map(
  pdf : @mbtpdf_pdf.Pdf,
  font_obj : @mbtpdf_pdf.PdfObject,
  page_index : Int,
  source_ref : PdfV2SourceRef,
) -> PdfV2PerfToUnicodeMap? {
  match pdf.lookup_direct("/ToUnicode", pdf.direct(font_obj)) {
    None => None
    Some(tounicode_obj) => {
      let object_ref = pdf_v2_perf_object_ref_from_option(
        pdf_v2_perf_indirect_number(tounicode_obj),
      )
      match pdf_v2_perf_tounicode_stream_text(pdf, tounicode_obj) {
        Ok(cmap_text) =>
          Some(
            pdf_v2_perf_parse_tounicode_cmap(
              cmap_text,
              page_index,
              source_ref,
              pdf_v2_perf_first_string(object_ref, source_ref.object_ref),
            ),
          )
        Err(message) => {
          let warning = pdf_v2_perf_warning(
            PdfV2WarningKind::DecodeFailure,
            PdfV2Severity::Warning,
            PdfV2CoreCapabilityKind::ToUnicode,
            Some(source_ref),
            pdf_v2_perf_first_string(object_ref, source_ref.object_ref),
            Some(page_index),
            "ToUnicode stream could not be decoded: " + message,
            ["tounicode_malformed", "bad_tounicode_handled", "text_retained"],
            PdfV2Recoverability::RecoverableWithLoss,
          )
          let risk = pdf_v2_risk_for_context(
            PdfV2RiskKind::DecodeFailure,
            PdfV2RiskSeverity::Warning,
            pdf_v2_diagnostic_context(
              PdfV2CoreCapabilityKind::ToUnicode,
              Some(source_ref),
              pdf_v2_perf_first_string(object_ref, source_ref.object_ref),
              Some(page_index),
              [],
            ),
            "ToUnicode stream decode failed; PDF v2 retains low-confidence raw text",
            [
              "tounicode_malformed", "bad_tounicode_handled", "text_retained", "no_fallback",
            ],
            PdfV2Recoverability::RecoverableWithLoss,
          )
          Some({
            map: Map([]),
            code_lengths: [1],
            warnings: [warning],
            risks: [risk],
            reason_tags: [
              "decode_source_tounicode", "bad_tounicode_handled", "tonyfettes_unicode_helper",
              "tonyfettes_encoding_utf16be",
            ],
            malformed: true,
          })
        }
      }
    }
  }
}

///|
fn pdf_v2_perf_tounicode_stream_text(
  pdf : @mbtpdf_pdf.Pdf,
  tounicode_obj : @mbtpdf_pdf.PdfObject,
) -> Result[String, String] {
  let direct = pdf.direct(tounicode_obj)
  try {
    @mbtpdf_codec.PdfCodec::new().decode_pdfstream(pdf, direct)
    direct.getstream()
    match direct {
      @mbtpdf_pdf.PdfObject::Stream(r) =>
        match r.val {
          (_, @mbtpdf_pdf.Stream::Got(bytes)) =>
            Ok(@mbtpdf_io.string_of_bytes(bytes))
          _ => Err("decoded stream bytes are unavailable")
        }
      _ => Err("ToUnicode object is not a stream")
    }
  } catch {
    err => Err(err.to_string())
  }
}

///|
fn pdf_v2_perf_parse_tounicode_cmap(
  cmap_text : String,
  page_index : Int,
  source_ref : PdfV2SourceRef,
  object_ref : String?,
) -> PdfV2PerfToUnicodeMap {
  let tokens = pdf_v2_perf_cmap_tokens(cmap_text)
  let map : Map[String, String] = Map([])
  let code_lengths : Array[Int] = []
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  let reason_tags : Array[String] = [
    "decode_source_tounicode", "tonyfettes_unicode_helper", "tonyfettes_encoding_utf16be",
  ]
  let malformed = Ref(false)
  let mut i = 0
  while i < tokens.length() {
    match tokens[i] {
      "begincodespacerange" => {
        let parsed = pdf_v2_perf_parse_codespace_range(
          tokens,
          i + 1,
          code_lengths,
          reason_tags,
        )
        if parsed.malformed {
          malformed.val = true
        }
        i = parsed.next_index
      }
      "beginbfchar" => {
        let parsed = pdf_v2_perf_parse_bfchar_range(
          tokens,
          i + 1,
          map,
          code_lengths,
          reason_tags,
        )
        if parsed.1 {
          malformed.val = true
        }
        i = parsed.0
      }
      "beginbfrange" => {
        let parsed = pdf_v2_perf_parse_bfrange_range(
          tokens,
          i + 1,
          map,
          code_lengths,
          reason_tags,
        )
        if parsed.1 {
          malformed.val = true
        }
        i = parsed.0
      }
      _ => i = i + 1
    }
  }
  if malformed.val && map.length() > 0 {
    warnings.push(
      pdf_v2_perf_tounicode_malformed_warning(
        source_ref, object_ref, page_index, "ToUnicode CMap contained malformed entries; usable mappings were retained",
      ),
    )
    risks.push(
      pdf_v2_perf_tounicode_malformed_risk(
        source_ref, object_ref, page_index, "ToUnicode CMap had malformed entries; PDF v2 retains decoded and raw text evidence",
      ),
    )
  }
  if map.length() == 0 {
    malformed.val = true
    warnings.push(
      pdf_v2_perf_warning(
        PdfV2WarningKind::GlyphDecodeLowConfidence,
        PdfV2Severity::Warning,
        PdfV2CoreCapabilityKind::ToUnicode,
        Some(source_ref),
        object_ref,
        Some(page_index),
        "ToUnicode CMap did not yield usable bfchar/bfrange mappings",
        ["tounicode_malformed", "bad_tounicode_handled", "text_retained"],
        PdfV2Recoverability::RecoverableWithLoss,
      ),
    )
    risks.push(
      pdf_v2_risk_for_context(
        PdfV2RiskKind::GlyphDecodeLowConfidence,
        PdfV2RiskSeverity::Warning,
        pdf_v2_diagnostic_context(
          PdfV2CoreCapabilityKind::ToUnicode,
          Some(source_ref),
          object_ref,
          Some(page_index),
          [],
        ),
        "ToUnicode CMap parse produced no usable mappings",
        [
          "tounicode_malformed", "bad_tounicode_handled", "text_retained", "no_fallback",
        ],
        PdfV2Recoverability::RecoverableWithLoss,
      ),
    )
  }
  if malformed.val {
    reason_tags.push("bad_tounicode_handled")
  }
  if code_lengths.is_empty() {
    code_lengths.push(1)
  }
  { map, code_lengths, warnings, risks, reason_tags, malformed: malformed.val }
}

///|
fn pdf_v2_perf_parse_codespace_range(
  tokens : Array[String],
  start : Int,
  code_lengths : Array[Int],
  reason_tags : Array[String],
) -> PdfV2PerfCodespaceParse {
  let mut i = start
  let mut malformed = false
  let mut applied = false
  let mut multibyte = false
  let mut variable = false
  while i < tokens.length() && tokens[i] != "endcodespacerange" {
    if i + 1 < tokens.length() &&
      pdf_v2_perf_is_hex_token(tokens[i]) &&
      pdf_v2_perf_is_hex_token(tokens[i + 1]) {
      let low_length = pdf_v2_perf_hex_token_byte_length(tokens[i])
      let high_length = pdf_v2_perf_hex_token_byte_length(tokens[i + 1])
      pdf_v2_perf_record_code_length(code_lengths, low_length)
      pdf_v2_perf_record_code_length(code_lengths, high_length)
      applied = true
      if low_length > 1 || high_length > 1 {
        multibyte = true
      }
      if low_length != high_length {
        variable = true
      }
      i = i + 2
    } else {
      malformed = true
      i = i + 1
    }
  }
  if i >= tokens.length() {
    malformed = true
  }
  if applied {
    reason_tags.push("tounicode_codespace_applied")
  }
  if multibyte {
    reason_tags.push("tounicode_codespace_multibyte")
  }
  if variable {
    reason_tags.push("tounicode_codespace_variable_width")
  }
  if malformed {
    reason_tags.push("tounicode_codespace_malformed")
  }
  { next_index: if i < tokens.length() { i + 1 } else { i }, malformed }
}

///|
fn pdf_v2_perf_note_source_code_length(
  length : Int,
  reason_tags : Array[String],
) -> Unit {
  if length > 1 {
    pdf_v2_perf_push_unique_tag(reason_tags, "tounicode_source_multibyte")
  }
  match length {
    2 => pdf_v2_perf_push_unique_tag(reason_tags, "tounicode_source_2byte")
    3 => pdf_v2_perf_push_unique_tag(reason_tags, "tounicode_source_3byte")
    4 => pdf_v2_perf_push_unique_tag(reason_tags, "tounicode_source_4byte")
    _ => ()
  }
}

///|
fn pdf_v2_perf_push_unique_tag(
  reason_tags : Array[String],
  tag : String,
) -> Unit {
  if !reason_tags.contains(tag) {
    reason_tags.push(tag)
  }
}

///|
fn pdf_v2_perf_tounicode_malformed_warning(
  source_ref : PdfV2SourceRef,
  object_ref : String?,
  page_index : Int,
  detail : String,
) -> PdfV2Warning {
  pdf_v2_perf_warning(
    PdfV2WarningKind::GlyphDecodeLowConfidence,
    PdfV2Severity::Warning,
    PdfV2CoreCapabilityKind::Cmap,
    Some(source_ref),
    object_ref,
    Some(page_index),
    detail,
    ["tounicode_malformed", "bad_tounicode_handled", "text_retained"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
fn pdf_v2_perf_tounicode_malformed_risk(
  source_ref : PdfV2SourceRef,
  object_ref : String?,
  page_index : Int,
  detail : String,
) -> PdfV2Risk {
  pdf_v2_risk_for_context(
    PdfV2RiskKind::GlyphDecodeLowConfidence,
    PdfV2RiskSeverity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::Cmap,
      Some(source_ref),
      object_ref,
      Some(page_index),
      [],
    ),
    detail,
    [
      "tounicode_malformed", "bad_tounicode_handled", "text_retained", "no_fallback",
    ],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
fn pdf_v2_perf_note_tounicode_target(
  token : String,
  reason_tags : Array[String],
) -> Unit {
  match pdf_v2_perf_decode_tounicode_hex_as_codepoints(token) {
    Some(codepoints) => {
      if codepoints.length() > 1 {
        pdf_v2_perf_push_unique_tag(
          reason_tags, "tounicode_target_multi_codepoint",
        )
      }
      for cp in codepoints {
        if cp > 0xFFFF {
          pdf_v2_perf_push_unique_tag(reason_tags, "tounicode_surrogate_pair")
        }
      }
    }
    None => ()
  }
}

///|
fn pdf_v2_perf_note_bfrange_array_length(
  expected : Int,
  actual : Int,
  reason_tags : Array[String],
) -> Bool {
  pdf_v2_perf_push_unique_tag(reason_tags, "tounicode_bfrange_array")
  if actual < expected {
    pdf_v2_perf_push_unique_tag(reason_tags, "tounicode_bfrange_array_short")
    true
  } else if actual > expected {
    pdf_v2_perf_push_unique_tag(reason_tags, "tounicode_bfrange_array_extra")
    true
  } else {
    false
  }
}

///|
fn pdf_v2_perf_bfrange_array_entry_count(
  tokens : Array[String],
  start : Int,
) -> Int {
  let mut count = 0
  let mut i = start
  while i < tokens.length() && tokens[i] != "]" {
    if pdf_v2_perf_is_hex_token(tokens[i]) {
      count = count + 1
    }
    i = i + 1
  }
  count
}

///|
fn pdf_v2_perf_parse_bfchar_range(
  tokens : Array[String],
  start : Int,
  map : Map[String, String],
  code_lengths : Array[Int],
  reason_tags : Array[String],
) -> (Int, Bool) {
  let mut i = start
  let mut malformed = false
  let mut applied = false
  while i < tokens.length() && tokens[i] != "endbfchar" {
    if i + 1 < tokens.length() &&
      pdf_v2_perf_is_hex_token(tokens[i]) &&
      pdf_v2_perf_is_hex_token(tokens[i + 1]) {
      let src = pdf_v2_perf_hex_token_bytes(tokens[i])
      pdf_v2_perf_note_source_code_length(src.length(), reason_tags)
      match pdf_v2_perf_decode_tounicode_hex(tokens[i + 1]) {
        Some(value) => {
          map.set(@mbtpdf_io.string_of_int_array(src), value)
          pdf_v2_perf_record_code_length(code_lengths, src.length())
          pdf_v2_perf_note_tounicode_target(tokens[i + 1], reason_tags)
          applied = true
        }
        None => {
          malformed = true
          pdf_v2_perf_push_unique_tag(reason_tags, "tounicode_target_malformed")
        }
      }
      i = i + 2
    } else {
      malformed = true
      i = i + 1
    }
  }
  if applied {
    reason_tags.push("tounicode_bfchar_applied")
  }
  (if i < tokens.length() { i + 1 } else { i }, malformed)
}

///|
fn pdf_v2_perf_parse_bfrange_range(
  tokens : Array[String],
  start : Int,
  map : Map[String, String],
  code_lengths : Array[Int],
  reason_tags : Array[String],
) -> (Int, Bool) {
  let mut i = start
  let mut malformed = false
  let mut applied = false
  while i < tokens.length() && tokens[i] != "endbfrange" {
    if i + 2 < tokens.length() &&
      pdf_v2_perf_is_hex_token(tokens[i]) &&
      pdf_v2_perf_is_hex_token(tokens[i + 1]) {
      let start_bytes = pdf_v2_perf_hex_token_bytes(tokens[i])
      let end_bytes = pdf_v2_perf_hex_token_bytes(tokens[i + 1])
      let start_code = pdf_v2_perf_bytes_to_int(start_bytes)
      let end_code = pdf_v2_perf_bytes_to_int(end_bytes)
      pdf_v2_perf_note_source_code_length(start_bytes.length(), reason_tags)
      if start_bytes.length() == 0 ||
        start_bytes.length() != end_bytes.length() ||
        end_code < start_code {
        malformed = true
        i = i + 1
      } else if pdf_v2_perf_is_hex_token(tokens[i + 2]) {
        pdf_v2_perf_push_unique_tag(reason_tags, "tounicode_bfrange_sequential")
        match pdf_v2_perf_decode_tounicode_hex_as_codepoints(tokens[i + 2]) {
          Some(codepoints) =>
            if codepoints.length() == 1 {
              let base = codepoints[0]
              let mut code = start_code
              while code <= end_code {
                match
                  pdf_v2_perf_unicode_string_from_codepoints([
                    base + code - start_code,
                  ]) {
                  Some(value) => {
                    map.set(
                      @mbtpdf_io.string_of_int_array(
                        pdf_v2_perf_int_to_fixed_bytes(
                          code,
                          start_bytes.length(),
                        ),
                      ),
                      value,
                    )
                    applied = true
                  }
                  None => malformed = true
                }
                code = code + 1
              }
              pdf_v2_perf_record_code_length(code_lengths, start_bytes.length())
            } else {
              malformed = true
              pdf_v2_perf_push_unique_tag(
                reason_tags, "tounicode_bfrange_sequential_multicodepoint_unsupported",
              )
            }
          None => {
            malformed = true
            pdf_v2_perf_push_unique_tag(
              reason_tags, "tounicode_target_malformed",
            )
          }
        }
        i = i + 3
      } else if tokens[i + 2] == "[" {
        let expected_count = end_code - start_code + 1
        let array_count = pdf_v2_perf_bfrange_array_entry_count(tokens, i + 3)
        if pdf_v2_perf_note_bfrange_array_length(
            expected_count, array_count, reason_tags,
          ) {
          malformed = true
        }
        let mut code = start_code
        let mut j = i + 3
        while j < tokens.length() && tokens[j] != "]" && code <= end_code {
          if pdf_v2_perf_is_hex_token(tokens[j]) {
            match pdf_v2_perf_decode_tounicode_hex(tokens[j]) {
              Some(value) => {
                map.set(
                  @mbtpdf_io.string_of_int_array(
                    pdf_v2_perf_int_to_fixed_bytes(code, start_bytes.length()),
                  ),
                  value,
                )
                pdf_v2_perf_note_tounicode_target(tokens[j], reason_tags)
                applied = true
              }
              None => {
                malformed = true
                pdf_v2_perf_push_unique_tag(
                  reason_tags, "tounicode_target_malformed",
                )
              }
            }
            code = code + 1
          } else {
            malformed = true
          }
          j = j + 1
        }
        if j >= tokens.length() || tokens[j] != "]" || code <= end_code {
          malformed = true
        }
        pdf_v2_perf_record_code_length(code_lengths, start_bytes.length())
        i = if j < tokens.length() { j + 1 } else { j }
      } else {
        malformed = true
        i = i + 1
      }
    } else {
      malformed = true
      i = i + 1
    }
  }
  if applied {
    reason_tags.push("tounicode_bfrange_applied")
  }
  (if i < tokens.length() { i + 1 } else { i }, malformed)
}

///|
fn pdf_v2_perf_cmap_tokens(text : String) -> Array[String] {
  let chars = text.to_array()
  let tokens : Array[String] = []
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if pdf_v2_perf_cmap_is_whitespace(ch) {
      i = i + 1
    } else if ch == '%' {
      i = i + 1
      while i < chars.length() && chars[i] != '\n' && chars[i] != '\r' {
        i = i + 1
      }
    } else if ch == '<' {
      if i + 1 < chars.length() && chars[i + 1] == '<' {
        tokens.push("<<")
        i = i + 2
      } else {
        let start = i
        i = i + 1
        while i < chars.length() && chars[i] != '>' {
          i = i + 1
        }
        if i < chars.length() {
          tokens.push(String::from_array(chars[start:i + 1].to_owned()))
          i = i + 1
        } else {
          tokens.push(String::from_array(chars[start:].to_owned()))
        }
      }
    } else if ch == '>' && i + 1 < chars.length() && chars[i + 1] == '>' {
      tokens.push(">>")
      i = i + 2
    } else if ch == '[' || ch == ']' {
      tokens.push(String::from_array([ch]))
      i = i + 1
    } else {
      let start = i
      while i < chars.length() &&
            !pdf_v2_perf_cmap_is_whitespace(chars[i]) &&
            chars[i] != '[' &&
            chars[i] != ']' &&
            chars[i] != '<' &&
            chars[i] != '>' &&
            chars[i] != '%' {
        i = i + 1
      }
      tokens.push(String::from_array(chars[start:i].to_owned()))
    }
  }
  tokens
}

///|
fn pdf_v2_perf_cmap_is_whitespace(ch : Char) -> Bool {
  ch == ' ' ||
  ch == '\n' ||
  ch == '\r' ||
  ch == '\t' ||
  ch == '\u000C' ||
  ch == '\u0000'
}

///|
fn pdf_v2_perf_is_hex_token(token : String) -> Bool {
  token.length() >= 2 &&
  token[0] == '<' &&
  token[token.length() - 1] == '>' &&
  !(token.length() >= 4 && token[1] == '<')
}

///|
fn pdf_v2_perf_hex_token_byte_length(token : String) -> Int {
  (pdf_v2_perf_hex_token_digits(token).length() + 1) / 2
}

///|
fn pdf_v2_perf_hex_token_bytes(token : String) -> Array[Int] {
  let digits = pdf_v2_perf_hex_token_digits(token)
  let bytes : Array[Int] = []
  let mut i = 0
  while i < digits.length() {
    let hi = pdf_v2_perf_hex_value(digits[i])
    let lo = if i + 1 < digits.length() {
      pdf_v2_perf_hex_value(digits[i + 1])
    } else {
      Some(0)
    }
    match (hi, lo) {
      (Some(h), Some(l)) => bytes.push((h << 4) | l)
      _ => ()
    }
    i = i + 2
  }
  bytes
}

///|
fn pdf_v2_perf_hex_token_digits(token : String) -> Array[Char] {
  let digits : Array[Char] = []
  if token.length() < 2 {
    return digits
  }
  for ch in token[1:token.length() - 1] {
    if !pdf_v2_perf_cmap_is_whitespace(ch) {
      digits.push(ch)
    }
  }
  digits
}

///|
fn pdf_v2_perf_hex_value(ch : Char) -> Int? {
  if ch >= '0' && ch <= '9' {
    Some(ch.to_int() - '0'.to_int())
  } else if ch >= 'a' && ch <= 'f' {
    Some(ch.to_int() - 'a'.to_int() + 10)
  } else if ch >= 'A' && ch <= 'F' {
    Some(ch.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn pdf_v2_perf_decode_tounicode_hex(token : String) -> String? {
  let bytes = pdf_v2_perf_hex_token_bytes(token)
  if bytes.is_empty() || bytes.length() % 2 != 0 {
    return None
  }
  let decoded = @tony_encoding.decode(
    Bytes::from_array(bytes.map(byte => byte.to_byte())),
    encoding=@tony_encoding.Encoding::UTF16BE,
  ) catch {
    _ => return None
  }
  Some(@unicode_normalization.nfc(decoded))
}

///|
fn pdf_v2_perf_decode_tounicode_hex_as_codepoints(
  token : String,
) -> Array[Int]? {
  let bytes = pdf_v2_perf_hex_token_bytes(token)
  if bytes.is_empty() || bytes.length() % 2 != 0 {
    return None
  }
  let codepoints : Array[Int] = []
  let mut i = 0
  while i < bytes.length() {
    let unit = (bytes[i] << 8) | bytes[i + 1]
    if unit >= 0xD800 && unit <= 0xDBFF {
      if i + 3 >= bytes.length() {
        return None
      }
      let low = (bytes[i + 2] << 8) | bytes[i + 3]
      if low < 0xDC00 || low > 0xDFFF {
        return None
      }
      codepoints.push(0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00))
      i = i + 4
    } else if unit >= 0xDC00 && unit <= 0xDFFF {
      return None
    } else {
      codepoints.push(unit)
      i = i + 2
    }
  }
  Some(codepoints)
}

///|
fn pdf_v2_perf_unicode_string_from_codepoints(
  codepoints : Array[Int],
) -> String? {
  let bytes : Array[Byte] = []
  for cp in codepoints {
    if cp < 0 || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF) {
      return None
    }
    if cp > 0xFFFF {
      let high = 0xD800 + ((cp - 0x10000) >> 10)
      let low = 0xDC00 + ((cp - 0x10000) & 0x3FF)
      pdf_v2_perf_append_utf16be_unit(bytes, high)
      pdf_v2_perf_append_utf16be_unit(bytes, low)
    } else {
      pdf_v2_perf_append_utf16be_unit(bytes, cp)
    }
  }
  let decoded = @tony_encoding.decode(
    Bytes::from_array(bytes),
    encoding=@tony_encoding.Encoding::UTF16BE,
  ) catch {
    _ => return None
  }
  Some(@unicode_normalization.nfc(decoded))
}

///|
fn pdf_v2_perf_append_utf16be_unit(bytes : Array[Byte], unit : Int) -> Unit {
  bytes.push(((unit >> 8) & 0xFF).to_byte())
  bytes.push((unit & 0xFF).to_byte())
}

///|
fn pdf_v2_perf_bytes_to_int(bytes : Array[Int]) -> Int {
  let mut out = 0
  for b in bytes {
    out = (out << 8) | b
  }
  out
}

///|
fn pdf_v2_perf_int_to_fixed_bytes(value : Int, length : Int) -> Array[Int] {
  let bytes = Array::make(length, 0)
  let mut v = value
  let mut i = length - 1
  while i >= 0 {
    bytes[i] = v & 0xFF
    v = v >> 8
    i = i - 1
  }
  bytes
}

///|
fn pdf_v2_perf_record_code_length(lengths : Array[Int], length : Int) -> Unit {
  if length > 0 && !lengths.contains(length) {
    lengths.push(length)
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
    return {
      extractor: Some(extractor),
      tounicode: None,
      warnings: [],
      risks: [],
      reason_tags: [],
    }
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
        Some(font_obj) => {
          let font_diagnostics = pdf_v2_perf_font_diagnostics(
            pdf, font_obj, font_name, page_index, source_ref,
          )
          let tounicode = pdf_v2_perf_build_tounicode_map(
            pdf, font_obj, page_index, source_ref,
          )
          match tounicode {
            Some(cmap) =>
              return {
                extractor: None,
                tounicode: Some(cmap),
                warnings: font_diagnostics.warnings + cmap.warnings,
                risks: font_diagnostics.risks + cmap.risks,
                reason_tags: font_diagnostics.reason_tags + cmap.reason_tags,
              }
            None => ()
          }
          try text_reader.text_extractor_of_font(font_obj) catch {
            _ => {
              let warning = if pdf_v2_perf_has_tounicode(pdf, font_obj) {
                pdf_v2_perf_warning(
                  PdfV2WarningKind::GlyphDecodeLowConfidence,
                  PdfV2Severity::Warning,
                  PdfV2CoreCapabilityKind::ToUnicode,
                  Some(source_ref),
                  source_ref.object_ref,
                  Some(page_index),
                  "ToUnicode map is present but mbtpdf could not build a text extractor",
                  ["tounicode_malformed", "glyph_decode_low_confidence"],
                  PdfV2Recoverability::RecoverableWithLoss,
                )
              } else if pdf_v2_perf_type0_missing_tounicode(pdf, font_obj) {
                warn_to_unicode_missing_or_malformed(font_resource).warning
              } else {
                warn_unknown_font_encoding(font_resource).warning
              }
              return {
                extractor: None,
                tounicode: None,
                warnings: font_diagnostics.warnings + [warning],
                risks: [
                  risk_glyph_decode_low_confidence(
                    Some(source_ref),
                    source_ref.object_ref,
                  ),
                ],
                reason_tags: font_diagnostics.reason_tags +
                ["glyph_decode_low_confidence"],
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
              {
                extractor: Some(extractor),
                tounicode: None,
                warnings: font_diagnostics.warnings + warnings,
                risks: font_diagnostics.risks,
                reason_tags: font_diagnostics.reason_tags,
              }
            }
          }
        }
        None => {
          let warning = warn_missing_font_resource(font_resource).warning
          {
            extractor: None,
            tounicode: None,
            warnings: [warning],
            risks: [
              risk_glyph_decode_low_confidence(
                Some(source_ref),
                source_ref.object_ref,
              ),
            ],
            reason_tags: [
              "missing_font_resource", "glyph_decode_low_confidence",
            ],
          }
        }
      }
    None => {
      let warning = warn_missing_font_resource(font_resource).warning
      {
        extractor: None,
        tounicode: None,
        warnings: [warning],
        risks: [
          risk_glyph_decode_low_confidence(
            Some(source_ref),
            source_ref.object_ref,
          ),
        ],
        reason_tags: ["missing_page_resources", "missing_font_resource"],
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
fn pdf_v2_perf_empty_instrumentation() -> PdfV2PerfInstrumentation {
  {
    decoded_stream_count: 0,
    decoded_stream_total_bytes: 0,
    max_decoded_stream_bytes: 0,
    content_stream_count: 0,
    page_count: 0,
    text_event_count: 0,
    glyph_or_char_count: 0,
    decode_failure_count: 0,
  }
}

///|
fn pdf_v2_perf_merge_instrumentation(
  left : PdfV2PerfInstrumentation,
  right : PdfV2PerfInstrumentation,
) -> PdfV2PerfInstrumentation {
  {
    decoded_stream_count: left.decoded_stream_count + right.decoded_stream_count,
    decoded_stream_total_bytes: left.decoded_stream_total_bytes +
    right.decoded_stream_total_bytes,
    max_decoded_stream_bytes: if left.max_decoded_stream_bytes >
      right.max_decoded_stream_bytes {
      left.max_decoded_stream_bytes
    } else {
      right.max_decoded_stream_bytes
    },
    content_stream_count: left.content_stream_count + right.content_stream_count,
    page_count: left.page_count + right.page_count,
    text_event_count: left.text_event_count + right.text_event_count,
    glyph_or_char_count: left.glyph_or_char_count + right.glyph_or_char_count,
    decode_failure_count: left.decode_failure_count + right.decode_failure_count,
  }
}

///|
fn pdf_v2_perf_text_event_char_count(events : Array[PdfV2CoreTextEvent]) -> Int {
  let mut total = 0
  for event in events {
    total = total + event.text.length()
  }
  total
}

///|
fn pdf_v2_perf_decoded_stream_total_bytes(
  pdf : @mbtpdf_pdf.Pdf,
  page : @mbtpdf_page.Page,
) -> Int {
  let mut total = 0
  for stream in page.content {
    total = total + pdf_v2_perf_stream_byte_count(pdf, stream)
  }
  total
}

///|
fn pdf_v2_perf_max_decoded_stream_bytes(
  pdf : @mbtpdf_pdf.Pdf,
  page : @mbtpdf_page.Page,
) -> Int {
  let mut max = 0
  for stream in page.content {
    let count = pdf_v2_perf_stream_byte_count(pdf, stream)
    if count > max {
      max = count
    }
  }
  max
}

///|
fn pdf_v2_perf_stream_byte_count(
  pdf : @mbtpdf_pdf.Pdf,
  stream : @mbtpdf_pdf.PdfObject,
) -> Int {
  try {
    let bytes = pdf.direct(stream).bigarray_of_stream()
    @mbtpdf_io.bytes_size(bytes)
  } catch {
    _ => 0
  }
}

///|
fn pdf_v2_perf_diagnostics_empty() -> PdfV2PerfDiagnostics {
  { warnings: [], risks: [] }
}

///|
fn pdf_v2_perf_warning(
  kind : PdfV2WarningKind,
  severity : PdfV2Severity,
  capability : PdfV2CoreCapabilityKind,
  source_ref : PdfV2SourceRef?,
  object_ref : String?,
  page_index : Int?,
  message : String,
  reason_tags : Array[String],
  recoverability : PdfV2Recoverability,
) -> PdfV2Warning {
  pdf_v2_warning_for_context(
    kind,
    severity,
    pdf_v2_diagnostic_context(capability, source_ref, object_ref, page_index, []),
    message,
    reason_tags + ["mbtpdf_backend_active", "no_fallback"],
    recoverability,
  )
}

///|
fn pdf_v2_perf_page_static_resource_diagnostics(
  pdf : @mbtpdf_pdf.Pdf,
  page : @mbtpdf_page.Page,
  page_index : Int,
  page_object_number : Int?,
  page_object_ref : String?,
) -> PdfV2PerfDiagnostics {
  let out = pdf_v2_perf_diagnostics_empty()
  let source_ref = pdf_v2_source_ref_for_page(page_index)
  let has_effective_resources = pdf_v2_perf_has_resource_entries(page.resources)
  let direct_resources = match page_object_number {
    Some(number) => pdf_v2_perf_page_direct_resources(pdf, number)
    None => None
  }
  match direct_resources {
    Some(_) =>
      if !has_effective_resources {
        out.warnings.push(
          pdf_v2_perf_warning(
            PdfV2WarningKind::MissingResource,
            PdfV2Severity::Warning,
            PdfV2CoreCapabilityKind::ResourceDictionary,
            Some(source_ref),
            page_object_ref,
            Some(page_index),
            "page resource dictionary is empty",
            ["missing_page_resources", "resource_inheritance_missing"],
            PdfV2Recoverability::RecoverableWithLoss,
          ),
        )
      }
    None =>
      if has_effective_resources {
        out.warnings.push(
          pdf_v2_perf_warning(
            PdfV2WarningKind::PartialCapability,
            PdfV2Severity::Info,
            PdfV2CoreCapabilityKind::ResourceDictionary,
            Some(source_ref),
            page_object_ref,
            Some(page_index),
            "page resources were supplied by mbtpdf page-tree inheritance",
            ["resource_inheritance_applied", "page_resources_effective"],
            PdfV2Recoverability::Recoverable,
          ),
        )
      } else {
        out.warnings.push(
          pdf_v2_perf_warning(
            PdfV2WarningKind::MissingResource,
            PdfV2Severity::Warning,
            PdfV2CoreCapabilityKind::ResourceDictionary,
            Some(source_ref),
            page_object_ref,
            Some(page_index),
            "page has no effective resources",
            ["missing_page_resources", "resource_inheritance_missing"],
            PdfV2Recoverability::RecoverableWithLoss,
          ),
        )
      }
  }
  out.warnings.append(
    pdf_v2_perf_unsupported_resource_kind_warnings(
      pdf,
      page.resources,
      page_index,
      page_object_ref,
      source_ref,
    ),
  )
  out
}

///|
fn pdf_v2_perf_page_op_resource_diagnostics(
  pdf : @mbtpdf_pdf.Pdf,
  resources : @mbtpdf_pdf.PdfObject,
  ops : Array[@mbtpdf_ops.LocatedOp],
  page_index : Int,
  page_object_ref : String?,
) -> PdfV2PerfDiagnostics {
  let out = pdf_v2_perf_diagnostics_empty()
  for located in ops {
    let source_ref : PdfV2SourceRef = {
      page_index,
      object_ref: pdf_v2_perf_object_ref_from_option(located.source_object_ref),
      stream_index: Some(located.source_stream_index),
      op_index: Some(located.source_op_index),
      content_order_index: None,
      text_object_id: None,
    }
    let object_ref = pdf_v2_perf_first_string(
      source_ref.object_ref,
      page_object_ref,
    )
    match located.op {
      @mbtpdf_ops.Op::OpDo(name) =>
        if !pdf_v2_perf_resource_name_exists(pdf, resources, "/XObject", name) {
          out.warnings.push(
            warn_missing_xobject_resource(
              make_resource_ref(
                PdfV2ResourceKind::Image,
                name,
                page_index,
                object_ref,
                Some(source_ref),
              ),
            ).warning,
          )
        }
      @mbtpdf_ops.Op::Opgs(name) =>
        if !pdf_v2_perf_resource_name_exists(pdf, resources, "/ExtGState", name) {
          out.warnings.push(
            pdf_v2_perf_warning(
              PdfV2WarningKind::MissingResource,
              PdfV2Severity::Warning,
              PdfV2CoreCapabilityKind::GraphicsState,
              Some(source_ref),
              object_ref,
              Some(page_index),
              "ExtGState resource is missing",
              ["missing_extgstate_resource", name],
              PdfV2Recoverability::RecoverableWithLoss,
            ),
          )
        }
      @mbtpdf_ops.Op::OpCS(name) =>
        if pdf_v2_perf_is_resource_colorspace_name(name) &&
          !pdf_v2_perf_resource_name_exists(pdf, resources, "/ColorSpace", name) {
          out.warnings.push(
            warn_missing_colorspace_resource(
              make_resource_ref(
                PdfV2ResourceKind::ColorSpace,
                name,
                page_index,
                object_ref,
                Some(source_ref),
              ),
            ).warning,
          )
        }
      @mbtpdf_ops.Op::Opcs(name) =>
        if pdf_v2_perf_is_resource_colorspace_name(name) &&
          !pdf_v2_perf_resource_name_exists(pdf, resources, "/ColorSpace", name) {
          out.warnings.push(
            warn_missing_colorspace_resource(
              make_resource_ref(
                PdfV2ResourceKind::ColorSpace,
                name,
                page_index,
                object_ref,
                Some(source_ref),
              ),
            ).warning,
          )
        }
      _ => ()
    }
  }
  out
}

///|
fn pdf_v2_perf_stream_filter_diagnostics(
  pdf : @mbtpdf_pdf.Pdf,
  page : @mbtpdf_page.Page,
  page_index : Int,
  page_object_ref : String?,
  decode_supported : Bool,
) -> PdfV2PerfDiagnostics {
  let out = pdf_v2_perf_diagnostics_empty()
  for stream_index = 0
      stream_index < page.content.length()
      stream_index = stream_index + 1 {
    let stream = page.content[stream_index]
    let object_ref = pdf_v2_perf_first_string(
      pdf_v2_perf_object_ref_from_option(pdf_v2_perf_indirect_number(stream)),
      page_object_ref,
    )
    let source_ref : PdfV2SourceRef = {
      page_index,
      object_ref,
      stream_index: Some(stream_index),
      op_index: None,
      content_order_index: None,
      text_object_id: None,
    }
    let filters = pdf_v2_perf_filter_names(pdf, stream)
    if filters.contains("/FlateDecode") {
      out.warnings.push(
        pdf_v2_perf_warning(
          PdfV2WarningKind::PartialCapability,
          PdfV2Severity::Info,
          PdfV2CoreCapabilityKind::StreamFilter,
          Some(source_ref),
          object_ref,
          Some(page_index),
          "content stream uses FlateDecode through mbtpdf decoder",
          ["filter_flate_decode_used", "lazy_stream_decode"],
          PdfV2Recoverability::Recoverable,
        ),
      )
    }
    if filters.length() > 1 {
      out.warnings.push(
        pdf_v2_perf_warning(
          PdfV2WarningKind::PartialCapability,
          if decode_supported {
            PdfV2Severity::Info
          } else {
            PdfV2Severity::Warning
          },
          PdfV2CoreCapabilityKind::StreamFilter,
          Some(source_ref),
          object_ref,
          Some(page_index),
          "content stream filter chain detected",
          if decode_supported {
            ["filter_chain_detected"]
          } else {
            ["filter_chain_detected", "filter_chain_unsupported"]
          },
          if decode_supported {
            PdfV2Recoverability::Recoverable
          } else {
            PdfV2Recoverability::RecoverableWithLoss
          },
        ),
      )
    }
    if pdf_v2_perf_decode_params_present(pdf, stream) {
      out.warnings.push(
        pdf_v2_perf_warning(
          PdfV2WarningKind::PartialCapability,
          PdfV2Severity::Info,
          PdfV2CoreCapabilityKind::StreamFilter,
          Some(source_ref),
          object_ref,
          Some(page_index),
          "DecodeParms are present; v2 records them as adapter diagnostics only",
          ["decode_params_present", "decode_params_ignored"],
          PdfV2Recoverability::Recoverable,
        ),
      )
    }
  }
  out
}

///|
fn pdf_v2_perf_document_structure_diagnostics(
  pdf : @mbtpdf_pdf.Pdf,
  objects : Array[PdfV2CoreObject],
) -> PdfV2PerfDiagnostics {
  let out = pdf_v2_perf_diagnostics_empty()
  let source_ref = pdf_v2_source_ref_for_page(0)
  let has_xref_stream = pdf_v2_perf_objects_contain(objects, "/XRef")
  let has_object_stream = pdf_v2_perf_objects_contain(objects, "/ObjStm") ||
    pdf.objects.object_stream_ids.length() > 0
  if has_xref_stream {
    out.warnings.push(
      pdf_v2_perf_warning(
        PdfV2WarningKind::PartialCapability,
        PdfV2Severity::Info,
        PdfV2CoreCapabilityKind::XrefStream,
        Some(source_ref),
        None,
        None,
        "xref stream detected and parsed by mbtpdf",
        ["xref_stream_detected", "xref_stream_supported"],
        PdfV2Recoverability::Recoverable,
      ),
    )
  } else {
    out.warnings.push(
      pdf_v2_perf_warning(
        PdfV2WarningKind::PartialCapability,
        PdfV2Severity::Info,
        PdfV2CoreCapabilityKind::XrefTable,
        Some(source_ref),
        None,
        None,
        "classic xref table used",
        ["xref_table_used"],
        PdfV2Recoverability::Recoverable,
      ),
    )
  }
  if has_object_stream {
    out.warnings.push(
      pdf_v2_perf_warning(
        PdfV2WarningKind::PartialCapability,
        PdfV2Severity::Info,
        PdfV2CoreCapabilityKind::ObjectStream,
        Some(source_ref),
        None,
        None,
        "object stream detected through mbtpdf object graph",
        ["object_stream_detected", "object_stream_supported"],
        PdfV2Recoverability::Recoverable,
      ),
    )
  }
  out
}

///|
fn pdf_v2_perf_font_diagnostics(
  pdf : @mbtpdf_pdf.Pdf,
  font_obj : @mbtpdf_pdf.PdfObject,
  font_name : String,
  page_index : Int,
  source_ref : PdfV2SourceRef,
) -> PdfV2PerfFontFacts {
  let direct = pdf.direct(font_obj)
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  let reason_tags : Array[String] = []
  let subtype = pdf_v2_perf_name_lookup(pdf, direct, "/Subtype")
  match subtype {
    Some("/Type0") => {
      reason_tags.push("font_type_type0")
      reason_tags.push("font_type_cid")
      warnings.push(
        pdf_v2_perf_warning(
          PdfV2WarningKind::PartialCapability,
          PdfV2Severity::Info,
          PdfV2CoreCapabilityKind::Type0Font,
          Some(source_ref),
          source_ref.object_ref,
          Some(page_index),
          "Type0/CID font handled through mbtpdf text extractor",
          ["font_type_type0", "font_type_cid"],
          PdfV2Recoverability::RecoverableWithLoss,
        ),
      )
    }
    Some(_) => reason_tags.push("font_type_simple")
    None => reason_tags.push("font_type_simple")
  }
  let descendant = pdf_v2_perf_descendant_font(pdf, direct)
  match descendant {
    Some(descendant_font) => {
      reason_tags.push("descendant_font_present")
      match pdf_v2_perf_name_lookup(pdf, descendant_font, "/Subtype") {
        Some("/CIDFontType0") => {
          reason_tags.push("font_type_cid")
          reason_tags.push("cid_font_type0")
        }
        Some("/CIDFontType2") => {
          reason_tags.push("font_type_cid")
          reason_tags.push("cid_font_type2")
        }
        Some(other) => {
          reason_tags.push("font_type_cid")
          reason_tags.push("cid_font_subtype:" + other)
        }
        None => reason_tags.push("cid_font_subtype_missing")
      }
      match pdf_v2_perf_cid_system_info_tags(pdf, descendant_font) {
        [] => reason_tags.push("cid_system_info_missing")
        tags => reason_tags.append(tags)
      }
    }
    None =>
      if subtype == Some("/Type0") {
        reason_tags.push("descendant_font_missing")
        warnings.push(
          pdf_v2_perf_warning(
            PdfV2WarningKind::PartialCapability,
            PdfV2Severity::Warning,
            PdfV2CoreCapabilityKind::CidFont,
            Some(source_ref),
            source_ref.object_ref,
            Some(page_index),
            "Type0 font has no usable DescendantFonts entry",
            ["descendant_font_missing", "font_type_type0", "font_type_cid"],
            PdfV2Recoverability::RecoverableWithLoss,
          ),
        )
      }
  }
  match pdf_v2_perf_base_font_name(pdf, direct) {
    Some(base_font) => {
      reason_tags.push("raw_base_font:" + base_font)
      match pdf_v2_perf_subset_base_font(base_font) {
        Some(normalized) => {
          reason_tags.push("font_subset_detected")
          reason_tags.push("font_subset_prefix_removed_or_recorded")
          reason_tags.push("normalized_base_font:" + normalized)
        }
        None => ()
      }
    }
    None => reason_tags.push("raw_resource_font:" + font_name)
  }
  let descendant_embedded = match descendant {
    Some(descendant_font) =>
      pdf_v2_perf_embedded_font_present(pdf, descendant_font)
    None => false
  }
  if pdf_v2_perf_embedded_font_present(pdf, direct) || descendant_embedded {
    reason_tags.push("embedded_font_present")
  } else {
    reason_tags.push("embedded_font_missing")
    warnings.push(
      pdf_v2_perf_warning(
        PdfV2WarningKind::PartialCapability,
        PdfV2Severity::Info,
        PdfV2CoreCapabilityKind::EmbeddedFont,
        Some(source_ref),
        source_ref.object_ref,
        Some(page_index),
        "font dictionary has no embedded FontFile entry",
        ["embedded_font_missing"],
        PdfV2Recoverability::Recoverable,
      ),
    )
  }
  if pdf_v2_perf_has_tounicode(pdf, direct) {
    reason_tags.push("tounicode_present")
    reason_tags.push("decode_source_tounicode")
    reason_tags.push("cmap_used")
  } else {
    reason_tags.push("tounicode_missing")
    if subtype == Some("/Type0") {
      reason_tags.push("cmap_missing")
      reason_tags.push("glyph_decode_best_effort")
      warnings.push(
        warn_to_unicode_missing_or_malformed(
          make_resource_ref(
            PdfV2ResourceKind::Font,
            font_name,
            page_index,
            source_ref.object_ref,
            Some(source_ref),
          ),
        ).warning,
      )
      risks.push(
        risk_glyph_decode_low_confidence(
          Some(source_ref),
          source_ref.object_ref,
        ),
      )
    } else {
      reason_tags.push("glyph_decode_best_effort")
    }
  }
  { warnings, risks, reason_tags }
}

///|
fn pdf_v2_perf_positioning_detail_warning(
  source_ref : PdfV2SourceRef,
  object_ref : String?,
  state : PdfV2PerfTextState,
) -> PdfV2Warning {
  pdf_v2_perf_warning(
    PdfV2WarningKind::PartialCapability,
    PdfV2Severity::Info,
    PdfV2CoreCapabilityKind::TextState,
    Some(source_ref),
    object_ref,
    Some(source_ref.page_index),
    "v2 perf reader preserves basic text matrix/origin; detailed advance and rotation remain partial",
    pdf_v2_perf_text_state_reason_tags(state) +
    [
      "positioning_detail_unavailable", "advance_width_unavailable", "rotation_unavailable",
      "line_matrix_partial",
    ],
    PdfV2Recoverability::Recoverable,
  )
}

///|
fn pdf_v2_perf_text_state_reason_tags(
  state : PdfV2PerfTextState,
) -> Array[String] {
  [
    "text_matrix",
    "line_matrix",
    "font_name",
    "font_size",
    "baseline_y",
    "origin_x",
    "origin_y",
    "line_height_estimate",
    "writing_direction",
    "writing_direction_ltr",
    "char_spacing:" + state.char_spacing.to_string(),
    "word_spacing:" + state.word_spacing.to_string(),
    "horizontal_scaling:" + state.horizontal_scaling.to_string(),
    "rendering_mode:" + state.rendering_mode.to_string(),
    "text_rise:" + state.text_rise.to_string(),
  ]
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
fn pdf_v2_perf_decode_params_present(
  pdf : @mbtpdf_pdf.Pdf,
  stream : @mbtpdf_pdf.PdfObject,
) -> Bool {
  let direct = pdf.direct(stream)
  pdf.lookup_direct("/DecodeParms", direct) is Some(_) ||
  pdf.lookup_direct("/DP", direct) is Some(_)
}

///|
fn pdf_v2_perf_has_resource_entries(obj : @mbtpdf_pdf.PdfObject) -> Bool {
  match obj {
    @mbtpdf_pdf.PdfObject::Dictionary(entries) => entries.length() > 0
    @mbtpdf_pdf.PdfObject::Stream(r) => {
      let (dict, _) = r.val
      pdf_v2_perf_has_resource_entries(dict)
    }
    _ => false
  }
}

///|
fn pdf_v2_perf_page_direct_resources(
  pdf : @mbtpdf_pdf.Pdf,
  page_object_number : Int,
) -> @mbtpdf_pdf.PdfObject? {
  pdf.lookup_obj(page_object_number).lookup_immediate("/Resources")
}

///|
fn pdf_v2_perf_unsupported_resource_kind_warnings(
  pdf : @mbtpdf_pdf.Pdf,
  resources : @mbtpdf_pdf.PdfObject,
  page_index : Int,
  page_object_ref : String?,
  source_ref : PdfV2SourceRef,
) -> Array[PdfV2Warning] {
  let warnings : Array[PdfV2Warning] = []
  match pdf.direct(resources) {
    @mbtpdf_pdf.PdfObject::Dictionary(entries) =>
      for entry in entries {
        let key = entry.0
        if ![
            "/Font", "/XObject", "/ExtGState", "/ColorSpace", "/Pattern", "/Shading",
            "/ProcSet", "/Properties",
          ].contains(key) {
          warnings.push(
            pdf_v2_perf_warning(
              PdfV2WarningKind::UnsupportedCapability,
              PdfV2Severity::Warning,
              PdfV2CoreCapabilityKind::ResourceDictionary,
              Some(source_ref),
              page_object_ref,
              Some(page_index),
              "unsupported resource dictionary entry",
              ["unsupported_resource_kind", key],
              PdfV2Recoverability::RecoverableWithLoss,
            ),
          )
        } else if ["/Pattern", "/Shading", "/Properties"].contains(key) {
          warnings.push(
            pdf_v2_perf_warning(
              PdfV2WarningKind::PartialCapability,
              PdfV2Severity::Info,
              PdfV2CoreCapabilityKind::ResourceDictionary,
              Some(source_ref),
              page_object_ref,
              Some(page_index),
              "resource kind is recorded but not interpreted by the text perf adapter",
              ["unsupported_resource_kind", key],
              PdfV2Recoverability::RecoverableWithLoss,
            ),
          )
        }
      }
    _ => ()
  }
  warnings
}

///|
fn pdf_v2_perf_resource_name_exists(
  pdf : @mbtpdf_pdf.Pdf,
  resources : @mbtpdf_pdf.PdfObject,
  resource_kind : String,
  name : String,
) -> Bool {
  match pdf.lookup_direct(resource_kind, resources) {
    Some(bucket) => pdf.lookup_direct(name, bucket) is Some(_)
    None => false
  }
}

///|
fn pdf_v2_perf_is_resource_colorspace_name(name : String) -> Bool {
  match name {
    "/DeviceGray" | "/DeviceRGB" | "/DeviceCMYK" | "/Pattern" => false
    _ => true
  }
}

///|
fn pdf_v2_perf_objects_contain(
  objects : Array[PdfV2CoreObject],
  needle : String,
) -> Bool {
  for object in objects {
    if object.raw.contains(needle) {
      return true
    }
    match object.dictionary {
      Some(dictionary) => if dictionary.contains(needle) { return true }
      None => ()
    }
  }
  false
}

///|
fn pdf_v2_perf_name_lookup(
  pdf : @mbtpdf_pdf.Pdf,
  obj : @mbtpdf_pdf.PdfObject,
  key : String,
) -> String? {
  match pdf.lookup_direct(key, obj) {
    Some(@mbtpdf_pdf.PdfObject::Name(name)) => Some(name.to_string_bytes())
    _ => None
  }
}

///|
fn pdf_v2_perf_base_font_name(
  pdf : @mbtpdf_pdf.Pdf,
  font_obj : @mbtpdf_pdf.PdfObject,
) -> String? {
  pdf_v2_perf_name_lookup(pdf, font_obj, "/BaseFont")
}

///|
fn pdf_v2_perf_descendant_font(
  pdf : @mbtpdf_pdf.Pdf,
  font_obj : @mbtpdf_pdf.PdfObject,
) -> @mbtpdf_pdf.PdfObject? {
  match pdf.lookup_direct("/DescendantFonts", font_obj) {
    Some(@mbtpdf_pdf.PdfObject::Array(fonts)) =>
      if fonts.length() > 0 {
        Some(pdf.direct(fonts[0]))
      } else {
        None
      }
    Some(font) => Some(pdf.direct(font))
    None => None
  }
}

///|
fn pdf_v2_perf_cid_system_info_tags(
  pdf : @mbtpdf_pdf.Pdf,
  font_obj : @mbtpdf_pdf.PdfObject,
) -> Array[String] {
  match pdf.lookup_direct("/CIDSystemInfo", font_obj) {
    Some(info) => {
      let tags : Array[String] = ["cid_system_info_present"]
      match pdf_v2_perf_string_or_name_lookup(pdf, info, "/Registry") {
        Some(value) => tags.push("cid_registry:" + value)
        None => tags.push("cid_registry_missing")
      }
      match pdf_v2_perf_string_or_name_lookup(pdf, info, "/Ordering") {
        Some(value) => tags.push("cid_ordering:" + value)
        None => tags.push("cid_ordering_missing")
      }
      match pdf_v2_perf_int_lookup(pdf, info, "/Supplement") {
        Some(value) => tags.push("cid_supplement:" + value.to_string())
        None => tags.push("cid_supplement_missing")
      }
      tags
    }
    None => []
  }
}

///|
fn pdf_v2_perf_string_or_name_lookup(
  pdf : @mbtpdf_pdf.Pdf,
  obj : @mbtpdf_pdf.PdfObject,
  key : String,
) -> String? {
  match pdf.lookup_direct(key, obj) {
    Some(@mbtpdf_pdf.PdfObject::String(value)) => Some(value)
    Some(@mbtpdf_pdf.PdfObject::Name(name)) => Some(name.to_string_bytes())
    _ => None
  }
}

///|
fn pdf_v2_perf_int_lookup(
  pdf : @mbtpdf_pdf.Pdf,
  obj : @mbtpdf_pdf.PdfObject,
  key : String,
) -> Int? {
  match pdf.lookup_direct(key, obj) {
    Some(@mbtpdf_pdf.PdfObject::Integer(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_v2_perf_subset_base_font(base_font : String) -> String? {
  let plus = base_font.find("+")
  match plus {
    Some(index) =>
      if index > 1 {
        Some(base_font[index + 1:].to_owned())
      } else {
        None
      }
    None => None
  }
}

///|
fn pdf_v2_perf_embedded_font_present(
  pdf : @mbtpdf_pdf.Pdf,
  font_obj : @mbtpdf_pdf.PdfObject,
) -> Bool {
  match pdf.lookup_direct("/FontDescriptor", pdf.direct(font_obj)) {
    Some(descriptor) =>
      pdf.lookup_direct("/FontFile", descriptor) is Some(_) ||
      pdf.lookup_direct("/FontFile2", descriptor) is Some(_) ||
      pdf.lookup_direct("/FontFile3", descriptor) is Some(_)
    None => false
  }
}

///|
fn pdf_v2_perf_has_tounicode(
  pdf : @mbtpdf_pdf.Pdf,
  font_obj : @mbtpdf_pdf.PdfObject,
) -> Bool {
  pdf.lookup_direct("/ToUnicode", pdf.direct(font_obj)) is Some(_)
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
    current_tounicode: None,
    current_font_warnings: [],
    current_font_risks: [],
    current_font_reason_tags: [],
    text_object_id: 0,
    content_order_index: 0,
    text_x: 0.0,
    text_y: 0.0,
    leading: 0.0,
    char_spacing: 0.0,
    word_spacing: 0.0,
    horizontal_scaling: 100.0,
    rendering_mode: 0,
    text_rise: 0.0,
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
  state.val.char_spacing = 0.0
  state.val.word_spacing = 0.0
  state.val.horizontal_scaling = 100.0
  state.val.rendering_mode = 0
  state.val.text_rise = 0.0
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
fn pdf_v2_perf_bytes_contain_ascii(bytes : Bytes, needle : String) -> Bool {
  if needle.length() == 0 || bytes.length() < needle.length() {
    return false
  }
  let needle_bytes = @mbtpdf_io.bytes_of_string(needle)
  let mut start = 0
  while start <= bytes.length() - needle_bytes.length() {
    let mut matched = true
    let mut offset = 0
    while offset < needle_bytes.length() {
      if bytes[start + offset] != needle_bytes[offset] {
        matched = false
        break
      }
      offset = offset + 1
    }
    if matched {
      return true
    }
    start = start + 1
  }
  false
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
      "batch_glyph_decode", "mbtpdf_backend_used", "v2_adapter_diagnostics_only",
      header_tag, "no_fallback",
    ],
    PdfV2Recoverability::Recoverable,
  )
}

///|
fn pdf_v2_perf_instrumentation_warning(
  instrumentation : PdfV2PerfInstrumentation,
) -> PdfV2Warning {
  pdf_v2_perf_warning(
    PdfV2WarningKind::PartialCapability,
    PdfV2Severity::Info,
    PdfV2CoreCapabilityKind::LowSignalDocument,
    None,
    None,
    None,
    "PDF v2 perf reader bounded decoded-stream lifetime counters",
    [
      "bounded_decoded_stream_lifetime",
      "decoded_stream_count",
      "decoded_stream_count:" + instrumentation.decoded_stream_count.to_string(),
      "decoded_stream_total_bytes",
      "decoded_stream_total_bytes:" +
      instrumentation.decoded_stream_total_bytes.to_string(),
      "max_decoded_stream_bytes",
      "max_decoded_stream_bytes:" +
      instrumentation.max_decoded_stream_bytes.to_string(),
      "content_stream_count",
      "content_stream_count:" + instrumentation.content_stream_count.to_string(),
      "page_count",
      "page_count:" + instrumentation.page_count.to_string(),
      "text_event_count",
      "text_event_count:" + instrumentation.text_event_count.to_string(),
      "glyph_or_char_count",
      "glyph_or_char_count:" + instrumentation.glyph_or_char_count.to_string(),
      "decode_failure_count",
      "decode_failure_count:" + instrumentation.decode_failure_count.to_string(),
      "stream_bytes_not_exposed_to_convert",
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
    [
      "mbtpdf_stream_decode_failed", "stream_decode_failed", "fail_closed", "no_fallback",
    ],
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
    [
      "mbtpdf_stream_decode_failed", "stream_decode_failed", "abstain_candidate",
      "no_fallback",
    ],
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
  let encrypted = reason_tags.contains("encrypted_pdf_detected") ||
    capability == PdfV2CoreCapabilityKind::EncryptionMetadata
  let warning = pdf_v2_warning_for_context(
    if encrypted {
      PdfV2WarningKind::EncryptedDocument
    } else {
      PdfV2WarningKind::MalformedObject
    },
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
    if encrypted {
      PdfV2RiskKind::EncryptedDocument
    } else {
      PdfV2RiskKind::MalformedObject
    },
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
