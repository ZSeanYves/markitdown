///|
fn pdf_parser_wbtest_source_ref(
  page : Int,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @core.SourceRef {
  {
    ..@core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some("hybrid.pdf"),
      Some("pdf"),
      Some(1),
      Some(1),
    ),
    page: Some(page),
    bbox: Some({ x0, y0, x1, y1 }),
  }
}

///|
fn pdf_parser_wbtest_ensure_dir_tree(path : String) -> Unit raise @fs.IOError {
  let normalized = path.trim().to_owned()
  if normalized == "" || normalized == "." || @fs.path_exists(normalized) {
    return
  }
  let parts = normalized.split("/")
  let mut current = if normalized.has_prefix("/") { "/" } else { "" }
  for raw in parts {
    let part = raw.trim().to_owned()
    if part == "" || part == "." {
      continue
    }
    if current == "" || current == "/" {
      current = if current == "/" { "/" + part } else { part }
    } else {
      current = current + "/" + part
    }
    if !@fs.path_exists(current) {
      @fs.create_dir(current)
    }
  }
}

///|
fn pdf_parser_wbtest_fake_rasterizer(
  page_count : Int,
  dir_name : String,
) -> (@input.InputSource) -> Result[
  (PdfRasterResult, String),
  PdfRasterizerError,
] {
  fn(_source : @input.InputSource) {
    let root = ".tmp/tests/formats-pdf/" + dir_name
    pdf_parser_wbtest_ensure_dir_tree(root) catch {
      err => abort("failed to create fake raster temp dir: " + err.to_string())
    }
    let pages : Array[PdfRasterPageArtifact] = []
    for page_index in 0..<page_count {
      pages.push({
        page_index,
        image_path: Some(
          root + "/page-" + (page_index + 1).to_string() + ".png",
        ),
        success: true,
        diagnostics: [],
      })
    }
    Ok(
      (
        { backend_name: "fake-raster", page_count, pages, diagnostics: [] },
        root,
      ),
    )
  }
}

///|
fn pdf_parser_wbtest_fake_ocr_provider(
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
    let parsed = match
      @focr.parse_tesseract_tsv(tsv, language=request.language) {
      Ok(value) => value
      Err(err) =>
        abort("expected fake OCR TSV parse success: " + err.to_string())
    }
    let jobs : Array[@focr.OcrProviderJobResult] = []
    let pages : Array[@focr.OcrPageModel] = []
    for image_path in request.image_paths {
      jobs.push(@focr.make_ocr_provider_job_result(image_path, parsed.pages))
      pages.append(parsed.pages[:])
    }
    Ok(
      @focr.make_ocr_provider_result(
        pages,
        "fake-tesseract",
        provider_version=Some("test"),
        jobs~,
      ),
    )
  }
}

