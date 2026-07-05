///|
test "ocr provider request preserves image path language and kind" {
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::Tesseract,
    language=Some("eng"),
  )
  assert_eq(request.image_path, "scan.png")
  assert_true(request.language == Some("eng"))
  assert_true(request.provider_kind == OcrProviderKind::Tesseract)
}

///|
test "ocr provider taxonomy exposes stable names" {
  assert_eq(ocr_provider_kind_name(OcrProviderKind::Tesseract), "tesseract")
  assert_eq(ocr_provider_kind_name(OcrProviderKind::PaddleOcr), "paddle_ocr")
  assert_eq(
    ocr_provider_selection_target_name(
      OcrProviderSelectionTarget::DirectImageBalanced,
    ),
    "direct_image_balanced",
  )
  assert_true(
    default_ocr_provider_kind_for_target(
      OcrProviderSelectionTarget::PdfBalanced,
    ) ==
    OcrProviderKind::Tesseract,
  )
  assert_true(
    default_ocr_provider_kind_for_target(
      OcrProviderSelectionTarget::PdfAccurate,
    ) ==
    OcrProviderKind::PaddleOcr,
  )
  assert_eq(
    ocr_provider_status_name(OcrProviderStatus::NotConfigured),
    "not_configured",
  )
  let error = OcrProviderError::CommandUnavailable("missing binary")
  assert_true(
    ocr_provider_error_status(error) == OcrProviderStatus::CommandUnavailable,
  )
  assert_eq(ocr_provider_language_label(Some("eng")), "eng")
  assert_eq(ocr_provider_language_label(None), "none")
  assert_true(
    tesseract_ocr_install_hint().contains("Missing dependency: Tesseract OCR"),
  )
  assert_true(tesseract_ocr_install_hint().contains("brew install tesseract"))
  assert_true(
    tesseract_ocr_install_hint().contains("sudo apt install tesseract-ocr"),
  )
  assert_true(
    paddle_ocr_install_hint().contains("Missing dependency: PaddleOCR bridge"),
  )
  assert_true(paddle_ocr_install_hint().contains("MARKITDOWN_PADDLE_OCR_CMD"))
  assert_eq(
    @core.dependency_diagnostic_status_name(
      tesseract_ocr_dependency_diagnostic().status,
    ),
    "missing",
  )
  assert_eq(tesseract_ocr_dependency_diagnostic().kind, "tesseract_ocr")
  assert_eq(paddle_ocr_dependency_diagnostic().kind, "paddle_ocr_bridge")
}

///|
test "ocr provider runtime resolves provider kinds without internal fallback" {
  assert_true(
    resolved_ocr_provider_kind_for_target(
      OcrProviderSelectionTarget::DirectImageBalanced,
    ) ==
    OcrProviderKind::Tesseract,
  )
  assert_true(
    resolved_ocr_provider_kind_for_target(
      OcrProviderSelectionTarget::DirectImageAccurate,
    ) ==
    OcrProviderKind::PaddleOcr,
  )
  assert_true(
    resolved_ocr_provider_kind_for_target(
      OcrProviderSelectionTarget::PdfAccurate,
    ) ==
    OcrProviderKind::PaddleOcr,
  )
  assert_true(
    ocr_provider_fallback_for_target(
      OcrProviderSelectionTarget::DirectImageAccurate,
    ) ==
    None,
  )
  assert_true(
    ocr_provider_fallback_for_target(OcrProviderSelectionTarget::PdfAccurate) ==
    None,
  )
  let paddle_request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::PaddleOcr,
    language=Some("eng"),
  )
  match run_ocr_provider(paddle_request) {
    Err(OcrProviderError::NotConfigured(msg)) =>
      assert_true(
        msg.contains("MARKITDOWN_PADDLE_OCR_CMD") &&
        msg.contains("pip install paddlepaddle paddleocr"),
      )
    Ok(_) => fail("expected Paddle provider stub to fail closed")
    Err(other) => fail("unexpected Paddle provider error: " + other.to_string())
  }
}

