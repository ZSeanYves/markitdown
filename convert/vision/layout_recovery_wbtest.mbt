///|
test "vision layout reading order uses geometry y then x" {
  let ordered = order_ocr_lines_for_reading({
    page_index: 0,
    width: 100.0,
    height: 100.0,
    lines: [
      make_layout_test_line(2, "Gamma", 20.0, 30.0, 30.0, 10.0, 0.8),
      make_layout_test_line(0, "Alpha", 10.0, 10.0, 30.0, 10.0, 0.9),
      make_layout_test_line(1, "Beta", 50.0, 10.0, 30.0, 10.0, 0.7),
    ],
    words: [],
    provider: "future-tsv",
    source_kind: "tesseract-tsv",
    warnings: [],
  })
  assert_eq(ordered.length(), 3)
  assert_eq(ordered[0].text, "Alpha")
  assert_eq(ordered[1].text, "Beta")
  assert_eq(ordered[2].text, "Gamma")
}

///|
test "vision layout reading order keeps line_index when geometry unknown" {
  let ordered = order_ocr_lines_for_reading({
    page_index: 0,
    width: -1.0,
    height: -1.0,
    lines: [
      make_unknown_layout_test_line(2, "Third"),
      make_unknown_layout_test_line(0, "First"),
      make_unknown_layout_test_line(1, "Second"),
    ],
    words: [],
    provider: "future-tsv",
    source_kind: "text-only",
    warnings: [],
  })
  assert_eq(ordered.length(), 3)
  assert_eq(ordered[0].text, "First")
  assert_eq(ordered[1].text, "Second")
  assert_eq(ordered[2].text, "Third")
}

///|
test "vision layout reading order uses conservative two-column order when obvious" {
  let ordered = order_ocr_lines_for_reading({
    page_index: 0,
    width: 400.0,
    height: 200.0,
    lines: [
      make_layout_test_line(0, "Left A1", 20.0, 10.0, 70.0, 12.0, 0.9),
      make_layout_test_line(1, "Right B1", 220.0, 10.0, 80.0, 12.0, 0.9),
      make_layout_test_line(2, "Left A2", 20.0, 30.0, 70.0, 12.0, 0.9),
      make_layout_test_line(3, "Right B2", 220.0, 30.0, 80.0, 12.0, 0.9),
    ],
    words: [],
    provider: "future-tsv",
    source_kind: "tesseract-tsv",
    warnings: [],
  })
  assert_eq(ordered.length(), 4)
  assert_eq(ordered[0].text, "Left A1")
  assert_eq(ordered[1].text, "Left A2")
  assert_eq(ordered[2].text, "Right B1")
  assert_eq(ordered[3].text, "Right B2")
}

///|
test "vision layout two-column warning is emitted when applied" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(0, "Left A1", 20.0, 10.0, 70.0, 12.0, 0.9),
      make_layout_test_line(1, "Right B1", 220.0, 10.0, 80.0, 12.0, 0.9),
      make_layout_test_line(2, "Left A2", 20.0, 30.0, 70.0, 12.0, 0.9),
      make_layout_test_line(3, "Right B2", 220.0, 30.0, 80.0, 12.0, 0.9),
    ]),
  )
  assert_true(layout.warnings.contains("two-column reading order applied"))
  assert_eq(layout.blocks[0].text, "Left A1 Left A2")
  assert_eq(layout.blocks[1].text, "Right B1 Right B2")
}

///|
test "vision layout skips blank lines before grouping" {
  let blocks = group_ordered_lines_into_paragraphs([
    make_layout_test_line(0, "Alpha", 10.0, 10.0, 30.0, 10.0, 0.9),
    make_layout_test_line(1, "   ", 10.0, 22.0, 30.0, 10.0, 0.9),
  ])
  assert_eq(blocks.length(), 1)
  assert_eq(blocks[0].text, "Alpha")
}

