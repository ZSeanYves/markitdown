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
  debug_assert_contains(rendered, "\"ocr_providers\"")
  debug_assert_contains(rendered, "\"name\": \"noop\"")
  debug_assert_contains(rendered, "\"name\": \"tesseract-cli\"")
  debug_assert_contains(rendered, "\"name\": \"ocrmypdf-cli\"")
  debug_assert_contains(rendered, "\"name\": \"paddleocr\"")
  debug_assert_contains(rendered, "\"probe_status\": \"not_run\"")
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
  debug_assert_contains(rendered, "\"ocr_providers\"")
  debug_assert_contains(rendered, "\"name\": \"noop\"")
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
fn unwrap_string_or_fail(
  result : Result[String, String],
  message : String,
) -> String raise {
  match result {
    Ok(text) => text
    Err(err) => fail(message + ": " + err)
  }
}
