///|
test "vision line resegmentation keeps normal sentence as one line" {
  let lines = resegment_ocr_words_into_lines([
    make_resegment_test_word(2, "sentence", 110.0, 20.0, 52.0, 12.0, 0.7),
    make_resegment_test_word(0, "MoonBit", 10.0, 20.0, 46.0, 12.0, 0.9),
    make_resegment_test_word(1, "keeps", 64.0, 20.0, 34.0, 12.0, 0.8),
  ])
  assert_eq(lines.length(), 1)
  assert_eq(lines[0].text, "MoonBit keeps sentence")
}

///|
test "vision line resegmentation splits same y groups with large gap" {
  let lines = resegment_ocr_words_into_lines([
    make_resegment_test_word(0, "Left", 10.0, 20.0, 26.0, 12.0, 0.9),
    make_resegment_test_word(1, "one", 42.0, 20.0, 22.0, 12.0, 0.8),
    make_resegment_test_word(2, "Right", 340.0, 20.0, 32.0, 12.0, 0.7),
    make_resegment_test_word(3, "one", 378.0, 20.0, 22.0, 12.0, 0.6),
  ])
  assert_eq(lines.length(), 2)
  assert_eq(lines[0].text, "Left one")
  assert_eq(lines[1].text, "Right one")
}

///|
test "vision line resegmentation preserves x order within segment" {
  let lines = resegment_ocr_words_into_lines([
    make_resegment_test_word(2, "Gamma", 90.0, 20.0, 32.0, 12.0, 0.7),
    make_resegment_test_word(0, "Alpha", 10.0, 20.0, 32.0, 12.0, 0.9),
    make_resegment_test_word(1, "Beta", 50.0, 20.0, 28.0, 12.0, 0.8),
  ])
  assert_eq(lines.length(), 1)
  assert_eq(lines[0].text, "Alpha Beta Gamma")
}

///|
test "vision line resegmentation averages known confidence only" {
  let lines = resegment_ocr_words_into_lines([
    make_resegment_test_word(0, "Alpha", 10.0, 20.0, 32.0, 12.0, -1.0),
    make_resegment_test_word(1, "Beta", 50.0, 20.0, 28.0, 12.0, 0.8),
    make_resegment_test_word(2, "Gamma", 86.0, 20.0, 32.0, 12.0, 0.6),
  ])
  assert_eq(lines.length(), 1)
  assert_eq(lines[0].confidence, 0.7)
}

///|
test "vision line resegmentation computes bbox union per line" {
  let lines = resegment_ocr_words_into_lines([
    make_resegment_test_word(0, "Alpha", 10.0, 18.0, 32.0, 12.0, 0.9),
    make_resegment_test_word(1, "Beta", 52.0, 20.0, 28.0, 16.0, 0.8),
  ])
  assert_eq(lines.length(), 1)
  assert_eq(lines[0].bbox.x, 10.0)
  assert_eq(lines[0].bbox.y, 18.0)
  assert_eq(lines[0].bbox.width, 70.0)
  assert_eq(lines[0].bbox.height, 18.0)
}

///|
test "vision line resegmentation missing word geometry skips with warning" {
  let original = make_resegment_page_with_lines(
    [
      make_resegment_test_line(
        0,
        "Left column line one Right column line one",
        10.0,
        20.0,
        300.0,
        12.0,
        0.8,
        [],
      ),
    ],
    [{ text: "Broken", bbox: unknown_bbox(), confidence: 0.9, word_index: 0 }],
  )
  let resegmented = resegment_ocr_page_lines_from_words(original)
  assert_eq(resegmented.lines.length(), original.lines.length())
  assert_eq(resegmented.lines[0].text, original.lines[0].text)
  assert_true(
    resegmented.warnings.contains(
      "line resegmentation skipped: missing word geometry",
    ),
  )
}

///|
test "vision line resegmentation with no words returns stable page" {
  let page = make_empty_ocr_page_model(0, "future-tsv", "tesseract-tsv")
  let resegmented = resegment_ocr_page_lines_from_words(page)
  assert_eq(resegmented.lines.length(), 0)
  assert_eq(resegmented.words.length(), 0)
  assert_eq(resegmented.warnings.length(), 0)
}

