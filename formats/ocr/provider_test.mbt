///|

///|
fn ocr_test_tmp_root() -> String {
  ".tmp/tests/ocr_provider"
}

///|
fn recreate_clean_dir(path : String) -> Unit raise {
  @therm.recreate_clean_dir(path)
}

///|
fn cleanup_temp_dir(path : String) -> Unit {
  @therm.cleanup_temp_dir(path)
}

///|
fn provider_test_ensure_dir_tree(path : String) -> Unit raise {
  @therm.ensure_dir_tree(path)
}

///|
fn provider_test_write_utf8_text(path : String, text : String) -> Unit raise {
  @therm.write_utf8_text(path, text)
}

///|
fn provider_test_read_utf8_text(path : String) -> String {
  @therm.read_utf8_text(path)
}

///|
fn provider_test_with_env_var(
  name : String,
  value : String,
  body : () -> Unit raise,
) -> Unit raise {
  @therm.with_env_var(name, value, body)
}

///|
fn provider_test_with_unset_env_var(
  name : String,
  body : () -> Unit raise,
) -> Unit raise {
  @therm.with_unset_env_var(name, body)
}

///|
fn ocr_provider_test_repo_local_runtime_python_path() -> String {
  @therm.repo_local_runtime_python_path()
}

///|
fn chmod_plus_x(path : String) -> Unit raise {
  @therm.chmod_plus_x(path)
}

///|
fn with_repo_local_runtime_python_stub(body : () -> Unit raise) -> Unit raise {
  @therm.with_repo_local_runtime_python_stub(body)
}

///|
fn with_repo_local_runtime_python_hidden(body : () -> Unit raise) -> Unit raise {
  @therm.with_repo_local_runtime_python_hidden(body)
}

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
  assert_true(
    tesseract_ocr_install_hint().contains(
      "./samples/env/install_ocr_balance_deps.sh",
    ),
  )
  assert_true(
    tesseract_ocr_install_hint().contains(
      "Direct image OCR and Tesseract-backed fallback routes",
    ),
  )
  assert_true(
    paddle_ocr_install_hint().contains("Missing dependency: PaddleOCR wrapper"),
  )
  assert_true(paddle_ocr_install_hint().contains("MARKITDOWN_PADDLE_OCR_CMD"))
  assert_true(
    paddle_ocr_install_hint().contains(
      "./samples/env/install_ocr_pdf_accurate_deps.sh",
    ),
  )
  assert_true(
    paddle_ocr_install_hint().contains("source ./env/accurate-ocr-pdf.env.sh"),
  )
  assert_eq(
    @core.dependency_diagnostic_status_name(
      tesseract_ocr_dependency_diagnostic().status,
    ),
    "missing",
  )
  assert_eq(tesseract_ocr_dependency_diagnostic().kind, "tesseract_ocr")
  assert_eq(paddle_ocr_dependency_diagnostic().kind, "paddle_ocr_wrapper")
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
    Some((OcrProviderKind::PaddleOcr, OcrProviderKind::Tesseract)),
  )
  assert_true(
    ocr_provider_fallback_for_target(OcrProviderSelectionTarget::PdfAccurate) ==
    None,
  )
}

