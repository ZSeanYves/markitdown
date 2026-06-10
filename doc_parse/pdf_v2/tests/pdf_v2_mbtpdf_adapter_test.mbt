///|
fn phase3_pad_xref_offset(value : Int) -> String {
  let mut out = value.to_string()
  while out.length() < 10 {
    out = "0" + out
  }
  out
}

///|
fn phase3_pdf_object(number : Int, body : String) -> String {
  "\{number} 0 obj\n" + body + "\nendobj\n"
}

///|
fn phase3_stream_object(content : String) -> String {
  "<< /Length " +
  content.length().to_string() +
  " >>\nstream\n" +
  content +
  "endstream"
}

///|
fn phase3_pdf_from_objects(objects : Array[(Int, String)]) -> String {
  let header = "%PDF-1.4\n"
  let pieces : Array[String] = [header]
  let offsets : Array[Int] = []
  let mut offset = header.length()
  for pair in objects {
    let object_text = phase3_pdf_object(pair.0, pair.1)
    offsets.push(offset)
    pieces.push(object_text)
    offset = offset + object_text.length()
  }
  let xref_offset = offset
  let size = objects.length() + 1
  let xref_entries : Array[String] = [
    "xref\n0 \{size}\n",
    "0000000000 65535 f \n",
  ]
  for object_offset in offsets {
    xref_entries.push(phase3_pad_xref_offset(object_offset) + " 00000 n \n")
  }
  xref_entries.push(
    "trailer\n<< /Root 1 0 R /Size \{size} >>\nstartxref\n\{xref_offset}\n%%EOF\n",
  )
  pieces.push(xref_entries.join(""))
  pieces.join("")
}

///|
fn phase3_one_page_pdf() -> String {
  let content = "q\n1 0 0 1 10 20 cm\n10 10 20 20 re\nS\nQ\n"
  phase3_pdf_from_objects([
    (1, "<< /Type /Catalog /Pages 2 0 R >>"),
    (2, "<< /Type /Pages /Count 1 /Kids [3 0 R] >>"),
    (
      3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] /CropBox [10 20 190 280] /Rotate 90 /UserUnit 2 /Resources << /ProcSet [/PDF] >> /Contents 4 0 R >>",
    ),
    (4, phase3_stream_object(content)),
  ])
}

///|
fn phase3_two_page_pdf() -> String {
  let content = "q\nQ\n"
  phase3_pdf_from_objects([
    (1, "<< /Type /Catalog /Pages 2 0 R >>"),
    (2, "<< /Type /Pages /Count 2 /Kids [3 0 R 4 0 R] >>"),
    (
      3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] /Resources << >> /Contents 5 0 R >>",
    ),
    (
      4, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] /Resources << >> /Contents 6 0 R >>",
    ),
    (5, phase3_stream_object(content)),
    (6, phase3_stream_object(content)),
  ])
}

