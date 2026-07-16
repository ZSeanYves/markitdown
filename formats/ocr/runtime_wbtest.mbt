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
  expected_provider_kind? : OcrProviderKind = Tesseract,
) -> (OcrProviderRequest) -> Result[OcrProviderResult, OcrProviderError] {
  fn(request : OcrProviderRequest) {
    if request.provider_kind != expected_provider_kind {
      abort("unexpected provider kind")
    }
    if !request.image_path.contains("scan.png") {
      abort("unexpected image path: " + request.image_path)
    }
    if request.language != expected_language {
      abort("unexpected OCR language")
    }
    Ok(
      make_ocr_provider_result(
        [fake_ocr_page(request.language)],
        ocr_provider_kind_name(request.provider_kind),
      ),
    )
  }
}

///|
test "in-memory OCR input materializes inside runtime and preserves logical source" {
  let bytes = Bytes::from_array(
    [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].map(Int::to_byte),
  )
  let source = @input.input_from_bytes_with_format(
    bytes,
    "archive.zip::images/scan.png",
    Some(Image(Png)),
  )
  let invoked_path : Ref[String] = { val: "" }
  let provider = fn(request : OcrProviderRequest) {
    invoked_path.val = request.image_path
    let exists = @fs.path_exists(request.image_path)
    if !exists || !request.image_path.has_suffix(".png") {
      abort("expected materialized PNG provider path")
    }
    Ok(make_ocr_provider_result([fake_ocr_page(None)], "mock-memory"))
  }
  let parsed = image_ocr_parser_result_with_provider(
    source,
    Image(Png),
    @parser.explicit_ocr_options(),
    provider,
  ).unwrap()
  assert_true(invoked_path.val != "")
  assert_true(!@fs.path_exists(invoked_path.val))
  let first = parsed.document.unwrap().blocks[0]
  assert_true(
    first.source_ref.unwrap().file_id == Some("archive.zip::images/scan.png"),
  )

  let calls : Ref[Int] = { val: 0 }
  let rejected = image_ocr_parser_result_with_provider(
    @input.input_from_bytes_with_format(
      Bytes::from_array([1, 2, 3].map(Int::to_byte)),
      "bad.png",
      Some(Image(Png)),
    ),
    Image(Png),
    @parser.explicit_ocr_options(),
    fn(_request) {
      calls.val += 1
      Ok(make_ocr_provider_result([fake_ocr_page(None)], "unexpected"))
    },
  )
  assert_true(rejected is Err(_))
  assert_eq(calls.val, 0)
}

///|
test "image OCR parser messages fallback policy and empty result remain explicit" {
  let png = @input.DetectedFormat::Image(Png)
  assert_true(image_requires_explicit_ocr_message(png).contains("png"))
  assert_true(image_ocr_disabled_message(png).contains("OCR is disabled"))
  let no_language = @parser.explicit_ocr_options()
  let language = @parser.explicit_ocr_options(language=Some(" eng "))
  assert_true(
    !image_ocr_provider_not_wired_message(png, no_language).contains(
      "language=",
    ),
  )
  assert_true(
    image_ocr_provider_not_wired_message(png, language).contains("language=eng"),
  )
  assert_true(
    !image_ocr_provider_not_wired_message(
      png,
      @parser.explicit_ocr_options(language=Some(" ")),
    ).contains("language="),
  )
  assert_true(
    image_ocr_provider_error_message(png, ExecutionFailed("boom")).contains(
      "image_format=png",
    ),
  )
  assert_true(image_ocr_provider_should_fallback(NotConfigured("x")))
  assert_true(image_ocr_provider_should_fallback(CommandUnavailable("x")))
  assert_true(!image_ocr_provider_should_fallback(ExecutionFailed("x")))
  assert_true(!image_ocr_provider_should_fallback(OutputParseFailed("x")))
  assert_true(!image_ocr_provider_should_fallback(EmptyResult("x")))
  assert_true(
    image_ocr_provider_fallback_note(PaddleOcr, Tesseract).contains(
      "paddle_ocr",
    ),
  )
  let original = make_ocr_provider_result([], "empty", diagnostics=["base"])
  let annotated = image_ocr_result_with_fallback_note(
    original,
    PaddleOcr,
    Tesseract,
  )
  assert_eq(original.diagnostics.length(), 1)
  assert_eq(annotated.diagnostics.length(), 2)
  match
    image_ocr_parse_success_result(
      @input.input_from_path("scan.png"),
      png,
      language,
      original,
      DirectImageBalanced,
    ) {
    Err(error) => assert_true(error.contains("empty OCR model"))
    Ok(_) => fail("empty OCR result must fail closed")
  }
  let context = @parser.new_parse_context(png)
  assert_true(ocr_options_from_parse_context(context).intent == Auto)
  assert_true(ocr_image_parser_capability().produces_layout)
}

