///|
test "docx marker spacing inlines do not inherit note ref metadata" {
  let note_ref = @core.empty_source_ref()
  let note_inline = @core.inline_with_attr(
    @core.inline_with_attr(
      @core.inline_with_attr(
        @core.inline_with_attr(
          @core.inline_with_attr(
            @core.make_inline_text("[^1]", source_ref=note_ref),
            "annotation_role",
            "note_ref",
          ),
          "annotation_kind",
          "footnote",
        ),
        "annotation_id",
        "1",
      ),
      "annotation_marker",
      "[^1]",
    ),
    "render_literal",
    "true",
  )
  let block = @core.block_with_rich_inlines(
    @core.make_block(@core.BlockKind::Paragraph, ""),
    Some([
      @core.make_inline_text("Body "),
      note_inline,
      @core.make_inline_text("tail"),
    ]),
  )
  let normalized = normalize_docx_marker_rich_inlines(
    block.rich_inlines.unwrap_or([]),
  )
  assert_eq(normalized.length(), 4)
  let spacing = normalized[2]
  assert_true(spacing.text == " ")
  assert_true(spacing.attrs.length() == 0)
}