///|
test "vision layout single line becomes one paragraph block" {
  let blocks = group_ordered_lines_into_paragraphs([
    make_layout_test_line(0, "Alpha", 10.0, 10.0, 30.0, 10.0, 0.9),
  ])
  assert_eq(blocks.length(), 1)
  assert_true(blocks[0].kind == OcrLayoutBlockKind::Paragraph)
  assert_eq(blocks[0].text, "Alpha")
  assert_eq(blocks[0].line_indices.length(), 1)
  assert_true(blocks[0].reasons.contains("single-line paragraph"))
}

///|
test "vision layout merges two close lines into one paragraph" {
  let blocks = group_ordered_lines_into_paragraphs([
    make_layout_test_line(0, "Alpha", 10.0, 10.0, 30.0, 10.0, 0.8),
    make_layout_test_line(1, "Beta", 12.0, 24.0, 35.0, 10.0, 0.6),
  ])
  assert_eq(blocks.length(), 1)
  assert_eq(blocks[0].text, "Alpha Beta")
  assert_eq(blocks[0].line_indices.length(), 2)
  assert_true(blocks[0].reasons.contains("merged by vertical gap"))
}

///|
test "vision layout large vertical gap splits paragraphs" {
  let blocks = group_ordered_lines_into_paragraphs([
    make_layout_test_line(0, "Alpha", 10.0, 10.0, 30.0, 10.0, 0.8),
    make_layout_test_line(1, "Beta", 10.0, 40.0, 30.0, 10.0, 0.7),
  ])
  assert_eq(blocks.length(), 2)
  assert_eq(blocks[0].text, "Alpha")
  assert_eq(blocks[1].text, "Beta")
}

///|
test "vision layout left indent change splits paragraphs" {
  let blocks = group_ordered_lines_into_paragraphs([
    make_layout_test_line(0, "Alpha", 10.0, 10.0, 30.0, 10.0, 0.8),
    make_layout_test_line(1, "Beta", 40.5, 24.0, 30.0, 10.0, 0.7),
  ])
  assert_eq(blocks.length(), 2)
}

///|
test "vision layout paragraph bbox is union of merged lines" {
  let blocks = group_ordered_lines_into_paragraphs([
    make_layout_test_line(0, "Alpha", 10.0, 10.0, 30.0, 10.0, 0.8),
    make_layout_test_line(1, "Beta", 12.0, 24.0, 40.0, 10.0, 0.6),
  ])
  assert_eq(blocks.length(), 1)
  assert_eq(blocks[0].bbox.x, 10.0)
  assert_eq(blocks[0].bbox.y, 10.0)
  assert_eq(blocks[0].bbox.width, 42.0)
  assert_eq(blocks[0].bbox.height, 24.0)
}

///|
test "vision layout confidence average ignores unknown" {
  let blocks = group_ordered_lines_into_paragraphs([
    make_layout_test_line(0, "Alpha", 10.0, 10.0, 30.0, 10.0, -1.0),
    make_layout_test_line(1, "Beta", 10.0, 24.0, 30.0, 10.0, 0.6),
  ])
  assert_eq(blocks.length(), 1)
  assert_eq(blocks[0].confidence, 0.6)
}

///|
test "vision layout text only page conservatively splits one block per line" {
  let page = make_text_only_ocr_page_model("Alpha\nBeta", "future-tsv")
  let layout = recover_ocr_layout_page(page)
  assert_eq(layout.blocks.length(), 2)
  assert_eq(layout.blocks[0].text, "Alpha")
  assert_eq(layout.blocks[1].text, "Beta")
  assert_true(
    layout.warnings.contains(
      "missing geometry: reading order kept line_index order",
    ),
  )
  assert_true(
    layout.warnings.contains("missing geometry: conservative paragraph split"),
  )
}