///|
fn phase4_text_pdf(content : String, include_font : Bool) -> String {
  if include_font {
    phase3_pdf_from_objects([
      (1, "<< /Type /Catalog /Pages 2 0 R >>"),
      (2, "<< /Type /Pages /Count 1 /Kids [3 0 R] >>"),
      (
        3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
      ),
      (4, phase3_stream_object(content)),
      (5, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
    ])
  } else {
    phase3_pdf_from_objects([
      (1, "<< /Type /Catalog /Pages 2 0 R >>"),
      (2, "<< /Type /Pages /Count 1 /Kids [3 0 R] >>"),
      (
        3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << >> /Contents 4 0 R >>",
      ),
      (4, phase3_stream_object(content)),
    ])
  }
}

///|
fn phase4_simple_text_pdf() -> String {
  phase4_text_pdf("BT\n/F1 12 Tf\n72 720 Td\n(Hello) Tj\nET\n", true)
}

///|
fn phase4_tj_text_pdf() -> String {
  phase4_text_pdf("BT\n/F1 12 Tf\n72 720 Td\n[(A) 120 (B)] TJ\nET\n", true)
}

///|
fn phase4_missing_font_pdf() -> String {
  phase4_text_pdf("BT\n/Missing 12 Tf\n72 720 Td\n(Hi) Tj\nET\n", false)
}

///|
fn phase4_text_state_pdf() -> String {
  phase4_text_pdf(
    "BT\n/F1 12 Tf\n1 Tc\n2 Tw\n95 Tz\n14 TL\n1 Tr\n3 Ts\n1 0 0 1 72 720 Tm\nT*\n(State) Tj\nET\n",
    true,
  )
}

///|
fn phase3_write_fixture(path : String, body : String) -> Unit raise {
  @fs.write_string_to_file(path, body, encoding="utf8") catch {
    err => fail("write fixture failed: " + err.to_string())
  }
}

///|
fn phase3_cleanup_fixture(path : String) -> Unit {
  if @fs.path_exists(path) {
    let _ = @fs.remove_file(path) catch { _ => () }
  }
}

///|
fn phase3_has_source_kind(
  events : Array[@pdfv2.PdfV2SourceEvent],
  kind : @pdfv2.PdfV2SourceEventKind,
) -> Bool {
  for event in events {
    if event.kind == kind {
      return true
    }
  }
  false
}

///|
fn phase3_has_warning_kind(
  warnings : Array[@pdfv2.PdfV2Warning],
  kind : @pdfv2.PdfV2WarningKind,
) -> Bool {
  for warning in warnings {
    if warning.kind == kind {
      return true
    }
  }
  false
}

///|
fn phase3_has_risk_kind(
  risks : Array[@pdfv2.PdfV2Risk],
  kind : @pdfv2.PdfV2RiskKind,
) -> Bool {
  for risk in risks {
    if risk.kind == kind {
      return true
    }
  }
  false
}

///|
fn phase4_count_source_kind(
  events : Array[@pdfv2.PdfV2SourceEvent],
  kind : @pdfv2.PdfV2SourceEventKind,
) -> Int {
  let mut count = 0
  for event in events {
    if event.kind == kind {
      count = count + 1
    }
  }
  count
}

///|
fn phase4_has_event_reason(
  events : Array[@pdfv2.PdfV2SourceEvent],
  tag : String,
) -> Bool {
  for event in events {
    if event.reason_tags.contains(tag) {
      return true
    }
  }
  false
}

///|
fn phase4_has_warning_reason(
  warnings : Array[@pdfv2.PdfV2Warning],
  tag : String,
) -> Bool {
  for warning in warnings {
    if warning.reason_tags.contains(tag) {
      return true
    }
  }
  false
}

///|
fn phase4_has_text_show_kind(
  events : Array[@pdfv2.PdfV2SourceEvent],
  kind : @pdfv2.PdfV2TextShowOperatorKind,
) -> Bool {
  for event in events {
    match event.text_show {
      Some(fact) if fact.raw_operator_kind == kind => return true
      _ => ()
    }
  }
  false
}

///|
fn phase4_first_text_show(
  events : Array[@pdfv2.PdfV2SourceEvent],
) -> @pdfv2.PdfV2TextShowFact? {
  for event in events {
    match event.text_show {
      Some(fact) => return Some(fact)
      None => ()
    }
  }
  None
}

///|
fn phase4_first_text_state_with_tag(
  events : Array[@pdfv2.PdfV2SourceEvent],
  tag : String,
) -> @pdfv2.PdfV2TextStateFact? {
  for event in events {
    if event.reason_tags.contains(tag) {
      match event.text_state {
        Some(fact) => return Some(fact)
        None => ()
      }
    }
  }
  None
}

///|
fn phase5_has_candidate_reason(
  candidates : Array[@pdfv2.PdfV2CharCandidate],
  tag : String,
) -> Bool {
  for candidate in candidates {
    if candidate.reason_tags.contains(tag) {
      return true
    }
  }
  false
}

///|
fn phase5_has_candidate_warning_reason(
  candidates : Array[@pdfv2.PdfV2CharCandidate],
  tag : String,
) -> Bool {
  for candidate in candidates {
    for warning in candidate.warnings {
      if warning.reason_tags.contains(tag) {
        return true
      }
    }
  }
  false
}

///|
fn phase5_repeated_text_pdf() -> String {
  phase4_text_pdf("BT\n/F1 12 Tf\n72 720 Td\n(A) Tj\n(B) Tj\nET\n", true)
}

///|
fn phase6_two_font_text_pdf() -> String {
  phase3_pdf_from_objects([
    (1, "<< /Type /Catalog /Pages 2 0 R >>"),
    (2, "<< /Type /Pages /Count 1 /Kids [3 0 R] >>"),
    (
      3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> /Contents 4 0 R >>",
    ),
    (
      4,
      phase3_stream_object(
        "BT\n/F1 12 Tf\n72 720 Td\n(A) Tj\n/F2 12 Tf\n(B) Tj\nET\n",
      ),
    ),
    (5, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
    (6, "<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>"),
  ])
}

///|
fn phase6_tj_spacing_pdf() -> String {
  phase4_text_pdf("BT\n/F1 12 Tf\n72 720 Td\n[(A) 240 (B)] TJ\nET\n", true)
}

///|
fn phase6_span_options(
  max_spans : Int,
  max_chars_per_span : Int,
  allow_tj_spacing_merge : Bool,
) -> @pdfv2.PdfV2SpanReconstructionOptions {
  { max_spans, max_chars_per_span, allow_tj_spacing_merge }
}

///|
fn phase6_has_span_break_reason(
  spans : Array[@pdfv2.PdfV2SpanCandidate],
  tag : String,
) -> Bool {
  for span in spans {
    if span.break_reason_tags.contains(tag) {
      return true
    }
  }
  false
}

///|
fn phase6_has_span_reason(
  spans : Array[@pdfv2.PdfV2SpanCandidate],
  tag : String,
) -> Bool {
  for span in spans {
    if span.reason_tags.contains(tag) || span.merge_reason_tags.contains(tag) {
      return true
    }
  }
  false
}

///|
fn phase3_open_options(
  max_pages : Int?,
  max_events : Int?,
) -> @pdfv2.PdfV2CoreOpenOptions {
  {
    collect_text: true,
    collect_images: true,
    collect_vectors: true,
    collect_annotations: true,
    collect_forms: true,
    collect_outlines: true,
    collect_metadata: true,
    max_pages,
    max_objects: None,
    max_stream_bytes: None,
    max_events,
    fail_on_encrypted: true,
  }
}

///|
test "pdf v2 mbtpdf adapter opens real minimal pdf from path" {
  let path = "/tmp/markitdown-pdf-v2-phase3-one-page.pdf"
  phase3_write_fixture(path, phase3_one_page_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.summary.page_count == 1)
      assert_true(doc.pages.length() == 1)
      assert_true(doc.source_events.length() > 0)
      assert_true(doc.summary.event_count == doc.source_events.length())
      assert_true(doc.summary.one_pass_scan)
      assert_true(!doc.summary.fallback_used)
      assert_true(!doc.summary.external_model_files_read)
      assert_true(phase3_has_source_kind(doc.source_events, PageBegin))
      assert_true(phase3_has_source_kind(doc.source_events, PageEnd))
      assert_true(phase3_has_source_kind(doc.source_events, ContentStreamBegin))
      assert_true(phase3_has_source_kind(doc.source_events, ContentStreamEnd))
      assert_true(phase3_has_source_kind(doc.source_events, Unknown))
      assert_true(doc.pages[0].text_blocks.length() == 0)
      assert_true(doc.pages[0].layout_regions.length() == 0)
      assert_true(doc.pages[0].bbox.x0 == 10.0)
      assert_true(doc.pages[0].bbox.y0 == 20.0)
      assert_true(doc.pages[0].source_ref.page_index == Some(0))
    }
    SourceOpenErr(_, _, message) =>
      fail("expected source document success: " + message)
  }
}

