///|
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
async fn open_raw_pdf(path : String) -> @raw.RawPdfDocumentExtract {
  let resolved = resolve_sample_path(path)
  match @raw.extract_raw_document_with_mbtpdf(resolved) {
    Ok(raw) => raw
    Err(e) => fail("extract_raw_document_with_mbtpdf failed: " + e.to_string())
  }
}

///|
async fn open_pdf_model(path : String) -> @model.PdfDocumentModel {
  let resolved = resolve_sample_path(path)
  match @api.extract_document_model(resolved, @api.default_pdf_core_config()) {
    Ok(doc) => doc
    Err(e) => fail("extract_document_model failed: " + e.to_string())
  }
}

///|
/// 断言 raw 层最小可用。
fn assert_raw_readable(raw : @raw.RawPdfDocumentExtract) -> Unit raise {
  if raw.page_count <= 0 {
    fail("page_count should be > 0")
  }

  if raw.pages.length() == 0 {
    fail("pages should not be empty")
  }

  for page in raw.pages {
    if page.page_index < 0 {
      fail("page_index should be >= 0")
    }
    if page.text_ops.is_empty() {
      fail(
        "text_ops should not be empty for page: " + page.page_index.to_string(),
      )
    }
  }
}

///|
/// 断言 chars 层最小可用。
fn assert_chars_readable(doc_chars : @text.PdfDocumentChars) -> Unit raise {
  if doc_chars.pages.is_empty() {
    fail("doc_chars.pages should not be empty")
  }

  for page in doc_chars.pages {
    if page.chars.is_empty() {
      fail(
        "page chars should not be empty for page: " +
        page.page_index.to_string(),
      )
    }
  }
}

///|
/// 断言 spans 层最小可用。
fn assert_spans_readable(doc_spans : @text.PdfDocumentSpans) -> Unit raise {
  if doc_spans.pages.is_empty() {
    fail("doc_spans.pages should not be empty")
  }

  for page in doc_spans.pages {
    if page.spans.is_empty() {
      fail(
        "page spans should not be empty for page: " +
        page.page_index.to_string(),
      )
    }
  }
}

///|
/// 断言 lines 层最小可用。
fn assert_lines_readable(doc_lines : @text.PdfDocumentLines) -> Unit raise {
  if doc_lines.pages.is_empty() {
    fail("doc_lines.pages should not be empty")
  }

  for page in doc_lines.pages {
    if page.lines.is_empty() {
      fail(
        "page lines should not be empty for page: " +
        page.page_index.to_string(),
      )
    }
  }
}

///|
/// 断言 blocks 层最小可用。
fn assert_blocks_readable(doc_blocks : @text.PdfDocumentBlocks) -> Unit raise {
  if doc_blocks.pages.is_empty() {
    fail("doc_blocks.pages should not be empty")
  }

  for page in doc_blocks.pages {
    if page.blocks.is_empty() {
      fail(
        "page blocks should not be empty for page: " +
        page.page_index.to_string(),
      )
    }
  }
}

///|
/// 断言最终 document model 最小可用。
fn assert_model_readable(doc : @model.PdfDocumentModel) -> Unit raise {
  if doc.page_count <= 0 {
    fail("document page_count should be > 0")
  }

  if doc.pages.is_empty() {
    fail("document pages should not be empty")
  }

  for page in doc.pages {
    if page.text_blocks.is_empty() {
      fail(
        "page text_blocks should not be empty for page: " +
        page.page_index.to_string(),
      )
    }
  }
}

///|
fn assert_valid_rect(rect : @model.PdfRect, label : String) -> Unit raise {
  if !@model.is_rect_valid(rect) {
    fail(label + " rect should be valid")
  }
  if @model.rect_width(rect) <= 0.0 {
    fail(label + " rect width should be > 0")
  }
  if @model.rect_height(rect) <= 0.0 {
    fail(label + " rect height should be > 0")
  }
}

///|
fn page_image_count(page : @model.PdfPageModel) -> Int {
  page.images.length()
}

///|
fn page_inline_image_count(page : @model.PdfPageModel) -> Int {
  let mut total = 0
  for image in page.images {
    if image.inline_image {
      total = total + 1
    }
  }
  total
}

