///|

///|
test "tesseract provider default shell remains explicit fail-closed not configured" {
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::Tesseract,
    language=Some("eng"),
  )
  let result = run_tesseract_provider(request)
  match result {
    Err(OcrProviderError::NotConfigured(msg)) => {
      assert_true(msg.contains("Tesseract OCR provider is not configured"))
      assert_true(msg.contains("language=eng"))
    }
    Err(other) => fail("unexpected provider shell error: " + other.to_string())
    Ok(_) => fail("tesseract provider shell should stay fail closed")
  }
}

///|
test "tesseract command builder keeps explicit-only argv shape and language passthrough" {
  let request = make_ocr_provider_request(
    "samples/fixtures/ocr/tiny_ocr_sample.png",
    OcrProviderKind::Tesseract,
    language=Some("eng"),
  )
  let plan = build_tesseract_tsv_command(request)
  assert_eq(plan.0, "tesseract")
  assert_eq(plan.1[0], "samples/fixtures/ocr/tiny_ocr_sample.png")
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
