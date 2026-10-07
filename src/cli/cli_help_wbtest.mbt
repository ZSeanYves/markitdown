///|
fn run_cli_app_silent(raw_cli_args : Array[String]) -> Int {
  let was_enabled = cli_console_enabled.val
  cli_console_enabled.val = false
  defer {
    cli_console_enabled.val = was_enabled
  }
  run_cli_app(raw_cli_args)
}

///|
test "main CLI app dispatches help version and removed command guidance" {
  assert_eq(run_cli_app_silent(["markitdown"]), 0)
  for arg in ["help", "--help", "-h"] {
    assert_eq(run_cli_app_silent(["markitdown", arg]), 0)
  }
  for arg in ["version", "--version"] {
    assert_eq(run_cli_app_silent(["markitdown", arg]), 0)
  }
  for arg in ["convert", "normal", "debug", "ocr", "bench"] {
    assert_eq(run_cli_app_silent(["markitdown", arg]), 2)
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
    assert_eq(run_cli_app_silent(args), 2)
  }
}

///|
test "main CLI help and fail closed messages remain nonempty across categories" {
  let was_enabled = cli_console_enabled.val
  cli_console_enabled.val = false
  defer {
    cli_console_enabled.val = was_enabled
  }
  cli_write_stderr("")
  assert_true(cli_unsupported_format_message("xyz").contains("xyz"))
  assert_true(
    cli_fail_closed_format_message("input.xyz", Unknown, "xyz", Balanced).contains(
      "unsupported format",
    ),
  )
  assert_true(
    cli_fail_closed_format_message("input.pdf", Pdf, "pdf", Balanced).contains(
      "pdf",
    ),
  )
  assert_true(
    cli_fail_closed_format_message("input.png", Image(Png), "png", Balanced) !=
    "",
  )
  assert_true(
    cli_fail_closed_format_message(
      "/definitely/missing/image.png",
      Image(Png),
      "png",
      Balanced,
    ).contains("unsupported format"),
  )
  assert_true(
    cli_fail_closed_format_message(
      "/definitely/missing/image.png",
      Image(Png),
      "png",
      Accurate,
    ) !=
    "",
  )
  assert_true(
    cli_usage_text().contains("unsupported mode requests fail closed"),
  )
  assert_eq(exit_cli_error(cli_failure(ConversionFailure, "contract")), 4)
  assert_eq(cli_failure_exit_code(cli_failure(UsageFailure, "bad option")), 2)
  assert_eq(
    cli_failure_exit_code(cli_failure(DetectionFailure, "same text")),
    3,
  )
  assert_eq(
    cli_failure_exit_code(cli_failure(ConversionFailure, "same text")),
    4,
  )
  assert_eq(cli_failure_exit_code(cli_failure(ResourceFailure, "same text")), 5)
  assert_eq(cli_failure_exit_code(cli_failure(OutputFailure, "same text")), 6)
}

///|
test "typed CLI failures preserve conversion categories and unsupported formats" {
  let opts = cli_options("/definitely/missing/input.txt", None, None, Markdown)
  let mapped = [
    cli_failure_from_convert_error(opts, DetectFailed("detect")),
    cli_failure_from_convert_error(opts, ParseFailed("parse")),
    cli_failure_from_convert_error(opts, RenderFailed("render")),
    cli_failure_from_convert_error(
      opts,
      ResourceLimitExceeded(kind="input_bytes", observed=2L, limit=1L),
    ),
  ]
  assert_true(mapped[0].kind == DetectionFailure)
  assert_true(mapped[1].kind == ConversionFailure)
  assert_true(mapped[2].kind == OutputFailure)
  assert_true(mapped[3].kind == ResourceFailure)

  let unsupported = cli_options(
    "/definitely/missing/workbook.xls",
    None,
    Some(Unknown),
    Markdown,
  )
  match run_cli_impl(unsupported, false) {
    Err(failure) => {
      assert_true(failure.kind == DetectionFailure)
      assert_eq(cli_failure_exit_code(failure), 3)
      assert_true(failure.message.contains("unsupported format"))
    }
    Ok(_) => fail("unsupported format must fail before conversion")
  }
}
