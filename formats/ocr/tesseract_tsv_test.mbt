///|
fn sample_tsv_single_page() -> String {
  [
    "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
    "5\t1\t1\t1\t2\t2\t60\t40\t20\t10\t92\tWorld", "4\t1\t1\t1\t2\t0\t0\t0\t0\t0\t-1\t",
    "5\t1\t1\t1\t1\t1\t10\t20\t20\t10\t95\tHello", "5\t1\t1\t1\t2\t1\t30\t40\t20\t10\t90\tMoonBit",
  ].join("\n")
}

///|
fn sample_tsv_multi_page() -> String {
  [
    "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
    "5\t2\t1\t1\t1\t1\t5\t6\t7\t8\t88\tSecond", "5\t1\t2\t1\t1\t1\t1\t2\t3\t4\t77\tFirst",
  ].join("\n")
}

///|
test "tesseract tsv parser builds page block line word model" {
  let result = match
    parse_tesseract_tsv(sample_tsv_single_page(), language=Some("eng")) {
    Ok(value) => value
    Err(err) => fail("expected TSV parse success: " + err.to_string())
  }
  assert_eq(result.provider_name, "tesseract")
  assert_true(result.provider_version == None)
  assert_true(result.diagnostics.length() == 0)
  assert_eq(result.pages.length(), 1)
  let page = result.pages[0]
  assert_eq(page.page_index, 0)
  assert_true(page.provider is Some(_))
  let provider = page.provider.unwrap_or(make_ocr_provider_info("none"))
  assert_eq(provider.name, "tesseract")
  assert_true(provider.language == Some("eng"))
  assert_eq(page.blocks.length(), 1)
  let block = page.blocks[0]
  assert_eq(block.block_index, 1)
  assert_eq(block.lines.length(), 2)
  let first_line = block.lines[0]
  let second_line = block.lines[1]
  assert_eq(first_line.line_index, 1)
  assert_eq(first_line.text, "Hello")
  assert_eq(first_line.words.length(), 1)
  assert_eq(first_line.words[0].text, "Hello")
  assert_true(first_line.words[0].confidence == Some(95.0))
  match first_line.words[0].bbox {
    Some(box) => {
      assert_eq(box.x0, 10.0)
      assert_eq(box.y0, 20.0)
      assert_eq(box.x1, 30.0)
      assert_eq(box.y1, 30.0)
    }
    None => fail("expected bbox on first OCR word")
  }
  assert_eq(second_line.line_index, 2)
  assert_eq(second_line.text, "MoonBit World")
  assert_eq(second_line.words.length(), 2)
  assert_eq(second_line.words[0].text, "MoonBit")
  assert_eq(second_line.words[1].text, "World")
  assert_true(second_line.confidence == Some(91.0))
  assert_true(page.width == Some(80.0))
  assert_true(page.height == Some(50.0))
}

///|
test "tesseract tsv parser sorts out-of-order rows and keeps 0-based pages" {
  let pages = match parse_tesseract_tsv_pages(sample_tsv_multi_page()) {
    Ok(value) => value
    Err(err) => fail("expected TSV pages parse success: " + err.to_string())
  }
  assert_eq(pages.length(), 2)
  assert_eq(pages[0].page_index, 0)
  assert_eq(pages[1].page_index, 1)
  assert_eq(pages[0].blocks[0].block_index, 2)
  assert_eq(pages[0].blocks[0].lines[0].text, "First")
  assert_eq(pages[1].blocks[0].lines[0].text, "Second")
}

///|
test "tesseract tsv parser reports empty and malformed outputs" {
  match parse_tesseract_tsv("") {
    Err(OcrProviderError::EmptyResult(msg)) =>
      assert_true(msg.contains("empty"))
    Err(other) => fail("unexpected empty TSV error: " + other.to_string())
    Ok(_) => fail("empty TSV should fail")
  }

  match
    parse_tesseract_tsv(
      "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n",
    ) {
    Err(OcrProviderError::EmptyResult(msg)) =>
      assert_true(msg.contains("header"))
    Err(other) => fail("unexpected header-only TSV error: " + other.to_string())
    Ok(_) => fail("header-only TSV should fail")
  }

  match parse_tesseract_tsv("bad\theader") {
    Err(OcrProviderError::OutputParseFailed(msg)) =>
      assert_true(msg.contains("header"))
    Err(other) =>
      fail("unexpected malformed header error: " + other.to_string())
    Ok(_) => fail("malformed header TSV should fail")
  }
}

///|
test "tesseract tsv parser skips invalid numeric and empty text rows with diagnostics" {
  let tsv = [
    "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
    "5\t1\t1\t1\t1\t1\t10\t20\t30\t40\t91\t", "5\t1\t1\t1\t1\t2\tbad\t20\t30\t40\t91\tbroken",
    "5\t1\t1\t1\t1\t3\t11\t21\t31\t41\t93\tok", "5\t1\t1\t1\t1",
  ].join("\n")
  let result = match parse_tesseract_tsv(tsv) {
    Ok(value) => value
    Err(err) =>
      fail("expected TSV parse success with diagnostics: " + err.to_string())
  }
  assert_eq(result.pages.length(), 1)
  let diagnostics = result.diagnostics.join("\n")
  assert_true(diagnostics.contains("skipped_empty_text_rows=1"))
  assert_true(diagnostics.contains("skipped_invalid_numeric_rows=1"))
  assert_true(diagnostics.contains("skipped_ragged_rows=1"))
  assert_eq(result.pages[0].blocks[0].lines[0].text, "ok")
}

///|
test "tesseract provider shell remains fail-closed even when TSV parser exists" {
  let request = make_ocr_provider_request(
    "scan.png",
    OcrProviderKind::Tesseract,
    language=Some("eng"),
  )
  match run_tesseract_provider(request) {
    Err(OcrProviderError::NotConfigured(msg)) => {
      assert_true(msg.contains("not configured"))
      assert_true(msg.contains("language=eng"))
    }
    Err(other) => fail("unexpected provider shell error: " + other.to_string())
    Ok(_) => fail("provider shell should remain fail-closed")
  }
}
