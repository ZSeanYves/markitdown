///|
struct PdfV2Reset14Case {
  name : String
  path : String
  synthetic_encrypted_marker : Bool
  expect_text : Bool
}

///|
struct PdfV2Reset14Coverage {
  pdf_name : String
  pdf_path : String
  pages : Int
  content_streams : Int
  source_events : Int
  text_ops : Int
  glyphs : Int
  decoded_chars : Int
  high_confidence_text_events : Int
  medium_confidence_text_events : Int
  low_confidence_text_events : Int
  failed_decode_text_events : Int
  low_confidence_text_ratio : Double
  unmapped_char_estimate : Int
  warnings : Int
  risks : Int
  core_warnings : Int
  core_risks : Int
  feature_records : Int
  decisions : Int
  lowered_blocks : Int
  type0_or_cid_font_present : Bool
  tounicode_or_cmap_covered : Bool
  flate_decode_handled : Bool
  missing_font_diagnostic : Bool
  missing_tounicode_diagnostic : Bool
  malformed_stream_diagnostic : Bool
  object_or_xref_issue_diagnostic : Bool
  encrypted_fail_closed : Bool
  no_fallback_preserved : Bool
  source_to_lowering_stable : Bool
  reason_tags : Array[String]
  warning_tags : Array[String]
  risk_tags : Array[String]
}

///|
test "test_reset14_real_pdf_coverage_summary" {
  let rows = reset14_collect_coverage()
  assert_true(rows.length() >= 6)
  let mut text_case_count = 0
  let mut type0_or_cid_case_count = 0
  let mut tounicode_case_count = 0
  let mut flate_case_count = 0
  let mut object_or_xref_case_count = 0
  let mut encrypted_case_count = 0
  for row in rows {
    assert_true(row.no_fallback_preserved)
    assert_true(row.source_to_lowering_stable)
    if row.decoded_chars > 0 {
      text_case_count = text_case_count + 1
    }
    if row.type0_or_cid_font_present {
      type0_or_cid_case_count = type0_or_cid_case_count + 1
    }
    if row.tounicode_or_cmap_covered {
      tounicode_case_count = tounicode_case_count + 1
    }
    if row.flate_decode_handled {
      flate_case_count = flate_case_count + 1
    }
    if row.object_or_xref_issue_diagnostic {
      object_or_xref_case_count = object_or_xref_case_count + 1
    }
    if row.encrypted_fail_closed {
      encrypted_case_count = encrypted_case_count + 1
    }
  }
  assert_true(text_case_count >= 3)
  assert_true(type0_or_cid_case_count >= 1)
  assert_true(tounicode_case_count >= 1)
  assert_true(flate_case_count >= 1)
  assert_true(object_or_xref_case_count >= 1)
  assert_true(encrypted_case_count == 1)
  reset14_write_tmp_report(rows)
}

///|
fn reset14_collect_coverage() -> Array[PdfV2Reset14Coverage] raise {
  let rows : Array[PdfV2Reset14Coverage] = []
  for c in reset14_cases() {
    let row = reset14_run_case(c)
    if c.expect_text {
      assert_true(row.decoded_chars > 0)
      assert_true(row.text_ops > 0)
    }
    rows.push(row)
  }
  rows
}

///|
fn reset14_cases() -> Array[PdfV2Reset14Case] {
  [
    {
      name: "mbtpdf_pdfjs_identity_tounicode",
      path: "doc_parse/pdf/vendor/mbtpdf/testdata/pdfjs_identity_tounicode.pdf",
      synthetic_encrypted_marker: false,
      expect_text: true,
    },
    {
      name: "mbtpdf_pdfjs_arial_unicode_ab_cidfont",
      path: "doc_parse/pdf/vendor/mbtpdf/testdata/pdfjs_arial_unicode_ab_cidfont.pdf",
      synthetic_encrypted_marker: false,
      expect_text: true,
    },
    {
      name: "mbtpdf_pandoc_unicode",
      path: "doc_parse/pdf/vendor/mbtpdf/testdata/pandoc/pandoc_unicode.pdf",
      synthetic_encrypted_marker: false,
      expect_text: true,
    },
    {
      name: "sample_text_simple",
      path: "samples/main_process/pdf/text_simple.pdf",
      synthetic_encrypted_marker: false,
      expect_text: true,
    },
    {
      name: "sample_repeated_header_footer",
      path: "samples/main_process/pdf/pdf_repeated_header_footer.pdf",
      synthetic_encrypted_marker: false,
      expect_text: true,
    },
    {
      name: "pdfjs_annotation_hidden_print_xref_stream",
      path: "doc_parse/pdf/testdata/pdfjs/annotation_hidden_print.pdf",
      synthetic_encrypted_marker: false,
      expect_text: false,
    },
    {
      name: "synthetic_encrypted_marker",
      path: "<synthetic:encrypted_marker>",
      synthetic_encrypted_marker: true,
      expect_text: false,
    },
  ]
}