///|
test "pdf v2 mbtpdf adapter exposes page facts from real pdf" {
  let path = "/tmp/markitdown-pdf-v2-phase3-page-facts.pdf"
  phase3_write_fixture(path, phase3_one_page_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_core_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    CoreOpenOk(core, events) => {
      assert_true(core.page_count == 1)
      assert_true(events.length() > 0)
      assert_true(core.page_facts.length() == 1)
      let fact = core.page_facts[0]
      assert_true(fact.media_box.x0 == 0.0)
      assert_true(fact.media_box.y0 == 0.0)
      assert_true(fact.media_box.x1 == 200.0)
      assert_true(fact.media_box.y1 == 300.0)
      match fact.crop_box {
        Some(crop) => {
          assert_true(crop.x0 == 10.0)
          assert_true(crop.y0 == 20.0)
          assert_true(crop.x1 == 190.0)
          assert_true(crop.y1 == 280.0)
        }
        None => fail("expected crop box")
      }
      assert_true(fact.rotate == 90)
      assert_true(fact.user_unit == Some(2.0))
      assert_true(fact.resources_present)
      assert_true(fact.source_ref.page_index == Some(0))
    }
    CoreOpenErr(_, _, message) =>
      fail("expected core document success: " + message)
  }
}

///|
test "pdf v2 mbtpdf adapter enforces max_pages cap" {
  let path = "/tmp/markitdown-pdf-v2-phase3-two-page.pdf"
  phase3_write_fixture(path, phase3_two_page_pdf())
  defer phase3_cleanup_fixture(path)

  let options = phase3_open_options(Some(1), None)
  let result = @pdfv2.pdf_v2_open_source_document_from_path(path, options)
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.summary.page_count == 1)
      assert_true(doc.pages.length() == 1)
      assert_true(doc.pages[0].page_index == 0)
      for event in doc.source_events {
        match event.page_index {
          Some(index) => assert_true(index == 0)
          None => ()
        }
      }
      assert_true(
        phase3_has_warning_kind(
          doc.warnings,
          @pdfv2.PdfV2WarningKind::PerformanceCap,
        ),
      )
      assert_true(
        phase3_has_risk_kind(
          doc.risks,
          @pdfv2.PdfV2RiskKind::PerformanceCapReached,
        ),
      )
    }
    SourceOpenErr(_, _, message) =>
      fail("expected capped source document success: " + message)
  }
}