///|
test "paddle runtime command builder defaults to repo-managed runtime" {
  assert_eq(paddle_ocr_command_env_var(), "MARKITDOWN_PADDLE_OCR_CMD")
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::PaddleOcr,
    language=Some("eng"),
  )
  with_repo_local_runtime_python_stub(fn() raise {
    provider_test_with_unset_env_var("MARKITDOWN_RUNTIME_PYTHON", fn() raise {
      provider_test_with_unset_env_var(paddle_ocr_command_env_var(), fn() raise {
        let autodetected = match build_paddle_ocr_command(request) {
          Ok(value) => value
          Err(err) =>
            fail("expected repo-local Paddle command plan: " + err.to_string())
        }
        assert_eq(
          autodetected.0,
          ocr_provider_test_repo_local_runtime_python_path(),
        )
        assert_eq(autodetected.1[0], "samples/env/ocr/paddle_ocr_wrapper.py")
        assert_eq(autodetected.1[1], "--batch-json")
        assert_true(autodetected.1[2].contains("/request.json"))
        assert_eq(autodetected.1[3], "--result-json")
        assert_true(autodetected.1[4].contains("/result.json"))
        let request_json = provider_test_read_utf8_text(autodetected.1[2])
        assert_true(request_json.contains("\"provider\":\"paddle_ocr\""))
        assert_true(request_json.contains("\"version\":\"v2\""))
        assert_true(request_json.contains("\"image_path\":\"scan.png\""))
        assert_true(request_json.contains("\"language\":\"eng\""))
      })
    })
  })
  let built = match
    build_paddle_ocr_command_with_wrapper(request, "wrapper --mode ocr") {
    Ok(value) => value
    Err(err) =>
      fail("expected wrapper-aware Paddle command plan: " + err.to_string())
  }
  assert_eq(built.0, "wrapper")
  assert_eq(built.1[0], "--mode")
  assert_eq(built.1[1], "ocr")
  assert_eq(built.1[2], "--batch-json")
  assert_true(built.1[3].contains("/request.json"))
  assert_eq(built.1[4], "--result-json")
  assert_true(built.1[5].contains("/result.json"))
  let built_request_json = provider_test_read_utf8_text(built.1[3])
  assert_true(built_request_json.contains("\"image_path\":\"scan.png\""))
  assert_true(built_request_json.contains("\"language\":\"eng\""))

  let quoted = match
    build_paddle_ocr_command_with_wrapper(
      request, "\"/tmp/paddle wrapper.py\" --mode \"ocr accurate\"",
    ) {
    Ok(value) => value
    Err(err) => fail("expected quoted Paddle command plan: " + err.to_string())
  }
  assert_eq(quoted.0, "/tmp/paddle wrapper.py")
  assert_eq(quoted.1[0], "--mode")
  assert_eq(quoted.1[1], "ocr accurate")
  assert_eq(quoted.1[2], "--batch-json")
  assert_true(quoted.1[3].contains("/request.json"))
  assert_eq(quoted.1[4], "--result-json")
  assert_true(quoted.1[5].contains("/result.json"))

  match build_paddle_ocr_command_with_wrapper(request, "\"unterminated") {
    Err(OcrProviderError::NotConfigured(msg)) =>
      assert_true(msg.contains("unterminated quotes"))
    Ok(_) => fail("expected malformed quoted Paddle command to fail")
    Err(other) => fail("unexpected quoted-command error: " + other.to_string())
  }
}

///|
test "paddle runtime repo-managed runtime beats MARKITDOWN_RUNTIME_PYTHON and MARKITDOWN_PADDLE_OCR_CMD" {
  let root = ocr_test_tmp_root() + "/runtime_python_override"
  recreate_clean_dir(root) catch {
    e => fail(e.to_string())
  }
  defer cleanup_temp_dir(root)
  let fake_python_dir = root + "/python bin"
  provider_test_ensure_dir_tree(fake_python_dir) catch {
    e => fail(e.to_string())
  }
  let fake_python = fake_python_dir + "/python3"
  provider_test_write_utf8_text(fake_python, "#!/bin/sh\n") catch {
    e => fail(e.to_string())
  }
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::PaddleOcr,
    language=Some("eng"),
  )
  with_repo_local_runtime_python_stub(fn() raise {
    provider_test_with_env_var("MARKITDOWN_RUNTIME_PYTHON", fake_python, fn() raise {
      provider_test_with_env_var(
        paddle_ocr_command_env_var(),
        "python3 wrapper.py",
        fn() raise {
          assert_true(paddle_ocr_runtime_available())
          let built = match build_paddle_ocr_command(request) {
            Ok(value) => value
            Err(err) =>
              fail("expected repo-managed Paddle plan: " + err.to_string())
          }
          assert_eq(built.0, ocr_provider_test_repo_local_runtime_python_path())
          assert_eq(built.1[0], "samples/env/ocr/paddle_ocr_wrapper.py")
          assert_eq(built.1[1], "--batch-json")
          assert_true(built.1[2].contains("/request.json"))
          assert_eq(built.1[3], "--result-json")
          assert_true(built.1[4].contains("/result.json"))
        },
      )
    })
  })
}

///|
test "paddle runtime falls back to MARKITDOWN_RUNTIME_PYTHON when repo-managed runtime is unavailable" {
  let root = ocr_test_tmp_root() + "/runtime_python_fallback"
  recreate_clean_dir(root) catch {
    e => fail(e.to_string())
  }
  defer cleanup_temp_dir(root)
  let fake_python_dir = root + "/python bin"
  provider_test_ensure_dir_tree(fake_python_dir) catch {
    e => fail(e.to_string())
  }
  let fake_python = fake_python_dir + "/python3"
  provider_test_write_utf8_text(fake_python, "#!/bin/sh\nexit 0\n") catch {
    e => fail(e.to_string())
  }
  chmod_plus_x(fake_python) catch {
    e => fail(e.to_string())
  }
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::PaddleOcr,
    language=Some("eng"),
  )
  with_repo_local_runtime_python_hidden(fn() raise {
    provider_test_with_env_var("MARKITDOWN_RUNTIME_PYTHON", fake_python, fn() raise {
      provider_test_with_unset_env_var(paddle_ocr_command_env_var(), fn() raise {
        assert_true(paddle_ocr_runtime_available())
        let built = match build_paddle_ocr_command(request) {
          Ok(value) => value
          Err(err) =>
            fail("expected runtime python fallback plan: " + err.to_string())
        }
        assert_eq(built.0, fake_python)
        assert_eq(built.1[0], "samples/env/ocr/paddle_ocr_wrapper.py")
        assert_eq(built.1[1], "--batch-json")
        assert_true(built.1[2].contains("/request.json"))
        assert_eq(built.1[3], "--result-json")
        assert_true(built.1[4].contains("/result.json"))
      })
    })
  })
}