///|
test "image OCR parser lowers injected OCR pages into document paragraphs and success diagnostics" {
  let source = @input.input_from_path("scan.png")
  let detected = @input.DetectedFormat::Image(Png)
  let parsed = match
    image_ocr_parser_result_with_provider(
      source,
      detected,
      @parser.explicit_ocr_options(language=Some("eng")),
      fake_success_provider(Some("eng")),
      requested_mode=Some(LayoutTwoStage),
    ) {
    Ok(value) => value
    Err(msg) => fail("expected OCR parser success: " + msg)
  }
  assert_true(parsed.mode == LayoutTwoStage)
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
      Image(Png),
      @parser.explicit_ocr_options(language=Some("eng")),
      failing_provider,
      requested_mode=Some(LayoutTwoStage),
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
      Image(Png),
      @parser.default_ocr_options(),
      skipped_provider,
    ) {
    Err(msg) => assert_true(msg.contains("image OCR is not enabled"))
    Ok(_) => fail("auto OCR should remain fail closed")
  }
  match
    image_ocr_parser_result_with_provider(
      @input.input_from_path("scan.png"),
      Image(Png),
      @parser.disabled_ocr_options(),
      skipped_provider,
    ) {
    Err(msg) => assert_true(msg.contains("OCR is disabled"))
    Ok(_) => fail("disabled OCR should remain fail closed")
  }
  assert_eq(skipped_calls.val, 0)
}

///|
async test "image OCR async parser lowers injected provider result" {
  let sync_provider = fake_success_provider(Some("eng"))
  let provider = async fn(request : OcrProviderRequest) {
    @async.with_timeout_opt(1000, fn() { sync_provider(request) }).unwrap()
  }
  let parsed = match
    image_ocr_parser_result_with_async_provider(
      @input.input_from_path("scan.png"),
      Image(Png),
      @parser.explicit_ocr_options(language=Some("eng")),
      provider,
      requested_mode=Some(LayoutTwoStage),
    ) {
    Ok(value) => value
    Err(msg) => fail("expected async OCR parser success: " + msg)
  }
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_eq(document.blocks.length(), 2)
  assert_eq(document.blocks[0].text, "MoonBit OCR")
  assert_true(
    parsed.diagnostics.metrics.get("ocr_provider_status") == Some("success"),
  )
}

///|
async test "image OCR async parser preserves no-call and invalid-format failures" {
  let calls : Ref[Int] = { val: 0 }
  let provider = async fn(_request : OcrProviderRequest) {
    @async.with_timeout_opt(1000, fn() {
      calls.val = calls.val + 1
      Err(OcrProviderError::ExecutionFailed("must not run"))
    }).unwrap()
  }
  let png = @input.DetectedFormat::Image(Png)
  assert_true(
    image_ocr_parser_result_with_async_provider(
      @input.input_from_path("scan.png"),
      png,
      @parser.default_ocr_options(),
      provider,
    )
    is Err(_),
  )
  assert_true(
    image_ocr_parser_result_with_async_provider(
      @input.input_from_path("scan.png"),
      png,
      @parser.disabled_ocr_options(),
      provider,
    )
    is Err(_),
  )
  assert_true(
    image_ocr_parser_result_with_async_provider(
      @input.input_from_path("not-image.txt"),
      Txt,
      @parser.explicit_ocr_options(),
      provider,
    )
    is Err(_),
  )
  assert_eq(calls.val, 0)
}

