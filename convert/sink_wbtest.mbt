///|
test "sink output is equivalent to buffered conversion" {
  let source = @input.input_from_text("# Sink\n\nbody")
  let options = default_convert_options()
  let buffered = match convert_input(source, options) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  let chunks : Array[String] = []
  let sink = make_output_sink(
    fn(chunk) {
      chunks.push(chunk)
      Ok(())
    },
    fn() { Ok(()) },
  )
  let streamed = match convert_input_to_sink(source, options, sink) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(chunks.join(""), buffered.content)
  assert_eq(streamed.content, buffered.content)
  assert_eq(
    streamed.diagnostics.metrics.get("sink_mode"),
    Some("parser_to_renderer_event_stream"),
  )
  assert_eq(streamed.assets.length(), buffered.assets.length())
  assert_eq(
    streamed.diagnostics.warnings.length(),
    buffered.diagnostics.warnings.length(),
  )
}

///|
test "sink pull stream matches buffered TXT across CRLF emoji and truncation" {
  let source = @input.input_from_text_with_format(
    "alpha\r\nemoji 😀\r\n\r\n1234567890",
    "stream.txt",
    Some(Txt),
  )
  let limits = @product.make_resource_limits(2000, 50, 100000, max_line_chars=5)
  let options = { ..default_convert_options(), limits, }
  let buffered = convert_input(source, options).unwrap()
  let chunks : Array[String] = []
  let streamed = convert_input_to_sink(
    source,
    options,
    make_output_sink(
      fn(chunk) {
        chunks.push(chunk)
        Ok(())
      },
      fn() { Ok(()) },
    ),
  ).unwrap()
  assert_eq(chunks.join(""), buffered.content)
  assert_eq(streamed.content, buffered.content)
  assert_eq(
    streamed.diagnostics.metrics.get("long_line_count"),
    buffered.diagnostics.metrics.get("long_line_count"),
  )
  assert_eq(
    streamed.diagnostics.warnings.length(),
    buffered.diagnostics.warnings.length(),
  )
}

///|
test "sink pull stream matches buffered SRT and VTT records" {
  let cases : Array[(@input.InputSource, @input.DetectedFormat)] = [
    (
      @input.input_from_text_with_format(
        "cue-a\r\n00:00:00,000 --> 00:00:02,000 align:start\r\n<b>Hello</b>\r\nSecond\r\n",
        "stream.srt",
        Some(Srt),
      ),
      Srt,
    ),
    (
      @input.input_from_text_with_format(
        "WEBVTT\r\n\r\ncue-a\r\n00:00:01.000 --> 00:00:03.500 align:start\r\n<v Ada><b>Hello</b></v>\r\n",
        "stream.vtt",
        Some(Vtt),
      ),
      Vtt,
    ),
  ]
  for item in cases {
    let source = item.0
    let buffered = convert_input(source, default_convert_options()).unwrap()
    let chunks : Array[String] = []
    let streamed = convert_input_to_sink(
      source,
      default_convert_options(),
      make_output_sink(
        fn(chunk) {
          chunks.push(chunk)
          Ok(())
        },
        fn() { Ok(()) },
      ),
    ).unwrap()
    assert_eq(chunks.join(""), buffered.content)
    assert_eq(streamed.content, buffered.content)
    assert_eq(
      streamed.diagnostics.metrics.get("sink_buffered_fallback"),
      Some("false"),
    )
    assert_true(streamed.detected_format == item.1)
  }
}

///|
test "sink pull stream matches buffered JSONL and NDJSON tables and tails" {
  let cases : Array[(@input.InputSource, @input.DetectedFormat)] = [
    (
      @input.input_from_text_with_format(
        "{\"name\":\"Alice\",\"score\":7}\n\n{\"name\":\"Bob\",\"score\":9}\n[1,2]",
        "records.jsonl",
        Some(Jsonl),
      ),
      Jsonl,
    ),
    (
      @input.input_from_text_with_format(
        "{\"name\":\"Carol\",\"score\":5}\n{\"name\":\"Dave\",\"score\":8}",
        "records.ndjson",
        Some(Ndjson),
      ),
      Ndjson,
    ),
  ]
  for item in cases {
    let buffered = convert_input(item.0, default_convert_options()).unwrap()
    let chunks : Array[String] = []
    let streamed = convert_input_to_sink(
      item.0,
      default_convert_options(),
      make_output_sink(
        fn(chunk) {
          chunks.push(chunk)
          Ok(())
        },
        fn() { Ok(()) },
      ),
    ).unwrap()
    assert_eq(chunks.join(""), buffered.content)
    assert_eq(streamed.content, buffered.content)
    assert_true(streamed.detected_format == item.1)
    assert_eq(
      streamed.diagnostics.metrics.get("sink_buffered_fallback"),
      Some("false"),
    )
  }
}

