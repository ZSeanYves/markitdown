///|
test "main cli rejects retired PDF OCR without suggesting an OCR route" {
  let root = test_tmp_root() + "/main-cli-pdf-explicit-ocr"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let pdf_path = root + "/tiny.pdf"
  write_utf8_text(pdf_path, "%PDF-1.4 fake")

  match parse_cli_options(["--ocr", pdf_path]) {
    Err(msg) => assert_true(msg.contains("removed option: --ocr"))
    Ok(_) => fail("expected balanced pdf --ocr parse to fail closed")
  }
}

///|
test "main cli scanned-like pdf fails closed instead of returning empty markdown" {
  let root = test_tmp_root() + "/main-cli-pdf-empty-text-layer"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let pdf_path = root + "/empty-text-layer.pdf"
  write_utf8_text(
    pdf_path,
    [
      "%PDF-1.4", "1 0 obj", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
      "endobj", "2 0 obj", "<< /Length 5 >>", "stream", "BT ET", "endstream", "endobj",
      "3 0 obj", "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
      "endobj", "4 0 obj", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>", "endobj",
      "5 0 obj", "<< /Type /Catalog /Pages 4 0 R >>", "endobj", "trailer", "<< /Size 6 /Root 5 0 R >>",
      "%%EOF", "",
    ].join("\n"),
  )

  match run_cli(cli_options(pdf_path, None, None, Markdown)) {
    Err(msg) => {
      assert_true(
        msg.contains("empty") ||
        msg.contains("route probe artifact missing or mismatched"),
      )
      assert_true(
        msg.contains("native PDF reader backend") ||
        msg.contains("not recoverable") ||
        msg.contains("route probe artifact missing or mismatched"),
      )
      assert_true(!msg.contains("not configured"))
      assert_true(
        !msg.contains("image OCR provider returned a non-empty OCR model"),
      )
    }
    Ok(content) =>
      fail(
        "scanned-like pdf must not return successful empty markdown: " + content,
      )
  }
}

///|
test "main cli documents fail-closed unsupported mode policy" {
  assert_true(
    cli_usage_text().contains(
      "accurate preserves additional Office/ODF semantics",
    ),
  )
  assert_true(
    cli_usage_text().contains("stream uses a declared streaming route"),
  )
}

///|
test "main cli pdf debug json exposes header footer candidate diagnostics" {
  let rendered = match
    run_cli(
      cli_options(
        "samples/fixtures/contracts/pdf/text_simple.pdf",
        None,
        Some(Pdf),
        Debug,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current pdf debug json cli failed: " + msg)
  }

  assert_true(rendered.contains("\"renderer_name\": \"DebugJsonRenderer\""))
  assert_true(
    rendered.contains(
      "\"pdf_header_footer_candidate_strategy\": \"conservative_v1\"",
    ),
  )
  assert_true(rendered.contains("\"pdf_header_candidate_count\": "))
  assert_true(rendered.contains("\"pdf_footer_candidate_count\": "))
  assert_true(rendered.contains("\"pdf_header_footer_candidate_count\": "))
  assert_true(
    rendered.contains("\"pdf_table_candidate_strategy\": \"conservative_v1\""),
  )
  assert_true(rendered.contains("\"pdf_table_candidate_count\": "))
  assert_true(rendered.contains("\"pdf_table_row_candidate_count\": "))
  assert_true(
    rendered.contains("\"pdf_header_footer_filter_policy\": \"disabled\""),
  )
  assert_true(
    rendered.contains(
      "\"pdf_table_reconstruction_policy\": \"internal_simple_rows_only\"",
    ),
  )
  assert_true(!rendered.contains("\"pdf_v2\""))
  assert_true(!rendered.contains("\"pdf_debug\""))
}

///|
test "main cli accurate pdf debug json preserves native text route metrics" {
  let rendered = match
    run_cli(
      make_cli_options(
        "samples/fixtures/contracts/pdf/text_simple.pdf",
        None,
        None,
        Some(Pdf),
        Accurate,
        Accurate,
        @convert.output_mode_for_output_format(Debug),
        false,
        Debug,
        rag_options=@rag.default_rag_options(),
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("accurate pdf debug json cli failed: " + msg)
  }
  assert_true(
    rendered.contains(
      "\"pdf_header_footer_filter_policy\": \"internal_high_confidence_only\"",
    ),
  )
  assert_true(rendered.contains("\"pdf_native_backend\": \"true\""))
  assert_true(
    rendered.contains(
      "\"pdf_table_reconstruction_policy\": \"internal_simple_rows_only\"",
    ),
  )
  assert_true(
    rendered.contains("\"pdf_table_reconstruction_table_count\": \"0\""),
  )
  assert_true(rendered.contains("\"parser_mode\": \"page_single_pass\""))
}
