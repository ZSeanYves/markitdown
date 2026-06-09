///|
struct PdfV2Reset19Case {
  name : String
  path : String
  synthetic_encrypted_marker : Bool
  expect_text : Bool
  expect_tounicode : Bool
}

///|
struct PdfV2Reset19AuditRow {
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
  type0_font_count : Int
  cid_font_seen : Bool
  cid_font_count : Int
  subset_font_seen : Bool
  cid_system_info_seen : Bool
  tounicode_seen : Bool
  decode_source_tounicode_seen : Bool
  tonyfettes_encoding_utf16be_seen : Bool
  nfc_normalized_seen : Bool
  nfc_normalized_observation : String
  bad_tounicode_handled_count : Int
  tounicode_unmapped_code_count : Int
  glyph_decode_low_confidence_count : Int
  font_subset_detected_count : Int
  cmap_bfchar_seen : Bool
  cmap_bfchar_count : Int
  cmap_bfrange_seen : Bool
  cmap_bfrange_count : Int
  cmap_multibyte_seen : Bool
  cmap_multibyte_count : Int
  surrogate_pair_seen : Bool
  surrogate_pair_count : Int
  encrypted_fail_closed : Bool
  pipeline_lowered_blocks : Int
  no_fallback_preserved : Bool
  source_to_lowering_stable : Bool
  top_reason_tags : Array[String]
}

///|
test "test_reset19_encoding_audit_samples_run_full_pipeline" {
  let rows = reset19_collect_audit()
  assert_eq(rows.length(), reset19_cases().length())
  let mut text_samples = 0
  let mut lowered_samples = 0
  let mut encrypted_samples = 0
  for row in rows {
    assert_true(row.no_fallback_preserved)
    assert_true(row.source_to_lowering_stable)
    if row.decoded_chars > 0 {
      text_samples = text_samples + 1
    }
    if row.pipeline_lowered_blocks > 0 {
      lowered_samples = lowered_samples + 1
    }
    if row.encrypted_fail_closed {
      encrypted_samples = encrypted_samples + 1
    }
  }
  assert_true(text_samples >= 5)
  assert_true(lowered_samples >= 5)
  assert_eq(encrypted_samples, 1)
  reset19_write_tmp_summary(rows)
}

///|
test "test_reset19_tounicode_reason_tags_present_on_relevant_samples" {
  let rows = reset19_collect_audit()
  let mut relevant = 0
  for row in rows {
    if reset19_relevant_tounicode_sample(row.sample_name) {
      relevant = relevant + 1
      assert_true(row.tounicode_seen)
      assert_true(row.decode_source_tounicode_seen)
      assert_true(row.tonyfettes_encoding_utf16be_seen)
    }
  }
  assert_eq(relevant, 3)
}

///|
test "test_reset19_no_low_confidence_regression_for_text_samples" {
  let rows = reset19_collect_audit()
  let mut checked = 0
  let mut low_confidence_samples = 0
  for row in rows {
    if row.decoded_chars > 0 {
      checked = checked + 1
      assert_true(row.low_confidence_chars <= row.decoded_chars)
      if row.low_confidence_chars > 0 {
        low_confidence_samples = low_confidence_samples + 1
        assert_eq(row.sample_name, "mbtpdf_pdfjs_identity_tounicode")
        assert_true(row.bad_tounicode_handled_count > 0)
        assert_true(row.tounicode_unmapped_code_count > 0)
        assert_true(row.glyph_decode_low_confidence_count > 0)
      }
    }
  }
  assert_true(checked >= 5)
  assert_true(low_confidence_samples <= 1)
}

