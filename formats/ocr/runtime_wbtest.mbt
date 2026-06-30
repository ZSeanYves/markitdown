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

///|
test "image OCR parser splits wide OCR lines into reading-order-aware paragraph blocks" {
  let tsv = [
    "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
    "5\t1\t1\t1\t1\t1\t80\t68\t100\t20\t96\tFIELD", "5\t1\t1\t1\t1\t2\t190\t68\t100\t20\t95\tNOTES",
    "5\t1\t1\t1\t1\t3\t300\t68\t50\t20\t95\tON", "5\t1\t1\t1\t1\t4\t360\t68\t160\t20\t95\tCOASTAL",
    "5\t1\t1\t1\t1\t5\t530\t68\t170\t20\t95\tWEATHER", "5\t1\t1\t1\t2\t1\t80\t155\t90\t20\t94\tMorning",
    "5\t1\t1\t1\t2\t2\t175\t155\t120\t20\t94\tobservations", "5\t1\t1\t1\t2\t3\t300\t155\t90\t20\t94\trecorded",
    "5\t1\t1\t1\t2\t4\t392\t155\t55\t20\t94\tover", "5\t1\t1\t1\t2\t5\t450\t155\t70\t20\t94\tthree",
    "5\t1\t1\t1\t2\t6\t525\t155\t80\t20\t94\tweeks", "5\t1\t1\t1\t2\t7\t610\t155\t55\t20\t94\tshow",
    "5\t1\t1\t1\t2\t8\t670\t155\t30\t20\t94\ta", "5\t1\t1\t1\t2\t9\t705\t155\t90\t20\t94\tstable",
    "5\t1\t1\t1\t2\t10\t980\t155\t110\t20\t93\tAfternoon", "5\t1\t1\t1\t2\t11\t1095\t155\t115\t20\t93\tsummaries",
    "5\t1\t1\t1\t2\t12\t1215\t155\t105\t20\t93\temphasize", "5\t1\t1\t1\t2\t13\t1325\t155\t70\t20\t93\tvessel",
    "5\t1\t1\t1\t3\t1\t80\t205\t130\t20\t94\ttemperature", "5\t1\t1\t1\t3\t2\t215\t205\t70\t20\t94\tband",
    "5\t1\t1\t1\t3\t3\t290\t205\t60\t20\t94\twith", "5\t1\t1\t1\t3\t4\t355\t205\t70\t20\t94\tbrief",
    "5\t1\t1\t1\t3\t5\t430\t205\t80\t20\t94\tspikes", "5\t1\t1\t1\t3\t6\t515\t205\t70\t20\t94\tafter",
    "5\t1\t1\t1\t3\t7\t590\t205\t75\t20\t94\tinland", "5\t1\t1\t1\t3\t8\t670\t205\t60\t20\t94\twind",
    "5\t1\t1\t1\t3\t9\t735\t205\t75\t20\t94\tshifts.", "5\t1\t1\t1\t3\t10\t980\t205\t55\t20\t93\tand",
    "5\t1\t1\t1\t3\t11\t1040\t205\t120\t20\t93\tmaintenance", "5\t1\t1\t1\t3\t12\t1165\t205\t90\t20\t93\tnotices",
  ].join("\n")
  let provider = fn(request : OcrProviderRequest) {
    if request.language != Some("eng") {
      abort("unexpected OCR language")
    }
    match parse_tesseract_tsv(tsv, language=request.language) {
      Ok(result) => Ok(result)
      Err(err) =>
        abort(
          "expected OCR TSV parse success in split-line test: " +
          err.to_string(),
        )
    }
  }
  let parsed = match
    image_ocr_parser_result_with_provider(
      @input.input_from_path("scan.png"),
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
      @parser.explicit_ocr_options(language=Some("eng")),
      provider,
      requested_mode=Some(@parser.ParserMode::LayoutTwoStage),
    ) {
    Ok(value) => value
    Err(msg) => fail("expected OCR parser success: " + msg)
  }
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_eq(document.blocks.length(), 3)
  assert_true(document.blocks[0].kind == @core.BlockKind::Paragraph)
  assert_eq(document.blocks[0].text, "FIELD NOTES ON COASTAL WEATHER")
  assert_eq(
    document.blocks[1].text,
    "Morning observations recorded over three weeks show a stable temperature band with brief spikes after inland wind shifts.",
  )
  assert_eq(
    document.blocks[2].text,
    "Afternoon summaries emphasize vessel and maintenance notices",
  )
  let heading_signal = document.blocks[0].signals.any(fn(signal) {
    signal.signal_type == @core.SignalType::HeadingCandidate
  })
  assert_true(heading_signal)
  let left_ref = document.blocks[1].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  let right_ref = document.blocks[2].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(left_ref.extra.get("reading_order_key") is Some(_))
  assert_true(right_ref.extra.get("reading_order_key") is Some(_))
}
