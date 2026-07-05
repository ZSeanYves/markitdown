///|
struct ContractMatrixCase {
  format : @input.DetectedFormat
  spec : @formats_root.ParserContractSpec
}

///|
fn contract_matrix_cases() -> Array[ContractMatrixCase] {
  let formats = [
    @input.DetectedFormat::Txt,
    @input.DetectedFormat::Csv,
    @input.DetectedFormat::Tsv,
    @input.DetectedFormat::Json,
    @input.DetectedFormat::Jsonl,
    @input.DetectedFormat::Ndjson,
    @input.DetectedFormat::Xml,
    @input.DetectedFormat::Yaml,
    @input.DetectedFormat::Toml,
    @input.DetectedFormat::Markdown,
    @input.DetectedFormat::Html,
    @input.DetectedFormat::Ipynb,
    @input.DetectedFormat::Srt,
    @input.DetectedFormat::Vtt,
    @input.DetectedFormat::Tex,
    @input.DetectedFormat::Rst,
    @input.DetectedFormat::Asciidoc,
    @input.DetectedFormat::Eml,
    @input.DetectedFormat::Zip,
    @input.DetectedFormat::Epub,
    @input.DetectedFormat::Odt,
    @input.DetectedFormat::Ods,
    @input.DetectedFormat::Odp,
    @input.DetectedFormat::Docx,
    @input.DetectedFormat::Pptx,
    @input.DetectedFormat::Xlsx,
    @input.DetectedFormat::Pdf,
    @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
    @input.DetectedFormat::Audio(@input.AudioFormat::Mp3),
    @input.DetectedFormat::Audio(@input.AudioFormat::M4a),
  ]
  formats.map(fn(format) {
    let spec = @formats_root.product_parser_contract_spec_by_format(format).unwrap_or_else(fn() {
        abort(
          "missing contract spec for " + @input.detected_format_name(format),
        )
      },
    )
    { format, spec }
  })
}

///|
fn contract_matrix_relax_extra_keys(
  spec : @formats_root.ParserContractSpec,
) -> Bool {
  match spec.parser_name {
    "docx_parser" | "pptx_parser" | "xlsx_parser" => true
    _ => false
  }
}

///|
fn contract_matrix_relax_fields(
  spec : @formats_root.ParserContractSpec,
) -> Bool {
  match spec.parser_name {
    "docx_parser" | "pptx_parser" | "xlsx_parser" => true
    _ => false
  }
}

