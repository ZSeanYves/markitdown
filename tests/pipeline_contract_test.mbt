///|
test "txt parser mode is visible and parser does not directly return markdown" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "# line 1\n\n> line 2",
      "x.txt",
      Some(@input.DetectedFormat::Txt),
    ),
    @input.DetectedFormat::Txt,
  )
  assert_true(parsed.mode == @parser.ParserMode::StreamingEvent)
  assert_true(parsed.document is None)
  assert_true(parsed.block_stream is None)
  assert_true(parsed.event_stream is Some(_))
  assert_true(parsed.diagnostics.parser_name == Some("txt_parser"))
  assert_metric_eq(parsed.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "event_stream")
  let events = parsed.event_stream.unwrap_or([])
  assert_true(events.length() == 3)
  assert_true(events[0].kind == @core.EventKind::TextLine)
  assert_eq(events[0].text, "# line 1")
  assert_true(events[1].kind == @core.EventKind::BlankLine)
  assert_eq(events[2].text, "> line 2")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "line")
  assert_metric_eq(parsed.diagnostics, "event_semantics", "line_event_stream")
  assert_metric_not_eq(parsed.diagnostics, "event_granularity", "paragraph")
  assert_metric_not_eq(
    parsed.diagnostics,
    "event_semantics",
    "paragraph_event_stream",
  )
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "paragraph_event_stream",
  ])
}

///|
test "txt stream convert mode uses event path without markdown as intermediate" {
  let result = convert_memory_text(
    "Alpha\n\nBeta",
    "stream.txt",
    @input.DetectedFormat::Txt,
    mode=@convert.ConvertMode::Stream,
  )
  assert_eq(result.content, "Alpha\n\nBeta")
  assert_true(result.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(
    result.diagnostics.metrics.get("ir_input_kind") == Some("event_stream"),
  )
  assert_true(
    result.diagnostics.metrics.get("builder_input_kind") == Some("event_stream"),
  )
  assert_true(
    !result.diagnostics.pass_trace.contains("builder:default_ir_builder"),
  )
  assert_true(
    contains_trace_in_order(result.diagnostics.pass_trace, [
      "detect:", "registry:lookup", "parse:txt_parser", "render:MarkdownRenderer",
    ]),
  )
}

///|
test "markdown parser mode and source refs are visible" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "# Title\n\nBody\n",
      "demo.md",
      Some(@input.DetectedFormat::Markdown),
    ),
    @input.DetectedFormat::Markdown,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  let blocks = document.blocks
  assert_true(parsed.mode == @parser.ParserMode::DomAstModel)
  assert_true(parsed.document is Some(_))
  assert_true(parsed.event_stream is None)
  assert_true(blocks.length() >= 2)
  assert_true(blocks[0].source_ref is Some(_))
  let src = blocks[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(src.file_id == Some("demo.md"))
  assert_true(src.format == Some("markdown"))
  assert_true(src.line_start == Some(1))
  assert_true(src.line_end == Some(1))
  assert_true(src.markdown_path is Some(_))
  assert_metric_eq(parsed.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "markdown_block")
  assert_true(
    parsed.diagnostics.metrics.get("product_path_enabled") == Some("true"),
  )
  assert_true(
    parsed.diagnostics.metrics.get("format_contract") == Some("markdown"),
  )
}

///|
test "markdown large input switches to true block-structured event stream" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "# Title\n\nParagraph\n\n- one\n- two\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n",
      "large.md",
      Some(@input.DetectedFormat::Markdown),
    ),
    @input.DetectedFormat::Markdown,
    requested_mode=Some(@parser.ParserMode::BlockStreaming),
  )
  assert_true(parsed.mode == @parser.ParserMode::BlockStreaming)
  assert_true(parsed.document is None)
  assert_true(parsed.block_stream is Some(_))
  assert_true(parsed.event_stream is None)
  assert_metric_eq(parsed.diagnostics, "effective_mode", "block_streaming")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "markdown_block")
  assert_metric_eq(
    parsed.diagnostics,
    "event_semantics",
    "markdown_block_stream",
  )
  assert_metric_absent(parsed.diagnostics, "streaming_fallback")
  assert_metric_eq(parsed.diagnostics, "resource_limit_hit", "false")
  assert_metric_eq(parsed.diagnostics, "block_limit_reached", "false")
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "markdown_streaming_fallback=deferred", "large_markdown_raw_fallback",
  ])
  let blocks = parsed.block_stream.unwrap_or([])
  assert_true(blocks.length() > 0)
  let first = blocks[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(first.format == Some("markdown"))
  assert_true(first.markdown_path is Some(_))
}

///|
test "markdown footnotes normalize missing refs and keep definition bodies" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "Body[^1] and missing[^6].\n\n[^1]: Footnote that ends with a list:\n\n    * item 1\n    * item 2\n\n[^d]:\n    _emphasis works_\n\n    _emphasis still works_\n\n[^e]: \n    1.  The top couple half figure, contrary sides and hands across with bottom couple,\n",
      "footnote-extra.md",
      Some(@input.DetectedFormat::Markdown),
    ),
    @input.DetectedFormat::Markdown,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(rendered.content.contains("Body[^1] and missing^6."))
  assert_true(!rendered.content.contains("missing[^6]."))
  assert_true(
    rendered.content.contains("[^1]: Footnote that ends with a list:"),
  )
  assert_true(rendered.content.contains("[^d]: _emphasis works_"))
  assert_true(
    rendered.content.contains(
      "[^e]: 1.  The top couple half figure, contrary sides and hands across with bottom couple,",
    ),
  )
  assert_metric_eq(parsed.diagnostics, "footnote_definition_count", "3")
  assert_metric_eq(parsed.diagnostics, "footnote_reference_count", "1")
  assert_true(
    document.blocks[1].attrs.get("raw_kind") ==
    Some("markdown_footnote_definition"),
  )
}

///|
test "csv and tsv parser mode contract stays streaming event" {
  let csv = default_registry_parse(
    @input.input_from_text_with_format(
      "a,b\n1,2\n",
      "demo.csv",
      Some(@input.DetectedFormat::Csv),
    ),
    @input.DetectedFormat::Csv,
  )
  let tsv = default_registry_parse(
    @input.input_from_text_with_format(
      "a\tb\n1\t2\n",
      "demo.tsv",
      Some(@input.DetectedFormat::Tsv),
    ),
    @input.DetectedFormat::Tsv,
  )
  assert_true(csv.mode == @parser.ParserMode::StreamingEvent)
  assert_true(tsv.mode == @parser.ParserMode::StreamingEvent)
  assert_true(csv.document is None)
  assert_true(tsv.document is None)
  assert_true(csv.block_stream is None)
  assert_true(tsv.block_stream is None)
  assert_true(csv.event_stream is Some(_))
  assert_true(tsv.event_stream is Some(_))
  assert_true(csv.diagnostics.parser_name == Some("csv_parser"))
  assert_true(tsv.diagnostics.parser_name == Some("tsv_parser"))
  assert_metric_eq(csv.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(csv.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(csv.diagnostics, "event_granularity", "row")
  assert_metric_eq(csv.diagnostics, "event_semantics", "row_cell_event_stream")
  assert_metric_eq(tsv.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(tsv.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(tsv.diagnostics, "event_granularity", "row")
  assert_metric_eq(tsv.diagnostics, "event_semantics", "row_cell_event_stream")
  let csv_events = csv.event_stream.unwrap_or([])
  let tsv_events = tsv.event_stream.unwrap_or([])
  assert_eq(csv_events[0].text, "a")
  assert_eq(tsv_events[0].text, "a")
}

///|
test "json lite parser mode and json pointer contract are visible" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "{\"name\":\"alice\"}",
      "demo.json",
      Some(@input.DetectedFormat::Json),
    ),
    @input.DetectedFormat::Json,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(parsed.mode == @parser.ParserMode::DomAstModel)
  assert_true(parsed.event_stream is None)
  assert_true(document.blocks.length() == 1)
  assert_metric_eq(parsed.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "none")
  assert_metric_eq(parsed.diagnostics, "event_semantics", "dom_ast_model")
  assert_metric_not_eq(parsed.diagnostics, "effective_mode", "streaming_event")
  let src = document.blocks[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(src.file_id == Some("demo.json"))
  assert_true(src.format == Some("json"))
  assert_true(src.json_pointer == Some("/"))
  assert_true(document.blocks[0].kind == @core.BlockKind::Table)
  assert_true(document.blocks[0].children.length() >= 2)
}

///|
test "jsonl and ndjson parser modes stay streaming event with line refs" {
  let jsonl = default_registry_parse(
    @input.input_from_text_with_format(
      "{\"name\":\"Alice\",\"score\":7}\n{\"name\":\"Bob\",\"score\":9}\n",
      "demo.jsonl",
      Some(@input.DetectedFormat::Jsonl),
    ),
    @input.DetectedFormat::Jsonl,
  )
  let ndjson = default_registry_parse(
    @input.input_from_text_with_format(
      "{\"name\":\"Carol\",\"score\":5}\n{\"name\":\"Dave\",\"score\":8}\n",
      "demo.ndjson",
      Some(@input.DetectedFormat::Ndjson),
    ),
    @input.DetectedFormat::Ndjson,
  )
  assert_true(jsonl.mode == @parser.ParserMode::StreamingEvent)
  assert_true(ndjson.mode == @parser.ParserMode::StreamingEvent)
  assert_metric_eq(jsonl.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(jsonl.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(jsonl.diagnostics, "event_granularity", "record")
  assert_metric_eq(jsonl.diagnostics, "event_semantics", "record_event_stream")
  assert_metric_eq(ndjson.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(ndjson.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(ndjson.diagnostics, "event_granularity", "record")
  assert_metric_eq(ndjson.diagnostics, "event_semantics", "record_event_stream")
  let jsonl_events = jsonl.event_stream.unwrap_or([])
  let ndjson_events = ndjson.event_stream.unwrap_or([])
  assert_true(jsonl_events.length() > 0)
  assert_true(ndjson_events.length() > 0)
  let src = jsonl_events[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(src.format == Some("jsonl"))
  assert_true(src.line_start == Some(1))
  assert_true(src.json_pointer == Some("/header"))
  assert_true(src.extra.get("synthetic_header") == Some("true"))
  let mut first_jsonl_data = @core.empty_source_ref()
  for event in jsonl_events {
    let source_ref = event.source_ref.unwrap_or(@core.empty_source_ref())
    if source_ref.extra.get("record_index") == Some("0") {
      first_jsonl_data = source_ref
      break
    }
  }
  assert_true(first_jsonl_data.json_pointer == Some("/0"))
  assert_true(first_jsonl_data.line_start == Some(1))
  assert_true(first_jsonl_data.extra.get("record_index") == Some("0"))
  let ndsrc = ndjson_events[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(ndsrc.format == Some("ndjson"))
  assert_true(ndsrc.line_start == Some(1))
  assert_true(ndsrc.json_pointer == Some("/header"))
}

///|
test "jsonl mixed schema fallback keeps fenced info without pipeline source format inference" {
  let result = convert_memory_text(
    "{\"name\":\"Alice\",\"score\":7}\n[1,2,3]\n",
    "mixed.jsonl",
    @input.DetectedFormat::Jsonl,
  )
  assert_true(result.content.contains("| name | score |"))
  assert_true(result.content.contains("```jsonl\n[1,2,3]\n```"))
}

///|
test "json invalid input falls back with diagnostics and no silent success" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "{\"name\":",
      "broken.json",
      Some(@input.DetectedFormat::Json),
    ),
    @input.DetectedFormat::Json,
  )
  assert_true(parsed.mode == @parser.ParserMode::DomAstModel)
  assert_true(parsed.document is Some(_))
  assert_true(parsed.event_stream is None)
  assert_true(parsed.diagnostics.metrics.get("json_valid") == Some("false"))
  assert_true(
    parsed.diagnostics.metrics.get("invalid_record_count") == Some("1"),
  )
  assert_true(
    parsed.diagnostics.degraded_features.contains("json_raw_fenced_fallback"),
  )
}

///|
test "ndjson invalid input falls back with line-aware diagnostics" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "{\"name\":\"ok\"}\n{\"name\":\n",
      "broken.ndjson",
      Some(@input.DetectedFormat::Ndjson),
    ),
    @input.DetectedFormat::Ndjson,
  )
  assert_true(parsed.document is Some(_))
  assert_true(parsed.mode == @parser.ParserMode::StreamingEvent)
  assert_true(parsed.diagnostics.metrics.get("json_valid") == Some("false"))
  assert_true(
    parsed.diagnostics.metrics.get("effective_mode") == Some("streaming_event"),
  )
  assert_true(
    parsed.diagnostics.warnings[0].contains("invalid ndjson record at line 2"),
  )
}

///|
test "jsonl and ndjson blank lines stay observable without becoming silent records" {
  let jsonl = default_registry_parse(
    @input.input_from_text_with_format(
      "{\"name\":\"Alice\"}\n\n{\"name\":\"Bob\"}\n",
      "blank-lines.jsonl",
      Some(@input.DetectedFormat::Jsonl),
    ),
    @input.DetectedFormat::Jsonl,
  )
  let ndjson = default_registry_parse(
    @input.input_from_text_with_format(
      "{\"name\":\"Carol\"}\n\n{\"name\":\"Dave\"}\n",
      "blank-lines.ndjson",
      Some(@input.DetectedFormat::Ndjson),
    ),
    @input.DetectedFormat::Ndjson,
  )
  assert_metric_eq(jsonl.diagnostics, "record_count", "2")
  assert_metric_eq(jsonl.diagnostics, "blank_line_count", "2")
  assert_metric_eq(jsonl.diagnostics, "warning_count", "1")
  assert_true(
    jsonl.diagnostics.degraded_features.contains("jsonl_blank_line_skipped"),
  )
  assert_true(
    jsonl.diagnostics.warnings[0].contains("blank jsonl line(s) skipped: 2"),
  )
  assert_metric_eq(ndjson.diagnostics, "record_count", "2")
  assert_metric_eq(ndjson.diagnostics, "blank_line_count", "2")
  assert_metric_eq(ndjson.diagnostics, "warning_count", "1")
  assert_true(
    ndjson.diagnostics.degraded_features.contains("ndjson_blank_line_skipped"),
  )
  assert_true(
    ndjson.diagnostics.warnings[0].contains("blank ndjson line(s) skipped: 2"),
  )
}

///|
test "jsonl and ndjson normalize record bom and text sequence prefixes" {
  let jsonl = convert_memory_text(
    "\u{FEFF}{\"a\":1}\n\u{001E}{\"b\":2}\n",
    "normalized.jsonl",
    @input.DetectedFormat::Jsonl,
  )
  let ndjson = convert_memory_text(
    "\u{001E}{\"name\":\"Alice\",\"score\":7}\n\u{FEFF}{\"name\":\"Bob\",\"score\":9}\n",
    "normalized.ndjson",
    @input.DetectedFormat::Ndjson,
  )
  assert_true(jsonl.content.contains("| a |"))
  assert_true(jsonl.content.contains("```jsonl\n{\"b\":2}\n```"))
  assert_true(ndjson.content.contains("| name | score |"))
  assert_true(ndjson.content.contains("| Alice | 7 |"))
  assert_true(ndjson.content.contains("| Bob | 9 |"))
}

///|
test "json large input switches to true streaming event path" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "{\"a\":1,\"b\":2}",
      "large.json",
      Some(@input.DetectedFormat::Json),
    ),
    @input.DetectedFormat::Json,
    requested_mode=Some(@parser.ParserMode::StreamingEvent),
  )
  assert_true(parsed.mode == @parser.ParserMode::StreamingEvent)
  assert_true(parsed.document is None)
  assert_true(parsed.block_stream is None)
  assert_true(parsed.event_stream is Some(_))
  assert_metric_absent(parsed.diagnostics, "streaming_fallback")
  assert_metric_eq(parsed.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(parsed.diagnostics, "dom_limit_reached", "false")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "json_structure")
  assert_metric_eq(
    parsed.diagnostics,
    "event_semantics",
    "json_structure_event_stream",
  )
  assert_metric_not_eq(parsed.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_absent(parsed.diagnostics, "streaming_fallback")
  assert_true(
    !parsed.diagnostics.degraded_features.contains("json_raw_fenced_fallback"),
  )
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "deferred_streaming_fallback", "streaming_fallback=deferred", "large_json_raw_fallback",
    "paragraph_event_stream",
  ])
  assert_true(parsed.diagnostics.metrics.get("json_token_count") != Some("0"))
  let events = parsed.event_stream.unwrap_or([])
  let first = events[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(first.format == Some("json"))
  assert_true(first.json_pointer == Some("/"))
  assert_true(first.byte_end is Some(_))
}

