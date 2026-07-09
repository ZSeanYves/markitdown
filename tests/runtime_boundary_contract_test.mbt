///|
test "detector contract covers core formats and unknown fallback" {
  let detector = @input.default_format_detector()
  assert_true(
    (detector.detect)(@input.input_from_path("notes.txt")).format ==
    @input.DetectedFormat::Txt,
  )
  let png = (detector.detect)(@input.input_from_path("scan.png"))
  assert_true(
    png.format == @input.DetectedFormat::Image(@input.ImageFormat::Png),
  )
  assert_true(png.notes.contains("image_ocr_candidate"))
  let audio = (detector.detect)(@input.input_from_path("voice.m4a"))
  assert_true(
    audio.format == @input.DetectedFormat::Audio(@input.AudioFormat::M4a),
  )
  let pdf_magic = (detector.detect)(
    @input.input_from_bytes(
      Bytes::from_array([37, 80, 68, 70, 45, 49, 46, 55]),
      source_name="blob",
    ),
  )
  assert_true(pdf_magic.format == @input.DetectedFormat::Pdf)
  let docx_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/docx/golden.docx",
  ) catch {
    e => fail("failed to read docx sample: " + e.to_string())
  }
  let docx = (detector.detect)(
    @input.input_from_bytes(docx_bytes, source_name="office-blob"),
  )
  assert_true(docx.format == @input.DetectedFormat::Docx)
  assert_true(docx.notes.contains("container_inspection"))
  let unknown = (detector.detect)(
    @input.input_from_bytes(
      Bytes::from_array([0, 1, 2, 3]),
      source_name="blob.bin",
    ),
  )
  assert_true(unknown.format == @input.DetectedFormat::Unknown)
  assert_true(unknown.binary_like)
}

///|
test "unknown convert path stays fail closed" {
  match
    @convert.convert_input(
      @input.input_from_bytes(Bytes::from_array([0, 1, 2]), source_name="blob"),
      @convert.default_convert_options(),
    ) {
    Err(@convert.ConvertError::DetectFailed(msg)) =>
      assert_eq(msg, "unknown format")
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
    Some(@input.DetectedFormat::Pdf),
  )
  match @convert.convert_input(source, @convert.default_convert_options()) {
    Err(@convert.ConvertError::ParseFailed(_)) => ()
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
    Err(_) => ()
    Ok(_) => fail("registry parse should not succeed for scanned-like pdf")
  }
}

///|
test "builtin registry wires pdf native text parser through the active registry" {
  let registry_impl = read_utf8_text("internal/formats/meta/registry.mbt")
  assert_true(registry_impl.contains("DetectedFormat::Pdf"))
  assert_true(registry_impl.contains("pdf_native_parser()"))
  assert_true(!registry_impl.contains("pdf_v2"))
  match
    @parser.registry_parse(
      @formats_root.builtin_registry(),
      @input.input_from_path_with_format(
        "samples/fixtures/contracts/pdf/text_simple.pdf",
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
test "root image parser keeps deterministic fail-closed OCR diagnostics" {
  let source = @input.input_from_path("scan.png")
  let detected = @input.DetectedFormat::Image(@input.ImageFormat::Png)
  match
    @focr.image_ocr_parser_result(
      source,
      detected,
      @parser.default_ocr_options(),
    ) {
    Err(msg) => {
      assert_true(msg.contains("image OCR is not enabled"))
      assert_true(msg.contains("png"))
    }
    Ok(_) => fail("default OCR path should stay fail closed")
  }
  let provider_calls : Ref[Int] = { val: 0 }
  match
    @focr.image_ocr_parser_result_with_provider(
      source,
      detected,
      @parser.explicit_ocr_options(language=Some("eng")),
      fn(request : @focr.OcrProviderRequest) {
        provider_calls.val = provider_calls.val + 1
        if request.language != Some("eng") {
          abort("unexpected OCR language")
        }
        Err(
          @focr.OcrProviderError::CommandUnavailable(
            "synthetic tesseract missing",
          ),
        )
      },
      requested_mode=Some(@parser.ParserMode::LayoutTwoStage),
    ) {
    Err(msg) =>
      assert_true(
        msg.contains("synthetic tesseract missing") &&
        msg.contains("image_format=png"),
      )
    Ok(_) =>
      fail("explicit OCR path should still fail until provider wiring exists")
  }
  assert_eq(provider_calls.val, 1)
  let diagnostics = @focr.image_ocr_fail_closed_diagnostics(
    source,
    detected,
    @parser.explicit_ocr_options(language=Some("eng")),
    requested_mode=Some(@parser.ParserMode::LayoutTwoStage),
  )
  assert_metric_eq(diagnostics, "ocr_candidate", "true")
  assert_metric_eq(diagnostics, "ocr_provider_wired", "false")
  assert_metric_eq(diagnostics, "effective_mode", "layout_two_stage")
}

///|
test "pure tesseract tsv parser stays provider-independent while root image OCR remains injected" {
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
  assert_eq(result.pages.length(), 2)
  assert_eq(result.pages[0].blocks[0].lines[0].text, "hello")
  assert_eq(result.pages[1].blocks[0].lines[0].text, "moonbit world")
  let image = @input.input_from_path_with_format(
    "scan.png",
    Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
  )
  match
    @convert.convert_input_with_image_ocr_provider(
      image,
      @convert.make_convert_options(
        @convert.ConvertMode::Balanced,
        @convert.OutputFormat::Markdown,
        Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
        @parser.explicit_ocr_options(),
        @convert.default_resource_limits(),
      ),
      fn(_request : @focr.OcrProviderRequest) {
        Err(
          @focr.OcrProviderError::ExecutionFailed(
            "synthetic tesseract execution failed",
          ),
        )
      },
    ) {
    Err(@convert.ConvertError::ParseFailed(msg)) =>
      assert_true(
        msg.contains("synthetic tesseract execution failed") &&
        msg.contains("image_format=png"),
      )
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
  assert_true(converted.parser_mode == @parser.ParserMode::LayoutTwoStage)
  assert_metric_eq(converted.diagnostics, "ocr_provider_status", "success")
  assert_metric_eq(converted.diagnostics, "renderer_name", "MarkdownRenderer")
}