///|
test "vision layout single-column geometry keeps y then x order" {
  let ordered = order_ocr_lines_for_reading({
    page_index: 0,
    width: 180.0,
    height: 200.0,
    lines: [
      make_layout_test_line(2, "Gamma", 20.0, 40.0, 70.0, 12.0, 0.9),
      make_layout_test_line(0, "Alpha", 20.0, 10.0, 70.0, 12.0, 0.9),
      make_layout_test_line(1, "Beta", 24.0, 25.0, 70.0, 12.0, 0.9),
      make_layout_test_line(3, "Delta", 22.0, 55.0, 70.0, 12.0, 0.9),
    ],
    words: [],
    provider: "future-tsv",
    source_kind: "tesseract-tsv",
    warnings: [],
  })
  assert_eq(ordered[0].text, "Alpha")
  assert_eq(ordered[1].text, "Beta")
  assert_eq(ordered[2].text, "Gamma")
  assert_eq(ordered[3].text, "Delta")
}

///|
test "vision layout obvious aligned rows become table-like candidate" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line_from_words(0, [
        make_layout_test_word(0, "Item", 10.0, 10.0, 28.0, 10.0, 0.9),
        make_layout_test_word(1, "Qty", 72.0, 10.0, 24.0, 10.0, 0.9),
      ]),
      make_layout_test_line_from_words(1, [
        make_layout_test_word(2, "Apple", 10.0, 22.0, 38.0, 10.0, 0.9),
        make_layout_test_word(3, "2", 72.0, 22.0, 8.0, 10.0, 0.9),
      ]),
      make_layout_test_line_from_words(2, [
        make_layout_test_word(4, "Banana", 10.0, 34.0, 48.0, 10.0, 0.9),
        make_layout_test_word(5, "5", 72.0, 34.0, 8.0, 10.0, 0.9),
      ]),
    ]),
  )
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::TableLike)
  assert_true(layout.blocks[0].reasons.contains("table-like rows"))
  assert_true(layout.blocks[0].reasons.contains("aligned column candidate"))
}

///|
test "vision layout table-like header row is not lifted to heading" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line_from_words(0, [
        make_layout_test_word(0, "Item", 45.0, 34.0, 60.0, 25.0, 0.72),
        make_layout_test_word(1, "Qty", 117.0, 34.0, 51.0, 32.0, 0.96),
      ]),
      make_layout_test_line_from_words(1, [
        make_layout_test_word(2, "Apple", 42.0, 84.0, 87.0, 32.0, 0.96),
        make_layout_test_word(3, "2", 140.0, 84.0, 16.0, 25.0, 0.96),
      ]),
      make_layout_test_line_from_words(2, [
        make_layout_test_word(4, "Banana", 44.0, 134.0, 114.0, 25.0, 0.94),
        make_layout_test_word(5, "5", 170.0, 134.0, 17.0, 25.0, 0.94),
      ]),
    ]),
  )
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::TableLike)
  assert_eq(layout.blocks[0].text, "Item Qty Apple 2 Banana 5")
  assert_true(
    !layout.blocks[0].reasons.contains("single-line heading candidate"),
  )
}

///|
test "vision layout table-like aligned rows do not trigger two-column order" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line_from_words(0, [
        make_layout_test_word(0, "Item", 10.0, 10.0, 28.0, 10.0, 0.9),
        make_layout_test_word(1, "Qty", 72.0, 10.0, 24.0, 10.0, 0.9),
      ]),
      make_layout_test_line_from_words(1, [
        make_layout_test_word(2, "Apple", 10.0, 22.0, 38.0, 10.0, 0.9),
        make_layout_test_word(3, "2", 72.0, 22.0, 8.0, 10.0, 0.9),
      ]),
      make_layout_test_line_from_words(2, [
        make_layout_test_word(4, "Banana", 10.0, 34.0, 48.0, 10.0, 0.9),
        make_layout_test_word(5, "5", 72.0, 34.0, 8.0, 10.0, 0.9),
      ]),
      make_layout_test_line_from_words(3, [
        make_layout_test_word(6, "Cherry", 10.0, 46.0, 44.0, 10.0, 0.9),
        make_layout_test_word(7, "7", 72.0, 46.0, 8.0, 10.0, 0.9),
      ]),
    ]),
  )
  assert_true(!layout.warnings.contains("two-column reading order applied"))
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::TableLike)
}