///|
fn reset14_run_case(c : PdfV2Reset14Case) -> PdfV2Reset14Coverage raise {
  let bytes = reset14_case_bytes(c)
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
  let reason_tags = reset14_core_reason_tags(core) + lowered.reason_tags
  let warning_tags = reset14_warning_tags(core.warnings)
  let risk_tags = reset14_risk_tags(core.risks)
  let text_counts = reset14_text_confidence_counts(core.text_events)
  let decoded_chars = reset14_decoded_char_count(core.text_events)
  let low_ratio = if core.text_events.length() == 0 {
    0.0
  } else {
    (text_counts.2 + text_counts.3).to_double() /
    core.text_events.length().to_double()
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
  let no_fallback = reset14_no_fallback_preserved(
    core, source, text_model, model, layout, features, lowered,
  )
  {
    pdf_name: c.name,
    pdf_path: c.path,
    pages: core.page_count,
    content_streams: core.content_streams.length(),
    source_events: source.summary.event_count,
    text_ops: core.text_events.length(),
    glyphs: text_model.summary.glyph_count,
    decoded_chars,
    high_confidence_text_events: text_counts.0,
    medium_confidence_text_events: text_counts.1,
    low_confidence_text_events: text_counts.2,
    failed_decode_text_events: text_counts.3,
    low_confidence_text_ratio: low_ratio,
    unmapped_char_estimate: reset14_unmapped_char_estimate(core.text_events),
    warnings,
    risks,
    core_warnings: core.warnings.length(),
    core_risks: core.risks.length(),
    feature_records: features.records.length(),
    decisions: decisions.length(),
    lowered_blocks: lowered.blocks.length(),
    type0_or_cid_font_present: reset14_has_any_tag(reason_tags, [
      "font_type_type0", "font_type_cid",
    ]),
    tounicode_or_cmap_covered: reset14_has_any_tag(reason_tags, [
      "tounicode_present", "cmap_used", "decode_source_tounicode",
    ]),
    flate_decode_handled: reset14_flate_decode_handled(core),
    missing_font_diagnostic: reset14_has_tag(
      reason_tags, "missing_font_resource",
    ) ||
    reset14_has_tag(warning_tags, "missing_font_resource"),
    missing_tounicode_diagnostic: reset14_has_any_tag(reason_tags, [
      "tounicode_missing", "cmap_missing", "missing_tounicode",
    ]) ||
    reset14_has_any_tag(warning_tags, [
      "tounicode_missing", "cmap_missing", "missing_tounicode",
    ]),
    malformed_stream_diagnostic: reset14_has_any_tag(warning_tags, [
      "stream_decode_failed", "mbtpdf_stream_decode_failed",
    ]) ||
    reset14_has_any_tag(risk_tags, [
      "stream_decode_failed", "mbtpdf_stream_decode_failed",
    ]),
    object_or_xref_issue_diagnostic: reset14_has_any_tag(warning_tags, [
      "xref_stream_detected", "xref_stream_supported", "object_stream_detected",
      "object_stream_supported", "xref_table_used",
    ]),
    encrypted_fail_closed: reset14_has_any_tag(warning_tags, [
      "encrypted_pdf_detected", "encrypted_pdf_unsupported",
    ]) &&
    reset14_has_any_tag(risk_tags, [
      "encrypted_pdf_detected", "encrypted_pdf_unsupported",
    ]),
    no_fallback_preserved: no_fallback,
    source_to_lowering_stable: no_fallback &&
    core.scanned_once &&
    source.summary.scanned_once &&
    text_model.summary.scanned_once &&
    model.source_summary.scanned_once &&
    layout.summary.one_pass_required &&
    features.summary.one_pass_required &&
    lowered.summary.one_pass_required,
    reason_tags: reset14_unique_strings(reason_tags),
    warning_tags,
    risk_tags,
  }
}

///|
fn reset14_case_bytes(c : PdfV2Reset14Case) -> Bytes raise {
  if c.synthetic_encrypted_marker {
    return pdf_v2_encrypted_marker_pdf_bytes()
  }
  let path = reset14_resolve_path(c.path)
  @fs.read_file_to_bytes(path) catch {
    e => fail("RESET-14 read PDF failed for " + c.path + ": " + e.to_string())
  }
}

///|
fn reset14_no_fallback_preserved(
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
fn reset14_text_confidence_counts(
  events : Array[@pdfv2.PdfV2CoreTextEvent],
) -> (Int, Int, Int, Int) {
  let mut high = 0
  let mut medium = 0
  let mut low = 0
  let mut failed = 0
  for event in events {
    if event.decode_confidence >= 0.90 {
      high = high + 1
    } else if event.decode_confidence >= 0.60 {
      medium = medium + 1
    } else if event.decode_confidence > 0.0 {
      low = low + 1
    } else {
      failed = failed + 1
    }
  }
  (high, medium, low, failed)
}

///|
fn reset14_decoded_char_count(events : Array[@pdfv2.PdfV2CoreTextEvent]) -> Int {
  let mut total = 0
  for event in events {
    total = total + event.text.length()
  }
  total
}

///|
fn reset14_unmapped_char_estimate(
  events : Array[@pdfv2.PdfV2CoreTextEvent],
) -> Int {
  let mut total = 0
  for event in events {
    if event.decode_confidence < 0.90 ||
      reset14_has_any_tag(event.reason_tags, [
        "glyph_decode_best_effort", "glyph_decode_low_confidence", "tounicode_missing",
        "cmap_missing", "tounicode_malformed",
      ]) {
      total = total + event.text.length()
    }
  }
  total
}

///|
fn reset14_flate_decode_handled(core : @pdfv2.PdfV2CoreDocument) -> Bool {
  for stream in core.content_streams {
    if stream.decode_supported &&
      reset14_has_tag(stream.filter_names, "/FlateDecode") {
      return true
    }
  }
  reset14_has_any_tag(reset14_warning_tags(core.warnings), [
    "filter_flate_decode_used", "decoded_stream_count",
  ])
}

///|
fn reset14_core_reason_tags(core : @pdfv2.PdfV2CoreDocument) -> Array[String] {
  let tags : Array[String] = []
  for event in core.text_events {
    reset14_push_all_unique(tags, event.reason_tags)
  }
  reset14_push_all_unique(tags, reset14_warning_tags(core.warnings))
  reset14_push_all_unique(tags, reset14_risk_tags(core.risks))
  tags
}

///|
fn reset14_warning_tags(warnings : Array[@pdfv2.PdfV2Warning]) -> Array[String] {
  let tags : Array[String] = []
  for warning in warnings {
    reset14_push_all_unique(tags, warning.reason_tags)
  }
  tags
}

///|
fn reset14_risk_tags(risks : Array[@pdfv2.PdfV2Risk]) -> Array[String] {
  let tags : Array[String] = []
  for risk in risks {
    reset14_push_all_unique(tags, risk.reason_tags)
  }
  tags
}

///|
fn reset14_has_tag(tags : Array[String], tag : String) -> Bool {
  tags.contains(tag)
}

///|
fn reset14_has_any_tag(tags : Array[String], needles : Array[String]) -> Bool {
  for needle in needles {
    if tags.contains(needle) {
      return true
    }
  }
  false
}

///|
fn reset14_push_all_unique(out : Array[String], values : Array[String]) -> Unit {
  for value in values {
    if !out.contains(value) {
      out.push(value)
    }
  }
}

///|
fn reset14_unique_strings(values : Array[String]) -> Array[String] {
  let out : Array[String] = []
  reset14_push_all_unique(out, values)
  out
}

///|
fn reset14_write_tmp_report(rows : Array[PdfV2Reset14Coverage]) -> Unit raise {
  let root = reset14_repo_root()
  let out_dir = reset14_join_path(root, ".tmp/pdf_v2_reset14")
  reset14_ensure_dir_tree(out_dir)
  let out_path = reset14_join_path(out_dir, "coverage_summary.json")
  @fs.write_string_to_file(out_path, reset14_report_json(rows), encoding="utf8") catch {
    e => fail("RESET-14 write coverage summary failed: " + e.to_string())
  }
}

///|
fn reset14_report_json(rows : Array[PdfV2Reset14Coverage]) -> String {
  let items : Array[String] = []
  for row in rows {
    items.push(reset14_row_json(row))
  }
  @cor.object_json([
    @cor.json_string("reset") + ": " + @cor.json_string("PDF-V2-RESET-14"),
    @cor.json_string("scope") +
    ": " +
    @cor.json_string(
      "mbtpdf-backed perf reader diagnostics/coverage on small real PDFs",
    ),
    @cor.json_string("pdf_count") + ": " + rows.length().to_string(),
    @cor.json_string("total_pages") +
    ": " +
    reset14_total_pages(rows).to_string(),
    @cor.json_string("total_text_ops") +
    ": " +
    reset14_total_text_ops(rows).to_string(),
    @cor.json_string("total_decoded_chars") +
    ": " +
    reset14_total_decoded_chars(rows).to_string(),
    @cor.json_string("total_warnings") +
    ": " +
    reset14_total_warnings(rows).to_string(),
    @cor.json_string("total_risks") +
    ": " +
    reset14_total_risks(rows).to_string(),
    @cor.json_string("records") + ": " + @cor.array_json(items),
  ]) +
  "\n"
}

///|
fn reset14_row_json(row : PdfV2Reset14Coverage) -> String {
  @cor.object_json([
    @cor.json_string("pdf_name") + ": " + @cor.json_string(row.pdf_name),
    @cor.json_string("pdf_path") + ": " + @cor.json_string(row.pdf_path),
    @cor.json_string("pages") + ": " + row.pages.to_string(),
    @cor.json_string("content_streams") + ": " + row.content_streams.to_string(),
    @cor.json_string("source_events") + ": " + row.source_events.to_string(),
    @cor.json_string("text_ops") + ": " + row.text_ops.to_string(),
    @cor.json_string("glyphs") + ": " + row.glyphs.to_string(),
    @cor.json_string("decoded_chars") + ": " + row.decoded_chars.to_string(),
    @cor.json_string("high_confidence_text_events") +
    ": " +
    row.high_confidence_text_events.to_string(),
    @cor.json_string("medium_confidence_text_events") +
    ": " +
    row.medium_confidence_text_events.to_string(),
    @cor.json_string("low_confidence_text_events") +
    ": " +
    row.low_confidence_text_events.to_string(),
    @cor.json_string("failed_decode_text_events") +
    ": " +
    row.failed_decode_text_events.to_string(),
    @cor.json_string("low_confidence_text_ratio") +
    ": " +
    row.low_confidence_text_ratio.to_string(),
    @cor.json_string("unmapped_char_estimate") +
    ": " +
    row.unmapped_char_estimate.to_string(),
    @cor.json_string("warnings") + ": " + row.warnings.to_string(),
    @cor.json_string("risks") + ": " + row.risks.to_string(),
    @cor.json_string("core_warnings") + ": " + row.core_warnings.to_string(),
    @cor.json_string("core_risks") + ": " + row.core_risks.to_string(),
    @cor.json_string("feature_records") + ": " + row.feature_records.to_string(),
    @cor.json_string("decisions") + ": " + row.decisions.to_string(),
    @cor.json_string("lowered_blocks") + ": " + row.lowered_blocks.to_string(),
    @cor.json_string("type0_or_cid_font_present") +
    ": " +
    @cor.bool_json(row.type0_or_cid_font_present),
    @cor.json_string("tounicode_or_cmap_covered") +
    ": " +
    @cor.bool_json(row.tounicode_or_cmap_covered),
    @cor.json_string("flate_decode_handled") +
    ": " +
    @cor.bool_json(row.flate_decode_handled),
    @cor.json_string("missing_font_diagnostic") +
    ": " +
    @cor.bool_json(row.missing_font_diagnostic),
    @cor.json_string("missing_tounicode_diagnostic") +
    ": " +
    @cor.bool_json(row.missing_tounicode_diagnostic),
    @cor.json_string("malformed_stream_diagnostic") +
    ": " +
    @cor.bool_json(row.malformed_stream_diagnostic),
    @cor.json_string("object_or_xref_issue_diagnostic") +
    ": " +
    @cor.bool_json(row.object_or_xref_issue_diagnostic),
    @cor.json_string("encrypted_fail_closed") +
    ": " +
    @cor.bool_json(row.encrypted_fail_closed),
    @cor.json_string("no_fallback_preserved") +
    ": " +
    @cor.bool_json(row.no_fallback_preserved),
    @cor.json_string("source_to_lowering_stable") +
    ": " +
    @cor.bool_json(row.source_to_lowering_stable),
    @cor.json_string("reason_tags") +
    ": " +
    @cor.string_array_json(row.reason_tags),
    @cor.json_string("warning_tags") +
    ": " +
    @cor.string_array_json(row.warning_tags),
    @cor.json_string("risk_tags") + ": " + @cor.string_array_json(row.risk_tags),
  ])
}

///|
fn reset14_total_pages(rows : Array[PdfV2Reset14Coverage]) -> Int {
  let mut total = 0
  for row in rows {
    total = total + row.pages
  }
  total
}

///|
fn reset14_total_text_ops(rows : Array[PdfV2Reset14Coverage]) -> Int {
  let mut total = 0
  for row in rows {
    total = total + row.text_ops
  }
  total
}

///|
fn reset14_total_decoded_chars(rows : Array[PdfV2Reset14Coverage]) -> Int {
  let mut total = 0
  for row in rows {
    total = total + row.decoded_chars
  }
  total
}

///|
fn reset14_total_warnings(rows : Array[PdfV2Reset14Coverage]) -> Int {
  let mut total = 0
  for row in rows {
    total = total + row.warnings
  }
  total
}

///|
fn reset14_total_risks(rows : Array[PdfV2Reset14Coverage]) -> Int {
  let mut total = 0
  for row in rows {
    total = total + row.risks
  }
  total
}

///|
fn reset14_resolve_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }
  let root = reset14_repo_root()
  let rooted = reset14_join_path(root, path)
  if @fs.path_exists(rooted) {
    return rooted
  }
  fail("RESET-14 PDF file not found: " + path)
}

///|
fn reset14_repo_root() -> String {
  match @sys.get_env_var("PWD") {
    Some(cwd) =>
      match reset14_find_repo_root_from(cwd) {
        Some(root) => root
        None => cwd
      }
    None => "."
  }
}

///|
fn reset14_find_repo_root_from(dir : String) -> String? {
  if @fs.path_exists(reset14_join_path(dir, "moon.mod")) {
    return Some(dir)
  }
  let parent = reset14_parent_dir(dir)
  if parent == "" || parent == dir {
    None
  } else {
    reset14_find_repo_root_from(parent)
  }
}

///|
fn reset14_parent_dir(path : String) -> String {
  match path.rev_find("/") {
    None => ""
    Some(idx) => if idx == 0 { "/" } else { path[:idx].to_owned() }
  }
}

///|
fn reset14_join_path(base : String, rel : String) -> String {
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
fn reset14_ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path) catch {
      e => fail("RESET-14 create dir failed: " + e.to_string())
    }
  }
}

///|
fn reset14_ensure_dir_tree(path : String) -> Unit raise {
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
    let next = reset14_join_path(current, segment)
    reset14_ensure_dir(next)
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