///|
test "pdf v2 mbtpdf adapter enforces max_events cap" {
  let path = "/tmp/markitdown-pdf-v2-phase3-max-events.pdf"
  phase3_write_fixture(path, phase3_one_page_pdf())
  defer phase3_cleanup_fixture(path)

  let options = phase3_open_options(None, Some(3))
  let result = @pdfv2.pdf_v2_open_source_document_from_path(path, options)
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.source_events.length() <= 3)
      assert_true(doc.summary.event_count == doc.source_events.length())
      assert_true(
        phase3_has_warning_kind(
          doc.warnings,
          @pdfv2.PdfV2WarningKind::PerformanceCap,
        ),
      )
      assert_true(
        phase3_has_risk_kind(
          doc.risks,
          @pdfv2.PdfV2RiskKind::PerformanceCapReached,
        ),
      )
    }
    SourceOpenErr(_, _, message) =>
      fail("expected event-capped source document success: " + message)
  }
}

///|
test "pdf v2 mbtpdf adapter fails closed on malformed pdf" {
  let path = "/tmp/markitdown-pdf-v2-phase3-malformed.pdf"
  phase3_write_fixture(
    path, "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF\n",
  )
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(_) => fail("expected malformed PDF to fail closed")
    SourceOpenErr(warnings, risks, _) => {
      assert_true(warnings.length() > 0)
      assert_true(risks.length() > 0)
      assert_true(
        phase3_has_warning_kind(
          warnings,
          @pdfv2.PdfV2WarningKind::MalformedObject,
        ),
      )
      assert_true(phase3_has_risk_kind(risks, @pdfv2.PdfV2RiskKind::Malformed))
    }
  }
}

///|
test "pdf v2 mbtpdf adapter emits typed text events for simple text" {
  let path = "/tmp/markitdown-pdf-v2-phase4-simple-text.pdf"
  phase3_write_fixture(path, phase4_simple_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(phase3_has_source_kind(doc.source_events, TextObjectBegin))
      assert_true(phase3_has_source_kind(doc.source_events, FontUse))
      assert_true(phase3_has_source_kind(doc.source_events, TextShow))
      assert_true(phase3_has_source_kind(doc.source_events, GlyphCandidate))
      assert_true(
        phase4_count_source_kind(doc.source_events, GlyphCandidate) >= 5,
      )
      assert_true(doc.pages[0].text_blocks.length() == 0)
      assert_true(doc.pages[0].layout_regions.length() == 0)
      match phase4_first_text_show(doc.source_events) {
        Some(fact) => {
          assert_true(
            fact.raw_operator_kind == @pdfv2.PdfV2TextShowOperatorKind::Tj,
          )
          assert_true(fact.decoded_text == Some("Hello"))
          assert_true(fact.font_size == Some(12.0))
          assert_true(
            fact.decode_confidence == @pdfv2.PdfV2TextDecodeConfidence::Medium,
          )
          assert_true(fact.source_ref.stream_index == Some(0))
          assert_true(fact.source_ref.op_index is Some(_))
        }
        None => fail("expected text show fact")
      }
    }
    SourceOpenErr(_, _, message) =>
      fail("expected simple text source document success: " + message)
  }
}

