///|
test "vision ir markdown renders paragraph through core emitter" {
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [
      make_vision_ir_markdown_block(
        OcrLayoutBlockKind::Paragraph,
        "Alpha paragraph",
      ),
    ],
    warnings: [],
  })
  let out = render_ocr_ir_document_markdown(doc)
  assert_eq(out, "Alpha paragraph\n")
}

///|
test "vision ir markdown renders heading through core emitter" {
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [
      make_vision_ir_markdown_block(OcrLayoutBlockKind::Heading, "Intro"),
    ],
    warnings: [],
  })
  let out = render_ocr_ir_document_markdown(doc)
  assert_eq(out, "# Intro\n")
}

///|
test "vision ir markdown renders list item through core emitter" {
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [
      make_vision_ir_markdown_block(
        OcrLayoutBlockKind::ListItem,
        "- first item",
      ),
    ],
    warnings: [],
  })
  let out = render_ocr_ir_document_markdown(doc)
  assert_eq(out, "- first item\n")
}

///|
test "vision ir markdown keeps table-like as plain text paragraph" {
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [
      make_vision_ir_markdown_block(
        OcrLayoutBlockKind::TableLike,
        "Item Qty Apple 2 Banana 5",
      ),
    ],
    warnings: [],
  })
  let out = render_ocr_ir_document_markdown(doc)
  assert_eq(out, "Item Qty Apple 2 Banana 5\n")
  assert_true(!out.contains("|"))
}

///|
test "vision ir markdown keeps unknown as plain paragraph" {
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [
      make_vision_ir_markdown_block(
        OcrLayoutBlockKind::Unknown,
        "Keep unknown content",
      ),
    ],
    warnings: [],
  })
  let out = render_ocr_ir_document_markdown(doc)
  assert_eq(out, "Keep unknown content\n")
}

///|
test "vision ir markdown drops noise" {
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [make_vision_ir_markdown_block(OcrLayoutBlockKind::Noise, "Page 1")],
    warnings: [],
  })
  let out = render_ocr_ir_document_markdown(doc)
  assert_eq(out, "")
}

///|
test "vision ir markdown page renderer matches layout markdown for representative page" {
  let page : OcrPageModel = {
    page_index: 0,
    width: 220.0,
    height: 220.0,
    lines: [
      make_markdown_test_line(0, "Vision OCR", 10.0, 10.0, 100.0, 12.0, 0.9),
      make_markdown_test_line(1, "- OCRPageModel", 10.0, 40.0, 100.0, 12.0, 0.8),
      make_markdown_test_line(2, "Page 1", 10.0, 190.0, 50.0, 12.0, 0.6),
      make_markdown_test_line(
        3, "MoonBit recovers layout from provider signals.", 10.0, 70.0, 180.0, 12.0,
        0.9,
      ),
    ],
    words: [],
    provider: "future-tsv",
    source_kind: "tesseract-tsv",
    warnings: [],
  }
  let layout = recover_ocr_layout_page(page)
  let layout_markdown = render_ocr_layout_page_markdown(layout)
  let ir_markdown = render_ocr_layout_page_via_ir_markdown(layout)
  assert_eq(ir_markdown, layout_markdown)
}

///|
test "vision ir markdown multi-page renderer stays stable" {
  let pages = [
    {
      page_index: 0,
      blocks: [
        make_vision_ir_markdown_block(OcrLayoutBlockKind::Heading, "Page One"),
      ],
      warnings: [],
    },
    {
      page_index: 1,
      blocks: [
        make_vision_ir_markdown_block(
          OcrLayoutBlockKind::Paragraph,
          "Page Two body",
        ),
      ],
      warnings: [],
    },
  ]
  let out = render_ocr_layout_pages_via_ir_markdown(pages)
  assert_eq(out, "# Page One\n\nPage Two body\n")
}

///|
fn make_vision_ir_markdown_block(
  kind : OcrLayoutBlockKind,
  text : String,
) -> OcrLayoutBlock {
  {
    kind,
    text,
    bbox: unknown_bbox(),
    confidence: -1.0,
    line_indices: [],
    reasons: [],
  }
}
