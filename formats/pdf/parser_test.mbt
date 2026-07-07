///|
test "pdf native bbox helpers keep geometry contracts stable" {
  let left = make_pdf_bbox(10.0, 20.0, 30.0, 40.0)
  let right = make_pdf_bbox(25.0, 15.0, 35.0, 20.0)
  assert_eq(pdf_bbox_right(left), 40.0)
  assert_eq(pdf_bbox_bottom(left), 60.0)
  assert_true(!pdf_bbox_is_empty(left))
  assert_true(pdf_bbox_is_empty(make_pdf_bbox(0.0, 0.0, 0.0, 5.0)))
  let merged = pdf_union_bbox(left, right)
  assert_eq(merged.x, 10.0)
  assert_eq(merged.y, 15.0)
  assert_eq(merged.width, 50.0)
  assert_eq(merged.height, 45.0)
}

///|
test "pdf native model constructors stay parser-owned and markdown-free" {
  let geometry = make_pdf_page_geometry(1, 612.0, 792.0)
  let bbox = make_pdf_bbox(10.0, 20.0, 30.0, 40.0)
  let span = make_pdf_native_text_span(
    "MoonBit",
    bbox,
    source_ref=Some(@core.empty_source_ref()),
    confidence=Some(95),
    reading_order_index=Some(1),
  )
  let line = make_pdf_native_text_line(
    [span],
    bbox,
    reading_order_index=Some(1),
  )
  let block = make_pdf_native_text_block(
    [line],
    bbox,
    reading_order_index=Some(1),
  )
  let image = make_pdf_native_image_candidate(bbox, reading_order_index=Some(2))
  let link = make_pdf_native_link_candidate(
    bbox,
    "https://example.com",
    text=Some("ref"),
  )
  let table = make_pdf_native_table_candidate(
    bbox,
    row_count=Some(2),
    column_count=Some(3),
    cell_bboxes=[bbox],
  )
  let artifact = make_pdf_native_artifact_candidate(
    "header_footer_candidate", bbox,
  )
  let page = make_pdf_native_page(
    geometry,
    text_blocks=[block],
    image_candidates=[image],
    link_candidates=[link],
    table_candidates=[table],
    artifact_candidates=[artifact],
  )
  let document = make_pdf_native_document(
    pages=[page],
    metadata=Map([("producer", @core.JsonValue::String("test"))]),
  )
  assert_eq(document.pages.length(), 1)
  assert_eq(document.pages[0].text_blocks.length(), 1)
  assert_eq(document.pages[0].text_blocks[0].lines[0].spans[0].text, "MoonBit")
  assert_eq(document.pages[0].link_candidates[0].href, "https://example.com")
  assert_eq(document.pages[0].table_candidates[0].cell_bboxes.length(), 1)
  match document.metadata.get("producer") {
    Some(@core.JsonValue::String(value)) => assert_eq(value, "test")
    _ => fail("expected producer metadata string")
  }
}

///|
test "pdf native parser default policy exposes stable capability and diagnostics" {
  let capability = pdf_native_parser_capability()
  assert_true(capability.parser_mode == @parser.ParserMode::PageSinglePass)
  assert_true(!capability.supports_streaming)
  assert_true(
    capability.streaming_granularity == @parser.StreamingGranularity::Page,
  )
  assert_true(capability.supports_document_ir)
  assert_true(!capability.produces_text)
  assert_true(capability.produces_layout)
  assert_true(capability.produces_tables)
  assert_true(capability.produces_images)
  assert_true(capability.produces_source_map)

  let source = @input.input_from_path("sample.pdf")
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(@input.DetectedFormat::Pdf),
    Some(@parser.ParserMode::PageSinglePass),
    None,
    None,
    None,
    None,
    false,
  )
  let diagnostics = pdf_native_fail_closed_diagnostics(source, context)
  assert_true(diagnostics.detected_format == Some("pdf"))
  assert_true(diagnostics.parser_name == Some(pdf_native_parser_name()))
  assert_true(
    diagnostics.metrics.get("fallback_reason") ==
    Some("pdf_native_restore_not_enabled"),
  )
  assert_true(
    diagnostics.metrics.get("fallback_reason_kind") ==
    Some("parser_policy_gate"),
  )
  assert_true(
    diagnostics.metrics.get("pdf_native_runtime_policy") ==
    Some("enable_text_restore"),
  )
  assert_true(
    diagnostics.metrics.get("pdf_header_footer_filter_policy") ==
    Some("disabled"),
  )
  assert_true(
    diagnostics.metrics.get("pdf_header_footer_filter_enabled") == Some("false"),
  )
  assert_true(
    diagnostics.metrics.get("pdf_header_footer_removed_count") == Some("0"),
  )
  assert_true(
    diagnostics.metrics.get("pdf_table_reconstruction_policy") ==
    Some("disabled"),
  )
  assert_true(
    diagnostics.metrics.get("pdf_table_reconstruction_enabled") == Some("false"),
  )
  assert_true(
    diagnostics.metrics.get("pdf_table_reconstruction_table_count") == Some("0"),
  )
  assert_true(
    diagnostics.warnings.join("\n").contains("disabled by parser policy"),
  )

  let disabled_context = @parser.parse_context_with_pdf_native_runtime_policy(
    context,
    @parser.PdfNativeRuntimePolicy::DisableTextRestore,
  )
  let parsed = pdf_native_parser_result(source, disabled_context)
  assert_true(parsed.mode == @parser.ParserMode::PageSinglePass)
  assert_true(parsed.parser_name == pdf_native_parser_name())
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_eq(document.blocks.length(), 0)
  assert_true(
    document.diagnostics.metrics.get("pdf_native_parser_gate") ==
    Some("disabled"),
  )

  match (pdf_native_parser().parse)(source, disabled_context) {
    Err(msg) => assert_true(msg == pdf_native_fail_closed_message())
    Ok(_) => fail("pdf parser should stay fail closed behind disable policy")
  }
}