///|
test "test_reset19_no_fallback_or_convert_reparse" {
  let rows = reset19_collect_audit()
  for row in rows {
    assert_true(row.no_fallback_preserved)
    assert_true(row.source_to_lowering_stable)
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
test "test_reset19_archive_summary_is_compact_and_has_expected_fields" {
  let generated = reset19_summary_jsonl(reset19_collect_audit())
  let archive_path = reset19_resolve_path(
    "docs/archive/pdf-v2-reset19-encoding-audit-summary.jsonl",
  )
  let archived = @fs.read_file_to_string(archive_path, encoding="utf8") catch {
    e => fail("RESET-19 read archive summary failed: " + e.to_string())
  }
  assert_eq(archived, generated)
  assert_true(archived.length() < 12000)
  assert_true(archived.contains("\"sample_name\""))
  assert_true(archived.contains("\"tonyfettes_encoding_utf16be_seen\""))
  assert_true(archived.contains("\"decode_source_tounicode_seen\""))
  assert_true(archived.contains("\"low_confidence_ratio\""))
  assert_true(archived.contains("\"pipeline_lowered_blocks\""))
}

///|
fn reset19_collect_audit() -> Array[PdfV2Reset19AuditRow] raise {
  let rows : Array[PdfV2Reset19AuditRow] = []
  for c in reset19_cases() {
    let row = reset19_run_case(c)
    if c.expect_text {
      assert_true(row.decoded_chars > 0)
      assert_true(row.text_ops > 0)
      assert_true(row.pipeline_lowered_blocks > 0)
    }
    if c.expect_tounicode {
      assert_true(row.tounicode_seen)
      assert_true(row.decode_source_tounicode_seen)
    }
    rows.push(row)
  }
  rows
}

///|
fn reset19_cases() -> Array[PdfV2Reset19Case] {
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
fn reset19_run_case(c : PdfV2Reset19Case) -> PdfV2Reset19AuditRow raise {
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
  let warning_tags = reset19_warning_tags(core.warnings)
  let risk_tags = reset19_risk_tags(core.risks)
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
    type0_font_count: reset19_tag_count(reason_tags, "font_type_type0"),
    cid_font_seen: reset19_has_tag(reason_tags, "font_type_cid"),
    cid_font_count: reset19_tag_count(reason_tags, "font_type_cid"),
    subset_font_seen: reset19_has_tag(reason_tags, "font_subset_detected"),
    cid_system_info_seen: reset19_has_tag(
      reason_tags, "cid_system_info_present",
    ),
    tounicode_seen: reset19_has_any_tag(reason_tags, [
      "tounicode_present", "cmap_used", "decode_source_tounicode",
    ]),
    decode_source_tounicode_seen: reset19_has_tag(
      reason_tags, "decode_source_tounicode",
    ),
    tonyfettes_encoding_utf16be_seen: reset19_has_tag(
      reason_tags, "tonyfettes_encoding_utf16be",
    ),
    nfc_normalized_seen: reset19_has_any_tag(reason_tags, [
      "nfc_normalized", "unicode_nfc_normalized", "tonyfettes_unicode_normalization_nfc",
    ]),
    nfc_normalized_observation: if reset19_has_any_tag(reason_tags, [
        "nfc_normalized", "unicode_nfc_normalized", "tonyfettes_unicode_normalization_nfc",
      ]) {
      "observed"
    } else {
      "not_observed_no_explicit_reason_tag"
    },
    bad_tounicode_handled_count: reset19_tag_count(
      reason_tags, "bad_tounicode_handled",
    ),
    tounicode_unmapped_code_count: reset19_tag_count(
      reason_tags, "tounicode_unmapped_code",
    ),
    glyph_decode_low_confidence_count: reset19_tag_count(
      reason_tags, "glyph_decode_low_confidence",
    ),
    font_subset_detected_count: reset19_tag_count(
      reason_tags, "font_subset_detected",
    ),
    cmap_bfchar_seen: reset19_has_tag(reason_tags, "tounicode_bfchar_applied"),
    cmap_bfchar_count: reset19_tag_count(
      reason_tags, "tounicode_bfchar_applied",
    ),
    cmap_bfrange_seen: reset19_has_tag(reason_tags, "tounicode_bfrange_applied"),
    cmap_bfrange_count: reset19_tag_count(
      reason_tags, "tounicode_bfrange_applied",
    ),
    cmap_multibyte_seen: reset19_has_any_tag(reason_tags, [
      "tounicode_codespace_multibyte", "tounicode_source_multibyte", "tounicode_source_2byte",
    ]),
    cmap_multibyte_count: reset19_tag_count(
      reason_tags, "tounicode_codespace_multibyte",
    ) +
    reset19_tag_count(reason_tags, "tounicode_source_multibyte") +
    reset19_tag_count(reason_tags, "tounicode_source_2byte"),
    surrogate_pair_seen: reset19_has_tag(
      reason_tags, "tounicode_surrogate_pair",
    ),
    surrogate_pair_count: reset19_tag_count(
      reason_tags, "tounicode_surrogate_pair",
    ),
    encrypted_fail_closed: reset19_has_any_tag(warning_tags, [
      "encrypted_pdf_detected", "encrypted_pdf_unsupported",
    ]) &&
    reset19_has_any_tag(risk_tags, [
      "encrypted_pdf_detected", "encrypted_pdf_unsupported",
    ]),
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
    top_reason_tags: reason_tags,
  }
}

///|
fn reset19_case_bytes(c : PdfV2Reset19Case) -> Bytes raise {
  if c.synthetic_encrypted_marker {
    return pdf_v2_encrypted_marker_pdf_bytes()
  }
  let path = reset19_resolve_path(c.path)
  @fs.read_file_to_bytes(path) catch {
    e => fail("RESET-19 read PDF failed for " + c.path + ": " + e.to_string())
  }
}

///|
fn reset19_no_fallback_preserved(
  core : @pdfv2.PdfV2CoreDocument,
  source : @source_event.PdfV2SourceDocument,
  text_model : @text_reconstruction.PdfV2TextModel,
  model : @normalized_model.PdfV2DocumentModel,
  layout : @layout_recovery.PdfV2LayoutRecoveryResult,
  features : @feature_export.PdfV2FeatureExportResult,
  lowered : @lowering.PdfV2LoweringResult,
) -> Bool {
  core.fallback_policy.legacy_fallback_allowed == false &&
  core.scan_boundary.convert_raw_reparse_allowed == false &&
  source.summary.legacy_fallback_allowed == false &&
  source.summary.convert_raw_reparse_allowed == false &&
  text_model.summary.legacy_fallback_allowed == false &&
  text_model.summary.convert_raw_reparse_allowed == false &&
  model.source_summary.legacy_fallback_allowed == false &&
  model.source_summary.convert_raw_reparse_allowed == false &&
  layout.summary.legacy_fallback_allowed == false &&
  layout.summary.convert_raw_reparse_allowed == false &&
  features.summary.legacy_fallback_allowed == false &&
  features.summary.convert_raw_reparse_allowed == false &&
  lowered.summary.legacy_fallback_allowed == false &&
  lowered.summary.convert_raw_reparse_allowed == false
}

///|
fn reset19_decoded_char_count(events : Array[@pdfv2.PdfV2CoreTextEvent]) -> Int {
  let mut total = 0
  for event in events {
    total = total + event.text.length()
  }
  total
}

///|
fn reset19_low_confidence_char_count(
  events : Array[@pdfv2.PdfV2CoreTextEvent],
) -> Int {
  let mut total = 0
  for event in events {
    if event.decode_confidence < 0.90 ||
      reset19_has_any_tag(event.reason_tags, [
        "glyph_decode_best_effort", "glyph_decode_low_confidence", "tounicode_unmapped_code",
        "tounicode_missing", "cmap_missing", "tounicode_malformed",
      ]) {
      total = total + event.text.length()
    }
  }
  total
}

///|
fn reset19_core_reason_tags(core : @pdfv2.PdfV2CoreDocument) -> Array[String] {
  let tags : Array[String] = []
  for event in core.text_events {
    reset19_push_all(tags, event.reason_tags)
    reset19_push_all(tags, reset19_warning_tags(event.warnings))
    reset19_push_all(tags, reset19_risk_tags(event.risks))
  }
  reset19_push_all(tags, reset19_warning_tags(core.warnings))
  reset19_push_all(tags, reset19_risk_tags(core.risks))
  tags
}

///|
fn reset19_warning_tags(warnings : Array[@pdfv2.PdfV2Warning]) -> Array[String] {
  let tags : Array[String] = []
  for warning in warnings {
    reset19_push_all(tags, warning.reason_tags)
  }
  tags
}

///|
fn reset19_risk_tags(risks : Array[@pdfv2.PdfV2Risk]) -> Array[String] {
  let tags : Array[String] = []
  for risk in risks {
    reset19_push_all(tags, risk.reason_tags)
  }
  tags
}

///|
fn reset19_has_tag(tags : Array[String], tag : String) -> Bool {
  tags.contains(tag)
}

///|
fn reset19_has_any_tag(tags : Array[String], needles : Array[String]) -> Bool {
  for needle in needles {
    if tags.contains(needle) {
      return true
    }
  }
  false
}

///|
fn reset19_tag_count(tags : Array[String], tag : String) -> Int {
  let mut count = 0
  for value in tags {
    if value == tag {
      count = count + 1
    }
  }
  count
}

///|
fn reset19_push_all(out : Array[String], values : Array[String]) -> Unit {
  for value in values {
    out.push(value)
  }
}

///|
fn reset19_unique_strings(values : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    if !out.contains(value) {
      out.push(value)
    }
  }
  out
}

///|
fn reset19_relevant_tounicode_sample(name : String) -> Bool {
  name == "mbtpdf_pdfjs_identity_tounicode" ||
  name == "mbtpdf_pdfjs_arial_unicode_ab_cidfont" ||
  name == "mbtpdf_pandoc_unicode"
}

///|
fn reset19_write_tmp_summary(rows : Array[PdfV2Reset19AuditRow]) -> Unit raise {
  let root = reset19_repo_root()
  let out_dir = reset19_join_path(root, ".tmp/pdf_v2_reset19")
  reset19_ensure_dir_tree(out_dir)
  let out_path = reset19_join_path(out_dir, "encoding_audit_summary.jsonl")
  @fs.write_string_to_file(
    out_path,
    reset19_summary_jsonl(rows),
    encoding="utf8",
  ) catch {
    e => fail("RESET-19 write encoding audit summary failed: " + e.to_string())
  }
}

///|
fn reset19_summary_jsonl(rows : Array[PdfV2Reset19AuditRow]) -> String {
  let lines : Array[String] = []
  for row in rows {
    lines.push(reset19_row_json(row))
  }
  lines.join("\n") + "\n"
}

///|
fn reset19_row_json(row : PdfV2Reset19AuditRow) -> String {
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
    @cor.json_string("type0_font_count") +
    ": " +
    row.type0_font_count.to_string(),
    @cor.json_string("cid_font_seen") + ": " + @cor.bool_json(row.cid_font_seen),
    @cor.json_string("cid_font_count") + ": " + row.cid_font_count.to_string(),
    @cor.json_string("subset_font_seen") +
    ": " +
    @cor.bool_json(row.subset_font_seen),
    @cor.json_string("cid_system_info_seen") +
    ": " +
    @cor.bool_json(row.cid_system_info_seen),
    @cor.json_string("tounicode_seen") +
    ": " +
    @cor.bool_json(row.tounicode_seen),
    @cor.json_string("decode_source_tounicode_seen") +
    ": " +
    @cor.bool_json(row.decode_source_tounicode_seen),
    @cor.json_string("tonyfettes_encoding_utf16be_seen") +
    ": " +
    @cor.bool_json(row.tonyfettes_encoding_utf16be_seen),
    @cor.json_string("nfc_normalized_seen") +
    ": " +
    @cor.bool_json(row.nfc_normalized_seen),
    @cor.json_string("nfc_normalized_observation") +
    ": " +
    @cor.json_string(row.nfc_normalized_observation),
    @cor.json_string("bad_tounicode_handled_count") +
    ": " +
    row.bad_tounicode_handled_count.to_string(),
    @cor.json_string("tounicode_unmapped_code_count") +
    ": " +
    row.tounicode_unmapped_code_count.to_string(),
    @cor.json_string("glyph_decode_low_confidence_count") +
    ": " +
    row.glyph_decode_low_confidence_count.to_string(),
    @cor.json_string("font_subset_detected_count") +
    ": " +
    row.font_subset_detected_count.to_string(),
    @cor.json_string("cmap_bfchar_seen") +
    ": " +
    @cor.bool_json(row.cmap_bfchar_seen),
    @cor.json_string("cmap_bfchar_count") +
    ": " +
    row.cmap_bfchar_count.to_string(),
    @cor.json_string("cmap_bfrange_seen") +
    ": " +
    @cor.bool_json(row.cmap_bfrange_seen),
    @cor.json_string("cmap_bfrange_count") +
    ": " +
    row.cmap_bfrange_count.to_string(),
    @cor.json_string("cmap_multibyte_seen") +
    ": " +
    @cor.bool_json(row.cmap_multibyte_seen),
    @cor.json_string("cmap_multibyte_count") +
    ": " +
    row.cmap_multibyte_count.to_string(),
    @cor.json_string("surrogate_pair_seen") +
    ": " +
    @cor.bool_json(row.surrogate_pair_seen),
    @cor.json_string("surrogate_pair_count") +
    ": " +
    row.surrogate_pair_count.to_string(),
    @cor.json_string("encrypted_fail_closed") +
    ": " +
    @cor.bool_json(row.encrypted_fail_closed),
    @cor.json_string("pipeline_lowered_blocks") +
    ": " +
    row.pipeline_lowered_blocks.to_string(),
    @cor.json_string("no_fallback_preserved") +
    ": " +
    @cor.bool_json(row.no_fallback_preserved),
    @cor.json_string("source_to_lowering_stable") +
    ": " +
    @cor.bool_json(row.source_to_lowering_stable),
    @cor.json_string("top_reason_tags") +
    ": " +
    reset19_compact_string_array_json(
      reset19_compact_reason_tags(row.top_reason_tags),
    ),
  ])
}

