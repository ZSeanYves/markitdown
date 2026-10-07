///|
test "detector contract covers core formats and unknown fallback" {
  let detector = @input.default_format_detector()
  assert_true(
    (detector.detect)(@input.input_from_path("notes.txt")).format == Txt,
  )
  let png = (detector.detect)(@input.input_from_path("scan.png"))
  assert_true(png.format == Image(Png))
  assert_true(png.notes.contains("image_input"))
  let audio = (detector.detect)(@input.input_from_path("voice.m4a"))
  assert_true(audio.format == Audio(M4a))
  let pdf_magic = (detector.detect)(
    @input.input_from_bytes(
      Bytes::from_array([37, 80, 68, 70, 45, 49, 46, 55]),
      source_name="blob",
    ),
  )
  assert_true(pdf_magic.format == Pdf)
  let docx_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/docx/golden.docx",
  ) catch {
    e => fail("failed to read docx sample: " + (e : Error).to_string())
  }
  let docx = (detector.detect)(
    @input.input_from_bytes(docx_bytes, source_name="office-blob"),
  )
  assert_true(docx.format == Docx)
  assert_true(docx.notes.contains("container_inspection"))
  let unknown = (detector.detect)(
    @input.input_from_bytes(
      Bytes::from_array([0, 1, 2, 3]),
      source_name="blob.bin",
    ),
  )
  assert_true(unknown.format == Unknown)
  assert_true(unknown.binary_like)
}

///|
test "unknown convert path stays fail closed" {
  match
    @convert.convert_input(
      @input.input_from_bytes(Bytes::from_array([0, 1, 2]), source_name="blob"),
      @convert.default_convert_options(),
    ) {
    Err(DetectFailed(msg)) => assert_eq(msg, "unknown format")
    Err(other) => fail("unexpected unknown-format error: " + other.to_string())
    Ok(_) => fail("unknown input should not convert successfully")
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
    Some(Pdf),
  )
  match @convert.convert_input(source, @convert.default_convert_options()) {
    Err(ParseFailed(_)) => ()
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
      @parser.new_parse_context(Pdf),
    ) {
    Err(_) => ()
    Ok(_) => fail("registry parse should not succeed for scanned-like pdf")
  }
}

///|
test "builtin registry wires pdf native text parser through the active registry" {
  let registry_impl = read_utf8_text("src/internal/formats/meta/registry.mbt")
  assert_true(
    registry_impl.contains("registry, Pdf, @fpdf.pdf_native_parser()"),
  )
  assert_true(!registry_impl.contains("pdf_v2"))
  match
    @parser.registry_parse(
      @formats_root.builtin_registry(),
      @input.input_from_path_with_format(
        "samples/fixtures/contracts/pdf/text_simple.pdf",
        Some(Pdf),
      ),
      @parser.new_parse_context(Pdf),
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
test "pdf accurate parser contract is registered and matches born-digital accurate output" {
  let spec = @fmeta.pdf_native_parser_contract_spec()
  assert_true(
    @fmeta.product_parser_contract_specs().any(spec0 => {
      spec0.parser_name == spec.parser_name
    }),
  )
  assert_true(@fmeta.contract_profile_matches_spec(Pdf, spec))
  assert_true(
    @fmeta.parser_contract_spec_matches_parser(spec, @fpdf.pdf_native_parser()),
  )
  let context0 = @parser.parse_context_with_product_modes(
    @parser.new_parse_context(Pdf),
    Accurate,
    Markdown,
  )
  let context1 = @parser.parse_context_with_limits(
    context0,
    Some(PageSinglePass),
    None,
    None,
    None,
    None,
    false,
  )
  let context3 = @parser.parse_context_with_pdf_header_footer_filter_policy(
    context1,
    InternalHighConfidenceOnly,
  )
  let context = @parser.parse_context_with_pdf_table_reconstruction_policy(
    context3,
    InternalSimpleRowsOnly,
  )
  let result = @fpdf.pdf_native_parser_result(
    @input.input_from_path_with_format(
      "samples/fixtures/contracts/pdf/text_simple.pdf",
      Some(Pdf),
    ),
    context,
  )
  assert_parse_result_matches_contract_spec(result, spec)
  assert_metric_eq(
    result.diagnostics,
    "pdf_header_footer_filter_policy",
    "internal_high_confidence_only",
  )
  assert_metric_eq(result.diagnostics, "pdf_native_backend", "true")
}
