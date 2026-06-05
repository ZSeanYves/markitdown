///|
test "vision markdown paragraph renders as text" {
  let out = render_ocr_layout_block_markdown(
    make_block(OcrLayoutBlockKind::Paragraph, "Alpha paragraph"),
  )
  assert_eq(out, "Alpha paragraph")
}

///|
test "vision markdown table-like block renders as plain text" {
  let out = render_ocr_layout_block_markdown(
    make_block(OcrLayoutBlockKind::TableLike, "Item Qty Apple 2 Banana 5"),
  )
  assert_eq(out, "Item Qty Apple 2 Banana 5")
  assert_true(!out.contains("|"))
}

///|
test "vision markdown heading renders with hash prefix" {
  let out = render_ocr_layout_block_markdown(
    make_block(OcrLayoutBlockKind::Heading, "Introduction"),
  )
  assert_eq(out, "# Introduction")
}

///|
test "vision markdown heading preserves existing hash prefix" {
  let out = render_ocr_layout_block_markdown(
    make_block(OcrLayoutBlockKind::Heading, "# Existing"),
  )
  assert_eq(out, "# Existing")
}

///|
test "vision markdown list item preserves marker" {
  let out = render_ocr_layout_block_markdown(
    make_block(OcrLayoutBlockKind::ListItem, "- first item"),
  )
  assert_eq(out, "- first item")
}

///|
test "vision markdown list item adds fallback marker when missing" {
  let out = render_ocr_layout_block_markdown(
    make_block(OcrLayoutBlockKind::ListItem, "first item"),
  )
  assert_eq(out, "- first item")
}

///|
test "vision markdown noise is omitted" {
  let out = render_ocr_layout_block_markdown(
    make_block(OcrLayoutBlockKind::Noise, "Page 1"),
  )
  assert_eq(out, "")
}

///|
test "vision markdown unknown block is preserved" {
  let out = render_ocr_layout_block_markdown(
    make_block(OcrLayoutBlockKind::Unknown, "Keep me"),
  )
  assert_eq(out, "Keep me")
}

///|
test "vision markdown empty blocks are skipped" {
  let out = render_ocr_layout_blocks_markdown([
    make_block(OcrLayoutBlockKind::Paragraph, "   "),
    make_block(OcrLayoutBlockKind::Noise, "Page 1"),
  ])
  assert_eq(out, "")
}

///|
test "vision markdown blocks are separated by blank line" {
  let out = render_ocr_layout_blocks_markdown([
    make_block(OcrLayoutBlockKind::Heading, "Intro"),
    make_block(OcrLayoutBlockKind::Paragraph, "Alpha paragraph"),
    make_block(OcrLayoutBlockKind::ListItem, "- bullet"),
  ])
  assert_eq(out, "# Intro\n\nAlpha paragraph\n\n- bullet\n")
}

///|
test "vision markdown final newline is stable" {
  let out = render_ocr_layout_blocks_markdown([
    make_block(OcrLayoutBlockKind::Paragraph, "Alpha"),
  ])
  assert_true(out.has_suffix("\n"))
  assert_eq(out, "Alpha\n")
}

///|
test "vision markdown recovered layout renders predictably" {
  let page : OcrPageModel = {
    page_index: 0,
    width: 200.0,
    height: 200.0,
    lines: [
      make_markdown_test_line(0, "Introduction", 10.0, 10.0, 90.0, 12.0, 0.9),
      make_markdown_test_line(1, "- first item", 10.0, 40.0, 90.0, 12.0, 0.8),
      make_markdown_test_line(2, "Page 1", 10.0, 180.0, 40.0, 12.0, 0.7),
      make_markdown_test_line(
        3, "Alpha body text.", 10.0, 70.0, 120.0, 12.0, 0.9,
      ),
    ],
    words: [],
    provider: "future-tsv",
    source_kind: "tesseract-tsv",
    warnings: [],
  }
  let layout = recover_ocr_layout_page(page)
  let out = render_ocr_layout_page_markdown(layout)
  assert_eq(out, "# Introduction\n\n- first item\n\nAlpha body text.\n")
}

///|
test "vision markdown renderer is library only and does not require cli" {
  let out = render_ocr_layout_blocks_markdown([
    make_block(OcrLayoutBlockKind::Paragraph, "Internal preview"),
  ])
  assert_eq(out, "Internal preview\n")
}

///|
fn make_block(kind : OcrLayoutBlockKind, text : String) -> OcrLayoutBlock {
  {
    kind,
    text,
    bbox: unknown_bbox(),
    confidence: -1.0,
    line_indices: [],
    reasons: [],
  }
}

///|
fn make_markdown_test_line(
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