///|
fn reset19_compact_object_json(fields : Array[String]) -> String {
  "{" + fields.join(",") + "}"
}

///|
fn reset19_compact_string_array_json(values : Array[String]) -> String {
  let items : Array[String] = []
  for value in values {
    items.push(@cor.json_string(value))
  }
  "[" + items.join(",") + "]"
}

///|
fn reset19_compact_reason_tags(tags : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for tag in tags {
    if reset19_compact_reason_tag_allowed(tag) && !out.contains(tag) {
      out.push(tag)
    }
  }
  out
}

///|
fn reset19_compact_reason_tag_allowed(tag : String) -> Bool {
  reset19_has_any_tag([tag], [
    "decode_source_tounicode", "tonyfettes_encoding_utf16be", "tonyfettes_unicode_helper",
    "bad_tounicode_handled", "tounicode_unmapped_code", "glyph_decode_low_confidence",
    "text_retained", "font_type_type0", "font_type_cid", "font_subset_detected",
    "cid_system_info_present", "tounicode_bfchar_applied", "tounicode_bfrange_applied",
    "tounicode_codespace_multibyte", "tounicode_source_multibyte", "tounicode_source_2byte",
    "tounicode_surrogate_pair", "filter_flate_decode_used", "object_stream_detected",
    "xref_table_used", "encrypted_pdf_detected", "encrypted_pdf_unsupported", "no_fallback",
    "no_raw_pdf_read", "no_old_pdf_runtime", "no_old_parser_runtime", "fail_closed",
  ])
}

