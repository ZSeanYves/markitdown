///|

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
fn unwrap_container_plan(
  result : @parser.ParseResult,
  context : String,
) -> @core.ContainerPlan {
  match result.container_plan {
    Some(plan) => plan
    None => abort("missing container plan: " + context)
  }
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
test "detector contract covers extensions and unknown fallback" {
  let detector = @input.default_format_detector()
  assert_true(
    (detector.detect)(@input.input_from_path("notes.txt")).format ==
    @input.DetectedFormat::Txt,
  )
  assert_true(
    (detector.detect)(@input.input_from_path("post.md")).format ==
    @input.DetectedFormat::Markdown,
  )
  assert_true(
    (detector.detect)(@input.input_from_path("post.markdown")).format ==
    @input.DetectedFormat::Markdown,
  )
  assert_true(
    (detector.detect)(@input.input_from_path("table.csv")).format ==
    @input.DetectedFormat::Csv,
  )
  assert_true(
    (detector.detect)(@input.input_from_path("table.tsv")).format ==
    @input.DetectedFormat::Tsv,
  )
  assert_true(
    (detector.detect)(@input.input_from_path("doc.json")).format ==
    @input.DetectedFormat::Json,
  )
  assert_true(
    (detector.detect)(@input.input_from_path("records.jsonl")).format ==
    @input.DetectedFormat::Jsonl,
  )
  assert_true(
    (detector.detect)(@input.input_from_path("records.ndjson")).format ==
    @input.DetectedFormat::Ndjson,
  )
  assert_true(
    (detector.detect)(@input.input_from_path("tree.xml")).format ==
    @input.DetectedFormat::Xml,
  )
  let png = (detector.detect)(@input.input_from_path("scan.png"))
  assert_true(
    png.format == @input.DetectedFormat::Image(@input.ImageFormat::Png),
  )
  assert_true(png.binary_like)
  assert_true(!png.text_like)
  assert_true(png.notes.contains("image_ocr_candidate"))
  let tiff = (detector.detect)(@input.input_from_path("scan.tiff"))
  assert_true(
    tiff.format == @input.DetectedFormat::Image(@input.ImageFormat::Tiff),
  )
  let pdf = (detector.detect)(@input.input_from_path("sample.pdf"))
  assert_true(pdf.format == @input.DetectedFormat::Pdf)
  assert_true(pdf.binary_like)
  assert_true(!pdf.text_like)
  assert_true(
    @input.parse_detected_format("jpg") ==
    @input.DetectedFormat::Image(@input.ImageFormat::Jpg),
  )
  assert_true(@input.parse_detected_format("pdf") == @input.DetectedFormat::Pdf)
  assert_true(@input.detected_format_name(@input.DetectedFormat::Pdf) == "pdf")
  assert_true(
    @input.detected_format_name(
      @input.DetectedFormat::Image(@input.ImageFormat::Webp),
    ) ==
    "webp",
  )
  let unknown = (detector.detect)(
    @input.input_from_bytes_with_format(
      Bytes::from_array([0, 1, 2, 3]),
      "blob.bin",
      None,
    ),
  )
  assert_true(unknown.format == @input.DetectedFormat::Unknown)
  assert_true(unknown.binary_like)
}

///|
test "convert contract recognizes image candidates but keeps default path fail closed" {
  let image = @input.input_from_path_with_format(
    "scan.png",
    Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
  )
  let result = @convert.convert_input(image, @convert.default_convert_options())
  match result {
    Err(@convert.ConvertError::ParseFailed(msg)) => {
      assert_true(msg.contains("image OCR is not enabled"))
      assert_true(msg.contains("png"))
    }
    Err(other) => fail("unexpected convert error kind: " + other.to_string())
    Ok(_) =>
      fail("image candidate should not produce successful default conversion")
  }
}

///|
test "convert contract threads OCR intent to image scaffold fail-closed branches" {
  let image = @input.input_from_path_with_format(
    "scan.png",
    Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
  )

  let explicit = @convert.convert_input(
    image,
    @convert.make_convert_options(
      @convert.ConvertMode::Balanced,
      @convert.OutputFormat::Markdown,
      Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
      @parser.explicit_ocr_options(language=Some("eng")),
      @convert.default_resource_limits(),
    ),
  )
  match explicit {
    Err(@convert.ConvertError::ParseFailed(msg)) => {
      assert_true(msg.contains("not configured"))
      assert_true(msg.contains("image_format=png"))
      assert_true(msg.contains("language=eng"))
    }
    Err(other) =>
      fail("unexpected explicit OCR convert error: " + other.to_string())
    Ok(_) => fail("explicit OCR image convert should stay fail closed")
  }

  let disabled = @convert.convert_input(
    image,
    @convert.make_convert_options(
      @convert.ConvertMode::Balanced,
      @convert.OutputFormat::Markdown,
      Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
      @parser.disabled_ocr_options(),
      @convert.default_resource_limits(),
    ),
  )
  match disabled {
    Err(@convert.ConvertError::ParseFailed(msg)) => {
      assert_true(msg.contains("OCR is disabled"))
      assert_true(msg.contains("png"))
    }
    Err(other) =>
      fail("unexpected disabled OCR convert error: " + other.to_string())
    Ok(_) => fail("disabled OCR image convert should stay fail closed")
  }
}

///|
test "convert contract recognizes pdf as a root native-text product format" {
  let pdf = @input.input_from_path_with_format(
    "samples/main_process/pdf/text_simple.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let result = @convert.convert_input(pdf, @convert.default_convert_options())
  match result {
    Ok(parsed) => {
      assert_true(parsed.content.contains("MarkItDown"))
      assert_true(!parsed.content.contains("]("))
      assert_true(
        parsed.diagnostics.metrics.get("detected_format") == Some("pdf"),
      )
      assert_true(
        parsed.diagnostics.metrics.get("product_path_enabled") == Some("true"),
      )
      assert_true(
        parsed.diagnostics.metrics.get("renderer_name") ==
        Some("MarkdownRenderer"),
      )
      assert_true(
        parsed.diagnostics.metrics.get("pdf_native_parser_gate") ==
        Some("enabled"),
      )
      assert_true(
        parsed.diagnostics.metrics.get("pdf_native_backend") == Some("true"),
      )
      assert_true(
        parsed.diagnostics.metrics.get("pdf_native_text_baseline") ==
        Some("true"),
      )
      assert_true(
        parsed.diagnostics.metrics.get("pdf_ocr_used") == Some("false"),
      )
      assert_true(
        parsed.diagnostics.metrics.get("pdf_v2_used") == Some("false"),
      )
      assert_true(
        parsed.diagnostics.metrics.get("pdf_empty_text_layer") == Some("false"),
      )
      assert_true(
        parsed.diagnostics.metrics.get("pdf_grouping_strategy") ==
        Some("conservative_v1"),
      )
      assert_true(
        parsed.diagnostics.metrics.get("pdf_grouping_paragraph_count")
        is Some(_),
      )
      assert_true(
        parsed.diagnostics.metrics.get("pdf_grouping_line_merge_count")
        is Some(_),
      )
      assert_true(!parsed.diagnostics.pass_trace.join("\n").contains("pdf_v2"))
      assert_true(
        !parsed.diagnostics.pass_trace.join("\n").contains("pdf_debug"),
      )
      assert_true(!parsed.diagnostics.warnings.join("\n").contains("pdf_v2"))
    }
    Err(other) =>
      fail("expected pdf native-text convert success: " + other.to_string())
  }
}

///|
test "convert pdf explicit OCR stays fail-closed before any image OCR provider route" {
  let pdf = @input.input_from_path_with_format(
    "samples/main_process/pdf/root_native_text_baseline.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match
    @convert.convert_input_with_image_ocr_provider(
      pdf,
      @convert.make_convert_options(
        @convert.ConvertMode::Balanced,
        @convert.OutputFormat::Markdown,
        Some(@input.DetectedFormat::Pdf),
        @parser.explicit_ocr_options(language=Some("eng")),
        @convert.default_resource_limits(),
      ),
      fn(_request) { abort("pdf input must not invoke image OCR provider") },
    ) {
    Err(@convert.ConvertError::ParseFailed(msg)) => {
      assert_true(msg.contains("PDF OCR is not supported"))
      assert_true(msg.contains("scanned/image-only PDFs"))
      assert_true(!msg.contains("not configured"))
    }
    Err(other) =>
      fail("unexpected pdf explicit OCR convert error: " + other.to_string())
    Ok(_) => fail("pdf explicit OCR should stay fail closed")
  }
}

///|
test "convert scanned-like pdf fails closed instead of returning empty markdown" {
  let empty_pdf = [
    "%PDF-1.4", "1 0 obj", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "endobj", "2 0 obj", "<< /Length 5 >>", "stream", "BT ET", "endstream", "endobj",
    "3 0 obj", "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
    "endobj", "4 0 obj", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>", "endobj", "5 0 obj",
    "<< /Type /Catalog /Pages 4 0 R >>", "endobj", "trailer", "<< /Size 6 /Root 5 0 R >>",
    "%%EOF", "",
  ].join("\n")
  let source = @input.input_from_bytes_with_format(
    @utf8.encode(empty_pdf),
    "scanned-like.pdf",
    Some(@input.DetectedFormat::Pdf),
  )

  match @convert.convert_input(source, @convert.default_convert_options()) {
    Err(@convert.ConvertError::ParseFailed(msg)) => {
      assert_true(msg.contains("empty"))
      assert_true(msg.contains("root pdf_native backend"))
      assert_true(!msg.contains("not configured"))
      assert_true(
        !msg.contains("image OCR provider returned a non-empty OCR model"),
      )
    }
    Err(other) =>
      fail("unexpected scanned-like pdf convert error: " + other.to_string())
    Ok(result) =>
      fail(
        "scanned-like pdf must fail closed instead of returning content: " +
        result.content,
      )
  }

  match
    @parser.registry_parse(
      @formats_root.builtin_registry(),
      source,
      @parser.new_parse_context(@input.DetectedFormat::Pdf),
    ) {
    Err(msg) => {
      assert_true(msg.contains("empty"))
      assert_true(msg.contains("root pdf_native backend"))
    }
    Ok(_) => fail("registry parse should not succeed for scanned-like pdf")
  }
}

///|
test "builtin registry wires pdf native text parser without unmigrated runtime imports" {
  let registry_impl = read_utf8_text("formats/registry.mbt")
  assert_true(registry_impl.contains("DetectedFormat::Pdf"))
  assert_true(registry_impl.contains("pdf_native_parser()"))
  assert_true(!registry_impl.contains("pdf_v2"))
  assert_true(!registry_impl.contains("pdf_debug"))
  assert_true(!registry_impl.contains("quality-lab"))

  match
    @parser.registry_parse(
      @formats_root.builtin_registry(),
      @input.input_from_path_with_format(
        "samples/main_process/pdf/text_simple.pdf",
        Some(@input.DetectedFormat::Pdf),
      ),
      @parser.new_parse_context(@input.DetectedFormat::Pdf),
    ) {
    Ok(result) => {
      let document = result.document.unwrap_or(@core.empty_document_ir())
      assert_true(document.blocks.length() >= 3)
      assert_true(
        document.diagnostics.metrics.get("runtime_exposed") == Some("true"),
      )
    }
    Err(msg) => fail("pdf registry parse should succeed: " + msg)
  }
}

///|
test "pdf explicit disable policy can still force fail-closed registry behavior" {
  let source = @input.input_from_path_with_format(
    "samples/main_process/pdf/text_simple.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let gated_context = @parser.parse_context_with_pdf_native_runtime_policy(
    @parser.parse_context_with_limits(
      @parser.new_parse_context(@input.DetectedFormat::Pdf),
      Some(@parser.ParserMode::PageSinglePass),
      None,
      None,
      None,
      None,
      false,
    ),
    @parser.PdfNativeRuntimePolicy::DisableTextRestore,
  )
  match
    @parser.registry_parse(
      @formats_root.builtin_registry(),
      source,
      gated_context,
    ) {
    Err(err) => assert_true(err.contains("disabled by parser policy"))
    Ok(_) => fail("disabled pdf policy should remain fail closed")
  }

  match
    @parser.registry_parse(
      @formats_root.builtin_registry(),
      source,
      @parser.new_parse_context(@input.DetectedFormat::Pdf),
    ) {
    Ok(parsed) => {
      let document = parsed.document.unwrap_or(@core.empty_document_ir())
      assert_true(document.blocks.length() >= 3)
      assert_true(
        document.diagnostics.metrics.get("pdf_native_parser_gate") ==
        Some("enabled"),
      )
    }
    Err(msg) => fail("default pdf registry path should succeed: " + msg)
  }
}

///|
test "pdf native unit bridge lowers facts to document ir without changing registry success behavior" {
  let bbox = @formats.make_pdf_bbox(10.0, 20.0, 40.0, 10.0)
  let line = @formats.make_pdf_native_text_line(
    [@formats.make_pdf_native_text_span("Bridge", bbox)],
    bbox,
    source_ref=Some({
      ..@core.source_ref_with_lines(
        @core.empty_source_ref(),
        Some("bridge.pdf"),
        Some("pdf"),
        Some(1),
        Some(1),
      ),
      page: Some(1),
    }),
    reading_order_index=Some(1),
  )
  let page = @formats.make_pdf_native_page(
    @formats.make_pdf_page_geometry(1, 612.0, 792.0),
    text_blocks=[@formats.make_pdf_native_text_block([line], bbox)],
    link_candidates=[
      @formats.make_pdf_native_link_candidate(
        bbox,
        "https://example.com",
        text=Some("Bridge"),
      ),
    ],
  )
  let diagnostics = @core.empty_diagnostics()
  diagnostics.metrics.set("product_path_enabled", "false")
  let document = @formats.pdf_native_document_to_ir(
    @formats.make_pdf_native_document(pages=[page], diagnostics~),
  )
  assert_eq(document.blocks.length(), 1)
  assert_eq(document.blocks[0].text, "Bridge")
  assert_true(
    document.diagnostics.metrics.get("pdf_native_ir_bridge") ==
    Some("unit_path"),
  )
  assert_true(document.diagnostics.metrics.get("renderer_name") == None)
  assert_true(
    document.diagnostics.metrics.get("product_path_enabled") == Some("false"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_link_candidate_count") == Some("1"),
  )
  match document.metadata.get("pdf_link_candidates") {
    Some(@core.JsonValue::Array(items)) => assert_eq(items.length(), 1)
    _ => fail("expected metadata-only link candidate preservation")
  }

  match
    @parser.registry_parse(
      @formats_root.builtin_registry(),
      @input.input_from_path_with_format(
        "samples/main_process/pdf/text_simple.pdf",
        Some(@input.DetectedFormat::Pdf),
      ),
      @parser.new_parse_context(@input.DetectedFormat::Pdf),
    ) {
    Ok(parsed) => {
      let parsed_document = parsed.document.unwrap_or(@core.empty_document_ir())
      assert_true(parsed_document.blocks.length() >= 3)
    }
    Err(msg) => fail("pdf registry success path should remain enabled: " + msg)
  }
}

///|
test "pdf native product path exposes header footer candidate diagnostics without changing markdown output" {
  let parsed = default_registry_parse(
    @input.input_from_path_with_format(
      "samples/main_process/pdf/text_simple.pdf",
      Some(@input.DetectedFormat::Pdf),
    ),
    @input.DetectedFormat::Pdf,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(
    document.diagnostics.metrics.get("pdf_header_footer_candidate_strategy") ==
    Some("conservative_v1"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_header_candidate_count") is Some(_),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_footer_candidate_count") is Some(_),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_header_footer_candidate_count")
    is Some(_),
  )
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(rendered.content.contains("MarkItDown"))
  assert_true(!rendered.content.to_lower().contains("pdf_v2"))
  assert_true(!rendered.content.to_lower().contains("pdf_debug"))
}

///|
test "pdf product options default disabled but expose future promotion targets in diagnostics" {
  let result = convert_path(
    "samples/main_process/pdf/root_native_text_baseline.pdf",
    format=Some(@input.DetectedFormat::Pdf),
    output=@convert.OutputFormat::DebugJson,
  )
  assert_metric_eq(result.diagnostics, "pdf_cleanup_mode", "none")
  assert_metric_eq(result.diagnostics, "pdf_cleanup_enabled", "false")
  assert_metric_eq(result.diagnostics, "pdf_cleanup_default_mode", "none")
  assert_metric_eq(
    result.diagnostics,
    "pdf_cleanup_promotion_target",
    "conservative",
  )
  assert_metric_eq(result.diagnostics, "pdf_table_mode", "none")
  assert_metric_eq(result.diagnostics, "pdf_table_enabled", "false")
  assert_metric_eq(result.diagnostics, "pdf_table_default_mode", "none")
  assert_metric_eq(result.diagnostics, "pdf_table_promotion_target", "simple")
}

///|
test "pdf product options opt in to cleanup and simple tables without changing default baseline contract" {
  let baseline = convert_path(
    "samples/main_process/pdf/root_native_text_baseline.pdf",
    format=Some(@input.DetectedFormat::Pdf),
  )
  let opted_in = convert_path(
    "samples/main_process/pdf/root_native_text_baseline.pdf",
    format=Some(@input.DetectedFormat::Pdf),
    pdf_cleanup_mode=@convert.PdfCleanupMode::Conservative,
    pdf_table_mode=@convert.PdfTableMode::Simple,
  )
  assert_eq(opted_in.content, baseline.content)
  assert_metric_eq(opted_in.diagnostics, "pdf_cleanup_mode", "conservative")
  assert_metric_eq(opted_in.diagnostics, "pdf_cleanup_enabled", "true")
  assert_metric_eq(opted_in.diagnostics, "pdf_table_mode", "simple")
  assert_metric_eq(opted_in.diagnostics, "pdf_table_enabled", "true")
  assert_metric_eq(
    opted_in.diagnostics,
    "pdf_header_footer_filter_policy",
    "internal_high_confidence_only",
  )
  assert_metric_eq(
    opted_in.diagnostics,
    "pdf_table_reconstruction_policy",
    "internal_simple_rows_only",
  )
}

///|
test "pdf native header footer candidates stay metadata only and do not filter rendered markdown" {
  let header = "Monthly Summary"
  let footer = "Page footer repeated"
  let page1 = @formats.make_pdf_native_page(
    @formats.make_pdf_page_geometry(1, 612.0, 792.0),
    text_blocks=[
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                header,
                @formats.make_pdf_bbox(40.0, 760.0, 120.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 760.0, 120.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("hf-product.pdf"),
                Some("pdf"),
                Some(1),
                Some(1),
              ),
              page: Some(1),
            }),
            reading_order_index=Some(1),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 760.0, 120.0, 12.0),
        reading_order_index=Some(1),
      ),
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "Body paragraph one",
                @formats.make_pdf_bbox(40.0, 420.0, 140.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 420.0, 140.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("hf-product.pdf"),
                Some("pdf"),
                Some(2),
                Some(2),
              ),
              page: Some(1),
            }),
            reading_order_index=Some(2),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 420.0, 140.0, 12.0),
        reading_order_index=Some(2),
      ),
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                footer,
                @formats.make_pdf_bbox(40.0, 18.0, 140.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 18.0, 140.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("hf-product.pdf"),
                Some("pdf"),
                Some(3),
                Some(3),
              ),
              page: Some(1),
            }),
            reading_order_index=Some(3),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 18.0, 140.0, 12.0),
        reading_order_index=Some(3),
      ),
    ],
  )
  let page2 = @formats.make_pdf_native_page(
    @formats.make_pdf_page_geometry(2, 612.0, 792.0),
    text_blocks=[
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                header,
                @formats.make_pdf_bbox(42.0, 760.0, 120.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(42.0, 760.0, 120.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("hf-product.pdf"),
                Some("pdf"),
                Some(1),
                Some(1),
              ),
              page: Some(2),
            }),
            reading_order_index=Some(1),
          ),
        ],
        @formats.make_pdf_bbox(42.0, 760.0, 120.0, 12.0),
        reading_order_index=Some(1),
      ),
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "Body paragraph two",
                @formats.make_pdf_bbox(40.0, 420.0, 140.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 420.0, 140.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("hf-product.pdf"),
                Some("pdf"),
                Some(2),
                Some(2),
              ),
              page: Some(2),
            }),
            reading_order_index=Some(2),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 420.0, 140.0, 12.0),
        reading_order_index=Some(2),
      ),
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                footer,
                @formats.make_pdf_bbox(42.0, 18.0, 140.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(42.0, 18.0, 140.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("hf-product.pdf"),
                Some("pdf"),
                Some(3),
                Some(3),
              ),
              page: Some(2),
            }),
            reading_order_index=Some(3),
          ),
        ],
        @formats.make_pdf_bbox(42.0, 18.0, 140.0, 12.0),
        reading_order_index=Some(3),
      ),
    ],
  )
  let document = @formats.pdf_native_document_to_ir(
    @formats.make_pdf_native_document(pages=[page1, page2]),
  )
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(rendered.content.contains(header))
  assert_true(rendered.content.contains(footer))
  assert_true(rendered.content.contains("Body paragraph one"))
  assert_true(rendered.content.contains("Body paragraph two"))
  assert_true(
    document.diagnostics.metrics.get("pdf_header_footer_candidate_count") ==
    Some("2"),
  )
  match document.metadata.get("pdf_header_footer_candidates") {
    Some(@core.JsonValue::Array(items)) => assert_eq(items.length(), 2)
    _ => fail("expected metadata-only header/footer candidate array")
  }
}

