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