///|
fn pdf_parser_wbtest_accurate_context() -> @parser.ParseContext {
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
  let with_ocr = @parser.parse_context_with_ocr_options(
    with_mode,
    @parser.explicit_ocr_options(language=Some("eng")),
  )
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
test "pdf hybrid page merge keeps native blocks and only appends non-duplicate OCR blocks in scope" {
  let native_blocks = [
    @core.make_block(
      Paragraph,
      "Native body",
      source_ref=pdf_parser_wbtest_source_ref(1, 10.0, 500.0, 120.0, 512.0),
    ),
    @core.make_block(
      Image,
      "image",
      source_ref=pdf_parser_wbtest_source_ref(1, 20.0, 430.0, 80.0, 470.0),
    ),
  ]
  let ocr_blocks = [
    @core.make_block(
      Paragraph,
      "Native body",
      source_ref=pdf_parser_wbtest_source_ref(1, 10.0, 500.0, 120.0, 512.0),
    ),
    @core.make_block(
      Paragraph,
      "Added OCR",
      source_ref=pdf_parser_wbtest_source_ref(1, 15.0, 470.0, 110.0, 482.0),
    ),
    @core.make_block(
      Paragraph,
      "Outside OCR",
      source_ref=pdf_parser_wbtest_source_ref(1, 260.0, 470.0, 340.0, 482.0),
    ),
  ]
  let merged = pdf_region_hybrid_page_blocks(native_blocks, ocr_blocks, {
    page_index: 1,
    route_kind: "hybrid_region_page",
    candidate_regions: [{ x0: 0.0, y0: 420.0, x1: 180.0, y1: 520.0 }],
    low_confidence_text_count: 1,
    native_text_detected: true,
  })
  assert_eq(merged.length(), 3)
  assert_true(merged.any(block => block.text == "Native body"))
  assert_true(merged.any(block => block.text == "Added OCR"))
  assert_true(!merged.any(block => block.text == "Outside OCR"))
  let mut added = @core.make_block(Paragraph, "")
  for block in merged {
    if block.text == "Added OCR" {
      added = block
      break
    }
  }
  assert_true(added.attrs.get("pdf_region_hybrid") == Some("true"))
}

///|
test "PDF native formats pipeline lowers main contract corpus to IR" {
  let paths = [
    "samples/fixtures/contracts/pdf/hardwrap_en.pdf", "samples/fixtures/contracts/pdf/pdf_header_footer_variants_phase15.pdf",
    "samples/fixtures/contracts/pdf/pdf_metadata_table_like.pdf", "samples/fixtures/contracts/pdf/pdf_metadata_uri_link.pdf",
    "samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf", "samples/fixtures/contracts/pdf/pdf_ocr_two_page.pdf",
    "samples/fixtures/contracts/pdf/pdf_simple_table_like.pdf", "samples/fixtures/contracts/pdf/root_native_text_baseline.pdf",
    "samples/fixtures/contracts/pdf/text_multipage.pdf", "samples/fixtures/contracts/pdf/text_simple.pdf",
  ]
  let parser = pdf_native_parser()
  let context = @parser.new_parse_context(Pdf)
  let mut succeeded = 0
  let mut failed = 0
  let mut blocks = 0
  let mut assets = 0
  for path in paths {
    match (parser.parse)(@input.input_from_path(path), context) {
      Ok(result) => {
        succeeded += 1
        let document = result.document.unwrap()
        blocks += document.blocks.length()
        assets += document.assets.length()
        assert_true(
          result.diagnostics.metrics.get("pdf_native_backend") is Some(_),
        )
      }
      Err(error) => {
        failed += 1
        assert_true(error != "")
      }
    }
  }
  assert_true(succeeded >= 8)
  assert_true(blocks > 0)
  assert_true(assets >= 0)
  assert_eq(succeeded + failed, paths.length())
}

///|
test "pdf accurate parser scanned route keeps OCR metrics and succeeds with injected runtime" {
  let parsed = match
    pdf_ocr_parser_result(
      @input.input_from_path_with_format(
        "samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf",
        Some(Pdf),
      ),
      pdf_parser_wbtest_accurate_context(),
      image_ocr_provider=pdf_parser_wbtest_fake_ocr_provider(Some("eng")),
      rasterizer=pdf_parser_wbtest_fake_rasterizer(1, "scanned-accurate"),
    ) {
    Ok(value) => value
    Err(err) => fail("expected accurate scanned parse success: " + err)
  }
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(document.blocks.length() >= 2)
  assert_true(document.blocks.any(block => block.text.contains("MoonBit OCR")))
  assert_true(parsed.diagnostics.metrics.get("pdf_ocr_used") == Some("true"))
  assert_true(
    parsed.diagnostics.metrics.get("ocr_provider_status") == Some("success"),
  )
  assert_true(
    parsed.diagnostics.metrics.get("pdf_raster_backend") == Some("fake-raster"),
  )
  assert_true(
    parsed.diagnostics.metrics.get("pdf_page_route_summary") ==
    Some("native_text_page=0,hybrid_region_page=0,ocr_page=1"),
  )
  assert_true(document.metadata.get("page_count") == Some(Number("1")))
}

///|
async test "pdf accurate async parser preserves injected scanned route semantics" {
  let provider = pdf_parser_wbtest_fake_ocr_provider(Some("eng"))
  let rasterizer = pdf_parser_wbtest_fake_rasterizer(
    1, "scanned-accurate-async",
  )
  let parsed = match
    pdf_ocr_parser_result_async(
      @input.input_from_path_with_format(
        "samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf",
        Some(Pdf),
      ),
      pdf_parser_wbtest_accurate_context(),
      image_ocr_provider=fn(request) { provider(request) },
      rasterizer=fn(source) { rasterizer(source) },
    ) {
    Ok(value) => value
    Err(err) => fail("expected async accurate scanned parse success: " + err)
  }
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(document.blocks.any(block => block.text.contains("MoonBit OCR")))
  assert_true(parsed.diagnostics.metrics.get("pdf_ocr_used") == Some("true"))
  assert_true(
    parsed.diagnostics.metrics.get("ocr_provider_status") == Some("success"),
  )
  assert_true(
    parsed.diagnostics.metrics.get("pdf_raster_backend") == Some("fake-raster"),
  )
  assert_true(
    parsed.diagnostics.metrics.get("pdf_page_route_summary") ==
    Some("native_text_page=0,hybrid_region_page=0,ocr_page=1"),
  )
}