///|
test "pdf native table candidates stay metadata only and do not change rendered markdown" {
  let page1 = @formats.make_pdf_native_page(
    @formats.make_pdf_page_geometry(1, 612.0, 792.0),
    text_blocks=[
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "Product",
                @formats.make_pdf_bbox(40.0, 620.0, 40.0, 12.0),
              ),
              @formats.make_pdf_native_text_span(
                " Region",
                @formats.make_pdf_bbox(120.0, 620.0, 40.0, 12.0),
              ),
              @formats.make_pdf_native_text_span(
                " Status",
                @formats.make_pdf_bbox(220.0, 620.0, 40.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 620.0, 220.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("table-product.pdf"),
                Some("pdf"),
                Some(1),
                Some(1),
              ),
              page: Some(1),
            }),
            reading_order_index=Some(1),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 620.0, 220.0, 12.0),
        reading_order_index=Some(1),
      ),
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "Alpha",
                @formats.make_pdf_bbox(40.0, 602.0, 40.0, 12.0),
              ),
              @formats.make_pdf_native_text_span(
                " East",
                @formats.make_pdf_bbox(120.0, 602.0, 36.0, 12.0),
              ),
              @formats.make_pdf_native_text_span(
                " Open",
                @formats.make_pdf_bbox(220.0, 602.0, 36.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 602.0, 216.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("table-product.pdf"),
                Some("pdf"),
                Some(2),
                Some(2),
              ),
              page: Some(1),
            }),
            reading_order_index=Some(2),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 602.0, 216.0, 12.0),
        reading_order_index=Some(2),
      ),
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "Beta",
                @formats.make_pdf_bbox(40.0, 584.0, 36.0, 12.0),
              ),
              @formats.make_pdf_native_text_span(
                " West",
                @formats.make_pdf_bbox(120.0, 584.0, 36.0, 12.0),
              ),
              @formats.make_pdf_native_text_span(
                " Closed",
                @formats.make_pdf_bbox(220.0, 584.0, 52.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 584.0, 232.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("table-product.pdf"),
                Some("pdf"),
                Some(3),
                Some(3),
              ),
              page: Some(1),
            }),
            reading_order_index=Some(3),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 584.0, 232.0, 12.0),
        reading_order_index=Some(3),
      ),
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "Body paragraph after table-like rows",
                @formats.make_pdf_bbox(40.0, 520.0, 220.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 520.0, 220.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("table-product.pdf"),
                Some("pdf"),
                Some(4),
                Some(4),
              ),
              page: Some(1),
            }),
            reading_order_index=Some(4),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 520.0, 220.0, 12.0),
        reading_order_index=Some(4),
      ),
    ],
  )
  let document = @formats.pdf_native_document_to_ir(
    @formats.make_pdf_native_document(pages=[page1]),
  )
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(rendered.content.contains("Product Region Status"))
  assert_true(rendered.content.contains("Alpha East Open"))
  assert_true(rendered.content.contains("Beta West Closed"))
  assert_true(rendered.content.contains("Body paragraph after table-like rows"))
  assert_true(!rendered.content.contains("| ---"))
  assert_true(
    document.diagnostics.metrics.get("pdf_table_candidate_strategy") ==
    Some("conservative_v1"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_table_candidate_count") == Some("1"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_table_row_candidate_count") ==
    Some("3"),
  )
  match document.metadata.get("pdf_table_candidates") {
    Some(@core.JsonValue::Array(items)) => assert_eq(items.length(), 1)
    _ => fail("expected metadata-only table candidate array")
  }
}

///|
test "pdf native parser policy scaffold remains opt-in and default product markdown stays unchanged" {
  let source = @input.input_from_path_with_format(
    "samples/main_process/pdf/root_native_text_baseline.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let default_parsed = match
    @parser.registry_parse(
      @formats_root.builtin_registry(),
      source,
      @parser.new_parse_context(@input.DetectedFormat::Pdf),
    ) {
    Ok(value) => value
    Err(msg) => fail("default pdf registry parse should succeed: " + msg)
  }
  let default_document = default_parsed.document.unwrap_or(
    @core.empty_document_ir(),
  )
  let default_rendered = (@render.markdown_renderer().render)(
    default_document,
    @render.make_render_context(false),
  )
  assert_eq(default_rendered.content.trim().to_owned(), "Hello PDF")
  assert_true(
    default_document.diagnostics.metrics.get("pdf_header_footer_filter_policy") ==
    Some("disabled"),
  )
  assert_true(
    default_document.diagnostics.metrics.get("pdf_table_reconstruction_policy") ==
    Some("disabled"),
  )

  let internal_context = @parser.parse_context_with_pdf_table_reconstruction_policy(
    @parser.parse_context_with_pdf_header_footer_filter_policy(
      @parser.new_parse_context(@input.DetectedFormat::Pdf),
      @parser.PdfHeaderFooterFilterPolicy::InternalHighConfidenceOnly,
    ),
    @parser.PdfTableReconstructionPolicy::InternalSimpleRowsOnly,
  )
  let internal_parsed = match
    @parser.registry_parse(
      @formats_root.builtin_registry(),
      source,
      internal_context,
    ) {
    Ok(value) => value
    Err(msg) => fail("internal pdf registry parse should still succeed: " + msg)
  }
  let internal_document = internal_parsed.document.unwrap_or(
    @core.empty_document_ir(),
  )
  let internal_rendered = (@render.markdown_renderer().render)(
    internal_document,
    @render.make_render_context(false),
  )
  assert_eq(internal_rendered.content, default_rendered.content)
  assert_true(
    internal_document.diagnostics.metrics.get("pdf_header_footer_filter_policy") ==
    Some("internal_high_confidence_only"),
  )
  assert_true(
    internal_document.diagnostics.metrics.get(
      "pdf_header_footer_filter_enabled",
    ) ==
    Some("true"),
  )
  assert_true(
    internal_document.diagnostics.metrics.get("pdf_table_reconstruction_policy") ==
    Some("internal_simple_rows_only"),
  )
  assert_true(
    internal_document.diagnostics.metrics.get(
      "pdf_table_reconstruction_enabled",
    ) ==
    Some("true"),
  )
  assert_true(
    internal_document.diagnostics.metrics.get("pdf_header_footer_removed_count") ==
    Some("0"),
  )
  assert_true(
    internal_document.diagnostics.metrics.get(
      "pdf_table_reconstruction_table_count",
    ) ==
    Some("0"),
  )
}

///|
test "pdf internal header footer filtering stays opt-in and only changes markdown behind internal policy" {
  let page1 = @formats.make_pdf_native_page(
    @formats.make_pdf_page_geometry(1, 612.0, 792.0),
    text_blocks=[
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "Sample Report - Internal Use Only",
                @formats.make_pdf_bbox(40.0, 760.0, 180.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 760.0, 180.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("hf-optin.pdf"),
                Some("pdf"),
                Some(1),
                Some(1),
              ),
              page: Some(1),
            }),
            reading_order_index=Some(1),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 760.0, 180.0, 12.0),
        reading_order_index=Some(1),
      ),
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "The body stays visible on page one.",
                @formats.make_pdf_bbox(40.0, 420.0, 220.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 420.0, 220.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("hf-optin.pdf"),
                Some("pdf"),
                Some(2),
                Some(2),
              ),
              page: Some(1),
            }),
            reading_order_index=Some(2),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 420.0, 220.0, 12.0),
        reading_order_index=Some(2),
      ),
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "Confidential Footer - Do Not Distribute",
                @formats.make_pdf_bbox(40.0, 18.0, 220.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 18.0, 220.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("hf-optin.pdf"),
                Some("pdf"),
                Some(3),
                Some(3),
              ),
              page: Some(1),
            }),
            reading_order_index=Some(3),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 18.0, 220.0, 12.0),
        reading_order_index=Some(3),
      ),
    ],
  )
  let page2 = @formats.make_pdf_native_page(
    @formats.make_pdf_page_geometry(2, 612.0, 792.0),
    text_blocks=[
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "Sample Report - Internal Use Only",
                @formats.make_pdf_bbox(40.0, 760.0, 180.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 760.0, 180.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("hf-optin.pdf"),
                Some("pdf"),
                Some(1),
                Some(1),
              ),
              page: Some(2),
            }),
            reading_order_index=Some(1),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 760.0, 180.0, 12.0),
        reading_order_index=Some(1),
      ),
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "The body stays visible on page two.",
                @formats.make_pdf_bbox(40.0, 420.0, 220.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 420.0, 220.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("hf-optin.pdf"),
                Some("pdf"),
                Some(2),
                Some(2),
              ),
              page: Some(2),
            }),
            reading_order_index=Some(2),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 420.0, 220.0, 12.0),
        reading_order_index=Some(2),
      ),
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "Confidential Footer - Do Not Distribute",
                @formats.make_pdf_bbox(40.0, 18.0, 220.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 18.0, 220.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("hf-optin.pdf"),
                Some("pdf"),
                Some(3),
                Some(3),
              ),
              page: Some(2),
            }),
            reading_order_index=Some(3),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 18.0, 220.0, 12.0),
        reading_order_index=Some(3),
      ),
    ],
  )
  let default_document = @formats.pdf_native_document_to_ir(
    @formats.make_pdf_native_document(pages=[page1, page2]),
  )
  let default_rendered = (@render.markdown_renderer().render)(
    default_document,
    @render.make_render_context(false),
  )
  assert_true(
    default_rendered.content.contains("Sample Report - Internal Use Only"),
  )
  assert_true(
    default_rendered.content.contains("Confidential Footer - Do Not Distribute"),
  )

  let filtered_document = @formats.pdf_native_document_to_ir_with_policies(
    @formats.make_pdf_native_document(pages=[page1, page2]),
    @parser.PdfHeaderFooterFilterPolicy::InternalHighConfidenceOnly,
    @parser.PdfTableReconstructionPolicy::Disabled,
  )
  let filtered_rendered = (@render.markdown_renderer().render)(
    filtered_document,
    @render.make_render_context(false),
  )
  assert_true(
    !filtered_rendered.content.contains("Sample Report - Internal Use Only"),
  )
  assert_true(
    !filtered_rendered.content.contains(
      "Confidential Footer - Do Not Distribute",
    ),
  )
  assert_true(
    filtered_rendered.content.contains("The body stays visible on page one."),
  )
  assert_true(
    filtered_rendered.content.contains("The body stays visible on page two."),
  )
  assert_true(
    filtered_document.diagnostics.metrics.get("pdf_header_footer_removed_count") ==
    Some("4"),
  )
}

///|
test "pdf internal simple table reconstruction stays opt-in and uses renderer table output only when enabled" {
  let page = @formats.make_pdf_native_page(
    @formats.make_pdf_page_geometry(1, 612.0, 792.0),
    text_blocks=[
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "Product",
                @formats.make_pdf_bbox(40.0, 620.0, 40.0, 12.0),
              ),
              @formats.make_pdf_native_text_span(
                " Region",
                @formats.make_pdf_bbox(120.0, 620.0, 40.0, 12.0),
              ),
              @formats.make_pdf_native_text_span(
                " Status",
                @formats.make_pdf_bbox(220.0, 620.0, 40.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 620.0, 220.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("table-optin.pdf"),
                Some("pdf"),
                Some(1),
                Some(1),
              ),
              page: Some(1),
            }),
            reading_order_index=Some(1),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 620.0, 220.0, 12.0),
        reading_order_index=Some(1),
      ),
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "Alpha",
                @formats.make_pdf_bbox(40.0, 602.0, 40.0, 12.0),
              ),
              @formats.make_pdf_native_text_span(
                " East",
                @formats.make_pdf_bbox(120.0, 602.0, 36.0, 12.0),
              ),
              @formats.make_pdf_native_text_span(
                " Open",
                @formats.make_pdf_bbox(220.0, 602.0, 36.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 602.0, 216.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("table-optin.pdf"),
                Some("pdf"),
                Some(2),
                Some(2),
              ),
              page: Some(1),
            }),
            reading_order_index=Some(2),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 602.0, 216.0, 12.0),
        reading_order_index=Some(2),
      ),
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "Beta",
                @formats.make_pdf_bbox(40.0, 584.0, 36.0, 12.0),
              ),
              @formats.make_pdf_native_text_span(
                " West",
                @formats.make_pdf_bbox(120.0, 584.0, 36.0, 12.0),
              ),
              @formats.make_pdf_native_text_span(
                " Closed",
                @formats.make_pdf_bbox(220.0, 584.0, 52.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 584.0, 232.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("table-optin.pdf"),
                Some("pdf"),
                Some(3),
                Some(3),
              ),
              page: Some(1),
            }),
            reading_order_index=Some(3),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 584.0, 232.0, 12.0),
        reading_order_index=Some(3),
      ),
      @formats.make_pdf_native_text_block(
        [
          @formats.make_pdf_native_text_line(
            [
              @formats.make_pdf_native_text_span(
                "Body paragraph after table-like rows",
                @formats.make_pdf_bbox(40.0, 520.0, 220.0, 12.0),
              ),
            ],
            @formats.make_pdf_bbox(40.0, 520.0, 220.0, 12.0),
            source_ref=Some({
              ..@core.source_ref_with_lines(
                @core.empty_source_ref(),
                Some("table-optin.pdf"),
                Some("pdf"),
                Some(4),
                Some(4),
              ),
              page: Some(1),
            }),
            reading_order_index=Some(4),
          ),
        ],
        @formats.make_pdf_bbox(40.0, 520.0, 220.0, 12.0),
        reading_order_index=Some(4),
      ),
    ],
  )
  let default_document = @formats.pdf_native_document_to_ir(
    @formats.make_pdf_native_document(pages=[page]),
  )
  let default_rendered = (@render.markdown_renderer().render)(
    default_document,
    @render.make_render_context(false),
  )
  assert_true(default_rendered.content.contains("Product Region Status"))
  assert_true(!default_rendered.content.contains("| --- |"))

  let reconstructed_document = @formats.pdf_native_document_to_ir_with_policies(
    @formats.make_pdf_native_document(pages=[page]),
    @parser.PdfHeaderFooterFilterPolicy::Disabled,
    @parser.PdfTableReconstructionPolicy::InternalSimpleRowsOnly,
  )
  let reconstructed_rendered = (@render.markdown_renderer().render)(
    reconstructed_document,
    @render.make_render_context(false),
  )
  assert_true(
    reconstructed_rendered.content.contains("| Product | Region | Status |"),
  )
  assert_true(
    reconstructed_rendered.content.contains("| Alpha | East | Open |"),
  )
  assert_true(
    reconstructed_rendered.content.contains("| Beta | West | Closed |"),
  )
  assert_true(
    reconstructed_rendered.content.contains(
      "Body paragraph after table-like rows",
    ),
  )
  assert_true(
    reconstructed_document.diagnostics.metrics.get(
      "pdf_table_reconstruction_table_count",
    ) ==
    Some("1"),
  )
}

///|
test "root image parser scaffold reserves explicit OCR mode without wiring a provider" {
  let source = @input.input_from_path("scan.png")
  let detected = @input.DetectedFormat::Image(@input.ImageFormat::Png)
  let disabled = @focr.image_ocr_parser_result(
    source,
    detected,
    @parser.default_ocr_options(),
  )
  match disabled {
    Err(msg) => {
      assert_true(msg.contains("image OCR is not enabled"))
      assert_true(msg.contains("png"))
    }
    Ok(_) => fail("default OCR scaffold should stay fail closed")
  }

  let explicit = @focr.image_ocr_parser_result(
    source,
    detected,
    @parser.explicit_ocr_options(),
    requested_mode=Some(@parser.ParserMode::LayoutTwoStage),
  )
  match explicit {
    Err(msg) => {
      assert_true(msg.contains("not configured"))
      assert_true(msg.contains("png"))
    }
    Ok(_) =>
      fail(
        "explicit OCR scaffold should still fail until provider wiring exists",
      )
  }

  let disabled_by_user = @focr.image_ocr_parser_result(
    source,
    detected,
    @parser.disabled_ocr_options(),
  )
  match disabled_by_user {
    Err(msg) => {
      assert_true(msg.contains("OCR is disabled"))
      assert_true(msg.contains("png"))
    }
    Ok(_) => fail("disabled OCR image scaffold should stay fail closed")
  }

  let diagnostics = @focr.image_ocr_fail_closed_diagnostics(
    source,
    detected,
    @parser.default_ocr_options(),
  )
  assert_metric_eq(diagnostics, "ocr_candidate", "true")
  assert_metric_eq(diagnostics, "ocr_provider_wired", "false")
  assert_metric_eq(diagnostics, "provider_invoked", "false")
  assert_metric_eq(diagnostics, "effective_mode", "fail_closed")

  let explicit_diagnostics = @focr.image_ocr_fail_closed_diagnostics(
    source,
    detected,
    @parser.explicit_ocr_options(language=Some("eng")),
    requested_mode=Some(@parser.ParserMode::LayoutTwoStage),
  )
  assert_metric_eq(explicit_diagnostics, "ocr_intent", "explicit")
  assert_metric_eq(explicit_diagnostics, "ocr_language", "eng")
  assert_metric_eq(explicit_diagnostics, "ocr_provider_kind", "tesseract")
  assert_metric_eq(
    explicit_diagnostics, "ocr_provider_status", "not_configured",
  )
  assert_metric_eq(explicit_diagnostics, "effective_mode", "layout_two_stage")

  let disabled_diagnostics = @focr.image_ocr_fail_closed_diagnostics(
    source,
    detected,
    @parser.disabled_ocr_options(),
  )
  assert_metric_eq(disabled_diagnostics, "ocr_intent", "disabled")
  assert_metric_eq(
    disabled_diagnostics, "ocr_provider_status", "skipped_disabled",
  )
  assert_metric_eq(
    disabled_diagnostics, "effective_mode", "fail_closed_disabled",
  )
}