///|
fn assert_page_image_count_at_least(
  page : @model.PdfPageModel,
  expected_min : Int,
  label : String,
) -> Unit raise {
  let actual = page_image_count(page)
  if actual < expected_min {
    fail(
      label +
      " image count too small: expected_at_least=" +
      expected_min.to_string() +
      " actual=" +
      actual.to_string(),
    )
  }
}

///|
fn assert_page_inline_image_count_at_least(
  page : @model.PdfPageModel,
  expected_min : Int,
  label : String,
) -> Unit raise {
  let actual = page_inline_image_count(page)
  if actual < expected_min {
    fail(
      label +
      " inline image count too small: expected_at_least=" +
      expected_min.to_string() +
      " actual=" +
      actual.to_string(),
    )
  }
}

///|
/// chars 总数。
fn document_char_count(doc_chars : @text.PdfDocumentChars) -> Int {
  let mut total = 0
  for page in doc_chars.pages {
    total = total + page.chars.length()
  }
  total
}

///|
/// spans 总数。
fn document_span_count(doc_spans : @text.PdfDocumentSpans) -> Int {
  let mut total = 0
  for page in doc_spans.pages {
    total = total + page.spans.length()
  }
  total
}

///|
/// lines 总数。
fn document_line_count(doc_lines : @text.PdfDocumentLines) -> Int {
  let mut total = 0
  for page in doc_lines.pages {
    total = total + page.lines.length()
  }
  total
}

///|
/// blocks 总数。
fn document_block_count(doc_blocks : @text.PdfDocumentBlocks) -> Int {
  let mut total = 0
  for page in doc_blocks.pages {
    total = total + page.blocks.length()
  }
  total
}

///|
/// 从 raw 依次构建到 chars。
fn build_chars_from_raw(
  raw : @raw.RawPdfDocumentExtract,
) -> @text.PdfDocumentChars raise {
  let doc_chars = @text.build_document_chars(raw)
  assert_chars_readable(doc_chars)
  doc_chars
}

///|
/// 从 raw 依次构建到 spans。
fn build_spans_from_raw(
  raw : @raw.RawPdfDocumentExtract,
) -> @text.PdfDocumentSpans raise {
  let doc_chars = build_chars_from_raw(raw)
  let doc_spans = @text.build_document_spans(doc_chars)
  assert_spans_readable(doc_spans)
  doc_spans
}

///|
/// 从 raw 依次构建到 lines。
fn build_lines_from_raw(
  raw : @raw.RawPdfDocumentExtract,
) -> @text.PdfDocumentLines raise {
  let doc_spans = build_spans_from_raw(raw)
  let doc_lines = @text.build_document_lines(doc_spans)
  assert_lines_readable(doc_lines)
  doc_lines
}

///|
/// 从 raw 依次构建到 blocks。
fn build_blocks_from_raw(
  raw : @raw.RawPdfDocumentExtract,
) -> @text.PdfDocumentBlocks raise {
  let doc_lines = build_lines_from_raw(raw)
  let doc_blocks = @text.build_document_blocks(doc_lines)
  assert_blocks_readable(doc_blocks)
  doc_blocks
}

///|
/// 将 page model 拉平成文本，方便 contains 断言。
fn page_joined_text(page : @model.PdfPageModel) -> String {
  let mut buf = ""
  for block in page.text_blocks {
    buf = buf + @model.block_text(block) + "\n"
  }
  buf
}

///|
/// 统计单页 heading candidate block 数量。
fn page_heading_candidate_count(page : @model.PdfPageModel) -> Int {
  let mut total = 0
  for block in page.text_blocks {
    if block.is_heading_candidate {
      total = total + 1
    }
  }
  total
}

///|
/// 断言单页 block 数量恰好等于预期。
fn assert_page_block_count(
  page : @model.PdfPageModel,
  expected : Int,
  label : String,
) -> Unit raise {
  let actual = page.text_blocks.length()
  if actual != expected {
    fail(
      label +
      " page block count mismatch: expected=" +
      expected.to_string() +
      " actual=" +
      actual.to_string(),
    )
  }
}

