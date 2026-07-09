///|

///|
fn with_env_var(
  name : String,
  value : String,
  body : () -> Unit raise,
) -> Unit raise {
  @therm.with_env_var(name, value, body)
}

///|
fn with_managed_command_record(
  name : String,
  value : String?,
  body : () -> Unit raise,
) -> Unit raise {
  @therm.with_managed_command_record(name, value, body)
}

///|
test "tesseract command builder keeps argv shape and language passthrough" {
  assert_eq(tesseract_command_env_var(), "MARKITDOWN_TESSERACT_BIN")
  let request = make_ocr_provider_request(
    "samples/fixtures/contracts/ocr/ocr_tiny_png.png",
    OcrProviderKind::Tesseract,
    language=Some("eng"),
  )
  let plan = build_tesseract_tsv_command(request)
  assert_true(plan.0 != "")
  assert_eq(plan.1[0], "samples/fixtures/contracts/ocr/ocr_tiny_png.png")
  assert_eq(plan.1[1], "stdout")
  assert_eq(plan.1[2], "--oem")
  assert_eq(plan.1[3], "1")
  assert_eq(plan.1[4], "--psm")
  assert_eq(plan.1[5], "6")
  assert_eq(plan.1[6], "-l")
  assert_eq(plan.1[7], "eng")
  assert_eq(plan.1[8], "tsv")
}

///|
test "tesseract runtime prefers repo-managed record over MARKITDOWN_TESSERACT_BIN" {
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::Tesseract,
    language=Some("eng"),
  )
  with_managed_command_record("tesseract", Some("/bin/sh"), fn() raise {
    with_env_var(tesseract_command_env_var(), "/bin/echo", fn() raise {
      let result = run_tesseract_provider_with_command(request, fn(cmd, _args) {
        if cmd != "/bin/sh" {
          abort("expected repo-managed tesseract command, got: " + cmd)
        }
        Ok(
          (
            0,
            [
              "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
              "5\t1\t1\t1\t1\t1\t10\t20\t20\t10\t95\tMoonBit",
            ].join("\n"),
            "",
          ),
        )
      })
      match result {
        Ok(parsed) => {
          assert_true(
            parsed.diagnostics.contains("tesseract_command_source=repo_managed"),
          )
          assert_true(parsed.diagnostics.contains("tesseract_command=/bin/sh"))
        }
        Err(err) =>
          fail("expected repo-managed tesseract success: " + err.to_string())
      }
    })
  })
}

///|
test "tesseract runtime ignores invalid repo-managed record and falls back to MARKITDOWN_TESSERACT_BIN" {
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::Tesseract,
    language=Some("eng"),
  )
  with_managed_command_record(
    "tesseract",
    Some("/definitely/missing/tesseract"),
    fn() raise {
      with_env_var(tesseract_command_env_var(), "/bin/echo", fn() raise {
        let result = run_tesseract_provider_with_command(request, fn(
          cmd,
          _args,
        ) {
          if cmd != "/bin/echo" {
            abort("expected env-var tesseract command, got: " + cmd)
          }
          Ok(
            (
              0,
              [
                "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
                "5\t1\t1\t1\t1\t1\t10\t20\t20\t10\t95\tMoonBit",
              ].join("\n"),
              "",
            ),
          )
        })
        match result {
          Ok(parsed) => {
            assert_true(
              parsed.diagnostics.contains("tesseract_command_source=env_var"),
            )
            assert_true(
              parsed.diagnostics.contains("tesseract_command=/bin/echo"),
            )
          }
          Err(err) => fail("expected env tesseract success: " + err.to_string())
        }
      })
    },
  )
}

///|
test "tesseract provider command abstraction maps success and provider taxonomy without local tesseract" {
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::Tesseract,
    language=Some("eng"),
  )
  let success = run_tesseract_provider_with_command(request, fn(_cmd, _args) {
    Ok(
      (
        0,
        [
          "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
          "5\t1\t1\t1\t1\t1\t10\t20\t20\t10\t95\tMoonBit", "5\t1\t1\t1\t1\t2\t35\t20\t20\t10\t94\tOCR",
        ].join("\n"),
        "",
      ),
    )
  })
  match success {
    Ok(result) => {
      assert_eq(result.provider_name, "tesseract")
      assert_eq(result.pages.length(), 1)
      assert_eq(result.pages[0].blocks[0].lines[0].text, "MoonBit OCR")
    }
    Err(err) => fail("expected fake provider success: " + err.to_string())
  }

  match
    run_tesseract_provider_with_command(request, fn(_cmd, _args) {
      Err(OcrProviderError::CommandUnavailable("missing"))
    }) {
    Err(OcrProviderError::CommandUnavailable(msg)) =>
      assert_true(msg.contains("missing"))
    Ok(_) => fail("expected command unavailable")
    Err(other) => fail("unexpected error kind: " + other.to_string())
  }

  match
    run_tesseract_provider_with_command(request, fn(_cmd, _args) {
      Ok((3, "", "boom"))
    }) {
    Err(OcrProviderError::ExecutionFailed(msg)) =>
      assert_true(msg.contains("boom"))
    Ok(_) => fail("expected execution failed")
    Err(other) => fail("unexpected error kind: " + other.to_string())
  }

  match
    run_tesseract_provider_with_command(request, fn(_cmd, _args) {
      Ok((0, "bad\theader", ""))
    }) {
    Err(OcrProviderError::OutputParseFailed(msg)) =>
      assert_true(msg.contains("header"))
    Ok(_) => fail("expected parse failure")
    Err(other) => fail("unexpected error kind: " + other.to_string())
  }

  match
    run_tesseract_provider_with_command(request, fn(_cmd, _args) {
      Ok((0, "", ""))
    }) {
    Err(OcrProviderError::EmptyResult(msg)) =>
      assert_true(msg.contains("empty"))
    Ok(_) => fail("expected empty result")
    Err(other) => fail("unexpected error kind: " + other.to_string())
  }
}

///|
async test "tesseract async provider command abstraction maps success and provider taxonomy" {
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::Tesseract,
    language=Some("eng"),
  )
  let success = run_tesseract_provider_with_async_command(request, (_cmd, _args) => {
    Ok(
      (
        0,
        [
          "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
          "5\t1\t1\t1\t1\t1\t10\t20\t20\t10\t95\tMoonBit", "5\t1\t1\t1\t1\t2\t35\t20\t20\t10\t94\tOCR",
        ].join("\n"),
        "",
      ),
    )
  })
  match success {
    Ok(result) => {
      assert_eq(result.provider_name, "tesseract")
      assert_eq(result.pages.length(), 1)
      assert_eq(result.pages[0].blocks[0].lines[0].text, "MoonBit OCR")
    }
    Err(err) => fail("expected fake async provider success: " + err.to_string())
  }

  match
    run_tesseract_provider_with_async_command(request, (_cmd, _args) => {
      Err(OcrProviderError::CommandUnavailable("missing"))
    }) {
    Err(OcrProviderError::CommandUnavailable(msg)) =>
      assert_true(msg.contains("missing"))
    Ok(_) => fail("expected async command unavailable")
    Err(other) => fail("unexpected error kind: " + other.to_string())
  }
}
