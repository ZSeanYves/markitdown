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
test "convert contract threads OCR intent through fail-closed image branches" {
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
    "samples/main_process/pdf/markdown/text_simple.pdf",
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
    "samples/main_process/pdf/markdown/root_native_text_baseline.pdf",
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
test "builtin registry wires pdf native text parser through the active registry" {
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
        "samples/main_process/pdf/markdown/text_simple.pdf",
        Some(@input.DetectedFormat::Pdf),
      ),
      @parser.new_parse_context(@input.DetectedFormat::Pdf),
    ) {
    Ok(result) => {
      let document = result.document.unwrap_or(@core.empty_document_ir())
      assert_true(document.blocks.length() >= 3)
      assert_true(
        document.diagnostics.metrics.get("pdf_native_parser_gate") ==
        Some("enabled"),
      )
    }
    Err(msg) => fail("pdf registry parse should succeed: " + msg)
  }
}

///|
test "pdf explicit disable policy can still force fail-closed registry behavior" {
  let source = @input.input_from_path_with_format(
    "samples/main_process/pdf/markdown/text_simple.pdf",
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
      let document = final_document_from_parse_result(parsed)
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
        "samples/main_process/pdf/markdown/text_simple.pdf",
        Some(@input.DetectedFormat::Pdf),
      ),
      @parser.new_parse_context(@input.DetectedFormat::Pdf),
    ) {
    Ok(parsed) => {
      let registry_document = parsed.document.unwrap_or(
        @core.empty_document_ir(),
      )
      assert_true(registry_document.blocks.length() >= 3)
    }
    Err(msg) => fail("pdf registry parse should succeed: " + msg)
  }
}

///|
test "pdf native parser internal policy stays opt-in and default product markdown stays unchanged" {
  let source = @input.input_from_path_with_format(
    "samples/main_process/pdf/markdown/root_native_text_baseline.pdf",
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
  let default_document = final_document_from_parse_result(default_parsed)
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
  let internal_document = final_document_from_parse_result(internal_parsed)
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
test "root image parser reserves explicit OCR mode without wiring a provider" {
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
    Ok(_) => fail("default OCR path should stay fail closed")
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
      fail("explicit OCR path should still fail until provider wiring exists")
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
    Ok(_) => fail("disabled OCR path should stay fail closed")
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
test "public gates and docs stay aligned on the main cli surface" {
  assert_file_contains_all("cli/cli.mbt", [
    "Supported product formats: txt, csv, tsv, json, jsonl, ndjson, xml, yaml, yml, html, htm, markdown, md, zip, epub, docx, xlsx, pptx, pdf",
    "PDF OCR is not supported", "DetectedFormat::Pdf", "cli_is_supported_format",
  ])
  assert_file_contains_all("samples/check.sh", [
    "SUPPORTED_FORMATS=(\"txt\" \"csv\" \"tsv\" \"json\" \"jsonl\" \"ndjson\" \"xml\" \"yaml\" \"html\" \"markdown\" \"zip\" \"epub\" \"docx\" \"xlsx\" \"pptx\" \"pdf\")",
    "txt, csv, tsv, json, jsonl, ndjson, xml, yaml, html, markdown, zip, epub, docx, xlsx, pptx, and pdf",
    "main CLI gate",
  ])
  assert_file_contains_all("samples/helpers/contracts/check_cli_contract.sh", [
    "txt csv tsv json jsonl ndjson xml yaml html markdown zip epub docx xlsx pptx and pdf succeed through main product cli",
    "markdown_frontmatter_passthrough.markdown", "zip_basic_structured.zip", "docx",
    "sheet_simple.xlsx", "pptx_hidden_slide_basic.pptx", "pdf", "PDF OCR is not supported",
    "help and version expose main cli product surface", "--pdf-cleanup none|conservative",
    "--pdf-tables none|simple", "PDF cleanup and simple table reconstruction are explicit opt-in product options",
  ])
  assert_file_contains_all("samples/helpers/contracts/check_zip_contract.sh", [
    "main cli zip markdown output stays root pipeline", "zip_html_local_image.zip",
    "format_readers/zip", "bikallem/compress/flate",
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
    "EPUB support is implemented through `format_readers/epub` on top of `format_readers/zip`",
  ])
  assert_file_contains_all("README.mbt.md", [
    "Core IR", "Renderer", "`input`", "`parser`", "`formats`", "`runtime`", "`pipeline`",
    "`render`", "`convert`", "`pdf`", "native-text PDFs", "moon test tests", "samples/check_quality.sh",
  ])
  assert_file_contains_all("samples/check.sh", [
    "--markdown", "--rag", "--assets", "--check-inventory", "--list-inventory", "samples/main_process",
    "txt, csv, tsv, json, jsonl, ndjson, xml, yaml, html, markdown, zip, epub, docx, xlsx, pptx, and pdf",
  ])
  assert_file_contains_all(
    "samples/helpers/contracts/check_root_contracts.sh",
    [
      "check_cli_contract.sh", "check_samples_check_contract.sh", "check_quality_contract.sh",
    ],
  )
}
