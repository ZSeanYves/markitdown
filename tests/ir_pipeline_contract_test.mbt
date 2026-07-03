///|
test "convert pipeline preserves parser irinput contracts" {
  let txt = convert_memory_text(
    "Alpha\n\nBeta",
    "contract.txt",
    @input.DetectedFormat::Txt,
  )
  let csv = convert_memory_text(
    "a,b\n1,2\n",
    "contract.csv",
    @input.DetectedFormat::Csv,
  )
  let tsv = convert_memory_text(
    "a\tb\n1\t2\n",
    "contract.tsv",
    @input.DetectedFormat::Tsv,
  )
  let json_small = convert_memory_text(
    "{\"name\":\"Alice\"}\n",
    "contract.json",
    @input.DetectedFormat::Json,
  )
  let json_large = convert_memory_text(
    "{\"a\":1,\"b\":2}\n",
    "contract-large.json",
    @input.DetectedFormat::Json,
    limits=limits(0, 50, 10000),
  )
  let jsonl = convert_memory_text(
    "{\"name\":\"Alice\",\"score\":7}\n{\"name\":\"Bob\",\"score\":9}\n",
    "contract.jsonl",
    @input.DetectedFormat::Jsonl,
  )
  let ndjson = convert_memory_text(
    "{\"name\":\"Carol\",\"score\":5}\n{\"name\":\"Dave\",\"score\":8}\n",
    "contract.ndjson",
    @input.DetectedFormat::Ndjson,
  )
  let xml_small = convert_memory_text(
    "<root><item>Hello</item></root>\n",
    "contract.xml",
    @input.DetectedFormat::Xml,
  )
  let xml_large = convert_memory_text(
    "<root><section><item>One</item><item>Two</item></section></root>\n",
    "contract-large.xml",
    @input.DetectedFormat::Xml,
    limits=limits(1, 50, 10000),
  )
  let yaml_small = convert_memory_text(
    "name: Alice\nrole: Engineer\n",
    "contract.yaml",
    @input.DetectedFormat::Yaml,
  )
  let toml_small = convert_memory_text(
    "name = \"Alice\"\nrole = \"Engineer\"\n",
    "contract.toml",
    @input.DetectedFormat::Toml,
  )
  let srt_small = convert_memory_text(
    "1\n00:00:00,000 --> 00:00:01,000\nHello\n",
    "contract.srt",
    @input.DetectedFormat::Srt,
  )
  let vtt_small = convert_memory_text(
    "WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nHello\n",
    "contract.vtt",
    @input.DetectedFormat::Vtt,
  )
  let tex_small = convert_memory_text(
    "\\section{Title}\n\nBody\n",
    "contract.tex",
    @input.DetectedFormat::Tex,
  )
  let rst_small = convert_memory_text(
    "Title\n=====\n\nBody\n",
    "contract.rst",
    @input.DetectedFormat::Rst,
  )
  let asciidoc_small = convert_memory_text(
    "= Title\n\nBody\n",
    "contract.adoc",
    @input.DetectedFormat::Asciidoc,
  )
  let ipynb_small = convert_memory_text(
    "{\n" +
    "  \"nbformat\": 4,\n" +
    "  \"nbformat_minor\": 5,\n" +
    "  \"metadata\": {\"language_info\": {\"name\": \"python\"}},\n" +
    "  \"cells\": [\n" +
    "    {\"cell_type\": \"markdown\", \"source\": [\"# Title\\n\", \"Body\\n\"]},\n" +
    "    {\"cell_type\": \"code\", \"execution_count\": 1, \"source\": \"print(1)\\n\", \"outputs\": [{\"output_type\": \"stream\", \"name\": \"stdout\", \"text\": [\"1\\\\n\"]}]}\n" +
    "  ]\n" +
    "}\n",
    "contract.ipynb",
    @input.DetectedFormat::Ipynb,
  )
  let ipynb_large = convert_memory_text(
    "{\n" +
    "  \"nbformat\": 4,\n" +
    "  \"nbformat_minor\": 5,\n" +
    "  \"metadata\": {\"language_info\": {\"name\": \"python\"}},\n" +
    "  \"cells\": [\n" +
    "    {\"cell_type\": \"markdown\", \"source\": [\"# A\\n\"]},\n" +
    "    {\"cell_type\": \"code\", \"execution_count\": 1, \"source\": \"print(1)\\n\", \"outputs\": [{\"output_type\": \"stream\", \"name\": \"stdout\", \"text\": [\"1\\\\n\"]}]},\n" +
    "    {\"cell_type\": \"code\", \"execution_count\": 2, \"source\": \"print(2)\\n\", \"outputs\": [{\"output_type\": \"stream\", \"name\": \"stdout\", \"text\": [\"2\\\\n\"]}]}\n" +
    "  ]\n" +
    "}\n",
    "contract-large.ipynb",
    @input.DetectedFormat::Ipynb,
    mode=@convert.ConvertMode::Stream,
    limits=limits(1, 50, 4),
  )
  let yaml_large = convert_memory_text(
    "-\n  name: Alice\n  role: Engineer\n-\n  name: Bob\n  role: Designer\n",
    "contract-large.yaml",
    @input.DetectedFormat::Yaml,
    limits=limits(1, 50, 10000),
  )
  let html_small = convert_memory_text(
    "<details><summary>Open</summary><p>Body</p></details>",
    "contract.html",
    @input.DetectedFormat::Html,
  )
  let html_large = convert_memory_text(
    "<html><body><article><h1>Title</h1><p>Body</p></article></body></html>\n",
    "contract-large.html",
    @input.DetectedFormat::Html,
    limits=limits(1, 50, 10000),
  )
  let eml_small = convert_memory_text(
    "From: Alice <alice@example.com>\n" +
    "To: Bob <bob@example.com>\n" +
    "Subject: Contract Mail\n" +
    "MIME-Version: 1.0\n" +
    "Content-Type: multipart/alternative; boundary=\"alt\"\n\n" +
    "--alt\n" +
    "Content-Type: text/plain; charset=\"utf-8\"\n\n" +
    "Hello from eml.\n" +
    "--alt--\n",
    "contract.eml",
    @input.DetectedFormat::Eml,
  )

  assert_true(txt.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(csv.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(tsv.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(json_small.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(json_large.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(jsonl.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(ndjson.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(xml_small.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(xml_large.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(yaml_small.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(toml_small.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(srt_small.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(vtt_small.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(tex_small.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(rst_small.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(asciidoc_small.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(ipynb_small.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(yaml_large.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(ipynb_large.parser_mode == @parser.ParserMode::BlockStreaming)
  assert_true(html_small.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(html_large.parser_mode == @parser.ParserMode::BlockStreaming)
  assert_true(eml_small.parser_mode == @parser.ParserMode::BlockStreaming)

  assert_metric_eq(txt.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(txt.diagnostics, "builder_input_kind", "event_stream")
  assert_metric_eq(csv.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(csv.diagnostics, "builder_input_kind", "event_stream")
  assert_metric_eq(tsv.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(tsv.diagnostics, "builder_input_kind", "event_stream")
  assert_metric_eq(json_small.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(json_small.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(json_small.diagnostics, "builder_input_kind", "document")
  assert_metric_eq(json_large.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(json_large.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(json_large.diagnostics, "builder_input_kind", "event_stream")
  assert_metric_eq(jsonl.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(jsonl.diagnostics, "builder_input_kind", "event_stream")
  assert_metric_eq(ndjson.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(ndjson.diagnostics, "builder_input_kind", "event_stream")
  assert_metric_eq(xml_small.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(xml_small.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(xml_small.diagnostics, "builder_input_kind", "document")
  assert_metric_eq(xml_large.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(xml_large.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(xml_large.diagnostics, "builder_input_kind", "event_stream")
  assert_metric_eq(yaml_small.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(yaml_small.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(yaml_small.diagnostics, "builder_input_kind", "document")
  assert_metric_eq(toml_small.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(toml_small.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(toml_small.diagnostics, "builder_input_kind", "document")
  assert_metric_eq(srt_small.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(srt_small.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(srt_small.diagnostics, "builder_input_kind", "event_stream")
  assert_metric_eq(vtt_small.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(vtt_small.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(vtt_small.diagnostics, "builder_input_kind", "event_stream")
  assert_metric_eq(tex_small.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(tex_small.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(tex_small.diagnostics, "builder_input_kind", "document")
  assert_metric_eq(rst_small.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(rst_small.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(rst_small.diagnostics, "builder_input_kind", "document")
  assert_metric_eq(
    asciidoc_small.diagnostics,
    "effective_mode",
    "dom_ast_model",
  )
  assert_metric_eq(asciidoc_small.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(asciidoc_small.diagnostics, "builder_input_kind", "document")
  assert_metric_eq(ipynb_small.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(ipynb_small.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(ipynb_small.diagnostics, "builder_input_kind", "document")
  assert_metric_eq(yaml_large.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(yaml_large.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(yaml_large.diagnostics, "builder_input_kind", "event_stream")
  assert_metric_eq(ipynb_large.diagnostics, "effective_mode", "block_streaming")
  assert_metric_eq(ipynb_large.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(
    ipynb_large.diagnostics,
    "builder_input_kind",
    "block_stream",
  )
  assert_metric_eq(html_small.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(html_small.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(html_small.diagnostics, "builder_input_kind", "document")
  assert_metric_eq(html_large.diagnostics, "effective_mode", "block_streaming")
  assert_metric_eq(html_large.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(html_large.diagnostics, "builder_input_kind", "block_stream")
  assert_metric_eq(eml_small.diagnostics, "effective_mode", "block_streaming")
  assert_metric_eq(eml_small.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(eml_small.diagnostics, "builder_input_kind", "block_stream")
}

///|
test "parser capabilities expose honest streaming granularity contracts" {
  let registry = @formats_root.builtin_registry()
  let txt = @parser.registry_lookup(registry, @input.DetectedFormat::Txt).unwrap_or_else(fn() {
      abort("missing txt parser")
    },
  )
  let csv = @parser.registry_lookup(registry, @input.DetectedFormat::Csv).unwrap_or_else(fn() {
      abort("missing csv parser")
    },
  )
  let tsv = @parser.registry_lookup(registry, @input.DetectedFormat::Tsv).unwrap_or_else(fn() {
      abort("missing tsv parser")
    },
  )
  let json = @parser.registry_lookup(registry, @input.DetectedFormat::Json).unwrap_or_else(fn() {
      abort("missing json parser")
    },
  )
  let jsonl = @parser.registry_lookup(registry, @input.DetectedFormat::Jsonl).unwrap_or_else(fn() {
      abort("missing jsonl parser")
    },
  )
  let ndjson = @parser.registry_lookup(registry, @input.DetectedFormat::Ndjson).unwrap_or_else(fn() {
      abort("missing ndjson parser")
    },
  )
  let xml = @parser.registry_lookup(registry, @input.DetectedFormat::Xml).unwrap_or_else(fn() {
      abort("missing xml parser")
    },
  )
  let yaml = @parser.registry_lookup(registry, @input.DetectedFormat::Yaml).unwrap_or_else(fn() {
      abort("missing yaml parser")
    },
  )
  let toml = @parser.registry_lookup(registry, @input.DetectedFormat::Toml).unwrap_or_else(fn() {
      abort("missing toml parser")
    },
  )
  let srt = @parser.registry_lookup(registry, @input.DetectedFormat::Srt).unwrap_or_else(fn() {
      abort("missing srt parser")
    },
  )
  let vtt = @parser.registry_lookup(registry, @input.DetectedFormat::Vtt).unwrap_or_else(fn() {
      abort("missing vtt parser")
    },
  )
  let tex = @parser.registry_lookup(registry, @input.DetectedFormat::Tex).unwrap_or_else(fn() {
      abort("missing tex parser")
    },
  )
  let rst = @parser.registry_lookup(registry, @input.DetectedFormat::Rst).unwrap_or_else(fn() {
      abort("missing rst parser")
    },
  )
  let asciidoc = @parser.registry_lookup(
    registry,
    @input.DetectedFormat::Asciidoc,
  ).unwrap_or_else(fn() { abort("missing asciidoc parser") })
  let ipynb = @parser.registry_lookup(registry, @input.DetectedFormat::Ipynb).unwrap_or_else(fn() {
      abort("missing ipynb parser")
    },
  )
  let html = @parser.registry_lookup(registry, @input.DetectedFormat::Html).unwrap_or_else(fn() {
      abort("missing html parser")
    },
  )
  let eml = @parser.registry_lookup(registry, @input.DetectedFormat::Eml).unwrap_or_else(fn() {
      abort("missing eml parser")
    },
  )
  let odt = @parser.registry_lookup(registry, @input.DetectedFormat::Odt).unwrap_or_else(fn() {
      abort("missing odt parser")
    },
  )
  let ods = @parser.registry_lookup(registry, @input.DetectedFormat::Ods).unwrap_or_else(fn() {
      abort("missing ods parser")
    },
  )
  let odp = @parser.registry_lookup(registry, @input.DetectedFormat::Odp).unwrap_or_else(fn() {
      abort("missing odp parser")
    },
  )
  let zip = @parser.registry_lookup(registry, @input.DetectedFormat::Zip).unwrap_or_else(fn() {
      abort("missing zip parser")
    },
  )
  let epub = @parser.registry_lookup(registry, @input.DetectedFormat::Epub).unwrap_or_else(fn() {
      abort("missing epub parser")
    },
  )
  assert_true(txt.capability.supports_streaming)
  assert_true(txt.capability.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(
    txt.capability.streaming_granularity == @parser.StreamingGranularity::Line,
  )
  assert_true(csv.capability.supports_streaming)
  assert_true(
    csv.capability.streaming_granularity == @parser.StreamingGranularity::Row,
  )
  assert_true(tsv.capability.supports_streaming)
  assert_true(
    tsv.capability.streaming_granularity == @parser.StreamingGranularity::Row,
  )
  assert_true(json.capability.supports_streaming)
  assert_true(json.capability.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(json.capability.supports_document_ir)
  assert_true(json.capability.supports_events)
  assert_true(
    json.capability.streaming_granularity ==
    @parser.StreamingGranularity::JsonStructure,
  )
  assert_true(jsonl.capability.supports_streaming)
  assert_true(
    jsonl.capability.streaming_granularity ==
    @parser.StreamingGranularity::Record,
  )
  assert_true(ndjson.capability.supports_streaming)
  assert_true(
    ndjson.capability.streaming_granularity ==
    @parser.StreamingGranularity::Record,
  )
  assert_true(xml.capability.supports_streaming)
  assert_true(xml.capability.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(xml.capability.supports_document_ir)
  assert_true(xml.capability.supports_events)
  assert_true(
    xml.capability.streaming_granularity ==
    @parser.StreamingGranularity::XmlStructure,
  )
  assert_true(yaml.capability.supports_streaming)
  assert_true(yaml.capability.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(yaml.capability.supports_document_ir)
  assert_true(yaml.capability.supports_events)
  assert_true(
    yaml.capability.streaming_granularity ==
    @parser.StreamingGranularity::YamlStructure,
  )
  assert_true(!toml.capability.supports_streaming)
  assert_true(toml.capability.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(toml.capability.supports_document_ir)
  assert_true(!toml.capability.supports_events)
  assert_true(!toml.capability.supports_blocks)
  assert_true(
    toml.capability.streaming_granularity == @parser.StreamingGranularity::None,
  )
  assert_true(srt.capability.supports_streaming)
  assert_true(srt.capability.supports_events)
  assert_true(!srt.capability.supports_document_ir)
  assert_true(srt.capability.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(
    srt.capability.streaming_granularity == @parser.StreamingGranularity::Record,
  )
  assert_true(vtt.capability.supports_streaming)
  assert_true(vtt.capability.supports_events)
  assert_true(!vtt.capability.supports_document_ir)
  assert_true(vtt.capability.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(
    vtt.capability.streaming_granularity == @parser.StreamingGranularity::Record,
  )
  assert_true(!tex.capability.supports_streaming)
  assert_true(tex.capability.supports_document_ir)
  assert_true(tex.capability.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(
    tex.capability.streaming_granularity == @parser.StreamingGranularity::None,
  )
  assert_true(!rst.capability.supports_streaming)
  assert_true(rst.capability.supports_document_ir)
  assert_true(rst.capability.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(
    rst.capability.streaming_granularity == @parser.StreamingGranularity::None,
  )
  assert_true(!asciidoc.capability.supports_streaming)
  assert_true(asciidoc.capability.supports_document_ir)
  assert_true(
    asciidoc.capability.parser_mode == @parser.ParserMode::DomAstModel,
  )
  assert_true(
    asciidoc.capability.streaming_granularity ==
    @parser.StreamingGranularity::None,
  )
  assert_true(ipynb.capability.supports_streaming)
  assert_true(ipynb.capability.supports_blocks)
  assert_true(ipynb.capability.supports_document_ir)
  assert_true(!ipynb.capability.supports_events)
  assert_true(ipynb.capability.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(
    ipynb.capability.streaming_granularity ==
    @parser.StreamingGranularity::NotebookCellOutputGroup,
  )
  assert_true(html.capability.supports_streaming)
  assert_true(html.capability.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(html.capability.supports_document_ir)
  assert_true(html.capability.supports_blocks)
  assert_true(!html.capability.supports_events)
  assert_true(
    html.capability.streaming_granularity ==
    @parser.StreamingGranularity::HtmlTokenStructure,
  )
  assert_true(eml.capability.supports_streaming)
  assert_true(eml.capability.supports_blocks)
  assert_true(eml.capability.supports_document_ir)
  assert_true(!eml.capability.supports_events)
  assert_true(eml.capability.parser_mode == @parser.ParserMode::BlockStreaming)
  assert_true(
    eml.capability.streaming_granularity ==
    @parser.StreamingGranularity::Message,
  )
  assert_true(odt.capability.supports_streaming)
  assert_true(odt.capability.supports_blocks)
  assert_true(odt.capability.supports_document_ir)
  assert_true(!odt.capability.supports_events)
  assert_true(
    odt.capability.parser_mode == @parser.ParserMode::PackageSinglePass,
  )
  assert_true(
    odt.capability.streaming_granularity == @parser.StreamingGranularity::Block,
  )
  assert_true(ods.capability.supports_streaming)
  assert_true(ods.capability.supports_blocks)
  assert_true(ods.capability.supports_document_ir)
  assert_true(!ods.capability.supports_events)
  assert_true(
    ods.capability.parser_mode == @parser.ParserMode::PackageSinglePass,
  )
  assert_true(
    ods.capability.streaming_granularity == @parser.StreamingGranularity::Row,
  )
  assert_true(odp.capability.supports_streaming)
  assert_true(odp.capability.supports_blocks)
  assert_true(odp.capability.supports_document_ir)
  assert_true(!odp.capability.supports_events)
  assert_true(
    odp.capability.parser_mode == @parser.ParserMode::PackageSinglePass,
  )
  assert_true(
    odp.capability.streaming_granularity == @parser.StreamingGranularity::Slide,
  )
  assert_true(zip.capability.supports_streaming)
  assert_true(zip.capability.supports_blocks)
  assert_true(
    zip.capability.parser_mode == @parser.ParserMode::ContainerRecursive,
  )
  assert_true(
    zip.capability.streaming_granularity ==
    @parser.StreamingGranularity::ArchiveEntry,
  )
  assert_true(epub.capability.supports_streaming)
  assert_true(epub.capability.supports_blocks)
  assert_true(
    epub.capability.parser_mode == @parser.ParserMode::PackageSinglePass,
  )
  assert_true(
    epub.capability.streaming_granularity ==
    @parser.StreamingGranularity::EpubSpineItem,
  )
  assert_true(
    @parser.StreamingGranularity::ArchiveEntry ==
    @parser.StreamingGranularity::ArchiveEntry,
  )
  assert_true(
    @parser.StreamingGranularity::EpubSpineItem ==
    @parser.StreamingGranularity::EpubSpineItem,
  )
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
  let raw_doc = @core.document_from_blocks([
    @core.make_block(
      @core.BlockKind::Paragraph,
      "Doc",
      source_ref=@core.empty_source_ref(),
    ),
  ])
  let document_doc = (builder.build)(@core.IRInput::Document(raw_doc))
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

///|
test "markdown convert route selects block streaming for over-limit documents" {
  let result = convert_memory_text(
    "# Title\n\nParagraph\n\n- one\n- two\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n",
    "route-large.md",
    @input.DetectedFormat::Markdown,
    limits=limits(1, 1, 10000),
  )
  assert_true(result.parser_mode == @parser.ParserMode::BlockStreaming)
  assert_metric_eq(result.diagnostics, "selected_route", "block_streaming")
  assert_metric_eq(
    result.diagnostics,
    "route_reason",
    "markdown_over_limit_block_streaming",
  )
  assert_metric_eq(result.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(result.diagnostics, "builder_input_kind", "block_stream")
}

///|
test "html convert route selects block streaming when scope budgets are exceeded" {
  let result = convert_memory_text(
    "<html><body>" +
    "<section><h2>One</h2><p>A</p></section>" +
    "<section><h2>Two</h2><p>B</p></section>" +
    "</body></html>",
    "route-large.html",
    @input.DetectedFormat::Html,
    limits=limits(1, 50, 100000),
  )
  assert_true(result.parser_mode == @parser.ParserMode::BlockStreaming)
  assert_metric_eq(result.diagnostics, "selected_route", "block_streaming")
  assert_metric_eq(
    result.diagnostics,
    "route_reason",
    "html_over_limit_block_streaming",
  )
  assert_metric_eq(result.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(result.diagnostics, "builder_input_kind", "block_stream")
  assert_true(
    result.diagnostics.metrics
    .get("route_probe_summary")
    .unwrap_or("")
    .contains("scopes=2/limit=1"),
  )
}
