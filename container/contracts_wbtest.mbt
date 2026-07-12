///|
test "container child dispatch keeps OCR exclusive to top-level pure images" {
  assert_false(
    container_supports_inner_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
    ),
  )
  assert_true(container_supports_inner_format(@input.DetectedFormat::Pdf))
  assert_false(container_supported_inner_formats().contains("png"))
  assert_true(container_unsupported_inner_formats().contains("png"))
  assert_true(
    container_dispatch_guardrails().contains(
      "embedded images remain assets and never enter OCR child dispatch",
    ),
  )
}
