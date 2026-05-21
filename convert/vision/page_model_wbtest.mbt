///|
test "vision empty ocr page model is stable" {
  let page = make_empty_ocr_page_model(2, "stub-provider", "text-only")
  assert_eq(page.page_index, 2)
  assert_eq(page.provider, "stub-provider")
  assert_eq(page.source_kind, "text-only")
  assert_eq(page.lines.length(), 0)
  assert_eq(page.words.length(), 0)
  assert_eq(page.warnings.length(), 0)
  assert_true(is_unknown_bbox(unknown_bbox()))
}

///|
test "vision unknown bbox sentinel stays negative" {
  let bbox = unknown_bbox()
  assert_true(is_unknown_bbox(bbox))
  assert_true(bbox.x < 0.0)
  assert_true(bbox.y < 0.0)
  assert_true(bbox.width < 0.0)
  assert_true(bbox.height < 0.0)
}

///|
test "vision text only single line model" {
  let page = make_text_only_ocr_page_model("MoonBit OCR", "retired-text-only")
  assert_eq(ocr_page_line_count(page), 1)
  assert_eq(ocr_page_word_count(page), 2)
  assert_eq(ocr_page_text(page), "MoonBit OCR")
  assert_eq(page.provider, "retired-text-only")
  assert_eq(page.source_kind, "text-only")
}

///|
test "vision text only multiple lines preserve line text" {
  let page = make_text_only_ocr_page_model(
    "MoonBit OCR\nSample 123\nLine Three", "retired-text-only",
  )
  assert_eq(ocr_page_line_count(page), 3)
  assert_eq(ocr_page_text(page), "MoonBit OCR\nSample 123\nLine Three")
}

///|
test "vision text only word count splits conservative spaces" {
  let page = make_text_only_ocr_page_model(
    "MoonBit   OCR\nSample   123", "retired-text-only",
  )
  assert_eq(ocr_page_word_count(page), 4)
}

///|
test "vision text only lines keep unknown bbox and confidence" {
  let page = make_text_only_ocr_page_model("Alpha\nBeta", "retired-text-only")
  assert_eq(page.lines.length(), 2)
  for line in page.lines {
    assert_true(is_unknown_bbox(line.bbox))
    assert_eq(line.confidence, -1.0)
  }
  for word in page.words {
    assert_true(is_unknown_bbox(word.bbox))
    assert_eq(word.confidence, -1.0)
  }
}

///|
test "vision text only empty text yields empty page" {
  let page = make_text_only_ocr_page_model(" \r\n", "retired-text-only")
  assert_eq(ocr_page_line_count(page), 0)
  assert_eq(ocr_page_word_count(page), 0)
  assert_eq(ocr_page_text(page), "")
}

///|
test "vision text only provider and source kind are preserved" {
  let page = make_text_only_ocr_page_model("Alpha", "future-tsv")
  assert_eq(page.provider, "future-tsv")
  assert_eq(page.source_kind, "text-only")
}

///|
test "vision page text round trip does not perform layout recovery" {
  let page = make_text_only_ocr_page_model("A\nB\n\nC", "retired-text-only")
  assert_eq(ocr_page_text(page), "A\nB\n\nC")
}