///|
test "xml small input stays dom ast model with xpath source refs" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "<root id=\"r1\"><item>Hello</item></root>",
      "demo.xml",
      Some(@input.DetectedFormat::Xml),
    ),
    @input.DetectedFormat::Xml,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(parsed.mode == @parser.ParserMode::DomAstModel)
  assert_true(parsed.event_stream is None)
  assert_metric_eq(parsed.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "none")
  assert_metric_eq(parsed.diagnostics, "event_semantics", "dom_ast_model")
  assert_metric_eq(parsed.diagnostics, "doctype_seen", "false")
  assert_metric_absent(parsed.diagnostics, "streaming_fallback")
  assert_true(document.blocks.length() == 2)
  assert_true(document.blocks[0].kind == @core.BlockKind::Heading)
  assert_eq(document.blocks[0].text, "<root>")
  let heading_ref = document.blocks[0].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(heading_ref.file_id == Some("demo.xml"))
  assert_true(heading_ref.format == Some("xml"))
  assert_true(heading_ref.xpath == Some("/root"))
  assert_true(document.blocks[1].kind == @core.BlockKind::List)
}

///|
test "xml large input switches to structure event stream without json semantics drift" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "<root><section><item>One</item><item>Two</item></section></root>",
      "large.xml",
      Some(@input.DetectedFormat::Xml),
    ),
    @input.DetectedFormat::Xml,
    requested_mode=Some(@parser.ParserMode::StreamingEvent),
  )
  assert_true(parsed.mode == @parser.ParserMode::StreamingEvent)
  assert_true(parsed.document is None)
  assert_true(parsed.event_stream is Some(_))
  assert_metric_eq(parsed.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "xml_structure")
  assert_metric_eq(
    parsed.diagnostics,
    "event_semantics",
    "xml_structure_event_stream",
  )
  assert_metric_absent(parsed.diagnostics, "streaming_fallback")
  assert_metric_eq(parsed.diagnostics, "dom_limit_reached", "false")
  assert_metric_eq(parsed.diagnostics, "resource_limit_hit", "false")
  assert_metric_not_eq(
    parsed.diagnostics,
    "event_semantics",
    "json_structure_event_stream",
  )
  assert_true(!parsed.diagnostics.degraded_features.contains("xml_fail_closed"))
  let events = parsed.event_stream.unwrap_or([])
  assert_true(events.length() > 0)
  let first = events[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(first.format == Some("xml"))
  assert_true(first.xpath == Some("/root"))
}

///|
test "xml fail closed paths preserve fenced raw output and diagnostics" {
  let doctype = convert_memory_text(
    "<!DOCTYPE note [<!ENTITY writer \"Alice\">]>\n<note>&writer;</note>\n",
    "doctype.xml",
    @input.DetectedFormat::Xml,
  )
  assert_true(doctype.content.contains("```xml"))
  assert_true(doctype.content.contains("<!DOCTYPE note"))
  assert_true(doctype.diagnostics.degraded_features.contains("xml_fail_closed"))
  assert_true(doctype.diagnostics.fallback_trace.length() > 0)
  assert_metric_eq(doctype.diagnostics, "doctype_seen", "true")

  let entity = convert_memory_text(
    "<root>&amp; &custom; &#169;</root>",
    "entity.xml",
    @input.DetectedFormat::Xml,
  )
  assert_true(entity.content.contains("```xml"))
  assert_true(entity.content.contains("&custom;"))
  assert_true(entity.content.contains("&#169;"))
  assert_true(entity.diagnostics.degraded_features.contains("xml_fail_closed"))
}

///|
test "xml numeric entities lower through product path while unknown entities still fail closed" {
  let numeric = convert_memory_text(
    "<root>&#169; &#x41; &#X4F60;</root>",
    "numeric-entities.xml",
    @input.DetectedFormat::Xml,
  )
  assert_eq(numeric.content, "# <root>\n\n- © A 你")
  assert_metric_eq(numeric.diagnostics, "format_contract", "xml")
  assert_true(
    !numeric.diagnostics.degraded_features.contains("xml_fail_closed"),
  )

  let unknown = convert_memory_text(
    "<root>&writer;</root>",
    "unknown-entity.xml",
    @input.DetectedFormat::Xml,
  )
  assert_true(unknown.content.contains("```xml"))
  assert_true(unknown.content.contains("&writer;"))
  assert_true(unknown.diagnostics.degraded_features.contains("xml_fail_closed"))
}

///|
test "xml path input honors declared iso-8859-1 bytes for literal fallback" {
  let root = test_tmp_root() + "/xml-encoding"
  recreate_clean_dir(root)
  let path = root + "/declared-latin1.xml"
  let bytes : Array[Byte] = []
  let micro_byte = 'µ'.to_int().to_byte()
  for
    ch in "<?xml version=\"1.0\" encoding=\"iso-8859-1\"?>\n<root>\u{00B5}</root>\n" {
    let code = ch.to_int()
    if ch == 'µ' {
      bytes.push(micro_byte)
    } else {
      bytes.push(code.to_byte())
    }
  }
  @fs.write_bytes_to_file(path, Bytes::from_array(bytes)) catch {
    e => fail("write failed: " + e.to_string())
  }
  let result = convert_path(path, format=Some(@input.DetectedFormat::Xml))
  assert_true(result.content.contains("# <root>"))
  assert_true(result.content.contains("µ"))
  assert_true(!result.content.contains("Պ"))
  cleanup_temp_dir(root)
}

///|
test "xml multiline attribute payload fails closed instead of structured outline" {
  let sample = "<a b='01234567890123456古人咏雪抽幽思骋妍辞竞险韵\n弘治戊午仲冬望日慈溪杨子器衵于海虞官舍序毕诗部' />\n"
  let result = convert_memory_text(
    sample,
    "long-attr.xml",
    @input.DetectedFormat::Xml,
  )
  assert_true(result.content.contains("```xml"))
  assert_true(
    result.content.contains("古人咏雪抽幽思骋妍辞竞险韵"),
  )
  assert_true(
    result.content.contains("弘治戊午仲冬望日慈溪杨子器"),
  )
  assert_true(result.diagnostics.degraded_features.contains("xml_fail_closed"))
  assert_true(!result.content.contains("# <a>"))
}

