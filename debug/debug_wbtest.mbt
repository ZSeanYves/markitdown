///|
fn debug_assert_contains(haystack : String, needle : String) -> Unit raise {
  if !haystack.contains(needle) {
    fail("expected text to contain: " + needle + "\nactual:\n" + haystack)
  }
}

///|
fn debug_resolve_sample(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
async test "debug inspect report works for txt" {
  let input = debug_resolve_sample("samples/main_process/txt/txt_plain.txt")
  let report = build_debug_report(input, {
      output_kind: @cor.DebugOutputKind::Json,
      with_ir: false,
      with_metadata_summary: false,
      with_normalization: false,
    })
    |> unwrap_or_fail("build txt debug report failed")

  assert_eq(report.detected_format, "txt")
  assert_eq(report.status, "ok")

  let rendered = @cor.render_debug_report(report, @cor.DebugOutputKind::Json)
  debug_assert_contains(rendered, "\"detected_format\": \"txt\"")
  debug_assert_contains(rendered, "\"sections\"")
}

///|
async test "debug inspect report includes pdf normalization section" {
  let input = debug_resolve_sample("samples/main_process/pdf/text_simple.pdf")
  let report = build_debug_report(input, {
      output_kind: @cor.DebugOutputKind::Json,
      with_ir: false,
      with_metadata_summary: false,
      with_normalization: true,
    })
    |> unwrap_or_fail("build pdf debug report failed")

  let rendered = @cor.render_debug_report(report, @cor.DebugOutputKind::Json)
  debug_assert_contains(rendered, "\"detected_format\": \"pdf\"")
  debug_assert_contains(rendered, "\"name\": \"pdf_backend\"")
  debug_assert_contains(rendered, "\"name\": \"pdf_pages\"")
  debug_assert_contains(rendered, "\"name\": \"pdf_text_model\"")
  debug_assert_contains(rendered, "\"name\": \"pdf_annotations\"")
  debug_assert_contains(rendered, "\"name\": \"pdf_links\"")
  debug_assert_contains(rendered, "\"name\": \"pdf_pipeline\"")
  debug_assert_contains(rendered, "\"name\": \"normalization\"")
  debug_assert_contains(rendered, "\"available\": true")
  debug_assert_contains(rendered, "\"output_profile\": \"PdfText\"")
  debug_assert_contains(rendered, "\"outline_count\"")
  debug_assert_contains(rendered, "\"heading_status_counts\"")
  debug_assert_contains(rendered, "\"text_signal_level\": \"normal\"")
  debug_assert_contains(rendered, "\"ocr_recommended\": false")
  debug_assert_contains(rendered, "\"name\": \"layout_assist\"")
  debug_assert_contains(rendered, "\"provider_count\"")
  debug_assert_contains(rendered, "\"prediction_count\"")
  debug_assert_contains(rendered, "\"heuristic-layout-assist\"")
}

///|
async test "debug inspect report surfaces report-only pdf scan diagnostics" {
  let input = debug_resolve_sample(
    "samples/main_process/pdf/assets/pdf_image_xobject.pdf",
  )
  let report = build_debug_report(input, {
      output_kind: @cor.DebugOutputKind::Json,
      with_ir: false,
      with_metadata_summary: false,
      with_normalization: false,
    })
    |> unwrap_or_fail("build low-text pdf debug report failed")

  let rendered = @cor.render_debug_report(report, @cor.DebugOutputKind::Json)
  debug_assert_contains(rendered, "\"detected_format\": \"pdf\"")
  debug_assert_contains(rendered, "\"name\": \"pdf_backend\"")
  debug_assert_contains(rendered, "\"ocr_mode\": \"native\"")
  debug_assert_contains(rendered, "\"ocr_used\": false")
  debug_assert_contains(rendered, "\"text_signal_level\": \"low\"")
  debug_assert_contains(rendered, "\"has_page_images\": true")
  debug_assert_contains(rendered, "\"page_image_count\": 1")
  debug_assert_contains(rendered, "\"image_only\": false")
  debug_assert_contains(rendered, "\"ocr_recommended\": true")
  debug_assert_contains(rendered, "\"name\": \"pdf_pages\"")
}

///|
async test "debug inspect report includes layout assist advisory predictions" {
  let input = debug_resolve_sample(
    "samples/main_process/pdf/pdf_heading_vs_short_sentence.pdf",
  )
  let report = build_debug_report(input, {
      output_kind: @cor.DebugOutputKind::Json,
      with_ir: false,
      with_metadata_summary: false,
      with_normalization: false,
    })
    |> unwrap_or_fail("build layout-assist debug report failed")

  let rendered = @cor.render_debug_report(report, @cor.DebugOutputKind::Json)
  debug_assert_contains(rendered, "\"name\": \"layout_assist\"")
  debug_assert_contains(rendered, "\"suggested_label\": \"heading_candidate\"")
  debug_assert_contains(rendered, "\"provider\": \"heuristic-layout-assist\"")
  debug_assert_contains(rendered, "\"mode\": \"report_only\"")
  debug_assert_contains(rendered, "\"target_id\"")
  debug_assert_contains(rendered, "\"label_counts\"")
  debug_assert_contains(rendered, "\"reason_counts\"")
}

///|
async test "debug pdf v2 trace report surfaces cross page sections in json" {
  let input = debug_resolve_sample(
    "samples/main_process/pdf/pdf_cross_page_paragraph.pdf",
  )
  let pipeline_options = @pdfv2conv.default_pdf_v2_convert_pipeline_options()
  let bridge_options = {
    ..@pdfv2conv.default_pdf_v2_product_bridge_options(),
    source_name: Some("pdf_cross_page_paragraph.pdf"),
  }
  let report = @pdfv2conv.pdf_v2_target_signal_trace_from_path(
      input, pipeline_options, bridge_options,
    )
    |> unwrap_trace_or_fail("build pdf v2 trace report failed")

  let rendered = @pdfv2conv.pdf_v2_target_signal_trace_to_json(report)
  debug_assert_contains(rendered, "\"source_name\":")
  debug_assert_contains(rendered, "\"selection\":")
  debug_assert_contains(rendered, "\"boundaries\":")
  debug_assert_contains(rendered, "\"heading_traces\":")
}

///|
async test "debug pdf v2 trace report surfaces cross page sections in text" {
  let input = debug_resolve_sample(
    "samples/main_process/pdf/pdf_cross_page_should_not_merge_phase15.pdf",
  )
  let pipeline_options = @pdfv2conv.default_pdf_v2_convert_pipeline_options()
  let bridge_options = {
    ..@pdfv2conv.default_pdf_v2_product_bridge_options(),
    source_name: Some("pdf_cross_page_should_not_merge_phase15.pdf"),
  }
  let report = @pdfv2conv.pdf_v2_target_signal_trace_from_path(
      input, pipeline_options, bridge_options,
    )
    |> unwrap_trace_or_fail("build pdf v2 trace text report failed")

  let rendered = @pdfv2conv.pdf_v2_target_signal_trace_to_text(report)
  debug_assert_contains(rendered, "pdf-v2 target signal trace")
  debug_assert_contains(rendered, "selection_path=")
  debug_assert_contains(rendered, "[boundary")
}

///|
async test "debug inspect report works for zip" {
  let input = debug_resolve_sample(
    "samples/main_process/zip/zip_basic_structured.zip",
  )
  let report = build_debug_report(input, {
      output_kind: @cor.DebugOutputKind::Json,
      with_ir: false,
      with_metadata_summary: true,
      with_normalization: false,
    })
    |> unwrap_or_fail("build zip debug report failed")

  assert_eq(report.detected_format, "zip")

  let rendered = @cor.render_debug_report(report, @cor.DebugOutputKind::Json)
  debug_assert_contains(rendered, "\"detected_format\": \"zip\"")
  debug_assert_contains(rendered, "\"name\": \"format_specific\"")
  debug_assert_contains(rendered, "\"unsafe_entry_count\"")
}

///|
async test "debug providers ocr listing stays lazy without probe" {
  let rendered = render_provider_listing(
    @cor.DebugOutputKind::Json,
    true,
    false,
    false,
  )
  debug_assert_contains(rendered, "\"kind\": \"provider_listing\"")
  debug_assert_contains(rendered, "\"probe_requested\": false")
  debug_assert_contains(rendered, "\"ocr_status\"")
  debug_assert_contains(rendered, "\"state\": \"rebuilding\"")
  debug_assert_contains(
    rendered, "\"message\": \"OCR provider execution has been retired while the OCRPageModel pipeline is rebuilt.\"",
  )
}

///|
async test "debug providers layout assist listing is stable" {
  let rendered = render_provider_listing(
    @cor.DebugOutputKind::Json,
    false,
    true,
    false,
  )
  debug_assert_contains(rendered, "\"layout_assist_providers\"")
  debug_assert_contains(rendered, "\"name\": \"noop-layout-assist\"")
  debug_assert_contains(rendered, "\"name\": \"heuristic-layout-assist\"")
  debug_assert_contains(rendered, "\"mode\": \"report_only\"")
}

///|
async test "debug providers probe path is explicit and skip safe" {
  let rendered = render_provider_listing(
    @cor.DebugOutputKind::Json,
    true,
    false,
    true,
  )
  debug_assert_contains(rendered, "\"probe_requested\": true")
  debug_assert_contains(rendered, "\"ocr_status\"")
  debug_assert_contains(rendered, "\"state\": \"rebuilding\"")
}

///|
async test "debug layout assist eval json includes summary fields" {
  let rendered = render_layout_assist_eval(
      @cor.DebugOutputKind::Json,
      Some("heldout"),
    )
    |> unwrap_string_or_fail("render layout-assist eval json failed")
  debug_assert_contains(rendered, "\"kind\": \"layout_assist_eval\"")
  debug_assert_contains(rendered, "\"sample_count\"")
  debug_assert_contains(rendered, "\"label_counts\"")
  debug_assert_contains(rendered, "\"provider\": \"heuristic-layout-assist\"")
  debug_assert_contains(rendered, "\"mode\": \"report_only\"")
}

///|
async test "debug layout assist eval text reports zero-prediction files" {
  let rendered = render_layout_assist_eval(
      @cor.DebugOutputKind::HumanReadable,
      Some("heldout"),
    )
    |> unwrap_string_or_fail("render layout-assist eval text failed")
  debug_assert_contains(rendered, "layout assist eval")
  debug_assert_contains(rendered, "summary=features=")
  debug_assert_contains(rendered, "zero_prediction_files=")
  debug_assert_contains(rendered, "label_counts=")
}

///|
fn unwrap_or_fail(
  result : Result[@cor.DebugReport, String],
  message : String,
) -> @cor.DebugReport raise {
  match result {
    Ok(report) => report
    Err(err) => fail(message + ": " + err)
  }
}

///|
fn unwrap_trace_or_fail(
  result : Result[@pdfv2conv.PdfV2TargetSignalTraceReport, @cor.AppError],
  message : String,
) -> @pdfv2conv.PdfV2TargetSignalTraceReport raise {
  match result {
    Ok(report) => report
    Err(err) => fail(message + ": " + err.to_string())
  }
}

///|
fn unwrap_string_or_fail(
  result : Result[String, String],
  message : String,
) -> String raise {
  match result {
    Ok(text) => text
    Err(err) => fail(message + ": " + err)
  }
}
