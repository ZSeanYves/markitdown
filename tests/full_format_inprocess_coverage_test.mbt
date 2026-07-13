///|
fn inprocess_convert_fixture(
  path : String,
  format : @input.DetectedFormat,
  mode : @convert.ConvertMode,
) -> @convert.ConvertResult {
  let options = @convert.make_convert_options(
    mode,
    @convert.OutputFormat::Markdown,
    Some(format),
    @parser.default_ocr_options(),
    @convert.default_resource_limits(),
    stream_requested=mode == @convert.ConvertMode::Stream,
  )
  match
    @convert.convert_input(
      @input.input_from_path_with_format(path, Some(format)),
      options,
    ) {
    Ok(result) => result
    Err(err) =>
      abort("fixture conversion failed for " + path + ": " + err.to_string())
  }
}

///|
fn convert_binary_source_for_equivalence(
  source : @input.InputSource,
  format : @input.DetectedFormat,
) -> @convert.ConvertResult {
  let options = @convert.make_convert_options(
    @convert.ConvertMode::Balanced,
    @convert.OutputFormat::Markdown,
    Some(format),
    @parser.default_ocr_options(),
    @convert.default_resource_limits(),
  )
  match @convert.convert_input(source, options) {
    Ok(result) => result
    Err(err) => abort("binary source conversion failed: " + err.to_string())
  }
}

///|
fn assert_binary_results_equivalent(
  expected : @convert.ConvertResult,
  actual : @convert.ConvertResult,
) -> Unit raise {
  assert_eq(actual.content, expected.content)
  assert_true(actual.detected_format == expected.detected_format)
  assert_true(actual.parser_mode == expected.parser_mode)
  assert_true(actual.convert_mode == expected.convert_mode)
  assert_eq(actual.assets.length(), expected.assets.length())
  for index in 0..<expected.assets.length() {
    let left = expected.assets[index]
    let right = actual.assets[index]
    assert_true(right.asset_kind == left.asset_kind)
    assert_eq(right.asset_id, left.asset_id)
    assert_true(right.path == left.path)
    assert_true(right.mime_type == left.mime_type)
    assert_true(right.payload == left.payload)
  }
  assert_true(
    actual.diagnostics.parser_name == expected.diagnostics.parser_name,
  )
  assert_true(
    actual.diagnostics.parser_mode == expected.diagnostics.parser_mode,
  )
  assert_true(actual.diagnostics.warnings == expected.diagnostics.warnings)
  assert_true(
    actual.diagnostics.degraded_features ==
    expected.diagnostics.degraded_features,
  )
  assert_true(actual.diagnostics.pass_trace == expected.diagnostics.pass_trace)
  for
    key in [
      "detected_format", "effective_mode", "resource_limit_hit", "asset_count",
    ] {
    assert_true(
      actual.diagnostics.metrics.get(key) ==
      expected.diagnostics.metrics.get(key),
    )
  }
}

///|
test "seekable package formats preserve Path Bytes and short Reader results" {
  let fixtures : Array[(String, @input.DetectedFormat)] = [
    ("samples/fixtures/contracts/docx/golden.docx", @input.DetectedFormat::Docx),
    (
      "samples/fixtures/contracts/pptx/pptx_simple.pptx",
      @input.DetectedFormat::Pptx,
    ),
    (
      "samples/fixtures/contracts/xlsx/sheet_simple.xlsx",
      @input.DetectedFormat::Xlsx,
    ),
    (
      "samples/fixtures/contracts/epub/epub_basic_package.epub",
      @input.DetectedFormat::Epub,
    ),
    (
      "samples/fixtures/contracts/odt/odt_basic_sample.odt",
      @input.DetectedFormat::Odt,
    ),
    (
      "samples/fixtures/contracts/ods/ods_basic_sample.ods",
      @input.DetectedFormat::Ods,
    ),
    (
      "samples/fixtures/contracts/odp/odp_basic_sample.odp",
      @input.DetectedFormat::Odp,
    ),
    (
      "samples/fixtures/contracts/zip/zip_basic_structured.zip",
      @input.DetectedFormat::Zip,
    ),
  ]
  for fixture in fixtures {
    let (path, format) = fixture
    let bytes = @fs.read_file_to_bytes(path) catch {
      err => fail("read equivalence fixture failed: " + err.to_string())
    }
    let source_name = path.split("/").last().unwrap_or(path).to_owned()
    let path_result = convert_binary_source_for_equivalence(
      @input.input_from_path_with_format(path, Some(format)),
      format,
    )
    let bytes_result = convert_binary_source_for_equivalence(
      @input.input_from_bytes_with_format(bytes, source_name, Some(format)),
      format,
    )
    let read_count = Ref(0)
    let reader = @input.make_input_reader(
      fn(offset, length) {
        read_count.val += 1
        let start = offset.to_int()
        let end_ = (start + length.min(4096)).min(bytes.length())
        Ok(bytes.view(start~, end=end_).to_owned())
      },
      size=bytes.length().to_int64(),
    )
    let reader_result = convert_binary_source_for_equivalence(
      @input.input_from_reader_with_format(reader, source_name, Some(format)),
      format,
    )
    assert_binary_results_equivalent(path_result, bytes_result)
    assert_binary_results_equivalent(path_result, reader_result)
    assert_true(read_count.val > 1)
  }
}

