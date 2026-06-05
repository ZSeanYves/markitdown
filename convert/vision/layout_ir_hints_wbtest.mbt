///|
test "vision ir hints preserve table-like hint while ir block stays paragraph" {
  let block = make_layout_ir_hint_block(
    OcrLayoutBlockKind::TableLike,
    "Item Qty Apple 2 Banana 5",
    [0, 1, 2],
    0.8,
    ["table-like rows", "aligned column candidate"],
  )
  let doc = convert_ocr_layout_page_to_ir({
    page_index: 0,
    blocks: [block],
    warnings: [],
  })
  let hints = collect_ocr_layout_page_ir_hints({
    page_index: 0,
    blocks: [block],
    warnings: [],
  })

  match doc.blocks.val[0] {
    @cor.Block::Paragraph("Item Qty Apple 2 Banana 5") => ()
    _ => fail("expected table-like block to stay paragraph in core IR")
  }
  assert_eq(hints.block_hints.length(), 1)
  let hint = hints.block_hints[0]
  assert_true(hint.kind == OcrIrBlockHintKind::TableLike)
  assert_eq(hint.source_line_indices.length(), 3)
  assert_eq(hint.source_line_indices[0], 0)
  assert_eq(hint.source_line_indices[1], 1)
  assert_eq(hint.source_line_indices[2], 2)
  assert_eq(hint.confidence, 0.8)
  assert_true(hint.reasons.contains("aligned column candidate"))
}

///|
test "vision ir hints preserve paragraph heading list and unknown kinds" {
  let hints = collect_ocr_layout_pages_ir_hints([
    {
      page_index: 0,
      blocks: [
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::Paragraph,
          "Paragraph",
          [0],
          0.7,
          [],
        ),
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::Heading,
          "Heading",
          [1],
          0.9,
          ["numbered heading pattern"],
        ),
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::ListItem,
          "- Bullet",
          [2],
          0.8,
          ["list marker prefix"],
        ),
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::Unknown,
          "Unknown",
          [3],
          -1.0,
          [],
        ),
      ],
      warnings: [],
    },
  ])
  assert_eq(hints.block_hints.length(), 4)
  assert_true(hints.block_hints[0].kind == OcrIrBlockHintKind::Paragraph)
  assert_true(hints.block_hints[1].kind == OcrIrBlockHintKind::Heading)
  assert_true(hints.block_hints[2].kind == OcrIrBlockHintKind::ListItem)
  assert_true(hints.block_hints[3].kind == OcrIrBlockHintKind::Unknown)
}

///|
test "vision ir hints lift conservative key value paragraphs into keyvaluelike" {
  let hints = collect_ocr_layout_pages_ir_hints([
    {
      page_index: 0,
      blocks: [
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::Paragraph,
          "Date: 2026-05-22",
          [0],
          0.9,
          ["single-line paragraph"],
        ),
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::Paragraph,
          "Total: 123.45",
          [1],
          0.8,
          ["single-line paragraph"],
        ),
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::Paragraph,
          "Status: Paid",
          [2],
          0.85,
          ["single-line paragraph"],
        ),
      ],
      warnings: [],
    },
  ])
  assert_eq(hints.block_hints.length(), 3)
  assert_true(hints.block_hints[0].kind == OcrIrBlockHintKind::KeyValueLike)
  assert_true(hints.block_hints[1].kind == OcrIrBlockHintKind::KeyValueLike)
  assert_true(hints.block_hints[2].kind == OcrIrBlockHintKind::KeyValueLike)
}

///|
test "vision ir hints keep caption like text out of keyvaluelike" {
  let hint = collect_ocr_layout_block_ir_hint(
    make_layout_ir_hint_block(
      OcrLayoutBlockKind::Paragraph,
      "Figure 1: System overview",
      [0],
      0.9,
      ["single-line paragraph"],
    ),
    0,
    0,
  )
  match hint {
    Some(value) => assert_true(value.kind == OcrIrBlockHintKind::CaptionLike)
    None => fail("expected non-empty hint")
  }
}

///|
test "vision ir hints classify common caption markers as captionlike" {
  let hints = collect_ocr_layout_pages_ir_hints([
    {
      page_index: 0,
      blocks: [
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::Paragraph,
          "Fig. 2: Pipeline",
          [0],
          0.9,
          ["single-line paragraph"],
        ),
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::Paragraph,
          "Table 3: Results",
          [1],
          0.8,
          ["single-line paragraph"],
        ),
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::Paragraph,
          "Chart 4: Revenue",
          [2],
          0.85,
          ["single-line paragraph"],
        ),
      ],
      warnings: [],
    },
  ])
  assert_eq(hints.block_hints.length(), 3)
  assert_true(hints.block_hints[0].kind == OcrIrBlockHintKind::CaptionLike)
  assert_true(hints.block_hints[1].kind == OcrIrBlockHintKind::CaptionLike)
  assert_true(hints.block_hints[2].kind == OcrIrBlockHintKind::CaptionLike)
}

