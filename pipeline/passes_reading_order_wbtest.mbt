///|
fn reading_order_test_block(
  kind : @core.BlockKind,
  text : String,
  format : String,
  reading_order_key : String,
) -> @core.CoreBlock {
  let source_ref = @core.source_ref_with_extra(
    @core.source_ref_with_office_fields(
      @core.source_ref_with_container_entry(
        @core.empty_source_ref(),
        Some("deck." + format),
        Some(format),
        Some("deck." + format),
        Some("ppt/slides/slide1.xml"),
        None,
        Some(format),
        Some(text),
      ),
      Some("deck." + format),
      Some(format),
      Some(text),
      None,
      None,
      Some(1),
      None,
      None,
    ),
    "reading_order_key",
    reading_order_key,
  )
  @core.make_block(kind, text, source_ref~)
}

///|
fn assert_block_text_order(
  blocks : Array[@core.CoreBlock],
  expected : Array[String],
) -> Unit raise {
  assert_eq(blocks.length(), expected.length())
  for i in 0..<expected.length() {
    assert_eq(blocks[i].text, expected[i])
  }
}

///|
fn sample_reading_order_blocks(format : String) -> Array[@core.CoreBlock] {
  [
    reading_order_test_block(
      @core.BlockKind::Paragraph,
      "Test text",
      format,
      "030:0002924944:0005580112:00004:shape-7",
    ),
    reading_order_test_block(
      @core.BlockKind::Paragraph,
      "Group test text",
      format,
      "030:0004581128:0005580112:00002:group-11/shape-10",
    ),
    reading_order_test_block(
      @core.BlockKind::Image,
      "group-image",
      format,
      "050:0003645024:0005580112:00001:group-11/picture-9",
    ),
    reading_order_test_block(
      @core.BlockKind::Paragraph,
      "Box 1",
      format,
      "030:0005517232:0005652120:00006:shape-12",
    ),
    reading_order_test_block(
      @core.BlockKind::Paragraph,
      "Box 2",
      format,
      "030:0005517232:0007668344:00007:shape-13",
    ),
    reading_order_test_block(
      @core.BlockKind::Image,
      "top-image",
      format,
      "050:0001988840:0005580112:00003:picture-6",
    ),
  ]
}

///|
test "reading order pass keeps pptx lowering order stable" {
  let resolved = resolve_reading_order_blocks(
    sample_reading_order_blocks("pptx"),
  )
  assert_block_text_order(resolved, [
    "Test text", "Group test text", "group-image", "Box 1", "Box 2", "top-image",
  ])
}

///|
test "reading order pass still reorders non-pptx reading hints" {
  let resolved = resolve_reading_order_blocks(
    sample_reading_order_blocks("png"),
  )
  assert_block_text_order(resolved, [
    "Test text", "Group test text", "Box 1", "Box 2", "top-image", "group-image",
  ])
}

///|
fn pdf_line_block(
  text : String,
  group : String,
  index : String,
  line : Int,
  bbox : @core.BBox?,
) -> @core.CoreBlock {
  let source_ref = {
    ..@core.empty_source_ref(),
    file_id: Some("fixture.pdf"),
    format: Some("pdf"),
    page: Some(1),
    line_start: Some(line),
    line_end: Some(line),
    bbox,
  }
  source_ref.extra.set("pdf_merge_group", group)
  source_ref.extra.set("reading_order_index", index)
  @core.make_block(@core.BlockKind::Paragraph, text, source_ref~)
}

///|
test "reading order pass merges compatible PDF lines and provenance" {
  let first = pdf_line_block(
    "hyphen-",
    "group",
    "1",
    3,
    Some({ x0: 10.0, y0: 20.0, x1: 30.0, y1: 40.0 }),
  )
  let second = pdf_line_block(
    "ated",
    "group",
    "1",
    4,
    Some({ x0: 5.0, y0: 25.0, x1: 35.0, y1: 50.0 }),
  )
  let merged = merge_text_line_blocks([first, second])
  assert_eq(merged.length(), 1)
  assert_eq(merged[0].text, "hyphenated")
  let source_ref = merged[0].source_ref.unwrap()
  assert_true(source_ref.line_start == Some(3))
  assert_true(source_ref.line_end == Some(4))
  assert_true(source_ref.bbox.unwrap().x0 == 5.0)
  assert_true(source_ref.bbox.unwrap().y1 == 50.0)
  assert_eq(merged_text_line_count([first, second], merged), 1)
}