///|
test "in-process complex document matrix exercises balanced product routes" {
  let fixtures : Array[(String, @input.DetectedFormat)] = [
    (
      "samples/fixtures/contracts/docx/docx_textbox_basic.docx",
      @input.DetectedFormat::Docx,
    ),
    (
      "samples/fixtures/contracts/docx/docx_note_comment_rich_content_boundary.docx",
      @input.DetectedFormat::Docx,
    ),
    (
      "samples/fixtures/contracts/xlsx/xlsx_multi_sheet_mixed.xlsx",
      @input.DetectedFormat::Xlsx,
    ),
    (
      "samples/fixtures/contracts/xlsx/sheet_simple.xlsx",
      @input.DetectedFormat::Xlsx,
    ),
    (
      "samples/fixtures/contracts/pptx/pptx_reading_order_geometry.pptx",
      @input.DetectedFormat::Pptx,
    ),
    (
      "samples/fixtures/contracts/pptx/pptx_speaker_notes_basic.pptx",
      @input.DetectedFormat::Pptx,
    ),
    (
      "samples/fixtures/contracts/odt/odt_basic_assets.odt",
      @input.DetectedFormat::Odt,
    ),
    (
      "samples/fixtures/contracts/odt/odt_basic_sample.odt",
      @input.DetectedFormat::Odt,
    ),
    (
      "samples/fixtures/contracts/ods/ods_basic_sample.ods",
      @input.DetectedFormat::Ods,
    ),
    (
      "samples/fixtures/contracts/odp/odp_basic_assets.odp",
      @input.DetectedFormat::Odp,
    ),
    (
      "samples/fixtures/contracts/epub/epub_ncx_nested.epub",
      @input.DetectedFormat::Epub,
    ),
    (
      "samples/fixtures/contracts/zip/zip_mixed_supported_entries.zip",
      @input.DetectedFormat::Zip,
    ),
    (
      "samples/fixtures/contracts/pdf/text_simple.pdf",
      @input.DetectedFormat::Pdf,
    ),
  ]
  for fixture in fixtures {
    let result = inprocess_convert_fixture(
      fixture.0,
      fixture.1,
      @convert.ConvertMode::Balanced,
    )
    assert_true(result.content.length() > 0)
    assert_true(result.diagnostics.detected_format is Some(_))
  }
}

///|
test "in-process accurate matrix exercises semantic feature routes" {
  let fixtures : Array[(String, @input.DetectedFormat)] = [
    (
      "samples/fixtures/contracts/docx/docx_multiple_notes_order.docx",
      @input.DetectedFormat::Docx,
    ),
    (
      "samples/fixtures/contracts/xlsx/xlsx_hidden_sheets_policy.xlsx",
      @input.DetectedFormat::Xlsx,
    ),
    (
      "samples/fixtures/contracts/pptx/pptx_hidden_slide_basic.pptx",
      @input.DetectedFormat::Pptx,
    ),
    (
      "samples/fixtures/contracts/odt/odt_basic_sample.odt",
      @input.DetectedFormat::Odt,
    ),
    (
      "samples/fixtures/contracts/ods/ods_basic_sample.ods",
      @input.DetectedFormat::Ods,
    ),
    (
      "samples/fixtures/contracts/odp/odp_basic_sample.odp",
      @input.DetectedFormat::Odp,
    ),
  ]
  for fixture in fixtures {
    let result = inprocess_convert_fixture(
      fixture.0,
      fixture.1,
      @convert.ConvertMode::Accurate,
    )
    assert_true(result.content.length() > 0)
    assert_true(result.diagnostics.fidelity_mode == Some("accurate"))
  }
}

