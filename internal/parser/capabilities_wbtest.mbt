///|
test "parser capability convenience builder selects primary shape" {
  let events = parser_capability(true, false, false)
  assert_true(events.parser_mode == StreamingEvent)
  assert_true(events.streaming_granularity == Record)
  assert_true(events.supports_events)
  assert_true(events.supports_streaming)

  let blocks = parser_capability(false, true, false)
  assert_true(blocks.parser_mode == BlockStreaming)
  assert_true(blocks.streaming_granularity == Block)
  assert_true(blocks.supports_blocks)

  let document = parser_capability(false, false, true)
  assert_true(document.parser_mode == DomAstModel)
  assert_true(document.streaming_granularity == None)
  assert_true(document.supports_document_ir)
  assert_true(!document.supports_streaming)
}

///|
test "parser capability specialized builders retain route contracts" {
  let baseline = default_parser_capability()
  assert_true(baseline.parser_mode == DomAstModel)
  assert_true(baseline.requires_random_access)
  assert_true(baseline.can_be_lossless)

  let dom = dom_ast_parser_capability(
    Page,
    true,
    true,
    true,
    true,
    false,
    true,
    true,
    false,
    true,
    false,
  )
  assert_true(dom.parser_mode == DomAstModel)
  assert_true(dom.supports_events && dom.supports_blocks)
  assert_true(dom.produces_tables && !dom.produces_images)

  let block = block_stream_parser_capability(
    Row,
    true,
    false,
    true,
    true,
    false,
    true,
    false,
  )
  assert_true(block.parser_mode == BlockStreaming)
  assert_true(block.supports_blocks && block.supports_document_ir)

  let event = streaming_event_parser_capability(
    Line,
    false,
    false,
    false,
    true,
    true,
    true,
    false,
    false,
  )
  assert_true(event.parser_mode == StreamingEvent)
  assert_true(event.supports_events && !event.supports_document_ir)

  let package_capability = package_with_block_route_parser_capability(
    ArchiveEntry,
    true,
    true,
    true,
    true,
    false,
    true,
    true,
    true,
    false,
    true,
  )
  assert_true(package_capability.parser_mode == PackageSinglePass)
  assert_true(
    package_capability.requires_random_access &&
    package_capability.source_single_pass_strict,
  )

  let container = container_recursive_parser_capability(
    ArchiveEntry,
    true,
    false,
    true,
    true,
    true,
    true,
    false,
    true,
    true,
  )
  assert_true(container.parser_mode == ContainerRecursive)
  assert_true(container.supports_streaming && container.supports_blocks)
}