///|
test "paddle runtime fails closed without repo-managed runtime or explicit overrides" {
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::PaddleOcr,
    language=Some("eng"),
  )
  with_repo_local_runtime_python_hidden(fn() raise {
    provider_test_with_unset_env_var("MARKITDOWN_RUNTIME_PYTHON", fn() raise {
      provider_test_with_unset_env_var(paddle_ocr_command_env_var(), fn() raise {
        match build_paddle_ocr_command(request) {
          Err(OcrProviderError::NotConfigured(msg)) =>
            assert_true(
              msg.contains("MARKITDOWN_PADDLE_OCR_CMD") &&
              msg.contains("./samples/env/install_ocr_pdf_accurate_deps.sh"),
            )
          Ok(_) =>
            fail(
              "expected Paddle command builder to fail closed without runtime discovery",
            )
          Err(other) =>
            fail(
              "unexpected Paddle command-builder error: " + other.to_string(),
            )
        }
      })
    })
  })
}

///|
test "paddle runtime command abstraction preserves fail-closed taxonomy" {
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::PaddleOcr,
    language=Some("eng"),
  )
  let payload = "{\n" +
    "  \"provider_name\": \"paddle_ocr\",\n" +
    "  \"provider_version\": \"wrapper-v1\",\n" +
    "  \"jobs\": [\n" +
    "    {\n" +
    "      \"job_id\": \"job-0\",\n" +
    "      \"status\": \"ok\",\n" +
    "      \"error_kind\": null,\n" +
    "      \"error_message\": null,\n" +
    "      \"pages\": [\n" +
    "        {\n" +
    "          \"page_index\": 0,\n" +
    "          \"blocks\": [\n" +
    "            {\n" +
    "              \"block_index\": 0,\n" +
    "              \"lines\": [\n" +
    "                {\n" +
    "                  \"line_index\": 0,\n" +
    "                  \"text\": \"MoonBit OCR\",\n" +
    "                  \"words\": [\n" +
    "                    {\"word_index\": 0, \"text\": \"MoonBit\"},\n" +
    "                    {\"word_index\": 1, \"text\": \"OCR\"}\n" +
    "                  ]\n" +
    "                }\n" +
    "              ]\n" +
    "            }\n" +
    "          ]\n" +
    "        }\n" +
    "      ]\n" +
    "    }\n" +
    "  ]\n" +
    "}\n"

  let result = match
    run_paddle_ocr_provider_with_command_with_wrapper(
      request,
      "wrapper --mode ocr",
      (cmd, args) => {
        if cmd != "wrapper" {
          abort("unexpected Paddle wrapper command: " + cmd)
        }
        if args[0] != "--mode" ||
          args[1] != "ocr" ||
          args[2] != "--batch-json" ||
          args[4] != "--result-json" {
          abort("unexpected Paddle wrapper argv")
        }
        provider_test_write_utf8_text(args[5], payload) catch {
          e => abort("failed to write result json: " + e.to_string())
        }
        Ok((0, payload, ""))
      },
    ) {
    Ok(value) => value
    Err(other) =>
      fail("expected Paddle wrapper success payload: " + other.to_string())
  }
  assert_eq(result.provider_name, "paddle_ocr")
  assert_true(result.provider_version == Some("wrapper-v1"))
  assert_eq(result.pages.length(), 1)
  assert_eq(result.jobs.length(), 1)
  assert_eq(result.jobs[0].image_path, "scan.png")
  assert_eq(result.pages[0].blocks.length(), 1)
  assert_eq(result.pages[0].blocks[0].lines.length(), 1)
  assert_eq(result.pages[0].blocks[0].lines[0].text, "MoonBit OCR")
  assert_eq(result.pages[0].blocks[0].lines[0].words.length(), 2)

  match
    run_paddle_ocr_provider_with_command_with_wrapper(request, "wrapper", fn(
      _cmd,
      args,
    ) {
      provider_test_write_utf8_text(
        args[3],
        "{\"provider_name\":\"paddle_ocr\"}",
      ) catch {
        e => abort("failed to write malformed result json: " + e.to_string())
      }
      Ok((0, "", ""))
    }) {
    Err(OcrProviderError::OutputParseFailed(msg)) =>
      assert_true(msg.contains("jobs"))
    Ok(_) => fail("expected malformed Paddle payload to fail parsing")
    Err(other) =>
      fail("unexpected Paddle malformed-payload error: " + other.to_string())
  }

  match
    run_paddle_ocr_provider_with_command_with_wrapper(request, "wrapper", fn(
      _cmd,
      _args,
    ) {
      Ok((127, "", "command not found"))
    }) {
    Err(OcrProviderError::CommandUnavailable(msg)) =>
      assert_true(
        msg.contains("command not found") &&
        msg.contains("Missing dependency: PaddleOCR wrapper"),
      )
    Ok(_) => fail("expected Paddle command unavailable")
    Err(other) =>
      fail("unexpected Paddle unavailable error: " + other.to_string())
  }

  match
    run_paddle_ocr_provider_with_command_with_wrapper(request, "wrapper", fn(
      _cmd,
      _args,
    ) {
      Ok((2, "", "boom"))
    }) {
    Err(OcrProviderError::ExecutionFailed(msg)) =>
      assert_true(
        msg.contains("boom") &&
        msg.contains("./samples/env/install_ocr_pdf_accurate_deps.sh"),
      )
    Ok(_) => fail("expected Paddle execution failed")
    Err(other) =>
      fail("unexpected Paddle execution error: " + other.to_string())
  }
}

