///|
test "vision layout to ir maps paragraph block" {
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [
      make_layout_to_ir_block(
        OcrLayoutBlockKind::Paragraph,
        "Alpha paragraph",
        [1, 2],
        0.7,
        ["single-line paragraph"],
      ),
    ],
    warnings: [],
  })
  match doc.blocks.val[0] {
    @cor.Block::Paragraph("Alpha paragraph") => ()
    _ => fail("expected paragraph block")
  }
  let origin = unwrap_layout_to_ir_origin(doc.block_origins.val[0])
  match origin.page {
    Some(1) => ()
    _ => fail("expected page=1")
  }
  match origin.block_index {
    Some(0) => ()
    _ => fail("expected block_index=0")
  }
  match origin.line_start {
    Some(1) => ()
    _ => fail("expected line_start=1")
  }
  match origin.line_end {
    Some(2) => ()
    _ => fail("expected line_end=2")
  }
}

///|
test "vision layout to ir maps heading block to heading level one" {
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [
      make_layout_to_ir_block(
        OcrLayoutBlockKind::Heading,
        "Vision OCR",
        [0],
        0.9,
        ["single-line heading candidate"],
      ),
    ],
    warnings: [],
  })
  match doc.blocks.val[0] {
    @cor.Block::Heading(1, "Vision OCR") => ()
    _ => fail("expected heading block")
  }
}

///|
test "vision layout to ir maps bullet list item to unordered list item" {
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [
      make_layout_to_ir_block(
        OcrLayoutBlockKind::ListItem,
        "- OCRPageModel",
        [4],
        0.8,
        ["list marker prefix"],
      ),
    ],
    warnings: [],
  })
  match doc.blocks.val[0] {
    @cor.Block::ListItem(false, 0, "OCRPageModel") => ()
    _ => fail("expected unordered list item")
  }
}

///|
test "vision layout to ir maps numbered list item to ordered list item" {
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [
      make_layout_to_ir_block(
        OcrLayoutBlockKind::ListItem,
        "1. Vision adapter",
        [4],
        0.8,
        ["list marker prefix"],
      ),
    ],
    warnings: [],
  })
  match doc.blocks.val[0] {
    @cor.Block::ListItem(true, 0, "Vision adapter") => ()
    _ => fail("expected ordered list item")
  }
}

///|
test "vision layout to ir maps table-like block to plain paragraph" {
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [
      make_layout_to_ir_block(
        OcrLayoutBlockKind::TableLike,
        "Item Qty Apple 2 Banana 5",
        [0, 1, 2],
        0.8,
        ["table-like rows", "aligned column candidate"],
      ),
    ],
    warnings: [],
  })
  match doc.blocks.val[0] {
    @cor.Block::Paragraph("Item Qty Apple 2 Banana 5") => ()
    _ => fail("expected table-like to stay plain paragraph in IR")
  }
}

///|
test "vision layout to ir preserves unknown block as paragraph" {
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [
      make_layout_to_ir_block(
        OcrLayoutBlockKind::Unknown,
        "Unclassified content",
        [],
        -1.0,
        [],
      ),
    ],
    warnings: [],
  })
  match doc.blocks.val[0] {
    @cor.Block::Paragraph("Unclassified content") => ()
    _ => fail("expected unknown block to stay paragraph")
  }
}

///|
test "vision layout to ir drops noise blocks" {
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [
      make_layout_to_ir_block(OcrLayoutBlockKind::Noise, "Page 1", [9], -1.0, [
        "page number noise",
      ]),
    ],
    warnings: [],
  })
  assert_eq(doc.blocks.val.length(), 0)
  assert_eq(doc.block_origins.val.length(), 0)
}

///|
test "vision layout to ir drops empty text blocks" {
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [
      make_layout_to_ir_block(OcrLayoutBlockKind::Paragraph, "   ", [0], 0.5, []),
    ],
    warnings: [],
  })
  assert_eq(doc.blocks.val.length(), 0)
}

///|
test "vision layout to ir keeps block ordering across pages" {
  let doc = convert_ocr_layout_pages_to_ir([
    {
      page_index: 0,
      blocks: [
        make_layout_to_ir_block(
          OcrLayoutBlockKind::Heading,
          "Page One",
          [0],
          0.9,
          [],
        ),
      ],
      warnings: [],
    },
    {
      page_index: 1,
      blocks: [
        make_layout_to_ir_block(
          OcrLayoutBlockKind::Paragraph,
          "Page Two paragraph",
          [1, 2],
          0.7,
          [],
        ),
      ],
      warnings: [],
    },
  ])
  assert_eq(doc.blocks.val.length(), 2)
  match doc.blocks.val[0] {
    @cor.Block::Heading(1, "Page One") => ()
    _ => fail("expected first page heading")
  }
  match doc.blocks.val[1] {
    @cor.Block::Paragraph("Page Two paragraph") => ()
    _ => fail("expected second page paragraph")
  }
  let origin0 = unwrap_layout_to_ir_origin(doc.block_origins.val[0])
  let origin1 = unwrap_layout_to_ir_origin(doc.block_origins.val[1])
  match origin0.page {
    Some(1) => ()
    _ => fail("expected first page origin")
  }
  match origin1.page {
    Some(2) => ()
    _ => fail("expected second page origin")
  }
}

///|
test "vision layout to ir emits warning paragraph when page drops all content" {
  let doc = convert_ocr_layout_pages_to_ir([
    {
      page_index: 0,
      blocks: [
        make_layout_to_ir_block(
          OcrLayoutBlockKind::Noise,
          "Page 1",
          [9],
          -1.0,
          ["page number noise"],
        ),
      ],
      warnings: ["two-column reading order applied"],
    },
  ])
  assert_eq(doc.blocks.val.length(), 1)
  match doc.blocks.val[0] {
    @cor.Block::Paragraph(text) =>
      assert_true(text.contains("two-column reading order applied"))
    _ => fail("expected warning paragraph when page content is fully dropped")
  }
}

///|
fn make_layout_to_ir_block(
  kind : OcrLayoutBlockKind,
  text : String,
  line_indices : Array[Int],
  confidence : Double,
  reasons : Array[String],
) -> OcrLayoutBlock {
  { kind, text, bbox: unknown_bbox(), confidence, line_indices, reasons }
}

///|
fn unwrap_layout_to_ir_origin(origin : @cor.Origin?) -> @cor.Origin {
  match origin {
    Some(value) => value
    None => abort("expected origin")
  }
}