///|
test "xml convert contract keeps dom and event paths renderer-aligned" {
  let small = convert_memory_text(
    "<root><item>Hello</item></root>",
    "small.xml",
    @input.DetectedFormat::Xml,
  )
  let large = convert_memory_text(
    "<root><section><item>One</item><item>Two</item></section></root>",
    "large.xml",
    @input.DetectedFormat::Xml,
    limits=limits(1, 50, 10000),
  )
  assert_eq(small.content, "# <root>\n\n- item: Hello")
  assert_eq(
    large.content,
    "# <root>\n\n- <section>\n  - item: One\n  - item: Two",
  )
  assert_true(small.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(large.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_metric_eq(small.diagnostics, "builder_input_kind", "document")
  assert_metric_eq(large.diagnostics, "builder_input_kind", "event_stream")
}

///|
test "xml worldbank namespace dataset stays on streaming event route" {
  let result = convert_path(
    "samples/main_process/xml/markdown/xml_namespace_syntax.xml",
    format=Some(@input.DetectedFormat::Xml),
    limits=limits(1, 50, 10000, max_line_chars=8),
  )
  assert_true(result.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(!result.diagnostics.degraded_features.contains("xml_fail_closed"))
  assert_metric_eq(result.diagnostics, "selected_route", "streaming_event")
  assert_metric_eq(result.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(result.diagnostics, "builder_input_kind", "event_stream")
}

///|
test "xml synthetic benchmark samples stay parseable and keep intended routes" {
  let small = convert_path(
    "samples/main_process/xml/markdown/xml_basic.xml",
    format=Some(@input.DetectedFormat::Xml),
    limits=limits(1, 50, 10000, max_line_chars=8),
  )
  let medium = convert_path(
    "samples/main_process/xml/markdown/xml_nested.xml",
    format=Some(@input.DetectedFormat::Xml),
    limits=limits(1, 50, 10000, max_line_chars=8),
  )
  let huge = convert_path(
    "samples/main_process/xml/markdown/xml_namespace_syntax.xml",
    format=Some(@input.DetectedFormat::Xml),
    limits=limits(1, 50, 10000, max_line_chars=8),
  )
  assert_true(!small.diagnostics.degraded_features.contains("xml_fail_closed"))
  assert_true(!medium.diagnostics.degraded_features.contains("xml_fail_closed"))
  assert_true(!huge.diagnostics.degraded_features.contains("xml_fail_closed"))
  assert_true(small.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(medium.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(huge.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_metric_eq(small.diagnostics, "selected_route", "streaming_event")
  assert_metric_eq(medium.diagnostics, "selected_route", "streaming_event")
  assert_metric_eq(huge.diagnostics, "selected_route", "streaming_event")
  assert_metric_eq(small.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(medium.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(huge.diagnostics, "effective_mode", "streaming_event")
}

///|
test "xlsx huge benchmark sample should not fail closed on package open" {
  let result = convert_path(
    "samples/main_process/xlsx/markdown/xlsx_multi_sheet_mixed.xlsx",
    format=Some(@input.DetectedFormat::Xlsx),
    limits=limits(1, 1, 1),
  )
  assert_true(
    !result.diagnostics.degraded_features.contains("xlsx_parse_failure"),
  )
  assert_true(result.parser_mode == @parser.ParserMode::BlockStreaming)
  assert_metric_eq(result.diagnostics, "selected_route", "block_streaming")
  assert_metric_eq(result.diagnostics, "effective_mode", "block_streaming")
  assert_metric_eq(result.diagnostics, "builder_input_kind", "block_stream")
}

///|
test "html large benchmark sample stays on block streaming route" {
  let result = convert_path(
    "samples/main_process/html/markdown/html_semantic_sectioning.html",
    format=Some(@input.DetectedFormat::Html),
    limits=limits(1, 50, 100000),
  )
  assert_true(result.parser_mode == @parser.ParserMode::BlockStreaming)
  assert_metric_eq(result.diagnostics, "selected_route", "block_streaming")
  assert_metric_eq(result.diagnostics, "effective_mode", "block_streaming")
  assert_metric_eq(result.diagnostics, "builder_input_kind", "block_stream")
}

///|
test "epub large benchmark sample keeps package single pass public shape" {
  let result = convert_path(
    "samples/main_process/epub/markdown/epub_basic_package.epub",
    format=Some(@input.DetectedFormat::Epub),
  )
  assert_true(result.parser_mode == @parser.ParserMode::PackageSinglePass)
  assert_metric_eq(result.diagnostics, "selected_route", "package_single_pass")
  assert_metric_eq(result.diagnostics, "effective_mode", "package_single_pass")
  assert_metric_eq(result.diagnostics, "builder_input_kind", "block_stream")
}

///|
test "yaml small input stays dom ast model with yaml path source refs" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "name: Alice\nroles: [owner, reviewer]\nactive: true\n",
      "demo.yaml",
      Some(@input.DetectedFormat::Yaml),
    ),
    @input.DetectedFormat::Yaml,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(parsed.mode == @parser.ParserMode::DomAstModel)
  assert_true(parsed.event_stream is None)
  assert_metric_eq(parsed.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "none")
  assert_metric_eq(parsed.diagnostics, "event_semantics", "dom_ast_model")
  assert_metric_absent(parsed.diagnostics, "streaming_fallback")
  assert_true(document.blocks.length() == 1)
  assert_true(document.blocks[0].kind == @core.BlockKind::Table)
  let src = document.blocks[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(src.file_id == Some("demo.yaml"))
  assert_true(src.format == Some("yaml"))
  assert_true(src.yaml_path == Some("/"))
}

///|
test "yaml large input switches to true structure event stream" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "records:\n  - name: Alice\n    role: Engineer\n  - name: Bob\n    role: Designer\n",
      "large.yaml",
      Some(@input.DetectedFormat::Yaml),
    ),
    @input.DetectedFormat::Yaml,
    requested_mode=Some(@parser.ParserMode::StreamingEvent),
  )
  assert_true(parsed.mode == @parser.ParserMode::StreamingEvent)
  assert_true(parsed.document is None)
  assert_true(parsed.event_stream is Some(_))
  assert_metric_eq(parsed.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "yaml_structure")
  assert_metric_eq(
    parsed.diagnostics,
    "event_semantics",
    "yaml_structure_event_stream",
  )
  assert_metric_absent(parsed.diagnostics, "streaming_fallback")
  assert_metric_eq(parsed.diagnostics, "dom_limit_reached", "false")
  assert_metric_eq(parsed.diagnostics, "resource_limit_hit", "false")
  let events = parsed.event_stream.unwrap_or([])
  assert_true(events.length() > 0)
  let first = events[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(first.format == Some("yaml"))
  assert_true(first.yaml_path == Some("/"))
}

///|
test "yaml convert contract keeps dom and event paths renderer-aligned" {
  let small = convert_memory_text(
    "name: Alice\nroles: [owner, reviewer]\n",
    "small.yaml",
    @input.DetectedFormat::Yaml,
  )
  let large = convert_memory_text(
    "-\n  name: Alice\n  role: Engineer\n-\n  name: Bob\n  role: Designer\n",
    "large.yaml",
    @input.DetectedFormat::Yaml,
    limits=limits(1, 50, 10000),
  )
  assert_eq(
    small.content,
    "| Key | Value |\n| --- | --- |\n| name | Alice |\n| roles | [owner, reviewer] |",
  )
  assert_eq(
    large.content,
    "| name | role |\n| --- | --- |\n| Alice | Engineer |\n| Bob | Designer |",
  )
  assert_true(small.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(large.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_metric_eq(small.diagnostics, "builder_input_kind", "document")
  assert_metric_eq(large.diagnostics, "builder_input_kind", "event_stream")
}

///|
test "html small input stays dom ast model with html path source refs and parser-owned semantics" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "<details><summary>Open</summary><p>Body</p></details>",
      "demo.html",
      Some(@input.DetectedFormat::Html),
    ),
    @input.DetectedFormat::Html,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(parsed.mode == @parser.ParserMode::DomAstModel)
  assert_true(parsed.event_stream is None)
  assert_metric_eq(parsed.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "none")
  assert_metric_eq(parsed.diagnostics, "event_semantics", "dom_ast_model")
  assert_metric_absent(parsed.diagnostics, "streaming_fallback")
  assert_true(document.blocks.length() >= 2)
  let src = document.blocks[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(src.file_id == Some("demo.html"))
  assert_true(src.format == Some("html"))
  assert_true(src.html_path is Some(_))
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_eq(rendered.content, "Open\n\nBody")
  assert_true(!document.blocks[0].text.contains("["))
}

///|
test "html large input switches to true structure event stream" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "<html><body><article><h1>Title</h1><p>Body</p></article></body></html>",
      "large.html",
      Some(@input.DetectedFormat::Html),
    ),
    @input.DetectedFormat::Html,
    requested_mode=Some(@parser.ParserMode::BlockStreaming),
  )
  assert_true(parsed.mode == @parser.ParserMode::BlockStreaming)
  assert_true(parsed.document is None)
  assert_true(parsed.block_stream is Some(_))
  assert_metric_eq(parsed.diagnostics, "effective_mode", "block_streaming")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(
    parsed.diagnostics,
    "event_granularity",
    "html_token_structure",
  )
  assert_metric_eq(parsed.diagnostics, "event_semantics", "html_block_stream")
  assert_metric_absent(parsed.diagnostics, "streaming_fallback")
  assert_metric_eq(parsed.diagnostics, "dom_limit_reached", "false")
  assert_metric_eq(parsed.diagnostics, "html_block_stream_reparse", "false")
  assert_metric_eq(parsed.diagnostics, "html_block_stream_token_path", "true")
  let blocks = parsed.block_stream.unwrap_or([])
  assert_true(blocks.length() > 0)
  let first = blocks[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(first.format == Some("html"))
  assert_true(first.html_path is Some(_))
  assert_true(
    parsed.diagnostics.pass_trace.contains(
      "parse:html_parser:block_stream_route",
    ),
  )
  assert_true(
    parsed.diagnostics.pass_trace.contains("lower:html_scope_subtree_blocks"),
  )
}

///|
test "html convert contract keeps dom and event paths renderer-aligned" {
  let small = convert_path(
    "samples/main_process/html/markdown/html_details_summary.html",
    format=Some(@input.DetectedFormat::Html),
  )
  let large_parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "<html><body><article><h1>Title</h1><p>Body</p></article></body></html>",
      "large.html",
      Some(@input.DetectedFormat::Html),
    ),
    @input.DetectedFormat::Html,
    requested_mode=Some(@parser.ParserMode::BlockStreaming),
  )
  let large_blocks = large_parsed.block_stream.unwrap_or([])
  let large_document = (@pipeline.default_ir_builder().build)(
    @core.IRInput::BlockStream(large_blocks),
  )
  let large_rendered = (@render.markdown_renderer().render)(
    large_document,
    @render.make_render_context(false),
  )
  assert_eq(small.content, "Open\n\nBody")
  assert_true(small.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(large_parsed.mode == @parser.ParserMode::BlockStreaming)
  assert_metric_eq(small.diagnostics, "builder_input_kind", "document")
  assert_metric_eq(
    large_parsed.diagnostics,
    "effective_mode",
    "block_streaming",
  )
  assert_metric_eq(large_parsed.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(
    large_parsed.diagnostics,
    "event_granularity",
    "html_token_structure",
  )
  assert_metric_eq(
    large_parsed.diagnostics,
    "html_block_stream_reparse",
    "false",
  )
  assert_metric_eq(
    large_parsed.diagnostics,
    "html_block_stream_token_path",
    "true",
  )
  assert_true(large_parsed.block_stream is Some(_))
  assert_metric_eq(
    large_document.diagnostics,
    "builder_input_kind",
    "block_stream",
  )
  assert_eq(large_rendered.content, "# Title\n\nBody")
}

///|
test "block stream fast path skips full pipeline for html block route" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "<html><body><article><h1>Title</h1><p>Body</p></article></body></html>",
      "fast-path.html",
      Some(@input.DetectedFormat::Html),
    ),
    @input.DetectedFormat::Html,
    requested_mode=Some(@parser.ParserMode::BlockStreaming),
  )
  let context = @pipeline.make_pass_context(false, "balanced")
  context.diagnostics.val = parsed.diagnostics
  let output = match
    @pipeline.run_default_pipeline(
      @runtime.parse_result_to_ir_input(parsed),
      context,
    ) {
    Ok(value) => value
    Err(err) => abort("html block stream fast path failed: " + err.message)
  }
  match output {
    @core.IRInput::BlockStream(_) => ()
    _ => fail("expected html block stream fast path to preserve BlockStream")
  }
  assert_true(
    context.diagnostics.val.pass_trace.contains(
      "pipeline:block_stream_fast_path",
    ),
  )
  assert_true(!context.diagnostics.val.pass_trace.contains("NormalizeTextPass"))
  assert_true(
    context.diagnostics.val.metrics.get("builder_input_kind") ==
    Some("block_stream"),
  )
}

///|
test "html parser contract preserves semantic behavior clusters and asset persistence" {
  let details = convert_path(
    "samples/main_process/html/markdown/html_details_summary.html",
    format=Some(@input.DetectedFormat::Html),
  )
  let nav = convert_path(
    "samples/main_process/html/markdown/html_semantic_containers.html",
    format=Some(@input.DetectedFormat::Html),
  )
  let list_quote = convert_path(
    "samples/main_process/html/markdown/html_listitem_with_blockquote.html",
    format=Some(@input.DetectedFormat::Html),
  )
  let blockquote = convert_path(
    "samples/main_process/html/markdown/html_blockquote_mixed_text_and_paragraph.html",
    format=Some(@input.DetectedFormat::Html),
  )
  let table = convert_path(
    "samples/main_process/html/markdown/html_br_table.html",
    format=Some(@input.DetectedFormat::Html),
  )
  let entities = convert_path(
    "samples/main_process/html/markdown/html_entities.html",
    format=Some(@input.DetectedFormat::Html),
  )
  let assets = convert_path(
    "samples/main_process/html/assets/html_img_single.html",
    format=Some(@input.DetectedFormat::Html),
  )
  assert_eq(details.content, "Open\n\nBody")
  assert_eq(nav.content, "# Primary Title\n\nBody paragraph.\n\nSide note.")
  assert_eq(list_quote.content, "- intro\n\nquoted")
  assert_eq(blockquote.content, "> head\n> \n> body\n> \n> tail")
  assert_eq(
    table.content,
    "| Column 1 | Column 2 |\n| --- | --- |\n| a<br>b | c |",
  )
  assert_eq(entities.content, "Alpha   Beta &copy; © & <ok>")
  assert_true(assets.assets.length() == 1)
  assert_true(assets.assets[0].path == Some("assets/image01.jpg"))
  assert_true(
    assets.assets[0].attrs.get("source_path") == Some("img/img_red.jpg"),
  )
  assert_true(assets.content.contains("![single](assets/image01.jpg)"))
}

///|
test "html figure keeps visible caption when image stays non-materialized" {
  let remote = convert_memory_text(
    "<article><figure><img src='https://example.com/a.png' alt='Remote'><figcaption>Caption text</figcaption></figure></article>",
    "figure-remote.html",
    @input.DetectedFormat::Html,
  )
  assert_eq(remote.content, "Caption text")
  assert_true(
    remote.diagnostics.degraded_features.contains(
      "html_remote_image_reference_only",
    ),
  )
  assert_metric_eq(remote.diagnostics, "asset_count", "0")

  let data = convert_memory_text(
    "<article><figure><img src='data:image/png;base64,abc' alt='Inline'><figcaption>Inline caption</figcaption></figure></article>",
    "figure-data.html",
    @input.DetectedFormat::Html,
  )
  assert_true(data.content.contains("\\[inline data\\]"))
  assert_true(data.content.contains("Inline caption"))
  assert_true(
    data.diagnostics.degraded_features.contains(
      "html_data_image_reference_only",
    ),
  )
}

///|
test "html parser keeps renderer boundary for link image table and br semantics" {
  let linked = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/html/markdown/html_link_in_paragraph.html",
    ),
    @input.DetectedFormat::Html,
  )
  let linked_doc = linked.document.unwrap_or(@core.empty_document_ir())
  assert_true(linked.mode == @parser.ParserMode::DomAstModel)
  assert_true(linked_doc.blocks.length() == 1)
  let paragraph = linked_doc.blocks[0]
  assert_true(paragraph.kind == @core.BlockKind::Paragraph)
  assert_true(paragraph.text == "Read the docs first.")
  assert_true(paragraph.rich_inlines is Some(_))
  let paragraph_inlines = paragraph.rich_inlines.unwrap_or([])
  assert_true(paragraph_inlines.length() == 3)
  assert_true(paragraph_inlines[0].kind == @core.InlineKind::Text)
  assert_true(paragraph_inlines[1].kind == @core.InlineKind::Link)
  assert_true(paragraph_inlines[1].text == "the docs")
  assert_true(
    paragraph_inlines[1].href == Some("https://example.com/paragraph"),
  )
  assert_true(paragraph_inlines[2].kind == @core.InlineKind::Text)
  assert_true(
    paragraph.source_ref.unwrap_or(@core.empty_source_ref()).html_path
    is Some(_),
  )
  assert_contains_none(paragraph.text, ["[the docs](", "<a "])

  let table = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/html/markdown/html_br_table.html",
    ),
    @input.DetectedFormat::Html,
  )
  let table_doc = table.document.unwrap_or(@core.empty_document_ir())
  assert_true(table_doc.blocks.length() == 1)
  let table_block = table_doc.blocks[0]
  assert_true(table_block.kind == @core.BlockKind::Table)
  assert_true(table_block.children.length() == 1)
  let table_row = table_block.children[0]
  assert_true(table_row.kind == @core.BlockKind::TableRow)
  assert_true(table_row.children.length() == 2)
  let first_cell = table_row.children[0]
  assert_true(first_cell.kind == @core.BlockKind::TableCell)
  assert_true(first_cell.text == "a<br>b")
  assert_true(first_cell.rich_inlines is Some(_))
  let cell_inlines = first_cell.rich_inlines.unwrap_or([])
  assert_true(cell_inlines.length() == 3)
  assert_true(cell_inlines[0].kind == @core.InlineKind::Text)
  assert_true(cell_inlines[1].kind == @core.InlineKind::LineBreak)
  assert_true(cell_inlines[2].kind == @core.InlineKind::Text)
  assert_true(
    first_cell.source_ref.unwrap_or(@core.empty_source_ref()).html_path
    is Some(_),
  )
  assert_contains_none(first_cell.text, ["  \n", "\\|"])

  let imaged = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/html/assets/html_img_single.html",
    ),
    @input.DetectedFormat::Html,
  )
  let image_doc = imaged.document.unwrap_or(@core.empty_document_ir())
  assert_true(image_doc.blocks.length() == 1)
  assert_true(image_doc.blocks[0].kind == @core.BlockKind::Image)
  assert_true(
    image_doc.blocks[0].attrs.get("path") == Some("assets/image01.jpg"),
  )
  assert_true(image_doc.blocks[0].attrs.get("alt") == Some("single"))
  assert_true(image_doc.assets.length() == 1)
  assert_true(image_doc.assets[0].path == Some("assets/image01.jpg"))
  assert_true(
    image_doc.assets[0].attrs.get("source_path") == Some("img/img_red.jpg"),
  )
  assert_true(
    image_doc.assets[0].source_ref.unwrap_or(@core.empty_source_ref()).html_path
    is Some(_),
  )
  assert_true(imaged.diagnostics.metrics.get("image_count") == Some("1"))
  assert_true(imaged.diagnostics.metrics.get("asset_count") == Some("1"))
}

///|
test "docx merged table boundary keeps full body column count through product path" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/docx/markdown/docx_table_merged_cells_boundary.docx",
    ),
    @input.DetectedFormat::Docx,
  )
  let doc = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(doc.blocks.length() == 1)
  let table = doc.blocks[0]
  assert_true(table.kind == @core.BlockKind::Table)
  assert_true(table.attrs.get("table_column_count") == Some("3"))
  assert_eq(table.children.length(), 4)
  assert_eq(table.children[0].children.length(), 2)
  assert_eq(table.children[1].children.length(), 3)
  assert_eq(table.children[2].children.length(), 3)
  assert_eq(table.children[3].children.length(), 3)

  let rendered = (@render.markdown_renderer().render)(
    @core.document_from_blocks([table]),
    @render.make_render_context(false),
  )
  assert_eq(
    rendered.content,
    "| Merged Head | Right |\n| --- | --- |\n| A | B | C |\n| Vert Start | Body 1 | Body 2 |\n|  | Tail 1 | Tail 2 |",
  )
}

///|
test "nested ordered list indentation remains parser-owned while renderer stays generic" {
  let html_mixed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/html/markdown/html_nested_list_mixed.html",
    ),
    @input.DetectedFormat::Html,
  )
  let html_mixed_doc = html_mixed.document.unwrap_or_else(fn() {
    abort("missing html nested mixed document")
  })
  let html_root_list = html_mixed_doc.blocks[0]
  assert_true(html_root_list.kind == @core.BlockKind::List)
  let html_parent = html_root_list.children[0]
  assert_true(html_parent.kind == @core.BlockKind::ListItem)
  assert_true(html_parent.children.length() == 1)
  let html_ordered_nested = html_parent.children[0]
  assert_true(html_ordered_nested.kind == @core.BlockKind::List)
  assert_true(html_ordered_nested.attrs.get("ordered") == Some("true"))
  assert_true(html_ordered_nested.children.length() == 2)
  assert_true(
    html_ordered_nested.children[0].attrs.get("stable_ordered_marker") ==
    Some("true"),
  )
  assert_true(
    html_ordered_nested.children[0].attrs.get("ordered_indent_step") ==
    Some("3"),
  )
  let html_mixed_rendered = (@render.markdown_renderer().render)(
    html_mixed_doc,
    @render.make_render_context(false),
  )
  let html_mixed_expected = read_utf8_text(
    "samples/main_process/html/expected/markdown/html_nested_list_mixed.md",
  )
  let html_deep_expected = read_utf8_text(
    "samples/main_process/html/expected/markdown/html_nested_lists_deep.md",
  )
  let docx_mixed_expected = read_utf8_text(
    "samples/main_process/docx/expected/markdown/docx_nested_lists_mixed.md",
  )
  assert_eq(
    html_mixed_rendered.content.trim().to_owned(),
    html_mixed_expected.trim().to_owned(),
  )

  let html_deep = convert_path(
    "samples/main_process/html/markdown/html_nested_lists_deep.html",
    format=Some(@input.DetectedFormat::Html),
  )
  assert_eq(
    html_deep.content.trim().to_owned(),
    html_deep_expected.trim().to_owned(),
  )

  let docx_mixed = convert_path(
    "samples/main_process/docx/markdown/docx_nested_lists_mixed.docx",
    format=Some(@input.DetectedFormat::Docx),
  )
  assert_eq(
    docx_mixed.content.trim().to_owned(),
    docx_mixed_expected.trim().to_owned(),
  )
  assert_file_contains_none("render/render.mbt", [
    "source_ref.format", "block_source_format(block) == Some(\"html\")",
  ])
}