///|
test "paddle wrapper payload parser lowers json wrapper output into OCR provider result" {
  let payload = "{\n" +
    "  \"provider_name\": \"paddle_ocr\",\n" +
    "  \"provider_version\": \"wrapper-v1\",\n" +
    "  \"diagnostics\": [\"wrapper=sample\"],\n" +
    "  \"jobs\": [\n" +
    "    {\n" +
    "      \"job_id\": \"job-0\",\n" +
    "      \"status\": \"ok\",\n" +
    "      \"error_kind\": null,\n" +
    "      \"error_message\": null,\n" +
    "      \"pages\": [\n" +
    "        {\n" +
    "          \"page_index\": 0,\n" +
    "          \"width\": 1000,\n" +
    "          \"height\": 2000,\n" +
    "          \"language\": \"eng\",\n" +
    "          \"diagnostics\": [\"page=0\"],\n" +
    "          \"blocks\": [\n" +
    "            {\n" +
    "              \"block_index\": 0,\n" +
    "              \"confidence\": 0.97,\n" +
    "              \"bbox\": {\"x0\": 10, \"y0\": 20, \"x1\": 300, \"y1\": 120},\n" +
    "              \"lines\": [\n" +
    "                {\n" +
    "                  \"line_index\": 0,\n" +
    "                  \"text\": \"MoonBit OCR\",\n" +
    "                  \"confidence\": 0.98,\n" +
    "                  \"bbox\": {\"x0\": 10, \"y0\": 20, \"x1\": 280, \"y1\": 60},\n" +
    "                  \"words\": [\n" +
    "                    {\n" +
    "                      \"word_index\": 0,\n" +
    "                      \"text\": \"MoonBit\",\n" +
    "                      \"confidence\": 0.99,\n" +
    "                      \"bbox\": {\"x0\": 10, \"y0\": 20, \"x1\": 150, \"y1\": 60}\n" +
    "                    },\n" +
    "                    {\n" +
    "                      \"word_index\": 1,\n" +
    "                      \"text\": \"OCR\",\n" +
    "                      \"confidence\": 0.96,\n" +
    "                      \"bbox\": {\"x0\": 170, \"y0\": 20, \"x1\": 280, \"y1\": 60}\n" +
    "                    }\n" +
    "                  ]\n" +
    "                }\n" +
    "              ]\n" +
    "            }\n" +
    "          ]\n" +
    "        }\n" +
    "      ]\n" +
    "    }\n" +
    "  ]\n" +
    "}\n"
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::PaddleOcr,
    language=Some("eng"),
  )

  let result = match parse_paddle_ocr_wrapper_payload(payload, request) {
    Ok(value) => value
    Err(err) =>
      fail("expected Paddle wrapper payload to parse: " + err.to_string())
  }

  assert_eq(result.provider_name, "paddle_ocr")
  assert_true(result.provider_version == Some("wrapper-v1"))
  assert_eq(result.diagnostics.length(), 1)
  assert_eq(result.diagnostics[0], "wrapper=sample")
  assert_eq(result.pages.length(), 1)
  assert_eq(result.jobs.length(), 1)
  assert_eq(result.jobs[0].status, "ok")
  assert_eq(result.jobs[0].image_path, "scan.png")
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
test "paddle wrapper payload parser reports malformed payloads with provider taxonomy" {
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::PaddleOcr,
    language=Some("eng"),
  )
  match parse_paddle_ocr_wrapper_payload("", request) {
    Err(OcrProviderError::EmptyResult(msg)) =>
      assert_true(msg.contains("empty payload"))
    Ok(_) => fail("expected empty Paddle payload to fail")
    Err(other) => fail("unexpected empty-payload error: " + other.to_string())
  }

  match
    parse_paddle_ocr_wrapper_payload(
      "{\"provider_name\":\"paddle_ocr\"}", request,
    ) {
    Err(OcrProviderError::OutputParseFailed(msg)) =>
      assert_true(msg.contains("jobs"))
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
  if paddle_ocr_runtime_available() {
    match
      run_paddle_ocr_provider_with_async_command(request, (_cmd, _args) => {
        Ok((0, "{}", ""))
      }) {
      Err(OcrProviderError::OutputParseFailed(msg)) =>
        assert_true(msg.contains("readable result JSON"))
      Ok(_) => fail("expected async Paddle malformed payload to fail closed")
      Err(other) => fail("unexpected async Paddle error: " + other.to_string())
    }
  } else {
    match
      run_paddle_ocr_provider_with_async_command(request, (_cmd, _args) => {
        Ok((0, "{}", ""))
      }) {
      Err(OcrProviderError::NotConfigured(msg)) =>
        assert_true(msg.contains("MARKITDOWN_PADDLE_OCR_CMD"))
      Ok(_) =>
        fail("expected async Paddle runtime without wrapper to fail closed")
      Err(other) => fail("unexpected async Paddle error: " + other.to_string())
    }
  }

  let payload = "{\n" +
    "  \"provider_name\": \"paddle_ocr\",\n" +
    "  \"provider_version\": \"wrapper-v1\",\n" +
    "  \"jobs\": [\n" +
    "    {\n" +
    "      \"job_id\": \"job-0\",\n" +
    "      \"status\": \"ok\",\n" +
    "      \"error_kind\": null,\n" +
    "      \"error_message\": null,\n" +
    "      \"pages\": [\n" +
    "        {\n" +
    "          \"page_index\": 0,\n" +
    "          \"blocks\": [\n" +
    "            {\n" +
    "              \"block_index\": 0,\n" +
    "              \"lines\": [\n" +
    "                {\n" +
    "                  \"line_index\": 0,\n" +
    "                  \"text\": \"MoonBit OCR\",\n" +
    "                  \"words\": [\n" +
    "                    {\"word_index\": 0, \"text\": \"MoonBit\"},\n" +
    "                    {\"word_index\": 1, \"text\": \"OCR\"}\n" +
    "                  ]\n" +
    "                }\n" +
    "              ]\n" +
    "            }\n" +
    "          ]\n" +
    "        }\n" +
    "      ]\n" +
    "    }\n" +
    "  ]\n" +
    "}\n"
  match
    run_paddle_ocr_provider_with_async_command_with_wrapper(
      request,
      "wrapper",
      (_cmd, args) => {
        provider_test_write_utf8_text(args[3], payload) catch {
          e => abort("failed to write async result json: " + e.to_string())
        }
        Ok((0, "", ""))
      },
    ) {
    Ok(result) => {
      assert_eq(result.provider_name, "paddle_ocr")
      assert_eq(result.pages.length(), 1)
    }
    Err(other) =>
      fail("unexpected wrapper-aware async Paddle error: " + other.to_string())
  }

  match
    run_paddle_ocr_provider_with_async_command_with_wrapper(
      request,
      "wrapper",
      (_cmd, args) => {
        provider_test_write_utf8_text(
          args[3],
          "{\"provider_name\":\"paddle_ocr\"}",
        ) catch {
          e =>
            abort(
              "failed to write async malformed result json: " + e.to_string(),
            )
        }
        Ok((0, "", ""))
      },
    ) {
    Err(OcrProviderError::OutputParseFailed(msg)) =>
      assert_true(msg.contains("jobs"))
    Ok(_) =>
      fail("expected malformed wrapper-aware async Paddle payload to fail")
    Err(other) =>
      fail("unexpected wrapper-aware async Paddle error: " + other.to_string())
  }
}