///|
test "vision line resegmentation does not mutate original page lines" {
  let page = make_same_y_two_column_page()
  let resegmented = resegment_ocr_page_lines_from_words(page)
  assert_eq(page.lines.length(), 3)
  assert_eq(resegmented.lines.length(), 6)
  assert_eq(page.lines[0].text, "Left column line one Right column line one")
  assert_eq(resegmented.lines[0].text, "Left column line one")
}

///|
test "vision tesseract parser default behavior stays unchanged before explicit resegmentation" {
  let page = expect_resegment_tsv_page(
    parse_tesseract_tsv_page(same_y_two_column_tsv()),
  )
  assert_eq(page.lines.length(), 3)
  assert_eq(page.lines[0].text, "Left column line one Right column line one")
  let resegmented = resegment_ocr_page_lines_from_words(page)
  assert_eq(resegmented.lines.length(), 6)
  assert_eq(resegmented.lines[0].text, "Left column line one")
  assert_eq(resegmented.lines[1].text, "Right column line one")
}

///|
test "vision line resegmentation can unlock two-column layout recovery" {
  let page = resegment_ocr_page_lines_from_words(make_same_y_two_column_page())
  let layout = recover_ocr_layout_page(page)
  assert_true(layout.warnings.contains("two-column reading order applied"))
  assert_eq(layout.blocks.length(), 2)
  assert_eq(
    layout.blocks[0].text,
    "Left column line one Left column line two Left column line three",
  )
  assert_eq(
    layout.blocks[1].text,
    "Right column line one Right column line two Right column line three",
  )
  let preview = render_ocr_layout_page_markdown(layout)
  assert_true(!preview.contains("# Left"))
  assert_true(!preview.contains("# Right"))
  assert_eq(
    preview, "Left column line one Left column line two Left column line three\n\nRight column line one Right column line two Right column line three\n",
  )
}

///|
test "vision line resegmentation keeps short same-y column text out of headings" {
  let page = resegment_ocr_page_lines_from_words(
    make_short_same_y_two_column_page(),
  )
  let layout = recover_ocr_layout_page(page)
  let preview = render_ocr_layout_page_markdown(layout)
  assert_eq(layout.blocks.length(), 2)
  assert_true(layout.blocks[0].kind == OcrLayoutBlockKind::Paragraph)
  assert_true(layout.blocks[1].kind == OcrLayoutBlockKind::Paragraph)
  assert_true(layout.blocks[0].kind != OcrLayoutBlockKind::TableLike)
  assert_true(layout.blocks[1].kind != OcrLayoutBlockKind::TableLike)
  assert_true(!preview.contains("# Left A1"))
  assert_true(!preview.contains("# Right B1"))
  assert_eq(preview, "Left A1 Left A2\n\nRight B1 Right B2\n")
}

///|
fn make_same_y_two_column_page() -> OcrPageModel {
  let words = same_y_two_column_words()
  {
    page_index: 0,
    width: 700.0,
    height: 220.0,
    lines: [
      make_resegment_test_line(
        0,
        "Left column line one Right column line one",
        10.0,
        20.0,
        500.0,
        12.0,
        0.8,
        copy_words_range(words, 0, 8),
      ),
      make_resegment_test_line(
        1,
        "Left column line two Right column line two",
        10.0,
        44.0,
        500.0,
        12.0,
        0.8,
        copy_words_range(words, 8, 16),
      ),
      make_resegment_test_line(
        2,
        "Left column line three Right column line three",
        10.0,
        68.0,
        520.0,
        12.0,
        0.8,
        copy_words_range(words, 16, 24),
      ),
    ],
    words,
    provider: "tesseract-tsv",
    source_kind: "tesseract-tsv",
    warnings: [],
  }
}

