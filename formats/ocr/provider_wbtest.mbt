///|
test "tesseract argv keeps explicit baseline args and language" {
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::Tesseract,
    language=Some("eng"),
  )
  let argv = build_tesseract_argv(request)
  assert_true(
    argv ==
    ["scan.png", "stdout", "--oem", "1", "--psm", "6", "-l", "eng", "tsv"],
  )
}

///|
test "tesseract injected command covers success and classified failures" {
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::Tesseract,
    language=Some("eng"),
  )
  let tsv = "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n" +
    "1\t1\t0\t0\t0\t0\t0\t0\t100\t100\t-1\t\n" +
    "2\t1\t1\t0\t0\t0\t0\t0\t100\t100\t-1\t\n" +
    "4\t1\t1\t1\t1\t0\t10\t20\t80\t20\t-1\t\n" +
    "5\t1\t1\t1\t1\t1\t10\t20\t35\t20\t95.5\tHello\n" +
    "5\t1\t1\t1\t1\t2\t50\t20\t40\t20\t92\tOCR\n"
  let success = run_tesseract_provider_with_command(request, fn(
    _program,
    _argv,
  ) {
    Ok((0, tsv, ""))
  }).unwrap()
  assert_eq(success.pages.length(), 1)
  assert_eq(success.pages[0].blocks[0].lines[0].words.length(), 2)
  assert_true(
    success.diagnostics.any(item => item.has_prefix("tesseract_command=")),
  )
  assert_true(
    run_tesseract_provider_with_command(request, fn(_, _) { Ok((0, "", "")) })
    is Err(OcrProviderError::EmptyResult(_)),
  )
  assert_true(
    run_tesseract_provider_with_command(request, fn(_, _) {
      Ok((127, "", "command not found"))
    })
    is Err(OcrProviderError::CommandUnavailable(_)),
  )
  assert_true(
    run_tesseract_provider_with_command(request, fn(_, _) {
      Ok((2, "bad input", ""))
    })
    is Err(OcrProviderError::ExecutionFailed(_)),
  )
  assert_true(
    run_tesseract_provider_with_command(request, fn(_, _) {
      Err(OcrProviderError::ExecutionFailed("collector failed"))
    })
    is Err(OcrProviderError::ExecutionFailed(_)),
  )
}

///|
test "tesseract collector captures real subprocess output and launch failures" {
  let shell = @rtcmd.make_resolved_command(
    "/bin/sh",
    "/bin/sh",
    @rtcmd.ResolvedCommandSource::ExplicitArg,
  )
  let collected = collect_tesseract_output(shell, [
    "-c", "printf tess-out; printf tess-err >&2; exit 5",
  ]).unwrap()
  assert_eq(collected.0, 5)
  assert_eq(collected.1, "tess-out")
  assert_eq(collected.2, "tess-err")
  assert_true(
    collect_tesseract_output(
      @rtcmd.fallback_command("/definitely/missing/tesseract"),
      [],
    )
    is Err(OcrProviderError::ExecutionFailed(_)),
  )
}

///|
test "tesseract default resolver and provider execute or fail closed reproducibly" {
  let previous = @env.get_env_var(tesseract_command_env_var())
  @env.set_env_var(tesseract_command_env_var(), "/bin/sh")
  defer (match previous {
    Some(value) => @env.set_env_var(tesseract_command_env_var(), value)
    None => @env.unset_env_var(tesseract_command_env_var())
  })
  let request = make_ocr_provider_request(
    "samples/fixtures/contracts/ocr/ocr_tiny_png.png",
    OcrProviderKind::Tesseract,
    language=Some("eng"),
  )
  let command = build_tesseract_tsv_command(request)
  assert_true(command.0 != "")
  assert_true(
    command.1[:4] ==
    ["samples/fixtures/contracts/ocr/ocr_tiny_png.png", "stdout", "--oem", "1"],
  )
  match run_tesseract_provider(request) {
    Ok(result) => assert_true(result.pages.length() > 0)
    Err(error) => assert_true(error.to_string() != "")
  }
  let no_language = build_tesseract_argv(
    make_ocr_provider_request(
      "scan.png",
      OcrProviderKind::Tesseract,
      language=Some("   "),
    ),
  )
  assert_true(!no_language.contains("-l"))
  let fallback = @rtcmd.fallback_command("tesseract")
  assert_true(
    finalize_tesseract_command_result(request, fallback, (9, "", ""))
    is Err(OcrProviderError::ExecutionFailed(_)),
  )
  assert_true(
    finalize_tesseract_command_result(request, fallback, (0, "invalid tsv", ""))
    is Err(_),
  )
}
