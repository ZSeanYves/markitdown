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
fn unwrap_or_fail(
  result : Result[@cor.DebugReport, String],
  message : String,
) -> @cor.DebugReport raise {
  match result {
    Ok(report) => report
    Err(err) => fail(message + ": " + err)
  }
}
