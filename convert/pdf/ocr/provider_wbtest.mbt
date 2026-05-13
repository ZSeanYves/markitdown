///|
test "ocr provider noop info is stable" {
  let info = noop_ocr_provider_info()
  assert_eq(info.name, "noop")
  assert_true(info.kind == OcrProviderKind::Noop)
  assert_true(info.available)
  assert_true(!info.probed)
}

///|
test "ocr provider descriptors include known external candidates" {
  let infos = list_known_ocr_providers()
  let names : Array[String] = []
  for info in infos {
    names.push(info.name)
  }
  assert_true(array_contains_string(names, "tesseract-cli"))
  assert_true(array_contains_string(names, "ocrmypdf-cli"))
  assert_true(array_contains_string(names, "paddleocr"))
}

///|
test "ocr provider result structs remain constructible for future providers" {
  let page : OcrPageResult = {
    page_index: 0,
    text: "sample",
    confidence: Some(0.9),
    language: Some("en"),
    warnings: [],
  }
  let doc : OcrDocumentResult = {
    provider: noop_ocr_provider_info(),
    pages: [page],
    warnings: [],
  }
  assert_eq(doc.pages.length(), 1)
  assert_eq(doc.pages[0].text, "sample")
}

///|
test "ocr provider list stays lazy by default" {
  let infos = list_known_ocr_providers()
  for info in infos {
    if info.name == "noop" {
      continue
    }
    assert_true(!info.probed)
    assert_true(!info.available)
    assert_true(info.unavailable_reason != None)
  }
}

///|
test "ocr provider noop recognize returns not implemented" {
  let result = recognize_pdf_with_ocr_provider(
    "noop",
    "sample.pdf",
    default_ocr_options(),
  )
  match result {
    Ok(_) => fail("expected noop OCR provider to fail closed")
    Err(err) => assert_true(err.kind == OcrProviderErrorKind::NotImplemented)
  }
}

///|
async test "ocr provider explicit noop probe is local and stable" {
  let probed = probe_known_ocr_provider("noop")
  match probed {
    Some(info) => {
      assert_true(info.probed)
      assert_true(info.available)
      assert_eq(info.name, "noop")
    }
    None => fail("expected noop provider probe result")
  }
}

///|
fn array_contains_string(xs : Array[String], needle : String) -> Bool {
  for x in xs {
    if x == needle {
      return true
    }
  }
  false
}
