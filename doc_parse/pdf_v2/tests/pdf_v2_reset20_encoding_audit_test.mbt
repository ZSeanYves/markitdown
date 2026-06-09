///|
struct PdfV2Reset20AuditRow {
  sample_name : String
  pdf_path : String
  pages : Int
  content_streams : Int
  text_ops : Int
  decoded_chars : Int
  low_confidence_chars : Int
  low_confidence_ratio : Double
  warnings : Int
  risks : Int
  type0_font_seen : Bool
  cid_font_seen : Bool
  subset_font_seen : Bool
  tounicode_seen : Bool
  decode_source_tounicode_seen : Bool
  tonyfettes_encoding_utf16be_seen : Bool
  nfc_normalized_applied_seen : Bool
  nfc_normalized_applied_count : Int
  bad_tounicode_handled_count : Int
  tounicode_unmapped_code_count : Int
  glyph_decode_low_confidence_count : Int
  cmap_bfchar_seen : Bool
  cmap_bfrange_seen : Bool
  cmap_multibyte_seen : Bool
  surrogate_pair_seen : Bool
  pipeline_lowered_blocks : Int
  no_fallback_preserved : Bool
  source_to_lowering_stable : Bool
  reason_tags : Array[String]
}

///|
test "test_reset20_nfc_audit_samples_run_full_pipeline" {
  let rows = reset20_collect_audit()
  assert_eq(rows.length(), reset20_cases().length())
  let mut text_samples = 0
  for row in rows {
    assert_true(row.no_fallback_preserved)
    assert_true(row.source_to_lowering_stable)
    if row.decoded_chars > 0 {
      text_samples = text_samples + 1
      assert_true(row.pipeline_lowered_blocks > 0)
    }
  }
  assert_true(text_samples >= 5)
  reset20_write_tmp_summary(rows)
}

///|
test "test_reset20_nfc_normalized_tag_present_on_tounicode_samples" {
  let rows = reset20_collect_audit()
  let mut observed = 0
  for row in rows {
    if row.nfc_normalized_applied_seen {
      observed = observed + 1
      assert_true(row.decode_source_tounicode_seen)
      assert_true(row.tonyfettes_encoding_utf16be_seen)
    }
  }
  assert_true(observed >= 4)
}

///|
test "test_reset20_subset_type0_cid_metrics_present" {
  let rows = reset20_collect_audit()
  let mut subset_samples = 0
  let mut type0_samples = 0
  let mut cid_samples = 0
  for row in rows {
    if row.subset_font_seen {
      subset_samples = subset_samples + 1
    }
    if row.type0_font_seen {
      type0_samples = type0_samples + 1
    }
    if row.cid_font_seen {
      cid_samples = cid_samples + 1
    }
  }
  assert_true(subset_samples >= 4)
  assert_true(type0_samples >= 4)
  assert_true(cid_samples >= 4)
}

///|
test "test_reset20_no_fallback_or_convert_reparse" {
  let rows = reset20_collect_audit()
  for row in rows {
    assert_true(row.no_fallback_preserved)
    assert_true(row.source_to_lowering_stable)
    assert_eq(
      reset19_has_any_tag(row.reason_tags, [
        "legacy_fallback", "old_pdf_fallback", "convert_raw_reparse", "convert_pdf_reparse",
        "doc_parse_pdf_fallback",
      ]),
      false,
    )
  }
}

///|
test "test_reset20_archive_summary_is_compact_and_has_expected_fields" {
  let generated = reset20_summary_jsonl(reset20_collect_audit())
  let archive_path = reset19_resolve_path(
    "docs/archive/pdf-v2-reset20-encoding-audit-summary.jsonl",
  )
  let archived = @fs.read_file_to_string(archive_path, encoding="utf8") catch {
    e => fail("RESET-20 read archive summary failed: " + e.to_string())
  }
  assert_eq(archived, generated)
  assert_true(archived.length() < 10000)
  assert_true(archived.contains("\"nfc_normalized_applied_seen\""))
  assert_true(archived.contains("\"subset_font_seen\""))
  assert_true(archived.contains("\"type0_font_seen\""))
  assert_true(archived.contains("\"cid_font_seen\""))
  assert_true(archived.contains("\"reason_tags\""))
}