///|
test "vision ir hints keep url like text out of keyvaluelike" {
  let hint = collect_ocr_layout_block_ir_hint(
    make_layout_ir_hint_block(
      OcrLayoutBlockKind::Paragraph,
      "Docs: https://example.com/spec",
      [0],
      0.9,
      ["single-line paragraph"],
    ),
    0,
    0,
  )
  match hint {
    Some(value) => assert_true(value.kind == OcrIrBlockHintKind::Paragraph)
    None => fail("expected non-empty hint")
  }
}

///|
test "vision ir hints keep url like text out of captionlike" {
  let hint = collect_ocr_layout_block_ir_hint(
    make_layout_ir_hint_block(
      OcrLayoutBlockKind::Paragraph,
      "Figure 1: https://example.com/spec",
      [0],
      0.9,
      ["single-line paragraph"],
    ),
    0,
    0,
  )
  match hint {
    Some(value) => assert_true(value.kind == OcrIrBlockHintKind::Paragraph)
    None => fail("expected non-empty hint")
  }
}

///|
test "vision ir hints keep heading list and tablelike priority over keyvaluelike" {
  let hints = collect_ocr_layout_pages_ir_hints([
    {
      page_index: 0,
      blocks: [
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::Heading,
          "Section: Overview",
          [0],
          0.9,
          ["single-line heading candidate"],
        ),
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::ListItem,
          "- Name: Value",
          [1],
          0.8,
          ["list marker prefix"],
        ),
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::TableLike,
          "Item Qty Apple 2 Banana 5",
          [2, 3, 4],
          0.7,
          ["table-like rows", "aligned column candidate"],
        ),
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::Paragraph,
          "Figure 1: System overview",
          [5],
          0.75,
          ["single-line paragraph"],
        ),
      ],
      warnings: [],
    },
  ])
  assert_eq(hints.block_hints.length(), 4)
  assert_true(hints.block_hints[0].kind == OcrIrBlockHintKind::Heading)
  assert_true(hints.block_hints[1].kind == OcrIrBlockHintKind::ListItem)
  assert_true(hints.block_hints[2].kind == OcrIrBlockHintKind::TableLike)
  assert_true(hints.block_hints[3].kind == OcrIrBlockHintKind::CaptionLike)
}

///|
test "vision ir hints drop noise and empty text" {
  let hints = collect_ocr_layout_pages_ir_hints([
    {
      page_index: 0,
      blocks: [
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::Noise,
          "Page 1",
          [9],
          -1.0,
          ["page number noise"],
        ),
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::Paragraph,
          "   ",
          [0],
          0.5,
          [],
        ),
      ],
      warnings: [],
    },
  ])
  assert_eq(hints.block_hints.length(), 0)
}

///|
test "vision ir hints preserve page warnings once" {
  let hints = collect_ocr_layout_pages_ir_hints([
    {
      page_index: 0,
      blocks: [
        make_layout_ir_hint_block(
          OcrLayoutBlockKind::Paragraph,
          "Alpha",
          [0],
          0.7,
          [],
        ),
      ],
      warnings: [
        "two-column reading order applied", "two-column reading order applied",
      ],
    },
  ])
  assert_eq(hints.warnings.length(), 1)
  assert_eq(hints.warnings[0], "two-column reading order applied")
}

///|
test "vision ir hints keep ir block indices aligned with emitted blocks" {
  let page = {
    page_index: 1,
    blocks: [
      make_layout_ir_hint_block(
        OcrLayoutBlockKind::Noise,
        "Page 2",
        [9],
        -1.0,
        ["page number noise"],
      ),
      make_layout_ir_hint_block(
        OcrLayoutBlockKind::Heading,
        "Section",
        [0],
        0.9,
        [],
      ),
      make_layout_ir_hint_block(
        OcrLayoutBlockKind::Paragraph,
        "Body",
        [1],
        0.8,
        [],
      ),
    ],
    warnings: [],
  }
  let doc = convert_ocr_layout_page_to_ir(page)
  let hints = collect_ocr_layout_page_ir_hints(page)
  assert_eq(doc.blocks.val.length(), 2)
  assert_eq(hints.block_hints.length(), 2)
  assert_eq(hints.block_hints[0].ir_block_index, 0)
  assert_eq(hints.block_hints[1].ir_block_index, 1)
}

///|
fn make_layout_ir_hint_block(
  kind : OcrLayoutBlockKind,
  text : String,
  line_indices : Array[Int],
  confidence : Double,
  reasons : Array[String],
) -> OcrLayoutBlock {
  { kind, text, bbox: unknown_bbox(), confidence, line_indices, reasons }
}