///|
fn same_y_two_column_words() -> Array[OcrSignalWord] {
  [
    make_resegment_test_word(0, "Left", 10.0, 20.0, 24.0, 12.0, 0.9),
    make_resegment_test_word(1, "column", 40.0, 20.0, 40.0, 12.0, 0.9),
    make_resegment_test_word(2, "line", 86.0, 20.0, 24.0, 12.0, 0.8),
    make_resegment_test_word(3, "one", 116.0, 20.0, 22.0, 12.0, 0.8),
    make_resegment_test_word(4, "Right", 360.0, 20.0, 30.0, 12.0, 0.9),
    make_resegment_test_word(5, "column", 396.0, 20.0, 40.0, 12.0, 0.9),
    make_resegment_test_word(6, "line", 442.0, 20.0, 24.0, 12.0, 0.8),
    make_resegment_test_word(7, "one", 472.0, 20.0, 22.0, 12.0, 0.8),
    make_resegment_test_word(8, "Left", 10.0, 44.0, 24.0, 12.0, 0.9),
    make_resegment_test_word(9, "column", 40.0, 44.0, 40.0, 12.0, 0.9),
    make_resegment_test_word(10, "line", 86.0, 44.0, 24.0, 12.0, 0.8),
    make_resegment_test_word(11, "two", 116.0, 44.0, 22.0, 12.0, 0.8),
    make_resegment_test_word(12, "Right", 360.0, 44.0, 30.0, 12.0, 0.9),
    make_resegment_test_word(13, "column", 396.0, 44.0, 40.0, 12.0, 0.9),
    make_resegment_test_word(14, "line", 442.0, 44.0, 24.0, 12.0, 0.8),
    make_resegment_test_word(15, "two", 472.0, 44.0, 22.0, 12.0, 0.8),
    make_resegment_test_word(16, "Left", 10.0, 68.0, 24.0, 12.0, 0.9),
    make_resegment_test_word(17, "column", 40.0, 68.0, 40.0, 12.0, 0.9),
    make_resegment_test_word(18, "line", 86.0, 68.0, 24.0, 12.0, 0.8),
    make_resegment_test_word(19, "three", 116.0, 68.0, 32.0, 12.0, 0.8),
    make_resegment_test_word(20, "Right", 360.0, 68.0, 30.0, 12.0, 0.9),
    make_resegment_test_word(21, "column", 396.0, 68.0, 40.0, 12.0, 0.9),
    make_resegment_test_word(22, "line", 442.0, 68.0, 24.0, 12.0, 0.8),
    make_resegment_test_word(23, "three", 472.0, 68.0, 32.0, 12.0, 0.8),
  ]
}

///|
fn same_y_two_column_tsv() -> String {
  same_y_two_column_tsv_header() +
  "\n" +
  "5\t1\t1\t1\t1\t1\t10\t20\t24\t12\t90\tLeft\n" +
  "5\t1\t1\t1\t1\t2\t40\t20\t40\t12\t90\tcolumn\n" +
  "5\t1\t1\t1\t1\t3\t86\t20\t24\t12\t80\tline\n" +
  "5\t1\t1\t1\t1\t4\t116\t20\t22\t12\t80\tone\n" +
  "5\t1\t1\t1\t1\t5\t360\t20\t30\t12\t90\tRight\n" +
  "5\t1\t1\t1\t1\t6\t396\t20\t40\t12\t90\tcolumn\n" +
  "5\t1\t1\t1\t1\t7\t442\t20\t24\t12\t80\tline\n" +
  "5\t1\t1\t1\t1\t8\t472\t20\t22\t12\t80\tone\n" +
  "5\t1\t1\t1\t2\t1\t10\t50\t24\t12\t90\tLeft\n" +
  "5\t1\t1\t1\t2\t2\t40\t50\t40\t12\t90\tcolumn\n" +
  "5\t1\t1\t1\t2\t3\t86\t50\t24\t12\t80\tline\n" +
  "5\t1\t1\t1\t2\t4\t116\t50\t22\t12\t80\ttwo\n" +
  "5\t1\t1\t1\t2\t5\t360\t50\t30\t12\t90\tRight\n" +
  "5\t1\t1\t1\t2\t6\t396\t50\t40\t12\t90\tcolumn\n" +
  "5\t1\t1\t1\t2\t7\t442\t50\t24\t12\t80\tline\n" +
  "5\t1\t1\t1\t2\t8\t472\t50\t22\t12\t80\ttwo\n" +
  "5\t1\t1\t1\t3\t1\t10\t80\t24\t12\t90\tLeft\n" +
  "5\t1\t1\t1\t3\t2\t40\t80\t40\t12\t90\tcolumn\n" +
  "5\t1\t1\t1\t3\t3\t86\t80\t24\t12\t80\tline\n" +
  "5\t1\t1\t1\t3\t4\t116\t80\t32\t12\t80\tthree\n" +
  "5\t1\t1\t1\t3\t5\t360\t80\t30\t12\t90\tRight\n" +
  "5\t1\t1\t1\t3\t6\t396\t80\t40\t12\t90\tcolumn\n" +
  "5\t1\t1\t1\t3\t7\t442\t80\t24\t12\t80\tline\n" +
  "5\t1\t1\t1\t3\t8\t472\t80\t32\t12\t80\tthree"
}

