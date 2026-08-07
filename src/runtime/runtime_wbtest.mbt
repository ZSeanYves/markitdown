///|
test "runtime converts every parse result public IR shape" {
  let diagnostics = @core.empty_diagnostics()
  let document = @core.empty_document_ir()
  match
    parse_result_to_ir_input(
      @parser.parse_result_with_document(
        "document",
        DomAstModel,
        document,
        diagnostics,
      ),
    ) {
    Document(_) => ()
    _ => fail("expected document IR")
  }
  let block = @core.make_block(Paragraph, "block")
  match
    parse_result_to_ir_input(
      @parser.parse_result_with_blocks(
        "blocks",
        BlockStreaming,
        [block],
        diagnostics,
      ),
    ) {
    BlockStream(blocks) => assert_eq(blocks.length(), 1)
    _ => fail("expected block stream")
  }
  let event : @core.CoreEvent = {
    kind: TextLine,
    text: "event",
    source_ref: None,
  }
  match
    parse_result_to_ir_input(
      @parser.parse_result_with_events(
        "events",
        StreamingEvent,
        [event],
        diagnostics,
      ),
    ) {
    EventStream(events) => assert_eq(events.length(), 1)
    _ => fail("expected event stream")
  }
}

///|
test "runtime diagnostics merge supports unique and append semantics" {
  let left = @core.empty_diagnostics()
    |> @core.diagnostics_with_parser(Some("left"), Some("left-mode"))
    |> @core.diagnostics_add_warning("shared")
    |> @core.diagnostics_add_warning("left")
    |> @core.diagnostics_add_error("left-error")
    |> @core.diagnostics_add_fallback_trace("fallback")
    |> @core.diagnostics_add_metric("same", "left")
  let right = @core.empty_diagnostics()
    |> @core.diagnostics_with_parser(Some("right"), None)
    |> @core.diagnostics_with_input(Some("memory"), Some("html"))
    |> @core.diagnostics_add_warning("shared")
    |> @core.diagnostics_add_warning("right")
    |> @core.diagnostics_add_error("right-error")
    |> @core.diagnostics_add_fallback_trace("fallback")
    |> @core.diagnostics_add_metric("same", "right")
  let unique = merge_diagnostics_unique(left, right)
  assert_true(unique.parser_name == Some("right"))
  assert_true(unique.parser_mode == Some("left-mode"))
  assert_true(unique.input_kind == Some("memory"))
  assert_true(unique.detected_format == Some("html"))
  assert_true(unique.warnings == ["shared", "left", "right"])
  assert_true(unique.errors == ["left-error", "right-error"])
  assert_true(unique.fallback_trace == ["fallback"])
  assert_true(unique.metrics.get("same") == Some("right"))
  let appended = merge_diagnostics_append(left, right)
  assert_true(appended.warnings == ["shared", "left", "shared", "right"])
  assert_true(appended.fallback_trace == ["fallback", "fallback"])
}

///|
fn runtime_document_parser(name : String) -> @parser.Parser {
  @parser.make_parser(
    name,
    DomAstModel,
    @parser.parser_capability(false, false, true),
    fn(_, _) {
      let document = {
        ..@core.empty_document_ir(),
        blocks: [@core.make_block(Paragraph, "document")],
      }
      Ok(
        @parser.parse_result_with_document(
          name,
          DomAstModel,
          document,
          @core.empty_diagnostics(),
        ),
      )
    },
  )
}

///|
fn runtime_block_parser(name : String) -> @parser.Parser {
  @parser.make_parser(
    name,
    BlockStreaming,
    @parser.parser_capability(false, true, true),
    fn(_, _) {
      Ok(
        @parser.parse_result_with_blocks(
          name,
          BlockStreaming,
          [@core.make_block(Paragraph, "block")],
          @core.empty_diagnostics(),
        ),
      )
    },
  )
}

///|
test "runtime child parsing prefers predecoded block stream for markup" {
  let registry = @parser.empty_registry()
  @parser.registry_register(registry, Html, runtime_document_parser("document"))
  @parser.registry_register(registry, Html, runtime_block_parser("blocks"))
  let product = parse_child_to_block_product(
    registry,
    @input.input_from_text("<p>fixture</p>"),
    Html,
    @parser.new_parse_context(Zip),
  ).unwrap()
  assert_eq(product.blocks.length(), 1)
  assert_eq(product.blocks[0].text, "block")
  assert_true(
    product.diagnostics.metrics.get("child_parse_preference") ==
    Some("prefer_block_stream_text_markup"),
  )
  assert_true(
    product.diagnostics.metrics.get("child_parse_fast_path_used") ==
    Some("true"),
  )
  assert_true(
    product.diagnostics.metrics.get("child_parse_predecoded_text_used") ==
    Some("true"),
  )
}

///|
test "runtime child parsing builds events and preserves document fast path" {
  let registry = @parser.empty_registry()
  @parser.registry_register(registry, Json, runtime_document_parser("document"))
  let document = parse_child_to_document(
    registry,
    @input.input_from_text("{}"),
    Json,
    @parser.new_parse_context(Zip),
  ).unwrap()
  assert_eq(document.blocks[0].text, "document")

  let event_parser = @parser.make_parser(
    "events",
    StreamingEvent,
    @parser.parser_capability(true, false, false),
    fn(_, _) {
      let event : @core.CoreEvent = {
        kind: TextLine,
        text: "event child",
        source_ref: Some(@core.empty_source_ref()),
      }
      Ok(
        @parser.parse_result_with_events(
          "events",
          StreamingEvent,
          [event],
          @core.empty_diagnostics(),
        ),
      )
    },
  )
  let event_registry = @parser.empty_registry()
  @parser.registry_register(event_registry, Txt, event_parser)
  let product = parse_child_to_block_product(
    event_registry,
    @input.input_from_text("event child"),
    Txt,
    @parser.new_parse_context(Zip),
  ).unwrap()
  assert_eq(product.blocks[0].text, "event child")
  assert_true(
    product.diagnostics.metrics.get("child_parse_fast_path_used") ==
    Some("false"),
  )
}

///|
test "runtime child parsing propagates missing parser errors and mode options" {
  let registry = @parser.empty_registry()
  let source = @input.input_from_text("fixture")
  let context = @parser.new_parse_context(Zip)
  let blocks = parse_child_to_block_product(registry, source, Markdown, context)
  let block_error = match blocks {
    Err(message) => message.contains("no parser registered")
    Ok(_) => false
  }
  assert_true(block_error)
  let document = parse_child_to_document(registry, source, Txt, context)
  let document_error = match document {
    Err(message) => message.contains("no parser registered")
    Ok(_) => false
  }
  assert_true(document_error)
  assert_true(child_format_prefers_block_stream_text_markup(Markdown))
  let stream_context = @parser.parse_context_with_limits(
    context,
    Some(BlockStreaming),
    None,
    None,
    None,
    None,
    false,
  )
  assert_true(child_product_options(stream_context).mode == Stream)
  let accurate_context = @parser.parse_context_with_product_modes(
    context,
    Accurate,
    Markdown,
  )
  assert_true(child_product_options(accurate_context).mode == Accurate)
}
