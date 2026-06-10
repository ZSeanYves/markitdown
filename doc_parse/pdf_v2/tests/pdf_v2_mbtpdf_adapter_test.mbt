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
fn phase7_source_order_line_pdf() -> String {
  phase4_text_pdf(
    "BT\n/F1 12 Tf\n72 720 Td\n(Hello) Tj\n(World) Tj\nET\n", true,
  )
}

///|
fn phase7_text_object_boundary_pdf() -> String {
  phase4_text_pdf(
    "BT\n/F1 12 Tf\n(A) Tj\nET\nBT\n/F1 12 Tf\n(B) Tj\nET\n", true,
  )
}

///|
fn phase7_explicit_line_move_pdf() -> String {
  phase4_text_pdf("BT\n/F1 12 Tf\n(A) Tj\nT*\n(B) Tj\nET\n", true)
}

///|
fn phase8_source_order_block_pdf() -> String {
  phase4_text_pdf(
    "BT\n/F1 12 Tf\n72 720 Td\n(Hello) Tj\nT*\n(World) Tj\nET\n", true,
  )
}

///|
fn phase8_three_line_block_pdf() -> String {
  phase4_text_pdf(
    "BT\n/F1 12 Tf\n72 720 Td\n(A) Tj\nT*\n(B) Tj\nT*\n(C) Tj\nET\n", true,
  )
}

