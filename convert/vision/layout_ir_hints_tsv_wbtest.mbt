///|
test "vision ir hints tsv renderer includes stable header" {
  let out = render_ocr_ir_document_hints_tsv({ block_hints: [], warnings: [] })
  assert_eq(
    out, "page_index\tir_block_index\tkind\tconfidence\tline_start\tline_end\ttext\treasons\n",
  )
}

///|
test "vision ir hints tsv renderer emits paragraph row" {
  let out = render_ocr_ir_document_hints_tsv({
    block_hints: [
      make_layout_ir_tsv_hint(
        0,
        0,
        OcrIrBlockHintKind::Paragraph,
        [1, 2],
        0.7,
        "Alpha paragraph",
        ["single-line paragraph"],
      ),
    ],
    warnings: [],
  })
  assert_true(
    out.contains(
      "0\t0\tParagraph\t0.7\t1\t2\tAlpha paragraph\tsingle-line paragraph",
    ),
  )
}

///|
test "vision ir hints tsv renderer emits tablelike kind and joined reasons" {
  let out = render_ocr_ir_document_hints_tsv({
    block_hints: [
      make_layout_ir_tsv_hint(
        0,
        3,
        OcrIrBlockHintKind::TableLike,
        [4, 5, 6],
        0.8,
        "Item Qty Apple 2 Banana 5",
        ["table-like rows", "aligned column candidate"],
      ),
    ],
    warnings: [],
  })
  assert_true(
    out.contains(
      "0\t3\tTableLike\t0.8\t4\t6\tItem Qty Apple 2 Banana 5\ttable-like rows;aligned column candidate",
    ),
  )
}

///|
test "vision ir hints tsv renderer emits keyvaluelike kind" {
  let out = render_ocr_ir_document_hints_tsv({
    block_hints: [
      make_layout_ir_tsv_hint(
        0,
        4,
        OcrIrBlockHintKind::KeyValueLike,
        [7],
        0.9,
        "Total: 123.45",
        ["single-line paragraph"],
      ),
    ],
    warnings: [],
  })
  assert_true(
    out.contains(
      "0\t4\tKeyValueLike\t0.9\t7\t7\tTotal: 123.45\tsingle-line paragraph",
    ),
  )
}

///|
test "vision ir hints tsv renderer emits captionlike kind" {
  let out = render_ocr_ir_document_hints_tsv({
    block_hints: [
      make_layout_ir_tsv_hint(
        0,
        5,
        OcrIrBlockHintKind::CaptionLike,
        [8],
        0.95,
        "Figure 1: System overview",
        ["single-line paragraph"],
      ),
    ],
    warnings: [],
  })
  assert_true(
    out.contains(
      "0\t5\tCaptionLike\t0.95\t8\t8\tFigure 1: System overview\tsingle-line paragraph",
    ),
  )
}

///|
test "vision ir hints tsv renderer escapes tabs and newlines" {
  let out = render_ocr_ir_document_hints_tsv({
    block_hints: [
      make_layout_ir_tsv_hint(
        0,
        0,
        OcrIrBlockHintKind::Unknown,
        [],
        -1.0,
        "Line\tOne\nLine Two",
        ["reason\tone", "reason\ntwo"],
      ),
    ],
    warnings: [],
  })
  assert_true(
    out.contains("Unknown\t-1.0\t\t\tLine One Line Two\treason one;reason two"),
  )
}

///|
test "vision ir hints tsv renderer keeps stable final newline" {
  let out = render_ocr_ir_document_hints_tsv({
    block_hints: [
      make_layout_ir_tsv_hint(
        1,
        2,
        OcrIrBlockHintKind::Heading,
        [9],
        0.9,
        "Heading",
        [],
      ),
    ],
    warnings: [],
  })
  assert_true(out.has_suffix("\n"))
}

///|
fn make_layout_ir_tsv_hint(
  page_index : Int,
  ir_block_index : Int,
  kind : OcrIrBlockHintKind,
  source_line_indices : Array[Int],
  confidence : Double,
  text : String,
  reasons : Array[String],
) -> OcrIrBlockHint {
  {
    page_index,
    ir_block_index,
    kind,
    source_line_indices,
    confidence,
    reasons,
    text,
  }
}