///|
fn make_short_same_y_two_column_page() -> OcrPageModel {
  let words = short_same_y_two_column_words()
  {
    page_index: 0,
    width: 460.0,
    height: 120.0,
    lines: [
      make_resegment_test_line(
        0,
        "Left A1 Right B1",
        10.0,
        20.0,
        320.0,
        12.0,
        0.8,
        copy_words_range(words, 0, 4),
      ),
      make_resegment_test_line(
        1,
        "Left A2 Right B2",
        10.0,
        44.0,
        320.0,
        12.0,
        0.8,
        copy_words_range(words, 4, 8),
      ),
    ],
    words,
    provider: "tesseract-tsv",
    source_kind: "tesseract-tsv",
    warnings: [],
  }
}

///|
fn short_same_y_two_column_words() -> Array[OcrSignalWord] {
  [
    make_resegment_test_word(0, "Left", 10.0, 20.0, 24.0, 12.0, 0.9),
    make_resegment_test_word(1, "A1", 40.0, 20.0, 18.0, 12.0, 0.9),
    make_resegment_test_word(2, "Right", 220.0, 20.0, 30.0, 12.0, 0.9),
    make_resegment_test_word(3, "B1", 256.0, 20.0, 18.0, 12.0, 0.9),
    make_resegment_test_word(4, "Left", 10.0, 44.0, 24.0, 12.0, 0.9),
    make_resegment_test_word(5, "A2", 40.0, 44.0, 18.0, 12.0, 0.9),
    make_resegment_test_word(6, "Right", 220.0, 44.0, 30.0, 12.0, 0.9),
    make_resegment_test_word(7, "B2", 256.0, 44.0, 18.0, 12.0, 0.9),
  ]
}

///|
fn expect_resegment_tsv_page(
  result : Result[OcrPageModel, TesseractTsvParseError],
) -> OcrPageModel {
  match result {
    Ok(page) => page
    Err(_) => panic()
  }
}

///|
fn same_y_two_column_tsv_header() -> String {
  "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext"
}

///|
fn make_resegment_page_with_lines(
  lines : Array[OcrSignalLine],
  words : Array[OcrSignalWord],
) -> OcrPageModel {
  {
    page_index: 0,
    width: 700.0,
    height: 220.0,
    lines,
    words,
    provider: "tesseract-tsv",
    source_kind: "tesseract-tsv",
    warnings: [],
  }
}

///|
fn make_resegment_test_line(
  line_index : Int,
  text : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  confidence : Double,
  words : Array[OcrSignalWord],
) -> OcrSignalLine {
  { text, bbox: { x, y, width, height }, confidence, words, line_index }
}

///|
fn make_resegment_test_word(
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
fn copy_words_range(
  words : Array[OcrSignalWord],
  start : Int,
  stop : Int,
) -> Array[OcrSignalWord] {
  let out : Array[OcrSignalWord] = []
  for i in start..<stop {
    out.push(words[i])
  }
  out
}