///|
fn phase8_two_page_text_pdf() -> String {
  let content_a = "BT\n/F1 12 Tf\n72 720 Td\n(A) Tj\nET\n"
  let content_b = "BT\n/F1 12 Tf\n72 720 Td\n(B) Tj\nET\n"
  phase3_pdf_from_objects([
    (1, "<< /Type /Catalog /Pages 2 0 R >>"),
    (2, "<< /Type /Pages /Count 2 /Kids [3 0 R 4 0 R] >>"),
    (
      3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 7 0 R >> >> /Contents 5 0 R >>",
    ),
    (
      4, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 7 0 R >> >> /Contents 6 0 R >>",
    ),
    (5, phase3_stream_object(content_a)),
    (6, phase3_stream_object(content_b)),
    (7, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
  ])
}

///|
fn phase11_image_xobject_pdf() -> String {
  let content = "q\n/Im1 Do\nQ\n"
  phase3_pdf_from_objects([
    (1, "<< /Type /Catalog /Pages 2 0 R /Metadata 7 0 R >>"),
    (2, "<< /Type /Pages /Count 1 /Kids [3 0 R] >>"),
    (
      3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << /XObject << /Im1 5 0 R >> /Font << /F1 6 0 R >> >> /Contents 4 0 R >>",
    ),
    (4, phase3_stream_object(content)),
    (
      5, "<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length 3 >>\nstream\nabcendstream",
    ),
    (6, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
    (
      7, "<< /Type /Metadata /Subtype /XML /Length 7 >>\nstream\n<xmp/> endstream",
    ),
  ])
}

///|
fn phase11_inline_image_pdf() -> String {
  let content = "q\nBI\n/W 1\n/H 1\n/BPC 8\n/CS /DeviceGray\nID\nz\nEI\nQ\n"
  phase4_text_pdf(content, false)
}

///|
fn phase11_link_annotation_pdf() -> String {
  phase3_pdf_from_objects([
    (1, "<< /Type /Catalog /Pages 2 0 R >>"),
    (2, "<< /Type /Pages /Count 1 /Kids [3 0 R] >>"),
    (
      3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Resources << >> /Annots [5 0 R] /Contents 4 0 R >>",
    ),
    (4, phase3_stream_object("q\nQ\n")),
    (
      5, "<< /Type /Annot /Subtype /Link /Rect [50 40 150 80] /A << /S /URI /URI (https://example.test/link) >> >>",
    ),
  ])
}

///|
fn phase11_widget_form_pdf() -> String {
  phase3_pdf_from_objects([
    (1, "<< /Type /Catalog /Pages 2 0 R /AcroForm << /Fields [5 0 R] >> >>"),
    (2, "<< /Type /Pages /Count 1 /Kids [3 0 R] >>"),
    (
      3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Resources << >> /Annots [5 0 R] /Contents 4 0 R >>",
    ),
    (4, phase3_stream_object("q\nQ\n")),
    (
      5, "<< /Type /Annot /Subtype /Widget /Rect [10 20 110 40] /T (Field1) /TU (Field one) /V (Value1) /AP << /N 6 0 R >> >>",
    ),
    (
      6, "<< /Type /XObject /Subtype /Form /BBox [0 0 10 10] /Length 0 >>\nstream\nendstream",
    ),
  ])
}

///|
fn phase11_outline_destination_metadata_pdf() -> String {
  let header = "%PDF-1.4\n"
  let objects : Array[(Int, String)] = [
    (1, "<< /Type /Catalog /Pages 2 0 R /Outlines 6 0 R >>"),
    (2, "<< /Type /Pages /Count 1 /Kids [3 0 R] >>"),
    (
      3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Resources << >> /Contents 4 0 R >>",
    ),
    (4, phase3_stream_object("q\nQ\n")),
    (5, "<< /Title (Chapter 1) /Dest [3 0 R /Fit] >>"),
    (6, "<< /Type /Outlines /First 5 0 R /Last 5 0 R /Count 1 >>"),
    (7, "<< /Title (Doc title) /Author (Ada) >>"),
  ]
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
    "trailer\n<< /Root 1 0 R /Info 7 0 R /Size \{size} >>\nstartxref\n\{xref_offset}\n%%EOF\n",
  )
  pieces.push(xref_entries.join(""))
  pieces.join("")
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
fn phase7_line_options(
  max_lines : Int,
  max_spans_per_line : Int,
  allow_source_order_merge : Bool,
  allow_geometry_merge : Bool,
) -> @pdfv2.PdfV2LineReconstructionOptions {
  {
    max_lines,
    max_spans_per_line,
    allow_source_order_merge,
    allow_geometry_merge,
  }
}

///|
fn phase8_block_options(
  max_blocks : Int,
  max_lines_per_block : Int,
  allow_source_order_merge : Bool,
  allow_geometry_merge : Bool,
  allow_vertical_gap_merge : Bool,
) -> @pdfv2.PdfV2BlockReconstructionOptions {
  {
    max_blocks,
    max_lines_per_block,
    allow_source_order_merge,
    allow_geometry_merge,
    allow_vertical_gap_merge,
  }
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
fn phase7_has_line_break_reason(
  lines : Array[@pdfv2.PdfV2LineCandidate],
  tag : String,
) -> Bool {
  for line in lines {
    if line.break_reason_tags.contains(tag) {
      return true
    }
  }
  false
}

///|
fn phase8_has_block_break_reason(
  blocks : Array[@pdfv2.PdfV2BlockCandidate],
  tag : String,
) -> Bool {
  for block in blocks {
    if block.break_reason_tags.contains(tag) {
      return true
    }
  }
  false
}

///|
fn phase8_has_block_reason(
  blocks : Array[@pdfv2.PdfV2BlockCandidate],
  tag : String,
) -> Bool {
  for block in blocks {
    if block.reason_tags.contains(tag) || block.merge_reason_tags.contains(tag) {
      return true
    }
  }
  false
}

///|
fn phase7_has_line_reason(
  lines : Array[@pdfv2.PdfV2LineCandidate],
  tag : String,
) -> Bool {
  for line in lines {
    if line.reason_tags.contains(tag) || line.merge_reason_tags.contains(tag) {
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

///|
test "pdf v2 line reconstruction emits source-order line candidate" {
  let path = "/tmp/markitdown-pdf-v2-phase7-source-order-line.pdf"
  phase3_write_fixture(path, phase7_source_order_line_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.char_candidates.length() == 10)
      assert_true(doc.span_candidates.length() == 2)
      assert_true(doc.line_candidates.length() == 1)
      assert_true(doc.line_candidates[0].text == "HelloWorld")
      assert_true(doc.line_candidates[0].source_refs.length() == 10)
      assert_true(doc.line_candidates[0].bbox is None)
      assert_true(doc.line_candidates[0].baseline is None)
      assert_true(
        doc.line_candidates[0].geometry_confidence ==
        @pdfv2.PdfV2GeometryConfidence::Unknown,
      )
      assert_true(
        doc.line_candidates[0].writing_direction ==
        @pdfv2.PdfV2WritingDirection::Unknown,
      )
      assert_true(
        phase7_has_line_reason(doc.line_candidates, "line_geometry_unavailable"),
      )
      assert_true(doc.reconstruction_summary.line_candidate_count == 1)
      assert_true(doc.reconstruction_summary.spans_grouped_count == 2)
      assert_true(doc.pages[0].text_blocks.length() == 0)
      assert_true(doc.pages[0].layout_regions.length() == 0)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 7 source-order line candidate: " + message)
  }
}

///|
test "pdf v2 line reconstruction breaks on text object boundary" {
  let path = "/tmp/markitdown-pdf-v2-phase7-text-object-boundary.pdf"
  phase3_write_fixture(path, phase7_text_object_boundary_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.span_candidates.length() == 2)
      assert_true(doc.line_candidates.length() == 2)
      assert_true(doc.line_candidates[0].text == "A")
      assert_true(doc.line_candidates[1].text == "B")
      assert_true(
        phase7_has_line_break_reason(
          doc.line_candidates,
          "text_object_boundary",
        ),
      )
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 7 text object boundary lines: " + message)
  }
}

///|
test "pdf v2 line reconstruction breaks on explicit line move" {
  let path = "/tmp/markitdown-pdf-v2-phase7-explicit-line-move.pdf"
  phase3_write_fixture(path, phase7_explicit_line_move_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.span_candidates.length() == 2)
      assert_true(doc.line_candidates.length() == 2)
      assert_true(doc.line_candidates[0].text == "A")
      assert_true(doc.line_candidates[1].text == "B")
      assert_true(
        phase7_has_line_break_reason(doc.line_candidates, "explicit_line_move"),
      )
      assert_true(
        !(doc.line_candidates.length() == 1 &&
        doc.line_candidates[0].decode_confidence ==
        @pdfv2.PdfV2TextDecodeConfidence::High),
      )
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 7 explicit line move lines: " + message)
  }
}

///|
test "pdf v2 line reconstruction enforces max spans per line" {
  let path = "/tmp/markitdown-pdf-v2-phase7-max-spans-per-line.pdf"
  phase3_write_fixture(
    path,
    phase4_text_pdf("BT\n/F1 12 Tf\n72 720 Td\n(ABC) Tj\nET\n", true),
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
        phase6_span_options(10, 1, true),
      )
      let lines = @pdfv2.pdf_v2_reconstruct_line_candidates(
        spans.spans,
        phase7_line_options(10, 2, true, false),
      )
      assert_true(spans.spans.length() == 3)
      assert_true(lines.lines.length() == 2)
      assert_true(lines.lines[0].text == "AB")
      assert_true(lines.lines[1].text == "C")
      assert_true(
        phase7_has_line_break_reason(lines.lines, "max_spans_per_line"),
      )
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 7 max spans per line: " + message)
  }
}

///|
test "pdf v2 line reconstruction max_lines cap is explicit" {
  let path = "/tmp/markitdown-pdf-v2-phase7-max-lines.pdf"
  phase3_write_fixture(
    path,
    phase4_text_pdf("BT\n/F1 12 Tf\n72 720 Td\n(ABC) Tj\nET\n", true),
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
        phase6_span_options(10, 1, true),
      )
      let lines = @pdfv2.pdf_v2_reconstruct_line_candidates(
        spans.spans,
        phase7_line_options(1, 1, true, false),
      )
      assert_true(lines.lines.length() == 1)
      assert_true(lines.summary.max_line_cap_hit)
      assert_true(phase7_has_line_break_reason(lines.lines, "max_lines_cap"))
      assert_true(
        phase3_has_warning_kind(
          lines.warnings,
          @pdfv2.PdfV2WarningKind::PerformanceCap,
        ),
      )
      assert_true(
        phase3_has_risk_kind(
          lines.risks,
          @pdfv2.PdfV2RiskKind::PerformanceCapReached,
        ),
      )
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 7 max lines cap: " + message)
  }
}

///|
test "pdf v2 line reconstruction keeps geometry unavailable conservative" {
  let path = "/tmp/markitdown-pdf-v2-phase7-geometry-unavailable.pdf"
  phase3_write_fixture(path, phase4_simple_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.line_candidates.length() == 1)
      assert_true(doc.line_candidates[0].bbox is None)
      assert_true(doc.line_candidates[0].baseline is None)
      assert_true(
        doc.line_candidates[0].geometry_confidence ==
        @pdfv2.PdfV2GeometryConfidence::Unknown,
      )
      assert_true(
        doc.line_candidates[0].reason_tags.contains("line_geometry_unavailable"),
      )
      assert_true(doc.reconstruction_summary.line_geometry_missing_count == 1)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 7 geometry unavailable line: " + message)
  }
}

