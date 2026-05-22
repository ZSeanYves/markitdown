///|
test "vision tesseract tsv parses standard one line row" {
  let tsv = tsv_header() +
    "\n" +
    "5\t1\t1\t1\t1\t1\t10\t20\t30\t40\t95\tMoonBit"
  let page = expect_tsv_page(parse_tesseract_tsv_page(tsv))
  assert_eq(page.provider, "tesseract-tsv")
  assert_eq(page.source_kind, "tesseract-tsv")
  assert_eq(page.page_index, 0)
  assert_eq(ocr_page_line_count(page), 1)
  assert_eq(ocr_page_word_count(page), 1)
  assert_eq(ocr_page_text(page), "MoonBit")
  assert_eq(page.words[0].bbox.x, 10.0)
  assert_eq(page.words[0].bbox.y, 20.0)
  assert_eq(page.words[0].bbox.width, 30.0)
  assert_eq(page.words[0].bbox.height, 40.0)
  assert_eq(page.lines[0].confidence, 95.0)
}

///|
test "vision tesseract tsv groups multiple words into one line" {
  let tsv = tsv_header() +
    "\n" +
    "5\t1\t1\t1\t1\t2\t50\t20\t10\t10\t90\tBeta\n" +
    "5\t1\t1\t1\t1\t1\t10\t20\t30\t10\t80\tAlpha"
  let page = expect_tsv_page(parse_tesseract_tsv_page(tsv))
  assert_eq(ocr_page_line_count(page), 1)
  assert_eq(ocr_page_word_count(page), 2)
  assert_eq(page.lines[0].text, "Alpha Beta")
  assert_eq(page.words[0].text, "Alpha")
  assert_eq(page.words[1].text, "Beta")
}

///|
test "vision tesseract tsv groups separate line numbers separately" {
  let tsv = tsv_header() +
    "\n" +
    "5\t1\t1\t1\t1\t1\t10\t20\t30\t10\t80\tAlpha\n" +
    "5\t1\t1\t1\t2\t1\t10\t40\t30\t10\t70\tBeta"
  let page = expect_tsv_page(parse_tesseract_tsv_page(tsv))
  assert_eq(ocr_page_line_count(page), 2)
  assert_eq(page.lines[0].text, "Alpha")
  assert_eq(page.lines[1].text, "Beta")
}

///|
test "vision tesseract tsv orders words by word_num" {
  let tsv = tsv_header() +
    "\n" +
    "5\t1\t1\t1\t1\t3\t90\t20\t10\t10\t90\tThree\n" +
    "5\t1\t1\t1\t1\t1\t10\t20\t10\t10\t90\tOne\n" +
    "5\t1\t1\t1\t1\t2\t50\t20\t10\t10\t90\tTwo"
  let page = expect_tsv_page(parse_tesseract_tsv_page(tsv))
  assert_eq(page.lines[0].text, "One Two Three")
  assert_eq(page.words[0].word_index, 1)
  assert_eq(page.words[1].word_index, 2)
  assert_eq(page.words[2].word_index, 0)
}

///|
test "vision tesseract tsv computes line bbox union" {
  let tsv = tsv_header() +
    "\n" +
    "5\t1\t1\t1\t1\t1\t10\t20\t30\t10\t90\tAlpha\n" +
    "5\t1\t1\t1\t1\t2\t50\t18\t15\t20\t70\tBeta"
  let page = expect_tsv_page(parse_tesseract_tsv_page(tsv))
  let line = page.lines[0]
  assert_eq(line.bbox.x, 10.0)
  assert_eq(line.bbox.y, 18.0)
  assert_eq(line.bbox.width, 55.0)
  assert_eq(line.bbox.height, 20.0)
}

///|
test "vision tesseract tsv computes average known confidence per line" {
  let tsv = tsv_header() +
    "\n" +
    "5\t1\t1\t1\t1\t1\t10\t20\t30\t10\t80\tAlpha\n" +
    "5\t1\t1\t1\t1\t2\t50\t20\t15\t10\t60\tBeta"
  let page = expect_tsv_page(parse_tesseract_tsv_page(tsv))
  assert_eq(page.lines[0].confidence, 70.0)
  assert_eq(ocr_page_average_confidence(page), 70.0)
}