///|
test "pdf v2 mbtpdf adapter emits typed TJ text show and candidates" {
  let path = "/tmp/markitdown-pdf-v2-phase4-tj.pdf"
  phase3_write_fixture(path, phase4_tj_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(
        phase4_has_text_show_kind(
          doc.source_events,
          @pdfv2.PdfV2TextShowOperatorKind::TJ,
        ),
      )
      assert_true(
        phase4_count_source_kind(doc.source_events, GlyphCandidate) >= 2,
      )
      assert_true(
        phase4_has_event_reason(doc.source_events, "spacing_adjustment_present"),
      )
      match phase4_first_text_show(doc.source_events) {
        Some(fact) => {
          assert_true(fact.decoded_text == Some("AB"))
          assert_true(fact.source_ref.stream_index == Some(0))
          assert_true(fact.source_ref.op_index is Some(_))
        }
        None => fail("expected TJ text show fact")
      }
    }
    SourceOpenErr(_, _, message) =>
      fail("expected TJ source document success: " + message)
  }
}

///|
test "pdf v2 mbtpdf adapter reports missing font resource conservatively" {
  let path = "/tmp/markitdown-pdf-v2-phase4-missing-font.pdf"
  phase3_write_fixture(path, phase4_missing_font_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(phase3_has_source_kind(doc.source_events, TextShow))
      assert_true(
        phase4_has_warning_reason(doc.warnings, "missing_font_resource"),
      )
      match phase4_first_text_show(doc.source_events) {
        Some(fact) => {
          assert_true(fact.decoded_text is None)
          assert_true(
            fact.decode_confidence == @pdfv2.PdfV2TextDecodeConfidence::Unknown,
          )
        }
        None => fail("expected missing-font text show fact")
      }
    }
    SourceOpenErr(_, _, message) =>
      fail(
        "expected missing-font document to return low-confidence events: " +
        message,
      )
  }
}

///|
test "pdf v2 mbtpdf adapter emits text state events" {
  let path = "/tmp/markitdown-pdf-v2-phase4-text-state.pdf"
  phase3_write_fixture(path, phase4_text_state_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(phase3_has_source_kind(doc.source_events, TextState))
      assert_true(phase4_has_event_reason(doc.source_events, "operator_Tc"))
      assert_true(phase4_has_event_reason(doc.source_events, "operator_Tw"))
      assert_true(phase4_has_event_reason(doc.source_events, "operator_Tz"))
      assert_true(phase4_has_event_reason(doc.source_events, "operator_TL"))
      assert_true(phase4_has_event_reason(doc.source_events, "operator_Tr"))
      assert_true(phase4_has_event_reason(doc.source_events, "operator_Ts"))
      assert_true(
        phase4_has_event_reason(doc.source_events, "text_state_incomplete"),
      )
      match phase4_first_text_state_with_tag(doc.source_events, "operator_Tm") {
        Some(fact) => {
          assert_true(fact.char_spacing == Some(1.0))
          assert_true(fact.word_spacing == Some(2.0))
          assert_true(fact.horizontal_scaling == Some(95.0))
          assert_true(fact.leading == Some(14.0))
          assert_true(fact.text_rendering_mode == Some(1))
          assert_true(fact.rise == Some(3.0))
          match fact.text_matrix {
            Some(matrix) => {
              assert_true(matrix.e == 72.0)
              assert_true(matrix.f == 720.0)
            }
            None => fail("expected text matrix")
          }
        }
        None => fail("expected Tm text state fact")
      }
    }
    SourceOpenErr(_, _, message) =>
      fail("expected text-state source document success: " + message)
  }
}