///|
fn reset19_resolve_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }
  let root = reset19_repo_root()
  let rooted = reset19_join_path(root, path)
  if @fs.path_exists(rooted) {
    return rooted
  }
  fail("RESET-19 file not found: " + path)
}

///|
fn reset19_repo_root() -> String {
  match @sys.get_env_var("PWD") {
    Some(cwd) =>
      match reset19_find_repo_root_from(cwd) {
        Some(root) => root
        None => cwd
      }
    None => "."
  }
}

///|
fn reset19_find_repo_root_from(dir : String) -> String? {
  if @fs.path_exists(reset19_join_path(dir, "moon.mod")) {
    return Some(dir)
  }
  let parent = reset19_parent_dir(dir)
  if parent == "" || parent == dir {
    None
  } else {
    reset19_find_repo_root_from(parent)
  }
}

///|
fn reset19_parent_dir(path : String) -> String {
  match path.rev_find("/") {
    None => ""
    Some(idx) => if idx == 0 { "/" } else { path[:idx].to_owned() }
  }
}

///|
fn reset19_join_path(base : String, rel : String) -> String {
  if base == "" || base == "." {
    rel
  } else if base == "/" {
    "/" + rel
  } else if base.has_suffix("/") {
    base + rel
  } else {
    base + "/" + rel
  }
}

///|
fn reset19_ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path) catch {
      e => fail("RESET-19 create dir failed: " + e.to_string())
    }
  }
}

///|
fn reset19_ensure_dir_tree(path : String) -> Unit raise {
  let trimmed = path.trim()
  if trimmed == "" {
    return
  }
  let chars = trimmed.to_array()
  let mut current = if chars.length() > 0 && chars[0] == '/' { "/" } else { "" }
  let part : Array[Char] = []

  fn flush(part : Array[Char], current : String) -> String raise {
    if part.length() == 0 {
      return current
    }
    let segment = String::from_array(part)
    part.clear()
    let next = reset19_join_path(current, segment)
    reset19_ensure_dir(next)
    next
  }

  for ch in chars {
    if ch == '/' {
      current = flush(part, current)
    } else {
      part.push(ch)
    }
  }
  ignore(flush(part, current))
}
