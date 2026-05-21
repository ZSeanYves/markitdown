///|
test "ocr cli help includes rebuild boundary" {
  let help = new_ocr_cli_parser().gen_help_message(
    ["markitdown-mb-ocr", "ocr"],
    {},
  )
  assert_contains(help, "Path to OCR candidate input")
  assert_contains(help, "current build returns a rebuild notice")
}

///|
test "ocr rebuild message stays stable" {
  assert_eq(
    ocr_rebuild_message(),
    "OCR is being rebuilt around OCRPageModel; current OCR provider execution is not wired in this build.",
  )
}

///|
fn assert_contains(haystack : String, needle : String) -> Unit raise {
  if !haystack.contains(needle) {
    fail("expected text to contain: " + needle + "\nactual:\n" + haystack)
  }
}