///|
test "html product path keeps content sections with hyphenated nav-like ids" {
  let result = convert_memory_text(
    "<article>" +
    "<section id='toc-nav'><h2><code>toc nav</code></h2><p>Body A</p></section>" +
    "<section id='landmarks-nav'><h2><code>landmarks nav</code></h2><p>Body B</p></section>" +
    "<section id='page-list-nav'><h2><code>page-list nav</code></h2><p>110</p></section>" +
    "<section id='custom-nav'><h2>Custom <code>nav</code> elements</h2><p>Glossary</p></section>" +
    "</article>",
    "nav-ids.html",
    @input.DetectedFormat::Html,
  )
  assert_contains_all(result.content, [
    "toc nav", "Body A", "landmarks nav", "Body B", "page-list nav", "110", "Custom nav elements",
    "Glossary",
  ])
}

///|
test "html product path keeps full safe external href" {
  let href = "https://epub-samples.googlecode.com/files/moby-dick-20120118.epub#epubcfi('/6/14!/4/2/2/2/2/1')"
  let result = convert_memory_text(
    "<article><p><a href=\"" +
    href +
    "\">Link to Chapter 1 of Moby Dick</a></p></article>",
    "long-link.html",
    @input.DetectedFormat::Html,
  )
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "<article><p><a href=\"" +
      href +
      "\">Link to Chapter 1 of Moby Dick</a></p></article>",
      "long-link.html",
      Some(@input.DetectedFormat::Html),
    ),
    @input.DetectedFormat::Html,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(document.blocks.length() == 1)
  let inlines = document.blocks[0].rich_inlines.unwrap_or([])
  assert_true(inlines.length() == 1)
  assert_true(inlines[0].kind == @core.InlineKind::Link)
  assert_true(inlines[0].href == Some(href))
  assert_true(result.content.contains(href))
}

///|
test "html safety keeps unsafe links as text with diagnostics and no parser markdown fallback" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/html/markdown/html_link_unsafe_javascript.html",
    ),
    @input.DetectedFormat::Html,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(parsed.mode == @parser.ParserMode::DomAstModel)
  assert_true(document.blocks.length() == 4)
  assert_true(parsed.diagnostics.warnings.length() > 0)
  assert_true(parsed.diagnostics.metrics.get("unsafe_node_count") == Some("3"))
  assert_true(
    parsed.diagnostics.metrics.get("validation_issue_count") == Some("3"),
  )
  assert_true(
    parsed.diagnostics.metrics.get("unsupported_feature_count") == Some("4"),
  )
  assert_true(parsed.diagnostics.metrics.get("link_count") == Some("4"))
  assert_true(parsed.diagnostics.metrics.get("streaming_fallback") == None)
  assert_true(
    parsed.diagnostics.warnings
    .join("\n")
    .contains("unsafe url uses javascript: scheme"),
  )
  assert_true(
    parsed.diagnostics.warnings
    .join("\n")
    .contains("unsafe url uses vbscript: scheme"),
  )
  assert_true(
    parsed.diagnostics.warnings
    .join("\n")
    .contains("unsafe url uses data: scheme"),
  )
  assert_true(
    !parsed.diagnostics.degraded_features.contains("html_raw_fenced_fallback"),
  )
  for block in document.blocks {
    assert_true(block.kind == @core.BlockKind::Paragraph)
    assert_true(block.rich_inlines is Some(_))
    let inlines = block.rich_inlines.unwrap_or([])
    assert_true(inlines.length() == 1)
    assert_true(inlines[0].kind == @core.InlineKind::Text)
    assert_contains_none(block.text, ["[", "](", "<a "])
  }
}

///|
test "html malformed input fail closes without markdown raw fallback" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "<!-- broken",
      "broken.html",
      Some(@input.DetectedFormat::Html),
    ),
    @input.DetectedFormat::Html,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(parsed.mode == @parser.ParserMode::DomAstModel)
  assert_true(document.blocks.length() == 0)
  assert_true(parsed.diagnostics.errors.length() > 0)
  assert_true(parsed.diagnostics.degraded_features.contains("html_fail_closed"))
  assert_true(
    !parsed.diagnostics.degraded_features.contains("html_raw_fenced_fallback"),
  )
  assert_true(parsed.diagnostics.fallback_trace[0].contains("html fail closed"))
}

///|
test "csv source ref contract keeps row and cell ranges" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "name,role\nalice,engineer\n",
      "demo.csv",
      Some(@input.DetectedFormat::Csv),
    ),
    @input.DetectedFormat::Csv,
  )
  let events = parsed.event_stream.unwrap_or([])
  assert_true(events.length() >= 3)
  let first_cell = events[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(first_cell.file_id == Some("demo.csv"))
  assert_true(first_cell.format == Some("csv"))
  assert_true(first_cell.cell_range == Some("R1C1"))
  let row_break = events[2].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(row_break.cell_range == Some("R1C1:R1C2"))
}

///|
test "txt source ref contract keeps line range in rendered document" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "One\n\nTwo",
      "demo.txt",
      Some(@input.DetectedFormat::Txt),
    ),
    @input.DetectedFormat::Txt,
  )
  let events = parsed.event_stream.unwrap_or([])
  assert_true(events.length() == 3)
  let first = events[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(first.file_id == Some("demo.txt"))
  assert_true(first.format == Some("txt"))
  assert_true(first.line_start == Some(1))
  let blank = events[1].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(blank.line_start == Some(2))
  let third = events[2].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(third.line_start == Some(3))
}

///|
test "txt empty mixed newline unicode and long line maturity stay observable" {
  let empty = convert_memory_text("", "empty.txt", @input.DetectedFormat::Txt)
  assert_eq(empty.content, "")
  assert_true(empty.diagnostics.metrics.get("block_count") == Some("0"))
  assert_true(empty.diagnostics.metrics.get("is_empty") == Some("true"))
  assert_true(empty.diagnostics.metrics.get("input_line_count") == Some("0"))
  assert_true(
    empty.diagnostics.metrics.get("product_path_enabled") == Some("true"),
  )
  assert_true(empty.diagnostics.metrics.get("format_contract") == Some("txt"))

  let mixed = convert_memory_text(
    "第一行\r\n\r\nemoji 😀\nlast\rline",
    "mixed.txt",
    @input.DetectedFormat::Txt,
  )
  assert_eq(mixed.content, "第一行\n\nemoji &#128512; last line")
  assert_true(mixed.diagnostics.metrics.get("newline_style") == Some("lf"))
  assert_true(mixed.diagnostics.metrics.get("paragraph_count") == Some("2"))
  assert_true(mixed.diagnostics.metrics.get("input_line_count") == Some("5"))
  assert_true(
    mixed.diagnostics.metrics.get("invalid_utf8_fallback") == Some("false"),
  )

  let long_line = convert_memory_text(
    "0123456789abcdef",
    "long.txt",
    @input.DetectedFormat::Txt,
    limits=limits(200, 50, 10000, max_line_chars=8),
  )
  assert_true(long_line.content.contains("\\[truncated\\]"))
  assert_true(long_line.diagnostics.warnings.length() > 0)
  assert_true(
    long_line.diagnostics.degraded_features.contains("txt_long_line_truncation"),
  )
}

///|
test "txt invalid utf8 bytes fail closed with diagnostics and raw fallback" {
  let options = @convert.make_convert_options(
    @convert.ConvertMode::Balanced,
    @convert.OutputFormat::Markdown,
    Some(@input.DetectedFormat::Txt),
    @parser.default_ocr_options(),
    @convert.default_resource_limits(),
  )
  let source = @input.input_from_bytes_with_format(
    Bytes::from_array([255, 254, 65]),
    "bad.txt",
    Some(@input.DetectedFormat::Txt),
  )
  let result = match @convert.convert_input(source, options) {
    Ok(value) => value
    Err(err) => fail("convert failed: " + err.to_string())
  }
  assert_true(result.content.contains("[invalid utf8 text input]"))
  assert_true(result.diagnostics.warnings.length() > 0)
  assert_true(
    result.diagnostics.degraded_features.contains("invalid_utf8_text_fallback"),
  )
  assert_true(
    result.diagnostics.metrics.get("invalid_utf8_fallback") == Some("true"),
  )
}

///|
test "txt utf16 bom bytes decode through shared text input path" {
  let bytes : Array[Byte] = [
    255, 254, 67, 0, 111, 0, 117, 0, 110, 0, 116, 0, 114, 0, 121, 0, 9, 0, 86, 0,
    97, 0, 108, 0, 117, 0, 101, 0, 10, 0, 77, 0, 111, 0, 111, 0, 110, 0, 66, 0, 105,
    0, 116, 0, 9, 0, 52, 0, 50, 0, 10, 0,
  ]
  let options = @convert.make_convert_options(
    @convert.ConvertMode::Balanced,
    @convert.OutputFormat::Markdown,
    Some(@input.DetectedFormat::Txt),
    @parser.default_ocr_options(),
    @convert.default_resource_limits(),
  )
  let source = @input.input_from_bytes_with_format(
    Bytes::from_array(bytes),
    "utf16.txt",
    Some(@input.DetectedFormat::Txt),
  )
  let result = match @convert.convert_input(source, options) {
    Ok(value) => value
    Err(err) => fail("convert failed: " + err.to_string())
  }
  assert_true(result.content.contains("Country\tValue"))
  assert_true(result.content.contains("MoonBit\t42"))
  assert_true(
    result.diagnostics.metrics.get("invalid_utf8_fallback") == Some("false"),
  )
}

///|
test "resource limits contract degrades csv instead of silently expanding" {
  let result = convert_memory_text(
    "a,b,c\n1,2,3\n4,5,6\n",
    "limits.csv",
    @input.DetectedFormat::Csv,
    mode=@convert.ConvertMode::Balanced,
    limits=limits(1, 2, 2),
  )
  assert_true(result.content.contains("| a | b |"))
  assert_true(!result.content.contains("| c |"))
  assert_true(result.diagnostics.warnings.length() > 0)
  assert_true(result.diagnostics.degraded_features.length() > 0)
  assert_true(result.diagnostics.fallback_trace.length() > 0)
  assert_true(result.diagnostics.metrics.get("row_count") == Some("1"))
  assert_true(result.diagnostics.metrics.get("column_count") == Some("2"))
}

///|
test "markdown maturity covers headings lists quotes frontmatter image and fence warnings" {
  let markdown = "---\n" +
    "title: Demo\n" +
    "---\n\n" +
    "# Title\n\n" +
    "## Section\n\n" +
    "- one\n" +
    "- two\n\n" +
    "1. first\n" +
    "2. second\n\n" +
    "> line a\n" +
    "> line b\n\n" +
    "![diagram](images/demo.png)\n\n" +
    "```moonbit\n" +
    "let x = 1\n" +
    "```\n"
  let result = convert_memory_text(
    markdown,
    "demo.md",
    @input.DetectedFormat::Markdown,
  )
  assert_true(result.content.contains("---\ntitle: Demo\n---"))
  assert_true(result.content.contains("# Title"))
  assert_true(result.content.contains("## Section"))
  assert_true(result.content.contains("- one\n- two"))
  assert_true(result.content.contains("1. first\n2. second"))
  assert_true(result.content.contains("> line a\n> line b"))
  assert_true(result.content.contains("![diagram](assets/image01.png)"))
  assert_true(result.content.contains("```moonbit\nlet x = 1\n```"))
  assert_true(result.diagnostics.metrics.get("has_frontmatter") == Some("true"))
  assert_true(result.diagnostics.metrics.get("image_count") == Some("1"))
  assert_true(result.diagnostics.metrics.get("asset_count") == Some("1"))
  assert_true(
    result.diagnostics.metrics.get("frontmatter_kind") == Some("yaml"),
  )
  assert_true(
    result.diagnostics.metrics.get("product_path_enabled") == Some("true"),
  )
  assert_true(
    result.diagnostics.metrics.get("format_contract") == Some("markdown"),
  )
}

///|
test "markdown parser keeps semantic IR and renderer owns markdown syntax" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "# Title\n\nSee [spec](https://example.com/spec) and `alpha`.\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n",
      "semantic.md",
      Some(@input.DetectedFormat::Markdown),
    ),
    @input.DetectedFormat::Markdown,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  let blocks = document.blocks
  assert_true(blocks.length() >= 3)
  let heading = blocks[0]
  let paragraph = blocks[1]
  let table = blocks[2]
  assert_true(heading.kind == @core.BlockKind::Heading)
  assert_eq(heading.text, "Title")
  assert_true(!heading.text.contains("#"))
  assert_true(paragraph.kind == @core.BlockKind::Paragraph)
  assert_eq(paragraph.text, "See [spec](https://example.com/spec) and `alpha`.")
  let inlines = paragraph.rich_inlines.unwrap_or([])
  assert_true(inlines.length() >= 4)
  assert_true(inlines[1].kind == @core.InlineKind::Link)
  assert_eq(inlines[1].text, "spec")
  assert_true(inlines[1].href == Some("https://example.com/spec"))
  assert_true(inlines[3].kind == @core.InlineKind::Code)
  assert_eq(inlines[3].text, "alpha")
  assert_true(table.kind == @core.BlockKind::Table)
  assert_true(table.children.length() == 2)
  assert_eq(table.children[0].children[0].text, "A")
  assert_eq(table.children[1].children[1].text, "2")
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(rendered.content.contains("# Title"))
  assert_true(rendered.content.contains("[spec](https://example.com/spec)"))
  assert_true(rendered.content.contains("`alpha`"))
  assert_true(rendered.content.contains("| A | B |"))
  assert_true(rendered.content.contains("| --- | --- |"))
}

///|
test "markdown unsafe links degrade to text with diagnostics and no fetch" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "[js](javascript:alert(1)) [vb](vbscript:alert(1)) [data](data:text/plain,hi) [file](file:///tmp/x)\n",
      "unsafe-links.md",
      Some(@input.DetectedFormat::Markdown),
    ),
    @input.DetectedFormat::Markdown,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  let blocks = document.blocks
  assert_true(blocks.length() == 1)
  let paragraph = blocks[0]
  assert_true(paragraph.kind == @core.BlockKind::Paragraph)
  let inlines = paragraph.rich_inlines.unwrap_or([])
  assert_true(inlines.length() == 7)
  for inline in inlines {
    assert_true(inline.kind != @core.InlineKind::Link)
  }
  assert_true(parsed.diagnostics.warnings.length() >= 4)
  assert_true(
    parsed.diagnostics.degraded_features.contains(
      "markdown_unsafe_link_text_only",
    ),
  )
  assert_true(
    parsed.diagnostics.fallback_trace.contains(
      "markdown unsafe link -> keep text, drop href",
    ),
  )
  assert_metric_eq(parsed.diagnostics, "unsafe_link_count", "4")
  assert_metric_eq(parsed.diagnostics, "warning_count", "4")
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_eq(rendered.content, "js vb data file")
  assert_true(!rendered.content.contains("[js]("))
}

