///|
fn test_tmp_root() -> String {
  ".tmp/tests/pipeline"
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise {
  let trimmed = path.trim()
  if trimmed == "" {
    return
  }
  let chars = trimmed.to_array()
  let mut current = if chars.length() > 0 && chars[0] == '/' { "/" } else { "" }
  let part : Array[Char] = []

  fn flush(part : Array[Char], current : String) -> String raise {
    if part.length() == 0 {
      return current
    }
    let segment = String::from_array(part)
    part.clear()
    let next = if current == "" || current == "/" {
      current + segment
    } else {
      current + "/" + segment
    }
    ensure_dir(next)
    next
  }

  for ch in chars {
    if ch == '/' {
      current = flush(part, current)
    } else {
      part.push(ch)
    }
  }
  ignore(flush(part, current))
}

///|
fn remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }
  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }
  @fs.remove_dir(path)
}

///|
fn recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    remove_dir_recursive(path)
  }
  ensure_dir_tree(path)
}

///|
fn cleanup_temp_dir(path : String) -> Unit {
  ignore(
    try remove_dir_recursive(path) |> Ok catch {
      _ => Err(())
    },
  )
}

///|
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @fs.write_string_to_file(path, text, encoding="utf8") catch {
    e => fail("write failed: " + e.to_string())
  }
}

///|
fn read_utf8_text(path : String) -> String {
  @fs.read_file_to_string(path, encoding="utf8") catch {
    e => abort("read failed: " + e.to_string())
  }
}

///|
fn collect_mbt_files(path : String, out : Array[String]) -> Unit raise {
  if !@fs.path_exists(path) {
    fail("path missing: " + path)
  }
  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      collect_mbt_files(child, out)
    } else if @fs.is_file(child) && child.has_suffix(".mbt") {
      out.push(child)
    }
  }
}