///|
test "pdf v2 mbtpdf adapter caps typed text events" {
  let path = "/tmp/markitdown-pdf-v2-phase4-text-cap.pdf"
  phase3_write_fixture(path, phase4_simple_text_pdf())
  defer phase3_cleanup_fixture(path)

  let options = phase3_open_options(None, Some(6))
  let result = @pdfv2.pdf_v2_open_source_document_from_path(path, options)
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.source_events.length() <= 6)
      assert_true(
        phase3_has_warning_kind(
          doc.warnings,
          @pdfv2.PdfV2WarningKind::PerformanceCap,
        ),
      )
      assert_true(
        phase3_has_risk_kind(
          doc.risks,
          @pdfv2.PdfV2RiskKind::PerformanceCapReached,
        ),
      )
      assert_true(doc.pages[0].text_blocks.length() == 0)
      assert_true(doc.pages[0].layout_regions.length() == 0)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected capped typed text document success: " + message)
  }
}

///|
test "pdf v2 char reconstruction emits simple ASCII candidates" {
  let path = "/tmp/markitdown-pdf-v2-phase5-simple-hi.pdf"
  phase3_write_fixture(
    path,
    phase4_text_pdf("BT\n/F1 12 Tf\n72 720 Td\n(Hi) Tj\nET\n", true),
  )
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.char_candidates.length() == 2)
      assert_true(doc.reconstruction_summary.char_candidate_count == 2)
      assert_true(doc.reconstruction_summary.decoded_char_count == 2)
      assert_true(doc.reconstruction_summary.geometry_missing_count == 2)
      assert_true(doc.font_cache.decode_profiles.length() == 1)
      let first = doc.char_candidates[0]
      assert_true(first.text == Some("H"))
      assert_true(first.unicode == Some("H"))
      assert_true(first.font_ref == Some("5 0 R"))
      assert_true(first.font_name == Some("/F1"))
      assert_true(first.font_size == Some(12.0))
      assert_true(
        first.decode_confidence == @pdfv2.PdfV2TextDecodeConfidence::Medium,
      )
      assert_true(
        first.geometry_confidence == @pdfv2.PdfV2GeometryConfidence::Unknown,
      )
      assert_true(first.bbox is None)
      assert_true(first.position is None)
      assert_true(first.source_ref.stream_index == Some(0))
      assert_true(first.source_ref.op_index is Some(_))
      assert_true(doc.pages[0].text_blocks.length() == 0)
      assert_true(doc.pages[0].layout_regions.length() == 0)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 5 simple char candidates: " + message)
  }
}

///|
test "pdf v2 char reconstruction preserves TJ spacing reason" {
  let path = "/tmp/markitdown-pdf-v2-phase5-tj.pdf"
  phase3_write_fixture(path, phase4_tj_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.char_candidates.length() == 2)
      assert_true(doc.char_candidates[0].text == Some("A"))
      assert_true(doc.char_candidates[1].text == Some("B"))
      assert_true(
        phase5_has_candidate_reason(
          doc.char_candidates,
          "spacing_adjustment_present",
        ),
      )
      assert_true(doc.char_candidates[0].source_ref.stream_index == Some(0))
      assert_true(doc.char_candidates[1].source_ref.op_index is Some(_))
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 5 TJ char candidates: " + message)
  }
}

///|
test "pdf v2 char reconstruction keeps missing font conservative" {
  let path = "/tmp/markitdown-pdf-v2-phase5-missing-font.pdf"
  phase3_write_fixture(path, phase4_missing_font_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.char_candidates.length() == 2)
      assert_true(doc.char_candidates[0].text is None)
      assert_true(doc.char_candidates[0].raw_bytes == "H")
      assert_true(doc.char_candidates[0].font_ref == Some("/Missing"))
      assert_true(
        doc.char_candidates[0].decode_confidence !=
        @pdfv2.PdfV2TextDecodeConfidence::High,
      )
      assert_true(
        phase5_has_candidate_reason(
          doc.char_candidates,
          "missing_font_resource",
        ),
      )
      assert_true(
        phase5_has_candidate_warning_reason(
          doc.char_candidates,
          "missing_font_resource",
        ),
      )
      assert_true(doc.reconstruction_summary.unknown_decode_count == 2)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 5 missing-font char candidates: " + message)
  }
}