///|
test "markdown raw html and frontmatter stay bounded and visible in diagnostics" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "---\n" + "title: Demo\n" + "---\n\n" + "<script>alert(1)</script>\n",
      "unsafe-html.md",
      Some(@input.DetectedFormat::Markdown),
    ),
    @input.DetectedFormat::Markdown,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  let blocks = document.blocks
  assert_true(blocks.length() == 2)
  assert_true(blocks[0].kind == @core.BlockKind::Raw)
  assert_true(blocks[0].attrs.get("raw_kind") == Some("markdown_frontmatter"))
  assert_true(blocks[1].kind == @core.BlockKind::Raw)
  assert_true(blocks[1].attrs.get("raw_kind") == Some("markdown_html_literal"))
  assert_true(blocks[1].attrs.get("unsafe_html") == Some("true"))
  assert_metric_eq(parsed.diagnostics, "frontmatter_seen", "true")
  assert_metric_eq(parsed.diagnostics, "frontmatter_kind", "yaml")
  assert_metric_eq(parsed.diagnostics, "raw_html_count", "1")
  assert_metric_eq(parsed.diagnostics, "unsafe_html_count", "1")
  assert_true(
    parsed.diagnostics.degraded_features.contains(
      "markdown_raw_html_unsafe_literal",
    ),
  )
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(rendered.content.contains("---\ntitle: Demo\n---"))
  assert_true(rendered.content.contains("<script>alert(1)</script>"))
}

///|
test "markdown unclosed fence warning and source refs stay visible" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "# T\n\n```moonbit\nlet x = 1\n",
      "broken.md",
      Some(@input.DetectedFormat::Markdown),
    ),
    @input.DetectedFormat::Markdown,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  let blocks = document.blocks
  assert_true(blocks.length() >= 2)
  assert_true(parsed.diagnostics.warnings.length() > 0)
  assert_true(
    parsed.diagnostics.degraded_features.contains("markdown_unclosed_fence"),
  )
  let heading = blocks[0]
  let src = heading.source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(src.line_start == Some(1))
  assert_true(src.line_end == Some(1))
  assert_true(
    parsed.diagnostics.metrics.get("table_like_row_count") == Some("0"),
  )
}

///|
test "csv and tsv maturity cover quoted fields ragged rows multiline cells and diagnostics" {
  let csv = convert_memory_text(
    "name,notes,quote\n" +
    "\"alice,bob\",\"line1\nline2\",\"a \"\"quoted\"\" value\"\n" +
    "carol,,tail\n",
    "quoted.csv",
    @input.DetectedFormat::Csv,
  )
  assert_true(csv.content.contains("| name | notes | quote |"))
  assert_true(csv.content.contains("alice,bob"))
  assert_true(csv.content.contains("line1<br>line2"))
  assert_true(csv.content.contains("a \"quoted\" value"))
  assert_true(csv.diagnostics.metrics.get("multiline_field_count") == Some("1"))
  assert_true(csv.diagnostics.metrics.get("header_rows") == Some("1"))
  assert_true(
    csv.diagnostics.metrics.get("quoted_field_support") == Some("true"),
  )
  assert_true(
    csv.diagnostics.metrics.get("quoted_newline_capability") == Some("true"),
  )
  assert_true(
    csv.diagnostics.metrics.get("quoted_newline_observed") == Some("true"),
  )
  assert_true(csv.diagnostics.metrics.get("delimiter") == Some("comma"))
  assert_true(
    csv.diagnostics.metrics.get("product_path_enabled") == Some("true"),
  )
  assert_true(csv.diagnostics.metrics.get("format_contract") == Some("csv"))

  let ragged = convert_memory_text(
    "a,b,c\n1,2\n3,4,5\n",
    "ragged.csv",
    @input.DetectedFormat::Csv,
  )
  assert_true(ragged.diagnostics.warnings.length() > 0)
  assert_true(
    ragged.diagnostics.degraded_features.contains("ragged_rows_normalized"),
  )
  assert_true(ragged.content.contains("| 1 | 2 |  |"))
  assert_true(
    ragged.diagnostics.warnings[0].contains("ragged row warning: row"),
  )

  let tsv = convert_memory_text(
    "a\tb\n\"x\ty\"\t2\n",
    "quoted.tsv",
    @input.DetectedFormat::Tsv,
  )
  assert_true(tsv.content.contains("| x\ty | 2 |"))
  assert_true(
    tsv.diagnostics.metrics.get("quoted_newline_observed") == Some("false"),
  )
  assert_true(tsv.diagnostics.metrics.get("delimiter") == Some("tab"))
  assert_true(
    tsv.diagnostics.metrics.get("quoted_delimiter_support") ==
    Some("quoted_tab"),
  )

  let blank_rows = convert_memory_text(
    "a,b\n\n1,2\n",
    "blank-rows.csv",
    @input.DetectedFormat::Csv,
  )
  assert_true(blank_rows.content.contains("| a | b |"))
  assert_true(blank_rows.content.contains("| 1 | 2 |"))
  assert_metric_eq(blank_rows.diagnostics, "blank_row_count", "0")
  assert_metric_eq(blank_rows.diagnostics, "line_count", "3")
}

///|
test "malformed csv degrades to raw fallback instead of hard failing" {
  let result = convert_memory_text(
    "\"unterminated,cell\nnext,row\n",
    "bad.csv",
    @input.DetectedFormat::Csv,
  )
  assert_true(result.content.contains("```csv"))
  assert_true(result.diagnostics.warnings.length() > 0)
  assert_true(result.diagnostics.degraded_features.contains("csv_raw_fallback"))
  assert_true(
    result.diagnostics.metrics.get("effective_mode") == Some("streaming_event"),
  )
  assert_true(
    result.diagnostics.metrics.get("fallback_reason_kind") ==
    Some("unterminated_quoted_field"),
  )
}

///|
test "renderer hardening covers ordered lists table escaping blockquote multiline and safe fences" {
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Deep",
    source_ref=@core.empty_source_ref(),
  )
  heading.attrs.set("level", "3")
  let list = @core.make_block(
    @core.BlockKind::List,
    "",
    source_ref=@core.empty_source_ref(),
  )
  list.attrs.set("ordered", "true")
  list.children.push(
    @core.block_with_attr(
      @core.make_block(
        @core.BlockKind::ListItem,
        "first",
        source_ref=@core.empty_source_ref(),
      ),
      "ordered",
      "true",
    ),
  )
  list.children.push(
    @core.block_with_attr(
      @core.make_block(
        @core.BlockKind::ListItem,
        "second",
        source_ref=@core.empty_source_ref(),
      ),
      "ordered",
      "true",
    ),
  )
  let table = @core.make_block(
    @core.BlockKind::Table,
    "",
    source_ref=@core.empty_source_ref(),
  )
  let header = @core.make_block(
    @core.BlockKind::TableRow,
    "",
    source_ref=@core.empty_source_ref(),
  )
  header.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "left|right",
      source_ref=@core.empty_source_ref(),
    ),
  )
  header.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "note",
      source_ref=@core.empty_source_ref(),
    ),
  )
  let row = @core.make_block(
    @core.BlockKind::TableRow,
    "",
    source_ref=@core.empty_source_ref(),
  )
  row.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "line1\nline2",
      source_ref=@core.empty_source_ref(),
    ),
  )
  table.children.push(header)
  table.children.push(row)
  let code = @core.make_block(
    @core.BlockKind::Code,
    "```\ninside\n```",
    source_ref=@core.empty_source_ref(),
  )
  code.attrs.set("info", "text")
  let quote = @core.make_block(
    @core.BlockKind::BlockQuote,
    "a\nb",
    source_ref=@core.empty_source_ref(),
  )
  let raw = @core.make_block(
    @core.BlockKind::Raw,
    "payload",
    source_ref=@core.empty_source_ref(),
  )
  raw.attrs.set("raw_kind", "text")
  let document = @core.document_from_blocks([
    heading, list, table, code, quote, raw,
  ])
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(rendered.content.contains("### Deep"))
  assert_true(rendered.content.contains("1. first\n2. second"))
  assert_true(rendered.content.contains("left\\|right"))
  assert_true(rendered.content.contains("line1<br>line2"))
  assert_true(rendered.content.contains("````text"))
  assert_true(rendered.content.contains("> a\n> b"))
  assert_true(rendered.content.contains("```text\npayload\n```"))
}

///|
test "renderer owns txt markdown escaping and parser keeps semantic text" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "# heading-ish\n\nemoji 😀",
      "escape.txt",
      Some(@input.DetectedFormat::Txt),
    ),
    @input.DetectedFormat::Txt,
  )
  let events = parsed.event_stream.unwrap_or([])
  assert_eq(events[0].text, "# heading-ish")
  assert_true(events[1].kind == @core.EventKind::BlankLine)
  assert_eq(events[2].text, "emoji 😀")

  let builder = @pipeline.default_ir_builder()
  let document = (builder.build)(@core.IRInput::EventStream(events))
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(rendered.content.contains("\\# heading-ish"))
  assert_true(rendered.content.contains("emoji &#128512;"))
}

///|
test "renderer owns csv and tsv table escaping while parser keeps raw cells" {
  let csv = default_registry_parse(
    @input.input_from_text_with_format(
      "left,right\n\"x|y\",\"line1\nline2\"\n",
      "escape.csv",
      Some(@input.DetectedFormat::Csv),
    ),
    @input.DetectedFormat::Csv,
  )
  let events = csv.event_stream.unwrap_or([])
  assert_eq(events[3].text, "x|y")
  assert_eq(events[4].text, "line1\nline2")

  let builder = @pipeline.default_ir_builder()
  let document = (builder.build)(@core.IRInput::EventStream(events))
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(rendered.content.contains("x\\|y"))
  assert_true(rendered.content.contains("line1<br>line2"))
}

///|
test "structured text parsers keep semantic values and renderer owns markdown formatting" {
  let json = default_registry_parse(
    @input.input_from_text_with_format(
      "{\"pipe\":\"x|y\",\"lines\":\"a\\nb\"}\n",
      "semantic.json",
      Some(@input.DetectedFormat::Json),
    ),
    @input.DetectedFormat::Json,
  )
  let yaml = default_registry_parse(
    @input.input_from_text_with_format(
      "pipe: x|y\nlines: \"a\\nb\"\n",
      "semantic.yaml",
      Some(@input.DetectedFormat::Yaml),
    ),
    @input.DetectedFormat::Yaml,
  )
  let json_doc = json.document.unwrap_or(@core.empty_document_ir())
  let yaml_doc = yaml.document.unwrap_or(@core.empty_document_ir())
  assert_true(json_doc.blocks[0].kind == @core.BlockKind::Table)
  assert_true(yaml_doc.blocks[0].kind == @core.BlockKind::Table)
  assert_eq(json_doc.blocks[0].children[1].children[1].text, "x|y")
  assert_eq(json_doc.blocks[0].children[2].children[1].text, "a\nb")
  assert_eq(yaml_doc.blocks[0].children[1].children[1].text, "x|y")
  assert_eq(yaml_doc.blocks[0].children[2].children[1].text, "a\nb")

  let rendered_json = (@render.markdown_renderer().render)(
    json_doc,
    @render.make_render_context(false),
  )
  let rendered_yaml = (@render.markdown_renderer().render)(
    yaml_doc,
    @render.make_render_context(false),
  )
  assert_true(rendered_json.content.contains("x\\|y"))
  assert_true(rendered_json.content.contains("a<br>b"))
  assert_true(rendered_yaml.content.contains("x\\|y"))
  assert_true(rendered_yaml.content.contains("a<br>b"))
}

///|
test "toml product path keeps array tables semantic and malformed fallback explicit" {
  let semantic = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/toml/markdown/toml_array_of_tables_table.toml",
    ),
    @input.DetectedFormat::Toml,
  )
  let malformed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/toml/markdown/toml_malformed_current_fallback.toml",
    ),
    @input.DetectedFormat::Toml,
  )
  let semantic_doc = semantic.document.unwrap_or(@core.empty_document_ir())
  let malformed_doc = malformed.document.unwrap_or(@core.empty_document_ir())
  assert_true(semantic_doc.blocks.length() >= 2)
  assert_true(semantic_doc.blocks[0].kind == @core.BlockKind::Heading)
  assert_true(semantic_doc.blocks[1].kind == @core.BlockKind::Table)
  assert_eq(semantic_doc.blocks[1].children[1].children[0].text, "Hammer")
  assert_true(
    !semantic.diagnostics.degraded_features.contains("toml_raw_fenced_fallback"),
  )
  assert_metric_eq(semantic.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(semantic.diagnostics, "ir_input_kind", "document")
  assert_true(malformed_doc.blocks.length() == 1)
  assert_true(malformed_doc.blocks[0].kind == @core.BlockKind::Code)
  assert_true(
    malformed.diagnostics.degraded_features.contains("toml_raw_fenced_fallback"),
  )
  assert_true(malformed.diagnostics.warnings.length() > 0)
  assert_metric_eq(malformed.diagnostics, "syntax_error_count", "1")
}