///|
test "pdf v2 line reconstruction keeps unknown decode conservative" {
  let path = "/tmp/markitdown-pdf-v2-phase7-unknown-decode.pdf"
  phase3_write_fixture(path, phase4_missing_font_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.line_candidates.length() == 1)
      assert_true(
        doc.line_candidates[0].decode_confidence !=
        @pdfv2.PdfV2TextDecodeConfidence::High,
      )
      assert_true(
        doc.line_candidates[0].decode_confidence ==
        @pdfv2.PdfV2TextDecodeConfidence::Unknown ||
        doc.line_candidates[0].decode_confidence ==
        @pdfv2.PdfV2TextDecodeConfidence::Failed,
      )
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 7 unknown decode line: " + message)
  }
}

///|
test "pdf v2 line reconstruction remains parser facts only" {
  let path = "/tmp/markitdown-pdf-v2-phase7-no-block-convert.pdf"
  phase3_write_fixture(path, phase7_source_order_line_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.line_candidates.length() == 1)
      assert_true(doc.pages[0].text_blocks.length() == 0)
      assert_true(doc.pages[0].layout_regions.length() == 0)
      assert_true(doc.summary.one_pass_scan)
      assert_true(!doc.summary.fallback_used)
      assert_true(!doc.summary.external_model_files_read)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 7 parser-fact-only line: " + message)
  }
}

///|
test "pdf v2 block reconstruction emits source-order block candidate" {
  let path = "/tmp/markitdown-pdf-v2-phase8-source-order-block.pdf"
  phase3_write_fixture(path, phase8_source_order_block_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.line_candidates.length() == 2)
      assert_true(doc.block_candidates.length() == 1)
      assert_true(doc.block_candidates[0].text.contains("Hello"))
      assert_true(doc.block_candidates[0].text.contains("World"))
      assert_true(doc.block_candidates[0].source_refs.length() == 10)
      assert_true(doc.block_candidates[0].bbox is None)
      assert_true(
        doc.block_candidates[0].geometry_confidence ==
        @pdfv2.PdfV2GeometryConfidence::Unknown,
      )
      assert_true(
        doc.block_candidates[0].block_kind_hint ==
        @pdfv2.PdfV2BlockKindHint::TextLike,
      )
      assert_true(
        phase8_has_block_reason(
          doc.block_candidates,
          "block_geometry_unavailable",
        ),
      )
      assert_true(doc.reconstruction_summary.block_candidate_count == 1)
      assert_true(doc.reconstruction_summary.lines_grouped_count == 2)
      assert_true(doc.pages[0].text_blocks.length() == 0)
      assert_true(doc.pages[0].layout_regions.length() == 0)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 8 source-order block candidate: " + message)
  }
}

///|
test "pdf v2 block reconstruction breaks on page boundary" {
  let path = "/tmp/markitdown-pdf-v2-phase8-page-boundary.pdf"
  phase3_write_fixture(path, phase8_two_page_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.line_candidates.length() == 2)
      assert_true(doc.block_candidates.length() == 2)
      assert_true(doc.block_candidates[0].text == "A")
      assert_true(doc.block_candidates[1].text == "B")
      assert_true(
        phase8_has_block_break_reason(doc.block_candidates, "page_change"),
      )
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 8 page-boundary blocks: " + message)
  }
}

