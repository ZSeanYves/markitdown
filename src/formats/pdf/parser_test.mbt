///|
fn pdf_test_image_only_pdf_bytes() -> Bytes {
  let jpeg_hex = "ffd8ffe000104a46494600010100000000000000ffdb004300030202020202030202020303030304060404040404080606050609080a0a090809090a" +
    "0c0f0c0a0b0e0b09090d110d0e0f101011100a0c12131210130f101010ffdb00430103030304030408040408100b090b101010101010101010101010" +
    "1010101010101010101010101010101010101010101010101010101010101010101010101010ffc00011080001000103011100021101031101ffc400" +
    "14000100000000000000000000000000000009ffc40014100100000000000000000000000000000000ffc40014010100000000000000000000000000" +
    "000005ffc40014110100000000000000000000000000000000ffda000c03010002110311003f003f0e847fffd9>"
  let content = ["q", "32 0 0 24 72 120 cm", "/Im0 Do", "Q", ""].join("\n")
  @utf8.encode(
    [
      "%PDF-1.4",
      "1 0 obj",
      "<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter [ /ASCIIHexDecode /DCTDecode ] /Length " +
      jpeg_hex.length().to_string() +
      " >>",
      "stream",
      jpeg_hex,
      "endstream",
      "endobj",
      "2 0 obj",
      "<< /Length " + content.length().to_string() + " >>",
      "stream",
      content,
      "endstream",
      "endobj",
      "3 0 obj",
      "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 200 200] /Resources << /ProcSet [ /PDF /ImageC ] /XObject << /Im0 1 0 R >> >> /Contents 2 0 R >>",
      "endobj",
      "4 0 obj",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "endobj",
      "5 0 obj",
      "<< /Type /Catalog /Pages 4 0 R >>",
      "endobj",
      "trailer",
      "<< /Size 6 /Root 5 0 R >>",
      "%%EOF",
      "",
    ].join("\n"),
  )
}

///|
fn pdf_parser_test_core_bbox(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @core.BBox {
  { x0, y0, x1, y1 }
}

///|
fn pdf_parser_test_source_ref(
  file_id : String,
  page : Int,
  line : Int,
  bbox : @core.BBox,
) -> @core.SourceRef {
  {
    ..@core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(file_id),
      Some("pdf"),
      Some(line),
      Some(line),
    ),
    page: Some(page),
    bbox: Some(bbox),
  }
}

///|
fn pdf_parser_test_line(
  text : String,
  x : Double,
  y : Double,
  width? : Double = 90.0,
  height? : Double = 12.0,
  file_id? : String = "synthetic.pdf",
  page? : Int = 1,
  line? : Int = 1,
  reading_order_index? : Int? = None,
) -> @dpdfnative.PdfNativeTextLine {
  let bbox = @dpdfnative.make_pdf_bbox(x, y, width, height)
  @dpdfnative.make_pdf_native_text_line(
    [@dpdfnative.make_pdf_native_text_span(text, bbox)],
    bbox,
    source_ref=Some(
      pdf_parser_test_source_ref(
        file_id,
        page,
        line,
        pdf_parser_test_core_bbox(x, y, x + width, y + height),
      ),
    ),
    reading_order_index~,
  )
}

///|
test "pdftoppm png command uses explicit raster baseline" {
  let (_, argv) = build_pdftoppm_png_command(
    "fixtures/input.pdf", ".tmp/pdf_pages",
  )
  assert_eq(argv.length(), 5)
  assert_eq(argv[0], "-r")
  assert_eq(argv[1], "150")
  assert_eq(argv[2], "-png")
  assert_eq(argv[3], "fixtures/input.pdf")
  assert_eq(argv[4], ".tmp/pdf_pages/page")
}

///|
fn pdf_parser_test_accurate_context(
  ocr_options? : @parser.OcrOptions = @parser.explicit_ocr_options(
    language=Some("eng"),
  ),
) -> @parser.ParseContext {
  let base = @parser.parse_context_with_product_modes(
    @parser.new_parse_context(Pdf),
    Accurate,
    Markdown,
  )
  let with_mode = @parser.parse_context_with_limits(
    base,
    Some(LayoutTwoStage),
    None,
    None,
    None,
    None,
    false,
  )
  let with_ocr = @parser.parse_context_with_ocr_options(with_mode, ocr_options)
  let with_header_footer = @parser.parse_context_with_pdf_header_footer_filter_policy(
    with_ocr,
    InternalHighConfidenceOnly,
  )
  @parser.parse_context_with_pdf_table_reconstruction_policy(
    with_header_footer,
    InternalSimpleRowsOnly,
  )
}

///|
test "pdf native parser default product path can return document ir" {
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Pdf),
    Some(PageSinglePass),
    None,
    None,
    None,
    None,
    false,
  )
  let source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/pdf/text_simple.pdf",
    Some(Pdf),
  )
  let parsed = pdf_native_parser_result(source, context)
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(parsed.parser_name == pdf_native_parser_name())
  assert_true(parsed.mode == PageSinglePass)
  assert_true(document.blocks.length() >= 3)
  assert_true(document.blocks[0].text.contains("MarkItDown"))
  assert_true(
    document.diagnostics.metrics.get("pdf_native_parser_gate") ==
    Some("enabled"),
  )
  assert_true(document.diagnostics.metrics.get("pdf_ocr_used") == Some("false"))
  assert_true(
    document.diagnostics.pass_trace.contains("pdf_native:parser_success_path"),
  )
}