///|
test "pdf v2 char reconstruction max_chars cap is explicit" {
  let path = "/tmp/markitdown-pdf-v2-phase5-char-cap.pdf"
  phase3_write_fixture(path, phase4_simple_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_core_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    CoreOpenOk(_, events) => {
      let font_cache = @pdfv2.pdf_v2_build_font_cache_from_text_events(events)
      let reconstructed = @pdfv2.pdf_v2_reconstruct_char_candidates(
        events, font_cache, 1,
      )
      assert_true(reconstructed.char_candidates.length() == 1)
      assert_true(reconstructed.summary.char_candidate_count == 1)
      assert_true(reconstructed.summary.max_chars == 1)
      assert_true(reconstructed.summary.max_chars_hit)
      assert_true(
        phase3_has_warning_kind(
          reconstructed.warnings,
          @pdfv2.PdfV2WarningKind::PerformanceCap,
        ),
      )
      assert_true(
        phase3_has_risk_kind(
          reconstructed.risks,
          @pdfv2.PdfV2RiskKind::PerformanceCapReached,
        ),
      )
    }
    CoreOpenErr(_, _, message) =>
      fail("expected Phase 5 max_chars core events: " + message)
  }
}

///|
test "pdf v2 char reconstruction records geometry gap" {
  let path = "/tmp/markitdown-pdf-v2-phase5-geometry.pdf"
  phase3_write_fixture(path, phase4_simple_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.char_candidates.length() == 5)
      assert_true(doc.reconstruction_summary.geometry_missing_count == 5)
      assert_true(
        phase5_has_candidate_reason(
          doc.char_candidates,
          "glyph_geometry_unavailable",
        ),
      )
      assert_true(
        phase5_has_candidate_warning_reason(
          doc.char_candidates,
          "glyph_geometry_unavailable",
        ),
      )
      for candidate in doc.char_candidates {
        assert_true(candidate.bbox is None)
        assert_true(candidate.position is None)
        assert_true(
          candidate.geometry_confidence ==
          @pdfv2.PdfV2GeometryConfidence::Unknown,
        )
      }
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 5 geometry-gap char candidates: " + message)
  }
}

///|
test "pdf v2 font cache summary deduplicates repeated text shows" {
  let path = "/tmp/markitdown-pdf-v2-phase5-font-cache.pdf"
  phase3_write_fixture(path, phase5_repeated_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.char_candidates.length() == 2)
      assert_true(doc.font_cache.decode_profiles.length() == 1)
      assert_true(doc.font_cache.cache_misses == 1)
      assert_true(doc.font_cache.cache_hits == 1)
      assert_true(doc.reconstruction_summary.font_cache_misses == 1)
      assert_true(doc.reconstruction_summary.font_cache_hits == 1)
      assert_true(
        doc.font_cache.decode_profiles[0].encoding_kind ==
        @pdfv2.PdfV2DecodeProfileEncodingKind::StandardEncoding,
      )
      assert_true(doc.pages[0].text_blocks.length() == 0)
      assert_true(doc.pages[0].layout_regions.length() == 0)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 5 font-cache source document: " + message)
  }
}

///|
test "pdf v2 span reconstruction emits simple ASCII span candidate" {
  let path = "/tmp/markitdown-pdf-v2-phase6-simple-span.pdf"
  phase3_write_fixture(path, phase4_simple_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.char_candidates.length() == 5)
      assert_true(doc.span_candidates.length() == 1)
      assert_true(doc.span_candidates[0].text == "Hello")
      assert_true(doc.span_candidates[0].source_refs.length() == 5)
      assert_true(doc.span_candidates[0].bbox is None)
      assert_true(
        doc.span_candidates[0].geometry_confidence ==
        @pdfv2.PdfV2GeometryConfidence::Unknown,
      )
      assert_true(
        doc.span_candidates[0].reason_tags.contains("span_geometry_unavailable"),
      )
      assert_true(doc.reconstruction_summary.span_candidate_count == 1)
      assert_true(doc.reconstruction_summary.chars_grouped_count == 5)
      assert_true(doc.pages[0].text_blocks.length() == 0)
      assert_true(doc.pages[0].layout_regions.length() == 0)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 6 simple span candidate: " + message)
  }
}