///|
fn reset20_collect_audit() -> Array[PdfV2Reset20AuditRow] raise {
  let rows : Array[PdfV2Reset20AuditRow] = []
  for c in reset20_cases() {
    let row = reset20_run_case(c)
    if c.expect_text {
      assert_true(row.decoded_chars > 0)
      assert_true(row.text_ops > 0)
    }
    rows.push(row)
  }
  rows
}

///|
fn reset20_cases() -> Array[PdfV2Reset19Case] {
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
      expect_tounicode: true,
    },
    {
      name: "sample_repeated_header_footer",
      path: "samples/main_process/pdf/pdf_repeated_header_footer.pdf",
      synthetic_encrypted_marker: false,
      expect_text: true,
      expect_tounicode: true,
    },
    {
      name: "pdfjs_annotation_hidden_print_xref_stream",
      path: "doc_parse/pdf/testdata/pdfjs/annotation_hidden_print.pdf",
      synthetic_encrypted_marker: false,
      expect_text: false,
      expect_tounicode: false,
    },
  ]
}

///|
fn reset20_run_case(c : PdfV2Reset19Case) -> PdfV2Reset20AuditRow raise {
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
  let low_ratio = if decoded_chars == 0 {
    0.0
  } else {
    low_confidence_chars.to_double() / decoded_chars.to_double()
  }
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
    sample_name: c.name,
    pdf_path: c.path,
    pages: core.page_count,
    content_streams: core.content_streams.length(),
    text_ops: core.text_events.length(),
    decoded_chars,
    low_confidence_chars,
    low_confidence_ratio: low_ratio,
    warnings,
    risks,
    type0_font_seen: reset19_has_tag(reason_tags, "font_type_type0"),
    cid_font_seen: reset19_has_tag(reason_tags, "font_type_cid"),
    subset_font_seen: reset19_has_tag(reason_tags, "font_subset_detected"),
    tounicode_seen: reset19_has_any_tag(reason_tags, [
      "tounicode_present", "cmap_used", "decode_source_tounicode",
    ]),
    decode_source_tounicode_seen: reset19_has_tag(
      reason_tags, "decode_source_tounicode",
    ),
    tonyfettes_encoding_utf16be_seen: reset19_has_tag(
      reason_tags, "tonyfettes_encoding_utf16be",
    ),
    nfc_normalized_applied_seen: reset19_has_tag(
      reason_tags, "nfc_normalized_applied",
    ),
    nfc_normalized_applied_count: reset19_tag_count(
      core_tags, "nfc_normalized_applied",
    ),
    bad_tounicode_handled_count: reset19_tag_count(
      reason_tags, "bad_tounicode_handled",
    ),
    tounicode_unmapped_code_count: reset19_tag_count(
      reason_tags, "tounicode_unmapped_code",
    ),
    glyph_decode_low_confidence_count: reset19_tag_count(
      reason_tags, "glyph_decode_low_confidence",
    ),
    cmap_bfchar_seen: reset19_has_tag(reason_tags, "tounicode_bfchar_applied"),
    cmap_bfrange_seen: reset19_has_tag(reason_tags, "tounicode_bfrange_applied"),
    cmap_multibyte_seen: reset19_has_any_tag(reason_tags, [
      "tounicode_codespace_multibyte", "tounicode_source_multibyte", "tounicode_source_2byte",
    ]),
    surrogate_pair_seen: reset19_has_tag(
      reason_tags, "tounicode_surrogate_pair",
    ),
    pipeline_lowered_blocks: lowered.blocks.length(),
    no_fallback_preserved: no_fallback,
    source_to_lowering_stable: no_fallback &&
    core.scanned_once &&
    source.summary.scanned_once &&
    text_model.summary.scanned_once &&
    model.source_summary.scanned_once &&
    layout.summary.one_pass_required &&
    features.summary.one_pass_required &&
    lowered.summary.one_pass_required,
    reason_tags: reset20_compact_reason_tags(reason_tags),
  }
}

///|
fn reset20_write_tmp_summary(rows : Array[PdfV2Reset20AuditRow]) -> Unit raise {
  let root = reset19_repo_root()
  let out_dir = reset19_join_path(root, ".tmp/pdf_v2_reset20")
  reset19_ensure_dir_tree(out_dir)
  let out_path = reset19_join_path(out_dir, "encoding_audit_summary.jsonl")
  @fs.write_string_to_file(
    out_path,
    reset20_summary_jsonl(rows),
    encoding="utf8",
  ) catch {
    e => fail("RESET-20 write encoding audit summary failed: " + e.to_string())
  }
}

