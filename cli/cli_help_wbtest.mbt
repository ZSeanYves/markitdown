///|
test "main CLI app dispatches help version and removed command guidance" {
  assert_eq(run_cli_app(["markitdown"]), 0)
  for arg in ["help", "--help", "-h"] {
    assert_eq(run_cli_app(["markitdown", arg]), 0)
  }
  for arg in ["version", "--version"] {
    assert_eq(run_cli_app(["markitdown", arg]), 0)
  }
  for arg in ["convert", "normal", "debug", "ocr", "bench"] {
    assert_eq(run_cli_app(["markitdown", arg]), 1)
  }
}

///|
test "main CLI app fails closed on malformed option sets" {
  let invalid = [
    ["markitdown", "--format"],
    ["markitdown", "--format", "unknown", "input"],
    ["markitdown", "--ocr", "--no-ocr", "input.png"],
    ["markitdown", "--debug", "--rag", "input.md"],
    ["markitdown", "accurate"],
    ["markitdown", "stream"],
    ["markitdown", "batch"],
    ["markitdown", "batch", "accurate"],
  ]
  for args in invalid {
    assert_eq(run_cli_app(args), 1)
  }
}

///|
test "main CLI help and fail closed messages remain nonempty across categories" {
  cli_write_stderr("")
  assert_true(cli_unsupported_format_message("xyz").contains("xyz"))
  assert_true(
    cli_fail_closed_format_message(
      "input.xyz",
      @input.DetectedFormat::Unknown,
      "xyz",
      @parser.default_ocr_options(),
      @convert.FidelityMode::Balanced,
    ).contains("unsupported format"),
  )
  assert_true(
    cli_fail_closed_format_message(
      "input.pdf",
      @input.DetectedFormat::Pdf,
      "pdf",
      @parser.default_ocr_options(),
      @convert.FidelityMode::Balanced,
    ).contains("PDF"),
  )
  assert_true(
    cli_fail_closed_format_message(
      "input.png",
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
      "png",
      @parser.disabled_ocr_options(),
      @convert.FidelityMode::Balanced,
    ) !=
    "",
  )
  assert_true(
    cli_fail_closed_format_message(
      "/definitely/missing/image.png",
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
      "png",
      @parser.default_ocr_options(),
      @convert.FidelityMode::Balanced,
    ).contains("image OCR"),
  )
  assert_true(
    cli_fail_closed_format_message(
      "/definitely/missing/image.png",
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
      "png",
      @parser.explicit_ocr_options(language=Some("eng")),
      @convert.FidelityMode::Accurate,
    ) !=
    "",
  )
  assert_true(
    cli_usage_text().contains("unsupported mode requests fail closed"),
  )
  assert_eq(exit_cli_error("contract", false), 1)
}