///|
test "vision tesseract tsv ignores empty text word rows" {
  let tsv = tsv_header() +
    "\n" +
    "5\t1\t1\t1\t1\t1\t10\t20\t30\t10\t80\t \n" +
    "5\t1\t1\t1\t1\t2\t50\t20\t15\t10\t60\tBeta"
  let page = expect_tsv_page(parse_tesseract_tsv_page(tsv))
  assert_eq(ocr_page_word_count(page), 1)
  assert_eq(ocr_page_text(page), "Beta")
}

///|
test "vision tesseract tsv treats conf -1 as unknown" {
  let tsv = tsv_header() + "\n" + "5\t1\t1\t1\t1\t1\t10\t20\t30\t10\t-1\tAlpha"
  let page = expect_tsv_page(parse_tesseract_tsv_page(tsv))
  assert_eq(page.words[0].confidence, -1.0)
  assert_eq(page.lines[0].confidence, -1.0)
  assert_false(ocr_page_has_confidence(page))
}

///|
test "vision tesseract tsv treats invalid conf as unknown with no hard failure" {
  let tsv = tsv_header() + "\n" + "5\t1\t1\t1\t1\t1\t10\t20\t30\t10\tbad\tAlpha"
  let page = expect_tsv_page(parse_tesseract_tsv_page(tsv))
  assert_eq(page.words[0].confidence, -1.0)
  assert_eq(page.lines[0].confidence, -1.0)
}

///|
test "vision tesseract tsv missing header column returns error" {
  let tsv = "level\tpage_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\n" +
    "5\t1\t1\t1\t10\t20\t30\t10\t90"
  match parse_tesseract_tsv_page(tsv) {
    Ok(_) => fail("expected missing text header to fail")
    Err(err) => {
      assert_true(err.kind == MissingRequiredColumn)
      assert_eq(err.line, 1)
      assert_true(err.message.contains("text"))
    }
  }
}

///|
test "vision tesseract tsv invalid bbox row is skipped with warning" {
  let tsv = tsv_header() +
    "\n" +
    "5\t1\t1\t1\t1\t1\t10\t20\t-30\t10\t80\tAlpha\n" +
    "5\t1\t1\t1\t1\t2\t50\t20\t15\t10\t60\tBeta"
  let page = expect_tsv_page(parse_tesseract_tsv_page(tsv))
  assert_eq(ocr_page_word_count(page), 1)
  assert_eq(page.words[0].text, "Beta")
  assert_true(page.warnings[0].contains("invalid bbox"))
}

///|
test "vision tesseract tsv approximates page geometry from words" {
  let tsv = tsv_header() +
    "\n" +
    "5\t1\t1\t1\t1\t1\t10\t20\t30\t10\t80\tAlpha\n" +
    "5\t1\t1\t1\t1\t2\t50\t25\t15\t12\t60\tBeta"
  let page = expect_tsv_page(parse_tesseract_tsv_page(tsv))
  assert_eq(page.width, 65.0)
  assert_eq(page.height, 37.0)
  assert_true(
    page.warnings.contains("page geometry approximated from word boxes"),
  )
}

///|
test "vision tesseract tsv empty input yields empty page" {
  let page = expect_tsv_page(parse_tesseract_tsv_page(""))
  assert_eq(ocr_page_line_count(page), 0)
  assert_eq(ocr_page_word_count(page), 0)
  assert_eq(page.source_kind, "tesseract-tsv")
}

///|
test "vision tesseract tsv header only yields empty page" {
  let page = expect_tsv_page(parse_tesseract_tsv_page(tsv_header()))
  assert_eq(ocr_page_line_count(page), 0)
  assert_eq(ocr_page_word_count(page), 0)
  assert_eq(page.source_kind, "tesseract-tsv")
}

///|
test "vision tesseract tsv keeps first page and warns on multi page" {
  let tsv = tsv_header() +
    "\n" +
    "5\t1\t1\t1\t1\t1\t10\t20\t30\t10\t80\tAlpha\n" +
    "5\t2\t1\t1\t1\t1\t10\t40\t30\t10\t70\tBeta"
  let page = expect_tsv_page(parse_tesseract_tsv_page(tsv))
  assert_eq(ocr_page_word_count(page), 1)
  assert_eq(ocr_page_text(page), "Alpha")
  assert_true(
    page.warnings.any(fn(w) { w.contains("multiple pages detected") }),
  )
}

///|
fn expect_tsv_page(
  result : Result[OcrPageModel, TesseractTsvParseError],
) -> OcrPageModel {
  match result {
    Ok(page) => page
    Err(_) => panic()
  }
}

///|
fn tsv_header() -> String {
  "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext"
}