///|
/// 断言单页 heading candidate 数量至少为预期。
fn assert_page_heading_candidate_at_least(
  page : @model.PdfPageModel,
  expected_min : Int,
  label : String,
) -> Unit raise {
  let actual = page_heading_candidate_count(page)
  if actual < expected_min {
    fail(
      label +
      " heading candidate count too small: expected_at_least=" +
      expected_min.to_string() +
      " actual=" +
      actual.to_string(),
    )
  }
}

///|
fn _print_structure_counts(
  label : String,
  raw : @raw.RawPdfDocumentExtract,
) -> Unit raise {
  let doc_chars = build_chars_from_raw(raw)
  let doc_spans = build_spans_from_raw(raw)
  let doc_lines = build_lines_from_raw(raw)
  let doc_blocks = build_blocks_from_raw(raw)

  println("== " + label + " ==")
  for i = 0; i < raw.pages.length(); i = i + 1 {
    let chars_n = doc_chars.pages[i].chars.length()
    let spans_n = doc_spans.pages[i].spans.length()
    let lines_n = doc_lines.pages[i].lines.length()
    let blocks_n = doc_blocks.pages[i].blocks.length()

    println(
      "page " +
      i.to_string() +
      " chars=" +
      chars_n.to_string() +
      " spans=" +
      spans_n.to_string() +
      " lines=" +
      lines_n.to_string() +
      " blocks=" +
      blocks_n.to_string(),
    )
  }
}

///|
fn _print_span_sources(
  label : String,
  doc_spans : @text.PdfDocumentSpans,
) -> Unit {
  println("== span sources: " + label + " ==")
  if doc_spans.pages.is_empty() {
    return
  }

  let spans = doc_spans.pages[0].spans
  let limit = if spans.length() < 12 { spans.length() } else { 12 }

  for i = 0; i < limit; i = i + 1 {
    let span = spans[i]
    let text = span.text
    let text_short = if text.length() > 30 {
      text[:30].to_string() + "..."
    } else {
      text
    }

    if span.source_refs.is_empty() {
      println("span " + i.to_string() + ": no source, text=" + text_short)
    } else {
      let s = span.source_refs[0]
      let a = match s.text_object_id {
        Some(v) => v.to_string()
        None => "None"
      }
      println(
        "span " +
        i.to_string() +
        ": text=" +
        text_short +
        " stream=" +
        s.source_stream_index.to_string() +
        " op=" +
        s.source_op_index.to_string() +
        " text_obj=" +
        a +
        " break=" +
        span.break_before.to_string(),
      )
    }
  }
}

///|
fn _print_line_sources(
  label : String,
  doc_lines : @text.PdfDocumentLines,
) -> Unit {
  println("== line sources: " + label + " ==")
  if doc_lines.pages.is_empty() {
    return
  }

  let lines = doc_lines.pages[0].lines
  let limit = if lines.length() < 12 { lines.length() } else { 12 }

  for i = 0; i < limit; i = i + 1 {
    let line = lines[i]
    let text = @model.line_text(line)
    let text_short = if text.length() > 30 {
      text[:30].to_string() + "..."
    } else {
      text
    }

    if line.source_refs.is_empty() {
      println("line " + i.to_string() + ": no source, text=" + text_short)
    } else {
      let s = line.source_refs[0]
      let a = match s.text_object_id {
        Some(v) => v.to_string()
        None => "None"
      }
      println(
        "line " +
        i.to_string() +
        ": text=" +
        text_short +
        " stream=" +
        s.source_stream_index.to_string() +
        " op=" +
        s.source_op_index.to_string() +
        " text_obj=" +
        a,
      )
    }
  }
}

///|
/// text_simple: 结构 smoke + 数量断言 + 最小内容断言。
async test "pdf core smoke works on text_simple sample" {
  let raw = open_raw_pdf("samples/main_process/pdf/text_simple.pdf")
  assert_raw_readable(raw)

  let doc_chars = build_chars_from_raw(raw)
  if document_char_count(doc_chars) <= 0 {
    fail("text_simple chars count should be > 0")
  }

  let doc_spans = build_spans_from_raw(raw)
  if document_span_count(doc_spans) <= 0 {
    fail("text_simple spans count should be > 0")
  }

  let doc_lines = build_lines_from_raw(raw)
  if document_line_count(doc_lines) <= 0 {
    fail("text_simple lines count should be > 0")
  }

  let doc_blocks = build_blocks_from_raw(raw)
  if document_block_count(doc_blocks) <= 0 {
    fail("text_simple blocks count should be > 0")
  }
  if doc_blocks.pages[0].blocks.length() <= 0 {
    fail("text_simple page 0 blocks length should be > 0")
  }

  //print_structure_counts("text_simple", raw)
  //print_span_sources("text_simple", doc_spans)
  //print_line_sources("text_simple", doc_lines)

  let doc = open_pdf_model("samples/main_process/pdf/text_simple.pdf")
  assert_model_readable(doc)

  assert_page_block_count(doc.pages[0], 4, "text_simple")
  assert_page_heading_candidate_at_least(doc.pages[0], 1, "text_simple")
  let text = page_joined_text(doc.pages[0])
  if !text.contains("English") {
    fail("text_simple page text should contain 'English'")
  }
}

