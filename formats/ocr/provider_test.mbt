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
  assert_eq(
    ocr_provider_selection_target_name(
      OcrProviderSelectionTarget::DirectImageBalanced,
    ),
    "direct_image_balanced",
  )
  assert_eq(ocr_provider_language_label(Some("eng")), "eng")
  assert_eq(ocr_provider_language_label(None), "none")
}
