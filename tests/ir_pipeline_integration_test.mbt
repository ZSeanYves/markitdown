///|
test "convert pipeline preserves representative parser irinput contracts" {
  let txt = convert_memory_text(
    "Alpha\n\nBeta",
    "contract.txt",
    @input.DetectedFormat::Txt,
  )
  let json = convert_memory_text(
    "{\"name\":\"Alice\"}\n",
    "contract.json",
    @input.DetectedFormat::Json,
  )
  let html = convert_memory_text(
    "<html><body><section><h2>One</h2><p>A</p></section><section><h2>Two</h2><p>B</p></section></body></html>",
    "contract.html",
    @input.DetectedFormat::Html,
    limits=limits(1, 50, 100000),
  )
  assert_true(txt.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_metric_eq(txt.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(txt.diagnostics, "builder_input_kind", "event_stream")
  assert_true(json.parser_mode == @parser.ParserMode::DomAstModel)
  assert_metric_eq(json.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(json.diagnostics, "builder_input_kind", "document")
  assert_true(html.parser_mode == @parser.ParserMode::BlockStreaming)
  assert_metric_eq(html.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(html.diagnostics, "builder_input_kind", "block_stream")
}

///|
test "irinput three-shape contract stays explicit" {
  let builder = @pipeline.default_ir_builder()
  let event_doc = (builder.build)(
    @core.IRInput::EventStream([
      {
        kind: @core.EventKind::Cell,
        text: "A",
        source_ref: Some(
          @core.source_ref_with_cell_range(
            @core.source_ref_with_lines(
              @core.empty_source_ref(),
              Some("t.csv"),
              Some("csv"),
              Some(1),
              Some(1),
            ),
            Some("t.csv"),
            Some("csv"),
            Some("R1C1"),
          ),
        ),
      },
      {
        kind: @core.EventKind::Cell,
        text: "B",
        source_ref: Some(
          @core.source_ref_with_cell_range(
            @core.source_ref_with_lines(
              @core.empty_source_ref(),
              Some("t.csv"),
              Some("csv"),
              Some(1),
              Some(1),
            ),
            Some("t.csv"),
            Some("csv"),
            Some("R1C2"),
          ),
        ),
      },
      {
        kind: @core.EventKind::RowBreak,
        text: "",
        source_ref: Some(
          @core.source_ref_with_cell_range(
            @core.source_ref_with_lines(
              @core.empty_source_ref(),
              Some("t.csv"),
              Some("csv"),
              Some(1),
              Some(1),
            ),
            Some("t.csv"),
            Some("csv"),
            Some("R1C1:R1C2"),
          ),
        ),
      },
    ]),
  )
  let block_doc = (builder.build)(
    @core.IRInput::BlockStream([
      @core.make_block(
        @core.BlockKind::Paragraph,
        "Body",
        source_ref=@core.empty_source_ref(),
      ),
    ]),
  )
  let document_doc = (builder.build)(
    @core.IRInput::Document(
      @core.document_from_blocks([
        @core.make_block(
          @core.BlockKind::Paragraph,
          "Doc",
          source_ref=@core.empty_source_ref(),
        ),
      ]),
    ),
  )
  assert_true(event_doc.blocks.length() == 1)
  assert_true(event_doc.blocks[0].kind == @core.BlockKind::Table)
  assert_true(
    block_doc.diagnostics.metrics.get("builder_input_kind") ==
    Some("block_stream"),
  )
  assert_true(
    document_doc.diagnostics.metrics.get("builder_input_kind") ==
    Some("document"),
  )
}

///|
test "convert route planner emits canonical route diagnostics" {
  let result = convert_memory_text(
    "Alpha\nBeta\n",
    "route.txt",
    @input.DetectedFormat::Txt,
  )
  assert_metric_eq(result.diagnostics, "selected_route", "streaming_event")
  assert_metric_eq(
    result.diagnostics,
    "route_reason",
    "txt_canonical_streaming_event",
  )
  assert_true(
    result.diagnostics.metrics.get("route_probe_summary") ==
    Some("route_probe:txt:streaming_event"),
  )
  assert_true(result.diagnostics.same_mode_degradation.length() == 0)
}