///|
test "in-process stream matrix exercises structured and container routes" {
  let fixtures : Array[(String, @input.DetectedFormat)] = [
    (
      "samples/fixtures/contracts/json/large_array_streaming.json",
      @input.DetectedFormat::Json,
    ),
    (
      "samples/fixtures/contracts/xml/xml_nested.xml",
      @input.DetectedFormat::Xml,
    ),
    (
      "samples/fixtures/contracts/yaml/yaml_mapping_basic.yaml",
      @input.DetectedFormat::Yaml,
    ),
    (
      "samples/fixtures/contracts/html/html_nested_lists_deep.html",
      @input.DetectedFormat::Html,
    ),
    (
      "samples/fixtures/contracts/markdown/markdown_frontmatter_passthrough.markdown",
      @input.DetectedFormat::Markdown,
    ),
    (
      "samples/fixtures/contracts/epub/epub_spine_order.epub",
      @input.DetectedFormat::Epub,
    ),
  ]
  for fixture in fixtures {
    let result = inprocess_convert_fixture(
      fixture.0,
      fixture.1,
      @convert.ConvertMode::Stream,
    )
    assert_true(result.content.length() > 0)
    assert_true(result.diagnostics.convert_mode == Some("stream"))
  }
}

///|
test "in-process ZIP rejects non-balance modes" {
  let source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/zip/zip_basic_structured.zip",
    Some(@input.DetectedFormat::Zip),
  )
  for mode in [@convert.ConvertMode::Accurate, @convert.ConvertMode::Stream] {
    let options = @convert.make_convert_options(
      mode,
      @convert.OutputFormat::Markdown,
      Some(@input.DetectedFormat::Zip),
      @parser.default_ocr_options(),
      @convert.default_resource_limits(),
    )
    match @convert.convert_input(source, options) {
      Err(err) =>
        assert_true(err.to_string().contains("mode is unsupported for `zip`"))
      Ok(_) => fail("ZIP non-balance mode must fail closed")
    }
  }
}

///|
fn inprocess_contract_files(
  directory : String,
  suffix : String,
) -> Array[String] raise {
  let paths : Array[String] = []
  for name in @fs.read_dir(directory) {
    if name.to_lower().has_suffix(suffix) {
      paths.push(directory + "/" + name)
    }
  }
  paths.sort()
  paths
}

///|
fn inprocess_smoke_directory(
  directory : String,
  suffix : String,
  format : @input.DetectedFormat,
) -> (Int, Int) raise {
  let mut succeeded = 0
  let mut failed = 0
  for path in inprocess_contract_files(directory, suffix) {
    let options = @convert.make_convert_options(
      @convert.ConvertMode::Balanced,
      @convert.OutputFormat::Markdown,
      Some(format),
      @parser.default_ocr_options(),
      @convert.default_resource_limits(),
    )
    match
      @convert.convert_input(
        @input.input_from_path_with_format(path, Some(format)),
        options,
      ) {
      Ok(result) => {
        assert_true(result.content.length() > 0)
        succeeded += 1
      }
      Err(_) => failed += 1
    }
  }
  (succeeded, failed)
}

