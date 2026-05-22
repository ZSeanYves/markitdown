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
  assert_false(bbox_is_valid(bbox))
  assert_true(bbox.x < 0.0)
  assert_true(bbox.y < 0.0)
  assert_true(bbox.width < 0.0)
  assert_true(bbox.height < 0.0)
  assert_eq(bbox_area(bbox), -1.0)
  assert_eq(bbox_right(bbox), -1.0)
  assert_eq(bbox_bottom(bbox), -1.0)
}

///|
test "vision valid bbox helpers stay stable" {
  let bbox : VisionBBox = { x: 10.0, y: 20.0, width: 30.0, height: 40.0 }
  assert_true(bbox_is_valid(bbox))
  assert_eq(bbox_right(bbox), 40.0)
  assert_eq(bbox_bottom(bbox), 60.0)
  assert_eq(bbox_area(bbox), 1200.0)
}

///|
test "vision bbox union combines known boxes" {
  let a : VisionBBox = { x: 10.0, y: 20.0, width: 30.0, height: 10.0 }
  let b : VisionBBox = { x: 25.0, y: 15.0, width: 20.0, height: 30.0 }
  let union = bbox_union(a, b)
  assert_true(bbox_is_valid(union))
  assert_eq(union.x, 10.0)
  assert_eq(union.y, 15.0)
  assert_eq(union.width, 35.0)
  assert_eq(union.height, 30.0)
}

///|
test "vision bbox union keeps known box when other is unknown" {
  let known : VisionBBox = { x: 5.0, y: 6.0, width: 7.0, height: 8.0 }
  let union1 = bbox_union(unknown_bbox(), known)
  let union2 = bbox_union(known, unknown_bbox())
  assert_eq(union1.x, known.x)
  assert_eq(union1.y, known.y)
  assert_eq(union1.width, known.width)
  assert_eq(union1.height, known.height)
  assert_eq(union2.x, known.x)
  assert_eq(union2.y, known.y)
  assert_eq(union2.width, known.width)
  assert_eq(union2.height, known.height)
}

///|
test "vision bbox union of two unknown boxes stays unknown" {
  let union = bbox_union(unknown_bbox(), unknown_bbox())
  assert_true(is_unknown_bbox(union))
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
  assert_false(ocr_page_has_geometry(page))
  assert_false(ocr_page_has_confidence(page))
  assert_eq(ocr_page_average_confidence(page), -1.0)
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
test "vision line helpers reconstruct conservative word text" {
  let line : OcrSignalLine = {
    text: "Alpha    Beta",
    bbox: unknown_bbox(),
    confidence: -1.0,
    words: [
      { text: "Alpha", bbox: unknown_bbox(), confidence: -1.0, word_index: 0 },
      { text: "Beta", bbox: unknown_bbox(), confidence: -1.0, word_index: 1 },
    ],
    line_index: 0,
  }
  assert_eq(ocr_line_word_count(line), 2)
  assert_eq(ocr_line_text_from_words(line), "Alpha Beta")
}

///|
test "vision line text helper falls back to line text when words absent" {
  let line : OcrSignalLine = {
    text: "Alpha  Beta",
    bbox: unknown_bbox(),
    confidence: -1.0,
    words: [],
    line_index: 0,
  }
  assert_eq(ocr_line_word_count(line), 0)
  assert_eq(ocr_line_text_from_words(line), "Alpha  Beta")
}

///|
test "vision page geometry helper sees real geometry" {
  let word : OcrSignalWord = {
    text: "Alpha",
    bbox: { x: 10.0, y: 12.0, width: 20.0, height: 8.0 },
    confidence: 0.8,
    word_index: 0,
  }
  let line : OcrSignalLine = {
    text: "Alpha",
    bbox: { x: 10.0, y: 12.0, width: 20.0, height: 8.0 },
    confidence: 0.8,
    words: [word],
    line_index: 0,
  }
  let page : OcrPageModel = {
    page_index: 0,
    width: 200.0,
    height: 300.0,
    lines: [line],
    words: [word],
    provider: "future-tsv",
    source_kind: "tesseract-tsv",
    warnings: ["low dpi"],
  }
  assert_true(ocr_page_has_geometry(page))
  assert_true(ocr_page_has_confidence(page))
  assert_eq(ocr_page_average_confidence(page), 0.8)
  assert_eq(ocr_page_warning_count(page), 1)
}

///|
test "vision page average confidence ignores unknown values" {
  let words : Array[OcrSignalWord] = [
    { text: "Alpha", bbox: unknown_bbox(), confidence: -1.0, word_index: 0 },
    { text: "Beta", bbox: unknown_bbox(), confidence: 0.5, word_index: 1 },
    { text: "Gamma", bbox: unknown_bbox(), confidence: 0.9, word_index: 2 },
  ]
  let lines : Array[OcrSignalLine] = [
    {
      text: "Alpha Beta Gamma",
      bbox: unknown_bbox(),
      confidence: -1.0,
      words,
      line_index: 0,
    },
  ]
  let page : OcrPageModel = {
    page_index: 0,
    width: -1.0,
    height: -1.0,
    lines,
    words,
    provider: "future-tsv",
    source_kind: "text-only",
    warnings: [],
  }
  assert_true(ocr_page_has_confidence(page))
  assert_eq(ocr_page_average_confidence(page), 0.7)
}

///|
test "vision page average confidence falls back to line confidence" {
  let line : OcrSignalLine = {
    text: "Alpha",
    bbox: unknown_bbox(),
    confidence: 0.75,
    words: [
      { text: "Alpha", bbox: unknown_bbox(), confidence: -1.0, word_index: 0 },
    ],
    line_index: 0,
  }
  let page : OcrPageModel = {
    page_index: 0,
    width: -1.0,
    height: -1.0,
    lines: [line],
    words: line.words,
    provider: "future-hocr",
    source_kind: "hocr",
    warnings: [],
  }
  assert_true(ocr_page_has_confidence(page))
  assert_eq(ocr_page_average_confidence(page), 0.75)
}

///|
test "vision document helpers join pages predictably" {
  let page1 = make_text_only_ocr_page_model("Page One", "future-tsv")
  let page2 = make_text_only_ocr_page_model("Page Two\nLine Two", "future-tsv")
  let page2_with_warning : OcrPageModel = {
    page_index: page2.page_index,
    width: page2.width,
    height: page2.height,
    lines: page2.lines,
    words: page2.words,
    provider: page2.provider,
    source_kind: page2.source_kind,
    warnings: ["cropped"],
  }
  let doc = make_ocr_document_model([page1, page2_with_warning], "future-tsv", [
    "provider warning",
  ])
  assert_eq(ocr_document_page_count(doc), 2)
  assert_eq(ocr_document_text(doc), "Page One\n\nPage Two\nLine Two")
  assert_eq(ocr_document_warning_count(doc), 2)
}

///|
test "vision page text round trip does not perform layout recovery" {
  let page = make_text_only_ocr_page_model("A\nB\n\nC", "retired-text-only")
  assert_eq(ocr_page_text(page), "A\nB\n\nC")
}