///|
test "pdf native parser default product path can return document ir" {
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(@input.DetectedFormat::Pdf),
    Some(@parser.ParserMode::PageSinglePass),
    None,
    None,
    None,
    None,
    false,
  )
  let source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/pdf/text_simple.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let parsed = pdf_native_parser_result(source, context)
  assert_true(parsed.parser_name == pdf_native_parser_name())
  assert_true(parsed.mode == @parser.ParserMode::PageSinglePass)
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(document.blocks.length() >= 3)
  assert_true(document.blocks[0].text.contains("MarkItDown"))
  assert_true(document.diagnostics.metrics.get("renderer_name") == None)
  assert_true(
    document.diagnostics.metrics.get("pdf_native_parser_gate") ==
    Some("enabled"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_native_runtime_policy") ==
    Some("enable_text_restore"),
  )
  assert_true(
    document.diagnostics.metrics.get("product_path_enabled") == Some("true"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_native_backend") == Some("true"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_native_text_baseline") == Some("true"),
  )
  assert_true(document.diagnostics.metrics.get("pdf_ocr_used") == Some("false"))
  assert_true(
    document.diagnostics.metrics.get("pdf_canonical_pipeline_used") ==
    Some("false"),
  )
  assert_true(
    document.diagnostics.metrics.get("probe_artifact_reused") == Some("false"),
  )
  assert_true(
    document.diagnostics.metrics.get("process_cache_hit") == Some("false"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_empty_text_layer") == Some("false"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_grouping_strategy") ==
    Some("conservative_v1"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_grouping_paragraph_count") is Some(_),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_grouping_line_merge_count") is Some(_),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_header_footer_filter_policy") ==
    Some("disabled"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_header_footer_filter_enabled") ==
    Some("false"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_header_footer_removed_count") ==
    Some("0"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_table_reconstruction_policy") ==
    Some("disabled"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_table_reconstruction_enabled") ==
    Some("false"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_table_reconstruction_table_count") ==
    Some("0"),
  )
  assert_true(
    document.metadata.get("pdf_native_backend") ==
    Some(@core.JsonValue::Bool(true)),
  )
  assert_true(
    document.metadata.get("pdf_native_text_baseline") ==
    Some(@core.JsonValue::Bool(true)),
  )
  assert_true(
    document.metadata.get("pdf_ocr_used") == Some(@core.JsonValue::Bool(false)),
  )
  assert_true(
    document.metadata.get("pdf_canonical_pipeline_used") ==
    Some(@core.JsonValue::Bool(false)),
  )
  assert_true(
    document.metadata.get("pdf_grouping_strategy") ==
    Some(@core.JsonValue::String("conservative_v1")),
  )
  assert_true(document.metadata.get("pdf_grouping_paragraph_count") is Some(_))
  assert_true(document.metadata.get("pdf_link_candidate_count") is Some(_))
  assert_true(
    document.diagnostics.pass_trace.contains("pdf_native:parser_success_path"),
  )
  assert_true(!document.diagnostics.pass_trace.join("\n").contains("pdf_v2"))
  assert_true(!document.diagnostics.pass_trace.join("\n").contains("pdf_debug"))
  match (pdf_native_parser().parse)(source, context) {
    Ok(result) => {
      let ok_document = result.document.unwrap_or(@core.empty_document_ir())
      assert_true(ok_document.blocks.length() >= 3)
      assert_true(ok_document.diagnostics.metrics.get("renderer_name") == None)
      assert_true(
        ok_document.diagnostics.metrics.get("pdf_native_parser_gate") ==
        Some("enabled"),
      )
    }
    Err(msg) => fail("default parser should allow product success path: " + msg)
  }
}

///|
test "pdf native parser explicit disable policy stays fail closed" {
  let context = @parser.parse_context_with_pdf_native_runtime_policy(
    @parser.new_parse_context(@input.DetectedFormat::Pdf),
    @parser.PdfNativeRuntimePolicy::DisableTextRestore,
  )
  let source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/pdf/text_simple.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let parsed = pdf_native_parser_result(source, context)
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_eq(document.blocks.length(), 0)
  assert_true(
    document.diagnostics.metrics.get("fallback_reason") ==
    Some("pdf_native_restore_not_enabled"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_native_runtime_policy") ==
    Some("disable_text_restore"),
  )
  match (pdf_native_parser().parse)(source, context) {
    Err(msg) => assert_true(msg.contains("disabled by parser policy"))
    Ok(_) => fail("disabled parser policy should stay fail closed")
  }
}

///|
test "pdf native parser preserves backend error taxonomy on product path" {
  let context = @parser.parse_context_with_pdf_native_runtime_policy(
    @parser.new_parse_context(@input.DetectedFormat::Pdf),
    @parser.PdfNativeRuntimePolicy::EnableTextRestore,
  )
  let source = @input.input_from_bytes_with_format(
    @utf8.encode("%PDF-1.4\n1 0 obj\n<< /Encrypt 2 0 R >>\nendobj\n%%EOF\n"),
    "encrypted.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let parsed = pdf_native_parser_result(source, context)
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_eq(document.blocks.length(), 0)
  assert_true(
    document.diagnostics.metrics.get("fallback_reason_kind") ==
    Some("encrypted_unsupported"),
  )
  assert_true(
    document.diagnostics.metrics.get("fallback_reason") ==
    Some("pdf_native_encrypted_unsupported"),
  )
  assert_true(document.diagnostics.errors.length() == 1)
  assert_true(
    document.diagnostics.metrics.get("product_path_enabled") == Some("true"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_native_backend") == Some("true"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_native_text_baseline") == Some("true"),
  )
  assert_true(document.diagnostics.metrics.get("pdf_ocr_used") == Some("false"))
  assert_true(
    document.diagnostics.metrics.get("pdf_canonical_pipeline_used") ==
    Some("false"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_empty_text_layer") == Some("false"),
  )
  assert_true(
    document.diagnostics.errors[0].contains("encrypted PDF is unsupported"),
  )
  match (pdf_native_parser().parse)(source, context) {
    Err(msg) => assert_true(msg.contains("encrypted PDF is unsupported"))
    Ok(_) => fail("encrypted PDF should still fail inside the internal gate")
  }
}

///|
test "pdf native unit ir bridge lowers parser-owned facts without direct markdown output" {
  let bbox = make_pdf_bbox(10.0, 20.0, 30.0, 10.0)
  let line = make_pdf_native_text_line(
    [make_pdf_native_text_span("Bridge line", bbox)],
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
  let page = make_pdf_native_page(
    make_pdf_page_geometry(1, 612.0, 792.0),
    text_blocks=[make_pdf_native_text_block([line], bbox)],
    link_candidates=[
      make_pdf_native_link_candidate(
        bbox,
        "https://example.com",
        text=Some("Bridge"),
      ),
    ],
  )
  let diagnostics = @core.empty_diagnostics()
  diagnostics.metrics.set("product_path_enabled", "false")
  let document = pdf_native_document_to_ir(
    make_pdf_native_document(pages=[page], diagnostics~),
  )
  assert_eq(document.blocks.length(), 1)
  assert_eq(document.blocks[0].text, "Bridge line")
  assert_true(
    document.diagnostics.metrics.get("pdf_native_ir_projection") ==
    Some("unit_path"),
  )
  assert_true(document.diagnostics.metrics.get("renderer_name") == None)
  match document.metadata.get("pdf_link_candidates") {
    Some(@core.JsonValue::Array(items)) => assert_eq(items.length(), 1)
    _ => fail("expected metadata-only link candidate preservation")
  }
}

///|
test "pdf native parser keeps stable diagnostics tokens for empty text layer and unsupported feature" {
  let context = @parser.parse_context_with_pdf_native_runtime_policy(
    @parser.new_parse_context(@input.DetectedFormat::Pdf),
    @parser.PdfNativeRuntimePolicy::EnableTextRestore,
  )

  let empty_pdf = [
    "%PDF-1.4", "1 0 obj", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "endobj", "2 0 obj", "<< /Length 5 >>", "stream", "BT ET", "endstream", "endobj",
    "3 0 obj", "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
    "endobj", "4 0 obj", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>", "endobj", "5 0 obj",
    "<< /Type /Catalog /Pages 4 0 R >>", "endobj", "trailer", "<< /Size 6 /Root 5 0 R >>",
    "%%EOF", "",
  ].join("\n")
  let empty_source = @input.input_from_bytes_with_format(
    @utf8.encode(empty_pdf),
    "empty.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let empty_parsed = pdf_native_parser_result(empty_source, context)
  let empty_document = empty_parsed.document.unwrap_or(
    @core.empty_document_ir(),
  )
  assert_true(
    empty_document.diagnostics.metrics.get("fallback_reason_kind") ==
    Some("empty_text_layer"),
  )
  assert_true(
    empty_document.diagnostics.metrics.get("fallback_reason") ==
    Some("pdf_native_empty_text_layer"),
  )
  assert_true(
    empty_document.diagnostics.metrics.get("pdf_empty_text_layer") ==
    Some("true"),
  )
  assert_true(
    empty_document.diagnostics.metrics.get("pdf_ocr_used") == Some("false"),
  )
  assert_true(
    empty_document.diagnostics.metrics.get("pdf_canonical_pipeline_used") ==
    Some("false"),
  )
  assert_true(
    empty_document.diagnostics.metrics.get("pdf_header_footer_filter_policy") ==
    Some("disabled"),
  )
  assert_true(
    empty_document.diagnostics.metrics.get("pdf_table_reconstruction_policy") ==
    Some("disabled"),
  )
  assert_true(
    empty_document.diagnostics.metrics.get("product_path_enabled") ==
    Some("true"),
  )
  assert_true(
    !empty_document.diagnostics.pass_trace.join("\n").contains("pdf_v2"),
  )
  assert_true(
    !empty_document.diagnostics.pass_trace.join("\n").contains("pdf_debug"),
  )
  assert_true(
    !empty_document.diagnostics.errors.join("\n").contains("not configured"),
  )
  assert_true(empty_document.diagnostics.errors[0].contains("empty"))

  let unsupported_filter_pdf = [
    "%PDF-1.4", "1 0 obj", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "endobj", "2 0 obj", "<< /Length 54 /Filter /ASCII85Decode >>", "stream", "BT /F1 12 Tf 1 0 0 1 50 700 Tm (Hello PDF backend) Tj ET",
    "endstream", "endobj", "3 0 obj", "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
    "endobj", "4 0 obj", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>", "endobj", "5 0 obj",
    "<< /Type /Catalog /Pages 4 0 R >>", "endobj", "trailer", "<< /Size 6 /Root 5 0 R >>",
    "%%EOF", "",
  ].join("\n")
  let unsupported_source = @input.input_from_bytes_with_format(
    @utf8.encode(unsupported_filter_pdf),
    "unsupported-feature.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let unsupported_parsed = pdf_native_parser_result(unsupported_source, context)
  let unsupported_document = unsupported_parsed.document.unwrap_or(
    @core.empty_document_ir(),
  )
  assert_true(
    unsupported_document.diagnostics.metrics.get("fallback_reason_kind") ==
    Some("unsupported_feature"),
  )
  assert_true(
    unsupported_document.diagnostics.metrics.get("fallback_reason") ==
    Some("pdf_native_unsupported_feature"),
  )
  assert_true(
    unsupported_document.diagnostics.metrics.get("pdf_empty_text_layer") ==
    Some("false"),
  )
  assert_true(
    unsupported_document.diagnostics.metrics.get(
      "pdf_header_footer_filter_enabled",
    ) ==
    Some("false"),
  )
  assert_true(
    unsupported_document.diagnostics.metrics.get(
      "pdf_table_reconstruction_enabled",
    ) ==
    Some("false"),
  )
  assert_true(
    unsupported_document.diagnostics.errors[0].contains(
      "unsupported PDF stream filter",
    ),
  )
}

///|
test "pdf native parser internal policy stays disabled by default and does not change output" {
  let base_context = @parser.new_parse_context(@input.DetectedFormat::Pdf)
  assert_true(
    @parser.pdf_header_footer_filter_policy_name(
      base_context.pdf_header_footer_filter_policy,
    ) ==
    "disabled",
  )
  assert_true(
    @parser.pdf_table_reconstruction_policy_name(
      base_context.pdf_table_reconstruction_policy,
    ) ==
    "disabled",
  )

  let enabled_like_context = @parser.parse_context_with_pdf_table_reconstruction_policy(
    @parser.parse_context_with_pdf_header_footer_filter_policy(
      base_context,
      @parser.PdfHeaderFooterFilterPolicy::InternalHighConfidenceOnly,
    ),
    @parser.PdfTableReconstructionPolicy::InternalSimpleRowsOnly,
  )
  let source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/pdf/root_native_text_baseline.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let parsed = pdf_native_parser_result(source, enabled_like_context)
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_eq(document.blocks.length(), 1)
  assert_eq(document.blocks[0].text, "Hello PDF")
  assert_true(
    document.diagnostics.metrics.get("pdf_header_footer_filter_policy") ==
    Some("internal_high_confidence_only"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_header_footer_filter_enabled") ==
    Some("true"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_header_footer_removed_count") ==
    Some("0"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_table_reconstruction_policy") ==
    Some("internal_simple_rows_only"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_table_reconstruction_enabled") ==
    Some("true"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_table_reconstruction_table_count") ==
    Some("0"),
  )
}

///|
fn sample_pdf_ocr_context() -> @parser.ParseContext {
  @parser.parse_context_with_limits(
    @parser.parse_context_with_pdf_ocr_policy(
      @parser.parse_context_with_ocr_options(
        @parser.new_parse_context(@input.DetectedFormat::Pdf),
        @parser.explicit_ocr_options(language=Some("eng")),
      ),
      @parser.PdfOcrPolicy::Explicit,
    ),
    Some(@parser.ParserMode::LayoutTwoStage),
    None,
    None,
    None,
    None,
    false,
  )
}

///|
fn sample_pdf_accurate_ocr_context() -> @parser.ParseContext {
  @parser.parse_context_with_limits(
    @parser.parse_context_with_pdf_ocr_policy(
      @parser.parse_context_with_product_modes(
        @parser.parse_context_with_ocr_options(
          @parser.new_parse_context(@input.DetectedFormat::Pdf),
          @parser.default_ocr_options(),
        ),
        @product.FidelityMode::Accurate,
        @product.OutputMode::Markdown,
      ),
      @parser.PdfOcrPolicy::AutoScanned,
    ),
    Some(@parser.ParserMode::LayoutTwoStage),
    None,
    None,
    None,
    None,
    false,
  )
}

///|
fn pdf_test_ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn pdf_test_ensure_dir_tree(path : String) -> Unit raise {
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
    pdf_test_ensure_dir(next)
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
fn fake_pdf_ocr_page(language : String?, label : String) -> @focr.OcrPageModel {
  let tsv = [
    "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
    "5\t1\t1\t1\t1\t1\t10\t10\t20\t10\t95\t" + label,
    "5\t1\t1\t1\t1\t2\t35\t10\t20\t10\t94\tOCR",
    "5\t1\t1\t1\t2\t1\t10\t25\t22\t10\t93\tSample",
    "5\t1\t1\t1\t2\t2\t36\t25\t18\t10\t92\t123",
  ].join("\n")
  let parsed = match @focr.parse_tesseract_tsv(tsv, language~) {
    Ok(value) => value
    Err(err) =>
      abort("expected fake PDF OCR TSV parse success: " + err.to_string())
  }
  parsed.pages[0]
}

///|
fn fake_pdf_ocr_provider(
  expected_language : String?,
  expected_provider_kind? : @focr.OcrProviderKind = @focr.OcrProviderKind::Tesseract,
) -> (@focr.OcrProviderRequest) -> Result[
  @focr.OcrProviderResult,
  @focr.OcrProviderError,
] {
  fn(request : @focr.OcrProviderRequest) {
    if request.provider_kind != expected_provider_kind {
      abort("unexpected PDF OCR provider kind")
    }
    if request.language != expected_language {
      abort("unexpected PDF OCR language")
    }
    let label = if request.image_path.contains("page-2") {
      "Second"
    } else {
      "MoonBit"
    }
    Ok(
      @focr.make_ocr_provider_result(
        [fake_pdf_ocr_page(request.language, label)],
        @focr.ocr_provider_kind_name(request.provider_kind),
      ),
    )
  }
}

///|
fn fake_pdf_rasterizer(
  page_count : Int,
) -> (@input.InputSource) -> Result[
  (PdfRasterResult, String),
  PdfRasterizerError,
] {
  fn(source : @input.InputSource) {
    rasterize_pdf_with_pdftoppm(source, fn(
      _cmd : String,
      args : Array[String],
    ) {
      let output_prefix = args[2]
      let parts = output_prefix
        .split("/")
        .to_array()
        .map(fn(part) { part.to_owned() })
      let output_dir = parts[:parts.length() - 1].join("/")
      pdf_test_ensure_dir_tree(output_dir) catch {
        e =>
          return Err(
            PdfRasterizerError::ExecutionFailed(
              "failed to create fake raster output dir: " + e.to_string(),
            ),
          )
      }
      for i in 0..<page_count {
        let page_name = output_dir + "/page-" + (i + 1).to_string() + ".png"
        @fs.write_bytes_to_file(page_name, Bytes::from_array([])) catch {
          e =>
            return Err(
              PdfRasterizerError::ExecutionFailed(
                "failed to create fake raster page: " + e.to_string(),
              ),
            )
        }
      }
      Ok((0, "", ""))
    })
  }
}

///|
test "pdf OCR route converts a scanned single-page sample through injected raster and OCR contracts" {
  let source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let parsed = match
    pdf_ocr_parser_result(
      source,
      sample_pdf_ocr_context(),
      image_ocr_provider=fake_pdf_ocr_provider(Some("eng")),
      rasterizer=fake_pdf_rasterizer(1),
    ) {
    Ok(value) => value
    Err(err) => fail("expected injected pdf OCR parser success: " + err)
  }
  assert_true(parsed.mode == @parser.ParserMode::LayoutTwoStage)
  assert_true(parsed.parser_name == pdf_ocr_parser_name())
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_eq(document.blocks.length(), 2)
  assert_eq(document.blocks[0].text, "MoonBit OCR")
  assert_eq(document.blocks[1].text, "Sample 123")
  assert_true(document.diagnostics.metrics.get("pdf_ocr_used") == Some("true"))
  assert_true(
    document.diagnostics.metrics.get("pdf_raster_backend") == Some("pdftoppm"),
  )
  assert_true(document.diagnostics.metrics.get("page_count") == Some("1"))
  assert_true(document.diagnostics.metrics.get("ocr_used_pages") == Some("1"))
  assert_true(
    document.diagnostics.metrics.get("pdf_raster_page_failure_count") ==
    Some("0"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_native_text_baseline") ==
    Some("false"),
  )
  assert_true(
    document.diagnostics.pass_trace.contains("pdf_ocr:layout_two_stage"),
  )
}

///|
test "pdf OCR route aggregates multi-page scanned samples without native-text fallback" {
  let source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/pdf/pdf_ocr_two_page.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let parsed = match
    pdf_ocr_parser_result(
      source,
      sample_pdf_ocr_context(),
      image_ocr_provider=fake_pdf_ocr_provider(Some("eng")),
      rasterizer=fake_pdf_rasterizer(2),
    ) {
    Ok(value) => value
    Err(err) =>
      fail("expected injected multi-page pdf OCR parser success: " + err)
  }
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_eq(document.blocks.length(), 4)
  assert_eq(document.blocks[0].text, "MoonBit OCR")
  assert_eq(document.blocks[1].text, "Sample 123")
  assert_eq(document.blocks[2].text, "Second OCR")
  assert_eq(document.blocks[3].text, "Sample 123")
  assert_true(document.diagnostics.metrics.get("page_count") == Some("2"))
  assert_true(document.diagnostics.metrics.get("ocr_used_pages") == Some("2"))
  assert_true(
    document.diagnostics.metrics.get("pdf_raster_page_success_count") ==
    Some("2"),
  )
  assert_true(document.diagnostics.metrics.get("pdf_ocr_used") == Some("true"))
  assert_true(
    !document.diagnostics.degraded_features.contains(
      "pdf_raster_partial_failure",
    ),
  )
  assert_true(
    !document.diagnostics.degraded_features.contains(
      "pdf_ocr_partial_page_failure",
    ),
  )
}

///|
test "pdf OCR parser requires explicit pdf OCR policy even under accurate fidelity" {
  let source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let parsed = match
    pdf_ocr_parser_result(
      source,
      sample_pdf_accurate_ocr_context(),
      image_ocr_provider=fake_pdf_ocr_provider(
        None,
        expected_provider_kind=@focr.OcrProviderKind::PaddleOcr,
      ),
      rasterizer=fake_pdf_rasterizer(1),
    ) {
    Ok(value) => value
    Err(err) =>
      fail("expected explicit pdf OCR policy to override accurate gate: " + err)
  }
  assert_true(parsed.mode == @parser.ParserMode::LayoutTwoStage)
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_eq(document.blocks.length(), 2)
  assert_eq(document.blocks[0].text, "MoonBit OCR")
  assert_eq(document.blocks[1].text, "Sample 123")
  assert_true(document.diagnostics.metrics.get("pdf_ocr_used") == Some("true"))
  assert_true(
    document.diagnostics.metrics.get("pdf_raster_backend") == Some("pdftoppm"),
  )
  assert_true(
    document.diagnostics.metrics.get("ocr_provider_selection_target") ==
    Some("pdf_accurate"),
  )
  assert_true(
    document.diagnostics.metrics.get("ocr_provider_requested_kind") ==
    Some("paddle_ocr"),
  )
  assert_true(
    document.diagnostics.metrics.get("ocr_provider_kind") == Some("paddle_ocr"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_ocr_policy") == Some("auto_scanned"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_ocr_trigger") == Some("auto_scanned"),
  )
}

///|
test "pdf native parser internal header footer filtering removes repeated high confidence lines only when enabled" {
  let header = "Monthly Summary"
  let footer = "Page footer repeated"
  let make_page = fn(page_no : Int, body : String) {
    make_pdf_native_page(make_pdf_page_geometry(page_no, 612.0, 792.0), text_blocks=[
      make_pdf_native_text_block(
        [
          pdf_test_line(
            header,
            40.0,
            760.0,
            width=140.0,
            file_id="hf-internal.pdf",
            page=page_no,
            line=1,
            reading_order_index=Some(1),
          ),
        ],
        make_pdf_bbox(40.0, 760.0, 140.0, 12.0),
        reading_order_index=Some(1),
      ),
      make_pdf_native_text_block(
        [
          pdf_test_line(
            body,
            40.0,
            420.0,
            width=180.0,
            file_id="hf-internal.pdf",
            page=page_no,
            line=2,
            reading_order_index=Some(2),
          ),
        ],
        make_pdf_bbox(40.0, 420.0, 180.0, 12.0),
        reading_order_index=Some(2),
      ),
      make_pdf_native_text_block(
        [
          pdf_test_line(
            footer,
            40.0,
            18.0,
            width=160.0,
            file_id="hf-internal.pdf",
            page=page_no,
            line=3,
            reading_order_index=Some(3),
          ),
        ],
        make_pdf_bbox(40.0, 18.0, 160.0, 12.0),
        reading_order_index=Some(3),
      ),
    ])
  }
  let doc = make_pdf_native_document(pages=[
    make_page(1, "Body paragraph one"),
    make_page(2, "Body paragraph two"),
  ])
  let default_document = pdf_native_document_to_ir(doc)
  assert_eq(
    default_document.blocks.map(block => block.text).join("\n"),
    [header, "Body paragraph one", footer, header, "Body paragraph two", footer].join(
      "\n",
    ),
  )

  let filtered_document = pdf_native_document_to_ir_with_policies(
    doc,
    @parser.PdfHeaderFooterFilterPolicy::InternalHighConfidenceOnly,
    @parser.PdfTableReconstructionPolicy::Disabled,
  )
  assert_eq(filtered_document.blocks.length(), 2)
  assert_eq(
    filtered_document.blocks.map(block => block.text).join("\n"),
    ["Body paragraph one", "Body paragraph two"].join("\n"),
  )
  assert_true(
    filtered_document.diagnostics.metrics.get("pdf_header_footer_removed_count") ==
    Some("4"),
  )
  assert_true(
    filtered_document.diagnostics.metrics.get(
      "pdf_header_footer_removed_candidates",
    ) ==
    Some([header, footer, header, footer].join(" || ")),
  )
  assert_true(
    filtered_document.diagnostics.metrics.get(
      "pdf_header_footer_removed_source_refs",
    )
    is Some(_),
  )
}

///|
test "pdf native parser internal simple table reconstruction lowers stable rows to table blocks only when enabled" {
  let table_doc = make_pdf_native_document(pages=[
    make_pdf_native_page(make_pdf_page_geometry(1, 612.0, 792.0), text_blocks=[
      make_pdf_native_text_block(
        [
          make_pdf_native_text_line(
            [
              make_pdf_native_text_span(
                "Product",
                make_pdf_bbox(40.0, 620.0, 40.0, 12.0),
              ),
              make_pdf_native_text_span(
                " Region",
                make_pdf_bbox(120.0, 620.0, 40.0, 12.0),
              ),
              make_pdf_native_text_span(
                " Status",
                make_pdf_bbox(220.0, 620.0, 40.0, 12.0),
              ),
            ],
            make_pdf_bbox(40.0, 620.0, 220.0, 12.0),
            source_ref=Some(
              pdf_test_source_ref(
                "table-internal.pdf",
                1,
                1,
                pdf_test_core_bbox(40.0, 620.0, 260.0, 632.0),
              ),
            ),
            reading_order_index=Some(1),
          ),
        ],
        make_pdf_bbox(40.0, 620.0, 220.0, 12.0),
        reading_order_index=Some(1),
      ),
      make_pdf_native_text_block(
        [
          make_pdf_native_text_line(
            [
              make_pdf_native_text_span(
                "Alpha",
                make_pdf_bbox(40.0, 602.0, 40.0, 12.0),
              ),
              make_pdf_native_text_span(
                " East",
                make_pdf_bbox(120.0, 602.0, 36.0, 12.0),
              ),
              make_pdf_native_text_span(
                " Open",
                make_pdf_bbox(220.0, 602.0, 36.0, 12.0),
              ),
            ],
            make_pdf_bbox(40.0, 602.0, 216.0, 12.0),
            source_ref=Some(
              pdf_test_source_ref(
                "table-internal.pdf",
                1,
                2,
                pdf_test_core_bbox(40.0, 602.0, 256.0, 614.0),
              ),
            ),
            reading_order_index=Some(2),
          ),
        ],
        make_pdf_bbox(40.0, 602.0, 216.0, 12.0),
        reading_order_index=Some(2),
      ),
      make_pdf_native_text_block(
        [
          make_pdf_native_text_line(
            [
              make_pdf_native_text_span(
                "Beta",
                make_pdf_bbox(40.0, 584.0, 36.0, 12.0),
              ),
              make_pdf_native_text_span(
                " West",
                make_pdf_bbox(120.0, 584.0, 36.0, 12.0),
              ),
              make_pdf_native_text_span(
                " Closed",
                make_pdf_bbox(220.0, 584.0, 52.0, 12.0),
              ),
            ],
            make_pdf_bbox(40.0, 584.0, 232.0, 12.0),
            source_ref=Some(
              pdf_test_source_ref(
                "table-internal.pdf",
                1,
                3,
                pdf_test_core_bbox(40.0, 584.0, 272.0, 596.0),
              ),
            ),
            reading_order_index=Some(3),
          ),
        ],
        make_pdf_bbox(40.0, 584.0, 232.0, 12.0),
        reading_order_index=Some(3),
      ),
      make_pdf_native_text_block(
        [
          pdf_test_line(
            "Body paragraph after table-like rows",
            40.0,
            520.0,
            width=220.0,
            file_id="table-internal.pdf",
            page=1,
            line=4,
            reading_order_index=Some(4),
          ),
        ],
        make_pdf_bbox(40.0, 520.0, 220.0, 12.0),
        reading_order_index=Some(4),
      ),
    ]),
  ])
  let default_document = pdf_native_document_to_ir(table_doc)
  assert_eq(default_document.blocks.length(), 4)
  let reconstructed_document = pdf_native_document_to_ir_with_policies(
    table_doc,
    @parser.PdfHeaderFooterFilterPolicy::Disabled,
    @parser.PdfTableReconstructionPolicy::InternalSimpleRowsOnly,
  )
  assert_eq(reconstructed_document.blocks.length(), 2)
  assert_true(reconstructed_document.blocks[0].kind == @core.BlockKind::Table)
  assert_eq(reconstructed_document.blocks[0].children.length(), 3)
  assert_eq(
    reconstructed_document.blocks[0].children[0].children
    .map(cell => cell.text)
    .join(" | "),
    "Product | Region | Status",
  )
  assert_eq(
    reconstructed_document.blocks[0].children[1].children
    .map(cell => cell.text)
    .join(" | "),
    "Alpha | East | Open",
  )
  assert_eq(
    reconstructed_document.blocks[0].children[2].children
    .map(cell => cell.text)
    .join(" | "),
    "Beta | West | Closed",
  )
  assert_eq(
    reconstructed_document.blocks[1].text,
    "Body paragraph after table-like rows",
  )
  assert_true(
    reconstructed_document.diagnostics.metrics.get(
      "pdf_table_reconstruction_table_count",
    ) ==
    Some("1"),
  )
  assert_true(
    reconstructed_document.diagnostics.metrics.get(
      "pdf_table_reconstruction_source_refs",
    )
    is Some(_),
  )
}