///|
test "vision layout table-like preview stays plain text" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line_from_words(0, [
        make_layout_test_word(0, "Item", 10.0, 10.0, 28.0, 10.0, 0.9),
        make_layout_test_word(1, "Qty", 72.0, 10.0, 24.0, 10.0, 0.9),
      ]),
      make_layout_test_line_from_words(1, [
        make_layout_test_word(2, "Apple", 10.0, 22.0, 38.0, 10.0, 0.9),
        make_layout_test_word(3, "2", 72.0, 22.0, 8.0, 10.0, 0.9),
      ]),
      make_layout_test_line_from_words(2, [
        make_layout_test_word(4, "Banana", 10.0, 34.0, 48.0, 10.0, 0.9),
        make_layout_test_word(5, "5", 72.0, 34.0, 8.0, 10.0, 0.9),
      ]),
    ]),
  )
  let out = render_ocr_layout_page_markdown(layout)
  assert_eq(out, "Item Qty Apple 2 Banana 5\n")
  assert_true(!out.contains("|"))
}

///|
test "vision layout page with geometry recovers stable text flow" {
  let page : OcrPageModel = {
    page_index: 3,
    width: 200.0,
    height: 200.0,
    lines: [
      make_layout_test_line(2, "Gamma", 10.0, 50.0, 30.0, 10.0, 0.5),
      make_layout_test_line(0, "Alpha", 10.0, 10.0, 30.0, 10.0, 0.9),
      make_layout_test_line(1, "Beta", 12.0, 24.0, 30.0, 10.0, 0.7),
    ],
    words: [],
    provider: "future-tsv",
    source_kind: "tesseract-tsv",
    warnings: ["page geometry approximated from word boxes"],
  }
  let layout = recover_ocr_layout_page(page)
  assert_eq(layout.page_index, 3)
  assert_eq(layout.blocks.length(), 2)
  assert_eq(layout.blocks[0].text, "Alpha Beta")
  assert_eq(layout.blocks[1].text, "Gamma")
  assert_eq(ocr_layout_page_text(layout), "Alpha Beta\n\nGamma")
  assert_true(
    layout.warnings.contains("page geometry approximated from word boxes"),
  )
}

///|
test "vision layout obvious heading becomes heading" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(0, "Introduction", 10.0, 10.0, 80.0, 12.0, 0.9),
      make_layout_test_line(
        1, "This remains body text.", 10.0, 40.0, 150.0, 12.0, 0.8,
      ),
    ]),
  )
  assert_eq(layout.blocks.length(), 2)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Heading)
  assert_true(
    layout.blocks[0].reasons.contains("single-line heading candidate"),
  )
}

///|
test "vision layout normal sentence remains paragraph" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(
        0, "This is a short sentence.", 10.0, 10.0, 140.0, 12.0, 0.9,
      ),
    ]),
  )
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Paragraph)
}

///|
test "vision layout numbered heading becomes heading" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(0, "1. Introduction", 10.0, 70.0, 100.0, 12.0, 0.9),
    ]),
  )
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Heading)
  assert_true(layout.blocks[0].reasons.contains("numbered heading pattern"))
}

///|
test "vision layout two-column short lines stay paragraph" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(0, "Left A1", 20.0, 10.0, 70.0, 12.0, 0.9),
      make_layout_test_line(1, "Right B1", 220.0, 10.0, 80.0, 12.0, 0.9),
      make_layout_test_line(2, "Left A2", 20.0, 30.0, 70.0, 12.0, 0.9),
      make_layout_test_line(3, "Right B2", 220.0, 30.0, 80.0, 12.0, 0.9),
    ]),
  )
  assert_true(layout.warnings.contains("two-column reading order applied"))
  assert_eq(layout.blocks.length(), 2)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Paragraph)
  assert_true(layout.blocks[1].kind == OcrLayoutBlockKind::Paragraph)
}