///|
async test "image OCR async accurate route controls fallback taxonomy" {
  let calls : Ref[Int] = { val: 0 }
  let fallback_provider = async fn(request : OcrProviderRequest) {
    @async.with_timeout_opt(1000, fn() {
      calls.val = calls.val + 1
      if calls.val == 1 {
        Err(OcrProviderError::NotConfigured("primary missing"))
      } else {
        fake_success_provider(Some("eng"))(request)
      }
    }).unwrap()
  }
  let parsed = image_ocr_parser_result_with_async_provider_target(
    @input.input_from_path("scan.png"),
    Image(Png),
    @parser.explicit_ocr_options(language=Some("eng")),
    DirectImageAccurate,
    fallback_provider,
  ).unwrap()
  assert_eq(calls.val, 2)
  assert_true(
    parsed.diagnostics.warnings.any(note => note.contains("provider_fallback")),
  )
  let failed = image_ocr_parser_result_with_async_provider_target(
    @input.input_from_path("scan.png"),
    Image(Png),
    @parser.explicit_ocr_options(),
    DirectImageAccurate,
    async fn(_request) {
      @async.with_timeout_opt(1000, fn() {
        Err(OcrProviderError::CommandUnavailable("missing"))
      }).unwrap()
    },
  )
  assert_true(failed is Err(_))
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
      Image(Png),
      @parser.explicit_ocr_options(language=Some("eng")),
      provider,
      requested_mode=Some(LayoutTwoStage),
    ) {
    Ok(value) => value
    Err(msg) => fail("expected OCR parser success: " + msg)
  }
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_eq(document.blocks.length(), 3)
  assert_true(document.blocks[0].kind == Paragraph)
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
    signal.signal_type == HeadingCandidate
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

///|
test "Paddle OCR wrapper payload parses batch geometry hierarchy and diagnostics" {
  let request = make_ocr_provider_batch_request(
    ["page-1.png", "page-2.png"],
    PaddleOcr,
    language=Some("eng"),
  )
  let payload =
    #|{
    #|  "provider_name": "paddle_ocr",
    #|  "provider_version": "3.0",
    #|  "diagnostics": ["batch complete", 42],
    #|  "jobs": [
    #|    {
    #|      "job_id": "job-0", "status": "ok", "diagnostics": ["first"],
    #|      "pages": [{
    #|        "page_index": 0, "width": 1200.5, "height": 800,
    #|        "provider_version": "3.0", "language": "eng", "diagnostics": ["page"],
    #|        "blocks": [{
    #|          "block_index": 0, "bbox": {"x": 10, "y": 20, "width": 300, "height": 40}, "confidence": 0.98,
    #|          "lines": [{
    #|            "line_index": 0, "text": "Hello OCR", "bbox": {"x0": 10, "y0": 20, "x1": 310, "y1": 60}, "confidence": 0.97,
    #|            "words": [
    #|              {"word_index": 0, "text": "Hello", "bbox": [10, 20, 100, 60], "confidence": 0.96},
    #|              {"word_index": 1, "text": "OCR", "confidence": 1}
    #|            ]
    #|          }]
    #|        }]
    #|      }]
    #|    },
    #|    {"job_id": "job-1", "status": "error", "error_kind": "decode", "error_message": "bad image", "pages": [], "diagnostics": []}
    #|  ]
    #|}
  let result = parse_paddle_ocr_wrapper_payload(payload, request).unwrap()
  assert_eq(result.pages.length(), 1)
  assert_eq(result.jobs.length(), 2)
  assert_eq(result.pages[0].blocks[0].lines[0].words.length(), 2)
  assert_true(result.pages[0].width == Some(1200.5))
  assert_true(result.provider_name == "paddle_ocr")
  assert_true(result.provider_version == Some("3.0"))
}