///|
test "sink pull stream matches buffered CSV and TSV quoted records" {
  let cases : Array[(@input.InputSource, @input.DetectedFormat)] = [
    (
      @input.input_from_text_with_format(
        "Name,Note,Value\r\nAlice,\"line one\r\nline two\",7\r\nBob,\"quote \"\"inside\"\"\",9",
        "records.csv",
        Some(Csv),
      ),
      Csv,
    ),
    (
      @input.input_from_text_with_format(
        "Name\tRole\tNote\nAlice\tEngineer\t\"hello\tworld\"\nBob\tDesigner",
        "records.tsv",
        Some(Tsv),
      ),
      Tsv,
    ),
  ]
  for item in cases {
    let buffered = convert_input(item.0, default_convert_options()).unwrap()
    let chunks : Array[String] = []
    let streamed = convert_input_to_sink(
      item.0,
      default_convert_options(),
      make_output_sink(
        fn(chunk) {
          chunks.push(chunk)
          Ok(())
        },
        fn() { Ok(()) },
      ),
    ).unwrap()
    assert_eq(chunks.join(""), buffered.content)
    assert_eq(streamed.content, buffered.content)
    assert_true(streamed.detected_format == item.1)
  }
}

///|
test "sink uses bounded chunks for large output" {
  let source = @input.input_from_text("line\n\n".repeat(40_000))
  let chunks : Array[String] = []
  let sink = make_output_sink(
    fn(chunk) {
      chunks.push(chunk)
      Ok(())
    },
    fn() { Ok(()) },
  )
  let result = match
    convert_input_to_sink(source, default_convert_options(), sink) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_true(chunks.length() > 1)
  for chunk in chunks {
    assert_true(chunk.length() <= 64 * 1024)
  }
  assert_eq(chunks.join(""), result.content)
}

///|
test "sink write failure stops before finish" {
  let finished = Ref(false)
  let sink = make_output_sink(fn(_chunk) { Err("cancelled") }, fn() {
    finished.val = true
    Ok(())
  })
  let result = convert_input_to_sink(
    @input.input_from_text("body"),
    default_convert_options(),
    sink,
  )
  match result {
    Err(RenderFailed(message)) =>
      assert_true(message.contains("sink write failed"))
    Err(other) => fail(other.to_string())
    Ok(_) => fail("write failure should fail conversion")
  }
  assert_false(finished.val)
}

///|
test "unbuffered sink returns side channels without retaining content" {
  let chunks : Array[String] = []
  let result = convert_input_to_sink_unbuffered(
    @input.input_from_text_with_format("alpha\n\nbeta", "plain.txt", Some(Txt)),
    default_convert_options(),
    make_output_sink(
      fn(chunk) {
        chunks.push(chunk)
        Ok(())
      },
      fn() { Ok(()) },
    ),
  ).unwrap()
  assert_eq(chunks.join(""), "alpha\n\nbeta")
  assert_eq(result.content, "")
  assert_eq(result.assets.length(), 0)
  assert_eq(
    result.diagnostics.metrics.get("sink_buffered_fallback"),
    Some("false"),
  )
}

///|
test "incremental renderer sink matches buffered output across format families" {
  let paths = [
    "samples/fixtures/contracts/html/html_simple.html", "samples/fixtures/contracts/markdown/markdown_basic_heading_paragraph.md",
    "samples/fixtures/contracts/json/json_object_basic.json", "samples/fixtures/contracts/xml/xml_basic.xml",
    "samples/fixtures/contracts/yaml/yaml_mapping_basic.yaml", "samples/fixtures/contracts/toml/toml_object_basic.toml",
    "samples/fixtures/contracts/ipynb/ipynb_markdown_basic.ipynb", "samples/fixtures/contracts/asciidoc/asciidoc_basic.adoc",
    "samples/fixtures/contracts/rst/rst_basic.rst", "samples/fixtures/contracts/tex/tex_basic.tex",
    "samples/fixtures/contracts/docx/golden.docx", "samples/fixtures/contracts/xlsx/sheet_simple.xlsx",
    "samples/fixtures/contracts/pptx/pptx_simple.pptx", "samples/fixtures/contracts/odt/odt_basic_sample.odt",
    "samples/fixtures/contracts/epub/epub_basic_package.epub", "samples/fixtures/contracts/zip/zip_basic_structured.zip",
    "samples/fixtures/contracts/pdf/text_simple.pdf",
  ]
  for path in paths {
    let source = @input.input_from_path(path)
    let options = default_convert_options()
    let buffered = convert_input(source, options).unwrap()
    let chunks : Array[String] = []
    let streamed = convert_input_to_sink(
      source,
      options,
      make_output_sink(
        fn(chunk) {
          chunks.push(chunk)
          Ok(())
        },
        fn() { Ok(()) },
      ),
    ).unwrap()
    assert_eq(chunks.join(""), buffered.content)
    assert_eq(streamed.content, buffered.content)
    assert_eq(streamed.assets.length(), buffered.assets.length())
    assert_eq(
      streamed.diagnostics.warnings.length(),
      buffered.diagnostics.warnings.length(),
    )
    assert_eq(streamed.source_map is Some(_), buffered.source_map is Some(_))
    assert_eq(
      streamed.diagnostics.metrics.get("sink_buffered_fallback"),
      Some("false"),
    )
  }
}