///|
async test "pdf core page geometry and source refs are populated" {
  let raw = open_raw_pdf("samples/main_process/pdf/text_simple.pdf")
  assert_raw_readable(raw)
  let raw_page = raw.pages[0]
  match raw_page.raw_page_ref {
    Some(r) =>
      if r.obj_num <= 0 {
        fail("raw page object number should be > 0")
      }
    None => fail("raw page ref should be available for text_simple")
  }
  match raw_page.media_box {
    Some(rect) => assert_valid_rect(rect, "raw media_box")
    None => fail("raw media_box should be available for text_simple")
  }
  if raw_page.rotation != 0 {
    fail("text_simple rotation should be stable at 0")
  }
  if raw_page.raw_content_stream_refs.is_empty() {
    fail("text_simple should expose indirect content stream refs")
  }

  let doc = open_pdf_model("samples/main_process/pdf/text_simple.pdf")
  assert_model_readable(doc)
  let page = doc.pages[0]
  assert_valid_rect(page.boxes.media_box, "model media_box")
  if page.rotation != raw_page.rotation {
    fail("model rotation should match raw rotation")
  }
  if page.raw_content_stream_refs.length() !=
    raw_page.raw_content_stream_refs.length() {
    fail("model raw_content_stream_refs should be passed through")
  }
}

///|
/// hardwrap_en: 结构 smoke + 数量断言 + 最小英文内容断言。
async test "pdf core smoke works on hardwrap_en sample" {
  let raw = open_raw_pdf("samples/main_process/pdf/hardwrap_en.pdf")
  assert_raw_readable(raw)

  let doc_chars = build_chars_from_raw(raw)
  if document_char_count(doc_chars) <= 0 {
    fail("hardwrap_en chars count should be > 0")
  }

  let doc_spans = build_spans_from_raw(raw)
  if document_span_count(doc_spans) <= 0 {
    fail("hardwrap_en spans count should be > 0")
  }

  let doc_lines = build_lines_from_raw(raw)
  if document_line_count(doc_lines) <= 0 {
    fail("hardwrap_en lines count should be > 0")
  }

  let doc_blocks = build_blocks_from_raw(raw)
  if document_block_count(doc_blocks) <= 0 {
    fail("hardwrap_en blocks count should be > 0")
  }
  if doc_blocks.pages[0].blocks.length() <= 0 {
    fail("hardwrap_en page 0 blocks length should be > 0")
  }

  //print_structure_counts("hardwrap_en", raw)
  //print_span_sources("hardwrap_en", doc_spans)
  //print_line_sources("hardwrap_en", doc_lines)

  let doc = open_pdf_model("samples/main_process/pdf/hardwrap_en.pdf")
  assert_model_readable(doc)

  assert_page_block_count(doc.pages[0], 3, "hardwrap_en")
  assert_page_heading_candidate_at_least(doc.pages[0], 1, "hardwrap_en")

  let text = page_joined_text(doc.pages[0])
  if !text.contains("Document") && !text.contains("document") {
    fail("hardwrap_en page text should contain 'Document' or 'document'")
  }
}

