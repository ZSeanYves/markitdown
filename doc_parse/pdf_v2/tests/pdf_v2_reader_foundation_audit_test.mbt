///|
struct PdfV2ReaderFoundationAuditRow {
  sample : String
  pdf_path : String
  pages : Int
  content_streams : Int
  text_ops : Int
  decoded_chars : Int
  low_confidence_chars : Int
  low_confidence_ratio : Double
  type0 : Bool
  cid : Bool
  subset : Bool
  tounicode : Bool
  nfc_normalized : Bool
  bad_tounicode_handled : Int
  warnings : Int
  risks : Int
  source_events : Int
  glyphs : Int
  lowered_blocks : Int
  no_fallback_preserved : Bool
  source_to_lowering_stable : Bool
  top_reason_tags : Array[String]
}

///|
test "test_reader_foundation_audit_runs_full_pipeline" {
  let rows = reader_foundation_collect_audit()
  assert_eq(rows.length(), reader_foundation_cases().length())
  let mut text_samples = 0
  for row in rows {
    assert_true(row.no_fallback_preserved)
    assert_true(row.source_to_lowering_stable)
    if row.decoded_chars > 0 {
      text_samples = text_samples + 1
      assert_true(row.lowered_blocks > 0)
    }
  }
  assert_true(text_samples >= 5)
  reader_foundation_write_tmp_summary(rows)
}

///|
test "test_reader_foundation_audit_no_fallback" {
  for row in reader_foundation_collect_audit() {
    assert_true(row.no_fallback_preserved)
    assert_eq(
      reset19_has_any_tag(row.top_reason_tags, [
        "legacy_fallback", "old_pdf_fallback", "convert_raw_reparse", "convert_pdf_reparse",
        "doc_parse_pdf_fallback",
      ]),
      false,
    )
  }
}

///|
test "test_reader_foundation_audit_summary_has_expected_fields" {
  let generated = reader_foundation_summary_jsonl(
    reader_foundation_collect_audit(),
  )
  let archive_path = reset19_resolve_path(
    "docs/archive/pdf-v2-reader-foundation-audit-summary.jsonl",
  )
  let archived = @fs.read_file_to_string(archive_path, encoding="utf8") catch {
    e => fail("reader foundation read archive summary failed: " + e.to_string())
  }
  assert_eq(archived, generated)
  assert_true(archived.length() < 12000)
  assert_true(archived.contains("\"sample\""))
  assert_true(archived.contains("\"low_confidence_ratio\""))
  assert_true(archived.contains("\"top_reason_tags\""))
  assert_true(archived.contains("\"no_fallback_preserved\""))
}

///|
test "test_reader_foundation_summary_metrics_are_visible_on_core_warnings" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_type0_cid_tounicode_pdf_bytes(
      "<0001>",
      base_tounicode_cmap_header("<0000> <FFFF>") +
      "1 beginbfchar\n" +
      "<0001> <0041>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  let warning_tags = reset19_warning_tags(core.warnings)
  assert_true(reset19_has_tag(warning_tags, "reader_summary_metrics"))
  assert_true(reset19_has_tag(warning_tags, "decoded_stream_count"))
  assert_true(reset19_has_tag(warning_tags, "decoded_char_count"))
  assert_true(reset19_has_tag(warning_tags, "font_count"))
  assert_true(reset19_has_tag(warning_tags, "tounicode_present_count"))
  assert_true(reset19_has_tag(warning_tags, "nfc_normalized_count"))
  assert_true(
    reset19_has_tag(warning_tags, "stream_bytes_not_exposed_to_convert"),
  )
}

///|
fn reader_foundation_collect_audit() -> Array[PdfV2ReaderFoundationAuditRow] raise {
  let rows : Array[PdfV2ReaderFoundationAuditRow] = []
  for c in reader_foundation_cases() {
    let row = reader_foundation_run_case(c)
    if c.expect_text {
      assert_true(row.decoded_chars > 0)
      assert_true(row.text_ops > 0)
    }
    rows.push(row)
  }
  rows
}