///|
test "in-process contract directories exercise broad real and malformed corpus" {
  let directories : Array[(String, String, @input.DetectedFormat)] = [
    ("samples/fixtures/contracts/docx", ".docx", @input.DetectedFormat::Docx),
    ("samples/fixtures/contracts/xlsx", ".xlsx", @input.DetectedFormat::Xlsx),
    ("samples/fixtures/contracts/pptx", ".pptx", @input.DetectedFormat::Pptx),
    ("samples/fixtures/contracts/odt", ".odt", @input.DetectedFormat::Odt),
    ("samples/fixtures/contracts/ods", ".ods", @input.DetectedFormat::Ods),
    ("samples/fixtures/contracts/odp", ".odp", @input.DetectedFormat::Odp),
    ("samples/fixtures/contracts/epub", ".epub", @input.DetectedFormat::Epub),
    ("samples/fixtures/contracts/zip", ".zip", @input.DetectedFormat::Zip),
    ("samples/fixtures/contracts/html", ".html", @input.DetectedFormat::Html),
    ("samples/fixtures/contracts/pdf", ".pdf", @input.DetectedFormat::Pdf),
    ("samples/fixtures/contracts/json", ".json", @input.DetectedFormat::Json),
    ("samples/fixtures/contracts/jsonl", ".jsonl", @input.DetectedFormat::Jsonl),
    (
      "samples/fixtures/contracts/ndjson",
      ".ndjson",
      @input.DetectedFormat::Ndjson,
    ),
    ("samples/fixtures/contracts/yaml", ".yaml", @input.DetectedFormat::Yaml),
    ("samples/fixtures/contracts/xml", ".xml", @input.DetectedFormat::Xml),
    ("samples/fixtures/contracts/toml", ".toml", @input.DetectedFormat::Toml),
    (
      "samples/fixtures/contracts/markdown",
      ".md",
      @input.DetectedFormat::Markdown,
    ),
    ("samples/fixtures/contracts/tex", ".tex", @input.DetectedFormat::Tex),
    ("samples/fixtures/contracts/rst", ".rst", @input.DetectedFormat::Rst),
    (
      "samples/fixtures/contracts/asciidoc",
      ".adoc",
      @input.DetectedFormat::Asciidoc,
    ),
  ]
  for directory in directories {
    let result = inprocess_smoke_directory(
      directory.0,
      directory.1,
      directory.2,
    )
    assert_true(
      result.0 > 0,
      msg="expected at least one successful fixture in " + directory.0,
    )
  }
}

///|
fn inprocess_convert_text(
  text : String,
  name : String,
  format : @input.DetectedFormat,
  mode : @convert.ConvertMode,
) -> Result[@convert.ConvertResult, @convert.ConvertError] {
  @convert.convert_input(
    @input.input_from_text_with_format(text, name, Some(format)),
    @convert.make_convert_options(
      mode,
      @convert.OutputFormat::Markdown,
      Some(format),
      @parser.default_ocr_options(),
      @convert.default_resource_limits(),
      stream_requested=mode == @convert.ConvertMode::Stream,
    ),
  )
}

///|
test "in-process mail subtitle and structured memory corpus exercises parsers" {
  let eml = [
    "From: alice@example.test", "To: bob@example.test", "Subject: Fixture", "MIME-Version: 1.0",
    "Content-Type: multipart/alternative; boundary=alt", "", "--alt", "Content-Type: text/plain; charset=utf-8",
    "", "Plain body", "--alt", "Content-Type: text/html; charset=utf-8", "", "<html><body><h1>HTML body</h1><p>text</p></body></html>",
    "--alt--",
  ].join("\r\n")
  let srt = [
    "1", "00:00:01,000 --> 00:00:02,500", "First line", "", "2", "00:00:03,000 --> 00:00:04,000",
    "Second line", "",
  ].join("\n")
  let vtt = [
    "WEBVTT", "", "STYLE", "::cue { color: lime; }", "", "cue-1", "00:00:01.000 --> 00:00:02.000 align:start",
    "Hello VTT", "",
  ].join("\n")
  let sources : Array[(String, String, @input.DetectedFormat)] = [
    (eml, "fixture.eml", @input.DetectedFormat::Eml),
    (srt, "fixture.srt", @input.DetectedFormat::Srt),
    (vtt, "fixture.vtt", @input.DetectedFormat::Vtt),
    (
      "{\"root\":{\"items\":[{\"name\":\"one\",\"tags\":[true,null,3]}]}}",
      "fixture.json",
      @input.DetectedFormat::Json,
    ),
    (
      "root:\n  items:\n    - name: one\n      tags: [a, b]\n    - name: two\n",
      "fixture.yaml",
      @input.DetectedFormat::Yaml,
    ),
    (
      "<?xml version=\"1.0\"?><root xmlns:x=\"urn:x\"><x:item id=\"1\"><![CDATA[value]]></x:item><!-- note --></root>",
      "fixture.xml",
      @input.DetectedFormat::Xml,
    ),
    (
      "title = \"Fixture\"\nvalues = [1, 2, 3]\n[[items]]\nname = \"one\"\n[items.meta]\nenabled = true\n",
      "fixture.toml",
      @input.DetectedFormat::Toml,
    ),
  ]
  for source in sources {
    for mode in [@convert.ConvertMode::Balanced, @convert.ConvertMode::Stream] {
      match inprocess_convert_text(source.0, source.1, source.2, mode) {
        Ok(result) => assert_true(result.content.length() > 0)
        Err(err) if source.2 == @input.DetectedFormat::Toml &&
          mode == @convert.ConvertMode::Stream =>
          assert_true(
            err.to_string().contains("stream mode is unsupported for `toml`"),
          )
        Err(err) => fail("memory conversion failed: " + err.to_string())
      }
    }
  }
}