///|
test "pure tesseract tsv parser returns provider-independent OCR pages without enabling product OCR" {
  let tsv = [
    "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
    "5\t2\t1\t1\t1\t2\t30\t10\t10\t10\t92\tworld", "5\t1\t1\t1\t1\t1\t10\t20\t20\t10\t95\thello",
    "5\t2\t1\t1\t1\t1\t5\t10\t20\t10\t90\tmoonbit",
  ].join("\n")
  let result = match @focr.parse_tesseract_tsv(tsv, language=Some("eng")) {
    Ok(value) => value
    Err(err) => fail("expected pure TSV parser success: " + err.to_string())
  }
  assert_eq(result.provider_name, "tesseract")
  assert_true(result.provider_version == None)
  assert_eq(result.pages.length(), 2)
  assert_eq(result.pages[0].page_index, 0)
  assert_eq(result.pages[0].blocks[0].lines[0].text, "hello")
  assert_eq(result.pages[1].page_index, 1)
  assert_eq(result.pages[1].blocks[0].lines[0].text, "moonbit world")
  let provider = result.pages[1].provider.unwrap_or(
    @focr.make_ocr_provider_info("missing"),
  )
  assert_eq(provider.name, "tesseract")
  assert_true(provider.language == Some("eng"))

  let image = @input.input_from_path_with_format(
    "scan.png",
    Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
  )
  match
    @convert.convert_input(
      image,
      @convert.make_convert_options(
        @convert.ConvertMode::Balanced,
        @convert.OutputFormat::Markdown,
        Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
        @parser.explicit_ocr_options(),
        @convert.default_resource_limits(),
      ),
    ) {
    Err(@convert.ConvertError::ParseFailed(msg)) =>
      assert_true(msg.contains("not configured"))
    Err(other) =>
      fail("unexpected image OCR product-path error: " + other.to_string())
    Ok(_) => fail("pure TSV parser must not enable product OCR success path")
  }
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
test "convert explicit image OCR injected provider reaches root convert and render path" {
  let image = @input.input_from_path_with_format(
    "scan.png",
    Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
  )
  let converted = match
    @convert.convert_input_with_image_ocr_provider(
      image,
      @convert.make_convert_options(
        @convert.ConvertMode::Balanced,
        @convert.OutputFormat::Markdown,
        Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
        @parser.explicit_ocr_options(language=Some("eng")),
        @convert.default_resource_limits(),
      ),
      pipeline_fake_image_ocr_provider(Some("eng")),
    ) {
    Ok(value) => value
    Err(err) => fail("expected injected convert success: " + err.to_string())
  }
  assert_eq(converted.content, "MoonBit OCR\n\nSample 123")
  assert_true(
    converted.detected_format ==
    @input.DetectedFormat::Image(@input.ImageFormat::Png),
  )
  assert_true(converted.parser_mode == @parser.ParserMode::LayoutTwoStage)
  assert_metric_eq(converted.diagnostics, "ocr_provider_status", "success")
  assert_metric_eq(converted.diagnostics, "renderer_name", "MarkdownRenderer")
}

///|
async test "async convert explicit image OCR injected provider reaches root convert and render path" {
  let image = @input.input_from_path_with_format(
    "scan.png",
    Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
  )
  let converted = match
    @convert.convert_input_with_image_ocr_provider_async(
      image,
      @convert.make_convert_options(
        @convert.ConvertMode::Balanced,
        @convert.OutputFormat::Markdown,
        Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
        @parser.explicit_ocr_options(language=Some("eng")),
        @convert.default_resource_limits(),
      ),
      request => pipeline_fake_image_ocr_provider(Some("eng"))(request),
    ) {
    Ok(value) => value
    Err(err) =>
      fail("expected injected async convert success: " + err.to_string())
  }
  assert_eq(converted.content, "MoonBit OCR\n\nSample 123")
  assert_true(
    converted.detected_format ==
    @input.DetectedFormat::Image(@input.ImageFormat::Png),
  )
  assert_true(converted.parser_mode == @parser.ParserMode::LayoutTwoStage)
  assert_metric_eq(converted.diagnostics, "ocr_provider_status", "success")
  assert_metric_eq(converted.diagnostics, "renderer_name", "MarkdownRenderer")
}

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
    contains_trace_in_order(result.diagnostics.pass_trace, [
      "detect:", "registry:lookup", "parse:txt_parser", "builder:default_ir_builder",
      "NormalizeTextPass", "NormalizeWhitespacePass", "AssembleSectionTreePass",
      "DebugAnnotationPass", "render:MarkdownRenderer",
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
  let blocks = parsed.block_stream.unwrap_or([])
  assert_true(parsed.mode == @parser.ParserMode::BlockStreaming)
  assert_true(parsed.document is None)
  assert_true(parsed.event_stream is None)
  assert_true(blocks.length() >= 2)
  assert_true(blocks[0].source_ref is Some(_))
  let src = blocks[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(src.file_id == Some("demo.md"))
  assert_true(src.format == Some("markdown"))
  assert_true(src.line_start == Some(1))
  assert_true(src.line_end == Some(1))
  assert_true(src.markdown_path is Some(_))
  assert_metric_eq(parsed.diagnostics, "effective_mode", "block_streaming")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "markdown_block")
  assert_true(
    parsed.diagnostics.metrics.get("readiness_status") == Some("near_ready"),
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
    max_rows=Some(1),
  )
  assert_true(parsed.mode == @parser.ParserMode::StreamingEvent)
  assert_true(parsed.document is None)
  assert_true(parsed.block_stream is None)
  assert_true(parsed.event_stream is Some(_))
  assert_metric_eq(parsed.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "markdown_block")
  assert_metric_eq(
    parsed.diagnostics,
    "event_semantics",
    "markdown_block_event_stream",
  )
  assert_metric_eq(parsed.diagnostics, "streaming_fallback", "true")
  assert_metric_eq(parsed.diagnostics, "resource_limit_hit", "true")
  assert_metric_eq(parsed.diagnostics, "block_limit_reached", "true")
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "markdown_streaming_fallback=deferred", "large_markdown_raw_fallback",
  ])
  let events = parsed.event_stream.unwrap_or([])
  assert_true(events.length() > 0)
  let first = events[0].source_ref.unwrap_or(@core.empty_source_ref())
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
  let document = (@pipeline.default_ir_builder().build)(
    @core.IRInput::BlockStream(parsed.block_stream.unwrap_or([])),
  )
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
test "json large input switches to true streaming event path" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "{\"a\":1,\"b\":2}",
      "large.json",
      Some(@input.DetectedFormat::Json),
    ),
    @input.DetectedFormat::Json,
    max_rows=Some(0),
  )
  assert_true(parsed.mode == @parser.ParserMode::StreamingEvent)
  assert_true(parsed.document is None)
  assert_true(parsed.block_stream is None)
  assert_true(parsed.event_stream is Some(_))
  assert_metric_eq(parsed.diagnostics, "streaming_fallback", "true")
  assert_metric_eq(parsed.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(parsed.diagnostics, "dom_limit_reached", "true")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "json_structure")
  assert_metric_eq(
    parsed.diagnostics,
    "event_semantics",
    "json_structure_event_stream",
  )
  assert_metric_not_eq(parsed.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_not_eq(parsed.diagnostics, "streaming_fallback", "deferred")
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
  assert_metric_eq(parsed.diagnostics, "streaming_fallback", "false")
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
    max_rows=Some(1),
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
  assert_metric_eq(parsed.diagnostics, "streaming_fallback", "true")
  assert_metric_eq(parsed.diagnostics, "dom_limit_reached", "true")
  assert_metric_eq(parsed.diagnostics, "resource_limit_hit", "true")
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
  assert_metric_eq(parsed.diagnostics, "streaming_fallback", "false")
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
    max_rows=Some(1),
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
  assert_metric_eq(parsed.diagnostics, "streaming_fallback", "true")
  assert_metric_eq(parsed.diagnostics, "dom_limit_reached", "true")
  assert_metric_eq(parsed.diagnostics, "resource_limit_hit", "true")
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
  assert_metric_eq(parsed.diagnostics, "streaming_fallback", "false")
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
    max_rows=Some(1),
  )
  assert_true(parsed.mode == @parser.ParserMode::StreamingEvent)
  assert_true(parsed.document is None)
  assert_true(parsed.event_stream is Some(_))
  assert_metric_eq(parsed.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(
    parsed.diagnostics,
    "event_granularity",
    "html_token_structure",
  )
  assert_metric_eq(
    parsed.diagnostics,
    "event_semantics",
    "html_token_structure_event_stream",
  )
  assert_metric_eq(parsed.diagnostics, "streaming_fallback", "true")
  assert_metric_eq(parsed.diagnostics, "dom_limit_reached", "true")
  let events = parsed.event_stream.unwrap_or([])
  assert_true(events.length() > 0)
  let first = events[0].source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(first.format == Some("html"))
  assert_true(first.html_path is Some(_))
}

///|
test "html convert contract keeps dom and event paths renderer-aligned" {
  let small = convert_path(
    "samples/main_process/html/html_details_summary.html",
    format=Some(@input.DetectedFormat::Html),
  )
  let large_parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "<html><body><article><h1>Title</h1><p>Body</p></article></body></html>",
      "large.html",
      Some(@input.DetectedFormat::Html),
    ),
    @input.DetectedFormat::Html,
    max_rows=Some(1),
  )
  let large_events = large_parsed.event_stream.unwrap_or([])
  let large_document = (@pipeline.default_ir_builder().build)(
    @core.IRInput::EventStream(large_events),
  )
  let large_rendered = (@render.markdown_renderer().render)(
    large_document,
    @render.make_render_context(false),
  )
  assert_eq(small.content, "Open\n\nBody")
  assert_true(small.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(large_parsed.mode == @parser.ParserMode::StreamingEvent)
  assert_metric_eq(small.diagnostics, "builder_input_kind", "document")
  assert_metric_eq(
    large_parsed.diagnostics,
    "effective_mode",
    "streaming_event",
  )
  assert_metric_eq(large_parsed.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(
    large_parsed.diagnostics,
    "event_granularity",
    "html_token_structure",
  )
  assert_true(large_parsed.event_stream is Some(_))
  ignore(large_rendered)
}

///|
test "html parser contract preserves semantic behavior clusters and asset persistence" {
  let details = convert_path(
    "samples/main_process/html/html_details_summary.html",
    format=Some(@input.DetectedFormat::Html),
  )
  let nav = convert_path(
    "samples/main_process/html/html_semantic_containers.html",
    format=Some(@input.DetectedFormat::Html),
  )
  let list_quote = convert_path(
    "samples/main_process/html/html_listitem_with_blockquote.html",
    format=Some(@input.DetectedFormat::Html),
  )
  let blockquote = convert_path(
    "samples/main_process/html/html_blockquote_mixed_text_and_paragraph.html",
    format=Some(@input.DetectedFormat::Html),
  )
  let table = convert_path(
    "samples/main_process/html/html_br_table.html",
    format=Some(@input.DetectedFormat::Html),
  )
  let entities = convert_path(
    "samples/main_process/html/html_entities.html",
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
test "html parser keeps renderer boundary for link image table and br semantics" {
  let linked = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/html/html_link_in_paragraph.html",
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
    @input.input_from_path("samples/main_process/html/html_br_table.html"),
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
      "samples/main_process/docx/docx_table_merged_cells_boundary.docx",
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
      "samples/main_process/html/html_nested_list_mixed.html",
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
    "samples/main_process/html/expected/html_nested_list_mixed.md",
  )
  let html_deep_expected = read_utf8_text(
    "samples/main_process/html/expected/html_nested_lists_deep.md",
  )
  let docx_mixed_expected = read_utf8_text(
    "samples/main_process/docx/expected/docx_nested_lists_mixed.md",
  )
  assert_eq(
    html_mixed_rendered.content.trim().to_owned(),
    html_mixed_expected.trim().to_owned(),
  )

  let html_deep = convert_path(
    "samples/main_process/html/html_nested_lists_deep.html",
    format=Some(@input.DetectedFormat::Html),
  )
  assert_eq(
    html_deep.content.trim().to_owned(),
    html_deep_expected.trim().to_owned(),
  )

  let docx_mixed = convert_path(
    "samples/main_process/docx/docx_nested_lists_mixed.docx",
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
      "samples/main_process/html/html_link_unsafe_javascript.html",
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
  assert_true(
    parsed.diagnostics.metrics.get("streaming_fallback") == Some("false"),
  )
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
test "convert pipeline preserves exposed parser irinput contracts" {
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
  assert_true(yaml_large.parser_mode == @parser.ParserMode::StreamingEvent)
  assert_true(html_small.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(html_large.parser_mode == @parser.ParserMode::StreamingEvent)

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
  assert_metric_eq(yaml_large.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(yaml_large.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(yaml_large.diagnostics, "builder_input_kind", "event_stream")
  assert_metric_eq(html_small.diagnostics, "effective_mode", "dom_ast_model")
  assert_metric_eq(html_small.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(html_small.diagnostics, "builder_input_kind", "document")
  assert_metric_eq(html_large.diagnostics, "effective_mode", "streaming_event")
  assert_metric_eq(html_large.diagnostics, "ir_input_kind", "event_stream")
  assert_metric_eq(html_large.diagnostics, "builder_input_kind", "event_stream")
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
  let html = @parser.registry_lookup(registry, @input.DetectedFormat::Html).unwrap_or_else(fn() {
      abort("missing html parser")
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
  assert_true(html.capability.supports_streaming)
  assert_true(html.capability.parser_mode == @parser.ParserMode::DomAstModel)
  assert_true(html.capability.supports_document_ir)
  assert_true(html.capability.supports_events)
  assert_true(
    html.capability.streaming_granularity ==
    @parser.StreamingGranularity::HtmlTokenStructure,
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
test "renderer only consumes core ir and accepts irinput via builder" {
  let builder = @pipeline.default_ir_builder()
  let document = (builder.build)(
    @core.IRInput::BlockStream([
      @core.make_block(
        @core.BlockKind::Heading,
        "Title",
        source_ref=@core.empty_source_ref(),
      ),
      @core.make_block(
        @core.BlockKind::Paragraph,
        "Body",
        source_ref=@core.empty_source_ref(),
      ),
    ]),
  )
  let renderer = @render.markdown_renderer()
  let rendered = (renderer.render)(document, @render.make_render_context(false))
  assert_eq(rendered.content, "# Title\n\nBody")
  assert_true(
    rendered.diagnostics.metrics.get("renderer_name") ==
    Some("MarkdownRenderer"),
  )
}

///|
test "renderer does not over-escape hyphen inside heading text" {
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "a-first.md",
    source_ref=@core.empty_source_ref(),
  )
  heading.attrs.set("level", "1")
  let document = (@pipeline.default_ir_builder().build)(
    @core.IRInput::BlockStream([heading]),
  )
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_eq(rendered.content, "# a-first.md")
}

///|
test "renderer keeps plain exclamation while preserving inline link image and markdown escapes" {
  let paragraph = @core.block_with_rich_inlines(
    @core.make_block(
      @core.BlockKind::Paragraph,
      "unused",
      source_ref=@core.empty_source_ref(),
    ),
    Some([
      @core.make_inline_text("Hello! See "),
      @core.make_inline_link("spec", "https://example.com/spec"),
      @core.make_inline_text(" and "),
      @core.make_inline_image("diagram", "https://example.com/diagram.png"),
      @core.make_inline_text(" with [literal] <tag>"),
    ]),
  )
  let rendered = (@render.markdown_renderer().render)(
    @core.document_from_blocks([paragraph]),
    @render.make_render_context(false),
  )
  assert_eq(
    rendered.content,
    "Hello! See [spec](https://example.com/spec) and ![diagram](https://example.com/diagram.png) with \\[literal\\] \\<tag\\>",
  )
  assert_true(!rendered.content.contains("\\!"))
}

///|
test "renderer keeps declared table width when header row is narrower than body rows" {
  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=@core.empty_source_ref(),
  )
  table.attrs.set("header_rows", "1")
  table.attrs.set("table_column_count", "3")

  let header = @core.make_block(
    @core.BlockKind::TableRow,
    "",
    source_ref=@core.empty_source_ref(),
  )
  header.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "Merged Head",
      source_ref=@core.empty_source_ref(),
    ),
  )
  header.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "Right",
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
      "A",
      source_ref=@core.empty_source_ref(),
    ),
  )
  row.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "B",
      source_ref=@core.empty_source_ref(),
    ),
  )
  row.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "C",
      source_ref=@core.empty_source_ref(),
    ),
  )

  table.children.push(header)
  table.children.push(row)

  let rendered = (@render.markdown_renderer().render)(
    @core.document_from_blocks([table]),
    @render.make_render_context(false),
  )
  assert_eq(
    rendered.content,
    "| Merged Head | Right |\n| --- | --- |\n| A | B | C |",
  )
}

///|
test "generic block event stream preserves inline attrs for renderer contracts" {
  let marker = @core.inline_with_attr(
    @core.inline_with_attr(
      @core.inline_with_attr(
        @core.make_inline_text("[^1]", source_ref=@core.empty_source_ref()),
        "annotation_role",
        "note_ref",
      ),
      "annotation_kind",
      "footnote",
    ),
    "annotation_marker",
    "[^1]",
  )
  let marker = @core.inline_with_attr(marker, "render_literal", "true")
  let paragraph = @core.block_with_rich_inlines(
    @core.make_block(
      @core.BlockKind::Paragraph,
      "",
      source_ref=@core.empty_source_ref(),
    ),
    Some([@core.make_inline_text("Body"), marker]),
  )
  let events = @pipeline.blocks_to_event_stream([paragraph])
  let document = (@pipeline.default_ir_builder().build)(
    @core.IRInput::EventStream(events),
  )
  let inlines = document.blocks[0].rich_inlines.unwrap_or([])
  assert_eq(inlines.length(), 2)
  assert_true(inlines[1].attrs.get("annotation_role") == Some("note_ref"))
  assert_true(inlines[1].attrs.get("annotation_marker") == Some("[^1]"))
  assert_true(inlines[1].attrs.get("render_literal") == Some("true"))
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_eq(rendered.content, "Body[^1]")
}

///|
test "renderer keeps plain exclamation in literal markdown lines" {
  let paragraph = @core.make_block(
    @core.BlockKind::Paragraph,
    "paragraph!\n# heading!\n1. ordered!",
    source_ref=@core.empty_source_ref(),
  )
  let rendered = (@render.markdown_renderer().render)(
    @core.document_from_blocks([paragraph]),
    @render.make_render_context(false),
  )
  assert_eq(rendered.content, "paragraph! \\# heading! 1\\. ordered!")
  assert_true(!rendered.content.contains("\\!"))
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
test "container scaffold exposes explicit irinput and parser mode contracts without enabling runtime" {
  assert_true(
    @parser.mode_name(@parser.ParserMode::ContainerRecursive) ==
    "container_recursive",
  )

  let source_ref = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some("sample.zip"),
    Some("zip"),
    Some("sample.zip"),
    Some("docs/readme.md"),
    Some(0),
    Some("markdown"),
    Some("#/heading[0]"),
  )
  let entry = @core.make_container_entry(
    "docs/readme.md",
    @core.ContainerEntryKind::Document,
    normalized_path=Some("docs/readme.md"),
    entry_index=Some(0),
    detected_format=Some("markdown"),
    source_ref=Some(source_ref),
  )
  let diagnostics = @core.empty_diagnostics()
  diagnostics.metrics.set("parser_mode", "container_recursive")
  diagnostics.metrics.set("ir_input_kind", "container_manifest")
  diagnostics.metrics.set("event_granularity", "archive_entry")
  diagnostics.metrics.set("container_entry_count", "1")
  diagnostics.metrics.set("selected_entry_count", "1")
  diagnostics.metrics.set("skipped_entry_count", "0")
  diagnostics.metrics.set("manifest_seen", "true")
  let manifest = @core.make_container_manifest(
    "zip",
    [entry],
    container_path=Some("sample.zip"),
    selected_entries=[entry],
    diagnostics~,
    source_ref=Some(source_ref),
  )
  let builder = @pipeline.default_ir_builder()
  let document = (builder.build)(@core.IRInput::ContainerManifest(manifest))
  assert_true(
    document.diagnostics.metrics.get("builder_input_kind") ==
    Some("container_manifest"),
  )
  assert_true(
    document.diagnostics.metrics.get("ir_input_kind") ==
    Some("container_manifest"),
  )
  assert_true(
    document.metadata.get("container_format") ==
    Some(@core.JsonValue::String("zip")),
  )
  assert_true(
    document.metadata.get("container_entry_count") ==
    Some(@core.JsonValue::Number("1")),
  )
}

///|
test "container plan scaffold keeps asset and inner document contracts explicit" {
  let source_ref = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some("book.epub"),
    Some("epub"),
    Some("book.epub"),
    Some("OEBPS/chapter1.xhtml"),
    Some(3),
    Some("html"),
    Some("/html/body/h1"),
  )
  let entry = @core.make_container_entry(
    "OEBPS/chapter1.xhtml",
    @core.ContainerEntryKind::Document,
    normalized_path=Some("OEBPS/chapter1.xhtml"),
    entry_index=Some(3),
    detected_format=Some("html"),
    media_type=Some("application/xhtml+xml"),
    source_ref=Some(source_ref),
  )
  let inner = @core.make_container_inner_document(
    entry,
    "book.epub::OEBPS/chapter1.xhtml",
    explicit_detected_format=Some("html"),
    inner_source_ref=Some(source_ref),
  )
  let asset = @core.make_container_asset_plan(
    "OEBPS/images/cover.jpg",
    "assets/cover.jpg",
    media_type=Some("image/jpeg"),
    size=Some(12),
    copy_policy=@core.ContainerAssetCopyPolicy::MaterializeAtOutputBoundary,
    source_ref=Some(
      @core.source_ref_with_container_entry(
        @core.empty_source_ref(),
        Some("book.epub"),
        Some("epub"),
        Some("book.epub"),
        Some("OEBPS/images/cover.jpg"),
        Some(7),
        Some("binary"),
        None,
      ),
    ),
  )
  let diagnostics = @core.empty_diagnostics()
  diagnostics.metrics.set("parser_mode", "container_recursive")
  diagnostics.metrics.set("ir_input_kind", "container_plan")
  diagnostics.metrics.set("event_granularity", "epub_spine_item")
  diagnostics.metrics.set("container_entry_count", "2")
  diagnostics.metrics.set("selected_entry_count", "1")
  diagnostics.metrics.set("asset_count", "1")
  diagnostics.metrics.set("spine_item_count", "1")
  diagnostics.metrics.set("nav_seen", "true")
  let plan = @core.make_container_plan(
    "epub",
    [entry],
    [inner],
    [asset],
    container_path=Some("book.epub"),
    diagnostics~,
    source_ref=Some(source_ref),
  )
  let document = (@pipeline.default_ir_builder().build)(
    @core.IRInput::ContainerPlan(plan),
  )
  assert_true(
    document.diagnostics.metrics.get("builder_input_kind") ==
    Some("container_plan"),
  )
  assert_true(
    document.metadata.get("asset_plan_count") ==
    Some(@core.JsonValue::Number("1")),
  )
  assert_true(
    @core.container_asset_copy_policy_name(asset.copy_policy) ==
    "materialize_at_output_boundary",
  )
}

///|
test "debug mode emits diagnostics parser metadata and pass trace" {
  let result = convert_memory_text(
    "Alpha\n\nBeta",
    "debug.txt",
    @input.DetectedFormat::Txt,
    mode=@convert.ConvertMode::Debug,
    output=@convert.OutputFormat::DebugJson,
  )
  assert_true(result.content.contains("\"diagnostics\""))
  assert_true(result.content.contains("\"parser_name\""))
  assert_true(result.content.contains("\"fallback_trace\""))
  assert_true(result.content.contains("\"pass_trace\""))
  assert_true(result.content.contains("\"source_ref\""))
  assert_true(result.diagnostics.convert_mode == Some("debug"))
  assert_true(
    result.diagnostics.metrics.get("renderer_name") == Some("DebugJsonRenderer"),
  )
}

///|
test "debug json source ref serialization keeps json xpath and yaml path fields visible" {
  let json = convert_memory_text(
    "{\"name\":\"Alice\"}\n",
    "debug.json",
    @input.DetectedFormat::Json,
    mode=@convert.ConvertMode::Debug,
    output=@convert.OutputFormat::DebugJson,
  )
  let xml = convert_memory_text(
    "<root><item>Hello</item></root>\n",
    "debug.xml",
    @input.DetectedFormat::Xml,
    mode=@convert.ConvertMode::Debug,
    output=@convert.OutputFormat::DebugJson,
  )
  let yaml = convert_memory_text(
    "name: Alice\nrole: Engineer\n",
    "debug.yaml",
    @input.DetectedFormat::Yaml,
    mode=@convert.ConvertMode::Debug,
    output=@convert.OutputFormat::DebugJson,
  )
  let markdown = convert_memory_text(
    "# Title\n\nBody\n",
    "debug.md",
    @input.DetectedFormat::Markdown,
    mode=@convert.ConvertMode::Debug,
    output=@convert.OutputFormat::DebugJson,
  )
  assert_true(json.content.contains("\"json_pointer\": \"/\""))
  assert_true(json.content.contains("\"xpath\": null"))
  assert_true(json.content.contains("\"yaml_path\": null"))
  assert_true(xml.content.contains("\"xpath\": \"/root\""))
  assert_true(xml.content.contains("\"json_pointer\": null"))
  assert_true(xml.content.contains("\"yaml_path\": null"))
  assert_true(yaml.content.contains("\"yaml_path\": \"/\""))
  assert_true(yaml.content.contains("\"json_pointer\": null"))
  assert_true(yaml.content.contains("\"xpath\": null"))
  assert_true(markdown.content.contains("\"markdown_path\": \"/heading[0]\""))
  assert_true(markdown.content.contains("\"yaml_path\": null"))
  assert_true(markdown.content.contains("\"xpath\": null"))
}

///|
test "debug json source ref serialization keeps office scaffold fields visible" {
  let source_ref = @core.source_ref_with_office_fields(
    @core.source_ref_with_container_entry(
      @core.empty_source_ref(),
      Some("sample.docx"),
      Some("docx"),
      Some("sample.docx"),
      Some("word/document.xml"),
      Some(0),
      Some("docx"),
      Some("/w:document/w:body/w:p[3]"),
    ),
    Some("sample.docx"),
    Some("docx"),
    Some("/w:document/w:body/w:p[3]"),
    Some("Sheet A"),
    Some("B7:C9"),
    Some(2),
    Some("shape-4"),
    Some("rId5"),
  )
  let with_extra = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(
            source_ref, "ooxml_part_type", "main_document",
          ),
          "part_name",
          "word/document.xml",
        ),
        "relationship_type",
        "image",
      ),
      "sheet_name",
      "Sheet A",
    ),
    "paragraph_index",
    "3",
  )
  let block = @core.make_block(
    @core.BlockKind::Paragraph,
    "Docx scaffold",
    source_ref=with_extra,
  )
  let document = @core.document_from_blocks([block])
  let rendered = (@render.debug_json_renderer().render)(
    document,
    @render.make_render_context(true),
  )
  assert_true(
    rendered.content.contains("\"inner_path\": \"/w:document/w:body/w:p[3]\""),
  )
  assert_true(rendered.content.contains("\"sheet\": \"Sheet A\""))
  assert_true(rendered.content.contains("\"cell_range\": \"B7:C9\""))
  assert_true(rendered.content.contains("\"slide\": 2"))
  assert_true(rendered.content.contains("\"shape_id\": \"shape-4\""))
  assert_true(rendered.content.contains("\"relationship_id\": \"rId5\""))
  assert_true(
    rendered.content.contains("\"ooxml_part_type\": \"main_document\""),
  )
  assert_true(rendered.content.contains("\"part_name\": \"word/document.xml\""))
  assert_true(rendered.content.contains("\"relationship_type\": \"image\""))
  assert_true(rendered.content.contains("\"sheet_name\": \"Sheet A\""))
  assert_true(rendered.content.contains("\"paragraph_index\": \"3\""))
}

