///|
test "PDF OCR raster runtime materializes bytes enumerates pages and cleans output" {
  let source = @input.input_from_bytes_with_format(
    @utf8.encode("%PDF-1.4\nsynthetic"),
    "scan contract.pdf",
    Some(Pdf),
  )
  let result = rasterize_pdf_with_pdftoppm(source, fn(_program, argv) {
    let prefix = argv[argv.length() - 1]
    @fs.write_bytes_to_file(prefix + "-1.png", @utf8.encode("page-one")) catch {
      err => return Err(ExecutionFailed(err.to_string()))
    }
    @fs.write_bytes_to_file(prefix + "-2.png", @utf8.encode("page-two")) catch {
      err => return Err(ExecutionFailed(err.to_string()))
    }
    Ok((0, "rendered", "warning"))
  }).unwrap()
  let raster = result.0
  let temp_dir = result.1
  assert_eq(raster.backend_name, "pdftoppm")
  assert_eq(raster.page_count, 2)
  assert_true(raster.pages.all(page => page.success))
  assert_true(raster.pages[0].image_path.unwrap().has_suffix("page-1.png"))
  assert_true(raster.diagnostics.contains("pdftoppm_stdout=rendered"))
  assert_true(raster.diagnostics.contains("pdftoppm_stderr=warning"))
  assert_true(@fs.path_exists(temp_dir))
  cleanup_pdf_ocr_temp_dir(temp_dir)
  assert_true(!@fs.path_exists(temp_dir))
}

///|
test "PDF OCR raster runtime classifies empty unavailable and execution failures" {
  let source = @input.input_from_bytes_with_format(
    @utf8.encode("%PDF-1.4\nsynthetic"),
    "failure.pdf",
    Some(Pdf),
  )
  assert_true(
    rasterize_pdf_with_pdftoppm(source, fn(_, _) { Ok((0, "", "")) })
    is Err(EmptyResult(_)),
  )
  assert_true(
    rasterize_pdf_with_pdftoppm(source, fn(_, _) {
      Ok((127, "", "command not found"))
    })
    is Err(CommandUnavailable(_)),
  )
  assert_true(
    rasterize_pdf_with_pdftoppm(source, fn(_, _) { Ok((2, "bad PDF", "")) })
    is Err(ExecutionFailed(_)),
  )
  assert_true(
    rasterize_pdf_with_pdftoppm(source, fn(_, _) {
      Err(OutputParseFailed("collector"))
    })
    is Err(OutputParseFailed(_)),
  )
}

///|
test "PDF raster taxonomy capability and command construction stay stable" {
  assert_eq(pdf_rasterizer_kind_name(PdfToPpm), "pdftoppm")
  let errors = [
    PdfRasterizerError::CommandUnavailable("missing"),
    ExecutionFailed("failed"),
    OutputParseFailed("parse"),
    EmptyResult("empty"),
  ]
  let statuses = errors.map(pdf_rasterizer_error_status)
  assert_true(statuses.contains(CommandUnavailable))
  assert_true(statuses.contains(ExecutionFailed))
  assert_true(statuses.contains(OutputParseFailed))
  assert_true(statuses.contains(EmptyResult))
  assert_true(errors.all(error => error.to_string() != ""))
  assert_true(pdf_raster_provider_error_message(errors[0]).contains("Poppler"))
  assert_eq(pdftoppm_command_env_var(), "MARKITDOWN_PDFTOPPM_BIN")
  let command = build_pdftoppm_png_command("input.pdf", "out")
  assert_true(command.1 == ["-r", "150", "-png", "input.pdf", "out/page"])
  assert_true(pdf_ocr_layout_capability().produces_layout)
}

///|
test "PDF raster collector captures real subprocess stdout stderr and exit code" {
  let shell = @rtcmd.make_resolved_command("/bin/sh", "/bin/sh", ExplicitArg)
  let collected = collect_pdftoppm_output(shell, [
    "-c", "printf raster-out; printf raster-err >&2; exit 7",
  ]).unwrap()
  assert_eq(collected.0, 7)
  assert_eq(collected.1, "raster-out")
  assert_eq(collected.2, "raster-err")
  assert_true(
    collect_pdftoppm_output(
      @rtcmd.fallback_command("/definitely/missing/pdftoppm"),
      [],
    )
    is Err(ExecutionFailed(_)),
  )
}

///|
test "PDF raster default path and utility branches remain deterministic" {
  assert_eq(
    pdf_rasterizer_status_name(CommandUnavailable),
    "command_unavailable",
  )
  assert_eq(pdf_rasterizer_status_name(ExecutionFailed), "execution_failed")
  assert_eq(
    pdf_rasterizer_status_name(OutputParseFailed),
    "output_parse_failed",
  )
  assert_eq(pdf_rasterizer_status_name(EmptyResult), "empty_result")
  assert_true(
    pdf_raster_backend_dependency_diagnostic().title.contains("pdftoppm"),
  )
  let root = ".tmp/tests/pdf_ocr/utilities"
  pdf_ocr_cleanup_temp_dir(root)
  pdf_ocr_ensure_dir_tree(root + "/./nested") catch {
    err => fail("create PDF OCR utility directory: " + err.to_string())
  }
  pdf_ocr_ensure_dir_tree(root + "/nested") catch {
    err => fail("repeat PDF OCR utility directory: " + err.to_string())
  }
  defer pdf_ocr_cleanup_temp_dir(root)
  let path_source = @input.input_from_path(
    "samples/fixtures/contracts/pdf/text_simple.pdf",
  )
  assert_eq(
    pdf_ocr_materialize_source_path(path_source, root).unwrap(),
    "samples/fixtures/contracts/pdf/text_simple.pdf",
  )
  assert_true(pdf_ocr_temp_dir_name(path_source).contains("text_simple_pdf"))
  let command = @rtcmd.fallback_command("pdftoppm")
  assert_true(
    finalize_pdftoppm_result([], command, (0, "", "")) is Err(EmptyResult(_)),
  )
  assert_true(
    finalize_pdftoppm_result([], command, (9, "", ""))
    is Err(ExecutionFailed(_)),
  )
  let previous = @env.get_env_var(pdftoppm_command_env_var())
  @env.set_env_var(pdftoppm_command_env_var(), "/bin/sh")
  defer (match previous {
    Some(value) => @env.set_env_var(pdftoppm_command_env_var(), value)
    None => @env.unset_env_var(pdftoppm_command_env_var())
  })
  match rasterize_pdf_with_pdftoppm_default(path_source) {
    Ok((raster, temp_dir)) => {
      assert_true(raster.page_count > 0)
      cleanup_pdf_ocr_temp_dir(temp_dir)
    }
    Err(error) => assert_true(error.to_string() != "")
  }
  pdf_ocr_cleanup_temp_dir(root + "/missing")
}