///|
test "in-process malformed memory corpus fails or degrades under control" {
  let malformed : Array[(String, String, @input.DetectedFormat)] = [
    (
      "Content-Type: multipart/mixed\r\n\r\nmissing boundary",
      "bad.eml",
      @input.DetectedFormat::Eml,
    ),
    ("1\nnot a timestamp\ntext", "bad.srt", @input.DetectedFormat::Srt),
    ("WEBVTT\n\ninvalid cue", "bad.vtt", @input.DetectedFormat::Vtt),
    ("{\"root\":[1,", "bad.json", @input.DetectedFormat::Json),
    ("root: [unterminated", "bad.yaml", @input.DetectedFormat::Yaml),
    ("<root><item></root>", "bad.xml", @input.DetectedFormat::Xml),
    ("[section\nvalue =", "bad.toml", @input.DetectedFormat::Toml),
  ]
  for source in malformed {
    match
      inprocess_convert_text(
        source.0,
        source.1,
        source.2,
        @convert.ConvertMode::Balanced,
      ) {
      Ok(result) =>
        assert_true(
          result.content.length() > 0 ||
          result.diagnostics.errors.length() > 0 ||
          result.diagnostics.warnings.length() > 0,
        )
      Err(_) => ()
    }
  }
}

///|
test "in-process complex EML corpus exercises related attachments and nesting" {
  let related = [
    "From: a@example.test", "Subject: Related", "MIME-Version: 1.0", "Content-Type: multipart/related; boundary=rel",
    "", "--rel", "Content-Type: text/html; charset=utf-8", "", "<html><body><img src=\"cid:hero\"><p>Body</p></body></html>",
    "--rel", "Content-Type: image/png; name=hero.png", "Content-Disposition: inline; filename=hero.png",
    "Content-ID: <hero>", "Content-Transfer-Encoding: base64", "", "iVBORw0KGgo=",
    "--rel--",
  ].join("\r\n")
  let typed = [
    "From: a@example.test", "Subject: Typed", "MIME-Version: 1.0", "Content-Type: multipart/mixed; boundary=mix",
    "", "--mix", "Content-Type: text/plain", "", "Body", "--mix", "Content-Type: application/json; name=data.json",
    "Content-Disposition: attachment; filename=data.json", "Content-Transfer-Encoding: base64",
    "", "eyJpdGVtcyI6WzEsMl19", "--mix", "Content-Type: application/xml; name=data.xml",
    "Content-Disposition: attachment; filename=data.xml", "", "<root><item>one</item></root>",
    "--mix--",
  ].join("\r\n")
  let nested = [
    "From: a@example.test", "Subject: Nested", "MIME-Version: 1.0", "Content-Type: multipart/mixed; boundary=outer",
    "", "--outer", "Content-Type: message/rfc822", "", "From: child@example.test",
    "Subject: Child", "Content-Type: text/plain", "", "Nested body", "--outer--",
  ].join("\r\n")
  let binary = [
    "From: a@example.test", "Subject: Binary", "MIME-Version: 1.0", "Content-Type: multipart/mixed; boundary=mix",
    "", "--mix", "Content-Type: text/plain", "", "Body", "--mix", "Content-Type: application/octet-stream; name=file.bin",
    "Content-Disposition: attachment; filename=file.bin", "Content-Transfer-Encoding: base64",
    "", "AAECAwQF", "--mix--",
  ].join("\r\n")
  for source in [related, typed, nested, binary] {
    match
      inprocess_convert_text(
        source,
        "complex.eml",
        @input.DetectedFormat::Eml,
        @convert.ConvertMode::Balanced,
      ) {
      Ok(result) => {
        assert_true(result.content.length() > 0)
        assert_true(result.diagnostics.metrics.get("part_count") is Some(_))
      }
      Err(err) => fail("complex EML failed: " + err.to_string())
    }
  }
}