///|
test "ipynb product path keeps notebook semantics assets and malformed fallback explicit" {
  let semantic = default_registry_parse(
    @input.input_from_text_with_format(
      "{\n" +
      "  \"nbformat\": 4,\n" +
      "  \"nbformat_minor\": 5,\n" +
      "  \"metadata\": {\n" +
      "    \"kernelspec\": {\"name\": \"python3\", \"display_name\": \"Python 3\"},\n" +
      "    \"language_info\": {\"name\": \"python\", \"version\": \"3.11\"}\n" +
      "  },\n" +
      "  \"cells\": [\n" +
      "    {\n" +
      "      \"cell_type\": \"markdown\",\n" +
      "      \"id\": \"m1\",\n" +
      "      \"attachments\": {\n" +
      "        \"dot.png\": {\n" +
      "          \"image/png\": \"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0MsAAAAASUVORK5CYII=\"\n" +
      "        }\n" +
      "      },\n" +
      "      \"source\": [\"![dot](attachment:dot.png)\\n\"]\n" +
      "    },\n" +
      "    {\n" +
      "      \"cell_type\": \"code\",\n" +
      "      \"id\": \"c1\",\n" +
      "      \"execution_count\": 1,\n" +
      "      \"source\": \"display('ok')\\n\",\n" +
      "      \"outputs\": [\n" +
      "        {\n" +
      "          \"output_type\": \"display_data\",\n" +
      "          \"data\": {\n" +
      "            \"image/png\": \"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0MsAAAAASUVORK5CYII=\",\n" +
      "            \"text/plain\": [\"<Image>\\n\"]\n" +
      "          }\n" +
      "        }\n" +
      "      ]\n" +
      "    }\n" +
      "  ]\n" +
      "}\n",
      "semantic.ipynb",
      Some(@input.DetectedFormat::Ipynb),
    ),
    @input.DetectedFormat::Ipynb,
  )
  let malformed = default_registry_parse(
    @input.input_from_text_with_format(
      "{\"nbformat\":4,\"cells\":\"oops\"}\n",
      "malformed.ipynb",
      Some(@input.DetectedFormat::Ipynb),
    ),
    @input.DetectedFormat::Ipynb,
  )
  let semantic_doc = semantic.document.unwrap_or(@core.empty_document_ir())
  let malformed_doc = malformed.document.unwrap_or(@core.empty_document_ir())
  let semantic_texts = flatten_block_texts(semantic_doc.blocks)
  assert_true(semantic_doc.blocks.length() >= 5)
  assert_true(semantic_doc.assets.length() == 2)
  assert_true(semantic_texts.contains("[Cell 1 | markdown]"))
  assert_true(semantic_texts.contains("[Cell 2 | code | execution=1]"))
  assert_true(
    semantic_texts.contains("[Output 2.1 | display_data | image/png]"),
  )
  let attachment_asset = semantic_doc.assets[0]
  assert_true(
    attachment_asset.path == Some("assets/ipynb-cell01-attachment-dot-png.png"),
  )
  assert_true(
    attachment_asset.attrs.get("inline_payload_kind") == Some("base64"),
  )
  assert_true(
    semantic_doc.assets
    .map(fn(asset) { asset.path.unwrap_or("") })
    .contains("assets/ipynb-cell02-output01.png"),
  )
  assert_metric_eq(semantic.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(semantic.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(semantic.diagnostics, "asset_count", "2")
  assert_true(
    !semantic.diagnostics.degraded_features.contains(
      "ipynb_raw_fenced_fallback",
    ),
  )
  assert_true(malformed_doc.blocks.length() == 1)
  assert_true(malformed_doc.blocks[0].kind == @core.BlockKind::Code)
  assert_true(
    malformed.diagnostics.degraded_features.contains(
      "ipynb_raw_fenced_fallback",
    ),
  )
  assert_true(malformed.diagnostics.warnings.length() > 0)
  assert_metric_eq(malformed.diagnostics, "syntax_error_count", "1")
}

///|
test "ipynb html output without visible html lowering falls back to fenced html" {
  let semantic = default_registry_parse(
    @input.input_from_text_with_format(
      "{\n" +
      "  \"nbformat\": 4,\n" +
      "  \"nbformat_minor\": 5,\n" +
      "  \"metadata\": {\"language_info\": {\"name\": \"python\"}},\n" +
      "  \"cells\": [\n" +
      "    {\n" +
      "      \"cell_type\": \"code\",\n" +
      "      \"execution_count\": 3,\n" +
      "      \"source\": \"display(HTML('<script>console.log(1)</script>'))\\n\",\n" +
      "      \"outputs\": [\n" +
      "        {\n" +
      "          \"output_type\": \"execute_result\",\n" +
      "          \"execution_count\": 3,\n" +
      "          \"data\": {\n" +
      "            \"text/html\": [\"<script>console.log(1)</script>\\n\"],\n" +
      "            \"text/plain\": [\"<IPython.core.display.HTML object>\\n\"]\n" +
      "          }\n" +
      "        }\n" +
      "      ]\n" +
      "    }\n" +
      "  ]\n" +
      "}\n",
      "html-output.ipynb",
      Some(@input.DetectedFormat::Ipynb),
    ),
    @input.DetectedFormat::Ipynb,
  )
  let semantic_doc = semantic.document.unwrap_or(@core.empty_document_ir())
  let semantic_texts = flatten_block_texts(semantic_doc.blocks)
  let html_blocks = semantic_doc.blocks.filter(fn(block) {
    block.kind == @core.BlockKind::Code &&
    block.attrs.get("info") == Some("html")
  })
  assert_true(
    semantic_texts.contains("[Output 1.1 | execute_result | text/html]"),
  )
  assert_true(html_blocks.length() == 1)
  assert_true(html_blocks[0].text.contains("<script>console.log(1)</script>"))
  assert_true(
    semantic.diagnostics.degraded_features.contains(
      "ipynb_html_output_empty_visible_payload",
    ),
  )
}

///|
test "ipynb javascript mime output is preferred over plain object repr" {
  let semantic = default_registry_parse(
    @input.input_from_text_with_format(
      "{\n" +
      "  \"nbformat\": 4,\n" +
      "  \"nbformat_minor\": 5,\n" +
      "  \"metadata\": {\"language_info\": {\"name\": \"python\"}},\n" +
      "  \"cells\": [\n" +
      "    {\n" +
      "      \"cell_type\": \"code\",\n" +
      "      \"execution_count\": 7,\n" +
      "      \"source\": \"%%javascript\\nconsole.log('hi')\\n\",\n" +
      "      \"outputs\": [\n" +
      "        {\n" +
      "          \"output_type\": \"display_data\",\n" +
      "          \"data\": {\n" +
      "            \"application/javascript\": [\"console.log(\\\"hi\\\");\"],\n" +
      "            \"text/plain\": [\"<IPython.core.display.Javascript object>\\n\"]\n" +
      "          }\n" +
      "        }\n" +
      "      ]\n" +
      "    }\n" +
      "  ]\n" +
      "}\n",
      "javascript-output.ipynb",
      Some(@input.DetectedFormat::Ipynb),
    ),
    @input.DetectedFormat::Ipynb,
  )
  let semantic_doc = semantic.document.unwrap_or(@core.empty_document_ir())
  let semantic_texts = flatten_block_texts(semantic_doc.blocks)
  let js_blocks = semantic_doc.blocks.filter(fn(block) {
    block.kind == @core.BlockKind::Code &&
    block.attrs.get("info") == Some("javascript")
  })
  let output_js_blocks = js_blocks.filter(fn(block) {
    let source_ref = block.source_ref.unwrap_or(@core.empty_source_ref())
    source_ref.extra.get("ipynb_output_kind") == Some("display_data")
  })
  assert_true(
    semantic_texts.contains(
      "[Output 1.1 | display_data | application/javascript]",
    ),
  )
  assert_true(output_js_blocks.length() == 1)
  assert_true(output_js_blocks[0].text.contains("console.log(\"hi\");"))
  assert_true(
    !flatten_block_texts([output_js_blocks[0]]).contains(
      "<IPython.core.display.Javascript object>",
    ),
  )
}

///|
test "tsv resource limits contract also degrades with diagnostics" {
  let result = convert_memory_text(
    "a\tb\tc\n1\t2\t3\n4\t5\t6\n",
    "limits.tsv",
    @input.DetectedFormat::Tsv,
    mode=@convert.ConvertMode::Stream,
    limits=limits(2, 1, 2),
  )
  assert_true(result.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(result.diagnostics.warnings.length() > 0)
  assert_true(result.diagnostics.degraded_features.length() > 0)
  assert_true(
    result.diagnostics.metrics.get("builder_input_kind") == Some("event_stream"),
  )
  assert_true(
    result.diagnostics.metrics.get("truncated_column_count") == Some("2"),
  )
  assert_true(
    result.diagnostics.metrics.get("truncated_row_count") == Some("1"),
  )
  assert_true(
    result.diagnostics.metrics.get("truncated_cell_count") == Some("7"),
  )
}

///|
test "asset ref stays first class even when renderer uses core blocks only" {
  let asset_source = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some("asset.md"),
    Some("markdown"),
    Some(1),
    Some(1),
  )
  let asset = @core.make_asset_ref(
    @core.AssetKind::Image,
    "img-1",
    source_ref=asset_source,
  )
  let asset = {
    ..asset,
    path: Some("images/demo.png"),
    mime_type: Some("image/png"),
  }
  let image = @core.make_block(
    @core.BlockKind::Image,
    "",
    source_ref=asset_source,
  )
  image.attrs.set("alt", "demo")
  image.attrs.set("path", asset.path.unwrap_or("#"))
  let document = @core.document_from_blocks([image])
  document.assets.push(asset)
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(rendered.content.contains("![demo](images/demo.png)"))
  assert_true(document.assets.length() == 1)
  assert_true(document.assets[0].asset_kind == @core.AssetKind::Image)
}

///|
test "markdown image blocks keep linked asset refs in the root-pipeline document" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "![diagram](images/demo.png)\n",
      "asset.md",
      Some(@input.DetectedFormat::Markdown),
    ),
    @input.DetectedFormat::Markdown,
  )
  let document = unwrap_pipeline_output(
    @pipeline.run_pipeline(
      @pipeline.default_pass_pipeline(),
      @runtime.parse_result_to_ir_input(parsed),
      @pipeline.make_pass_context(false, "balanced"),
    ),
    "markdown image pipeline",
  )
  assert_true(document.blocks.length() == 1)
  assert_true(document.assets.length() == 1)
  assert_true(document.assets[0].asset_kind == @core.AssetKind::Image)
  assert_true(document.assets[0].path == Some("assets/image01.png"))
  assert_true(document.assets[0].attrs.get("alt") == Some("diagram"))
  assert_true(
    document.blocks[0].attrs.get("asset_id") == Some("markdown-image-1"),
  )
}

///|
test "path input can run root convert without touching old cli" {
  let root = test_tmp_root()
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let path = root + "/sample.txt"
  write_utf8_text(path, "One\n\nTwo")
  let options = @convert.default_convert_options()
  let result = match
    @convert.convert_input(@input.input_from_path(path), options) {
    Ok(value) => value
    Err(err) => fail("convert failed: " + err.to_string())
  }
  assert_eq(result.content, "One\n\nTwo")
  assert_true(result.diagnostics.metrics.get("input_kind") == Some("path"))
}

///|
test "product main cli points directly at the root cli entry" {
  let cli_main = read_utf8_text("cli/main.mbt")
  let cli_pkg = read_utf8_text("cli/moon.pkg")
  let cli_impl = read_utf8_text("cli/cli.mbt")
  let convert_pkg = read_utf8_text("convert/moon.pkg")
  let tests_pkg = read_utf8_text("tests/moon.pkg")
  let contract_script = read_utf8_text(
    "samples/helpers/contracts/check_root_contracts.sh",
  )
  let sample_gate = read_utf8_text("samples/check.sh")
  assert_true(cli_main.contains("run_cli_app(@sys.get_cli_args())"))
  assert_true(cli_pkg.contains("\"is-main\": true"))
  assert_true(cli_pkg.contains("ZSeanYves/markitdown/convert"))
  assert_true(cli_pkg.contains("ZSeanYves/markitdown/input"))
  assert_true(!cli_pkg.contains("ZSeanYves/markitdown/next/cli"))
  assert_true(!cli_pkg.contains("ZSeanYves/markitdown/convert/"))
  assert_true(cli_impl.contains("@convert.convert_input"))
  assert_true(convert_pkg.contains("ZSeanYves/markitdown/formats"))
  assert_true(tests_pkg.contains("ZSeanYves/markitdown/convert"))
  assert_true(contract_script.contains("check_pdf_signal_contract.sh"))
  assert_true(
    sample_gate.contains("samples/helpers/validation/check_samples_impl.sh"),
  )
  assert_true(!@fs.path_exists("unmigrated/moon.mod"))
  assert_true(!@fs.path_exists("unmigrated/cli_support"))
  assert_true(!@fs.path_exists("unmigrated/convert/convert/dispatcher.mbt"))
  assert_true(!@fs.path_exists("cli_support"))
  assert_true(!@fs.path_exists("next"))
  assert_true(!@fs.path_exists("convert/pdf_v2"))
  assert_true(!@fs.path_exists("doc_parse/pdf_v2"))
  assert_true(!@fs.path_exists("adapters"))
  assert_true(!@fs.path_exists("cli/next_textlike_route.mbt"))
  assert_files_avoid_strings(
    [
      "cli/moon.pkg", "cli/cli.mbt", "convert/moon.pkg", "convert/convert.mbt", "tests/moon.pkg",
      "samples/check.sh", "samples/helpers/contracts/check_root_contracts.sh", "samples/helpers/contracts/check_pdf_signal_contract.sh",
      "samples/helpers/validation/check_samples_impl.sh",
    ],
    [
      "ZSeanYves/markitdown/unmigrated/", "ZSeanYves/markitdown/cli_support", "ZSeanYves/markitdown/adapters",
      "ZSeanYves/markitdown/next/", "ZSeanYves/markitdown/convert/pdf_v2", "ZSeanYves/markitdown/doc_parse/pdf_v2",
    ],
  )
}

///|
test "root package manifests avoid retired convert and core runtime dependencies" {
  let package_files = [
    "cli/moon.pkg", "input/moon.pkg", "core/moon.pkg", "parser/moon.pkg", "formats/moon.pkg",
    "container/moon.pkg", "format_readers/ooxml/shared/moon.pkg", "pipeline/moon.pkg",
    "render/moon.pkg", "convert/moon.pkg", "tests/moon.pkg",
  ]
  for file in package_files {
    let content = read_utf8_text(file)
    assert_true(!content.contains("ZSeanYves/markitdown/unmigrated/"))
  }
  let formats_pkg = read_utf8_text("formats/moon.pkg")
  let json_pkg = read_utf8_text("formats/json/moon.pkg")
  let toml_pkg = read_utf8_text("formats/toml/moon.pkg")
  let xml_pkg = read_utf8_text("formats/xml/moon.pkg")
  let yaml_pkg = read_utf8_text("formats/yaml/moon.pkg")
  assert_true(json_pkg.contains("ZSeanYves/markitdown/format_readers/json"))
  assert_true(toml_pkg.contains("ZSeanYves/markitdown/format_readers/toml"))
  assert_true(xml_pkg.contains("ZSeanYves/markitdown/format_readers/xml"))
  assert_true(yaml_pkg.contains("ZSeanYves/markitdown/format_readers/yaml"))
  assert_true(!formats_pkg.contains("ZSeanYves/markitdown/convert/json"))
  assert_true(!formats_pkg.contains("ZSeanYves/markitdown/convert/toml"))
  assert_true(!formats_pkg.contains("ZSeanYves/markitdown/convert/xml"))
  assert_true(!formats_pkg.contains("ZSeanYves/markitdown/convert/yaml"))
  let json_impl = read_package_mbt_sources("formats/json")
  let toml_impl = read_package_mbt_sources("formats/toml")
  let xml_impl = read_package_mbt_sources("formats/xml")
  assert_true(!json_impl.contains("@oldjson"))
  assert_true(!json_impl.contains("@legacy"))
  assert_true(!json_impl.contains("convert/json"))
  assert_true(!toml_impl.contains("@legacy"))
  assert_true(!toml_impl.contains("convert/toml"))
  assert_true(!xml_impl.contains("@legacy"))
  assert_true(!xml_impl.contains("convert/xml"))
  let yaml_impl = read_package_mbt_sources("formats/yaml")
  assert_true(yaml_impl.contains("@dyaml.parse_yaml_structure_document"))
  assert_true(!yaml_impl.contains("convert/yaml"))
  let render_impl = read_utf8_text("render/render.mbt")
  assert_true(!render_impl.contains("emitter_markdown"))
  let cli_impl = read_utf8_text("cli/cli.mbt")
  assert_true(!cli_impl.contains("@clisup"))
  let container_pkg = read_utf8_text("container/moon.pkg")
  let container_impl = read_utf8_text("container/contracts.mbt")
  let office_pkg = read_utf8_text("format_readers/ooxml/shared/moon.pkg")
  let office_impl = read_package_mbt_sources("format_readers/ooxml/shared")
  assert_true(!container_pkg.contains("ZSeanYves/markitdown/convert"))
  assert_true(!container_pkg.contains("ZSeanYves/markitdown/unmigrated/"))
  assert_true(!container_impl.contains("ZSeanYves/markitdown/convert/"))
  assert_true(!container_impl.contains("ZSeanYves/markitdown/unmigrated/"))
  assert_true(!container_impl.contains("@legacy"))
  assert_true(!office_pkg.contains("ZSeanYves/markitdown/convert"))
  assert_true(!office_pkg.contains("ZSeanYves/markitdown/unmigrated/"))
  assert_true(!office_impl.contains("ZSeanYves/markitdown/convert/"))
  assert_true(!office_impl.contains("ZSeanYves/markitdown/unmigrated/"))
  assert_true(!office_impl.contains("@legacy"))
}