///|
test "vision layout two-column numbered heading stays heading" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(0, "1. Intro", 20.0, 10.0, 70.0, 12.0, 0.9),
      make_layout_test_line(1, "2. Scope", 220.0, 10.0, 80.0, 12.0, 0.9),
      make_layout_test_line(2, "Body A", 20.0, 80.0, 70.0, 12.0, 0.9),
      make_layout_test_line(3, "Body B", 220.0, 80.0, 80.0, 12.0, 0.9),
    ]),
  )
  assert_true(layout.warnings.contains("two-column reading order applied"))
  assert_eq(layout.blocks.length(), 4)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Heading)
  assert_true(layout.blocks[1].kind == OcrLayoutBlockKind::Paragraph)
  assert_true(layout.blocks[2].kind == OcrLayoutBlockKind::Heading)
  assert_true(layout.blocks[3].kind == OcrLayoutBlockKind::Paragraph)
}

///|
test "vision layout two-column long title-like heading stays heading" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(
        0, "Vision OCR Overview", 20.0, 10.0, 120.0, 12.0, 0.9,
      ),
      make_layout_test_line(
        1, "Layout Recovery Notes", 220.0, 10.0, 140.0, 12.0, 0.9,
      ),
      make_layout_test_line(2, "Body A", 20.0, 80.0, 70.0, 12.0, 0.9),
      make_layout_test_line(3, "Body B", 220.0, 80.0, 80.0, 12.0, 0.9),
    ]),
  )
  assert_true(layout.warnings.contains("two-column reading order applied"))
  assert_eq(layout.blocks.length(), 4)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Heading)
  assert_true(layout.blocks[1].kind == OcrLayoutBlockKind::Paragraph)
  assert_true(layout.blocks[2].kind == OcrLayoutBlockKind::Heading)
  assert_true(layout.blocks[3].kind == OcrLayoutBlockKind::Paragraph)
}

///|
test "vision layout bullet line becomes list item" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(0, "- first item", 10.0, 20.0, 100.0, 12.0, 0.9),
    ]),
  )
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::ListItem)
  assert_true(layout.blocks[0].reasons.contains("list marker prefix"))
}

///|
test "vision layout numbered list line becomes list item" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(0, "1) first item", 10.0, 20.0, 120.0, 12.0, 0.9),
    ]),
  )
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::ListItem)
}

///|
test "vision layout pure page number becomes noise" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(0, "1", 80.0, 180.0, 10.0, 10.0, 0.5),
    ]),
  )
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Noise)
  assert_true(layout.blocks[0].reasons.contains("page number noise"))
}

///|
test "vision layout page of count becomes noise" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(0, "Page 1 of 3", 60.0, 180.0, 60.0, 10.0, 0.5),
    ]),
  )
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Noise)
}

///|
test "vision layout separator line becomes noise" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(0, "---", 60.0, 180.0, 20.0, 10.0, 0.5),
    ]),
  )
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Noise)
  assert_true(layout.blocks[0].reasons.contains("separator noise"))
}

///|
test "vision layout amount like line remains paragraph" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(0, "Total $12.50", 10.0, 20.0, 80.0, 12.0, 0.9),
    ]),
  )
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Paragraph)
}

///|
test "vision layout key value receipt remains paragraph" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line_from_words(0, [
        make_layout_test_word(0, "Date:", 10.0, 10.0, 28.0, 10.0, 0.9),
        make_layout_test_word(1, "2026-05-22", 72.0, 10.0, 60.0, 10.0, 0.9),
      ]),
      make_layout_test_line_from_words(1, [
        make_layout_test_word(2, "Total:", 10.0, 22.0, 32.0, 10.0, 0.9),
        make_layout_test_word(3, "123.45", 72.0, 22.0, 38.0, 10.0, 0.9),
      ]),
      make_layout_test_line_from_words(2, [
        make_layout_test_word(4, "Status:", 10.0, 34.0, 36.0, 10.0, 0.9),
        make_layout_test_word(5, "Paid", 72.0, 34.0, 24.0, 10.0, 0.9),
      ]),
    ]),
  )
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Paragraph)
}