///|
test "debug json source ref serialization keeps container fields visible" {
  let source_ref = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some("sample.zip"),
    Some("zip"),
    Some("sample.zip"),
    Some("docs/readme.md"),
    Some(4),
    Some("markdown"),
    Some("#/heading[0]"),
  )
  let block = @core.make_block(
    @core.BlockKind::Paragraph,
    "Entry text",
    source_ref~,
  )
  let document = @core.document_from_blocks([block])
  let rendered = (@render.debug_json_renderer().render)(
    document,
    @render.make_render_context(true),
  )
  assert_contains_all(rendered.content, [
    "\"container_path\": \"sample.zip\"", "\"entry_path\": \"docs/readme.md\"", "\"entry_index\": 4",
    "\"entry_format\": \"markdown\"", "\"inner_path\": \"#/heading[0]\"",
  ])
}

///|
test "container contract helper keeps inner dispatch on the root pipeline and bounded" {
  let supported = @container.container_supported_inner_formats()
  assert_true(
    supported ==
    [
      "txt", "csv", "tsv", "json", "jsonl", "ndjson", "xml", "yaml", "yml", "html",
      "htm", "markdown", "md", "epub",
    ],
  )
  assert_true(
    @container.container_supports_inner_format(@input.DetectedFormat::Txt),
  )
  assert_true(
    @container.container_supports_inner_format(@input.DetectedFormat::Markdown),
  )
  assert_true(
    !@container.container_unsupported_inner_formats().contains("html"),
  )
  assert_contains_all(@container.container_dispatch_guardrails().join("\n"), [
    "root ParserRegistry / root pipeline", "no legacy dispatcher", "no convert/html",
    "no convert/markdown", "no convert/zip", "no convert/epub", "no old core",
  ])
}

///|
test "container asset boundary helper rejects unsafe output paths" {
  let safe_plan = @core.make_container_asset_plan(
    "images/cover.jpg",
    "assets/cover.jpg",
    copy_policy=@core.ContainerAssetCopyPolicy::MaterializeAtOutputBoundary,
  )
  let traversal_plan = @core.make_container_asset_plan(
    "images/cover.jpg",
    "../cover.jpg",
    copy_policy=@core.ContainerAssetCopyPolicy::RejectUnsafePath,
  )
  let absolute_plan = @core.make_container_asset_plan(
    "images/cover.jpg",
    "/tmp/cover.jpg",
    copy_policy=@core.ContainerAssetCopyPolicy::RejectUnsafePath,
  )
  assert_true(@container.container_asset_plan_is_safe(safe_plan))
  assert_true(!@container.container_asset_plan_is_safe(traversal_plan))
  assert_true(!@container.container_asset_plan_is_safe(absolute_plan))
  assert_contains_all(
    @container.container_asset_write_guardrails().join("\n"),
    [
      "actual file writes only happen at the CLI/output boundary", "no parser/orchestrator file writes",
      "no external fetch", "no path traversal",
    ],
  )
}

///|
test "office shared scaffold models and guardrails stay root-pipeline only" {
  let rel_src = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("sample.docx"),
    Some("docx"),
    Some("/w:document/w:body/w:p[1]"),
    None,
    None,
    None,
    None,
    Some("rIdMain"),
  )
  let rel = @shared.make_office_relationship(
    "word/document.xml",
    "rIdExt",
    "image",
    "https://example.com/image.png",
    target_mode="External",
    is_external=true,
    source_ref=Some(rel_src),
    security_findings=[@shared.OfficeSecurityFinding::ExternalRelationship],
  )
  let part = @shared.make_office_part(
    "word/document.xml",
    normalized_part_name=Some("word/document.xml"),
    content_type=Some(
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
    ),
    source_ref=Some(rel_src),
  )
  let content_type = @shared.make_office_content_type(
    "application/xml",
    extension=Some("xml"),
  )
  let media = @shared.make_office_media_asset(
    "word/media/image1.png",
    content_type=Some("image/png"),
    relationship_id=Some("rIdImg"),
    source_part=Some("word/document.xml"),
    size=Some(128),
    source_ref=Some(rel_src),
  )
  let diagnostics = @core.empty_diagnostics()
  diagnostics.metrics.set("office_document_kind", "docx")
  diagnostics.metrics.set("relationship_count", "1")
  let pkg = @shared.make_office_package(
    @shared.OfficeDocumentKind::Docx,
    [part],
    [rel],
    [content_type],
    [media],
    container_path=Some("sample.docx"),
    source_id=Some("sample.docx"),
    diagnostics~,
    source_ref=Some(rel_src),
  )
  let asset_plan = @shared.make_office_asset_plan(
    "word/media/image1.png",
    "assets/docx/image01.png",
    source_ref=Some(rel_src),
  )
  let plan = @shared.make_office_semantic_plan(
    @shared.OfficeDocumentKind::Docx,
    pkg,
    "document_model",
    ["paragraph:0", "table:1"],
    [asset_plan],
    diagnostics~,
  )
  assert_true(@shared.office_document_kind_name(plan.document_kind) == "docx")
  assert_true(@shared.office_relationship_is_no_fetch(rel))
  assert_true(@shared.office_asset_plan_is_safe(asset_plan))
  assert_true(!@shared.office_asset_output_path_is_safe("../unsafe/image.png"))
  assert_true(
    @shared.office_relationship_guardrails().contains(
      "TargetMode=External is no-fetch",
    ),
  )
  assert_true(
    @shared.office_asset_write_guardrails().contains(
      "asset writes only happen at the CLI/output boundary",
    ),
  )
  assert_true(
    @shared.office_source_ref_extra_keys().contains("relationship_id"),
  )
  assert_true(
    @shared.office_source_ref_extra_keys().contains("paragraph_index"),
  )
  assert_true(
    @shared.office_diagnostic_metric_keys().contains("office_document_kind"),
  )
  assert_true(
    @shared.office_diagnostic_metric_keys().contains("alt_chunk_count"),
  )
  assert_true(
    @shared.office_diagnostic_metric_keys().contains("docx_hyperlink_count"),
  )
  assert_true(
    @shared.office_diagnostic_metric_keys().contains("fallback_count"),
  )
  assert_true(@shared.office_resource_limit_keys().contains("max_ooxml_parts"))
  assert_true(plan.office_package.parts.length() == 1)
  assert_true(plan.office_package.relationships.length() == 1)
  assert_true(plan.asset_plans.length() == 1)
}

///|
test "office parser modes and granularities exist only as scaffold contracts" {
  let modes = @shared.office_parser_modes()
  assert_true(modes.contains(@parser.ParserMode::DocumentModel))
  assert_true(modes.contains(@parser.ParserMode::PresentationModel))
  assert_true(modes.contains(@parser.ParserMode::WorkbookModel))
  let granularities = @shared.office_streaming_granularities()
  assert_true(granularities.contains(@parser.StreamingGranularity::DocxBlock))
  assert_true(granularities.contains(@parser.StreamingGranularity::PptxSlide))
  assert_true(granularities.contains(@parser.StreamingGranularity::XlsxSheet))
  assert_true(granularities.contains(@parser.StreamingGranularity::XlsxRow))
}

///|
test "docx parser is product exposure and avoids legacy imports" {
  let contract = @fdocx.docx_parser()
  let context = @parser.new_parse_context(@input.DetectedFormat::Docx)
  let result = match
    (contract.parse)(
      @input.input_from_path(
        "samples/main_process/docx/docx_multiple_notes_order.docx",
      ),
      context,
    ) {
    Ok(value) => value
    Err(msg) =>
      fail("docx parser should return root-pipeline parse result: " + msg)
  }
  assert_true(contract.name == "docx_parser")
  assert_true(contract.mode == @parser.ParserMode::DocumentModel)
  assert_true(
    contract.capability.streaming_granularity ==
    @parser.StreamingGranularity::DocxBlock,
  )
  assert_true(result.document is Some(_))
  assert_true(result.event_stream is None)
  assert_true(result.block_stream is None)
  let document = result.document.unwrap_or_else(fn() {
    abort("missing docx document")
  })
  assert_true(document.blocks.length() > 0)
  assert_true(
    result.diagnostics.metrics.get("ir_input_kind") == Some("document"),
  )
  assert_true(
    result.diagnostics.metrics.get("event_granularity") == Some("docx_block"),
  )
  assert_true(result.diagnostics.metrics.get("runtime_exposed") == Some("true"))
  assert_true(
    result.diagnostics.metrics.get("effective_mode") == Some("document_model"),
  )
  assert_true(
    result.diagnostics.metrics.get("parser_name") == Some("docx_parser"),
  )
  assert_true(
    result.diagnostics.metrics.get("office_document_kind") == Some("docx"),
  )
  assert_true(
    result.diagnostics.metrics.get("legacy_convert_dependency") == Some("none"),
  )
  assert_true(
    result.diagnostics.metrics.get("legacy_runtime_dependency") == Some("none"),
  )
  assert_true(
    result.diagnostics.metrics.get("legacy_fallback") == Some("forbidden"),
  )
  let registry_source = read_utf8_text("formats/registry.mbt")
  assert_true(registry_source.contains("DetectedFormat::Docx"))
  assert_true(registry_source.contains("docx_parser()"))
  assert_true(registry_source.contains("DetectedFormat::Xlsx"))
  assert_true(registry_source.contains("xlsx_parser()"))
  assert_true(!registry_source.contains("docx_parser_contract()"))
  let formats_pkg = read_utf8_text("formats/moon.pkg")
  let office_pkg = read_utf8_text("format_readers/ooxml/shared/moon.pkg")
  let office_impl = read_utf8_text("format_readers/ooxml/shared/shared.mbt")
  let docx_impl = read_utf8_text("formats/docx/parser.mbt")
  assert_contains_none(formats_pkg, [
    "ZSeanYves/markitdown/convert/docx", "ZSeanYves/markitdown/convert/docx_v2",
    "ZSeanYves/markitdown/unmigrated/",
  ])
  assert_contains_none(office_pkg, [
    "ZSeanYves/markitdown/convert/", "ZSeanYves/markitdown/unmigrated/",
  ])
  assert_contains_none(office_impl, [
    "ZSeanYves/markitdown/convert/", "ZSeanYves/markitdown/unmigrated/", "@legacy",
  ])
  assert_contains_none(docx_impl, [
    "convert/docx", "convert/docx_v2", "@legacy", "emitter_markdown", "legacy_dispatcher",
  ])
  assert_diagnostics_lists_contain_none(result.diagnostics, [
    "docx_raw_fallback", "docx_legacy_fallback", "legacy_dispatcher_used", "convert_docx_used",
    "convert_docx_v2_used",
  ])
}