///|
fn contract_matrix_source(format : @input.DetectedFormat) -> @input.InputSource {
  match format {
    @input.DetectedFormat::Txt =>
      @input.input_from_text_with_format(
        "Alpha\n\nBeta\n",
        "contract.txt",
        Some(format),
      )
    @input.DetectedFormat::Csv =>
      @input.input_from_text_with_format(
        "name,score\nAlice,7\nBob,9\n",
        "contract.csv",
        Some(format),
      )
    @input.DetectedFormat::Tsv =>
      @input.input_from_text_with_format(
        "name\tscore\nAlice\t7\nBob\t9\n",
        "contract.tsv",
        Some(format),
      )
    @input.DetectedFormat::Json =>
      @input.input_from_text_with_format(
        "{\"team\":\"MoonBit\",\"members\":[\"A\",\"B\"]}\n",
        "contract.json",
        Some(format),
      )
    @input.DetectedFormat::Jsonl =>
      @input.input_from_text_with_format(
        "{\"name\":\"Alice\"}\n{\"name\":\"Bob\"}\n",
        "contract.jsonl",
        Some(format),
      )
    @input.DetectedFormat::Ndjson =>
      @input.input_from_text_with_format(
        "{\"name\":\"Carol\"}\n{\"name\":\"Dave\"}\n",
        "contract.ndjson",
        Some(format),
      )
    @input.DetectedFormat::Xml =>
      @input.input_from_text_with_format(
        "<root><item>Hello</item><item>World</item></root>\n",
        "contract.xml",
        Some(format),
      )
    @input.DetectedFormat::Yaml =>
      @input.input_from_text_with_format(
        "name: Alice\nrole: Engineer\n",
        "contract.yaml",
        Some(format),
      )
    @input.DetectedFormat::Toml =>
      @input.input_from_text_with_format(
        "name = \"Alice\"\n[tool.demo]\nrole = \"Engineer\"\n",
        "contract.toml",
        Some(format),
      )
    @input.DetectedFormat::Markdown =>
      @input.input_from_text_with_format(
        "# Title\n\nBody with [link](https://example.com).\n",
        "contract.md",
        Some(format),
      )
    @input.DetectedFormat::Html =>
      @input.input_from_text_with_format(
        "<html><body><main><h1>Title</h1><p>Body</p></main></body></html>\n",
        "contract.html",
        Some(format),
      )
    @input.DetectedFormat::Ipynb =>
      @input.input_from_text_with_format(
        "{\n" +
        "  \"nbformat\": 4,\n" +
        "  \"nbformat_minor\": 5,\n" +
        "  \"metadata\": {\"language_info\": {\"name\": \"python\"}},\n" +
        "  \"cells\": [\n" +
        "    {\"cell_type\": \"markdown\", \"source\": [\"# Title\\n\", \"Body\\n\"]}\n" +
        "  ]\n" +
        "}\n",
        "contract.ipynb",
        Some(format),
      )
    @input.DetectedFormat::Srt =>
      @input.input_from_text_with_format(
        "1\n00:00:00,000 --> 00:00:01,000\nHello\n",
        "contract.srt",
        Some(format),
      )
    @input.DetectedFormat::Vtt =>
      @input.input_from_text_with_format(
        "WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nHello\n",
        "contract.vtt",
        Some(format),
      )
    @input.DetectedFormat::Tex =>
      @input.input_from_text_with_format(
        "\\section{Title}\n\nBody\n",
        "contract.tex",
        Some(format),
      )
    @input.DetectedFormat::Rst =>
      @input.input_from_text_with_format(
        "Title\n=====\n\nBody\n",
        "contract.rst",
        Some(format),
      )
    @input.DetectedFormat::Asciidoc =>
      @input.input_from_text_with_format(
        "= Title\n\nBody\n",
        "contract.adoc",
        Some(format),
      )
    @input.DetectedFormat::Eml =>
      @input.input_from_text_with_format(
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
        Some(format),
      )
    @input.DetectedFormat::Zip =>
      @input.input_from_path_with_format(
        "samples/fixtures/contracts/zip/zip_basic_structured.zip",
        Some(format),
      )
    @input.DetectedFormat::Epub =>
      @input.input_from_path_with_format(
        "samples/fixtures/contracts/epub/epub_basic_package.epub",
        Some(format),
      )
    @input.DetectedFormat::Odt =>
      @input.input_from_path_with_format(
        "samples/fixtures/contracts/odt/odt_basic_sample.odt",
        Some(format),
      )
    @input.DetectedFormat::Ods =>
      @input.input_from_path_with_format(
        "samples/fixtures/contracts/ods/ods_basic_sample.ods",
        Some(format),
      )
    @input.DetectedFormat::Odp =>
      @input.input_from_path_with_format(
        "samples/fixtures/contracts/odp/odp_basic_sample.odp",
        Some(format),
      )
    @input.DetectedFormat::Docx =>
      @input.input_from_path_with_format(
        "samples/fixtures/contracts/docx/docx_paragraph_linebreak.docx",
        Some(format),
      )
    @input.DetectedFormat::Pptx =>
      @input.input_from_path_with_format(
        "samples/fixtures/contracts/pptx/pptx_link_basic.pptx",
        Some(format),
      )
    @input.DetectedFormat::Xlsx =>
      @input.input_from_path_with_format(
        "samples/fixtures/contracts/xlsx/sheet_simple.xlsx",
        Some(format),
      )
    @input.DetectedFormat::Pdf =>
      @input.input_from_path_with_format(
        "samples/fixtures/contracts/pdf/text_simple.pdf",
        Some(format),
      )
    @input.DetectedFormat::Audio(audio_format) =>
      @input.input_from_path_with_format(
        "samples/fixtures/contracts/audio/contract." +
        @input.audio_format_name(audio_format),
        Some(@input.DetectedFormat::Audio(audio_format)),
      )
    @input.DetectedFormat::Image(image_format) =>
      @input.input_from_bytes_with_format(
        Bytes::from_array([137, 80, 78, 71, 13, 10, 26, 10]),
        "contract." +
        @input.detected_format_name(@input.DetectedFormat::Image(image_format)),
        Some(@input.DetectedFormat::Image(image_format)),
      )
    @input.DetectedFormat::Unknown =>
      @input.input_from_text_with_format("", "unknown.bin", Some(format))
  }
}