///|
fn reader_foundation_cases() -> Array[PdfV2Reset19Case] {
  [
    {
      name: "mbtpdf_pdfjs_identity_tounicode",
      path: "doc_parse/pdf/vendor/mbtpdf/testdata/pdfjs_identity_tounicode.pdf",
      synthetic_encrypted_marker: false,
      expect_text: true,
      expect_tounicode: true,
    },
    {
      name: "mbtpdf_pdfjs_arial_unicode_ab_cidfont",
      path: "doc_parse/pdf/vendor/mbtpdf/testdata/pdfjs_arial_unicode_ab_cidfont.pdf",
      synthetic_encrypted_marker: false,
      expect_text: true,
      expect_tounicode: true,
    },
    {
      name: "mbtpdf_pandoc_unicode",
      path: "doc_parse/pdf/vendor/mbtpdf/testdata/pandoc/pandoc_unicode.pdf",
      synthetic_encrypted_marker: false,
      expect_text: true,
      expect_tounicode: true,
    },
    {
      name: "sample_text_simple",
      path: "samples/main_process/pdf/text_simple.pdf",
      synthetic_encrypted_marker: false,
      expect_text: true,
      expect_tounicode: false,
    },
    {
      name: "sample_repeated_header_footer",
      path: "samples/main_process/pdf/pdf_repeated_header_footer.pdf",
      synthetic_encrypted_marker: false,
      expect_text: true,
      expect_tounicode: false,
    },
    {
      name: "pdfjs_annotation_hidden_print_xref_stream",
      path: "doc_parse/pdf/testdata/pdfjs/annotation_hidden_print.pdf",
      synthetic_encrypted_marker: false,
      expect_text: false,
      expect_tounicode: false,
    },
    {
      name: "synthetic_encrypted_marker",
      path: "<synthetic:encrypted_marker>",
      synthetic_encrypted_marker: true,
      expect_text: false,
      expect_tounicode: false,
    },
  ]
}

///|
fn reader_foundation_run_case(
  c : PdfV2Reset19Case,
) -> PdfV2ReaderFoundationAuditRow raise {
  let bytes = reset19_case_bytes(c)
  let core = @pdfv2.open_pdf_core_v2_perf(bytes)
  let source = @source_event.build_pdf_v2_source_event_document(core, [])
  let text_model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  let model = @normalized_model.build_pdf_v2_document_model(source, text_model)
  let layout = @layout_recovery.recover_pdf_v2_layout(
    model,
    @layout_recovery.default_pdf_v2_layout_recovery_options(),
  )
  let features = @feature_export.export_pdf_v2_block_features(model, layout, {
    ..@feature_export.default_pdf_v2_feature_export_options(),
    doc_id: c.name,
  })
  let decisions = @classifier_gate.build_pdf_v2_block_decisions(
    features.records,
    @classifier_gate.default_pdf_v2_block_decision_options(),
  )
  let lowered = @lowering.lower_pdf_v2_document(
    model,
    features.records,
    decisions,
    @lowering.default_pdf_v2_lowering_options(),
  )
  let core_tags = reset19_core_reason_tags(core)
  let reason_tags = reset19_unique_strings(core_tags + lowered.reason_tags)
  let decoded_chars = reset19_decoded_char_count(core.text_events)
  let low_confidence_chars = reset19_low_confidence_char_count(core.text_events)
  let warnings = core.warnings.length() +
    source.warnings.length() +
    text_model.warnings.length() +
    model.warnings.length() +
    layout.warnings.length() +
    features.warnings.length() +
    lowered.warnings.length()
  let risks = core.risks.length() +
    source.risks.length() +
    text_model.risks.length() +
    model.risks.length() +
    layout.risks.length() +
    features.risks.length() +
    lowered.parser_risks.length()
  let no_fallback = reset19_no_fallback_preserved(
    core, source, text_model, model, layout, features, lowered,
  )
  {
    sample: c.name,
    pdf_path: c.path,
    pages: core.page_count,
    content_streams: core.content_streams.length(),
    text_ops: core.text_events.length(),
    decoded_chars,
    low_confidence_chars,
    low_confidence_ratio: if decoded_chars == 0 {
      0.0
    } else {
      low_confidence_chars.to_double() / decoded_chars.to_double()
    },
    type0: reset19_has_tag(reason_tags, "font_type_type0"),
    cid: reset19_has_tag(reason_tags, "font_type_cid"),
    subset: reset19_has_tag(reason_tags, "font_subset_detected"),
    tounicode: reset19_has_any_tag(reason_tags, [
      "tounicode_present", "cmap_used", "decode_source_tounicode",
    ]),
    nfc_normalized: reset19_has_tag(reason_tags, "nfc_normalized_applied"),
    bad_tounicode_handled: reset19_tag_count(
      reason_tags, "bad_tounicode_handled",
    ),
    warnings,
    risks,
    source_events: source.summary.event_count,
    glyphs: text_model.summary.glyph_count,
    lowered_blocks: lowered.blocks.length(),
    no_fallback_preserved: no_fallback,
    source_to_lowering_stable: no_fallback &&
    core.scanned_once &&
    source.summary.scanned_once &&
    text_model.summary.scanned_once &&
    model.source_summary.scanned_once &&
    layout.summary.one_pass_required &&
    features.summary.one_pass_required &&
    lowered.summary.one_pass_required,
    top_reason_tags: reader_foundation_compact_reason_tags(reason_tags),
  }
}