///|
test "docx parser keeps note ordering and code blocks on the root pipeline" {
  let notes = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/docx/docx_multiple_notes_order.docx",
    ),
    @input.DetectedFormat::Docx,
  )
  let note_document = notes.document.unwrap_or_else(fn() {
    abort("missing note-order document")
  })
  let note_rendered = (@render.markdown_renderer().render)(
    note_document,
    @render.make_render_context(false),
  )
  assert_true(
    note_rendered.content.contains("First reference[^1] then second [^2]"),
  )
  assert_true(note_rendered.content.contains("Comment here [comment 1]"))
  assert_true(note_rendered.content.contains("Endnote here[^e1]"))
  assert_exact_count(note_rendered.content, "[comment 1]", 1)
  assert_exact_count(note_rendered.content, "[^e1]", 2)
  match note_rendered.content.split_once("[^1]: Second footnote body.") {
    Some((_, tail)) => assert_true(tail.contains("[^2]: First footnote body."))
    None => fail("docx note definition order should contain [^1] before [^2]")
  }

  let code = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/docx/docx_codeblock_basic.docx",
    ),
    @input.DetectedFormat::Docx,
  )
  let code_document = code.document.unwrap_or_else(fn() {
    abort("missing code document")
  })
  assert_true(code_document.blocks.length() == 1)
  assert_true(code_document.blocks[0].kind == @core.BlockKind::Code)
  assert_eq(code_document.blocks[0].text, "let x = 1\nprintln(x)")
}

///|
test "docx parser keeps note comment boundary spacing without duplicating markers" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/docx/docx_note_comment_rich_content_boundary.docx",
    ),
    @input.DetectedFormat::Docx,
  )
  let document = parsed.document.unwrap_or_else(fn() {
    abort("missing note-comment boundary document")
  })
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(rendered.content.contains("Body[^1]  [comment 1]"))
  assert_contains_none(rendered.content, [
    "[^1][^1]", "[^e1][^e1]", "[comment 1][comment 1]",
  ])
  assert_exact_count(rendered.content, "[comment 1]", 1)
  assert_exact_count(rendered.content, "[^1]", 2)
}

///|
test "docx contract guardrails and helper remain aligned with product runtime" {
  assert_eq(@shared.docx_contract_parser_name(), "docx_parser_contract")
  assert_true(@shared.docx_contract_mode() == @parser.ParserMode::DocumentModel)
  assert_true(
    @shared.docx_contract_granularity() ==
    @parser.StreamingGranularity::DocxBlock,
  )
  assert_eq(@shared.docx_contract_ir_input_kind(), "document")
  assert_true(
    @shared.docx_contract_foundations() ==
    ["format_readers/ooxml/docx", "format_readers/ooxml/package"],
  )
  assert_contains_all(@shared.docx_contract_guardrails().join("\n"), [
    "DOCX is restored on the current main CLI", "DocumentModel / IRInput::Document / docx_block",
    "format_readers/ooxml/package + format_readers/ooxml/docx foundation", "no old core",
    "no legacy convert", "no markdown emitter", "no main CLI fallback", "assets stay output-boundary only",
  ])
  let helper = @formats_root.docx_parser_contract()
  let helper_result = match
    (helper.parse)(
      @input.input_from_path(
        "samples/main_process/docx/docx_multiple_notes_order.docx",
      ),
      @parser.new_parse_context(@input.DetectedFormat::Docx),
    ) {
    Ok(value) => value
    Err(msg) => fail("docx contract helper should produce diagnostics: " + msg)
  }
  assert_true(helper_result.document is Some(_))
  assert_metric_eq(helper_result.diagnostics, "runtime_exposed", "true")
  assert_metric_eq(
    helper_result.diagnostics,
    "effective_mode",
    "document_model",
  )
  assert_metric_eq(helper_result.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(helper_result.diagnostics, "event_granularity", "docx_block")
  assert_true(
    helper_result.diagnostics.degraded_features.contains(
      "docx_contract_helper_only",
    ),
  )
  assert_true(helper_result.diagnostics.errors.length() == 0)
  assert_true(helper_result.diagnostics.warnings.length() == 1)
  assert_true(
    helper_result.diagnostics.warnings[0].contains(
      "mirrors the DOCX product boundary",
    ),
  )
}

///|
test "docx parser diagnostics source refs and renderer boundary stay contract locked" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/docx/docx_image_alt_title.docx",
    ),
    @input.DetectedFormat::Docx,
  )
  assert_metric_eq(parsed.diagnostics, "effective_mode", "document_model")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "docx_block")
  assert_metric_eq(parsed.diagnostics, "office_document_kind", "docx")
  assert_metric_eq(parsed.diagnostics, "runtime_exposed", "true")
  assert_true(parsed.diagnostics.metrics.get("ooxml_part_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("relationship_count") is Some(_))
  assert_true(
    parsed.diagnostics.metrics.get("external_relationship_count") is Some(_),
  )
  assert_true(
    parsed.diagnostics.metrics.get("missing_relationship_target_count")
    is Some(_),
  )
  assert_true(
    parsed.diagnostics.metrics.get("unsupported_relationship_count") is Some(_),
  )
  assert_true(parsed.diagnostics.metrics.get("media_asset_count") is Some(_))
  assert_true(
    parsed.diagnostics.metrics.get("materialized_asset_count") is Some(_),
  )
  assert_true(parsed.diagnostics.metrics.get("skipped_asset_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("content_type_count") is Some(_))
  assert_true(
    parsed.diagnostics.metrics.get("total_uncompressed_bytes") is Some(_),
  )
  assert_true(parsed.diagnostics.metrics.get("path_traversal_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("duplicate_part_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("xml_dtd_count") is Some(_))
  assert_true(
    parsed.diagnostics.metrics.get("xml_external_entity_count") is Some(_),
  )
  assert_true(parsed.diagnostics.metrics.get("macro_part_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("ole_object_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("alt_chunk_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("docx_paragraph_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("docx_heading_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("docx_table_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("docx_list_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("docx_image_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("docx_hyperlink_count") is Some(_))
  assert_true(
    parsed.diagnostics.metrics.get("docx_header_footer_count") is Some(_),
  )
  assert_true(parsed.diagnostics.metrics.get("docx_comment_count") is Some(_))
  assert_true(
    parsed.diagnostics.metrics.get("docx_tracked_change_count") is Some(_),
  )
  assert_true(parsed.diagnostics.pass_trace.contains("parse:docx_parser"))
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "docx_raw_fallback", "docx_legacy_fallback", "legacy_dispatcher_used", "convert_docx_used",
    "convert_docx_v2_used",
  ])
  let document = parsed.document.unwrap_or_else(fn() {
    abort("missing docx document")
  })
  assert_true(document.blocks.length() > 0)
  let image = document.blocks[0]
  assert_true(image.kind == @core.BlockKind::Image)
  let image_ref = image.source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(image_ref.format == Some("docx"))
  assert_true(image_ref.container_path is Some(_))
  assert_true(image_ref.entry_path is Some(_))
  assert_true(image_ref.inner_path is Some(_))
  match image_ref.extra.get("part_name") {
    Some(value) => assert_eq(value, "word/document.xml")
    None => fail("docx image source ref should keep part_name")
  }
  match image_ref.extra.get("paragraph_index") {
    Some(_) => ()
    None => fail("docx image source ref should keep paragraph_index")
  }
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(
    rendered.content.contains("![Figure alt text](assets/image01.png)"),
  )
  assert_true(rendered.content.contains("*Figure title text*"))

  let headings = default_registry_parse(
    @input.input_from_path("samples/main_process/docx/docx_heading_levels.docx"),
    @input.DetectedFormat::Docx,
  )
  let heading_document = headings.document.unwrap_or_else(fn() {
    abort("missing heading document")
  })
  assert_true(heading_document.blocks.length() > 0)
  let heading = heading_document.blocks[0]
  assert_true(heading.kind == @core.BlockKind::Heading)
  assert_true(!heading.text.contains("# "))
  let heading_rendered = (@render.markdown_renderer().render)(
    heading_document,
    @render.make_render_context(false),
  )
  assert_true(heading_rendered.content.contains("# Heading Level 1"))
}

///|
test "pptx scaffold models and guardrails stay contract-locked after runtime restore" {
  let slide_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(
            @core.source_ref_with_extra(
              @core.source_ref_with_extra(
                @core.source_ref_with_office_fields(
                  @core.source_ref_with_container_entry(
                    @core.empty_source_ref(),
                    Some("deck.pptx"),
                    Some("pptx"),
                    Some("deck.pptx"),
                    Some("ppt/slides/slide2.xml"),
                    Some(1),
                    Some("pptx"),
                    Some("/p:sld/p:cSld/p:spTree/p:sp[3]"),
                  ),
                  Some("deck.pptx"),
                  Some("pptx"),
                  Some("/p:sld/p:cSld/p:spTree/p:sp[3]"),
                  None,
                  None,
                  Some(2),
                  Some("shape-3"),
                  Some("rIdSlide2"),
                ),
                "slide_index",
                "2",
              ),
              "slide_id",
              "257",
            ),
            "slide_part",
            "ppt/slides/slide2.xml",
          ),
          "layout_part",
          "ppt/slideLayouts/slideLayout3.xml",
        ),
        "master_part",
        "ppt/slideMasters/slideMaster1.xml",
      ),
      "theme_part",
      "ppt/theme/theme1.xml",
    ),
    "shape_name",
    "Agenda Body",
  )
  let placeholder_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(slide_ref, "placeholder_type", "body"),
      "placeholder_idx",
      "1",
    ),
    "shape_type",
    "body",
  )
  let run = @shared.make_pptx_text_run_model(
    "Quarterly review",
    relationship_id=Some("rIdHyper1"),
    source_ref=Some(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(placeholder_ref, "paragraph_index", "0"),
        "run_index",
        "0",
      ),
    ),
  )
  let para = @shared.make_pptx_paragraph_model(
    0,
    [run],
    level=Some(0),
    bullet_kind=Some("unordered"),
    source_ref=Some(
      @core.source_ref_with_extra(placeholder_ref, "paragraph_index", "0"),
    ),
  )
  let table = @shared.make_pptx_table_model([
    @shared.make_pptx_table_row_model(0, [
      @shared.make_pptx_table_cell_model(
        0,
        0,
        "North",
        source_ref=Some(
          @core.source_ref_with_extra(placeholder_ref, "shape_type", "table"),
        ),
      ),
      @shared.make_pptx_table_cell_model(0, 1, "42"),
    ]),
  ])
  let image = @shared.make_pptx_image_model(
    asset_part=Some("ppt/media/image1.png"),
    content_type=Some("image/png"),
    alt_text=Some("Trend chart"),
    title=Some("Trend"),
    relationship_id=Some("rIdImage1"),
    source_ref=Some(slide_ref),
  )
  let placeholder = @shared.make_pptx_placeholder_model(
    "body",
    placeholder_index=Some("1"),
    placeholder_name=Some("Body Placeholder"),
    resolved_from=@shared.PptxPlaceholderOrigin::LayoutPlaceholder,
    source_ref=Some(placeholder_ref),
  )
  let shape = @shared.make_pptx_shape_model(
    @shared.PptxShapeType::Body,
    text_paragraphs=[para],
    shape_id=Some("shape-3"),
    shape_name=Some("Agenda Body"),
    bbox=Some({ x0: 10.0, y0: 20.0, x1: 200.0, y1: 120.0 }),
    table=Some(table),
    image=Some(image),
    placeholder=Some(placeholder),
    source_ref=Some(placeholder_ref),
  )
  let notes = @shared.make_pptx_notes_model(
    ["speaker note"],
    notes_part=Some("ppt/notesSlides/notesSlide2.xml"),
    source_ref=Some(
      @core.source_ref_with_extra(
        slide_ref, "notes_part", "ppt/notesSlides/notesSlide2.xml",
      ),
    ),
  )
  let comment = @shared.make_pptx_comment_model(
    "comment-7",
    "Move this bullet higher",
    author=Some("reviewer"),
    source_ref=Some(
      @core.source_ref_with_extra(slide_ref, "comment_id", "comment-7"),
    ),
  )
  let order = @shared.make_pptx_reading_order_item(
    0,
    2,
    @shared.PptxReadingOrderStrategy::PlaceholderThenGeometry,
    shape_id=Some("shape-3"),
    confidence=Some("high"),
    source_ref=Some(
      @core.source_ref_with_extra(slide_ref, "reading_order_index", "0"),
    ),
  )
  let slide = @shared.make_pptx_slide_model(
    2,
    [shape],
    slide_id=Some("257"),
    slide_part=Some("ppt/slides/slide2.xml"),
    visibility=@shared.PptxSlideVisibility::Hidden,
    layout_part=Some("ppt/slideLayouts/slideLayout3.xml"),
    master_part=Some("ppt/slideMasters/slideMaster1.xml"),
    theme_part=Some("ppt/theme/theme1.xml"),
    notes=Some(notes),
    comments=[comment],
    reading_order=[order],
    source_ref=Some(slide_ref),
  )
  let presentation = @shared.make_pptx_presentation_model(
    [slide],
    themes=[
      @shared.make_pptx_theme_model(
        theme_name=Some("Office Theme"),
        part_name=Some("ppt/theme/theme1.xml"),
      ),
    ],
    masters=[
      @shared.make_pptx_master_model(
        master_name=Some("Master 1"),
        part_name=Some("ppt/slideMasters/slideMaster1.xml"),
        theme_part=Some("ppt/theme/theme1.xml"),
        placeholder_count=4,
      ),
    ],
    layouts=[
      @shared.make_pptx_layout_model(
        layout_name=Some("Title and Content"),
        part_name=Some("ppt/slideLayouts/slideLayout3.xml"),
        master_part=Some("ppt/slideMasters/slideMaster1.xml"),
        theme_part=Some("ppt/theme/theme1.xml"),
        placeholder_count=2,
      ),
    ],
  )
  let plan = @shared.make_pptx_presentation_plan(presentation, ["257"], hidden_slide_ids=[
    "257",
  ])
  assert_true(
    @shared.office_document_kind_name(@shared.OfficeDocumentKind::Pptx) ==
    "pptx",
  )
  assert_true(@shared.pptx_slide_visibility_name(slide.visibility) == "hidden")
  assert_true(@shared.pptx_shape_type_name(shape.shape_type) == "body")
  assert_true(
    @shared.pptx_placeholder_origin_name(placeholder.resolved_from) ==
    "layout_placeholder",
  )
  assert_true(
    @shared.pptx_reading_order_strategy_name(order.strategy) ==
    "placeholder_then_geometry",
  )
  assert_true(plan.presentation.slides.length() == 1)
  assert_true(plan.ordered_slide_ids == ["257"])
  assert_true(plan.hidden_slide_ids == ["257"])
  assert_true(slide.comments.length() == 1)
  assert_true(slide.reading_order.length() == 1)
  assert_true(shape.table is Some(_))
  assert_true(shape.image is Some(_))
  assert_true(shape.placeholder is Some(_))
  match shape.placeholder {
    Some(value) => {
      assert_eq(value.placeholder_type, "body")
      assert_true(value.placeholder_index == Some("1"))
    }
    None => fail("pptx scaffold shape should keep placeholder contract")
  }
  assert_contains_all(@shared.pptx_contract_guardrails().join("\n"), [
    "PPTX is restored on the current main CLI", "PresentationModel / IRInput::Document / pptx_slide",
    "format_readers/ooxml/package + format_readers/ooxml/pptx foundation", "no old core",
    "no legacy convert", "no markdown emitter", "no main CLI fallback", "slide order follows presentation.xml",
    "placeholder inheritance is slide -> layout -> master -> geometry inference",
    "assets stay output-boundary only", "TargetMode=External is no-fetch",
  ])
  assert_contains_all(@shared.pptx_contract_slide_policy().join("\n"), [
    "slide order is derived from presentation.xml and slide relationship ids", "hidden slides remain explicit semantic units with diagnostics-first visibility policy",
    "slide part resolution is package-local only", "missing slide relationships fail closed with diagnostics",
  ])
  assert_contains_all(@shared.pptx_contract_placeholder_policy().join("\n"), [
    "placeholder inheritance resolves through slide, layout, then master", "placeholder type/index stays observable through source_ref extras",
    "unresolved placeholders stay diagnosed rather than silently flattened", "geometry/name inference is last-resort only",
  ])
  assert_contains_all(@shared.pptx_contract_reading_order_policy().join("\n"), [
    "reading order uses placeholder hints before geometry heuristics", "geometry heuristics stay bounded and diagnostics-visible",
    "legacy reading-order fallback is forbidden", "reading-order strategy remains observable in diagnostics metrics",
  ])
  assert_contains_all(@shared.pptx_contract_notes_policy().join("\n"), [
    "speaker notes remain attached per slide", "comments remain metadata-first and slide-scoped",
    "missing notes/comments parts are diagnosed", "notes/comments never trigger external fetch",
  ])
  assert_contains_all(@shared.pptx_contract_relationship_policy().join("\n"), [
    "relationship target resolution is package-local by default", "TargetMode=External is no-fetch",
    "missing targets are diagnosed", "relationship traversal outside package-safe normalized boundaries is forbidden",
    "unsupported embedded/chart/media relationships remain diagnostics-first",
  ])
  assert_contains_all(@shared.pptx_contract_asset_policy().join("\n"), [
    "internal slide media stays package-local only", "materialization only happens at the CLI/output boundary",
    "parser/orchestrator file writes are forbidden", "charts smartart ole and embedded binaries remain reference-only or unsupported diagnostics",
  ])
}

