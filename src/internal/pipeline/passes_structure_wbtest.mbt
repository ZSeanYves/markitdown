///|
test "structure pass promotes heading attrs and signals with clamped levels" {
  let attributed = @core.make_block(Paragraph, "Attributed")
    |> @core.block_with_attr("heading_candidate", "true")
    |> @core.block_with_attr("level", "9")
    |> @core.block_with_attr("custom", "kept")
  let payload : Map[String, @core.JsonValue] = Map([("level", Number("0"))])
  let signaled = @core.make_block(Paragraph, "Signaled")
    |> @core.block_with_signals([
      @core.make_signal(HeadingCandidate, 90, payload~),
    ])
  let existing = @core.make_block(Heading, "Existing")
    |> @core.block_with_attr("level", "invalid")
  let resolved = resolve_heading_blocks([attributed, signaled, existing])
  assert_true(resolved.all(block => block.kind == Heading))
  assert_true(resolved[0].attrs.get("level") == Some("6"))
  assert_true(resolved[0].attrs.get("custom") == Some("kept"))
  assert_true(resolved[1].attrs.get("level") == Some("1"))
  assert_true(resolved[2].attrs.get("level") == Some("1"))
  assert_eq(heading_block_count(resolved), 3)
}

///|
fn structure_list_candidate(
  text : String,
  level : String,
  ordered : Bool,
) -> @core.CoreBlock {
  @core.make_block(Paragraph, text)
  |> @core.block_with_attr("list_item_candidate", "true")
  |> @core.block_with_attr("level", level)
  |> @core.block_with_attr("ordered", if ordered { "true" } else { "false" })
}

///|
test "structure pass groups nested and mixed ordered list candidates" {
  let resolved = resolve_list_blocks([
    structure_list_candidate("root", "0", false),
    structure_list_candidate("nested", "1", false),
    structure_list_candidate("ordered", "1", true),
    structure_list_candidate("root two", "-2", false),
    @core.make_block(Paragraph, "body"),
  ])
  assert_eq(resolved.length(), 2)
  assert_true(resolved[0].kind == List)
  assert_true(resolved[0].attrs.get("ordered") == Some("false"))
  assert_eq(resolved[0].children.length(), 2)
  assert_true(resolved[0].children[0].children.any(child => child.kind == List))
  assert_eq(resolved[1].text, "body")
  assert_true(list_block_count(resolved) >= 3)
}

///|
test "structure pass preserves existing list item with nested list" {
  let nested = @core.make_block(List, "")
  let item = @core.make_block(ListItem, "item")
    |> @core.block_with_children([nested])
  let result = list_item_group_to_blocks([item])
  assert_eq(result.length(), 1)
  assert_true(result[0].kind == ListItem)
  assert_eq(list_item_group_to_blocks([]).length(), 0)
}

///|
test "structure passes preserve input shapes and publish metrics" {
  let context = make_pass_context(false, "balanced")
  let heading = structure_list_candidate("Heading", "1", false)
    |> @core.block_with_attr("heading_level", "2")
  let document = { ..@core.empty_document_ir(), blocks: [heading] }
  match (resolve_heading_pass().run)(context, Document(document)).unwrap() {
    Document(next) => {
      assert_true(next.blocks[0].kind == Heading)
      assert_true(
        next.diagnostics.metrics.get("resolved_heading_count") == Some("1"),
      )
    }
    _ => fail("expected document")
  }
  match
    (resolve_list_pass().run)(
      context,
      BlockStream([structure_list_candidate("item", "0", false)]),
    ).unwrap() {
    BlockStream(blocks) => assert_true(blocks[0].kind == List)
    _ => fail("expected block stream")
  }
  assert_true(
    context.diagnostics.val.metrics.get("resolved_list_count") == Some("1"),
  )
  let event : @core.CoreEvent = { kind: Text, text: "event", source_ref: None }
  match (resolve_list_pass().run)(context, EventStream([event])).unwrap() {
    EventStream(events) => assert_eq(events.length(), 1)
    _ => fail("expected event stream")
  }
}
