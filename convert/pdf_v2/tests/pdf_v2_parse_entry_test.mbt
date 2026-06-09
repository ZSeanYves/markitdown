///|
test "test_parse_pdf_v2_minimal_text_pdf_fail_closes_until_mbtpdf_base" {
  let result = @pdfv2convert.parse_pdf_v2_bytes_with_options(
    convert_pdf_v2_minimal_text_pdf_bytes(),
    "minimal-text.pdf",
    @pdfv2convert.default_pdf_v2_convert_options(),
  )
  assert_eq(result.core.text_events.length(), 0)
  assert_eq(result.text_model.summary.block_count, 0)
  assert_eq(result.document.blocks.val.length(), 1)
  match result.document.blocks.val[0] {
    @cor.Block::Paragraph(text) =>
      assert_true(text.contains("reader scaffold produced no text blocks"))
    _ => fail("expected conservative paragraph")
  }
  assert_eq(
    has_convert_warning_tag(result.core.warnings, "self_written_core_removed"),
    true,
  )
  assert_eq(@pdfv2convert.pdf_v2_pipeline_preserves_no_fallback(result), true)
}

///|
test "test_no_legacy_fallback_even_on_malformed_pdf" {
  let result = @pdfv2convert.parse_pdf_v2_bytes_with_options(
    Bytes::from_array([37, 80, 68, 70]),
    "malformed.pdf",
    @pdfv2convert.default_pdf_v2_convert_options(),
  )
  assert_eq(result.core.text_events.length(), 0)
  assert_eq(result.document.blocks.val.length(), 1)
  assert_eq(@pdfv2convert.pdf_v2_pipeline_preserves_no_fallback(result), true)
}

///|
test "test_convert_entry_does_not_call_old_pdf_parser" {
  let result = @pdfv2convert.parse_pdf_v2_bytes_with_options(
    convert_pdf_v2_minimal_text_pdf_bytes(),
    "no-legacy.pdf",
    @pdfv2convert.default_pdf_v2_convert_options(),
  )
  assert_eq(result.reason_tags.contains("no_old_convert_pdf"), true)
  assert_eq(result.reason_tags.contains("no_old_doc_parse_pdf"), true)
  assert_eq(result.lowering.reason_tags.contains("no_old_pdf_runtime"), true)
  assert_eq(result.source.summary.convert_raw_reparse_allowed, false)
  assert_eq(result.core.text_events.length(), 0)
}

///|
test "test_convert_flate_stream_uses_scaffold_warning_without_fallback" {
  let result = @pdfv2convert.parse_pdf_v2_bytes_with_options(
    convert_pdf_v2_flate_text_pdf_bytes(),
    "flate.pdf",
    @pdfv2convert.default_pdf_v2_convert_options(),
  )
  assert_eq(result.core.content_streams.length(), 0)
  assert_eq(result.core.text_events.length(), 0)
  assert_eq(
    has_convert_warning_tag(result.core.warnings, "self_written_core_removed"),
    true,
  )
  assert_eq(@pdfv2convert.pdf_v2_pipeline_preserves_no_fallback(result), true)
}

///|
fn convert_pdf_v2_minimal_text_pdf_bytes() -> Bytes {
  convert_pdf_v2_bytes_from_ascii(
    "%PDF-1.4\n" +
    "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n" +
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n" +
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>\nendobj\n" +
    "4 0 obj\n<< /Length 47 >>\nstream\nBT /F1 12 Tf 72 720 Td (Hello PDF v2) Tj ET\nendstream\nendobj\n" +
    "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj\n" +
    "xref\n0 6\n0000000000 65535 f \ntrailer\n<< /Root 1 0 R /Size 6 >>\nstartxref\n0\n%%EOF\n",
  )
}

///|
fn convert_pdf_v2_flate_text_pdf_bytes() -> Bytes {
  convert_pdf_v2_bytes_from_ascii(
    "%PDF-1.4\n" +
    "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n" +
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n" +
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>\nendobj\n" +
    "4 0 obj\n<< /Length 8 /Filter /FlateDecode >>\nstream\nnotflate\nendstream\nendobj\n" +
    "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj\n" +
    "xref\n0 6\n0000000000 65535 f \ntrailer\n<< /Root 1 0 R /Size 6 >>\nstartxref\n0\n%%EOF\n",
  )
}

///|
fn convert_pdf_v2_bytes_from_ascii(text : String) -> Bytes {
  let out : Array[Byte] = []
  for ch in text.to_array() {
    out.push(ch.to_int().to_byte())
  }
  Bytes::from_array(out)
}

///|
fn has_convert_warning_tag(
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