///|
test "in-process core text matrix handles strict resource limits under control" {
  let long = "x".repeat(4096)
  let sources : Array[(String, String, @input.DetectedFormat)] = [
    (long + "\n" + long, "limit.txt", @input.DetectedFormat::Txt),
    (
      "a,b\n" + ("1," + long + "\n").repeat(8),
      "limit.csv",
      @input.DetectedFormat::Csv,
    ),
    (
      "a\tb\n" + ("1\t" + long + "\n").repeat(8),
      "limit.tsv",
      @input.DetectedFormat::Tsv,
    ),
    (
      ("1\n00:00:01,000 --> 00:00:02,000\n" + long + "\n\n").repeat(8),
      "limit.srt",
      @input.DetectedFormat::Srt,
    ),
    (
      "WEBVTT\n\n" +
      ("00:00:01.000 --> 00:00:02.000\n" + long + "\n\n").repeat(8),
      "limit.vtt",
      @input.DetectedFormat::Vtt,
    ),
    (
      "[" +
      [long, long, long, long].map(value => "\"" + value + "\"").join(",") +
      "]",
      "limit.json",
      @input.DetectedFormat::Json,
    ),
    (
      ("{\"value\":\"" + long + "\"}\n").repeat(8),
      "limit.jsonl",
      @input.DetectedFormat::Jsonl,
    ),
    (
      ("{\"value\":\"" + long + "\"}\n").repeat(8),
      "limit.ndjson",
      @input.DetectedFormat::Ndjson,
    ),
    (
      "root:\n" + ("  - " + long + "\n").repeat(8),
      "limit.yaml",
      @input.DetectedFormat::Yaml,
    ),
    (
      "<root>" + ("<item>" + long + "</item>").repeat(8) + "</root>",
      "limit.xml",
      @input.DetectedFormat::Xml,
    ),
    (
      "values = [" +
      [long, long, long].map(value => "\"" + value + "\"").join(",") +
      "]",
      "limit.toml",
      @input.DetectedFormat::Toml,
    ),
    (
      "<html><body>" + ("<p>" + long + "</p>").repeat(8) + "</body></html>",
      "limit.html",
      @input.DetectedFormat::Html,
    ),
    (
      ("# Heading\n\n" + long + "\n\n").repeat(8),
      "limit.md",
      @input.DetectedFormat::Markdown,
    ),
    (
      ("Section\n=======\n\n" + long + "\n\n").repeat(8),
      "limit.rst",
      @input.DetectedFormat::Rst,
    ),
    (
      ("= Section\n\n" + long + "\n\n").repeat(8),
      "limit.adoc",
      @input.DetectedFormat::Asciidoc,
    ),
    (
      ("\\section{Title}\n" + long + "\n").repeat(8),
      "limit.tex",
      @input.DetectedFormat::Tex,
    ),
  ]
  let limits = @convert.make_resource_limits(3, 3, 9, max_line_chars=64)
  for source in sources {
    let outcome = @convert.convert_input(
      @input.input_from_text_with_format(source.0, source.1, Some(source.2)),
      @convert.make_convert_options(
        @convert.ConvertMode::Balanced,
        @convert.OutputFormat::Markdown,
        Some(source.2),
        @parser.default_ocr_options(),
        limits,
      ),
    )
    match outcome {
      Ok(result) =>
        assert_true(
          result.content.length() > 0 ||
          result.diagnostics.warnings.length() > 0 ||
          result.diagnostics.degraded_features.length() > 0,
        )
      Err(error) => assert_true(error.to_string() != "")
    }
  }
}