///|
test "zip foundation contract reuses the active zip reader and avoids custom decompressor or retired convert layers" {
  let formats_pkg = read_utf8_text("formats/moon.pkg")
  let zip_pkg = read_utf8_text("formats/zip/moon.pkg")
  let cli_pkg = read_utf8_text("cli/moon.pkg")
  let registry_impl = read_utf8_text("formats/registry.mbt")
  let zip_parser = read_package_mbt_sources("formats/zip")
  let runtime_impl = read_utf8_text("runtime/runtime.mbt")
  let zip_reader_pkg = read_utf8_text("format_readers/zip/moon.pkg")
  assert_contains_all(formats_pkg, ["ZSeanYves/markitdown/formats/zip"])
  assert_contains_all(zip_pkg, [
    "ZSeanYves/markitdown/format_readers/zip", "ZSeanYves/markitdown/container",
    "ZSeanYves/markitdown/runtime",
  ])
  assert_contains_all(cli_pkg, ["ZSeanYves/markitdown/format_readers/zip"])
  assert_contains_all(zip_reader_pkg, ["bikallem/compress/flate"])
  assert_contains_all(registry_impl, [
    "@input.DetectedFormat::Zip", "@fzip.zip_container_parser(fn() { builtin_registry() })",
  ])
  assert_contains_all(zip_parser, [
    "@dzip.open_zip", "@dzip.inspect_zip_archive", "@dzip.read_entry", "@dzip.normalize_entry_path",
    "registry_provider", "@runtime.parse_child_to_document",
  ])
  assert_contains_all(runtime_impl, [
    "pub fn parse_child_to_document", "@parser.registry_parse(registry, source, inner_context)",
  ])
  assert_contains_none(formats_pkg, [
    "ZSeanYves/markitdown/format_readers/zip", "ZSeanYves/markitdown/container",
    "ZSeanYves/markitdown/runtime", "ZSeanYves/markitdown/convert/zip", "ZSeanYves/markitdown/convert/zip_core",
    "bikallem/compress/flate",
  ])
  assert_contains_none(cli_pkg, [
    "ZSeanYves/markitdown/convert/zip", "ZSeanYves/markitdown/convert/zip_core",
  ])
  assert_contains_none(zip_parser, [
    "@flate", "bikallem/compress/flate", "convert/zip", "convert/zip_core", "zip_legacy_fallback",
    "zip_raw_fallback",
  ])
}

///|
test "root runtime and exposed parser foundations stay free of retired runtime imports" {
  assert_files_avoid_strings(
    [
      "cli/main.mbt", "cli/moon.pkg", "cli/cli.mbt", "convert/moon.pkg", "convert/convert.mbt",
      "formats/moon.pkg", "formats/registry.mbt", "formats/zip/parser.mbt", "formats/epub/parser.mbt",
      "formats/html/parser.mbt", "container/moon.pkg", "container/contracts.mbt",
      "render/moon.pkg", "core/moon.pkg", "core/core.mbt",
    ],
    ["ZSeanYves/markitdown/unmigrated/", "ZSeanYves/markitdown/convert/"],
  )
  assert_files_avoid_strings(
    [
      "format_readers/txt/moon.pkg", "format_readers/txt/text_types.mbt", "format_readers/txt/text_parser.mbt",
      "format_readers/txt/text_inspect.mbt", "format_readers/txt/text_profile_internal.mbt",
      "format_readers/csv/moon.pkg", "format_readers/csv/csv_types.mbt", "format_readers/csv/csv_parser.mbt",
      "format_readers/csv/csv_inspect.mbt", "format_readers/tsv/moon.pkg", "format_readers/tsv/tsv_parser.mbt",
      "format_readers/json/moon.pkg", "format_readers/json/json_types.mbt", "format_readers/json/json_parser.mbt",
      "format_readers/json/json_inspect.mbt", "format_readers/json/json_profile_internal.mbt",
      "format_readers/toml/moon.pkg", "format_readers/toml/toml_types.mbt", "format_readers/toml/toml_parser.mbt",
      "format_readers/toml/toml_inspect.mbt", "format_readers/xml/moon.pkg", "format_readers/xml/xml_types.mbt",
      "format_readers/xml/xml_tokenizer.mbt", "format_readers/xml/xml_parser.mbt",
      "format_readers/xml/xml_inspect.mbt", "format_readers/yaml/moon.pkg", "format_readers/yaml/yaml_types.mbt",
      "format_readers/yaml/yaml_parser.mbt", "format_readers/yaml/yaml_inspect.mbt",
      "format_readers/yaml/yaml_profile_internal.mbt", "format_readers/html/moon.pkg",
      "format_readers/html/html_types.mbt", "format_readers/html/html_guards.mbt",
      "format_readers/html/html_tokenizer.mbt", "format_readers/html/html_semantic.mbt",
      "format_readers/html/html_parser.mbt", "format_readers/html/html_inspect.mbt",
      "format_readers/zip/moon.pkg", "format_readers/zip/zip_types.mbt", "format_readers/zip/zip_codec.mbt",
      "format_readers/zip/zip_codec_backend.mbt", "format_readers/zip/zip_reader.mbt",
    ],
    [
      "ZSeanYves/markitdown/convert/", "ZSeanYves/markitdown/cli_support", "emitter_markdown",
    ],
  )
  assert_file_contains_none("render/render.mbt", [
    "emitter_markdown", "render_legacy_table", "render_markdown_note_ref",
  ])
  assert_file_contains_none("core/core.mbt", ["@cor"])
  assert_file_contains_all("cli/main.mbt", ["run_cli_app(@sys.get_cli_args())"])
}

///|
test "root convert points directly to canonical root pipeline formats semantics" {
  let convert_pkg = read_utf8_text("convert/moon.pkg")
  let convert_impl = read_utf8_text("convert/convert.mbt")
  assert_true(convert_pkg.contains("ZSeanYves/markitdown/formats"))
  assert_true(convert_impl.contains("@formats.builtin_registry()"))
  assert_true(!@fs.path_exists("adapters"))
}

///|
test "cli package stays isolated from retired layers and calls root convert" {
  let cli_pkg = read_utf8_text("cli/moon.pkg")
  let cli_impl = read_utf8_text("cli/cli.mbt")
  assert_true(cli_pkg.contains("ZSeanYves/markitdown/convert"))
  assert_true(!cli_pkg.contains("ZSeanYves/markitdown/cli_support"))
  assert_true(!cli_pkg.contains("ZSeanYves/markitdown/convert/"))
  assert_true(!cli_pkg.contains("ZSeanYves/markitdown/unmigrated/"))
  assert_true(cli_impl.contains("@convert.convert_input"))
  assert_true(!cli_impl.contains("@clisup"))
}

///|
test "zip parser stays on block stream archive entry contracts even when stream mode is requested" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/zip/markdown/zip_basic_structured.zip",
    ),
    @input.DetectedFormat::Zip,
    requested_mode=Some(@parser.ParserMode::StreamingEvent),
  )

  assert_true(parsed.parser_name == "zip_container_parser")
  assert_true(parsed.mode == @parser.ParserMode::ContainerRecursive)
  assert_true(
    parsed.capabilities.parser_mode == @parser.ParserMode::ContainerRecursive,
  )
  assert_true(
    parsed.capabilities.streaming_granularity ==
    @parser.StreamingGranularity::ArchiveEntry,
  )
  match parsed.event_stream {
    Some(_) => fail("zip parse result must not expose an event stream")
    None => ()
  }
  match parsed.block_stream {
    Some(_) => ()
    None => fail("zip parse result must expose a block stream")
  }
  match parsed.document {
    Some(_) => fail("zip parse result must not expose a document IR directly")
    None => ()
  }
  assert_metric_eq(parsed.diagnostics, "requested_mode", "streaming_event")
  assert_metric_eq(parsed.diagnostics, "effective_mode", "container_recursive")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "archive_entry")
  assert_metric_absent(parsed.diagnostics, "streaming_fallback")
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "zip_streaming_fallback=deferred", "zip_raw_fallback", "zip_legacy_fallback",
  ])
}

///|
test "zip parser keeps root-pipeline merged block output and source refs" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/zip/markdown/zip_mixed_supported_entries.zip",
    ),
    @input.DetectedFormat::Zip,
  )
  let blocks = parsed.block_stream.unwrap_or([])
  assert_contains_all(parsed.diagnostics.pass_trace.join("\n"), [
    "parse:zip_container_parser", "parse:markdown_parser", "parse:json_parser", "parse:html_parser",
    "parse:csv_parser", "parse:txt_parser",
  ])
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "legacy dispatcher", "convert/html", "convert/markdown", "convert/zip_core",
    "zip_raw_fallback", "zip_legacy_fallback",
  ])
  let entry_heading = match
    find_block_in_tree(blocks, @core.BlockKind::Heading, "alpha/readme.md") {
    Some(block) => block
    None => fail("missing archive entry heading block for alpha/readme.md")
  }
  let inner_heading = match
    find_block_in_tree(blocks, @core.BlockKind::Heading, "Alpha") {
    Some(block) => block
    None => fail("missing inner markdown heading block for alpha/readme.md")
  }
  assert_true(block_tree_has_kind(blocks, @core.BlockKind::Table))
  assert_true(!block_tree_contains_text_fragment(blocks, "# alpha/readme.md"))
  assert_true(!block_tree_contains_text_fragment(blocks, "| --- | --- |"))
  let entry_ref = match entry_heading.source_ref {
    Some(value) => value
    None => fail("entry heading should keep a source ref")
  }
  let inner_ref = match inner_heading.source_ref {
    Some(value) => value
    None => fail("inner heading should keep a source ref")
  }
  assert_true(
    entry_ref.container_path == Some("zip_mixed_supported_entries.zip"),
  )
  assert_true(entry_ref.entry_path == Some("alpha/readme.md"))
  assert_true(entry_ref.entry_format == Some("markdown"))
  assert_true(entry_ref.inner_path == None)
  assert_true(
    inner_ref.container_path == Some("zip_mixed_supported_entries.zip"),
  )
  assert_true(inner_ref.entry_path == Some("alpha/readme.md"))
  assert_true(inner_ref.entry_format == Some("markdown"))
  assert_true(inner_ref.inner_path == Some("/heading[0]"))
  assert_true(inner_ref.entry_index == entry_ref.entry_index)
}

///|
test "zip convert result keeps root container diagnostics and source refs" {
  let result = convert_path(
    "samples/main_process/zip/markdown/zip_basic_structured.zip",
    format=Some(@input.DetectedFormat::Zip),
  )
  assert_true(result.content.contains("# data/person.json"))
  assert_true(
    result.content.contains("> Skipped: nested archive is not supported: zip"),
  )
  assert_true(result.parser_mode == @parser.ParserMode::ContainerRecursive)
  assert_true(
    result.diagnostics.metrics.get("parser_name") ==
    Some("zip_container_parser"),
  )
  assert_true(
    result.diagnostics.metrics.get("parser_mode") == Some("container_recursive"),
  )
  assert_true(
    result.diagnostics.metrics.get("effective_mode") ==
    Some("container_recursive"),
  )
  assert_true(result.diagnostics.metrics.get("detected_format") == Some("zip"))
  assert_true(
    result.diagnostics.metrics.get("ir_input_kind") == Some("block_stream"),
  )
  assert_true(
    result.diagnostics.metrics.get("event_granularity") == Some("archive_entry"),
  )
  assert_true(
    result.diagnostics.metrics.get("selected_entry_count") == Some("4"),
  )
  assert_true(
    result.diagnostics.metrics.get("skipped_entry_count") == Some("2"),
  )
  assert_true(
    result.diagnostics.metrics.get("unsupported_entry_count") == Some("2"),
  )
  assert_true(
    result.diagnostics.metrics.get("container_entry_count") == Some("13"),
  )
  assert_true(
    result.diagnostics.metrics.get("nested_archive_count") == Some("1"),
  )
  for
    key in [
      "container_entry_count", "selected_entry_count", "skipped_entry_count", "unsupported_entry_count",
      "asset_count", "total_uncompressed_bytes", "max_compression_ratio_observed",
      "path_traversal_count", "duplicate_path_count", "encrypted_entry_count", "unsupported_compression_count",
      "resource_limit_hit", "nested_archive_count",
    ] {
    assert_metric_present(result.diagnostics, key)
  }
  assert_true(result.diagnostics.pass_trace.length() > 0)
  assert_true(result.diagnostics.fallback_trace.length() > 0)
  assert_diagnostics_lists_contain_none(result.diagnostics, [
    "zip_legacy_fallback", "zip_raw_fallback",
  ])
}

///|
test "epub foundation contract reuses active epub and zip readers plus root html without retired bridges" {
  let formats_pkg = read_utf8_text("formats/moon.pkg")
  let epub_pkg = read_utf8_text("formats/epub/moon.pkg")
  let html_pkg = read_utf8_text("formats/html/moon.pkg")
  let cli_pkg = read_utf8_text("cli/moon.pkg")
  let registry_impl = read_utf8_text("formats/registry.mbt")
  let epub_parser = read_package_mbt_sources("formats/epub")
  let runtime_impl = read_utf8_text("runtime/runtime.mbt")
  let epub_reader_pkg = read_utf8_text("format_readers/epub/moon.pkg")
  let zip_reader_pkg = read_utf8_text("format_readers/zip/moon.pkg")
  assert_contains_all(formats_pkg, [
    "ZSeanYves/markitdown/formats/epub", "ZSeanYves/markitdown/formats/html",
  ])
  assert_contains_all(epub_pkg, [
    "ZSeanYves/markitdown/format_readers/epub", "ZSeanYves/markitdown/runtime",
  ])
  assert_contains_all(html_pkg, ["ZSeanYves/markitdown/format_readers/html"])
  assert_contains_all(cli_pkg, ["ZSeanYves/markitdown/format_readers/zip"])
  assert_contains_all(epub_reader_pkg, [
    "ZSeanYves/markitdown/format_readers/zip",
  ])
  assert_contains_all(zip_reader_pkg, ["bikallem/compress/flate"])
  assert_contains_all(registry_impl, [
    "@input.DetectedFormat::Epub", "@fepub.epub_package_parser(fn() { builtin_registry() })",
    "@input.DetectedFormat::Html", "@fhtml.html_parser()",
  ])
  assert_contains_all(epub_parser, [
    "@depub.open_epub_package", "@depub.inspect_epub_package", "@depub.read_part_bytes",
    "registry_provider", "@runtime.parse_child_to_block_product",
  ])
  assert_contains_all(runtime_impl, [
    "pub fn parse_child_to_document", "pub fn parse_child_to_block_product", "@parser.registry_parse(registry, source, inner_context)",
  ])
  assert_contains_none(formats_pkg, [
    "ZSeanYves/markitdown/format_readers/epub", "ZSeanYves/markitdown/format_readers/zip",
    "ZSeanYves/markitdown/format_readers/html", "ZSeanYves/markitdown/pipeline",
    "ZSeanYves/markitdown/runtime", "ZSeanYves/markitdown/convert/epub", "ZSeanYves/markitdown/convert/html",
    "ZSeanYves/markitdown/unmigrated/",
  ])
  assert_contains_none(cli_pkg, [
    "ZSeanYves/markitdown/convert/epub", "ZSeanYves/markitdown/convert/html",
  ])
  assert_contains_none(epub_reader_pkg, ["ZSeanYves/markitdown/convert/"])
  assert_contains_none(epub_parser, [
    "@flate", "bikallem/compress/flate", "convert/epub", "convert/html", "epub_raw_fallback",
    "epub_legacy_fallback",
  ])
}