///|
test "pdf v2 block reconstruction handles text object boundary conservatively" {
  let path = "/tmp/markitdown-pdf-v2-phase8-text-object-boundary.pdf"
  phase3_write_fixture(path, phase7_text_object_boundary_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.line_candidates.length() == 2)
      assert_true(doc.block_candidates.length() == 2)
      assert_true(
        phase8_has_block_break_reason(
          doc.block_candidates,
          "text_object_boundary",
        ),
      )
      assert_true(
        !(doc.block_candidates.length() == 1 &&
        !phase8_has_block_reason(doc.block_candidates, "text_object_boundary")),
      )
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 8 text object boundary blocks: " + message)
  }
}

///|
test "pdf v2 block reconstruction enforces max lines per block" {
  let path = "/tmp/markitdown-pdf-v2-phase8-max-lines-per-block.pdf"
  phase3_write_fixture(path, phase8_three_line_block_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      let blocks = @pdfv2.pdf_v2_reconstruct_block_candidates(
        doc.line_candidates,
        phase8_block_options(10, 2, true, false, false),
      )
      assert_true(doc.line_candidates.length() == 3)
      assert_true(blocks.blocks.length() == 2)
      assert_true(blocks.blocks[0].text.contains("A"))
      assert_true(blocks.blocks[0].text.contains("B"))
      assert_true(blocks.blocks[1].text == "C")
      assert_true(
        phase8_has_block_break_reason(blocks.blocks, "max_lines_per_block"),
      )
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 8 max lines per block: " + message)
  }
}

///|
test "pdf v2 block reconstruction max_blocks cap is explicit" {
  let path = "/tmp/markitdown-pdf-v2-phase8-max-blocks.pdf"
  phase3_write_fixture(path, phase8_three_line_block_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      let blocks = @pdfv2.pdf_v2_reconstruct_block_candidates(
        doc.line_candidates,
        phase8_block_options(1, 1, true, false, false),
      )
      assert_true(blocks.blocks.length() == 1)
      assert_true(blocks.summary.max_block_cap_hit)
      assert_true(
        phase8_has_block_break_reason(blocks.blocks, "max_blocks_cap"),
      )
      assert_true(
        phase3_has_warning_kind(
          blocks.warnings,
          @pdfv2.PdfV2WarningKind::PerformanceCap,
        ),
      )
      assert_true(
        phase3_has_risk_kind(
          blocks.risks,
          @pdfv2.PdfV2RiskKind::PerformanceCapReached,
        ),
      )
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 8 max blocks cap: " + message)
  }
}

///|
test "pdf v2 block reconstruction keeps geometry unavailable conservative" {
  let path = "/tmp/markitdown-pdf-v2-phase8-geometry-unavailable.pdf"
  phase3_write_fixture(path, phase4_simple_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.block_candidates.length() == 1)
      assert_true(doc.block_candidates[0].bbox is None)
      assert_true(
        doc.block_candidates[0].geometry_confidence ==
        @pdfv2.PdfV2GeometryConfidence::Unknown,
      )
      assert_true(
        doc.block_candidates[0].reason_tags.contains(
          "block_geometry_unavailable",
        ),
      )
      assert_true(doc.reconstruction_summary.block_geometry_missing_count == 1)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 8 geometry unavailable block: " + message)
  }
}

///|
test "pdf v2 block reconstruction keeps unknown decode conservative" {
  let path = "/tmp/markitdown-pdf-v2-phase8-unknown-decode.pdf"
  phase3_write_fixture(path, phase4_missing_font_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.block_candidates.length() == 1)
      assert_true(
        doc.block_candidates[0].decode_confidence !=
        @pdfv2.PdfV2TextDecodeConfidence::High,
      )
      assert_true(
        doc.block_candidates[0].decode_confidence ==
        @pdfv2.PdfV2TextDecodeConfidence::Unknown ||
        doc.block_candidates[0].decode_confidence ==
        @pdfv2.PdfV2TextDecodeConfidence::Failed,
      )
      assert_true(
        doc.block_candidates[0].block_kind_hint !=
        @pdfv2.PdfV2BlockKindHint::TextLike,
      )
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 8 unknown decode block: " + message)
  }
}

///|
test "pdf v2 block reconstruction remains parser facts only" {
  let path = "/tmp/markitdown-pdf-v2-phase8-no-semantic-convert.pdf"
  phase3_write_fixture(path, phase8_source_order_block_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.block_candidates.length() == 1)
      assert_true(
        doc.block_candidates[0].block_kind_hint ==
        @pdfv2.PdfV2BlockKindHint::TextLike,
      )
      assert_true(doc.pages[0].text_blocks.length() == 0)
      assert_true(doc.pages[0].layout_regions.length() == 0)
      assert_true(doc.summary.one_pass_scan)
      assert_true(!doc.summary.fallback_used)
      assert_true(!doc.summary.external_model_files_read)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 8 parser-fact-only block: " + message)
  }
}

///|
test "pdf v2 model assembly opens minimal real pdf model" {
  let path = "/tmp/markitdown-pdf-v2-phase9-minimal-model.pdf"
  phase3_write_fixture(path, phase4_simple_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_model_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    ModelAssemblyOk(model) => {
      assert_true(model.page_count == 1)
      assert_true(model.pages.length() == 1)
      assert_true(model.pages[0].blocks.length() == 1)
      assert_true(model.pages[0].lines.length() == 1)
      assert_true(model.pages[0].spans.length() == 1)
      assert_true(model.pages[0].chars.length() == 5)
      assert_true(model.one_pass)
      assert_true(model.no_fallback)
      assert_true(model.source_summary.one_pass_scan)
      assert_true(!model.source_summary.fallback_used)
      assert_true(
        model.pages[0].blocks[0].block_kind_hint ==
        @pdfv2.PdfV2BlockKindHint::TextLike,
      )
      assert_true(model.pages[0].text_blocks.length() == 0)
      assert_true(model.pages[0].layout_regions.length() == 0)
    }
    ModelAssemblyErr(_, _, message) =>
      fail("expected Phase 9 minimal model: " + message)
  }
}