///|
/// hardwrap_zh: 结构 smoke + 数量断言 + 最小中文内容断言。
async test "pdf core smoke works on hardwrap_zh sample" {
  let raw = open_raw_pdf("samples/main_process/pdf/hardwrap_zh.pdf")
  assert_raw_readable(raw)

  let doc_chars = build_chars_from_raw(raw)
  if document_char_count(doc_chars) <= 0 {
    fail("hardwrap_zh chars count should be > 0")
  }

  let doc_spans = build_spans_from_raw(raw)
  if document_span_count(doc_spans) <= 0 {
    fail("hardwrap_zh spans count should be > 0")
  }

  let doc_lines = build_lines_from_raw(raw)
  if document_line_count(doc_lines) <= 0 {
    fail("hardwrap_zh lines count should be > 0")
  }

  let doc_blocks = build_blocks_from_raw(raw)
  if document_block_count(doc_blocks) <= 0 {
    fail("hardwrap_zh blocks count should be > 0")
  }
  if doc_blocks.pages[0].blocks.length() <= 0 {
    fail("hardwrap_zh page 0 blocks length should be > 0")
  }

  //print_structure_counts("hardwrap_zh", raw)
  //print_span_sources("hardwrap_zh", doc_spans)
  //print_line_sources("hardwrap_zh", doc_lines)

  let doc = open_pdf_model("samples/main_process/pdf/hardwrap_zh.pdf")
  assert_model_readable(doc)

  assert_page_block_count(doc.pages[0], 4, "hardwrap_zh")
  assert_page_heading_candidate_at_least(doc.pages[0], 2, "hardwrap_zh")

  let text = page_joined_text(doc.pages[0])
  if !text.contains("研究") && !text.contains("技术") {
    fail("hardwrap_zh page text should contain Chinese content")
  }
}

///|
/// 普通 XObject 图片：
/// - raw 层应能看到 images
/// - model 层应能看到 images
/// - 至少一张不是 inline image
async test "pdf core collects xobject images" {
  let raw = open_raw_pdf("samples/assets/pdf/pdf_image_xobject.pdf")
  if raw.pages.is_empty() {
    fail("xobject image sample raw pages should not be empty")
  }
  if raw.pages[0].images.length() <= 0 {
    fail("raw page 0 should contain at least one image")
  }

  let doc = open_pdf_model("samples/assets/pdf/pdf_image_xobject.pdf")
  assert_model_readable(doc)

  assert_page_image_count_at_least(doc.pages[0], 1, "xobject image sample")

  let mut non_inline_found = false
  for image in doc.pages[0].images {
    if !image.inline_image {
      non_inline_found = true
    }
    if image.width_px <= 0 || image.height_px <= 0 {
      fail("xobject image should have positive width/height")
    }
  }
  if !non_inline_found {
    fail("xobject image sample should contain at least one non-inline image")
  }
}

///|
/// Inline image：
/// - model 层至少一张 inline image
async test "pdf core collects inline images" {
  let raw = open_raw_pdf("samples/assets/pdf/pdf_image_inline.pdf")
  if raw.pages.is_empty() {
    fail("inline image sample raw pages should not be empty")
  }
  if raw.pages[0].images.length() <= 0 {
    fail("raw page 0 should contain at least one image")
  }

  let doc = open_pdf_model("samples/assets/pdf/pdf_image_inline.pdf")
  assert_model_readable(doc)

  assert_page_image_count_at_least(doc.pages[0], 1, "inline image sample")
  assert_page_inline_image_count_at_least(
    doc.pages[0],
    1,
    "inline image sample",
  )

  for image in doc.pages[0].images {
    if image.inline_image {
      if image.width_px <= 0 || image.height_px <= 0 {
        fail("inline image should have positive width/height")
      }
      return
    }
  }

  fail("inline image sample should contain at least one inline image")
}

///|
/// Form XObject 内嵌图片：
/// - 应能通过 form 递归抓到图片
/// - 通常应为非 inline image
async test "pdf core collects form xobject images" {
  let raw = open_raw_pdf("samples/assets/pdf/pdf_image_form_xobject.pdf")
  if raw.pages.is_empty() {
    fail("form xobject image sample raw pages should not be empty")
  }
  if raw.pages[0].images.length() <= 0 {
    fail("raw page 0 should contain at least one image")
  }

  let doc = open_pdf_model("samples/assets/pdf/pdf_image_form_xobject.pdf")
  assert_model_readable(doc)

  assert_page_image_count_at_least(doc.pages[0], 1, "form xobject image sample")

  let mut non_inline_found = false
  for image in doc.pages[0].images {
    if !image.inline_image {
      non_inline_found = true
    }
    if image.width_px <= 0 || image.height_px <= 0 {
      fail("form xobject image should have positive width/height")
    }
  }

  if !non_inline_found {
    fail(
      "form xobject image sample should contain at least one non-inline image",
    )
  }
}

