///|
fn fake_ocr_page(language : String?) -> OcrPageModel {
  let tsv = [
    "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
    "5\t1\t1\t1\t1\t1\t10\t10\t20\t10\t95\tMoonBit", "5\t1\t1\t1\t1\t2\t35\t10\t15\t10\t94\tOCR",
    "5\t1\t1\t1\t2\t1\t10\t25\t22\t10\t93\tSample", "5\t1\t1\t1\t2\t2\t36\t25\t18\t10\t92\t123",
  ].join("\n")
  let parsed = match parse_tesseract_tsv(tsv, language~) {
    Ok(value) => value
    Err(err) => abort("expected fake OCR TSV parse success: " + err.to_string())
  }
  parsed.pages[0]
}

///|
fn fake_success_provider(
  expected_language : String?,
) -> (OcrProviderRequest) -> Result[OcrProviderResult, OcrProviderError] {
  fn(request : OcrProviderRequest) {
    if request.provider_kind != OcrProviderKind::Tesseract {
      abort("unexpected provider kind")
    }
    if !request.image_path.contains("scan.png") {
      abort("unexpected image path: " + request.image_path)
    }
    if request.language != expected_language {
      abort("unexpected OCR language")
    }
    Ok(make_ocr_provider_result([fake_ocr_page(request.language)], "tesseract"))
  }
}

///|
test "image OCR parser lowers injected OCR pages into document paragraphs and success diagnostics" {
  let source = @input.input_from_path("scan.png")
  let detected = @input.DetectedFormat::Image(@input.ImageFormat::Png)
  let parsed = match
    image_ocr_parser_result_with_provider(
      source,
      detected,
      @parser.explicit_ocr_options(language=Some("eng")),
      fake_success_provider(Some("eng")),
      requested_mode=Some(@parser.ParserMode::LayoutTwoStage),
    ) {
    Ok(value) => value
    Err(msg) => fail("expected OCR parser success: " + msg)
  }
  assert_true(parsed.mode == @parser.ParserMode::LayoutTwoStage)
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_eq(document.blocks.length(), 2)
  assert_eq(document.blocks[0].text, "MoonBit OCR")
  assert_eq(document.blocks[1].text, "Sample 123")
  let source_ref = document.blocks[0].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(source_ref.file_id == Some("scan.png"))
  assert_true(source_ref.format == Some("png"))
  assert_true(source_ref.page == Some(1))
  assert_true(source_ref.line_start == Some(1))
  assert_true(source_ref.line_end == Some(1))
  assert_true(
    parsed.diagnostics.metrics.get("ocr_provider_status") == Some("success"),
  )
  assert_true(
    parsed.diagnostics.metrics.get("provider_invoked") == Some("true"),
  )
  assert_true(parsed.diagnostics.metrics.get("block_count") == Some("2"))
}

///|
test "image OCR parser injected provider keeps fail-closed taxonomy and no-call branches" {
  let provider_called : Ref[Int] = { val: 0 }
  let failing_provider = fn(request : OcrProviderRequest) {
    provider_called.val = provider_called.val + 1
    if request.language != Some("eng") {
      abort("unexpected failing provider language")
    }
    Err(OcrProviderError::ExecutionFailed("boom"))
  }
  match
    image_ocr_parser_result_with_provider(
      @input.input_from_path("scan.png"),
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
      @parser.explicit_ocr_options(language=Some("eng")),
      failing_provider,
      requested_mode=Some(@parser.ParserMode::LayoutTwoStage),
    ) {
    Err(msg) => {
      assert_true(msg.contains("boom"))
      assert_true(msg.contains("image_format=png"))
    }
    Ok(_) => fail("expected injected OCR provider failure")
  }
  assert_eq(provider_called.val, 1)

  let skipped_calls : Ref[Int] = { val: 0 }
  let skipped_provider = fn(_request : OcrProviderRequest) {
    skipped_calls.val = skipped_calls.val + 1
    Err(OcrProviderError::ExecutionFailed("should not run"))
  }
  match
    image_ocr_parser_result_with_provider(
      @input.input_from_path("scan.png"),
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
      @parser.default_ocr_options(),
      skipped_provider,
    ) {
    Err(msg) => assert_true(msg.contains("image OCR is not enabled"))
    Ok(_) => fail("auto OCR should remain fail closed")
  }
  match
    image_ocr_parser_result_with_provider(
      @input.input_from_path("scan.png"),
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
      @parser.disabled_ocr_options(),
      skipped_provider,
    ) {
    Err(msg) => assert_true(msg.contains("OCR is disabled"))
    Ok(_) => fail("disabled OCR should remain fail closed")
  }
  assert_eq(skipped_calls.val, 0)
}
