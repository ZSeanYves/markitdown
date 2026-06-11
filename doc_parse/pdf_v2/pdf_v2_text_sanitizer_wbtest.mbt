///|
test "pdf v2 text sanitizer drops unsafe controls and preserves CJK" {
  let source_ref = pdf_v2_document_source_ref()
  let raw = String::from_array([
    'A', '\u{0000}', 'B', '\u{0001}', 'C', '\t', '中',
  ])
  let sanitized = pdf_v2_sanitize_decoded_text_for_candidate(raw, source_ref)
  assert_true(sanitized.text == "ABC 中")
  assert_true(sanitized.dropped_count == 2)
  assert_true(sanitized.reason_tags.contains("nul_byte_dropped"))
  assert_true(sanitized.reason_tags.contains("control_byte_dropped"))
  assert_true(sanitized.reason_tags.contains("text_whitespace_normalized"))
  assert_true(sanitized.warnings.length() == 1)
  assert_true(sanitized.warnings[0].kind == PdfV2WarningKind::DecodeIssue)
}

///|
test "pdf v2 object string decode handles bom and suppresses controls" {
  let source_ref = pdf_v2_document_source_ref()
  let utf16 = @pdfio.string_of_int_array([0xfe, 0xff, 0x00, 0x48, 0x00, 0x69])
  let decoded = pdf_v2_decode_pdfdoc_string_text(utf16, source_ref)
  match decoded {
    (Some(text), tags, warnings) => {
      assert_true(text == "Hi")
      assert_true(tags.contains("pdfdoc_string"))
      assert_true(warnings.length() == 0)
    }
    _ => fail("expected UTF-16BE BOM PDFDocString decode")
  }
  let binary = @pdfio.string_of_int_array([0x41, 0x00, 0x42])
  let suppressed = pdf_v2_decode_pdfdoc_string_text(binary, source_ref)
  match suppressed {
    (None, tags, warnings) => {
      assert_true(tags.contains("pdfdoc_string"))
      assert_true(tags.contains("control_byte_dropped"))
      assert_true(warnings.length() == 1)
    }
    _ => fail("expected binary PDFDocString suppression")
  }
}