///|
fn reset20_summary_jsonl(rows : Array[PdfV2Reset20AuditRow]) -> String {
  let lines : Array[String] = []
  for row in rows {
    lines.push(reset20_row_json(row))
  }
  lines.join("\n") + "\n"
}

///|
fn reset20_row_json(row : PdfV2Reset20AuditRow) -> String {
  reset19_compact_object_json([
    @cor.json_string("sample_name") + ": " + @cor.json_string(row.sample_name),
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
    @cor.json_string("warnings") + ": " + row.warnings.to_string(),
    @cor.json_string("risks") + ": " + row.risks.to_string(),
    @cor.json_string("type0_font_seen") +
    ": " +
    @cor.bool_json(row.type0_font_seen),
    @cor.json_string("cid_font_seen") + ": " + @cor.bool_json(row.cid_font_seen),
    @cor.json_string("subset_font_seen") +
    ": " +
    @cor.bool_json(row.subset_font_seen),
    @cor.json_string("tounicode_seen") +
    ": " +
    @cor.bool_json(row.tounicode_seen),
    @cor.json_string("decode_source_tounicode_seen") +
    ": " +
    @cor.bool_json(row.decode_source_tounicode_seen),
    @cor.json_string("tonyfettes_encoding_utf16be_seen") +
    ": " +
    @cor.bool_json(row.tonyfettes_encoding_utf16be_seen),
    @cor.json_string("nfc_normalized_applied_seen") +
    ": " +
    @cor.bool_json(row.nfc_normalized_applied_seen),
    @cor.json_string("nfc_normalized_applied_count") +
    ": " +
    row.nfc_normalized_applied_count.to_string(),
    @cor.json_string("bad_tounicode_handled_count") +
    ": " +
    row.bad_tounicode_handled_count.to_string(),
    @cor.json_string("tounicode_unmapped_code_count") +
    ": " +
    row.tounicode_unmapped_code_count.to_string(),
    @cor.json_string("glyph_decode_low_confidence_count") +
    ": " +
    row.glyph_decode_low_confidence_count.to_string(),
    @cor.json_string("cmap_bfchar_seen") +
    ": " +
    @cor.bool_json(row.cmap_bfchar_seen),
    @cor.json_string("cmap_bfrange_seen") +
    ": " +
    @cor.bool_json(row.cmap_bfrange_seen),
    @cor.json_string("cmap_multibyte_seen") +
    ": " +
    @cor.bool_json(row.cmap_multibyte_seen),
    @cor.json_string("surrogate_pair_seen") +
    ": " +
    @cor.bool_json(row.surrogate_pair_seen),
    @cor.json_string("pipeline_lowered_blocks") +
    ": " +
    row.pipeline_lowered_blocks.to_string(),
    @cor.json_string("no_fallback_preserved") +
    ": " +
    @cor.bool_json(row.no_fallback_preserved),
    @cor.json_string("source_to_lowering_stable") +
    ": " +
    @cor.bool_json(row.source_to_lowering_stable),
    @cor.json_string("reason_tags") +
    ": " +
    reset19_compact_string_array_json(row.reason_tags),
  ])
}

///|
fn reset20_compact_reason_tags(tags : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for tag in tags {
    if reset20_compact_reason_tag_allowed(tag) && !out.contains(tag) {
      out.push(tag)
    }
  }
  out
}

///|
fn reset20_compact_reason_tag_allowed(tag : String) -> Bool {
  reset19_has_any_tag([tag], [
    "decode_source_tounicode", "tonyfettes_encoding_utf16be", "nfc_normalized_applied",
    "tounicode_bfchar_applied", "tounicode_bfrange_applied", "bad_tounicode_handled",
    "tounicode_unmapped_code", "glyph_decode_low_confidence", "text_retained", "tounicode_identity_name_detected",
    "identity_edge_case", "identity_tounicode_mbtpdf_extractor", "font_type_type0",
    "font_type_cid", "font_subset_detected", "cid_system_info_present", "tounicode_codespace_multibyte",
    "tounicode_source_multibyte", "tounicode_source_2byte", "tounicode_surrogate_pair",
    "filter_flate_decode_used", "object_stream_detected", "xref_table_used", "no_fallback",
    "no_raw_pdf_read", "no_old_pdf_runtime", "no_old_parser_runtime", "fail_closed",
  ])
}