///|
test "vision layout two-column rows stay non-table-like" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line_from_words(0, [
        make_layout_test_word(0, "Left", 20.0, 10.0, 30.0, 10.0, 0.9),
        make_layout_test_word(1, "A1", 56.0, 10.0, 16.0, 10.0, 0.9),
      ]),
      make_layout_test_line_from_words(1, [
        make_layout_test_word(2, "Right", 220.0, 10.0, 34.0, 10.0, 0.9),
        make_layout_test_word(3, "B1", 260.0, 10.0, 16.0, 10.0, 0.9),
      ]),
      make_layout_test_line_from_words(2, [
        make_layout_test_word(4, "Left", 20.0, 30.0, 30.0, 10.0, 0.9),
        make_layout_test_word(5, "A2", 56.0, 30.0, 16.0, 10.0, 0.9),
      ]),
      make_layout_test_line_from_words(6, [
        make_layout_test_word(6, "Right", 220.0, 30.0, 34.0, 10.0, 0.9),
        make_layout_test_word(7, "B2", 260.0, 30.0, 16.0, 10.0, 0.9),
      ]),
    ]),
  )
  assert_true(layout.warnings.contains("two-column reading order applied"))
  for block in layout.blocks {
    assert_true(block.kind != OcrLayoutBlockKind::TableLike)
  }
}

///|
test "vision layout two aligned lines are not table-like" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line_from_words(0, [
        make_layout_test_word(0, "Item", 10.0, 10.0, 28.0, 10.0, 0.9),
        make_layout_test_word(1, "Qty", 72.0, 10.0, 24.0, 10.0, 0.9),
      ]),
      make_layout_test_line_from_words(1, [
        make_layout_test_word(2, "Apple", 10.0, 22.0, 38.0, 10.0, 0.9),
        make_layout_test_word(3, "2", 72.0, 22.0, 8.0, 10.0, 0.9),
      ]),
    ]),
  )
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Paragraph)
}

///|
test "vision layout one line in right column is not enough for two-column order" {
  let ordered = order_ocr_lines_for_reading({
    page_index: 0,
    width: 400.0,
    height: 200.0,
    lines: [
      make_layout_test_line(0, "Left A1", 20.0, 10.0, 70.0, 12.0, 0.9),
      make_layout_test_line(1, "Right B1", 220.0, 10.0, 80.0, 12.0, 0.9),
      make_layout_test_line(2, "Left A2", 20.0, 30.0, 70.0, 12.0, 0.9),
      make_layout_test_line(3, "Left A3", 20.0, 50.0, 70.0, 12.0, 0.9),
    ],
    words: [],
    provider: "future-tsv",
    source_kind: "tesseract-tsv",
    warnings: [],
  })
  assert_eq(ordered[0].text, "Left A1")
  assert_eq(ordered[1].text, "Right B1")
  assert_eq(ordered[2].text, "Left A2")
  assert_eq(ordered[3].text, "Left A3")
}

///|
test "vision layout overlapping x clusters are not enough for two-column order" {
  let ordered = order_ocr_lines_for_reading({
    page_index: 0,
    width: 260.0,
    height: 200.0,
    lines: [
      make_layout_test_line(0, "Left A1", 20.0, 10.0, 70.0, 12.0, 0.9),
      make_layout_test_line(1, "Right B1", 72.0, 10.0, 80.0, 12.0, 0.9),
      make_layout_test_line(2, "Left A2", 22.0, 30.0, 70.0, 12.0, 0.9),
      make_layout_test_line(3, "Right B2", 74.0, 30.0, 80.0, 12.0, 0.9),
    ],
    words: [],
    provider: "future-tsv",
    source_kind: "tesseract-tsv",
    warnings: [],
  })
  assert_eq(ordered[0].text, "Left A1")
  assert_eq(ordered[1].text, "Right B1")
  assert_eq(ordered[2].text, "Left A2")
  assert_eq(ordered[3].text, "Right B2")
}

///|
test "vision layout rows without geometry are not table-like" {
  let page = make_text_only_ocr_page_model(
    "Item Qty\nApple 2\nBanana 5", "future-tsv",
  )
  let block = classify_ocr_layout_block(
    {
      kind: OcrLayoutBlockKind::Paragraph,
      text: "Item Qty Apple 2 Banana 5",
      bbox: unknown_bbox(),
      confidence: -1.0,
      line_indices: [0, 1, 2],
      reasons: ["unknown geometry: conservative split"],
    },
    page,
  )
  assert_true(block.kind == OcrLayoutBlockKind::Paragraph)
}