///|
test "paddle runtime command builder requires adapter env and passes image path language" {
  assert_eq(paddle_ocr_command_env_var(), "MARKITDOWN_PADDLE_OCR_CMD")
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::PaddleOcr,
    language=Some("eng"),
  )
  match build_paddle_ocr_command(request) {
    Err(OcrProviderError::NotConfigured(msg)) =>
      assert_true(
        msg.contains("MARKITDOWN_PADDLE_OCR_CMD") &&
        msg.contains("samples/helpers/paddle_ocr_wrapper.py"),
      )
    Ok(_) => fail("expected Paddle command builder to fail closed without env")
    Err(other) =>
      fail("unexpected Paddle command-builder error: " + other.to_string())
  }
  let built = match
    build_paddle_ocr_command_with_adapter(request, "adapter --mode ocr") {
    Ok(value) => value
    Err(err) =>
      fail("expected adapter-aware Paddle command plan: " + err.to_string())
  }
  assert_eq(built.0, "adapter")
  assert_eq(built.1[0], "--mode")
  assert_eq(built.1[1], "ocr")
  assert_eq(built.1[2], "scan.png")
  assert_eq(built.1[3], "--lang")
  assert_eq(built.1[4], "eng")

  let quoted = match
    build_paddle_ocr_command_with_adapter(
      request, "\"/tmp/paddle wrapper.py\" --mode \"ocr accurate\"",
    ) {
    Ok(value) => value
    Err(err) => fail("expected quoted Paddle command plan: " + err.to_string())
  }
  assert_eq(quoted.0, "/tmp/paddle wrapper.py")
  assert_eq(quoted.1[0], "--mode")
  assert_eq(quoted.1[1], "ocr accurate")
  assert_eq(quoted.1[2], "scan.png")
  assert_eq(quoted.1[3], "--lang")
  assert_eq(quoted.1[4], "eng")

  match build_paddle_ocr_command_with_adapter(request, "\"unterminated") {
    Err(OcrProviderError::NotConfigured(msg)) =>
      assert_true(msg.contains("unterminated quotes"))
    Ok(_) => fail("expected malformed quoted Paddle command to fail")
    Err(other) => fail("unexpected quoted-command error: " + other.to_string())
  }
}

///|
test "paddle runtime command abstraction preserves fail-closed taxonomy" {
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::PaddleOcr,
    language=Some("eng"),
  )
  let payload = "{\"provider_name\":\"paddle_ocr\",\"provider_version\":\"bridge-v1\",\"pages\":[{\"page_index\":0,\"blocks\":[{\"block_index\":0,\"lines\":[{\"line_index\":0,\"text\":\"MoonBit OCR\",\"words\":[{\"word_index\":0,\"text\":\"MoonBit\"},{\"word_index\":1,\"text\":\"OCR\"}]}]}]}]}"

  let result = match
    run_paddle_ocr_provider_with_command_with_adapter(
      request,
      "adapter --mode ocr",
      (cmd, args) => {
        if cmd != "adapter" {
          abort("unexpected Paddle adapter command: " + cmd)
        }
        if args[0] != "--mode" ||
          args[1] != "ocr" ||
          args[2] != "scan.png" ||
          args[3] != "--lang" ||
          args[4] != "eng" {
          abort("unexpected Paddle adapter argv")
        }
        Ok((0, payload, ""))
      },
    ) {
    Ok(value) => value
    Err(other) =>
      fail("expected Paddle adapter success payload: " + other.to_string())
  }
  assert_eq(result.provider_name, "paddle_ocr")
  assert_true(result.provider_version == Some("bridge-v1"))
  assert_eq(result.pages.length(), 1)
  assert_eq(result.pages[0].blocks.length(), 1)
  assert_eq(result.pages[0].blocks[0].lines.length(), 1)
  assert_eq(result.pages[0].blocks[0].lines[0].text, "MoonBit OCR")
  assert_eq(result.pages[0].blocks[0].lines[0].words.length(), 2)

  match
    run_paddle_ocr_provider_with_command_with_adapter(request, "adapter", fn(
      _cmd,
      _args,
    ) {
      Ok((0, "{\"provider_name\":\"paddle_ocr\"}", ""))
    }) {
    Err(OcrProviderError::OutputParseFailed(msg)) =>
      assert_true(msg.contains("pages"))
    Ok(_) => fail("expected malformed Paddle payload to fail parsing")
    Err(other) =>
      fail("unexpected Paddle malformed-payload error: " + other.to_string())
  }

  match
    run_paddle_ocr_provider_with_command_with_adapter(request, "adapter", fn(
      _cmd,
      _args,
    ) {
      Ok((127, "", "command not found"))
    }) {
    Err(OcrProviderError::CommandUnavailable(msg)) =>
      assert_true(
        msg.contains("command not found") &&
        msg.contains("Missing dependency: PaddleOCR bridge"),
      )
    Ok(_) => fail("expected Paddle command unavailable")
    Err(other) =>
      fail("unexpected Paddle unavailable error: " + other.to_string())
  }

  match
    run_paddle_ocr_provider_with_command_with_adapter(request, "adapter", fn(
      _cmd,
      _args,
    ) {
      Ok((2, "", "boom"))
    }) {
    Err(OcrProviderError::ExecutionFailed(msg)) =>
      assert_true(
        msg.contains("boom") &&
        msg.contains("python3 -m pip install paddlepaddle paddleocr"),
      )
    Ok(_) => fail("expected Paddle execution failed")
    Err(other) =>
      fail("unexpected Paddle execution error: " + other.to_string())
  }
}