///|
test "reading order pass refuses unsafe PDF line merges" {
  let base = pdf_line_block("base", "group", "1", 1, None)
  let different_group = pdf_line_block("other", "other", "1", 2, None)
  let different_index = pdf_line_block("index", "group", "2", 2, None)
  let different_page_ref = {
    ..different_index.source_ref.unwrap(),
    page: Some(2),
  }
  let different_page = {
    ..different_index,
    source_ref: Some(different_page_ref),
  }
  let header = pdf_line_block("header", "group", "1", 2, None)
    |> @core.block_with_attr("header_footer_candidate", "true")
  assert_eq(merge_text_line_blocks([base, different_group]).length(), 2)
  assert_eq(merge_text_line_blocks([base, different_index]).length(), 2)
  assert_eq(merge_text_line_blocks([base, different_page]).length(), 2)
  assert_eq(merge_text_line_blocks([base, header]).length(), 2)
  assert_eq(merge_text_line_strings("", " right "), "right ")
  assert_eq(merge_text_line_strings(" left ", ""), " left")
  assert_eq(merge_text_line_strings("left", "right"), "left right")
}

///|
test "reading order header footer cleanup honors debug and signals" {
  let attr_candidate = @core.make_block(@core.BlockKind::Paragraph, "header")
    |> @core.block_with_attr("header_footer_candidate", "true")
  let signal_candidate = @core.make_block(@core.BlockKind::Paragraph, "footer")
    |> @core.block_with_signals([
      @core.make_signal(@core.SignalType::HeaderFooterCandidate, 100),
    ])
  let body = @core.make_block(@core.BlockKind::Paragraph, "body")
  let removed = remove_header_footer_blocks(
    [attr_candidate, body, signal_candidate],
    true,
    false,
  )
  assert_eq(removed.0.length(), 1)
  assert_eq(removed.1, 2)
  let debug = remove_header_footer_blocks(
    [attr_candidate, signal_candidate],
    true,
    true,
  )
  assert_eq(debug.0.length(), 2)
  assert_eq(debug.1, 0)
  assert_true(debug.0[1].attrs.get("header_footer_candidate") == Some("true"))
}

///|
test "reading order passes preserve IR shapes and publish metrics" {
  let context = make_pass_context(false, "balanced", pdf_cleanup_enabled=true)
  let blocks = [
    pdf_line_block("one", "group", "1", 1, None),
    pdf_line_block("two", "group", "1", 2, None),
  ]
  let merged = (merge_text_line_pass().run)(
    context,
    @core.IRInput::BlockStream(blocks),
  ).unwrap()
  match merged {
    @core.IRInput::BlockStream(items) => assert_eq(items.length(), 1)
    _ => fail("expected block stream")
  }
  assert_true(
    context.diagnostics.val.metrics.get("merged_text_line_count") == Some("1"),
  )
  let event : @core.CoreEvent = {
    kind: @core.EventKind::Text,
    text: "event",
    source_ref: None,
  }
  match
    (resolve_reading_order_pass().run)(
      context,
      @core.IRInput::EventStream([event]),
    ).unwrap() {
    @core.IRInput::EventStream(events) => assert_eq(events.length(), 1)
    _ => fail("expected event stream")
  }
  let document = {
    ..@core.empty_document_ir(),
    blocks: [
      @core.make_block(@core.BlockKind::Paragraph, "header")
      |> @core.block_with_attr("header_footer_candidate", "true"),
    ],
  }
  match
    (remove_header_footer_pass().run)(
      context,
      @core.IRInput::Document(document),
    ).unwrap() {
    @core.IRInput::Document(next) => {
      assert_eq(next.blocks.length(), 0)
      assert_true(
        next.diagnostics.metrics.get("removed_header_footer_count") == Some("1"),
      )
    }
    _ => fail("expected document")
  }
}

///|
test "reading order optional geometry helpers cover absent bounds" {
  let bbox : @core.BBox = { x0: 1.0, y0: 2.0, x1: 3.0, y1: 4.0 }
  assert_true(merge_source_bbox(Some(bbox), None).unwrap().x0 == 1.0)
  assert_true(merge_source_bbox(None, Some(bbox)).unwrap().y1 == 4.0)
  assert_true(merge_source_bbox(None, None) is None)
  assert_true(min_optional_int(Some(2), Some(1)) == Some(1))
  assert_true(min_optional_int(Some(2), None) == Some(2))
  assert_true(min_optional_int(None, Some(1)) == Some(1))
  assert_true(min_optional_int(None, None) is None)
  assert_true(max_optional_int(Some(2), Some(1)) == Some(2))
  assert_true(max_optional_int(Some(2), None) == Some(2))
  assert_true(max_optional_int(None, Some(1)) == Some(1))
  assert_true(max_optional_int(None, None) is None)
  assert_eq(left_pad_numeric_string("-2", 4), "-0002")
}