///|
test "pdf native parser lowers exportable image xobjects into image assets" {
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Pdf),
    Some(PageSinglePass),
    None,
    None,
    None,
    None,
    false,
  )
  let source = @input.input_from_bytes_with_format(
    pdf_test_image_only_pdf_bytes(),
    "image-only.pdf",
    Some(Pdf),
  )
  let parsed = pdf_native_parser_result(source, context)
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_eq(document.blocks.length(), 1)
  assert_true(document.blocks[0].kind == Image)
  assert_true(
    document.blocks[0].attrs.get("path") == Some("assets/image01.jpg"),
  )
  assert_true(document.assets.length() == 1)
  assert_true(document.assets[0].asset_id == "pdf:1")
  assert_true(document.assets[0].mime_type == Some("image/jpeg"))
  assert_true(document.diagnostics.metrics.get("asset_count") == Some("1"))
}

///|
test "pdf native parser scanned-like inputs stay fail closed with stable diagnostics" {
  let context = @parser.parse_context_with_pdf_native_runtime_policy(
    @parser.new_parse_context(Pdf),
    EnableTextRestore,
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
    Some(Pdf),
  )
  let empty_document = pdf_native_parser_result(empty_source, context).document.unwrap_or(
    @core.empty_document_ir(),
  )
  assert_eq(empty_document.blocks.length(), 0)
  assert_true(
    empty_document.diagnostics.metrics.get("fallback_reason_kind") ==
    Some("empty_text_layer"),
  )
  assert_true(
    empty_document.diagnostics.metrics.get("fallback_reason") ==
    Some("pdf_native_empty_text_layer"),
  )

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
    Some(Pdf),
  )
  let unsupported_document = pdf_native_parser_result(
    unsupported_source, context,
  ).document.unwrap_or(@core.empty_document_ir())
  assert_eq(unsupported_document.blocks.length(), 0)
  assert_true(
    unsupported_document.diagnostics.metrics.get("fallback_reason_kind") ==
    Some("empty_text_layer"),
  )
  assert_true(
    unsupported_document.diagnostics.metrics.get("pdf_empty_text_layer") ==
    Some("true"),
  )
}

///|
test "pdf native parser internal header footer filtering removes repeated high confidence lines only when enabled" {
  let header = "Monthly Summary"
  let footer = "Page footer repeated"
  let make_page = fn(page_no : Int, body : String) {
    @dpdfnative.make_pdf_native_page(
      @dpdfnative.make_pdf_page_geometry(page_no, 612.0, 792.0),
      text_blocks=[
        @dpdfnative.make_pdf_native_text_block(
          [
            pdf_parser_test_line(
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
          @dpdfnative.make_pdf_bbox(40.0, 760.0, 140.0, 12.0),
          reading_order_index=Some(1),
        ),
        @dpdfnative.make_pdf_native_text_block(
          [
            pdf_parser_test_line(
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
          @dpdfnative.make_pdf_bbox(40.0, 420.0, 180.0, 12.0),
          reading_order_index=Some(2),
        ),
        @dpdfnative.make_pdf_native_text_block(
          [
            pdf_parser_test_line(
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
          @dpdfnative.make_pdf_bbox(40.0, 18.0, 160.0, 12.0),
          reading_order_index=Some(3),
        ),
      ],
    )
  }
  let doc = @dpdfnative.make_pdf_native_document(pages=[
    make_page(1, "Body paragraph one"),
    make_page(2, "Body paragraph two"),
  ])
  let default_document = pdf_native_document_to_ir(doc)
  assert_eq(default_document.blocks.length(), 6)

  let filtered_document = pdf_native_document_to_ir_with_policies(
    doc,
    InternalHighConfidenceOnly,
    Disabled,
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
}

///|
test "pdf accurate parser preserves native born-digital facts when OCR is not needed" {
  let source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/pdf/text_simple.pdf",
    Some(Pdf),
  )
  let context = pdf_parser_test_accurate_context(
    ocr_options=@parser.explicit_ocr_options(language=Some("eng")),
  )
  let parsed = match
    pdf_ocr_parser_result(
      source,
      context,
      image_ocr_provider=fn(_request : @focr.OcrProviderRequest) {
        abort("born-digital accurate route should not invoke OCR provider")
      },
      rasterizer=fn(_source : @input.InputSource) {
        abort("born-digital accurate route should not rasterize")
      },
    ) {
    Ok(value) => value
    Err(err) => fail("expected accurate born-digital parse success: " + err)
  }
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(parsed.mode == LayoutTwoStage)
  assert_true(document.blocks.length() >= 3)
  assert_true(document.blocks[0].text.contains("MarkItDown"))
  assert_true(
    document.metadata.get("pdf_page_route_summary") ==
    Some(String("native_text_page=1,hybrid_region_page=0,ocr_page=0")),
  )
  assert_true(
    parsed.diagnostics.metrics.get("provider_invoked") == Some("false"),
  )
  assert_true(
    parsed.diagnostics.metrics.get("ocr_provider_status") ==
    Some("skipped_native_text_only"),
  )
  assert_true(parsed.diagnostics.metrics.get("pdf_ocr_used") == Some("false"))
  assert_true(
    parsed.diagnostics.metrics.get("pdf_native_backend") == Some("true"),
  )
  assert_true(document.metadata.get("format") == Some(String("pdf")))
}