///|
fn contract_matrix_context(
  format : @input.DetectedFormat,
) -> @parser.ParseContext {
  match format {
    @input.DetectedFormat::Audio(_) =>
      @parser.parse_context_with_audio_options(
        @parser.new_parse_context(format),
        @parser.explicit_audio_options(language=Some("eng")),
      )
    @input.DetectedFormat::Image(image_format) =>
      @parser.parse_context_with_ocr_options(
        @parser.new_parse_context(@input.DetectedFormat::Image(image_format)),
        @parser.explicit_ocr_options(language=Some("eng")),
      )
    _ => @parser.new_parse_context(format)
  }
}

///|
test "product parser contract specs stay registered and capability-honest" {
  let registry = @formats_root.builtin_registry()
  let specs = @formats_root.product_parser_contract_specs()
  assert_true(specs.length() >= 29)
  for item in contract_matrix_cases() {
    let format = item.format
    let spec = item.spec
    let parser = @parser.registry_lookup(registry, format).unwrap_or_else(fn() {
      abort("missing parser for format " + @input.detected_format_name(format))
    })
    if !@formats_root.parser_contract_spec_matches_parser(spec, parser) {
      fail(
        "contract parser mismatch for " + @input.detected_format_name(format),
      )
    }
    if !@formats_root.contract_profile_matches_spec(format, spec) {
      fail(
        "contract profile mismatch for " + @input.detected_format_name(format),
      )
    }
    if parser.capability.parser_mode != parser.mode {
      fail(
        "capability parser_mode mismatch for " +
        @input.detected_format_name(format),
      )
    }
    assert_contract_spec_matches_parser(spec, parser)
    assert_contract_spec_matches_parser_capability(spec, parser) catch {
      _ =>
        fail(
          "capability contract failed for " +
          @input.detected_format_name(format),
        )
    }
    match @formats_root.product_parser_contract_spec_by_format(format) {
      Some(by_format) => assert_true(by_format.parser_name == spec.parser_name)
      None =>
        fail(
          "missing contract spec lookup for " +
          @input.detected_format_name(format),
        )
    }
  }
}

///|
test "product parser contract specs cover canonical parse results and source refs" {
  let registry = @formats_root.builtin_registry()
  with_mock_audio_runtime(fn() raise {
    for item in contract_matrix_cases() {
      let format = item.format
      let spec = item.spec
      let source = contract_matrix_source(format)
      let context = contract_matrix_context(format)
      let parser = @parser.registry_lookup(registry, format).unwrap_or_else(fn() {
        abort(
          "missing parser for format " + @input.detected_format_name(format),
        )
      })
      let result = match (parser.parse)(source, context) {
        Ok(value) => value
        Err(err) =>
          fail(
            "contract parse failed for " +
            @input.detected_format_name(format) +
            ": " +
            err,
          )
      }
      assert_parse_result_matches_contract_spec(result, spec)
      assert_parse_result_source_refs_match_contract_spec(
        result,
        spec,
        allow_relaxed_extra_keys=contract_matrix_relax_extra_keys(spec),
        allow_relaxed_fields=contract_matrix_relax_fields(spec),
      )
    }
  })
}