///|
test "vision layout date like line remains paragraph" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(0, "2024-01-01", 10.0, 20.0, 80.0, 12.0, 0.9),
    ]),
  )
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Paragraph)
}

///|
test "vision layout unknown geometry uses conservative classification" {
  let page = make_text_only_ocr_page_model("Overview\n- item", "future-tsv")
  let layout = recover_ocr_layout_page(page)
  assert_eq(layout.blocks.length(), 2)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Paragraph)
  assert_true(layout.blocks[1].kind == OcrLayoutBlockKind::ListItem)
}

///|
test "vision layout reasons stay populated after classification" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(0, "Introduction", 10.0, 10.0, 80.0, 12.0, 0.9),
    ]),
  )
  assert_eq(layout.blocks.length(), 1)
  assert_true(layout.blocks[0].reasons.length() > 0)
}

///|
test "vision layout emits no unknown kinds in conservative classification" {
  let layout = recover_ocr_layout_page(
    make_layout_test_page([
      make_layout_test_line(0, "Introduction", 10.0, 10.0, 80.0, 12.0, 0.9),
      make_layout_test_line(1, "- item", 10.0, 40.0, 80.0, 12.0, 0.9),
      make_layout_test_line(2, "Page 1", 10.0, 180.0, 40.0, 12.0, 0.9),
      make_layout_test_line(
        3, "Normal paragraph text.", 10.0, 70.0, 140.0, 12.0, 0.9,
      ),
    ]),
  )
  for block in layout.blocks {
    assert_true(
      block.kind == OcrLayoutBlockKind::Paragraph ||
      block.kind == OcrLayoutBlockKind::TableLike ||
      block.kind == OcrLayoutBlockKind::Heading ||
      block.kind == OcrLayoutBlockKind::ListItem ||
      block.kind == OcrLayoutBlockKind::Noise,
    )
  }
}

///|
fn make_layout_test_page(lines : Array[OcrSignalLine]) -> OcrPageModel {
  {
    page_index: 0,
    width: 200.0,
    height: 200.0,
    lines,
    words: [],
    provider: "future-tsv",
    source_kind: "tesseract-tsv",
    warnings: [],
  }
}

///|
fn make_layout_test_line(
  line_index : Int,
  text : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  confidence : Double,
) -> OcrSignalLine {
  { text, bbox: { x, y, width, height }, confidence, words: [], line_index }
}

///|
fn make_layout_test_word(
  word_index : Int,
  text : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  confidence : Double,
) -> OcrSignalWord {
  { text, bbox: { x, y, width, height }, confidence, word_index }
}

///|
fn make_layout_test_line_from_words(
  line_index : Int,
  words : Array[OcrSignalWord],
) -> OcrSignalLine {
  let bbox = bbox_union_from_words(words)
  let parts : Array[String] = []
  let known_confidence : Array[Double] = []
  for word in words {
    let text = word.text.trim().to_owned()
    if text != "" {
      parts.push(text)
    }
    if word.confidence >= 0.0 {
      known_confidence.push(word.confidence)
    }
  }
  let confidence = if known_confidence.length() == 0 {
    -1.0
  } else {
    let mut total = 0.0
    for value in known_confidence {
      total = total + value
    }
    total / known_confidence.length().to_double()
  }
  { text: parts.join(" "), bbox, confidence, words, line_index }
}

///|
fn bbox_union_from_words(words : Array[OcrSignalWord]) -> VisionBBox {
  let mut merged = unknown_bbox()
  for word in words {
    merged = bbox_union(merged, word.bbox)
  }
  merged
}

///|
fn make_unknown_layout_test_line(
  line_index : Int,
  text : String,
) -> OcrSignalLine {
  { text, bbox: unknown_bbox(), confidence: -1.0, words: [], line_index }
}
