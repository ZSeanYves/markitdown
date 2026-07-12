///|
fn registry_fixture_parser(name : String, mode : ParserMode) -> Parser {
  make_parser(name, mode, parser_capability(false, false, true), fn(_, _) {
    Ok(
      parse_result_with_document(
        name,
        mode,
        @core.empty_document_ir(),
        @core.empty_diagnostics(),
      ),
    )
  })
}

///|
test "parser registry preserves default and selects newest mode override" {
  let registry = empty_registry()
  let default = registry_fixture_parser("default", ParserMode::DomAstModel)
  let first_stream = registry_fixture_parser(
    "stream-old",
    ParserMode::BlockStreaming,
  )
  let newest_stream = registry_fixture_parser(
    "stream-new",
    ParserMode::BlockStreaming,
  )
  registry_register(registry, @input.DetectedFormat::Txt, default)
  registry_register(registry, @input.DetectedFormat::Txt, first_stream)
  registry_register(registry, @input.DetectedFormat::Txt, newest_stream)
  assert_true(
    registry_lookup(registry, @input.DetectedFormat::Txt).unwrap().name ==
    "default",
  )
  assert_true(registry_lookup(registry, @input.DetectedFormat::Pdf) is None)

  let source = @input.input_from_text("fixture")
  let default_result = registry_parse(
    registry,
    source,
    new_parse_context(@input.DetectedFormat::Txt),
  )
  assert_true(default_result.unwrap().parser_name == "default")
  let stream_context = {
    ..new_parse_context(@input.DetectedFormat::Txt),
    requested_mode: Some(ParserMode::BlockStreaming),
  }
  let stream_result = registry_parse(registry, source, stream_context)
  assert_true(stream_result.unwrap().parser_name == "stream-new")
  let unmatched_context = {
    ..stream_context,
    requested_mode: Some(ParserMode::StreamingEvent),
  }
  assert_true(
    registry_parse(registry, source, unmatched_context).unwrap().parser_name ==
    "default",
  )
}

///|
test "parser registry returns controlled missing-format errors" {
  let result = registry_parse(
    empty_registry(),
    @input.input_from_text("fixture"),
    new_parse_context(@input.DetectedFormat::Json),
  )
  let missing_error = match result {
    Err(message) => message == "no parser registered for format: json"
    Ok(_) => false
  }
  assert_true(missing_error)
  assert_eq(registry_key(@input.DetectedFormat::Markdown), "markdown")
  let sync_registry = empty_registry()
  registry_register(
    sync_registry,
    @input.DetectedFormat::Txt,
    registry_fixture_parser("sync", ParserMode::DomAstModel),
  )
  let registry = async_registry_from_sync(sync_registry)
  assert_true(
    async_registry_lookup(registry, @input.DetectedFormat::Txt).unwrap().name ==
    "sync",
  )
  assert_true(
    async_registry_lookup(registry, @input.DetectedFormat::Pdf) is None,
  )

  let async_registry = empty_async_registry()
  let first = make_async_parser(
    "first",
    ParserMode::DomAstModel,
    default_parser_capability(),
    fn(_, _) {
      Ok(
        parse_result_with_document(
          "first",
          ParserMode::DomAstModel,
          @core.empty_document_ir(),
          @core.empty_diagnostics(),
        ),
      )
    },
  )
  let stream = make_async_parser(
    "stream",
    ParserMode::BlockStreaming,
    parser_capability(false, true, true),
    fn(_, _) {
      Ok(
        parse_result_with_blocks(
          "stream",
          ParserMode::BlockStreaming,
          [],
          @core.empty_diagnostics(),
        ),
      )
    },
  )
  async_registry_register(async_registry, @input.DetectedFormat::Txt, first)
  async_registry_register(async_registry, @input.DetectedFormat::Txt, stream)
  assert_true(
    async_registry_lookup_for_context(async_registry, {
      ..new_parse_context(@input.DetectedFormat::Txt),
      requested_mode: Some(ParserMode::BlockStreaming),
    }).unwrap().name ==
    "stream",
  )
  assert_true(
    async_registry_lookup_for_context(
      async_registry,
      new_parse_context(@input.DetectedFormat::Txt),
    ).unwrap().name ==
    "first",
  )
  assert_true(
    !parser_matches_requested_mode(
      registry_fixture_parser("default", ParserMode::DomAstModel),
      None,
    ),
  )
}

///|
test "parser stable names cover disabled policies and all granularities" {
  assert_eq(ocr_intent_name(OcrIntent::Disabled), "disabled")
  assert_eq(
    pdf_native_runtime_policy_name(PdfNativeRuntimePolicy::DisableTextRestore),
    "disable_text_restore",
  )
  let granularities : Array[StreamingGranularity] = [
    StreamingGranularity::Byte,
    StreamingGranularity::Line,
    StreamingGranularity::Record,
    StreamingGranularity::Row,
    StreamingGranularity::JsonStructure,
    StreamingGranularity::NotebookCellOutputGroup,
    StreamingGranularity::XmlStructure,
    StreamingGranularity::YamlStructure,
    StreamingGranularity::HtmlTokenStructure,
    StreamingGranularity::MarkdownBlock,
    StreamingGranularity::DocxBlock,
    StreamingGranularity::PptxSlide,
    StreamingGranularity::XlsxSheet,
    StreamingGranularity::XlsxRow,
    StreamingGranularity::ArchiveEntry,
    StreamingGranularity::EpubSpineItem,
    StreamingGranularity::Block,
    StreamingGranularity::Page,
    StreamingGranularity::Slide,
    StreamingGranularity::Sheet,
    StreamingGranularity::Chapter,
    StreamingGranularity::Message,
    StreamingGranularity::None,
  ]
  for granularity in granularities {
    assert_true(streaming_granularity_name(granularity) != "")
  }
}