///|
test "pptx contract helper stays scaffold-only while runtime parser is exposed and legacy free" {
  assert_eq(@shared.pptx_contract_parser_name(), "pptx_parser_contract")
  assert_true(
    @shared.pptx_contract_mode() == @parser.ParserMode::PresentationModel,
  )
  assert_true(
    @shared.pptx_contract_granularity() ==
    @parser.StreamingGranularity::PptxSlide,
  )
  assert_eq(@shared.pptx_contract_ir_input_kind(), "document")
  assert_true(
    @shared.pptx_contract_foundations() ==
    ["format_readers/ooxml/package", "format_readers/ooxml/pptx"],
  )
  assert_true(
    @shared.pptx_contract_excluded_runtime_foundations() ==
    ["convert/pptx", "old_core", "legacy_dispatcher", "markdown_emitter"],
  )
  let helper = @formats_root.pptx_parser_contract()
  let helper_result = match
    (helper.parse)(
      @input.input_from_path(
        "samples/main_process/pptx/pptx_hidden_slide_basic.pptx",
      ),
      @parser.new_parse_context(@input.DetectedFormat::Unknown),
    ) {
    Ok(value) => value
    Err(msg) => fail("pptx contract helper should produce diagnostics: " + msg)
  }
  assert_true(helper_result.document is Some(_))
  assert_metric_eq(helper_result.diagnostics, "runtime_exposed", "false")
  assert_metric_eq(
    helper_result.diagnostics,
    "parser_mode",
    "presentation_model",
  )
  assert_metric_eq(
    helper_result.diagnostics,
    "effective_mode",
    "presentation_model",
  )
  assert_metric_eq(helper_result.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(helper_result.diagnostics, "event_granularity", "pptx_slide")
  assert_metric_eq(helper_result.diagnostics, "office_document_kind", "pptx")
  assert_metric_eq(
    helper_result.diagnostics,
    "legacy_runtime_dependency",
    "none",
  )
  assert_metric_eq(
    helper_result.diagnostics,
    "legacy_convert_dependency",
    "none",
  )
  assert_metric_eq(helper_result.diagnostics, "legacy_fallback", "forbidden")
  assert_metric_eq(
    helper_result.diagnostics,
    "pptx_reading_order_strategy",
    "placeholder_then_geometry",
  )
  assert_true(
    helper_result.diagnostics.degraded_features.contains(
      "pptx_contract_helper_only",
    ),
  )
  assert_true(helper_result.diagnostics.errors.length() == 0)
  assert_true(helper_result.diagnostics.warnings.length() == 1)
  assert_true(
    helper_result.diagnostics.warnings[0].contains(
      "mirrors the PPTX product boundary",
    ),
  )
  let formats_pkg = read_utf8_text("formats/moon.pkg")
  let office_pkg = read_utf8_text("format_readers/ooxml/shared/moon.pkg")
  let office_impl = read_utf8_text("format_readers/ooxml/shared/shared.mbt")
  let pptx_contract_impl = read_utf8_text("formats/format_contracts.mbt")
  let registry_impl = read_utf8_text("formats/registry.mbt")
  assert_contains_none(formats_pkg, [
    "ZSeanYves/markitdown/convert/pptx", "ZSeanYves/markitdown/unmigrated/",
  ])
  assert_contains_none(office_pkg, [
    "ZSeanYves/markitdown/format_readers/ooxml/pptx", "ZSeanYves/markitdown/convert/pptx",
    "ZSeanYves/markitdown/unmigrated/",
  ])
  assert_contains_none(office_impl, [
    "ZSeanYves/markitdown/format_readers/ooxml/pptx", "ZSeanYves/markitdown/unmigrated/",
    "@legacy",
  ])
  assert_contains_none(pptx_contract_impl, [
    "format_readers/ooxml/pptx", "convert/pptx", "@legacy", "emitter_markdown", "legacy_dispatcher",
  ])
  assert_true(registry_impl.contains("@input.DetectedFormat::Pptx"))
  assert_true(registry_impl.contains("pptx_parser()"))
  assert_true(!registry_impl.contains("pptx_parser_contract()"))
}

///|
test "pptx source ref debug json and metric scaffolds stay visible after runtime restore" {
  let source_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(
            @core.source_ref_with_extra(
              @core.source_ref_with_extra(
                @core.source_ref_with_extra(
                  @core.source_ref_with_extra(
                    @core.source_ref_with_extra(
                      @core.source_ref_with_office_fields(
                        @core.source_ref_with_container_entry(
                          @core.empty_source_ref(),
                          Some("deck.pptx"),
                          Some("pptx"),
                          Some("deck.pptx"),
                          Some("ppt/slides/slide3.xml"),
                          Some(2),
                          Some("pptx"),
                          Some("/p:sld/p:cSld/p:spTree/p:sp[4]"),
                        ),
                        Some("deck.pptx"),
                        Some("pptx"),
                        Some("/p:sld/p:cSld/p:spTree/p:sp[4]"),
                        None,
                        None,
                        Some(3),
                        Some("shape-4"),
                        Some("rId9"),
                      ),
                      "slide_index",
                      "3",
                    ),
                    "slide_id",
                    "4096",
                  ),
                  "slide_part",
                  "ppt/slides/slide3.xml",
                ),
                "layout_part",
                "ppt/slideLayouts/slideLayout2.xml",
              ),
              "master_part",
              "ppt/slideMasters/slideMaster1.xml",
            ),
            "theme_part",
            "ppt/theme/theme1.xml",
          ),
          "shape_name",
          "Title 1",
        ),
        "shape_type",
        "title",
      ),
      "placeholder_type",
      "title",
    ),
    "placeholder_idx",
    "0",
  )
  let with_more = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(source_ref, "reading_order_index", "0"),
          "notes_part",
          "ppt/notesSlides/notesSlide3.xml",
        ),
        "comment_id",
        "comment-11",
      ),
      "part_name",
      "ppt/slides/slide3.xml",
    ),
    "paragraph_index",
    "0",
  )
  let block = @core.make_block(
    @core.BlockKind::Heading,
    "Quarterly review",
    source_ref=with_more,
  )
  let rendered = (@render.debug_json_renderer().render)(
    @core.document_from_blocks([block]),
    @render.make_render_context(true),
  )
  assert_true(rendered.content.contains("\"format\": \"pptx\""))
  assert_true(rendered.content.contains("\"slide\": 3"))
  assert_true(rendered.content.contains("\"shape_id\": \"shape-4\""))
  assert_true(rendered.content.contains("\"relationship_id\": \"rId9\""))
  assert_true(rendered.content.contains("\"slide_index\": \"3\""))
  assert_true(rendered.content.contains("\"slide_id\": \"4096\""))
  assert_true(
    rendered.content.contains("\"slide_part\": \"ppt/slides/slide3.xml\""),
  )
  assert_true(
    rendered.content.contains(
      "\"layout_part\": \"ppt/slideLayouts/slideLayout2.xml\"",
    ),
  )
  assert_true(
    rendered.content.contains(
      "\"master_part\": \"ppt/slideMasters/slideMaster1.xml\"",
    ),
  )
  assert_true(
    rendered.content.contains("\"theme_part\": \"ppt/theme/theme1.xml\""),
  )
  assert_true(rendered.content.contains("\"shape_name\": \"Title 1\""))
  assert_true(rendered.content.contains("\"shape_type\": \"title\""))
  assert_true(rendered.content.contains("\"placeholder_type\": \"title\""))
  assert_true(rendered.content.contains("\"placeholder_idx\": \"0\""))
  assert_true(rendered.content.contains("\"reading_order_index\": \"0\""))
  assert_true(
    rendered.content.contains(
      "\"notes_part\": \"ppt/notesSlides/notesSlide3.xml\"",
    ),
  )
  assert_true(rendered.content.contains("\"comment_id\": \"comment-11\""))
  assert_contains_all(@shared.office_source_ref_extra_keys().join("\n"), [
    "slide_index", "slide_id", "slide_part", "layout_part", "master_part", "theme_part",
    "shape_name", "shape_type", "placeholder_type", "placeholder_idx", "reading_order_index",
    "notes_part", "comment_id",
  ])
  assert_contains_all(
    @shared.pptx_contract_source_ref_extra_keys().join("\n"),
    [
      "slide_index", "slide_id", "slide_part", "layout_part", "master_part", "theme_part",
      "shape_id", "shape_name", "shape_type", "placeholder_type", "placeholder_idx",
      "reading_order_index", "notes_part", "comment_id", "part_name", "relationship_id",
      "paragraph_index", "run_index",
    ],
  )
  assert_contains_all(@shared.office_diagnostic_metric_keys().join("\n"), [
    "pptx_slide_count", "pptx_hidden_slide_count", "pptx_shape_count", "pptx_text_box_count",
    "pptx_placeholder_count", "pptx_table_count", "pptx_image_count", "pptx_notes_count",
    "pptx_layout_count", "pptx_master_count", "pptx_theme_count", "pptx_resolved_placeholder_count",
    "pptx_unresolved_placeholder_count", "pptx_comment_count", "pptx_external_media_count",
    "pptx_reading_order_strategy",
  ])
  assert_contains_all(@shared.office_resource_limit_keys().join("\n"), [
    "max_pptx_slides", "max_pptx_shapes", "max_pptx_text_runs", "max_pptx_tables",
    "max_pptx_images", "max_pptx_notes", "max_pptx_comments",
  ])
}

///|
test "pptx runtime keeps presentation order reading order and diagnostics contracts" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/pptx/pptx_hidden_slides_policy.pptx",
    ),
    @input.DetectedFormat::Pptx,
  )
  assert_metric_eq(parsed.diagnostics, "parser_mode", "presentation_model")
  assert_metric_eq(parsed.diagnostics, "effective_mode", "presentation_model")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "pptx_slide")
  assert_metric_eq(parsed.diagnostics, "office_document_kind", "pptx")
  assert_metric_eq(parsed.diagnostics, "runtime_exposed", "true")
  assert_metric_eq(parsed.diagnostics, "legacy_runtime_dependency", "none")
  assert_metric_eq(parsed.diagnostics, "legacy_convert_dependency", "none")
  assert_metric_eq(parsed.diagnostics, "legacy_fallback", "forbidden")
  assert_metric_eq(parsed.diagnostics, "pptx_slide_count", "3")
  assert_metric_eq(parsed.diagnostics, "pptx_visible_slide_count", "2")
  assert_metric_eq(parsed.diagnostics, "pptx_hidden_slide_count", "1")
  assert_metric_eq(
    parsed.diagnostics,
    "pptx_reading_order_strategy",
    "placeholder_then_geometry",
  )
  assert_true(parsed.diagnostics.metrics.get("ooxml_part_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("relationship_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("content_type_count") is Some(_))
  assert_true(
    parsed.diagnostics.metrics.get("total_uncompressed_bytes") is Some(_),
  )
  assert_true(
    parsed.diagnostics.warnings.contains("hidden pptx slide skipped: Slide 2"),
  )
  assert_true(
    parsed.diagnostics.degraded_features.contains("pptx_hidden_slide_skipped"),
  )
  assert_true(parsed.diagnostics.pass_trace.contains("parse:pptx_parser"))
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "pptx_raw_fallback", "pptx_legacy_fallback", "legacy_dispatcher_used", "convert_pptx_used",
    "xml_order_text_dump",
  ])
  let document = parsed.document.unwrap_or_else(fn() {
    abort("missing pptx document")
  })
  assert_true(document.blocks.length() == 6)
  assert_true(document.blocks[0].kind == @core.BlockKind::Heading)
  assert_eq(document.blocks[0].text, "Slide 1")
  assert_eq(document.blocks[1].text, "Third")
  assert_eq(document.blocks[2].text, "Alpha")
  assert_eq(document.blocks[3].text, "Slide 3")
  assert_eq(document.blocks[4].text, "Second")
  assert_eq(document.blocks[5].text, "Gamma")
  let slide1_ref = document.blocks[0].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(slide1_ref.entry_path == Some("ppt/slides/slide1.xml"))
  assert_true(slide1_ref.extra.get("slide_id") == Some("256"))
  let title_ref = document.blocks[1].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(title_ref.extra.get("placeholder_type") == Some("center_title"))
  assert_true(title_ref.extra.get("shape_name") == Some("Third"))
  let body_ref = document.blocks[2].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(body_ref.extra.get("shape_name") == Some("Alpha"))
  assert_true(body_ref.extra.get("reading_order_key") is Some(_))
}

///|
test "pptx runtime keeps nested list tree and renderer boundary on expected-next sample" {
  let parsed = default_registry_parse(
    @input.input_from_path("samples/main_process/pptx/pptx_bullet_levels.pptx"),
    @input.DetectedFormat::Pptx,
  )
  assert_metric_eq(parsed.diagnostics, "effective_mode", "presentation_model")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "pptx_slide")
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "pptx_raw_fallback", "pptx_legacy_fallback", "convert_pptx_used", "legacy_dispatcher_used",
    "xml_order_text_dump",
  ])
  let document = parsed.document.unwrap_or_else(fn() {
    abort("missing pptx bullet document")
  })
  assert_true(document.blocks.length() == 3)
  assert_true(document.blocks[0].kind == @core.BlockKind::Heading)
  assert_true(document.blocks[1].kind == @core.BlockKind::Heading)
  assert_true(document.blocks[2].kind == @core.BlockKind::List)
  let list = document.blocks[2]
  assert_true(list.text == "")
  assert_true(list.children.length() == 2)
  assert_true(list.children[0].kind == @core.BlockKind::ListItem)
  assert_true(list.children[0].text == "Phase 1")
  assert_true(list.children[0].children.length() == 1)
  let nested = list.children[0].children[0]
  assert_true(nested.kind == @core.BlockKind::List)
  assert_true(nested.children.length() == 2)
  assert_true(nested.children[0].kind == @core.BlockKind::ListItem)
  assert_true(nested.children[0].text == "Task 1.1")
  assert_true(nested.children[1].kind == @core.BlockKind::ListItem)
  assert_true(nested.children[1].text == "Task 1.2")
  assert_true(list.children[1].kind == @core.BlockKind::ListItem)
  assert_true(list.children[1].text == "Phase 2")
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  let expected = read_utf8_text(
    "samples/main_process/pptx/expected_next/pptx_bullet_levels.md",
  )
  assert_eq(rendered.content.trim().to_owned(), expected.trim().to_owned())
  assert_true(rendered.content.contains("- Phase 1"))
  assert_true(rendered.content.contains("  - Task 1.1"))
  assert_true(rendered.content.contains("  - Task 1.2"))
}

///|
test "pptx runtime keeps speaker notes separate from slide body and source refs explicit" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/pptx/pptx_speaker_notes_basic.pptx",
    ),
    @input.DetectedFormat::Pptx,
  )
  assert_metric_eq(parsed.diagnostics, "effective_mode", "presentation_model")
  assert_metric_eq(parsed.diagnostics, "pptx_notes_count", "3")
  assert_metric_eq(parsed.diagnostics, "pptx_comment_count", "0")
  assert_metric_eq(parsed.diagnostics, "pptx_hidden_slide_count", "0")
  let document = parsed.document.unwrap_or_else(fn() {
    abort("missing pptx notes document")
  })
  assert_true(document.blocks.length() == 18)
  assert_eq(document.blocks[6].text, "Speaker Notes")
  assert_eq(document.blocks[7].text, "本页核心信息")
  assert_eq(document.blocks[12].text, "Speaker Notes")
  assert_eq(document.blocks[13].text, "第二页备注")
  assert_eq(document.blocks[16].text, "Speaker Notes")
  assert_eq(document.blocks[17].text, "最后页备注")
  let notes_heading_ref = document.blocks[6].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(
    notes_heading_ref.entry_path == Some("ppt/notesSlides/notesSlide1.xml"),
  )
  assert_true(
    notes_heading_ref.extra.get("notes_part") ==
    Some("ppt/notesSlides/notesSlide1.xml"),
  )
  let notes_text_ref = document.blocks[7].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(
    notes_text_ref.entry_path == Some("ppt/notesSlides/notesSlide1.xml"),
  )
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  let expected = read_utf8_text(
    "samples/main_process/pptx/expected_next/pptx_speaker_notes_basic.md",
  )
  assert_eq(rendered.content.trim().to_owned(), expected.trim().to_owned())
  assert_true(rendered.content.contains("### Speaker Notes"))
  assert_true(rendered.content.contains("本页核心信息"))
  assert_true(!rendered.content.contains("Speaker Notes 1"))
}

///|
test "pptx runtime keeps package-local assets in document ir and expected-next baseline" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/pptx/assets/pptx_image_single.pptx",
    ),
    @input.DetectedFormat::Pptx,
  )
  assert_metric_eq(parsed.diagnostics, "effective_mode", "presentation_model")
  assert_metric_eq(parsed.diagnostics, "asset_count", "1")
  assert_metric_eq(parsed.diagnostics, "media_asset_count", "1")
  assert_metric_eq(parsed.diagnostics, "materialized_asset_count", "1")
  assert_metric_eq(parsed.diagnostics, "pptx_image_count", "1")
  assert_metric_eq(parsed.diagnostics, "pptx_external_media_count", "0")
  let document = parsed.document.unwrap_or_else(fn() {
    abort("missing pptx image document")
  })
  assert_true(document.blocks.length() == 2)
  assert_true(document.blocks[1].kind == @core.BlockKind::Image)
  assert_true(
    document.blocks[1].attrs.get("path") == Some("assets/image01.png"),
  )
  assert_true(document.assets.length() == 1)
  assert_true(document.assets[0].path == Some("assets/image01.png"))
  assert_true(
    document.assets[0].attrs.get("source_path") == Some("ppt/media/image1.png"),
  )
  assert_true(
    document.assets[0].attrs.get("zip_container_format") == Some("pptx"),
  )
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  let expected = read_utf8_text(
    "samples/main_process/pptx/expected_next/assets/pptx_image_single.md",
  )
  assert_eq(rendered.content.trim().to_owned(), expected.trim().to_owned())
}

///|
test "xlsx scaffold models and guardrails stay root-pipeline only" {
  let xlsx_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(
            @core.source_ref_with_office_fields(
              @core.source_ref_with_container_entry(
                @core.empty_source_ref(),
                Some("sample.xlsx"),
                Some("xlsx"),
                Some("sample.xlsx"),
                Some("xl/worksheets/sheet1.xml"),
                Some(0),
                Some("xlsx"),
                Some("/worksheet/sheetData/row[7]/c[2]"),
              ),
              Some("sample.xlsx"),
              Some("xlsx"),
              Some("/worksheet/sheetData/row[7]/c[2]"),
              Some("Sheet A"),
              Some("B7"),
              None,
              None,
              Some("rIdSheet1"),
            ),
            "sheet_name",
            "Sheet A",
          ),
          "sheet_id",
          "1",
        ),
        "sheet_visibility",
        "visible",
      ),
      "row_index",
      "7",
    ),
    "column_index",
    "2",
  )
  let style : @core.StyleRef = {
    style_id: Some("3"),
    style_name: Some("Currency"),
    attrs: Map([]),
  }
  let formula = @shared.make_xlsx_formula(
    "SUM(B2:B6)",
    cached_value=Some("42"),
    formula_ref=Some("B7"),
    source_ref=Some(xlsx_ref),
  )
  let cell = @shared.make_xlsx_cell_model(
    "B7",
    7,
    2,
    @shared.XlsxCellType::Formula,
    raw_value=Some("42"),
    display_value=Some("42"),
    style_ref=Some(style),
    formula=Some(formula),
    source_ref=Some(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(xlsx_ref, "cell_ref", "B7"),
          "formula_ref",
          "B7",
        ),
        "style_id",
        "3",
      ),
    ),
  )
  let merge = @shared.make_xlsx_merged_range(
    "A1:B1",
    "A1",
    "B1",
    source_ref=Some(
      @core.source_ref_with_extra(xlsx_ref, "merge_range", "A1:B1"),
    ),
  )
  let row = @shared.make_xlsx_row_model(7, [cell], source_ref=Some(xlsx_ref))
  let sheet = @shared.make_xlsx_sheet_model(
    "Sheet A",
    [row],
    sheet_id=Some("1"),
    relationship_id=Some("rIdSheet1"),
    part_name=Some("xl/worksheets/sheet1.xml"),
    visibility=@shared.XlsxSheetVisibility::Visible,
    dimension_ref=Some("A1:B7"),
    merged_ranges=[merge],
    source_ref=Some(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          xlsx_ref, "part_name", "xl/worksheets/sheet1.xml",
        ),
        "relationship_id",
        "rIdSheet1",
      ),
    ),
  )
  let workbook = @shared.make_xlsx_workbook_model(
    [sheet],
    shared_strings=[@shared.make_xlsx_shared_string(0, "Total")],
    styles_summary=Map([
      ("style_count", @core.JsonValue::Number("1")),
      ("format_policy", @core.JsonValue::String("best_effort_display_only")),
    ]),
    defined_names=["Totals"],
    source_ref=Some(
      @core.source_ref_with_extra(
        @core.source_ref_with_container_entry(
          @core.empty_source_ref(),
          Some("sample.xlsx"),
          Some("xlsx"),
          Some("sample.xlsx"),
          Some("xl/workbook.xml"),
          Some(0),
          Some("xlsx"),
          Some("/workbook/sheets/sheet[1]"),
        ),
        "sheet_visibility",
        "visible",
      ),
    ),
  )
  let plan = @shared.make_xlsx_workbook_plan(workbook, ["Sheet A"], skipped_sheet_names=[
    "Hidden 1",
  ])
  assert_true(
    @shared.office_document_kind_name(@shared.OfficeDocumentKind::Xlsx) ==
    "xlsx",
  )
  assert_true(@shared.xlsx_sheet_visibility_name(sheet.visibility) == "visible")
  assert_true(@shared.xlsx_cell_type_name(cell.cell_type) == "formula")
  assert_true(plan.workbook.sheets.length() == 1)
  assert_true(plan.workbook.shared_strings.length() == 1)
  assert_true(plan.included_sheet_names == ["Sheet A"])
  assert_true(plan.skipped_sheet_names == ["Hidden 1"])
  assert_true(cell.formula is Some(_))
  assert_true(cell.style_ref is Some(_))
  match cell.formula {
    Some(value) => {
      assert_eq(value.formula_text, "SUM(B2:B6)")
      assert_true(value.cached_value == Some("42"))
    }
    None => fail("xlsx scaffold cell should keep formula contract")
  }
  assert_contains_all(@shared.xlsx_contract_guardrails().join("\n"), [
    "XLSX is restored on the current main CLI", "WorkbookModel / IRInput::Document / xlsx_sheet",
    "future large path = StreamingEvent / EventStream / xlsx_row", "format_readers/ooxml/shared now owns the shared XLSX semantic scaffold",
    "no old core", "no legacy convert", "no markdown emitter", "no main CLI fallback",
    "assets stay output-boundary only", "formulas are preserved and never executed",
    "external links are no-fetch",
  ])
  assert_contains_all(@shared.xlsx_contract_formula_policy().join("\n"), [
    "formula text is preserved", "formula evaluation is forbidden", "cached value may be used when present",
    "external formula links are not fetched", "volatile functions are not evaluated",
  ])
  assert_contains_all(@shared.xlsx_contract_sheet_policy().join("\n"), [
    "visible sheets are future first-scope input", "hidden sheets require explicit diagnostics policy",
    "very hidden sheets require explicit diagnostics policy", "large sheets are bounded and defer to future xlsx_row streaming",
  ])
  assert_contains_all(@shared.xlsx_contract_relationship_policy().join("\n"), [
    "relationship target resolution is package-local by default", "TargetMode=External is no-fetch",
    "external links are diagnostics/metadata only", "missing targets are diagnosed",
    "relationship traversal outside package-safe normalized boundaries is forbidden",
  ])
  assert_contains_all(@shared.xlsx_contract_asset_policy().join("\n"), [
    "drawing/image relationships stay package-local only", "materialization only happens at the CLI/output boundary",
    "parser/orchestrator file writes are forbidden", "assets stay reference-only until output policy opts in",
  ])
}