///|
test "Paddle OCR wrapper payload failures remain classified and fail closed" {
  let request = make_ocr_provider_request("page.png", PaddleOcr)
  let invalid_payloads = [
    "", "not json", "[]", "{}", "{\"provider_name\":\"paddle\"}", "{\"provider_name\":\"paddle\",\"jobs\":[1]}",
    "{\"provider_name\":\"paddle\",\"jobs\":[{\"job_id\":1,\"status\":\"ok\",\"pages\":[]}]}",
    "{\"provider_name\":\"paddle\",\"jobs\":[{\"job_id\":\"job-0\",\"status\":1,\"pages\":[]}]}",
    "{\"provider_name\":\"paddle\",\"jobs\":[{\"job_id\":\"job-0\",\"status\":\"ok\"}]}",
    "{\"provider_name\":\"paddle\",\"jobs\":[{\"job_id\":\"job-0\",\"status\":\"ok\",\"pages\":[1]}]}",
    "{\"provider_name\":\"paddle\",\"jobs\":[{\"job_id\":\"job-0\",\"status\":\"ok\",\"pages\":[{\"page_index\":0}]}]}",
    "{\"provider_name\":\"paddle\",\"jobs\":[{\"job_id\":\"job-0\",\"status\":\"ok\",\"pages\":[{\"page_index\":0,\"blocks\":[1]}]}]}",
    "{\"provider_name\":\"paddle\",\"jobs\":[{\"job_id\":\"job-0\",\"status\":\"ok\",\"pages\":[{\"page_index\":0,\"blocks\":[{\"block_index\":0}]}]}]}",
  ]
  for payload in invalid_payloads {
    assert_true(parse_paddle_ocr_wrapper_payload(payload, request) is Err(_))
  }
  assert_true(
    parse_paddle_ocr_wrapper_payload(
      "{\"provider_name\":\"paddle\",\"jobs\":[{\"job_id\":\"job-0\",\"status\":\"empty\",\"pages\":[]}]}",
      request,
    )
    is Err(EmptyResult(_)),
  )
  assert_true(
    parse_paddle_ocr_wrapper_payload(
      "{\"provider_name\":\"paddle\",\"jobs\":[{\"job_id\":\"job-0\",\"status\":\"error\",\"error_message\":\"failed\",\"pages\":[]}]}",
      request,
    )
    is Err(ExecutionFailed(_)),
  )
}

///|
test "Paddle OCR explicit wrapper command plans finalize and clean temporary files" {
  let request = make_ocr_provider_request(
    "scan.png",
    PaddleOcr,
    language=Some("eng"),
  )
  let plan = build_paddle_ocr_command_with_wrapper(
    request, "/usr/bin/env python3 wrapper.py",
  ).unwrap()
  assert_eq(plan.0, "/usr/bin/env")
  assert_true(plan.1.contains("python3"))
  assert_true(plan.1.contains("--batch-json"))
  assert_true(plan.1.contains("--result-json"))
  let result = run_paddle_ocr_provider_with_command_with_wrapper(
    request,
    "/usr/bin/env python3 wrapper.py",
    fn(_program, argv) {
      let result_path = argv[argv.length() - 1]
      let payload = "{\"provider_name\":\"paddle_ocr\",\"provider_version\":\"test\",\"jobs\":[{\"job_id\":\"job-0\",\"status\":\"ok\",\"pages\":[{\"page_index\":0,\"blocks\":[]}]}]}"
      @fs.write_string_to_file(result_path, payload, encoding="utf8") catch {
        err => return Err(ExecutionFailed(err.to_string()))
      }
      Ok((0, "wrapper stdout", "wrapper stderr"))
    },
  ).unwrap()
  assert_eq(result.pages.length(), 1)
  assert_true(result.diagnostics.contains("paddle_ocr_stdout=wrapper stdout"))
  assert_true(result.diagnostics.contains("paddle_ocr_stderr=wrapper stderr"))
  assert_true(
    result.diagnostics.any(item => item.has_prefix("paddle_ocr_command_source=")),
  )
}