///|
test "paddle bridge payload parser lowers json adapter output into OCR provider result" {
  let payload = "{\"provider_name\":\"paddle_ocr\",\"provider_version\":\"bridge-v1\",\"diagnostics\":[\"bridge=sample\"],\"pages\":[{\"page_index\":0,\"width\":1000,\"height\":2000,\"language\":\"eng\",\"diagnostics\":[\"page=0\"],\"blocks\":[{\"block_index\":0,\"confidence\":0.97,\"bbox\":{\"x0\":10,\"y0\":20,\"x1\":300,\"y1\":120},\"lines\":[{\"line_index\":0,\"text\":\"MoonBit OCR\",\"confidence\":0.98,\"bbox\":{\"x0\":10,\"y0\":20,\"x1\":280,\"y1\":60},\"words\":[{\"word_index\":0,\"text\":\"MoonBit\",\"confidence\":0.99,\"bbox\":{\"x0\":10,\"y0\":20,\"x1\":150,\"y1\":60}},{\"word_index\":1,\"text\":\"OCR\",\"confidence\":0.96,\"bbox\":{\"x0\":170,\"y0\":20,\"x1\":280,\"y1\":60}}]}]}]}]}"

  let result = match parse_paddle_ocr_bridge_payload(payload) {
    Ok(value) => value
    Err(err) =>
      fail("expected Paddle bridge payload to parse: " + err.to_string())
  }

  assert_eq(result.provider_name, "paddle_ocr")
  assert_true(result.provider_version == Some("bridge-v1"))
  assert_eq(result.diagnostics.length(), 1)
  assert_eq(result.diagnostics[0], "bridge=sample")
  assert_eq(result.pages.length(), 1)
  assert_eq(result.pages[0].page_index, 0)
  assert_true(result.pages[0].width == Some(1000))
  assert_true(result.pages[0].height == Some(2000))
  assert_eq(result.pages[0].diagnostics.length(), 1)
  assert_eq(result.pages[0].diagnostics[0], "page=0")
  assert_eq(result.pages[0].blocks.length(), 1)
  assert_eq(result.pages[0].blocks[0].block_index, 0)
  assert_eq(result.pages[0].blocks[0].lines.length(), 1)
  assert_eq(result.pages[0].blocks[0].lines[0].text, "MoonBit OCR")
  assert_eq(result.pages[0].blocks[0].lines[0].words.length(), 2)
  assert_eq(result.pages[0].blocks[0].lines[0].words[0].text, "MoonBit")
  assert_eq(result.pages[0].blocks[0].lines[0].words[1].text, "OCR")
}

///|
test "paddle bridge payload parser reports malformed payloads with provider taxonomy" {
  match parse_paddle_ocr_bridge_payload("") {
    Err(OcrProviderError::EmptyResult(msg)) =>
      assert_true(msg.contains("empty payload"))
    Ok(_) => fail("expected empty Paddle payload to fail")
    Err(other) => fail("unexpected empty-payload error: " + other.to_string())
  }

  match parse_paddle_ocr_bridge_payload("{\"provider_name\":\"paddle_ocr\"}") {
    Err(OcrProviderError::OutputParseFailed(msg)) =>
      assert_true(msg.contains("pages"))
    Ok(_) => fail("expected malformed Paddle payload to fail")
    Err(other) =>
      fail("unexpected malformed-payload error: " + other.to_string())
  }
}

///|
async test "paddle runtime async command abstraction remains fail closed" {
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::PaddleOcr,
    language=Some("eng"),
  )
  match
    run_paddle_ocr_provider_with_async_command(request, (_cmd, _args) => {
      Ok((0, "{}", ""))
    }) {
    Err(OcrProviderError::NotConfigured(msg)) =>
      assert_true(
        msg.contains("MARKITDOWN_PADDLE_OCR_CMD") ||
        msg.contains("output parsing is not wired"),
      )
    Ok(_) => fail("expected async Paddle adapter path to remain fail closed")
    Err(other) => fail("unexpected async Paddle error: " + other.to_string())
  }

  let payload = "{\"provider_name\":\"paddle_ocr\",\"provider_version\":\"bridge-v1\",\"pages\":[{\"page_index\":0,\"blocks\":[{\"block_index\":0,\"lines\":[{\"line_index\":0,\"text\":\"MoonBit OCR\",\"words\":[{\"word_index\":0,\"text\":\"MoonBit\"},{\"word_index\":1,\"text\":\"OCR\"}]}]}]}]}"
  match
    run_paddle_ocr_provider_with_async_command_with_adapter(
      request,
      "adapter",
      (_cmd, _args) => Ok((0, payload, "")),
    ) {
    Ok(result) => {
      assert_eq(result.provider_name, "paddle_ocr")
      assert_eq(result.pages.length(), 1)
    }
    Err(other) =>
      fail("unexpected adapter-aware async Paddle error: " + other.to_string())
  }

  match
    run_paddle_ocr_provider_with_async_command_with_adapter(
      request,
      "adapter",
      (_cmd, _args) => Ok((0, "{\"provider_name\":\"paddle_ocr\"}", "")),
    ) {
    Err(OcrProviderError::OutputParseFailed(msg)) =>
      assert_true(msg.contains("pages"))
    Ok(_) =>
      fail("expected malformed adapter-aware async Paddle payload to fail")
    Err(other) =>
      fail("unexpected adapter-aware async Paddle error: " + other.to_string())
  }
}