///|
async test "pdf core xobject image carries payload" {
  let doc = open_pdf_model("samples/assets/pdf/pdf_image_xobject.pdf")
  assert_page_image_count_at_least(doc.pages[0], 1, "xobject payload sample")

  let mut found = false
  for image in doc.pages[0].images {
    if !image.inline_image {
      match image.payload {
        Some(_) => {
          found = true
          break
        }
        None => ()
      }
    }
  }

  if !found {
    fail(
      "xobject image sample should contain at least one payload-bearing image",
    )
  }
}

///|
async test "pdf core inline image carries payload" {
  let doc = open_pdf_model("samples/assets/pdf/pdf_image_inline.pdf")
  assert_page_inline_image_count_at_least(
    doc.pages[0],
    1,
    "inline payload sample",
  )

  let mut found = false
  for image in doc.pages[0].images {
    if image.inline_image {
      match image.payload {
        Some(_) => {
          found = true
          break
        }
        None => ()
      }
    }
  }

  if !found {
    fail(
      "inline image sample should contain at least one payload-bearing inline image",
    )
  }
}

///|
async test "pdf core form xobject image carries payload" {
  let doc = open_pdf_model("samples/assets/pdf/pdf_image_form_xobject.pdf")
  assert_page_image_count_at_least(doc.pages[0], 1, "form payload sample")

  let mut found = false
  for image in doc.pages[0].images {
    if !image.inline_image {
      match image.payload {
        Some(_) => {
          found = true
          break
        }
        None => ()
      }
    }
  }

  if !found {
    fail(
      "form xobject image sample should contain at least one payload-bearing image",
    )
  }
}

///|
async test "pdf core raw xobject image carries payload" {
  let raw = open_raw_pdf("samples/assets/pdf/pdf_image_xobject.pdf")
  if raw.pages.is_empty() {
    fail("raw pages should not be empty")
  }
  if raw.pages[0].images.is_empty() {
    fail("raw page 0 should contain at least one image")
  }

  let mut found = false
  for image in raw.pages[0].images {
    if !image.inline_image {
      match image.payload {
        Some(_) => {
          found = true
          break
        }
        None => ()
      }
    }
  }

  if !found {
    fail(
      "raw xobject image sample should contain at least one payload-bearing image",
    )
  }
}

///|
async test "pdf core xobject image has placement bbox" {
  let doc = open_pdf_model("samples/assets/pdf/pdf_image_xobject.pdf")
  assert_page_image_count_at_least(doc.pages[0], 1, "xobject bbox sample")

  let mut found = false
  for image in doc.pages[0].images {
    if !image.inline_image &&
      image.bbox.x1 > image.bbox.x0 &&
      image.bbox.y1 > image.bbox.y0 {
      found = true
      break
    }
  }

  if !found {
    fail("xobject image sample should contain at least one non-empty bbox")
  }
}

///|
async test "pdf core inline image has placement bbox" {
  let doc = open_pdf_model("samples/assets/pdf/pdf_image_inline.pdf")
  assert_page_inline_image_count_at_least(doc.pages[0], 1, "inline bbox sample")

  let mut found = false
  for image in doc.pages[0].images {
    if image.inline_image &&
      image.bbox.x1 > image.bbox.x0 &&
      image.bbox.y1 > image.bbox.y0 {
      found = true
      break
    }
  }

  if !found {
    fail("inline image sample should contain at least one non-empty bbox")
  }
}

///|
async test "pdf core form xobject image has placement bbox" {
  let doc = open_pdf_model("samples/assets/pdf/pdf_image_form_xobject.pdf")
  assert_page_image_count_at_least(doc.pages[0], 1, "form bbox sample")

  let mut found = false
  for image in doc.pages[0].images {
    if !image.inline_image &&
      image.bbox.x1 > image.bbox.x0 &&
      image.bbox.y1 > image.bbox.y0 {
      found = true
      break
    }
  }

  if !found {
    fail("form xobject image sample should contain at least one non-empty bbox")
  }
}