///|
test "xlsx contract helper and dependency guard stay restored and legacy free" {
  assert_eq(@shared.xlsx_contract_parser_name(), "xlsx_parser_contract")
  assert_true(@shared.xlsx_contract_mode() == @parser.ParserMode::WorkbookModel)
  assert_true(
    @shared.xlsx_contract_granularity() ==
    @parser.StreamingGranularity::XlsxSheet,
  )
  assert_true(
    @shared.xlsx_contract_large_granularity() ==
    @parser.StreamingGranularity::XlsxRow,
  )
  assert_eq(@shared.xlsx_contract_ir_input_kind(), "document")
  assert_eq(@shared.xlsx_contract_large_ir_input_kind(), "event_stream")
  assert_true(
    @shared.xlsx_contract_foundations() ==
    ["format_readers/ooxml/package", "format_readers/ooxml/shared"],
  )
  assert_true(
    @shared.xlsx_contract_excluded_runtime_foundations() ==
    ["convert/xlsx", "old_core"],
  )
  let helper = @formats_root.xlsx_parser_contract()
  let helper_result = match
    (helper.parse)(
      @input.input_from_path("samples/main_process/xlsx/sheet_simple.xlsx"),
      @parser.new_parse_context(@input.DetectedFormat::Unknown),
    ) {
    Ok(value) => value
    Err(msg) => fail("xlsx contract helper should produce diagnostics: " + msg)
  }
  assert_true(helper_result.document is Some(_))
  assert_metric_eq(helper_result.diagnostics, "runtime_exposed", "true")
  assert_metric_eq(helper_result.diagnostics, "parser_mode", "workbook_model")
  assert_metric_eq(
    helper_result.diagnostics,
    "effective_mode",
    "workbook_model",
  )
  assert_metric_eq(helper_result.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(helper_result.diagnostics, "event_granularity", "xlsx_sheet")
  assert_metric_eq(helper_result.diagnostics, "office_document_kind", "xlsx")
  assert_metric_eq(
    helper_result.diagnostics,
    "legacy_runtime_dependency",
    "none",
  )
  assert_metric_eq(
    helper_result.diagnostics,
    "legacy_convert_dependency",
    "none",
  )
  assert_metric_eq(helper_result.diagnostics, "legacy_fallback", "forbidden")
  assert_true(
    helper_result.diagnostics.degraded_features.contains(
      "xlsx_contract_helper_only",
    ),
  )
  assert_true(helper_result.diagnostics.errors.length() == 0)
  assert_true(helper_result.diagnostics.warnings.length() == 1)
  assert_true(
    helper_result.diagnostics.warnings[0].contains(
      "mirrors the XLSX product boundary",
    ),
  )
  let formats_pkg = read_utf8_text("formats/moon.pkg")
  let office_pkg = read_utf8_text("format_readers/ooxml/shared/moon.pkg")
  let office_impl = read_utf8_text("format_readers/ooxml/shared/shared.mbt")
  let xlsx_contract_impl = read_utf8_text("formats/format_contracts.mbt")
  assert_contains_none(formats_pkg, [
    "ZSeanYves/markitdown/convert/xlsx", "ZSeanYves/markitdown/unmigrated/",
  ])
  assert_contains_none(office_pkg, [
    "ZSeanYves/markitdown/convert/xlsx", "ZSeanYves/markitdown/unmigrated/",
  ])
  assert_contains_none(office_impl, [
    "ZSeanYves/markitdown/convert/xlsx", "ZSeanYves/markitdown/unmigrated/", "@legacy",
  ])
  assert_contains_none(xlsx_contract_impl, [
    "convert/xlsx", "@legacy", "emitter_markdown", "legacy_dispatcher",
  ])
}

///|
test "xlsx parser keeps workbook-model diagnostics source refs and sheet policy contract locked" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/xlsx/xlsx_hidden_sheets_policy.xlsx",
    ),
    @input.DetectedFormat::Xlsx,
  )
  assert_metric_eq(parsed.diagnostics, "parser_mode", "workbook_model")
  assert_metric_eq(parsed.diagnostics, "effective_mode", "workbook_model")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "document")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "xlsx_sheet")
  assert_metric_eq(parsed.diagnostics, "office_document_kind", "xlsx")
  assert_metric_eq(parsed.diagnostics, "runtime_exposed", "true")
  assert_metric_eq(parsed.diagnostics, "legacy_runtime_dependency", "none")
  assert_metric_eq(parsed.diagnostics, "legacy_convert_dependency", "none")
  assert_metric_eq(parsed.diagnostics, "legacy_fallback", "forbidden")
  assert_metric_eq(parsed.diagnostics, "xlsx_sheet_count", "3")
  assert_metric_eq(parsed.diagnostics, "xlsx_visible_sheet_count", "1")
  assert_metric_eq(parsed.diagnostics, "xlsx_hidden_sheet_count", "1")
  assert_metric_eq(parsed.diagnostics, "xlsx_very_hidden_sheet_count", "1")
  assert_metric_eq(parsed.diagnostics, "xlsx_workbook_part", "xl/workbook.xml")
  assert_true(parsed.diagnostics.metrics.get("ooxml_part_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("relationship_count") is Some(_))
  assert_true(parsed.diagnostics.metrics.get("content_type_count") is Some(_))
  assert_true(
    parsed.diagnostics.metrics.get("total_uncompressed_bytes") is Some(_),
  )
  assert_true(
    parsed.diagnostics.warnings.contains(
      "hidden xlsx sheet skipped: HiddenData",
    ),
  )
  assert_true(
    parsed.diagnostics.warnings.contains(
      "very hidden xlsx sheet skipped: VeryHiddenAudit",
    ),
  )
  assert_true(
    parsed.diagnostics.degraded_features.contains("xlsx_hidden_sheet_skipped"),
  )
  assert_true(
    parsed.diagnostics.degraded_features.contains(
      "xlsx_very_hidden_sheet_skipped",
    ),
  )
  assert_true(parsed.diagnostics.pass_trace.contains("parse:xlsx_parser"))
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "xlsx_legacy_fallback", "legacy_dispatcher_used", "convert_xlsx_used", "doc_parse_xlsx_used",
    "xlsx_raw_fallback", "formula_evaluation_enabled",
  ])
  let document = parsed.document.unwrap_or_else(fn() {
    abort("missing xlsx document")
  })
  match document.metadata.get("workbook_part") {
    Some(@core.JsonValue::String(value)) => assert_eq(value, "xl/workbook.xml")
    _ => fail("xlsx document metadata should keep workbook_part")
  }
  assert_true(document.blocks.length() == 2)
  assert_true(document.blocks[0].kind == @core.BlockKind::Heading)
  assert_eq(document.blocks[0].text, "Visible")
  assert_true(document.blocks[1].kind == @core.BlockKind::Table)
  let table_ref = document.blocks[1].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(table_ref.format == Some("xlsx"))
  match table_ref.container_path {
    Some(value) => assert_eq(value, "xlsx_hidden_sheets_policy.xlsx")
    None => fail("xlsx table source ref should keep container_path")
  }
  assert_true(table_ref.entry_path == Some("xl/worksheets/sheet1.xml"))
  assert_true(table_ref.inner_path == Some("/worksheet/sheetData"))
  assert_true(table_ref.extra.get("sheet_name") == Some("Visible"))
  assert_true(table_ref.extra.get("sheet_visibility") == Some("visible"))
  assert_true(
    table_ref.extra.get("part_name") == Some("xl/worksheets/sheet1.xml"),
  )
  assert_true(table_ref.extra.get("relationship_id") == Some("rId1"))
}

///|
test "xlsx parser preserves formulas and expected-next renderer boundary without execution" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/xlsx/xlsx_formula_missing_cache.xlsx",
    ),
    @input.DetectedFormat::Xlsx,
  )
  assert_metric_eq(parsed.diagnostics, "effective_mode", "workbook_model")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "xlsx_sheet")
  assert_metric_eq(parsed.diagnostics, "xlsx_formula_count", "3")
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "formula_evaluation_enabled", "xlsx_legacy_fallback", "convert_xlsx_used",
  ])
  let document = parsed.document.unwrap_or_else(fn() {
    abort("missing xlsx formula document")
  })
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  let expected = read_utf8_text(
    "samples/main_process/xlsx/expected_next/xlsx_formula_missing_cache.md",
  )
  assert_eq(rendered.content.trim().to_owned(), expected.trim().to_owned())
  assert_true(rendered.content.contains("| Missing numeric cache | =1+2 |"))
  assert_true(
    rendered.content.contains("| Missing string cache | =CONCAT(\"a\",\"b\") |"),
  )
  assert_true(rendered.content.contains("| Error cache present | #DIV/0! |"))
}

///|
test "xlsx source ref debug json and metric scaffolds stay visible without runtime exposure" {
  let source_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(
            @core.source_ref_with_extra(
              @core.source_ref_with_extra(
                @core.source_ref_with_extra(
                  @core.source_ref_with_office_fields(
                    @core.source_ref_with_container_entry(
                      @core.empty_source_ref(),
                      Some("book.xlsx"),
                      Some("xlsx"),
                      Some("book.xlsx"),
                      Some("xl/worksheets/sheet1.xml"),
                      Some(0),
                      Some("xlsx"),
                      Some("/worksheet/sheetData/row[7]/c[2]"),
                    ),
                    Some("book.xlsx"),
                    Some("xlsx"),
                    Some("/worksheet/sheetData/row[7]/c[2]"),
                    Some("Summary"),
                    Some("B7:C9"),
                    None,
                    None,
                    Some("rIdSheet1"),
                  ),
                  "sheet_name",
                  "Summary",
                ),
                "sheet_id",
                "1",
              ),
              "sheet_visibility",
              "very_hidden",
            ),
            "cell_ref",
            "B7",
          ),
          "row_index",
          "7",
        ),
        "column_index",
        "2",
      ),
      "formula_ref",
      "B7",
    ),
    "shared_string_index",
    "14",
  )
  let with_more = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(source_ref, "style_id", "3"),
        "merge_range",
        "B7:C9",
      ),
      "part_name",
      "xl/worksheets/sheet1.xml",
    ),
    "relationship_id",
    "rIdSheet1",
  )
  let block = @core.make_block(
    @core.BlockKind::TableCell,
    "42",
    source_ref=with_more,
  )
  let rendered = (@render.debug_json_renderer().render)(
    @core.document_from_blocks([block]),
    @render.make_render_context(true),
  )
  assert_true(rendered.content.contains("\"format\": \"xlsx\""))
  assert_true(rendered.content.contains("\"sheet\": \"Summary\""))
  assert_true(rendered.content.contains("\"cell_range\": \"B7:C9\""))
  assert_true(rendered.content.contains("\"sheet_name\": \"Summary\""))
  assert_true(rendered.content.contains("\"sheet_id\": \"1\""))
  assert_true(
    rendered.content.contains("\"sheet_visibility\": \"very_hidden\""),
  )
  assert_true(rendered.content.contains("\"cell_ref\": \"B7\""))
  assert_true(rendered.content.contains("\"row_index\": \"7\""))
  assert_true(rendered.content.contains("\"column_index\": \"2\""))
  assert_true(rendered.content.contains("\"formula_ref\": \"B7\""))
  assert_true(rendered.content.contains("\"shared_string_index\": \"14\""))
  assert_true(rendered.content.contains("\"style_id\": \"3\""))
  assert_true(rendered.content.contains("\"merge_range\": \"B7:C9\""))
  assert_true(
    rendered.content.contains("\"part_name\": \"xl/worksheets/sheet1.xml\""),
  )
  assert_true(rendered.content.contains("\"relationship_id\": \"rIdSheet1\""))
  assert_contains_all(@shared.office_source_ref_extra_keys().join("\n"), [
    "sheet_name", "sheet_id", "sheet_visibility", "cell_ref", "cell_range", "row_index",
    "column_index", "formula_ref", "shared_string_index", "style_id", "merge_range",
  ])
  assert_contains_all(
    @shared.xlsx_contract_source_ref_extra_keys().join("\n"),
    [
      "sheet_name", "sheet_id", "sheet_visibility", "cell_ref", "cell_range", "row_index",
      "column_index", "formula_ref", "shared_string_index", "style_id", "merge_range",
      "relationship_id", "part_name",
    ],
  )
  assert_contains_all(@shared.office_diagnostic_metric_keys().join("\n"), [
    "external_link_count", "xlsx_sheet_count", "xlsx_hidden_sheet_count", "xlsx_very_hidden_sheet_count",
    "xlsx_row_count", "xlsx_cell_count", "xlsx_non_empty_cell_count", "xlsx_merged_cell_count",
    "xlsx_formula_count", "xlsx_shared_formula_count", "xlsx_array_formula_count",
    "xlsx_shared_string_count", "xlsx_style_count", "xlsx_drawing_count", "xlsx_image_count",
  ])
  assert_contains_all(@shared.office_resource_limit_keys().join("\n"), [
    "max_xlsx_sheets", "max_xlsx_rows", "max_xlsx_columns", "max_xlsx_cells", "max_xlsx_non_empty_cells",
    "max_shared_strings", "max_formula_count", "max_merged_ranges", "max_materialized_assets",
  ])
}

///|
test "container model scaffold can represent unsafe and limited entries without runtime enablement" {
  let unsafe_src = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some("sample.zip"),
    Some("zip"),
    Some("sample.zip"),
    Some("../evil.txt"),
    Some(9),
    Some("txt"),
    None,
  )
  let unsafe_entry = @core.make_container_entry(
    "../evil.txt",
    @core.ContainerEntryKind::Unsafe,
    normalized_path=None,
    entry_index=Some(9),
    detected_format=Some("txt"),
    is_encrypted=true,
    compression_method=Some("unsupported:deflate64"),
    source_ref=Some(unsafe_src),
    security_findings=[
      @core.ContainerSecurityFinding::PathTraversal,
      @core.ContainerSecurityFinding::EncryptedEntry,
      @core.ContainerSecurityFinding::UnsupportedCompression,
      @core.ContainerSecurityFinding::CompressionRatioLimit,
    ],
  )
  assert_true(
    @core.container_entry_kind_name(unsafe_entry.entry_kind) == "unsafe",
  )
  assert_true(unsafe_entry.is_encrypted)
  assert_true(
    unsafe_entry.security_findings.map(f => {
      @core.container_security_finding_name(f)
    }) ==
    [
      "path_traversal", "encrypted_entry", "unsupported_compression", "compression_ratio_limit",
    ],
  )
  assert_contains_all(
    @container.container_diagnostic_metric_keys().join("\n"),
    [
      "container_entry_count", "selected_entry_count", "skipped_entry_count", "unsupported_entry_count",
      "asset_count", "total_uncompressed_bytes", "max_compression_ratio_observed",
      "path_traversal_count", "encrypted_entry_count", "unsupported_compression_count",
      "resource_limit_hit", "manifest_seen", "spine_item_count", "nav_seen",
    ],
  )
  assert_contains_all(@container.container_resource_limit_keys().join("\n"), [
    "max_container_entries", "max_total_uncompressed_bytes", "max_single_entry_bytes",
    "max_compression_ratio", "max_nested_archive_depth", "max_selected_inner_documents",
    "max_materialized_assets",
  ])
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
    empty.diagnostics.metrics.get("readiness_status") == Some("near_ready"),
  )

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
    result.diagnostics.metrics.get("readiness_status") == Some("near_ready"),
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
  let blocks = parsed.block_stream.unwrap_or([])
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
  let document = (@pipeline.default_ir_builder().build)(
    @core.IRInput::BlockStream(blocks),
  )
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
  let blocks = parsed.block_stream.unwrap_or([])
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
  let document = (@pipeline.default_ir_builder().build)(
    @core.IRInput::BlockStream(blocks),
  )
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
  let blocks = parsed.block_stream.unwrap_or([])
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
  let document = (@pipeline.default_ir_builder().build)(
    @core.IRInput::BlockStream(blocks),
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
  let blocks = parsed.block_stream.unwrap_or([])
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
    csv.diagnostics.metrics.get("readiness_status") == Some("near_ready"),
  )

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
  let blocks = parsed.block_stream.unwrap_or([])
  let document = (@pipeline.default_ir_builder().build)(
    @core.IRInput::BlockStream(blocks),
  )
  let document = @pipeline.run_pipeline(
    @pipeline.default_pass_pipeline(),
    document,
    @pipeline.make_pass_context(false, "balanced"),
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
test "product main cli now shells directly into root cli and legacy shell stays sealed" {
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
test "root package manifests avoid legacy convert and old core runtime dependencies" {
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
  let xml_pkg = read_utf8_text("formats/xml/moon.pkg")
  let yaml_pkg = read_utf8_text("formats/yaml/moon.pkg")
  assert_true(json_pkg.contains("ZSeanYves/markitdown/format_readers/json"))
  assert_true(xml_pkg.contains("ZSeanYves/markitdown/format_readers/xml"))
  assert_true(yaml_pkg.contains("ZSeanYves/markitdown/format_readers/yaml"))
  assert_true(!formats_pkg.contains("ZSeanYves/markitdown/convert/json"))
  assert_true(!formats_pkg.contains("ZSeanYves/markitdown/convert/xml"))
  assert_true(!formats_pkg.contains("ZSeanYves/markitdown/convert/yaml"))
  let json_impl = read_utf8_text("formats/json/parser.mbt")
  let xml_impl = read_utf8_text("formats/xml/parser.mbt")
  assert_true(!json_impl.contains("@oldjson"))
  assert_true(!json_impl.contains("@legacy"))
  assert_true(!json_impl.contains("convert/json"))
  assert_true(!xml_impl.contains("@legacy"))
  assert_true(!xml_impl.contains("convert/xml"))
  let yaml_impl = read_utf8_text("formats/yaml/parser.mbt")
  assert_true(yaml_impl.contains("@dyaml.parse_yaml_structure_document"))
  assert_true(!yaml_impl.contains("convert/yaml"))
  let render_impl = read_utf8_text("render/render.mbt")
  assert_true(!render_impl.contains("emitter_markdown"))
  let cli_impl = read_utf8_text("cli/cli.mbt")
  assert_true(!cli_impl.contains("@clisup"))
  let container_pkg = read_utf8_text("container/moon.pkg")
  let container_impl = read_utf8_text("container/contracts.mbt")
  let office_pkg = read_utf8_text("format_readers/ooxml/shared/moon.pkg")
  let office_impl = read_utf8_text("format_readers/ooxml/shared/shared.mbt")
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
  let zip_parser = read_utf8_text("formats/zip/parser.mbt")
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
    "zip_raw_fallback", "legacy_dispatcher_used", "convert_zip_used",
  ])
}