///|
test "epub parser stays on package single pass block stream contracts even when stream mode is requested" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/epub/markdown/epub_basic_package.epub",
    ),
    @input.DetectedFormat::Epub,
    requested_mode=Some(@parser.ParserMode::StreamingEvent),
  )

  assert_true(parsed.parser_name == "epub_package_parser")
  assert_true(parsed.mode == @parser.ParserMode::PackageSinglePass)
  assert_true(
    parsed.capabilities.parser_mode == @parser.ParserMode::PackageSinglePass,
  )
  assert_true(
    parsed.capabilities.streaming_granularity ==
    @parser.StreamingGranularity::EpubSpineItem,
  )
  match parsed.event_stream {
    Some(_) => fail("epub parse result must not expose an event stream")
    None => ()
  }
  match parsed.block_stream {
    Some(_) => ()
    None => fail("epub parse result must expose a block stream")
  }
  match parsed.document {
    Some(_) => fail("epub parse result must not expose a document IR directly")
    None => ()
  }
  assert_metric_eq(parsed.diagnostics, "requested_mode", "streaming_event")
  assert_metric_eq(parsed.diagnostics, "effective_mode", "package_single_pass")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "epub_spine_item")
  assert_metric_absent(parsed.diagnostics, "streaming_fallback")
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "epub_streaming_fallback=deferred", "epub_raw_fallback", "epub_legacy_fallback",
  ])
}

///|
test "epub parser preserves opf spine order and root html source refs without parser markdown emission" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/epub/markdown/epub_spine_order.epub",
    ),
    @input.DetectedFormat::Epub,
  )
  let blocks = parsed.block_stream.unwrap_or([])
  let block_texts = flatten_block_texts(blocks)
  assert_ordered_strings(block_texts, "Chapter Two", "Chapter One")
  assert_true(!block_tree_contains_text_fragment(blocks, "# Chapter Two"))
  assert_true(!block_tree_contains_text_fragment(blocks, "# Chapter One"))
  let chapter_two = match
    find_block_in_tree(blocks, @core.BlockKind::Heading, "Chapter Two") {
    Some(block) => block
    None => fail("missing chapter two heading block")
  }
  let chapter_one = match
    find_block_in_tree(blocks, @core.BlockKind::Heading, "Chapter One") {
    Some(block) => block
    None => fail("missing chapter one heading block")
  }
  let chapter_two_ref = match chapter_two.source_ref {
    Some(value) => value
    None => fail("chapter two source ref should exist")
  }
  let chapter_one_ref = match chapter_one.source_ref {
    Some(value) => value
    None => fail("chapter one source ref should exist")
  }
  assert_true(chapter_two_ref.container_path == Some("epub_spine_order.epub"))
  assert_true(chapter_two_ref.entry_path == Some("OPS/text/chapter-02.xhtml"))
  assert_true(chapter_two_ref.entry_index == Some(0))
  assert_true(chapter_two_ref.entry_format == Some("html"))
  assert_true(chapter_two_ref.html_path == Some("/block/html:block:h1:2"))
  assert_true(chapter_two_ref.inner_path == Some("/block/html:block:h1:2"))
  assert_true(chapter_one_ref.container_path == Some("epub_spine_order.epub"))
  assert_true(chapter_one_ref.entry_path == Some("OPS/text/chapter-01.xhtml"))
  assert_true(chapter_one_ref.entry_index == Some(1))
  assert_true(chapter_one_ref.entry_format == Some("html"))
  assert_true(chapter_one_ref.html_path == Some("/block/html:block:h1:2"))
  assert_true(chapter_one_ref.inner_path == Some("/block/html:block:h1:2"))
  assert_contains_all(parsed.diagnostics.pass_trace.join("\n"), [
    "parse:epub_package_parser", "parse:html_parser",
  ])
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "legacy dispatcher", "convert/html", "convert/epub", "epub_raw_fallback", "epub_legacy_fallback",
  ])
}

///|
test "epub parser keeps missing and unsupported spine diagnostics root-pipeline and renderer owned" {
  let missing = convert_path(
    "samples/main_process/epub/markdown/epub_spine_missing_item_boundary.epub",
    format=Some(@input.DetectedFormat::Epub),
  )
  assert_true(missing.content.contains("# (missing manifest item #0: missing)"))
  assert_true(
    missing.content.contains(
      "> Skipped: spine item references missing manifest item: missing",
    ),
  )
  assert_metric_eq(missing.diagnostics, "effective_mode", "package_single_pass")
  assert_metric_eq(missing.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(missing.diagnostics, "event_granularity", "epub_spine_item")
  assert_metric_eq(missing.diagnostics, "missing_manifest_item_count", "1")
  assert_metric_eq(missing.diagnostics, "missing_spine_item_count", "1")
  assert_metric_eq(missing.diagnostics, "selected_entry_count", "1")
  assert_metric_eq(missing.diagnostics, "skipped_entry_count", "1")
  assert_true(missing.diagnostics.fallback_trace.length() > 0)
  assert_diagnostics_lists_contain_none(missing.diagnostics, [
    "epub_legacy_fallback",
  ])

  let unsupported = convert_path(
    "samples/main_process/epub/markdown/epub_unsupported_spine_warning.epub",
    format=Some(@input.DetectedFormat::Epub),
  )
  assert_true(unsupported.content.contains("# OPS/chapter.xhtml"))
  assert_true(
    unsupported.content.contains(
      "> Skipped: unsupported spine media type: image/svg+xml",
    ),
  )
  assert_metric_eq(unsupported.diagnostics, "unsupported_entry_count", "1")
  assert_metric_eq(unsupported.diagnostics, "selected_entry_count", "1")
  assert_metric_eq(unsupported.diagnostics, "skipped_entry_count", "1")
  assert_true(
    unsupported.diagnostics.degraded_features.contains(
      "epub_unsupported_spine_skip",
    ),
  )
}

///|
test "epub parser keeps remote and data image refs bounded without local asset materialization" {
  let remote_json = convert_path(
    "samples/main_process/epub/markdown/epub_remote_data_image_boundary.epub",
    format=Some(@input.DetectedFormat::Epub),
    output=@convert.OutputFormat::DebugJson,
  )
  assert_metric_eq(remote_json.diagnostics, "asset_count", "0")
  assert_metric_eq(remote_json.diagnostics, "external_resource_count", "0")
  assert_true(
    remote_json.diagnostics.degraded_features.contains(
      "html_remote_image_reference_only",
    ),
  )
  assert_true(
    remote_json.diagnostics.degraded_features.contains(
      "html_data_image_reference_only",
    ),
  )
}

///|
test "canonical architecture guide records stable parser and ir boundaries" {
  assert_file_contains_all("docs/architecture/mb-markitdown-architecture.md", [
    "ParserRegistry", "ParseResult", "CoreIRBuilder", "IR Pass Pipeline", "Renderer",
    "Parser 可以多态", "Core IR 必须统一", "Renderer 必须统一", "Markdown 是输出，不是中间表示",
    "ContainerRecursive", "page-single-pass",
  ])
}

///|
fn resolve_test_sample_path(path : String) -> String {
  if @fs.path_exists(path) {
    return path
  }
  "../../" + path
}

///|
test "xml structure scan stays stable on mixed xml input" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<root xmlns=\"urn:test\">\n" +
    "  <!-- note -->\n" +
    "  <section id=\"a\">alpha<![CDATA[```fence```]]><?pi ok?></section>\n" +
    "</root>\n"
  let scan = @xml.scan_xml_structure(xml)
  assert_true(scan.status == @xml.XmlStructureScanStatus::Success)
  assert_eq(scan.element_count, 2)
  assert_eq(scan.attribute_count, 2)
  assert_eq(scan.comment_count, 1)
  assert_eq(scan.cdata_count, 1)
  assert_eq(scan.processing_instruction_count, 1)
  assert_true(scan.node_count >= 7)
  assert_eq(scan.max_depth, 2)
  assert_true(scan.has_default_namespace)
  assert_true(scan.has_markdown_fence_text)
  assert_true(!scan.has_doctype)
}

///|
test "ooxml xml part payload exposes structure scan for workbook parts" {
  let sample_path = resolve_test_sample_path(
    "samples/main_process/xlsx/markdown/xlsx_multi_sheet_mixed.xlsx",
  )
  let pkg = @ox.open_ooxml_package(
    @fs.read_file_to_bytes(sample_path) catch {
      e => fail("expected xlsx fixture bytes: " + e.to_string())
    },
  ) catch {
    e => fail("expected ooxml package open: " + e.to_string())
  }
  let payload = @ox.read_xml_part_payload(pkg, "xl/workbook.xml") catch {
    e => fail("expected workbook payload: " + e.to_string())
  }
  assert_true(payload.text.contains("<workbook"))
  assert_true(payload.bytes.length() > 0)
  assert_true(
    payload.structure_scan.status == @xml.XmlStructureScanStatus::Success,
  )
  assert_true(payload.structure_scan.element_count > 0)
  assert_true(payload.structure_scan.max_depth > 0)
}

///|
test "epub package xml payload path keeps package open semantics stable" {
  let sample_path = resolve_test_sample_path(
    "samples/fixtures/epub/epub_remote_image.epub",
  )
  let pkg = @epub.open_epub_package(
    @fs.read_file_to_bytes(sample_path) catch {
      e => fail("expected epub fixture bytes: " + e.to_string())
    },
    "epub_remote_image.epub",
  ) catch {
    e => fail("expected epub package open: " + e.to_string())
  }
  let content = @epub.read_part_text(pkg, "OPS/content.opf") catch {
    e => fail("expected content.opf text: " + e.to_string())
  }
  assert_true(content.contains("<package"))
  assert_eq(pkg.rootfile_path, "OPS/content.opf")
  assert_true(pkg.manifest.length() > 0)
}

///|
test "shared child runtime exposes parse result lowering and child dispatch entrypoints" {
  let empty = @parser.parse_result_with_document(
    "test_runtime",
    @parser.ParserMode::PackageSinglePass,
    @core.empty_document_ir(),
    @core.empty_diagnostics(),
  )
  match @runtime.parse_result_to_ir_input(empty) {
    @core.IRInput::Document(_) => ()
    _ => fail("runtime parse_result_to_ir_input should preserve document input")
  }
  let merged = @runtime.merge_diagnostics_unique(
    @core.empty_diagnostics(),
    @core.empty_diagnostics(),
  )
  assert_true(merged.warnings.length() == 0)
  assert_true(merged.errors.length() == 0)
}

///|
test "v2 stabilization drift keeps runtime child dispatch thin and canonical pipeline visible" {
  let pipeline_impl = read_utf8_text("pipeline/pipeline.mbt")
  let pipeline_event_builder_impl = read_utf8_text(
    "pipeline/event_document_builder.mbt",
  )
  let convert_preflight_impl = read_utf8_text("convert/preflight_probe.mbt")
  let render_impl = read_utf8_text("render/render.mbt")
  let runtime_pkg = read_utf8_text("runtime/moon.pkg")
  let runtime_impl = read_utf8_text("runtime/runtime.mbt")
  let zip_impl = read_package_mbt_sources("formats/zip")
  let epub_impl = read_package_mbt_sources("formats/epub")
  let docx_impl = read_package_mbt_sources("formats/docx")
  let core_impl = read_package_mbt_sources("core")
  let core_source_ref_impl = read_utf8_text("core/source_refs.mbt")
  let core_document_impl = read_utf8_text("core/document_ops.mbt")
  let core_constructor_impl = read_utf8_text("core/constructors.mbt")

  assert_true(
    !pipeline_impl.contains("@formats.html_blocks_from_structure_events"),
  )
  assert_true(!pipeline_impl.contains("source_ref.format == Some(\"html\")"))
  assert_true(!pipeline_impl.contains("source_ref.format == Some(\"xml\")"))
  assert_true(!pipeline_impl.contains("source_ref.format == Some(\"yaml\")"))
  assert_true(
    !pipeline_impl.contains("source_ref.format == Some(\"markdown\")"),
  )
  assert_true(!pipeline_impl.contains("source_ref.format == Some(\"json\")"))
  assert_true(!pipeline_impl.contains("pub fn blocks_to_event_stream"))
  assert_true(
    pipeline_event_builder_impl.contains("@core.build_document_from_events"),
  )
  assert_true(core_impl.contains("ir_event_encoding"))
  assert_true(
    convert_preflight_impl.contains("@dhtml.tokenize_html_events(text)"),
  )
  assert_true(
    !convert_preflight_impl.contains("@dhtml.parse_html_document(text)"),
  )
  assert_true(
    !convert_preflight_impl.contains(
      "@dhtml.collect_html_semantic_document(doc)",
    ),
  )

  assert_true(!render_impl.contains("source_ref.format == Some(\"xml\")"))
  assert_true(
    !render_impl.contains("block_source_format(block) == Some(\"html\")"),
  )
  assert_true(render_impl.contains("render_inline_escape_mode"))
  assert_true(render_impl.contains("literal_text_block"))
  assert_true(!render_impl.contains("docx_note_definition_id"))
  assert_true(!render_impl.contains("docx_marker_literal"))
  assert_true(render_impl.contains("note_definition_id"))
  assert_true(render_impl.contains("annotation_role"))
  assert_true(render_impl.contains("annotation_marker"))
  assert_true(render_impl.contains("render_literal"))

  assert_true(runtime_pkg.contains("ZSeanYves/markitdown/parser"))
  assert_true(runtime_pkg.contains("ZSeanYves/markitdown/pipeline"))
  assert_true(runtime_impl.contains("pub fn parse_result_to_ir_input"))
  assert_true(runtime_impl.contains("pub fn parse_child_to_document"))
  assert_true(runtime_impl.contains("pub fn parse_child_to_block_product"))
  assert_true(
    runtime_impl.contains("@pipeline.build_document_with_default_pipeline"),
  )
  assert_true(!runtime_impl.contains("fn run_child_document_passes"))
  assert_true(!runtime_impl.contains("fn child_ir_input_to_document"))
  assert_true(!runtime_impl.contains("fn build_child_document_from_events"))
  assert_true(!runtime_impl.contains("fn normalize_block_text"))
  assert_true(!runtime_impl.contains("fn normalize_block_whitespace"))
  assert_true(!runtime_impl.contains("fn collect_document_asset_refs"))
  assert_true(zip_impl.contains("@runtime.parse_child_to_document"))
  assert_true(epub_impl.contains("@runtime.parse_child_to_block_product"))
  assert_true(!zip_impl.contains("zip_parse_result_to_ir_input"))
  assert_true(!zip_impl.contains("zip_ir_input_to_document"))
  assert_true(!zip_impl.contains("zip_run_default_passes"))
  assert_true(!epub_impl.contains("epub_parse_result_to_ir_input"))
  assert_true(!epub_impl.contains("epub_ir_input_to_document"))
  assert_true(!epub_impl.contains("epub_run_default_passes"))

  assert_true(!docx_impl.contains("docx_marker_literal"))
  assert_true(!docx_impl.contains("docx_note_definition_id"))
  assert_true(docx_impl.contains("note_definition_id"))
  assert_true(docx_impl.contains("annotation_role"))
  assert_true(docx_impl.contains("annotation_marker"))

  assert_true(core_impl.contains("pub(all) struct SourceMapEntry"))
  assert_true(core_impl.contains("pub(all) struct SourceMap"))
  assert_true(core_impl.contains("source_map : SourceMap?"))
  assert_true(core_source_ref_impl.contains("pub fn empty_source_map()"))
  assert_true(core_document_impl.contains("pub fn document_with_source_map"))
  assert_true(core_constructor_impl.contains("pub fn make_signal("))
  assert_true(core_impl.contains("RenderHint"))
  assert_true(core_impl.contains("NoteRef"))
  assert_true(core_impl.contains("CommentRef"))
}

///|
