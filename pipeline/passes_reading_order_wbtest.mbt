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