///|
test "root runtime and exposed parser foundations stay free of legacy runtime imports" {
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
      "format_readers/text/moon.pkg", "format_readers/text/text_types.mbt", "format_readers/text/text_parser.mbt",
      "format_readers/text/text_inspect.mbt", "format_readers/text/text_profile_internal.mbt",
      "format_readers/csv/moon.pkg", "format_readers/csv/csv_types.mbt", "format_readers/csv/csv_parser.mbt",
      "format_readers/csv/csv_inspect.mbt", "format_readers/tsv/moon.pkg", "format_readers/tsv/tsv_parser.mbt",
      "format_readers/json/moon.pkg", "format_readers/json/json_types.mbt", "format_readers/json/json_parser.mbt",
      "format_readers/json/json_inspect.mbt", "format_readers/json/json_profile_internal.mbt",
      "format_readers/xml/moon.pkg", "format_readers/xml/xml_types.mbt", "format_readers/xml/xml_tokenizer.mbt",
      "format_readers/xml/xml_parser.mbt", "format_readers/xml/xml_inspect.mbt",
      "format_readers/yaml/moon.pkg", "format_readers/yaml/yaml_types.mbt", "format_readers/yaml/yaml_parser.mbt",
      "format_readers/yaml/yaml_inspect.mbt", "format_readers/yaml/yaml_profile_internal.mbt",
      "format_readers/html/moon.pkg", "format_readers/html/html_types.mbt", "format_readers/html/html_guards.mbt",
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
test "cli package stays isolated from legacy layers and calls root convert" {
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
test "zip parser stays on container plan archive entry contracts even when stream mode is requested" {
  let parsed = default_registry_parse(
    @input.input_from_path("samples/main_process/zip/zip_basic_structured.zip"),
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
    Some(_) => fail("zip parse result must not expose a block stream")
    None => ()
  }
  match parsed.document {
    Some(_) => fail("zip parse result must not expose a document IR directly")
    None => ()
  }
  match parsed.container_manifest {
    Some(_) => fail("zip parse result must not expose a container manifest")
    None => ()
  }
  let plan = unwrap_container_plan(parsed, "zip basic structured")
  assert_true(plan.container_format == "zip")
  assert_metric_eq(parsed.diagnostics, "requested_mode", "streaming_event")
  assert_metric_eq(parsed.diagnostics, "effective_mode", "container_recursive")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "container_plan")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "archive_entry")
  assert_metric_eq(parsed.diagnostics, "streaming_fallback", "false")
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "zip_streaming_fallback=deferred", "zip_raw_fallback", "zip_legacy_fallback",
  ])
}

///|
test "zip parser keeps root-pipeline inner dispatch core block output and merged source refs" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/zip/zip_mixed_supported_entries.zip",
    ),
    @input.DetectedFormat::Zip,
  )
  let plan = unwrap_container_plan(parsed, "zip mixed supported entries")
  assert_true(plan.container_format == "zip")
  assert_true(plan.inner_documents_to_convert.length() == 5)
  assert_true(plan.assets_to_materialize.length() == 0)
  let formats = plan.inner_documents_to_convert.map(inner => {
    inner.explicit_detected_format.unwrap_or("")
  })
  assert_contains_all(formats.join("\n"), [
    "markdown", "json", "html", "csv", "txt",
  ])
  let source_names = plan.inner_documents_to_convert.map(inner => {
    inner.source_name
  })
  assert_contains_all(source_names.join("\n"), [
    "zip_mixed_supported_entries.zip::alpha/readme.md", "zip_mixed_supported_entries.zip::beta/info.json",
    "zip_mixed_supported_entries.zip::delta/page.html", "zip_mixed_supported_entries.zip::gamma/data.csv",
    "zip_mixed_supported_entries.zip::zeta/notes.txt",
  ])
  assert_contains_all(parsed.diagnostics.pass_trace.join("\n"), [
    "parse:zip_container_parser", "parse:markdown_parser", "parse:json_parser", "parse:html_parser",
    "parse:csv_parser", "parse:txt_parser",
  ])
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "legacy dispatcher", "convert/html", "convert/markdown", "convert/zip_core",
    "zip_raw_fallback", "zip_legacy_fallback",
  ])
  let entry_heading = match
    find_block_in_tree(
      plan.merged_blocks,
      @core.BlockKind::Heading,
      "alpha/readme.md",
    ) {
    Some(block) => block
    None => fail("missing archive entry heading block for alpha/readme.md")
  }
  let inner_heading = match
    find_block_in_tree(plan.merged_blocks, @core.BlockKind::Heading, "Alpha") {
    Some(block) => block
    None => fail("missing inner markdown heading block for alpha/readme.md")
  }
  assert_true(block_tree_has_kind(plan.merged_blocks, @core.BlockKind::Table))
  assert_true(
    !block_tree_contains_text_fragment(plan.merged_blocks, "# alpha/readme.md"),
  )
  assert_true(
    !block_tree_contains_text_fragment(plan.merged_blocks, "| --- | --- |"),
  )
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
    "samples/main_process/zip/zip_basic_structured.zip",
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
    result.diagnostics.metrics.get("ir_input_kind") == Some("container_plan"),
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
    "zip_legacy_fallback", "zip_raw_fallback", "legacy_dispatcher_used", "convert_zip_used",
  ])
}

///|
test "epub foundation contract reuses active epub and zip readers plus root html without retired bridges" {
  let formats_pkg = read_utf8_text("formats/moon.pkg")
  let epub_pkg = read_utf8_text("formats/epub/moon.pkg")
  let html_pkg = read_utf8_text("formats/html/moon.pkg")
  let cli_pkg = read_utf8_text("cli/moon.pkg")
  let registry_impl = read_utf8_text("formats/registry.mbt")
  let epub_parser = read_utf8_text("formats/epub/parser.mbt")
  let runtime_impl = read_utf8_text("runtime/runtime.mbt")
  let epub_reader_pkg = read_utf8_text("format_readers/epub/moon.pkg")
  let zip_reader_pkg = read_utf8_text("format_readers/zip/moon.pkg")
  assert_contains_all(formats_pkg, [
    "ZSeanYves/markitdown/formats/epub", "ZSeanYves/markitdown/formats/html",
  ])
  assert_contains_all(epub_pkg, [
    "ZSeanYves/markitdown/format_readers/epub", "ZSeanYves/markitdown/runtime",
  ])
  assert_contains_all(html_pkg, [
    "ZSeanYves/markitdown/format_readers/html", "ZSeanYves/markitdown/pipeline",
  ])
  assert_contains_all(cli_pkg, ["ZSeanYves/markitdown/format_readers/zip"])
  assert_contains_all(epub_reader_pkg, [
    "ZSeanYves/markitdown/format_readers/zip",
  ])
  assert_contains_all(zip_reader_pkg, ["bikallem/compress/flate"])
  assert_contains_all(registry_impl, [
    "@input.DetectedFormat::Epub", "@fepub.epub_container_parser(fn() { builtin_registry() })",
    "@input.DetectedFormat::Html", "@fhtml.html_lite_parser()",
  ])
  assert_contains_all(epub_parser, [
    "@depub.open_epub_package", "@depub.inspect_epub_package", "@depub.read_part_bytes",
    "registry_provider", "@runtime.parse_child_to_document",
  ])
  assert_contains_all(runtime_impl, [
    "pub fn parse_child_to_document", "@parser.registry_parse(registry, source, inner_context)",
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
    "epub_legacy_fallback", "legacy_dispatcher_used", "convert_epub_used", "convert_html_used",
  ])
}

///|
test "epub parser stays on container plan spine item contracts even when stream mode is requested" {
  let parsed = default_registry_parse(
    @input.input_from_path("samples/main_process/epub/epub_basic_package.epub"),
    @input.DetectedFormat::Epub,
    requested_mode=Some(@parser.ParserMode::StreamingEvent),
  )

  assert_true(parsed.parser_name == "epub_container_parser")
  assert_true(parsed.mode == @parser.ParserMode::ContainerRecursive)
  assert_true(
    parsed.capabilities.parser_mode == @parser.ParserMode::ContainerRecursive,
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
    Some(_) => fail("epub parse result must not expose a block stream")
    None => ()
  }
  match parsed.document {
    Some(_) => fail("epub parse result must not expose a document IR directly")
    None => ()
  }
  match parsed.container_manifest {
    Some(_) => fail("epub parse result must not expose a container manifest")
    None => ()
  }
  let plan = unwrap_container_plan(parsed, "epub basic package")
  assert_true(plan.container_format == "epub")
  assert_metric_eq(parsed.diagnostics, "requested_mode", "streaming_event")
  assert_metric_eq(parsed.diagnostics, "effective_mode", "container_recursive")
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "container_plan")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "epub_spine_item")
  assert_metric_eq(parsed.diagnostics, "streaming_fallback", "false")
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "epub_streaming_fallback=deferred", "epub_raw_fallback", "epub_legacy_fallback",
  ])
}

///|
test "epub parser preserves opf spine order and root html source refs without parser markdown emission" {
  let parsed = default_registry_parse(
    @input.input_from_path("samples/main_process/epub/epub_spine_order.epub"),
    @input.DetectedFormat::Epub,
  )
  let plan = unwrap_container_plan(parsed, "epub spine order")
  assert_true(plan.container_format == "epub")
  assert_true(plan.inner_documents_to_convert.length() == 2)
  let source_names = plan.inner_documents_to_convert.map(inner => {
    inner.source_name
  })
  assert_eq(source_names[0], "epub_spine_order.epub::OPS/text/chapter-02.xhtml")
  assert_eq(source_names[1], "epub_spine_order.epub::OPS/text/chapter-01.xhtml")
  let entry_paths = plan.ordered_entries.map(entry => entry.entry_path)
  assert_eq(entry_paths[0], "OPS/text/chapter-02.xhtml")
  assert_eq(entry_paths[1], "OPS/text/chapter-01.xhtml")
  let block_texts = flatten_block_texts(plan.merged_blocks)
  assert_ordered_strings(block_texts, "Chapter Two", "Chapter One")
  assert_true(
    !block_tree_contains_text_fragment(plan.merged_blocks, "# Chapter Two"),
  )
  assert_true(
    !block_tree_contains_text_fragment(plan.merged_blocks, "# Chapter One"),
  )
  let chapter_two = match
    find_block_in_tree(
      plan.merged_blocks,
      @core.BlockKind::Heading,
      "Chapter Two",
    ) {
    Some(block) => block
    None => fail("missing chapter two heading block")
  }
  let chapter_one = match
    find_block_in_tree(
      plan.merged_blocks,
      @core.BlockKind::Heading,
      "Chapter One",
    ) {
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
    "parse:epub_container_parser", "parse:html_parser",
  ])
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "legacy dispatcher", "convert/html", "convert/epub", "epub_raw_fallback", "epub_legacy_fallback",
  ])
}

///|
test "epub parser keeps missing and unsupported spine diagnostics root-pipeline and renderer owned" {
  let missing = convert_path(
    "samples/main_process/epub/epub_spine_missing_item_boundary.epub",
    format=Some(@input.DetectedFormat::Epub),
  )
  assert_true(missing.content.contains("# (missing manifest item #0: missing)"))
  assert_true(
    missing.content.contains(
      "> Skipped: spine item references missing manifest item: missing",
    ),
  )
  assert_metric_eq(missing.diagnostics, "effective_mode", "container_recursive")
  assert_metric_eq(missing.diagnostics, "ir_input_kind", "container_plan")
  assert_metric_eq(missing.diagnostics, "event_granularity", "epub_spine_item")
  assert_metric_eq(missing.diagnostics, "missing_manifest_item_count", "1")
  assert_metric_eq(missing.diagnostics, "missing_spine_item_count", "1")
  assert_metric_eq(missing.diagnostics, "selected_entry_count", "1")
  assert_metric_eq(missing.diagnostics, "skipped_entry_count", "1")
  assert_true(missing.diagnostics.fallback_trace.length() > 0)
  assert_diagnostics_lists_contain_none(missing.diagnostics, [
    "epub_legacy_fallback", "convert_epub_used", "convert_html_used",
  ])

  let unsupported = convert_path(
    "samples/main_process/epub/epub_unsupported_spine_warning.epub",
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
    "samples/main_process/epub/epub_remote_data_image_boundary.epub",
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
test "public gates and docs stay aligned on the markdown-restored main cli surface" {
  assert_file_contains_all("cli/cli.mbt", [
    "\"txt\"", "\"csv\"", "\"tsv\"", "\"json\"", "\"jsonl\"", "\"ndjson\"", "\"xml\"",
    "\"yaml\"", "\"yml\"", "\"html\"", "\"htm\"", "\"markdown\"", "\"md\"", "\"zip\"",
    "\"xlsx\"", "\"pptx\"", "\"epub\"", "\"docx\"", "\"pdf\"", "Supported product formats: txt, csv, tsv, json, jsonl, ndjson, xml, yaml, yml, html, htm, markdown, md, zip, epub, docx, xlsx, pptx, pdf",
    "PDF OCR is not supported", "DetectedFormat::Pdf",
  ])
  assert_file_contains_all("samples/check.sh", [
    "SUPPORTED_FORMATS=(\"txt\" \"csv\" \"tsv\" \"json\" \"jsonl\" \"ndjson\" \"xml\" \"yaml\" \"html\" \"markdown\" \"zip\" \"epub\" \"docx\" \"xlsx\" \"pptx\" \"pdf\")",
    "txt, csv, tsv, json, jsonl, ndjson, xml, yaml, html, markdown, zip, epub, docx, xlsx, pptx, and pdf",
    "no legacy fallback",
  ])
  assert_file_contains_all("samples/helpers/contracts/check_cli_contract.sh", [
    "txt csv tsv json jsonl ndjson xml yaml html markdown zip epub docx xlsx pptx and pdf succeed through main product cli",
    "markdown_frontmatter_passthrough.markdown", "zip_basic_structured.zip", "docx",
    "sheet_simple.xlsx", "pptx_hidden_slide_basic.pptx", "pdf", "PDF OCR is not supported",
  ])
  assert_file_contains_all("samples/helpers/contracts/check_zip_contract.sh", [
    "main cli zip markdown output stays root pipeline", "zip_html_local_image.zip",
    "format_readers/zip", "bikallem/compress/flate", "convert/zip_core", "zip_legacy_fallback",
    "legacy_dispatcher_used",
  ])
  assert_file_contains_none("samples/helpers/contracts/check_zip_contract.sh", [
    "resolve_markitdown_zip_cli", "run_markitdown_zip_cli",
  ])
  assert_file_contains_all(
    "samples/helpers/contracts/check_samples_check_contract.sh",
    [
      "formats=txt,csv,tsv,json,jsonl,ndjson,xml,yaml,html,markdown,zip,epub,docx,xlsx,pptx,pdf",
      "formats=markdown", "formats=docx", "formats=xlsx", "formats=pptx", "formats=pdf",
    ],
  )
  assert_file_contains_all("README.md", [
    "InputSource", "ParserRegistry", "ParseResult", "Renderer", "`txt`", "`csv`",
    "`tsv`", "`json`", "`jsonl`", "`ndjson`", "`xml`", "`yaml`", "`yml`", "`html`",
    "`htm`", "`markdown`", "`md`", "`zip`", "`epub`", "`docx`", "`xlsx`", "`pptx`",
    "`pdf`", "native-text PDFs", "pdf --ocr", "Unsupported formats fail closed",
    "samples/helpers/contracts/check_root_contracts.sh", "markitdown-quality-lab/",
  ])
  assert_file_contains_all("README.mbt.md", [
    "Core IR", "Renderer", "`input`", "`parser`", "`formats`", "`runtime`", "`pipeline`",
    "`render`", "`convert`", "`pdf`", "native-text PDFs", "moon test tests", "samples/check_quality.sh",
  ])
  assert_file_contains_all("samples/README.md", [
    "samples/main_process/", "samples/check.sh", "samples/check_quality.sh", "check_root_contracts.sh",
    "`txt`", "`csv`", "`tsv`", "`json`", "`jsonl`", "`ndjson`", "`xml`", "`yaml`",
    "`html`", "`markdown`", "`zip`", "`epub`", "`docx`", "`xlsx`", "`pptx`", "`pdf`",
    "native-text baseline", "expected_next/",
  ])
  assert_file_contains_all("tests/README.md", [
    "moon test tests", "negative assertions", "architecture guard",
  ])
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
test "shared child runtime exposes parse result lowering and child dispatch entrypoints" {
  let empty = @parser.parse_result_with_document(
    "test_runtime",
    @parser.ParserMode::DocumentModel,
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
  let render_impl = read_utf8_text("render/render.mbt")
  let runtime_pkg = read_utf8_text("runtime/moon.pkg")
  let runtime_impl = read_utf8_text("runtime/runtime.mbt")
  let zip_impl = read_utf8_text("formats/zip/parser.mbt")
  let epub_impl = read_utf8_text("formats/epub/parser.mbt")
  let docx_impl = read_utf8_text("formats/docx/parser.mbt")
  let core_impl = read_utf8_text("core/core.mbt")

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
  assert_true(pipeline_impl.contains("pub fn blocks_to_event_stream"))
  assert_true(pipeline_impl.contains("ir_event_encoding"))

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
  assert_true(epub_impl.contains("@runtime.parse_child_to_document"))
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
  assert_true(docx_impl.contains("render_literal"))
  assert_true(docx_impl.contains("join(\"<br>\")"))

  assert_true(core_impl.contains("pub(all) struct SourceMapEntry"))
  assert_true(core_impl.contains("pub(all) struct SourceMap"))
  assert_true(core_impl.contains("source_map : SourceMap?"))
  assert_true(core_impl.contains("pub fn empty_source_map()"))
  assert_true(core_impl.contains("pub fn document_with_source_map"))
  assert_true(core_impl.contains("pub fn make_signal("))
  assert_true(core_impl.contains("SignalType::RenderHint"))
  assert_true(core_impl.contains("SignalType::NoteRef"))
  assert_true(core_impl.contains("SignalType::CommentRef"))
}

///|