///|
fn read_package_mbt_sources(path : String) -> String {
  let files : Array[String] = []
  collect_mbt_files(path, files) catch {
    e => abort("collect mbt files failed: " + e.to_string())
  }
  files.sort()
  let parts : Array[String] = []
  for file in files {
    parts.push(read_utf8_text(file))
  }
  parts.join("\n")
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
fn assert_metric_not_eq(
  diagnostics : @core.Diagnostics,
  key : String,
  unexpected : String,
) -> Unit raise {
  assert_true(diagnostics.metrics.get(key) != Some(unexpected))
}

///|
fn assert_metric_absent(
  diagnostics : @core.Diagnostics,
  key : String,
) -> Unit raise {
  assert_true(diagnostics.metrics.get(key) == None)
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
fn assert_exact_count(
  text : String,
  needle : String,
  expected : Int,
) -> Unit raise {
  let mut count = 0
  let mut rest = text
  while true {
    match rest.split_once(needle) {
      Some((_, tail)) => {
        count += 1
        rest = tail.to_owned()
      }
      None => break
    }
  }
  assert_eq(count, expected)
}

///|
fn assert_string_items_contain_none(
  items : Array[String],
  needles : Array[String],
) -> Unit raise {
  assert_contains_none(items.join("\n"), needles)
}

///|
fn assert_diagnostics_lists_contain_none(
  diagnostics : @core.Diagnostics,
  needles : Array[String],
) -> Unit raise {
  assert_string_items_contain_none(diagnostics.warnings, needles)
  assert_string_items_contain_none(diagnostics.errors, needles)
  assert_string_items_contain_none(diagnostics.degraded_features, needles)
  assert_string_items_contain_none(diagnostics.fallback_trace, needles)
  assert_string_items_contain_none(diagnostics.pass_trace, needles)
}

///|
fn assert_file_contains_all(
  path : String,
  needles : Array[String],
) -> Unit raise {
  assert_contains_all(read_utf8_text(path), needles)
}

///|
fn assert_file_contains_none(
  path : String,
  needles : Array[String],
) -> Unit raise {
  assert_contains_none(read_utf8_text(path), needles)
}

///|
fn assert_files_avoid_strings(
  paths : Array[String],
  needles : Array[String],
) -> Unit raise {
  for path in paths {
    assert_file_contains_none(path, needles)
  }
}

///|
fn final_document_from_parse_result(
  parsed : @parser.ParseResult,
  debug? : Bool = false,
  pdf_cleanup_enabled? : Bool = false,
) -> @core.DocumentIR {
  let mut document = @pipeline.build_document_with_default_pipeline(
    @runtime.parse_result_to_ir_input(parsed),
    @pipeline.make_pass_context(
      debug,
      parsed.mode |> @parser.mode_name,
      pdf_cleanup_enabled~,
    ),
    trace_builder=false,
    trace_passes=false,
  )
  let merged = @runtime.merge_diagnostics_append(
    parsed.diagnostics,
    document.diagnostics,
  )
  document = @core.document_with_diagnostics(document, merged)
  document
}

///|
fn convert_memory_text(
  text : String,
  source_name : String,
  format : @input.DetectedFormat,
  mode? : @convert.ConvertMode = @convert.ConvertMode::Balanced,
  output? : @convert.OutputFormat = @convert.OutputFormat::Markdown,
  ocr_options? : @parser.OcrOptions = @parser.default_ocr_options(),
  limits? : @convert.ResourceLimits = @convert.default_resource_limits(),
  pdf_cleanup_mode? : @convert.PdfCleanupMode = @convert.default_pdf_cleanup_mode(),
  pdf_table_mode? : @convert.PdfTableMode = @convert.default_pdf_table_mode(),
) -> @convert.ConvertResult {
  let options = @convert.make_convert_options(
    mode,
    output,
    Some(format),
    ocr_options,
    limits,
    pdf_cleanup_mode~,
    pdf_table_mode~,
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
fn convert_path(
  path : String,
  format? : @input.DetectedFormat? = None,
  mode? : @convert.ConvertMode = @convert.ConvertMode::Balanced,
  output? : @convert.OutputFormat = @convert.OutputFormat::Markdown,
  ocr_options? : @parser.OcrOptions = @parser.default_ocr_options(),
  limits? : @convert.ResourceLimits = @convert.default_resource_limits(),
  pdf_cleanup_mode? : @convert.PdfCleanupMode = @convert.default_pdf_cleanup_mode(),
  pdf_table_mode? : @convert.PdfTableMode = @convert.default_pdf_table_mode(),
) -> @convert.ConvertResult {
  let options = @convert.make_convert_options(
    mode,
    output,
    format,
    ocr_options,
    limits,
    pdf_cleanup_mode~,
    pdf_table_mode~,
  )
  match @convert.convert_input(@input.input_from_path(path), options) {
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
  let registry = @formats_root.builtin_registry()
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
fn find_block_in_tree(
  blocks : Array[@core.CoreBlock],
  kind : @core.BlockKind,
  text : String,
) -> @core.CoreBlock? {
  for block in blocks {
    if block.kind == kind && block.text == text {
      return Some(block)
    }
    match find_block_in_tree(block.children, kind, text) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn block_tree_has_kind(
  blocks : Array[@core.CoreBlock],
  kind : @core.BlockKind,
) -> Bool {
  for block in blocks {
    if block.kind == kind {
      return true
    }
    if block_tree_has_kind(block.children, kind) {
      return true
    }
  }
  false
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
fn flatten_block_texts(blocks : Array[@core.CoreBlock]) -> Array[String] {
  let out : Array[String] = []
  collect_block_texts(blocks, out)
  out
}

///|
fn collect_block_texts(
  blocks : Array[@core.CoreBlock],
  out : Array[String],
) -> Unit {
  for block in blocks {
    out.push(block.text)
    if block.children.length() > 0 {
      collect_block_texts(block.children, out)
    }
  }
}

///|
fn first_string_index(items : Array[String], needle : String) -> Int? {
  for i in 0..<items.length() {
    if items[i] == needle {
      return Some(i)
    }
  }
  None
}

///|
fn assert_ordered_strings(
  items : Array[String],
  left : String,
  right : String,
) -> Unit raise {
  let left_index = match first_string_index(items, left) {
    Some(value) => value
    None => fail("missing ordered string: " + left)
  }
  let right_index = match first_string_index(items, right) {
    Some(value) => value
    None => fail("missing ordered string: " + right)
  }
  assert_true(left_index < right_index)
}

///|
fn contains_trace_in_order(
  traces : Array[String],
  ordered_needles : Array[String],
) -> Bool {
  if ordered_needles.length() == 0 {
    return true
  }
  let mut cursor = 0
  for trace in traces {
    if trace.contains(ordered_needles[cursor]) {
      cursor += 1
      if cursor == ordered_needles.length() {
        return true
      }
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
fn assert_contract_spec_matches_parser(
  spec : @formats_root.ParserContractSpec,
  parser : @parser.Parser,
) -> Unit raise {
  assert_true(@formats_root.parser_contract_spec_matches_parser(spec, parser))
}

///|
fn streaming_granularity_name_local(
  granularity : @parser.StreamingGranularity,
) -> String {
  match granularity {
    @parser.StreamingGranularity::Byte => "byte"
    @parser.StreamingGranularity::Line => "line"
    @parser.StreamingGranularity::Record => "record"
    @parser.StreamingGranularity::Row => "row"
    @parser.StreamingGranularity::JsonStructure => "json_structure"
    @parser.StreamingGranularity::XmlStructure => "xml_structure"
    @parser.StreamingGranularity::YamlStructure => "yaml_structure"
    @parser.StreamingGranularity::HtmlTokenStructure => "html_token_structure"
    @parser.StreamingGranularity::MarkdownBlock => "markdown_block"
    @parser.StreamingGranularity::DocxBlock => "docx_block"
    @parser.StreamingGranularity::PptxSlide => "pptx_slide"
    @parser.StreamingGranularity::XlsxSheet => "xlsx_sheet"
    @parser.StreamingGranularity::XlsxRow => "xlsx_row"
    @parser.StreamingGranularity::ArchiveEntry => "archive_entry"
    @parser.StreamingGranularity::EpubSpineItem => "epub_spine_item"
    @parser.StreamingGranularity::Block => "block"
    @parser.StreamingGranularity::Page => "page"
    @parser.StreamingGranularity::Slide => "slide"
    @parser.StreamingGranularity::Sheet => "sheet"
    @parser.StreamingGranularity::Chapter => "chapter"
    @parser.StreamingGranularity::Message => "message"
    @parser.StreamingGranularity::None => "none"
  }
}

///|
fn assert_parse_result_matches_contract_spec(
  result : @parser.ParseResult,
  spec : @formats_root.ParserContractSpec,
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
  assert_metric_pair(
    "event_granularity",
    streaming_granularity_name_local(spec.streaming_granularity),
  )
  assert_metric_pair("ir_input_kind", spec.ir_input_kind)
  for key in spec.required_metrics {
    assert_metric_present(result.diagnostics, key)
  }
}