///|
test "Paddle OCR explicit wrapper command classifies plan collector and process failures" {
  let request = make_ocr_provider_request("scan.png", PaddleOcr)
  assert_true(
    build_paddle_ocr_command_with_wrapper(request, "  ")
    is Err(NotConfigured(_)),
  )
  assert_true(
    build_paddle_ocr_command_with_wrapper(request, "python 'unterminated")
    is Err(NotConfigured(_)),
  )
  assert_true(
    run_paddle_ocr_provider_with_command_with_wrapper(
      request,
      "/usr/bin/env python3 wrapper.py",
      fn(_, _) { Err(ExecutionFailed("collector")) },
    )
    is Err(ExecutionFailed(_)),
  )
  assert_true(
    run_paddle_ocr_provider_with_command_with_wrapper(
      request,
      "/usr/bin/env python3 wrapper.py",
      fn(_, _) { Ok((0, "", "")) },
    )
    is Err(OutputParseFailed(_)),
  )
  assert_true(
    run_paddle_ocr_provider_with_command_with_wrapper(
      request,
      "/usr/bin/env python3 wrapper.py",
      fn(_, _) { Ok((127, "", "command not found")) },
    )
    is Err(CommandUnavailable(_)),
  )
  assert_true(
    run_paddle_ocr_provider_with_command_with_wrapper(
      request,
      "/usr/bin/env python3 wrapper.py",
      fn(_, _) { Ok((2, "failed", "")) },
    )
    is Err(ExecutionFailed(_)),
  )
}

///|
test "Paddle OCR collector captures real subprocess output and launch failures" {
  let shell = @rtcmd.make_resolved_command("/bin/sh", "/bin/sh", ExplicitArg)
  let collected = collect_paddle_ocr_output(shell, [
    "-c", "printf paddle-out; printf paddle-err >&2; exit 4",
  ]).unwrap()
  assert_eq(collected.0, 4)
  assert_eq(collected.1, "paddle-out")
  assert_eq(collected.2, "paddle-err")
  assert_true(
    collect_paddle_ocr_output(
      @rtcmd.fallback_command("/definitely/missing/paddle-wrapper"),
      [],
    )
    is Err(ExecutionFailed(_)),
  )
}

///|
test "Paddle OCR runtime utilities cover configuration paths JSON and recursive cleanup" {
  assert_eq(runtime_python_env_var(), "MARKITDOWN_RUNTIME_PYTHON")
  assert_true(
    paddle_ocr_default_wrapper_path().has_suffix("paddle_ocr_wrapper.py"),
  )
  assert_true(
    repo_local_runtime_python_path().contains(".venv-markitdown-accurate"),
  )
  assert_true(official_paddle_wrapper_missing_message().contains("PaddleOCR"))
  assert_true(
    paddle_ocr_split_command_config_error("TEST", TrailingEscape)
    is NotConfigured(_),
  )
  assert_eq(
    paddle_json_quote_string("a\"b\\c\nd\re\tf"),
    "\"a\\\"b\\\\c\\nd\\re\\tf\"",
  )
  let empty = make_ocr_provider_batch_request([], PaddleOcr)
  assert_true(ocr_runtime_request_temp_dir(empty).contains("paddle_empty_"))
  assert_true(paddle_ocr_batch_request_json(empty).contains("\"jobs\":[]"))
  let root = ".tmp/tests/ocr_runtime/utility-contract"
  ocr_runtime_cleanup_temp_dir(root)
  ocr_runtime_ensure_dir_tree(root + "/./a/b") catch {
    err => fail("create OCR utility dirs: " + err.to_string())
  }
  @fs.write_string_to_file(root + "/a/b/value.txt", "value", encoding="utf8") catch {
    err => fail("write OCR utility file: " + err.to_string())
  }
  ocr_runtime_ensure_dir_tree(root + "/a/b") catch {
    err => fail("repeat OCR utility dirs: " + err.to_string())
  }
  ocr_runtime_cleanup_temp_dir(root)
  assert_true(!@fs.path_exists(root))
  ocr_runtime_cleanup_temp_dir(root)
  let request = make_ocr_provider_request("scan.png", PaddleOcr)
  match build_paddle_ocr_command(request) {
    Ok(command) => {
      assert_true(command.0 != "")
      assert_true(command.1.contains("--batch-json"))
      let result_path = command.1[command.1.length() - 1]
      let temp_dir = result_path[:result_path.length() - "/result.json".length()].to_owned()
      ocr_runtime_cleanup_temp_dir(temp_dir)
    }
    Err(error) => assert_true(error.to_string() != "")
  }
}

///|