///|
fn reader_foundation_write_tmp_summary(
  rows : Array[PdfV2ReaderFoundationAuditRow],
) -> Unit raise {
  let root = reset19_repo_root()
  let out_dir = reset19_join_path(root, ".tmp/pdf_v2_reader_foundation")
  reset19_ensure_dir_tree(out_dir)
  let out_path = reset19_join_path(out_dir, "audit_summary.jsonl")
  @fs.write_string_to_file(
    out_path,
    reader_foundation_summary_jsonl(rows),
    encoding="utf8",
  ) catch {
    e => fail("reader foundation write summary failed: " + e.to_string())
  }
}

///|
fn reader_foundation_summary_jsonl(
  rows : Array[PdfV2ReaderFoundationAuditRow],
) -> String {
  let lines : Array[String] = []
  for row in rows {
    lines.push(reader_foundation_row_json(row))
  }
  lines.join("\n") + "\n"
}

///|
fn reader_foundation_row_json(row : PdfV2ReaderFoundationAuditRow) -> String {
  reset19_compact_object_json([
    @cor.json_string("sample") + ": " + @cor.json_string(row.sample),
    @cor.json_string("pdf_path") + ": " + @cor.json_string(row.pdf_path),
    @cor.json_string("pages") + ": " + row.pages.to_string(),
    @cor.json_string("content_streams") + ": " + row.content_streams.to_string(),
    @cor.json_string("text_ops") + ": " + row.text_ops.to_string(),
    @cor.json_string("decoded_chars") + ": " + row.decoded_chars.to_string(),
    @cor.json_string("low_confidence_chars") +
    ": " +
    row.low_confidence_chars.to_string(),
    @cor.json_string("low_confidence_ratio") +
    ": " +
    row.low_confidence_ratio.to_string(),
    @cor.json_string("type0") + ": " + @cor.bool_json(row.type0),
    @cor.json_string("cid") + ": " + @cor.bool_json(row.cid),
    @cor.json_string("subset") + ": " + @cor.bool_json(row.subset),
    @cor.json_string("tounicode") + ": " + @cor.bool_json(row.tounicode),
    @cor.json_string("nfc_normalized") +
    ": " +
    @cor.bool_json(row.nfc_normalized),
    @cor.json_string("bad_tounicode_handled") +
    ": " +
    row.bad_tounicode_handled.to_string(),
    @cor.json_string("warnings") + ": " + row.warnings.to_string(),
    @cor.json_string("risks") + ": " + row.risks.to_string(),
    @cor.json_string("source_events") + ": " + row.source_events.to_string(),
    @cor.json_string("glyphs") + ": " + row.glyphs.to_string(),
    @cor.json_string("lowered_blocks") + ": " + row.lowered_blocks.to_string(),
    @cor.json_string("no_fallback_preserved") +
    ": " +
    @cor.bool_json(row.no_fallback_preserved),
    @cor.json_string("source_to_lowering_stable") +
    ": " +
    @cor.bool_json(row.source_to_lowering_stable),
    @cor.json_string("top_reason_tags") +
    ": " +
    reset19_compact_string_array_json(row.top_reason_tags),
  ])
}

///|
fn reader_foundation_compact_reason_tags(tags : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for tag in tags {
    if reader_foundation_reason_tag_allowed(tag) && !out.contains(tag) {
      out.push(tag)
    }
  }
  out
}

///|
fn reader_foundation_reason_tag_allowed(tag : String) -> Bool {
  reset19_has_any_tag([tag], [
    "reader_summary_metrics", "source_ref_preserved", "object_ref_preserved", "font_resource_name_preserved",
    "page_resources_present", "font_resource_present", "filter_flate_decode_used",
    "decode_source_tounicode", "tonyfettes_encoding_utf16be", "tonyfettes_unicode_helper",
    "nfc_normalized_applied", "tounicode_bfchar_applied", "tounicode_bfrange_applied",
    "tounicode_codespace_multibyte", "tounicode_source_multibyte", "bad_tounicode_handled",
    "tounicode_unmapped_code", "glyph_decode_low_confidence", "text_retained", "font_type_type0",
    "font_type_cid", "cid_font_type2", "font_subset_detected", "embedded_font_present",
    "embedded_font_missing", "cid_system_info_present", "object_stream_detected",
    "xref_stream_detected", "xref_table_used", "encrypted_pdf_detected", "encrypted_pdf_unsupported",
    "stream_bytes_not_exposed_to_convert", "no_fallback", "no_legacy_fallback", "convert_raw_reparse_forbidden",
    "one_pass_required", "fail_closed",
  ])
}
