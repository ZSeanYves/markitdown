///|
test "main cli image OCR intent remains fail closed by mode" {
  let root = test_tmp_root() + "/main-cli-image-ocr-intent"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let png_path = root + "/tiny.png"
  write_utf8_text(png_path, "not-a-real-image")

  match
    run_cli_with_image_ocr_provider(
      cli_options(
        png_path,
        None,
        None,
        @convert.OutputFormat::Markdown,
        ocr_options=@parser.explicit_ocr_options(),
      ),
      fake_cli_failing_image_provider(
        png_path,
        None,
        @focr.OcrProviderError::CommandUnavailable(
          "synthetic OCR provider unavailable",
        ),
      ),
    ) {
    Err(msg) =>
      assert_true(
        msg.contains("synthetic OCR provider unavailable") &&
        msg.contains("image_format=png"),
      )
    Ok(_) => fail("expected explicit OCR image path to fail closed")
  }

  match
    run_cli_with_image_ocr_provider(
      cli_options(
        png_path,
        None,
        None,
        @convert.OutputFormat::Markdown,
        ocr_options=@parser.explicit_ocr_options(language=Some("eng")),
      ),
      fake_cli_failing_image_provider(
        png_path,
        Some("eng"),
        @focr.OcrProviderError::ExecutionFailed("synthetic OCR provider failed"),
      ),
    ) {
    Err(msg) =>
      assert_true(
        msg.contains("synthetic OCR provider failed") &&
        msg.contains("image_format=png"),
      )
    Ok(_) => fail("expected explicit OCR image/lang path to fail closed")
  }

  let provider_calls : Ref[Int] = { val: 0 }
  match
    run_cli_with_image_ocr_provider(
      cli_options(
        png_path,
        None,
        None,
        @convert.OutputFormat::Markdown,
        ocr_options=@parser.disabled_ocr_options(),
      ),
      fn(_request : @focr.OcrProviderRequest) {
        provider_calls.val = provider_calls.val + 1
        Err(@focr.OcrProviderError::ExecutionFailed("provider should not run"))
      },
    ) {
    Err(msg) => {
      assert_true(msg.contains("image input conversion is not enabled"))
      assert_true(msg.contains("OCR is disabled"))
    }
    Ok(_) => fail("expected disabled OCR image path to fail closed")
  }
  assert_eq(provider_calls.val, 0)
}

///|
test "main cli parse rejects balanced pdf explicit OCR with accurate-route guidance" {
  let root = test_tmp_root() + "/main-cli-pdf-explicit-ocr"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let pdf_path = root + "/tiny.pdf"
  write_utf8_text(pdf_path, "%PDF-1.4 fake")

  match parse_cli_options(["--ocr", pdf_path]) {
    Err(msg) =>
      assert_true(
        msg.contains(
          "PDF OCR is only available through the `accurate` PDF layout route",
        ),
      )
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

  match
    run_cli(cli_options(pdf_path, None, None, @convert.OutputFormat::Markdown)) {
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
test "main cli direct image OCR can succeed through injected provider as a supported product path" {
  let root = test_tmp_root() + "/main-cli-image-ocr-success"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let png_path = root + "/tiny.png"
  write_utf8_text(png_path, "not-a-real-image")

  let result = run_cli_with_image_ocr_provider(
    cli_options(
      png_path,
      None,
      None,
      @convert.OutputFormat::Markdown,
      ocr_options=@parser.explicit_ocr_options(language=Some("eng")),
    ),
    fake_cli_image_provider(png_path, Some("eng")),
  )
  match result {
    Ok(content) => assert_eq(content, "MoonBit OCR\n\nSample 123")
    Err(msg) => fail("expected injected cli OCR success: " + msg)
  }
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
    ),
  )
}

///|
test "main cli direct image OCR can succeed through injected provider" {
  let root = test_tmp_root() + "/main-cli-image-ocr-success-async"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let png_path = root + "/tiny.png"
  write_utf8_text(png_path, "not-a-real-image")

  let result = run_cli_with_image_ocr_provider(
    cli_options(
      png_path,
      None,
      None,
      @convert.OutputFormat::Markdown,
      ocr_options=@parser.explicit_ocr_options(language=Some("eng")),
    ),
    fake_cli_image_provider(png_path, Some("eng")),
  )
  match result {
    Ok(content) => assert_eq(content, "MoonBit OCR\n\nSample 123")
    Err(msg) => fail("expected injected async cli OCR success: " + msg)
  }
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
    ),
  )
}

///|
test "main cli stream warning message stays stable for unsupported explicit stream fallback" {
  assert_eq(
    cli_explicit_stream_warning_message(@input.DetectedFormat::Toml),
    "warning: explicit --stream is not productized for `toml` yet; falling back to the canonical route",
  )
}

///|
test "main cli accurate warning message stays stable for unsupported accurate fallback" {
  assert_eq(
    cli_accurate_fallback_warning_message(@input.DetectedFormat::Toml),
    "warning: `--accurate` is not productized for `toml` yet; falling back to balanced mode",
  )
}

///|
test "main cli pdf debug json exposes header footer candidate diagnostics" {
  let rendered = match
    run_cli(
      cli_options(
        "samples/fixtures/contracts/pdf/text_simple.pdf",
        None,
        Some(@input.DetectedFormat::Pdf),
        @convert.OutputFormat::DebugJson,
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
    rendered.contains("\"pdf_table_reconstruction_policy\": \"disabled\""),
  )
  assert_true(!rendered.contains("\"pdf_v2\""))
  assert_true(!rendered.contains("\"pdf_debug\""))
}
