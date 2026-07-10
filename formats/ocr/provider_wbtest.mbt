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
