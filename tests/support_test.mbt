///|
fn read_utf8_text(path : String) -> String {
  @fs.read_file_to_string(path, encoding="utf8") catch {
    e => abort("read failed: " + e.to_string())
  }
}

///|
fn assert_metric_eq(
  diagnostics : @core.Diagnostics,
  key : String,
  expected : String,
) -> Unit raise {
  assert_true(diagnostics.metrics.get(key) == Some(expected))
}

///|
fn assert_metric_present(
  diagnostics : @core.Diagnostics,
  key : String,
) -> Unit raise {
  match diagnostics.metrics.get(key) {
    Some(_) => ()
    None => fail("missing diagnostics metric: " + key)
  }
}

///|
fn assert_contains_all(text : String, needles : Array[String]) -> Unit raise {
  for needle in needles {
    assert_true(text.contains(needle))
  }
}

///|
fn assert_contains_none(text : String, needles : Array[String]) -> Unit raise {
  for needle in needles {
    assert_true(!text.contains(needle))
  }
}

///|
fn convert_memory_text(
  text : String,
  source_name : String,
  format : @input.DetectedFormat,
  mode? : @convert.ConvertMode = Balanced,
  output? : @convert.OutputFormat = Markdown,
  ocr_options? : @parser.OcrOptions = @parser.default_ocr_options(),
  limits? : @convert.ResourceLimits = @convert.default_resource_limits(),
) -> @convert.ConvertResult {
  let output_mode = @convert.output_mode_for_output_format(output)
  let options = @convert.make_convert_options(
    mode,
    output,
    Some(format),
    ocr_options,
    limits,
    output_mode~,
    stream_requested=mode == Stream,
  )
  match
    @convert.convert_input(
      @input.input_from_text_with_format(text, source_name, Some(format)),
      options,
    ) {
    Ok(result) => result
    Err(err) => abort("convert failed: " + err.to_string())
  }
}

///|
fn limits(
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
  max_line_chars? : Int = 4000,
) -> @convert.ResourceLimits {
  @convert.make_resource_limits(max_rows, max_cols, max_cells, max_line_chars~)
}

///|
fn default_registry_parse(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  requested_mode? : @parser.ParserMode? = None,
  max_rows? : Int? = None,
  max_cols? : Int? = None,
  max_cells? : Int? = None,
  debug? : Bool = false,
) -> @parser.ParseResult {
  let registry = @fmeta.builtin_registry()
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(format),
    requested_mode,
    max_rows,
    max_cols,
    max_cells,
    None,
    debug,
  )
  match @parser.registry_parse(registry, source, context) {
    Ok(result) => result
    Err(err) => abort("parse failed: " + err)
  }
}

///|
fn unwrap_pipeline_output(
  result : Result[@core.IRInput, @pipeline.PassError],
  context : String,
) -> @core.DocumentIR {
  let input = match result {
    Ok(value) => value
    Err(err) => abort(context + ": " + err.message)
  }
  @pipeline.ir_input_to_document(input)
}

///|
fn block_tree_contains_text_fragment(
  blocks : Array[@core.CoreBlock],
  fragment : String,
) -> Bool {
  for block in blocks {
    if block.text.contains(fragment) {
      return true
    }
    if block_tree_contains_text_fragment(block.children, fragment) {
      return true
    }
  }
  false
}

///|
fn pipeline_fake_image_ocr_provider(
  expected_language : String?,
) -> (@focr.OcrProviderRequest) -> Result[
  @focr.OcrProviderResult,
  @focr.OcrProviderError,
] {
  fn(request : @focr.OcrProviderRequest) {
    if request.language != expected_language {
      abort("unexpected OCR language")
    }
    let tsv = [
      "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
      "5\t1\t1\t1\t1\t1\t10\t10\t20\t10\t95\tMoonBit", "5\t1\t1\t1\t1\t2\t35\t10\t15\t10\t94\tOCR",
      "5\t1\t1\t1\t2\t1\t10\t25\t22\t10\t93\tSample", "5\t1\t1\t1\t2\t2\t36\t25\t18\t10\t92\t123",
    ].join("\n")
    match @focr.parse_tesseract_tsv(tsv, language=request.language) {
      Ok(value) => Ok(value)
      Err(err) =>
        abort("expected fake OCR TSV parse success: " + err.to_string())
    }
  }
}

///|
fn streaming_granularity_name_local(
  granularity : @parser.StreamingGranularity,
) -> String {
  match granularity {
    Byte => "byte"
    Line => "line"
    Record => "record"
    Row => "row"
    JsonStructure => "json_structure"
    XmlStructure => "xml_structure"
    YamlStructure => "yaml_structure"
    HtmlTokenStructure => "html_token_structure"
    MarkdownBlock => "markdown_block"
    DocxBlock => "docx_block"
    PptxSlide => "pptx_slide"
    XlsxSheet => "xlsx_sheet"
    XlsxRow => "xlsx_row"
    ArchiveEntry => "archive_entry"
    EpubSpineItem => "epub_spine_item"
    NotebookCellOutputGroup => "notebook_cell_output_group"
    Block => "block"
    Page => "page"
    Slide => "slide"
    Sheet => "sheet"
    Chapter => "chapter"
    Message => "message"
    None => "none"
  }
}

///|
fn assert_parse_result_matches_contract_spec(
  result : @parser.ParseResult,
  spec : @fmeta.ParserContractSpec,
) -> Unit raise {
  fn assert_metric_pair(key : String, expected : String) -> Unit raise {
    match result.diagnostics.metrics.get(key) {
      Some(actual) =>
        if actual != expected {
          fail(
            "contract metric mismatch for " +
            key +
            ": expected " +
            expected +
            ", got " +
            actual,
          )
        }
      None =>
        fail("contract metric missing for " + key + ": expected " + expected)
    }
  }
  assert_metric_pair("parser_name", spec.parser_name)
  assert_metric_pair("parser_mode", @parser.mode_name(spec.parser_mode))
  let actual_shape = @runtime.parse_result_to_ir_input(result)
  let actual_ir_input_kind = match actual_shape {
    Document(_) => "document"
    BlockStream(_) => "block_stream"
    EventStream(_) => "event_stream"
  }
  let expected_ir_input_kind = if actual_ir_input_kind == spec.ir_input_kind {
    spec.ir_input_kind
  } else {
    match spec.large_route_ir_input_kind {
      Some(value) if value == actual_ir_input_kind => value
      _ =>
        fail(
          "contract ir_input_kind mismatch: expected " +
          spec.ir_input_kind +
          " or " +
          spec.large_route_ir_input_kind.unwrap_or("none") +
          ", got " +
          actual_ir_input_kind,
        )
    }
  }
  let expected_granularity = if expected_ir_input_kind == spec.ir_input_kind {
    spec.streaming_granularity
  } else {
    spec.large_route_granularity.unwrap_or(spec.streaming_granularity)
  }
  assert_metric_pair(
    "event_granularity",
    streaming_granularity_name_local(expected_granularity),
  )
  assert_metric_pair("ir_input_kind", expected_ir_input_kind)
  match actual_shape {
    Document(_) => {
      assert_true(result.document is Some(_))
      assert_true(result.block_stream is None)
      assert_true(result.event_stream is None)
    }
    BlockStream(_) => {
      assert_true(result.document is None)
      assert_true(result.block_stream is Some(_))
      assert_true(result.event_stream is None)
    }
    EventStream(_) => {
      assert_true(result.document is None)
      assert_true(result.block_stream is None)
      assert_true(result.event_stream is Some(_))
    }
  }
  for key in spec.required_metrics {
    assert_metric_present(result.diagnostics, key)
  }
}