///|
test "pdf v2 span reconstruction breaks on font change" {
  let path = "/tmp/markitdown-pdf-v2-phase6-font-change.pdf"
  phase3_write_fixture(path, phase6_two_font_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.char_candidates.length() == 2)
      assert_true(doc.span_candidates.length() == 2)
      assert_true(doc.span_candidates[0].text == "A")
      assert_true(doc.span_candidates[1].text == "B")
      assert_true(
        phase6_has_span_break_reason(doc.span_candidates, "font_change"),
      )
      assert_true(doc.reconstruction_summary.span_break_count >= 1)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 6 font-change spans: " + message)
  }
}

///|
test "pdf v2 span reconstruction handles TJ spacing boundary option" {
  let path = "/tmp/markitdown-pdf-v2-phase6-tj-spacing.pdf"
  phase3_write_fixture(path, phase6_tj_spacing_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.char_candidates.length() == 2)
      assert_true(doc.span_candidates.length() == 2)
      assert_true(
        phase6_has_span_break_reason(doc.span_candidates, "tj_spacing_boundary"),
      )
      let merged = @pdfv2.pdf_v2_reconstruct_span_candidates(
        doc.char_candidates,
        phase6_span_options(10, 10, true),
      )
      assert_true(merged.spans.length() == 1)
      assert_true(merged.spans[0].text == "AB")
      assert_true(phase6_has_span_reason(merged.spans, "tj_spacing_boundary"))
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 6 TJ spacing spans: " + message)
  }
}

///|
test "pdf v2 span reconstruction enforces max chars per span" {
  let path = "/tmp/markitdown-pdf-v2-phase6-max-chars-per-span.pdf"
  phase3_write_fixture(
    path,
    phase4_text_pdf("BT\n/F1 12 Tf\n72 720 Td\n(ABCDE) Tj\nET\n", true),
  )
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      let spans = @pdfv2.pdf_v2_reconstruct_span_candidates(
        doc.char_candidates,
        phase6_span_options(10, 2, true),
      )
      assert_true(spans.spans.length() == 3)
      assert_true(spans.spans[0].text == "AB")
      assert_true(spans.spans[1].text == "CD")
      assert_true(spans.spans[2].text == "E")
      assert_true(
        phase6_has_span_break_reason(spans.spans, "max_chars_per_span"),
      )
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 6 max chars per span: " + message)
  }
}

///|
test "pdf v2 span reconstruction max_spans cap is explicit" {
  let path = "/tmp/markitdown-pdf-v2-phase6-max-spans.pdf"
  phase3_write_fixture(path, phase4_simple_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      let spans = @pdfv2.pdf_v2_reconstruct_span_candidates(
        doc.char_candidates,
        phase6_span_options(1, 2, true),
      )
      assert_true(spans.spans.length() == 1)
      assert_true(spans.summary.max_span_cap_hit)
      assert_true(
        phase3_has_warning_kind(
          spans.warnings,
          @pdfv2.PdfV2WarningKind::PerformanceCap,
        ),
      )
      assert_true(
        phase3_has_risk_kind(
          spans.risks,
          @pdfv2.PdfV2RiskKind::PerformanceCapReached,
        ),
      )
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 6 max spans cap: " + message)
  }
}

///|
test "pdf v2 span reconstruction keeps unknown decode conservative" {
  let path = "/tmp/markitdown-pdf-v2-phase6-unknown-decode.pdf"
  phase3_write_fixture(path, phase4_missing_font_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.char_candidates.length() == 2)
      assert_true(doc.span_candidates.length() == 1)
      assert_true(
        doc.span_candidates[0].decode_confidence !=
        @pdfv2.PdfV2TextDecodeConfidence::High,
      )
      assert_true(
        doc.span_candidates[0].decode_confidence ==
        @pdfv2.PdfV2TextDecodeConfidence::Unknown,
      )
      assert_true(doc.pages[0].text_blocks.length() == 0)
      assert_true(doc.pages[0].layout_regions.length() == 0)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 6 unknown decode span: " + message)
  }
}