///|
test "pdf v2 model assembly groups candidates by page" {
  let path = "/tmp/markitdown-pdf-v2-phase9-two-page-model.pdf"
  phase3_write_fixture(path, phase8_two_page_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_document_model_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    ModelAssemblyOk(model) => {
      assert_true(model.page_count == 2)
      assert_true(model.pages.length() == 2)
      assert_true(model.pages[0].blocks.length() == 1)
      assert_true(model.pages[1].blocks.length() == 1)
      for ch in model.pages[0].chars {
        assert_true(ch.page_index == Some(0))
      }
      for ch in model.pages[1].chars {
        assert_true(ch.page_index == Some(1))
      }
      assert_true(model.pages[0].blocks[0].page_index == Some(0))
      assert_true(model.pages[1].blocks[0].page_index == Some(1))
      assert_true(model.source_summary.page_count == 2)
    }
    ModelAssemblyErr(_, _, message) =>
      fail("expected Phase 9 two-page model: " + message)
  }
}

///|
test "pdf v2 model assembly preserves source refs" {
  let path = "/tmp/markitdown-pdf-v2-phase9-source-refs.pdf"
  phase3_write_fixture(path, phase4_simple_text_pdf())
  defer phase3_cleanup_fixture(path)

  let source_result = @pdfv2.parse_pdf_v2_source_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match source_result {
    SourceOpenOk(source) => {
      let block_ref = source.block_candidates[0].source_refs[0]
      let line_ref = source.line_candidates[0].source_refs[0]
      let span_ref = source.span_candidates[0].source_refs[0]
      let char_ref = source.char_candidates[0].source_ref
      match @pdfv2.pdf_v2_document_model_from_source(source) {
        ModelAssemblyOk(model) => {
          let model_block_ref = model.pages[0].blocks[0].source_refs[0]
          let model_line_ref = model.pages[0].lines[0].source_refs[0]
          let model_span_ref = model.pages[0].spans[0].source_refs[0]
          let model_char_ref = model.pages[0].chars[0].source_ref
          assert_true(model_block_ref.page_index == block_ref.page_index)
          assert_true(model_block_ref.stream_index == block_ref.stream_index)
          assert_true(model_line_ref.op_index == line_ref.op_index)
          assert_true(model_span_ref.object_id == span_ref.object_id)
          assert_true(
            model_char_ref.content_order_index == char_ref.content_order_index,
          )
        }
        ModelAssemblyErr(_, _, message) =>
          fail("expected Phase 9 source-ref model: " + message)
      }
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 9 source doc: " + message)
  }
}

///|
test "pdf v2 model assembly preserves warnings and risks" {
  let path = "/tmp/markitdown-pdf-v2-phase9-warning-risk.pdf"
  phase3_write_fixture(path, phase4_missing_font_pdf())
  defer phase3_cleanup_fixture(path)

  let source_result = @pdfv2.pdf_v2_open_source_document_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match source_result {
    SourceOpenOk(source) => {
      let warning_count = source.warnings.length()
      let risk_count = source.risks.length()
      assert_true(warning_count > 0)
      assert_true(risk_count > 0)
      match @pdfv2.pdf_v2_document_model_from_source(source) {
        ModelAssemblyOk(model) => {
          assert_true(model.warnings.length() >= warning_count)
          assert_true(model.risks.length() >= risk_count)
          assert_true(
            phase4_has_warning_reason(model.warnings, "missing_font_resource"),
          )
          assert_true(
            phase3_has_risk_kind(
              model.risks,
              @pdfv2.PdfV2RiskKind::DecodeLowConfidence,
            ),
          )
        }
        ModelAssemblyErr(_, _, message) =>
          fail("expected Phase 9 warning-risk model: " + message)
      }
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 9 warning-risk source doc: " + message)
  }
}

///|
test "pdf v2 model assembly keeps parser facts non-semantic" {
  let path = "/tmp/markitdown-pdf-v2-phase9-no-semantic.pdf"
  phase3_write_fixture(path, phase8_source_order_block_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_document_model_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    ModelAssemblyOk(model) => {
      assert_true(model.pages[0].blocks.length() == 1)
      assert_true(
        model.pages[0].blocks[0].block_kind_hint ==
        @pdfv2.PdfV2BlockKindHint::TextLike,
      )
      assert_true(model.pages[0].text_blocks.length() == 0)
      assert_true(model.pages[0].layout_regions.length() == 0)
      assert_true(model.layout.regions.length() == 0)
      assert_true(model.layout.reading_order.region_indices.length() == 0)
      assert_true(model.one_pass)
      assert_true(model.no_fallback)
    }
    ModelAssemblyErr(_, _, message) =>
      fail("expected Phase 9 non-semantic model: " + message)
  }
}

///|
test "pdf v2 model assembly summary counts match candidates" {
  let path = "/tmp/markitdown-pdf-v2-phase9-summary.pdf"
  phase3_write_fixture(path, phase8_source_order_block_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.pdf_v2_open_document_model_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    ModelAssemblyOk(model) => {
      let mut block_count = 0
      let mut line_count = 0
      let mut span_count = 0
      let mut char_count = 0
      for page in model.pages {
        block_count = block_count + page.blocks.length()
        line_count = line_count + page.lines.length()
        span_count = span_count + page.spans.length()
        char_count = char_count + page.chars.length()
      }
      assert_true(
        block_count == model.reconstruction_summary.block_candidate_count,
      )
      assert_true(
        line_count == model.reconstruction_summary.line_candidate_count,
      )
      assert_true(
        span_count == model.reconstruction_summary.span_candidate_count,
      )
      assert_true(
        char_count == model.reconstruction_summary.char_candidate_count,
      )
      assert_true(model.page_count == model.pages.length())
    }
    ModelAssemblyErr(_, _, message) =>
      fail("expected Phase 9 summary model: " + message)
  }
}

///|
test "pdf v2 layout facts expose minimal text scaffold" {
  let path = "/tmp/markitdown-pdf-v2-phase10-minimal-layout-facts.pdf"
  phase3_write_fixture(path, phase4_simple_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_layout_facts_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    LayoutFactOk(facts) => {
      assert_true(facts.summary.page_count == 1)
      assert_true(facts.page_layouts.length() == 1)
      assert_true(facts.one_pass)
      assert_true(facts.no_fallback)
      let page = facts.page_layouts[0]
      assert_true(page.text_candidate_refs.has_block_candidates)
      assert_true(page.text_candidate_refs.has_line_candidates)
      assert_true(page.text_candidate_refs.has_span_candidates)
      assert_true(page.text_candidate_refs.has_char_candidates)
      assert_true(page.text_candidate_refs.char_count == 5)
      assert_true(page.text_candidate_refs.source_refs.length() > 0)
      assert_true(
        page.reading_order_status ==
        @pdfv2.PdfV2LayoutRecoveryStatus::SourceOrderOnly,
      )
      assert_true(
        page.layout_region_status ==
        @pdfv2.PdfV2LayoutRecoveryStatus::InsufficientGeometry,
      )
      assert_true(
        page.table_region_status ==
        @pdfv2.PdfV2LayoutRecoveryStatus::NotAttempted,
      )
    }
    LayoutFactErr(_, _, message) =>
      fail("expected Phase 10 minimal layout facts: " + message)
  }
}

///|
test "pdf v2 layout facts keep missing geometry explicit" {
  let path = "/tmp/markitdown-pdf-v2-phase10-missing-geometry.pdf"
  phase3_write_fixture(path, phase4_simple_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_layout_facts_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    LayoutFactOk(facts) => {
      let page = facts.page_layouts[0]
      assert_true(
        page.geometry_coverage == @pdfv2.PdfV2GeometryCoverage::Missing,
      )
      assert_true(
        phase4_has_warning_reason(facts.warnings, "layout_geometry_missing"),
      )
      assert_true(
        phase4_has_warning_reason(page.warnings, "insufficient_geometry"),
      )
      assert_true(facts.summary.pages_with_missing_geometry == 1)
      assert_true(
        page.source_refs.length() > page.text_candidate_refs.char_count,
      )
    }
    LayoutFactErr(_, _, message) =>
      fail("expected Phase 10 missing geometry facts: " + message)
  }
}

///|
test "pdf v2 layout facts keep empty page non-inferred" {
  let path = "/tmp/markitdown-pdf-v2-phase10-empty-page.pdf"
  phase3_write_fixture(path, phase3_one_page_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_layout_facts_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    LayoutFactOk(facts) => {
      assert_true(facts.summary.page_count == 1)
      assert_true(facts.summary.pages_with_text_candidates == 0)
      assert_true(facts.summary.pages_with_layout_not_attempted == 1)
      let page = facts.page_layouts[0]
      assert_true(!page.text_candidate_refs.has_block_candidates)
      assert_true(!page.text_candidate_refs.has_line_candidates)
      assert_true(!page.text_candidate_refs.has_span_candidates)
      assert_true(!page.text_candidate_refs.has_char_candidates)
      assert_true(
        page.geometry_coverage == @pdfv2.PdfV2GeometryCoverage::Unknown,
      )
      assert_true(
        page.reading_order_status ==
        @pdfv2.PdfV2LayoutRecoveryStatus::NotAttempted,
      )
      assert_true(
        page.layout_region_status ==
        @pdfv2.PdfV2LayoutRecoveryStatus::NotAttempted,
      )
    }
    LayoutFactErr(_, _, message) =>
      fail("expected Phase 10 empty-page facts: " + message)
  }
}

///|
test "pdf v2 layout facts aggregate multi page candidates" {
  let path = "/tmp/markitdown-pdf-v2-phase10-two-page-facts.pdf"
  phase3_write_fixture(path, phase8_two_page_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_layout_facts_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    LayoutFactOk(facts) => {
      assert_true(facts.summary.page_count == 2)
      assert_true(facts.page_layouts.length() == 2)
      assert_true(facts.summary.pages_with_text_candidates == 2)
      assert_true(facts.summary.pages_with_block_candidates == 2)
      assert_true(facts.summary.pages_with_missing_geometry == 2)
      assert_true(facts.summary.pages_source_order_only == 2)
      assert_true(facts.page_layouts[0].page_index == 0)
      assert_true(facts.page_layouts[1].page_index == 1)
      assert_true(facts.page_layouts[0].text_candidate_refs.char_count == 1)
      assert_true(facts.page_layouts[1].text_candidate_refs.char_count == 1)
    }
    LayoutFactErr(_, _, message) =>
      fail("expected Phase 10 two-page facts: " + message)
  }
}

///|
test "pdf v2 layout facts preserve model and candidate source refs" {
  let path = "/tmp/markitdown-pdf-v2-phase10-source-refs.pdf"
  phase3_write_fixture(path, phase4_simple_text_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_model_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    ModelAssemblyOk(model) => {
      let page_ref = model.pages[0].source_ref
      let char_ref = model.pages[0].chars[0].source_ref
      let facts = @pdfv2.pdf_v2_layout_facts_from_model(model)
      let page = facts.page_layouts[0]
      assert_true(
        page.page_box_facts.source_ref.page_index == page_ref.page_index,
      )
      assert_true(page.source_refs[0].kind == @pdfv2.PdfV2SourceKind::Page)
      assert_true(
        page.text_candidate_refs.source_refs[0].content_order_index ==
        char_ref.content_order_index,
      )
      assert_true(facts.source_refs.length() >= page.source_refs.length())
      assert_true(facts.summary.warning_count == facts.warnings.length())
      assert_true(facts.summary.risk_count == facts.risks.length())
    }
    ModelAssemblyErr(_, _, message) =>
      fail("expected Phase 10 source-ref model: " + message)
  }
}

///|
test "pdf v2 layout facts do not perform semantic layout recovery or convert" {
  let path = "/tmp/markitdown-pdf-v2-phase10-no-semantic-convert.pdf"
  phase3_write_fixture(path, phase8_source_order_block_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_model_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    ModelAssemblyOk(model) => {
      assert_true(model.layout.regions.length() == 0)
      assert_true(model.layout.reading_order.region_indices.length() == 0)
      let facts = @pdfv2.pdf_v2_layout_facts_from_model(model)
      let page = facts.page_layouts[0]
      assert_true(
        page.reading_order_status ==
        @pdfv2.PdfV2LayoutRecoveryStatus::SourceOrderOnly,
      )
      assert_true(
        page.table_region_status ==
        @pdfv2.PdfV2LayoutRecoveryStatus::NotAttempted,
      )
      assert_true(
        page.image_region_status ==
        @pdfv2.PdfV2LayoutRecoveryStatus::NotAttempted,
      )
      assert_true(
        page.annotation_region_status ==
        @pdfv2.PdfV2LayoutRecoveryStatus::NotAttempted,
      )
      assert_true(!page.object_candidate_refs.has_annotations)
      assert_true(!page.object_candidate_refs.has_forms)
      assert_true(!page.object_candidate_refs.has_outlines)
      assert_true(!page.object_candidate_refs.has_destinations)
      assert_true(facts.one_pass)
      assert_true(facts.no_fallback)
    }
    ModelAssemblyErr(_, _, message) =>
      fail("expected Phase 10 no-semantic model: " + message)
  }
}

///|
test "pdf v2 object facts expose image xobject metadata candidate" {
  let path = "/tmp/markitdown-pdf-v2-phase11-image-xobject.pdf"
  phase3_write_fixture(path, phase11_image_xobject_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_source_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.image_candidates.length() == 1)
      let image = doc.image_candidates[0]
      assert_true(image.width == Some(2))
      assert_true(image.height == Some(1))
      assert_true(image.color_space == Some("/DeviceRGB"))
      assert_true(image.bits_per_component == Some(8))
      assert_true(image.filters.contains("/DCTDecode"))
      assert_true(!image.inline)
      assert_true(
        image.decode_status == @pdfv2.PdfV2ImageDecodeStatus::MetadataOnly,
      )
      assert_true(image.reason_tags.contains("image_decode_not_attempted"))
      assert_true(image.source_ref.kind == @pdfv2.PdfV2SourceKind::Image)
      assert_true(doc.object_summary.image_count == 1)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 11 image source facts: " + message)
  }
}

///|
test "pdf v2 object facts expose inline image metadata candidate" {
  let path = "/tmp/markitdown-pdf-v2-phase11-inline-image.pdf"
  phase3_write_fixture(path, phase11_inline_image_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_source_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    SourceOpenOk(doc) => {
      assert_true(doc.inline_image_candidates.length() == 1)
      let image = doc.inline_image_candidates[0]
      assert_true(image.width == Some(1))
      assert_true(image.height == Some(1))
      assert_true(image.color_space == Some("/DeviceGray"))
      assert_true(image.bits_per_component == Some(8))
      assert_true(image.filters.length() == 0)
      assert_true(
        image.decode_status == @pdfv2.PdfV2ImageDecodeStatus::MetadataOnly,
      )
      assert_true(image.reason_tags.contains("inline_image"))
      assert_true(image.source_ref.kind == @pdfv2.PdfV2SourceKind::InlineImage)
      assert_true(doc.object_summary.inline_image_count == 1)
    }
    SourceOpenErr(_, _, message) =>
      fail("expected Phase 11 inline image facts: " + message)
  }
}

///|
test "pdf v2 object facts expose link annotation candidate" {
  let path = "/tmp/markitdown-pdf-v2-phase11-link-annotation.pdf"
  phase3_write_fixture(path, phase11_link_annotation_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_model_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    ModelAssemblyOk(model) => {
      assert_true(model.pages[0].annotations.length() == 1)
      assert_true(model.pages[0].links.length() == 1)
      let annotation = model.pages[0].annotations[0]
      let link = model.pages[0].links[0]
      assert_true(annotation.subtype == Some("/Link"))
      assert_true(link.uri == Some("https://example.test/link"))
      match link.rect {
        Some(rect) => {
          assert_true(rect.x0 == 50.0)
          assert_true(rect.y0 == 40.0)
          assert_true(rect.x1 == 150.0)
          assert_true(rect.y1 == 80.0)
        }
        None => fail("expected link rect")
      }
      assert_true(link.reason_tags.contains("semantic_not_lowered"))
      assert_true(model.object_summary.link_count == 1)
    }
    ModelAssemblyErr(_, _, message) =>
      fail("expected Phase 11 link model facts: " + message)
  }
}

///|
test "pdf v2 object facts expose widget form candidate" {
  let path = "/tmp/markitdown-pdf-v2-phase11-widget-form.pdf"
  phase3_write_fixture(path, phase11_widget_form_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_model_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    ModelAssemblyOk(model) => {
      assert_true(model.pages[0].forms.length() >= 1)
      let form = model.pages[0].forms[0]
      assert_true(form.field_name == Some("Field1"))
      assert_true(form.alternate_name == Some("Field one"))
      assert_true(form.value == Some("Value1"))
      match form.rect {
        Some(rect) => assert_true(rect.x0 == 10.0 && rect.x1 == 110.0)
        None => fail("expected widget rect")
      }
      assert_true(form.reason_tags.contains("semantic_not_lowered"))
      assert_true(model.object_summary.form_count >= 1)
    }
    ModelAssemblyErr(_, _, message) =>
      fail("expected Phase 11 widget model facts: " + message)
  }
}

///|
test "pdf v2 object facts expose outline destination metadata candidates" {
  let path = "/tmp/markitdown-pdf-v2-phase11-outline-metadata.pdf"
  phase3_write_fixture(path, phase11_outline_destination_metadata_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_model_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    ModelAssemblyOk(model) => {
      assert_true(model.outlines.length() == 1)
      assert_true(model.destinations.length() == 1)
      assert_true(model.metadata_candidates.length() >= 2)
      assert_true(model.outlines[0].title == Some("Chapter 1"))
      assert_true(model.outlines[0].reason_tags.contains("toc_not_lowered"))
      assert_true(model.object_summary.outline_count == 1)
      assert_true(model.object_summary.destination_count == 1)
      assert_true(model.object_summary.metadata_count >= 2)
    }
    ModelAssemblyErr(_, _, message) =>
      fail("expected Phase 11 outline metadata model facts: " + message)
  }
}

///|
test "pdf v2 object facts expose page resource candidates" {
  let path = "/tmp/markitdown-pdf-v2-phase11-resources.pdf"
  phase3_write_fixture(path, phase11_image_xobject_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_model_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    ModelAssemblyOk(model) => {
      assert_true(model.pages[0].resources.length() >= 2)
      let mut has_image_resource = false
      let mut has_font_resource = false
      for resource in model.pages[0].resources {
        if resource.resource_kind == @pdfv2.PdfV2ResourceKind::ImageXObject {
          has_image_resource = true
          assert_true(resource.name == "/Im1")
          assert_true(resource.object_ref == Some("5 0 R"))
        }
        if resource.resource_kind == @pdfv2.PdfV2ResourceKind::Font {
          has_font_resource = true
        }
      }
      assert_true(has_image_resource)
      assert_true(has_font_resource)
      assert_true(model.object_summary.resource_count >= 2)
    }
    ModelAssemblyErr(_, _, message) =>
      fail("expected Phase 11 resource model facts: " + message)
  }
}

///|
test "pdf v2 layout facts include object coverage statuses" {
  let path = "/tmp/markitdown-pdf-v2-phase11-layout-object-coverage.pdf"
  phase3_write_fixture(path, phase11_image_xobject_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_layout_facts_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    LayoutFactOk(facts) => {
      let page = facts.page_layouts[0]
      assert_true(page.object_candidate_refs.has_images)
      assert_true(page.object_candidate_refs.has_resources)
      assert_true(
        page.image_region_status ==
        @pdfv2.PdfV2LayoutRecoveryStatus::PartialFacts,
      )
      assert_true(
        page.annotation_region_status ==
        @pdfv2.PdfV2LayoutRecoveryStatus::NotAttempted,
      )
      assert_true(
        page.table_region_status ==
        @pdfv2.PdfV2LayoutRecoveryStatus::NotAttempted,
      )
      assert_true(page.object_candidate_refs.source_refs.length() > 0)
    }
    LayoutFactErr(_, _, message) =>
      fail("expected Phase 11 layout object coverage: " + message)
  }
}

///|
test "pdf v2 object facts remain parser facts without semantic convert fallback" {
  let path = "/tmp/markitdown-pdf-v2-phase11-no-semantic-convert.pdf"
  phase3_write_fixture(path, phase11_image_xobject_pdf())
  defer phase3_cleanup_fixture(path)

  let result = @pdfv2.parse_pdf_v2_model_from_path(
    path,
    @pdfv2.default_pdf_v2_core_open_options(),
  )
  match result {
    ModelAssemblyOk(model) => {
      assert_true(model.pages[0].images.length() == 1)
      assert_true(model.pages[0].images[0].bbox is None)
      assert_true(
        model.pages[0].images[0].decode_status ==
        @pdfv2.PdfV2ImageDecodeStatus::MetadataOnly,
      )
      assert_true(model.layout.regions.length() == 0)
      assert_true(model.layout.reading_order.region_indices.length() == 0)
      assert_true(model.one_pass)
      assert_true(model.no_fallback)
      assert_true(model.source_summary.one_pass_scan)
      assert_true(!model.source_summary.fallback_used)
      assert_true(!model.source_summary.external_model_files_read)
    }
    ModelAssemblyErr(_, _, message) =>
      fail("expected Phase 11 parser-fact-only model: " + message)
  }
}
