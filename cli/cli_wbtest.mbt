///|
fn test_tmp_root() -> String {
  ".tmp/tests/cli"
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
fn cli_options(
  input : String,
  output : String?,
  explicit_format : @input.DetectedFormat?,
  output_format : @convert.OutputFormat,
  provenance_output? : String? = None,
  ocr_options? : @parser.OcrOptions = @parser.default_ocr_options(),
  pdf_cleanup_mode? : @convert.PdfCleanupMode = @convert.default_pdf_cleanup_mode(),
  pdf_table_mode? : @convert.PdfTableMode = @convert.default_pdf_table_mode(),
) -> CliOptions {
  make_cli_options(
    input,
    output,
    provenance_output,
    explicit_format,
    ocr_options,
    @convert.FidelityMode::Balanced,
    @convert.ConvertMode::Balanced,
    @convert.output_mode_for_output_format(output_format),
    false,
    output_format,
    pdf_cleanup_mode~,
    pdf_table_mode~,
    rag_options=@rag.default_rag_options(),
  )
}

///|
test "main cli product policy exposes text, notebook, markup, container, office, pdf, and image formats" {
  assert_true(cli_is_supported_format(@input.DetectedFormat::Txt))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Csv))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Tsv))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Srt))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Vtt))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Json))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Jsonl))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Ndjson))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Ipynb))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Xml))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Yaml))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Toml))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Html))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Eml))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Markdown))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Tex))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Rst))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Asciidoc))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Zip))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Epub))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Odt))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Ods))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Odp))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Docx))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Xlsx))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Pptx))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Pdf))
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Jpg),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Jpeg),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Bmp),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Webp),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Tif),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Tiff),
    ),
  )
  assert_true(!cli_is_supported_format(@input.DetectedFormat::Unknown))
  let supported = [
    "txt", "csv", "tsv", "srt", "vtt", "json", "jsonl", "ndjson", "ipynb", "xml",
    "yaml", "yml", "toml", "html", "htm", "markdown", "md", "eml", "tex", "latex",
    "rst", "adoc", "asciidoc", "zip", "epub", "docx", "xlsx", "pptx", "pdf", "png",
    "jpg", "jpeg", "bmp", "webp", "tif", "tiff",
  ]
  assert_eq(supported.length(), 36)
  assert_eq(supported[0], "txt")
  assert_eq(supported[1], "csv")
  assert_eq(supported[2], "tsv")
  assert_eq(supported[3], "srt")
  assert_eq(supported[4], "vtt")
  assert_eq(supported[5], "json")
  assert_eq(supported[6], "jsonl")
  assert_eq(supported[7], "ndjson")
  assert_eq(supported[8], "ipynb")
  assert_eq(supported[9], "xml")
  assert_eq(supported[10], "yaml")
  assert_eq(supported[11], "yml")
  assert_eq(supported[12], "toml")
  assert_eq(supported[13], "html")
  assert_eq(supported[14], "htm")
  assert_eq(supported[15], "markdown")
  assert_eq(supported[16], "md")
  assert_eq(supported[17], "eml")
  assert_eq(supported[18], "tex")
  assert_eq(supported[19], "latex")
  assert_eq(supported[20], "rst")
  assert_eq(supported[21], "adoc")
  assert_eq(supported[22], "asciidoc")
  assert_eq(supported[23], "zip")
  assert_eq(supported[24], "epub")
  assert_eq(supported[25], "docx")
  assert_eq(supported[26], "xlsx")
  assert_eq(supported[27], "pptx")
  assert_eq(supported[28], "pdf")
  assert_eq(supported[29], "png")
  assert_eq(supported[30], "jpg")
  assert_eq(supported[31], "jpeg")
  assert_eq(supported[32], "bmp")
  assert_eq(supported[33], "webp")
  assert_eq(supported[34], "tif")
  assert_eq(supported[35], "tiff")
}

///|
test "main cli accepts known image extensions as supported formats" {
  let root = test_tmp_root() + "/main-cli-image-fail-closed"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let png_path = root + "/tiny.png"
  write_utf8_text(png_path, "not-a-real-image")

  let explicit = parse_explicit_format(Some("png"))
  match explicit {
    Ok(Some(format)) =>
      assert_true(
        format == @input.DetectedFormat::Image(@input.ImageFormat::Png),
      )
    Ok(None) => fail("expected explicit png format to parse")
    Err(msg) => fail("expected explicit png format to stay supported: " + msg)
  }
}

///|
test "main cli parses explicit OCR intent flags" {
  match parse_cli_options(["--ocr", "--ocr-lang", "eng", "tiny.png"]) {
    Ok(opts) => {
      assert_true(opts.ocr_options.intent == @parser.OcrIntent::Explicit)
      assert_true(opts.ocr_options.language == Some("eng"))
    }
    Err(msg) => fail("expected OCR flags to parse: " + msg)
  }

  match parse_cli_options(["--no-ocr", "tiny.png"]) {
    Ok(opts) => {
      assert_true(opts.ocr_options.intent == @parser.OcrIntent::Disabled)
      assert_true(opts.ocr_options.language == None)
    }
    Err(msg) => fail("expected --no-ocr to parse: " + msg)
  }

  match parse_cli_options(["tiny.png"]) {
    Ok(opts) => {
      assert_true(opts.ocr_options.intent == @parser.OcrIntent::Explicit)
      assert_true(opts.ocr_options.language == None)
    }
    Err(msg) => fail("expected direct image input to default to OCR: " + msg)
  }

  match parse_cli_options(["--ocr-lang", "eng", "tiny.png"]) {
    Ok(opts) => {
      assert_true(opts.ocr_options.intent == @parser.OcrIntent::Explicit)
      assert_true(opts.ocr_options.language == Some("eng"))
    }
    Err(msg) => fail("expected direct image input to accept --ocr-lang: " + msg)
  }
}

///|
test "main cli keeps --debug and rejects retired --json alias" {
  match parse_cli_options(["--accurate", "tiny.txt"]) {
    Ok(opts) => {
      assert_true(opts.fidelity_mode == @convert.FidelityMode::Accurate)
      assert_true(opts.convert_mode == @convert.ConvertMode::Accurate)
      assert_true(opts.output_mode == @convert.OutputMode::Markdown)
      assert_true(opts.output_format == @convert.OutputFormat::Markdown)
    }
    Err(msg) => fail("expected --accurate to parse: " + msg)
  }

  match parse_cli_options(["--accurate", "--debug", "tiny.txt"]) {
    Ok(opts) => {
      assert_true(opts.fidelity_mode == @convert.FidelityMode::Accurate)
      assert_true(opts.convert_mode == @convert.ConvertMode::Accurate)
      assert_true(opts.output_mode == @convert.OutputMode::Debug)
      assert_true(opts.output_format == @convert.OutputFormat::DebugJson)
    }
    Err(msg) => fail("expected --accurate --debug to parse: " + msg)
  }

  match parse_cli_options(["--accurate", "--rag", "tiny.txt"]) {
    Ok(opts) => {
      assert_true(opts.fidelity_mode == @convert.FidelityMode::Accurate)
      assert_true(opts.convert_mode == @convert.ConvertMode::Accurate)
      assert_true(opts.output_mode == @convert.OutputMode::Rag)
      assert_true(opts.output_format == @convert.OutputFormat::RagJson)
    }
    Err(msg) => fail("expected --accurate --rag to parse: " + msg)
  }

  match parse_cli_options(["--debug", "tiny.txt"]) {
    Ok(opts) => {
      assert_true(opts.convert_mode == @convert.ConvertMode::Balanced)
      assert_true(!opts.stream_requested)
      assert_true(opts.output_mode == @convert.OutputMode::Debug)
      assert_true(opts.output_format == @convert.OutputFormat::DebugJson)
    }
    Err(msg) => fail("expected --debug to parse: " + msg)
  }

  match parse_cli_options(["--rag", "tiny.txt"]) {
    Ok(opts) => {
      assert_true(opts.convert_mode == @convert.ConvertMode::Balanced)
      assert_true(opts.output_mode == @convert.OutputMode::Rag)
      assert_true(opts.output_format == @convert.OutputFormat::RagJson)
      assert_eq(
        opts.rag_options.chunk_size,
        @rag.default_rag_options().chunk_size,
      )
      assert_eq(
        opts.rag_options.chunk_overlap,
        @rag.default_rag_options().chunk_overlap,
      )
      assert_true(opts.rag_options.preserve_heading_path)
      assert_true(opts.rag_options.preserve_source_ref)
      assert_true(opts.rag_options.split_tables)
      assert_true(opts.rag_options.split_code_blocks)
    }
    Err(msg) => fail("expected --rag to parse: " + msg)
  }

  match parse_cli_options(["--debug", "--rag", "tiny.txt"]) {
    Err(msg) => assert_true(msg.contains("cannot combine --debug and --rag"))
    Ok(_) => fail("expected --debug and --rag to conflict")
  }

  match parse_cli_options(["--stream", "tiny.txt"]) {
    Ok(opts) => {
      assert_true(opts.stream_requested)
      assert_true(opts.convert_mode == @convert.ConvertMode::Stream)
      assert_true(opts.output_mode == @convert.OutputMode::Markdown)
      assert_true(opts.output_format == @convert.OutputFormat::Markdown)
    }
    Err(msg) => fail("expected --stream to parse: " + msg)
  }

  match parse_cli_options(["--stream", "--debug", "tiny.txt"]) {
    Ok(opts) => {
      assert_true(opts.stream_requested)
      assert_true(opts.convert_mode == @convert.ConvertMode::Stream)
      assert_true(opts.output_mode == @convert.OutputMode::Debug)
      assert_true(opts.output_format == @convert.OutputFormat::DebugJson)
    }
    Err(msg) => fail("expected --stream --debug to parse: " + msg)
  }

  match parse_cli_options(["--stream", "--rag", "tiny.txt"]) {
    Ok(opts) => {
      assert_true(opts.stream_requested)
      assert_true(opts.convert_mode == @convert.ConvertMode::Stream)
      assert_true(opts.output_mode == @convert.OutputMode::Rag)
      assert_true(opts.output_format == @convert.OutputFormat::RagJson)
    }
    Err(msg) => fail("expected --stream --rag to parse: " + msg)
  }

  match parse_cli_options(["--stream", "--accurate", "tiny.txt"]) {
    Err(msg) =>
      assert_true(msg.contains("cannot combine --stream and --accurate"))
    Ok(_) => fail("expected --stream and --accurate to conflict")
  }

  match parse_cli_options(["--json", "tiny.txt"]) {
    Err(msg) => assert_true(msg.contains("unsupported option: --json"))
    Ok(_) => fail("expected retired --json alias to fail")
  }
}

///|
test "main cli parses explicit PDF product option flags" {
  match
    parse_cli_options([
      "--pdf-cleanup", "conservative", "--pdf-tables", "simple", "tiny.pdf",
    ]) {
    Ok(opts) => {
      assert_true(
        opts.pdf_cleanup_mode == @convert.PdfCleanupMode::Conservative,
      )
      assert_true(opts.pdf_table_mode == @convert.PdfTableMode::Simple)
    }
    Err(msg) => fail("expected PDF product flags to parse: " + msg)
  }

  match parse_cli_options(["tiny.pdf"]) {
    Ok(opts) => {
      assert_true(opts.pdf_cleanup_mode == @convert.PdfCleanupMode::Disabled)
      assert_true(opts.pdf_table_mode == @convert.PdfTableMode::Disabled)
    }
    Err(msg) => fail("expected default PDF product flags to parse: " + msg)
  }
}

///|
test "main cli rejects invalid PDF product option values" {
  match parse_cli_options(["--pdf-cleanup", "aggressive", "tiny.pdf"]) {
    Err(msg) => assert_true(msg.contains("unsupported --pdf-cleanup value"))
    Ok(_) => fail("expected invalid --pdf-cleanup to fail")
  }
  match parse_cli_options(["--pdf-tables", "full", "tiny.pdf"]) {
    Err(msg) => assert_true(msg.contains("unsupported --pdf-tables value"))
    Ok(_) => fail("expected invalid --pdf-tables to fail")
  }
}

///|
test "main cli rejects conflicting OCR intent flags" {
  match parse_cli_options(["--ocr", "--no-ocr", "tiny.png"]) {
    Err(msg) => assert_true(msg.contains("cannot combine --ocr and --no-ocr"))
    Ok(_) => fail("expected conflicting OCR flags to fail")
  }
}

///|
test "main cli constrains --ocr-lang to OCR-capable routes" {
  match parse_cli_options(["--ocr-lang", "eng", "tiny.png"]) {
    Ok(opts) => {
      assert_true(opts.ocr_options.intent == @parser.OcrIntent::Explicit)
      assert_true(opts.ocr_options.language == Some("eng"))
    }
    Err(msg) => fail("expected direct image --ocr-lang to parse: " + msg)
  }

  match parse_cli_options(["--ocr-lang", "eng", "tiny.txt"]) {
    Err(msg) =>
      assert_true(
        msg.contains(
          "--ocr-lang requires --ocr, Accurate-mode PDF input, or direct image input",
        ),
      )
    Ok(_) => fail("expected non-image --ocr-lang without --ocr to fail")
  }

  match parse_cli_options(["--ocr-lang", "eng", "--ocr", "tiny.pdf"]) {
    Ok(opts) => {
      assert_true(opts.ocr_options.intent == @parser.OcrIntent::Explicit)
      assert_true(opts.ocr_options.language == Some("eng"))
    }
    Err(msg) => fail("expected pdf --ocr-lang with --ocr to parse: " + msg)
  }

  match parse_cli_options(["--accurate", "tiny.pdf"]) {
    Ok(opts) => {
      assert_true(opts.fidelity_mode == @convert.FidelityMode::Accurate)
      assert_true(opts.ocr_options.intent == @parser.OcrIntent::Explicit)
      assert_true(opts.ocr_options.language == None)
    }
    Err(msg) => fail("expected accurate pdf to auto-enable OCR: " + msg)
  }

  match parse_cli_options(["--accurate", "--ocr-lang", "eng", "tiny.pdf"]) {
    Ok(opts) => {
      assert_true(opts.fidelity_mode == @convert.FidelityMode::Accurate)
      assert_true(opts.ocr_options.intent == @parser.OcrIntent::Explicit)
      assert_true(opts.ocr_options.language == Some("eng"))
    }
    Err(msg) => fail("expected accurate pdf --ocr-lang to parse: " + msg)
  }
}

///|
test "main cli parses provenance output flag" {
  match parse_cli_options(["--provenance-out", "trace.json", "tiny.txt"]) {
    Ok(opts) => {
      assert_true(opts.provenance_output == Some("trace.json"))
      assert_eq(opts.input, "tiny.txt")
      assert_true(opts.output == None)
    }
    Err(msg) => fail("expected --provenance-out to parse: " + msg)
  }
}

///|
test "main cli first user arg helper handles executable-prefixed argv" {
  assert_true(first_user_cli_arg(["cli.exe"]) == None)
  assert_true(first_user_cli_arg(["cli.exe", "help"]) == Some("help"))
  assert_true(first_user_cli_arg(["cli.exe", "normal"]) == Some("normal"))
}

///|
test "main cli can parse options from either implicit or explicit convert position" {
  match parse_cli_options_from_index(["demo.txt"], 0) {
    Ok(opts) => {
      assert_eq(opts.input, "demo.txt")
      assert_true(opts.output == None)
    }
    Err(msg) => fail("expected implicit convert argv to parse: " + msg)
  }

  match parse_cli_options_from_index(["convert", "demo.txt", "out.md"], 1) {
    Ok(opts) => {
      assert_eq(opts.input, "demo.txt")
      assert_true(opts.output == Some("out.md"))
    }
    Err(msg) => fail("expected explicit convert argv to parse: " + msg)
  }
}

///|
test "main cli image OCR intent remains fail closed by mode" {
  let root = test_tmp_root() + "/main-cli-image-ocr-intent"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let png_path = root + "/tiny.png"
  write_utf8_text(png_path, "not-a-real-image")

  match
    run_cli(
      cli_options(
        png_path,
        None,
        None,
        @convert.OutputFormat::Markdown,
        ocr_options=@parser.explicit_ocr_options(),
      ),
    ) {
    Err(msg) =>
      assert_true(
        msg.contains("Tesseract OCR command is unavailable") ||
        msg.contains("launch tesseract failed") ||
        msg.contains("image_format=png"),
      )
    Ok(_) => fail("expected explicit OCR image path to fail closed")
  }

  match
    run_cli(
      cli_options(
        png_path,
        None,
        None,
        @convert.OutputFormat::Markdown,
        ocr_options=@parser.explicit_ocr_options(language=Some("eng")),
      ),
    ) {
    Err(msg) =>
      assert_true(
        msg.contains("language=eng") ||
        msg.contains("image_format=png") ||
        msg.contains("Tesseract OCR command"),
      )
    Ok(_) => fail("expected explicit OCR image/lang path to fail closed")
  }

  match
    run_cli(
      cli_options(
        png_path,
        None,
        None,
        @convert.OutputFormat::Markdown,
        ocr_options=@parser.disabled_ocr_options(),
      ),
    ) {
    Err(msg) => {
      assert_true(msg.contains("image input conversion is not enabled"))
      assert_true(msg.contains("OCR is disabled"))
    }
    Ok(_) => fail("expected disabled OCR image path to fail closed")
  }
}

///|
test "main cli pdf plus explicit OCR enters OCR route or returns explicit dependency guidance" {
  let root = test_tmp_root() + "/main-cli-pdf-explicit-ocr"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let pdf_path = root + "/tiny.pdf"
  write_utf8_text(pdf_path, "%PDF-1.4 fake")

  match
    run_cli_with_image_ocr_provider(
      cli_options(
        pdf_path,
        None,
        None,
        @convert.OutputFormat::Markdown,
        ocr_options=@parser.explicit_ocr_options(language=Some("eng")),
      ),
      fn(request) {
        let tsv = [
          "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
          "5\t1\t1\t1\t1\t1\t10\t10\t20\t10\t95\tPDF", "5\t1\t1\t1\t1\t2\t35\t10\t20\t10\t94\tOCR",
        ].join("\n")
        match @focr.parse_tesseract_tsv(tsv, language=request.language) {
          Ok(value) => Ok(value)
          Err(err) => abort(err.to_string())
        }
      },
    ) {
    Ok(content) => assert_true(content.contains("PDF OCR"))
    Err(msg) =>
      assert_true(
        msg.contains("pdftoppm") ||
        msg.contains("poppler-utils") ||
        msg.contains("brew install poppler"),
      )
  }
}

///|
test "main cli scanned-like pdf fails closed instead of returning empty markdown" {
  let root = test_tmp_root() + "/main-cli-pdf-empty-text-layer"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let pdf_path = root + "/empty-text-layer.pdf"
  write_utf8_text(
    pdf_path,
    [
      "%PDF-1.4", "1 0 obj", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
      "endobj", "2 0 obj", "<< /Length 5 >>", "stream", "BT ET", "endstream", "endobj",
      "3 0 obj", "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
      "endobj", "4 0 obj", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>", "endobj",
      "5 0 obj", "<< /Type /Catalog /Pages 4 0 R >>", "endobj", "trailer", "<< /Size 6 /Root 5 0 R >>",
      "%%EOF", "",
    ].join("\n"),
  )

  match
    run_cli(cli_options(pdf_path, None, None, @convert.OutputFormat::Markdown)) {
    Err(msg) => {
      assert_true(msg.contains("empty"))
      assert_true(msg.contains("root pdf_native backend"))
      assert_true(!msg.contains("not configured"))
      assert_true(
        !msg.contains("image OCR provider returned a non-empty OCR model"),
      )
    }
    Ok(content) =>
      fail(
        "scanned-like pdf must not return successful empty markdown: " + content,
      )
  }
}

///|
fn fake_cli_image_provider(
  expected_input : String,
  expected_language : String?,
) -> (@focr.OcrProviderRequest) -> Result[
  @focr.OcrProviderResult,
  @focr.OcrProviderError,
] {
  fn(request : @focr.OcrProviderRequest) {
    if request.image_path != expected_input {
      abort("unexpected image path")
    }
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
        abort("expected fake cli OCR TSV parse success: " + err.to_string())
    }
  }
}

///|
test "main cli direct image OCR can succeed through injected provider as a supported product path" {
  let root = test_tmp_root() + "/main-cli-image-ocr-success"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let png_path = root + "/tiny.png"
  write_utf8_text(png_path, "not-a-real-image")

  let result = run_cli_with_image_ocr_provider(
    cli_options(
      png_path,
      None,
      None,
      @convert.OutputFormat::Markdown,
      ocr_options=@parser.explicit_ocr_options(language=Some("eng")),
    ),
    fake_cli_image_provider(png_path, Some("eng")),
  )
  match result {
    Ok(content) => assert_eq(content, "MoonBit OCR\n\nSample 123")
    Err(msg) => fail("expected injected cli OCR success: " + msg)
  }
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
    ),
  )
}

///|
async test "main cli async direct image OCR can succeed through injected provider" {
  let root = test_tmp_root() + "/main-cli-image-ocr-success-async"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let png_path = root + "/tiny.png"
  write_utf8_text(png_path, "not-a-real-image")

  let result = run_cli_with_async_image_ocr_provider(
    cli_options(
      png_path,
      None,
      None,
      @convert.OutputFormat::Markdown,
      ocr_options=@parser.explicit_ocr_options(language=Some("eng")),
    ),
    request => fake_cli_image_provider(png_path, Some("eng"))(request),
  )
  match result {
    Ok(content) => assert_eq(content, "MoonBit OCR\n\nSample 123")
    Err(msg) => fail("expected injected async cli OCR success: " + msg)
  }
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
    ),
  )
}

///|
test "root cli converts txt csv tsv json jsonl ndjson xml yaml and markdown through the current product shell" {
  let root = test_tmp_root() + "/main-cli"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let txt_path = root + "/demo.txt"
  let csv_path = root + "/demo.csv"
  let tsv_path = root + "/demo.tsv"
  let json_path = root + "/demo.json"
  let jsonl_path = root + "/demo.jsonl"
  let ndjson_path = root + "/demo.ndjson"
  let xml_path = root + "/demo.xml"
  let yaml_path = root + "/demo.yaml"
  let markdown_path = root + "/demo.md"
  let markdown_long_path = root + "/demo.markdown"
  write_utf8_text(txt_path, "alpha\n\nbeta")
  write_utf8_text(csv_path, "name,score\nalice,7\n")
  write_utf8_text(tsv_path, "name\tscore\nbob\t9\n")
  write_utf8_text(json_path, "{\"name\":\"Alice\",\"role\":\"Engineer\"}\n")
  write_utf8_text(
    jsonl_path, "{\"name\":\"Alice\",\"score\":7}\n{\"name\":\"Bob\",\"score\":9}\n",
  )
  write_utf8_text(
    ndjson_path, "{\"name\":\"Carol\",\"score\":5}\n{\"name\":\"Dave\",\"score\":8}\n",
  )
  write_utf8_text(xml_path, "<root><item>Hello</item></root>\n")
  write_utf8_text(yaml_path, "name: Alice\nrole: Engineer\n")
  write_utf8_text(markdown_path, "# Markdown Demo\n\nBody line.\n")
  write_utf8_text(markdown_long_path, "---\ntitle: Demo\n---\n\n# Title\n")

  let txt = match
    run_cli(
      cli_options(
        txt_path,
        None,
        Some(@input.DetectedFormat::Txt),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current txt cli failed: " + msg)
  }
  let csv = match
    run_cli(
      cli_options(
        csv_path,
        None,
        Some(@input.DetectedFormat::Csv),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current csv cli failed: " + msg)
  }
  let tsv = match
    run_cli(
      cli_options(
        tsv_path,
        None,
        Some(@input.DetectedFormat::Tsv),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current tsv cli failed: " + msg)
  }
  let json = match
    run_cli(
      cli_options(
        json_path,
        None,
        Some(@input.DetectedFormat::Json),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current json cli failed: " + msg)
  }
  let jsonl = match
    run_cli(
      cli_options(
        jsonl_path,
        None,
        Some(@input.DetectedFormat::Jsonl),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current jsonl cli failed: " + msg)
  }
  let ndjson = match
    run_cli(
      cli_options(
        ndjson_path,
        None,
        Some(@input.DetectedFormat::Ndjson),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current ndjson cli failed: " + msg)
  }
  let xml = match
    run_cli(
      cli_options(
        xml_path,
        None,
        Some(@input.DetectedFormat::Xml),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current xml cli failed: " + msg)
  }
  let yaml = match
    run_cli(
      cli_options(
        yaml_path,
        None,
        Some(@input.DetectedFormat::Yaml),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current yaml cli failed: " + msg)
  }
  let markdown = match
    run_cli(
      cli_options(markdown_path, None, None, @convert.OutputFormat::Markdown),
    ) {
    Ok(value) => value
    Err(msg) => fail("current markdown cli failed: " + msg)
  }
  let markdown_long = match
    run_cli(
      cli_options(
        markdown_long_path,
        None,
        None,
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current .markdown cli failed: " + msg)
  }

  assert_eq(txt, "alpha\n\nbeta")
  assert_true(csv.contains("| name | score |"))
  assert_true(csv.contains("| alice | 7 |"))
  assert_true(tsv.contains("| name | score |"))
  assert_true(tsv.contains("| bob | 9 |"))
  assert_true(json.contains("| Key | Value |"))
  assert_true(json.contains("| name | Alice |"))
  assert_true(jsonl.contains("| name | score |"))
  assert_true(jsonl.contains("| Alice | 7 |"))
  assert_true(ndjson.contains("| name | score |"))
  assert_true(ndjson.contains("| Dave | 8 |"))
  assert_eq(xml, "# <root>\n\n- item: Hello")
  assert_true(yaml.contains("| Key | Value |"))
  assert_true(yaml.contains("| name | Alice |"))
  assert_eq(markdown, "# Markdown Demo\n\nBody line.")
  assert_true(markdown_long.contains("---\ntitle: Demo\n---"))
  assert_true(markdown_long.contains("# Title"))
}

///|
test "main cli emits debug json on the canonical renderer path" {
  let root = test_tmp_root() + "/main-cli-json"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let txt_path = root + "/debug.txt"
  write_utf8_text(txt_path, "plain")
  let rendered = match
    run_cli(
      cli_options(
        txt_path,
        None,
        Some(@input.DetectedFormat::Txt),
        @convert.OutputFormat::DebugJson,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("debug json cli failed: " + msg)
  }

  assert_true(rendered.contains("\"event_count\": 1"))
  assert_true(rendered.contains("\"renderer_name\": \"DebugJsonRenderer\""))
  assert_true(rendered.contains("\"render_input_kind\": \"event_stream\""))
  assert_true(rendered.contains("\"source_ref\""))
}

///|
test "main cli provenance sidecar preserves conversion output semantics" {
  let root = test_tmp_root() + "/main-cli-provenance"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let input_path = root + "/demo.json"
  let output_path = root + "/demo.md"
  let provenance_path = root + "/demo.provenance.json"
  write_utf8_text(input_path, "{\"name\":\"Alice\",\"role\":\"Engineer\"}\n")

  let rendered = match
    run_cli(
      cli_options(
        input_path,
        Some(output_path),
        Some(@input.DetectedFormat::Json),
        @convert.OutputFormat::Markdown,
        provenance_output=Some(provenance_path),
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("expected cli provenance sidecar conversion: " + msg)
  }

  assert_true(rendered.contains("| Key | Value |"))
  assert_true(read_utf8_text(output_path).contains("| Key | Value |"))
  let sidecar = read_utf8_text(provenance_path)
  assert_true(sidecar.contains("\"selected_route\":"))
  assert_true(sidecar.contains("\"route_reason\":"))
  assert_true(sidecar.contains("\"route_probe_summary\":"))
  assert_true(sidecar.contains("\"effective_parser_mode\":"))
  assert_true(sidecar.contains("\"render_input_kind\":"))
}

///|
test "main cli stream warning message stays stable for unsupported explicit stream fallback" {
  assert_eq(
    cli_explicit_stream_warning_message(@input.DetectedFormat::Toml),
    "warning: explicit --stream is not productized for `toml` yet; falling back to the canonical route",
  )
}

///|
test "main cli pdf debug json exposes header footer candidate diagnostics" {
  let rendered = match
    run_cli(
      cli_options(
        "samples/fixtures/contracts/pdf/text_simple.pdf",
        None,
        Some(@input.DetectedFormat::Pdf),
        @convert.OutputFormat::DebugJson,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current pdf debug json cli failed: " + msg)
  }

  assert_true(rendered.contains("\"renderer_name\": \"DebugJsonRenderer\""))
  assert_true(
    rendered.contains(
      "\"pdf_header_footer_candidate_strategy\": \"conservative_v1\"",
    ),
  )
  assert_true(rendered.contains("\"pdf_header_candidate_count\": "))
  assert_true(rendered.contains("\"pdf_footer_candidate_count\": "))
  assert_true(rendered.contains("\"pdf_header_footer_candidate_count\": "))
  assert_true(
    rendered.contains("\"pdf_table_candidate_strategy\": \"conservative_v1\""),
  )
  assert_true(rendered.contains("\"pdf_table_candidate_count\": "))
  assert_true(rendered.contains("\"pdf_table_row_candidate_count\": "))
  assert_true(rendered.contains("\"pdf_cleanup_mode\": \"none\""))
  assert_true(rendered.contains("\"pdf_cleanup_default_mode\": \"none\""))
  assert_true(
    rendered.contains("\"pdf_cleanup_opt_in_mode\": \"conservative\""),
  )
  assert_true(rendered.contains("\"pdf_table_mode\": \"none\""))
  assert_true(rendered.contains("\"pdf_table_default_mode\": \"none\""))
  assert_true(rendered.contains("\"pdf_table_opt_in_mode\": \"simple\""))
  assert_true(!rendered.contains("\"pdf_v2\""))
  assert_true(!rendered.contains("\"pdf_debug\""))
}

///|
test "main cli pdf product options stay opt-in and only change diagnostics when not requested" {
  let root = test_tmp_root() + "/main-cli-pdf-options"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let pdf_path = "samples/fixtures/contracts/pdf/root_native_text_baseline.pdf"
  let baseline = match
    run_cli(
      cli_options(
        pdf_path,
        None,
        Some(@input.DetectedFormat::Pdf),
        @convert.OutputFormat::DebugJson,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("baseline pdf debug json should succeed: " + msg)
  }
  assert_true(baseline.contains("\"pdf_cleanup_mode\": \"none\""))
  assert_true(baseline.contains("\"pdf_table_mode\": \"none\""))
  assert_true(baseline.contains("\"pdf_cleanup_enabled\": \"false\""))
  assert_true(baseline.contains("\"pdf_table_enabled\": \"false\""))

  let opted_in = match
    run_cli(
      cli_options(
        pdf_path,
        None,
        Some(@input.DetectedFormat::Pdf),
        @convert.OutputFormat::DebugJson,
        pdf_cleanup_mode=@convert.PdfCleanupMode::Conservative,
        pdf_table_mode=@convert.PdfTableMode::Simple,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("opt-in pdf debug json should succeed: " + msg)
  }
  assert_true(opted_in.contains("\"pdf_cleanup_mode\": \"conservative\""))
  assert_true(opted_in.contains("\"pdf_cleanup_enabled\": \"true\""))
  assert_true(opted_in.contains("\"pdf_table_mode\": \"simple\""))
  assert_true(opted_in.contains("\"pdf_table_enabled\": \"true\""))
}

///|
test "main cli persists pptx local assets only at output boundary" {
  let root = test_tmp_root() + "/main-cli-pptx-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let out_dir = root + "/out"
  let out_path = out_dir + "/pptx_image_single.md"
  ensure_dir_tree(out_dir)
  let persisted = match
    run_cli(
      cli_options(
        "samples/fixtures/contracts/pptx/pptx_image_single.pptx",
        Some(out_path),
        Some(@input.DetectedFormat::Pptx),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current pptx local asset cli failed: " + msg)
  }
  assert_true(persisted.contains("![slide-1-image-1](assets/image01.png)"))
  let persisted_markdown = read_utf8_text(out_path)
  assert_true(
    persisted_markdown.contains("![slide-1-image-1](assets/image01.png)"),
  )
  assert_true(@fs.path_exists(out_dir + "/assets/image01.png"))
}

///|
test "main cli persists markdown local assets only at output boundary" {
  let root = test_tmp_root() + "/main-cli-markdown-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let input_dir = root + "/input"
  let image_dir = input_dir + "/img"
  let out_dir = root + "/out"
  ensure_dir_tree(image_dir)
  ensure_dir_tree(out_dir)
  let input_path = input_dir + "/sample.md"
  let output_path = out_dir + "/sample.md"
  write_utf8_text(
    input_path, "![single](img/img_red.jpg)\n\n![remote](https://example.com/remote.png)\n",
  )
  let source_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/html/img_red.jpg",
  ) catch {
    e => fail("read markdown asset sample failed: " + e.to_string())
  }
  @fs.write_bytes_to_file(image_dir + "/img_red.jpg", source_bytes) catch {
    e => fail("write markdown asset sample failed: " + e.to_string())
  }

  let rendered = match
    run_cli(
      cli_options(
        input_path,
        Some(output_path),
        Some(@input.DetectedFormat::Markdown),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current markdown cli asset persistence failed: " + msg)
  }

  assert_true(rendered.contains("![single](assets/image01.jpg)"))
  assert_true(rendered.contains("![remote](https://example.com/remote.png)"))
  let persisted_markdown = read_utf8_text(output_path)
  assert_true(persisted_markdown.contains("![single](assets/image01.jpg)"))
  assert_true(
    persisted_markdown.contains("![remote](https://example.com/remote.png)"),
  )
  let copied_asset_path = out_dir + "/assets/image01.jpg"
  assert_true(@fs.path_exists(copied_asset_path))
  assert_true(!@fs.path_exists(out_dir + "/assets/image02.png"))
  let copied_bytes = @fs.read_file_to_bytes(copied_asset_path) catch {
    e => fail("read copied markdown asset failed: " + e.to_string())
  }
  assert_true(copied_bytes.to_array() == source_bytes.to_array())
}

///|
test "main cli converts zip through the root container pipeline and persists local assets only at output boundary" {
  let root = test_tmp_root() + "/main-cli-zip"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let zip_input = "samples/fixtures/contracts/zip/zip_html_local_image.zip"
  let out_dir = root + "/out"
  let out_md = out_dir + "/archive.md"
  ensure_dir_tree(out_dir)

  let rendered = match
    run_cli(
      cli_options(
        zip_input,
        Some(out_md),
        Some(@input.DetectedFormat::Zip),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current zip cli failed: " + msg)
  }

  assert_true(rendered.contains("# site/page.html"))
  assert_true(
    rendered.contains("![single](assets/archive/site_page.html/image01.png)"),
  )
  let persisted_markdown = read_utf8_text(out_md)
  assert_true(
    persisted_markdown.contains(
      "![single](assets/archive/site_page.html/image01.png)",
    ),
  )
  let copied_asset_path = out_dir + "/assets/archive/site_page.html/image01.png"
  assert_true(@fs.path_exists(copied_asset_path))
  assert_true(
    !@fs.path_exists(out_dir + "/assets/archive/site_page.html/image02.png"),
  )
}

///|
test "main cli persists ipynb inline image assets at output boundary" {
  let root = test_tmp_root() + "/main-cli-ipynb-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let input_path = root + "/sample.ipynb"
  let out_dir = root + "/out"
  let output_path = out_dir + "/sample.md"
  ensure_dir_tree(out_dir)
  write_utf8_text(
    input_path,
    "{\n" +
    "  \"nbformat\": 4,\n" +
    "  \"nbformat_minor\": 5,\n" +
    "  \"metadata\": {\"language_info\": {\"name\": \"python\"}},\n" +
    "  \"cells\": [\n" +
    "    {\n" +
    "      \"cell_type\": \"markdown\",\n" +
    "      \"attachments\": {\n" +
    "        \"dot.png\": {\n" +
    "          \"image/png\": \"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0MsAAAAASUVORK5CYII=\"\n" +
    "        }\n" +
    "      },\n" +
    "      \"source\": [\"![dot](attachment:dot.png)\\n\"]\n" +
    "    },\n" +
    "    {\n" +
    "      \"cell_type\": \"code\",\n" +
    "      \"execution_count\": 1,\n" +
    "      \"source\": \"display('ok')\\n\",\n" +
    "      \"outputs\": [\n" +
    "        {\n" +
    "          \"output_type\": \"display_data\",\n" +
    "          \"data\": {\n" +
    "            \"image/png\": \"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0MsAAAAASUVORK5CYII=\",\n" +
    "            \"text/plain\": [\"<Image>\\n\"]\n" +
    "          }\n" +
    "        }\n" +
    "      ]\n" +
    "    }\n" +
    "  ]\n" +
    "}\n",
  )

  let rendered = match
    run_cli(
      cli_options(
        input_path,
        Some(output_path),
        Some(@input.DetectedFormat::Ipynb),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current ipynb cli asset persistence failed: " + msg)
  }

  assert_true(
    rendered.contains("![notebook image](assets/ipynb-cell02-output01.png)"),
  )
  let persisted_markdown = read_utf8_text(output_path)
  assert_true(
    persisted_markdown.contains(
      "![dot](assets/ipynb-cell01-attachment-dot-png.png)",
    ),
  )
  assert_true(
    persisted_markdown.contains(
      "![notebook image](assets/ipynb-cell02-output01.png)",
    ),
  )
  assert_true(
    @fs.path_exists(out_dir + "/assets/ipynb-cell01-attachment-dot-png.png"),
  )
  assert_true(@fs.path_exists(out_dir + "/assets/ipynb-cell02-output01.png"))
}

///|
test "main cli persists odt local assets only at output boundary" {
  let root = test_tmp_root() + "/main-cli-odt-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let out_dir = root + "/out"
  let out_path = out_dir + "/odt_basic_assets.md"
  ensure_dir_tree(out_dir)
  let persisted = match
    run_cli(
      cli_options(
        "samples/fixtures/contracts/odt/odt_basic_assets.odt",
        Some(out_path),
        Some(@input.DetectedFormat::Odt),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("odt local asset cli failed: " + msg)
  }
  assert_true(persisted.contains("![red-dot](assets/odt-red.png)"))
  let persisted_markdown = read_utf8_text(out_path)
  assert_true(persisted_markdown.contains("![red-dot](assets/odt-red.png)"))
  assert_true(@fs.path_exists(out_dir + "/assets/odt-red.png"))
}

///|
test "main cli persists odp local assets only at output boundary" {
  let root = test_tmp_root() + "/main-cli-odp-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let out_dir = root + "/out"
  let out_path = out_dir + "/odp_basic_assets.md"
  ensure_dir_tree(out_dir)
  let persisted = match
    run_cli(
      cli_options(
        "samples/fixtures/contracts/odp/odp_basic_assets.odp",
        Some(out_path),
        Some(@input.DetectedFormat::Odp),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("odp local asset cli failed: " + msg)
  }
  assert_true(persisted.contains("![red-dot](assets/odp-slide1-red.png)"))
  let persisted_markdown = read_utf8_text(out_path)
  assert_true(
    persisted_markdown.contains("![red-dot](assets/odp-slide1-red.png)"),
  )
  assert_true(@fs.path_exists(out_dir + "/assets/odp-slide1-red.png"))
}

///|
test "main cli keeps epub local assets output boundary only and remote data assets no fetch" {
  let root = test_tmp_root() + "/main-cli-epub-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let out_dir = root + "/out"
  let local_md = out_dir + "/local.md"
  let remote_md = out_dir + "/remote.md"
  ensure_dir_tree(out_dir)

  let local_rendered = match
    run_cli(
      cli_options(
        "samples/fixtures/contracts/epub/epub_local_image_basic.epub",
        Some(local_md),
        Some(@input.DetectedFormat::Epub),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current epub local asset cli failed: " + msg)
  }
  assert_true(
    local_rendered.contains(
      "![cover art](assets/archive/OPS_chapter.xhtml/image01.png)",
    ),
  )
  let persisted_local = read_utf8_text(local_md)
  assert_true(
    persisted_local.contains(
      "![cover art](assets/archive/OPS_chapter.xhtml/image01.png)",
    ),
  )
  assert_true(
    @fs.path_exists(out_dir + "/assets/archive/OPS_chapter.xhtml/image01.png"),
  )

  let remote_rendered = match
    run_cli(
      cli_options(
        "samples/fixtures/contracts/epub/epub_remote_data_image_boundary.epub",
        Some(remote_md),
        Some(@input.DetectedFormat::Epub),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current epub remote asset cli failed: " + msg)
  }
  assert_true(remote_rendered.contains("# Boundary Chapter"))
  let persisted_remote = read_utf8_text(remote_md)
  assert_true(persisted_remote.contains("# Boundary Chapter"))
  assert_true(!persisted_remote.contains("https://example.com/a.png"))
  assert_true(!persisted_remote.contains("data:image/png"))
  assert_true(
    !@fs.path_exists(out_dir + "/assets/archive/OPS_chapter.xhtml/image02.png"),
  )
}

///|
test "main cli restores docx xlsx pptx and native-text pdf" {
  let root = test_tmp_root() + "/main-cli-unsupported"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let docx_path = root + "/sample.docx"
  let pptx_path = root + "/sample.pptx"
  let xlsx_path = root + "/sample.xlsx"
  let pdf_path = root + "/sample.pdf"
  let docx_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/docx/docx_image_alt_title.docx",
  ) catch {
    e => fail("read docx sample failed: " + e.to_string())
  }
  @fs.write_bytes_to_file(docx_path, docx_bytes) catch {
    e => fail("write docx sample failed: " + e.to_string())
  }
  let pptx_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/pptx/pptx_hidden_slide_basic.pptx",
  ) catch {
    e => fail("read pptx sample failed: " + e.to_string())
  }
  @fs.write_bytes_to_file(pptx_path, pptx_bytes) catch {
    e => fail("write pptx sample failed: " + e.to_string())
  }
  let xlsx_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/xlsx/sheet_simple.xlsx",
  ) catch {
    e => fail("read xlsx sample failed: " + e.to_string())
  }
  @fs.write_bytes_to_file(xlsx_path, xlsx_bytes) catch {
    e => fail("write xlsx sample failed: " + e.to_string())
  }
  let pdf_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/pdf/root_native_text_baseline.pdf",
  ) catch {
    e => fail("read pdf sample failed: " + e.to_string())
  }
  @fs.write_bytes_to_file(pdf_path, pdf_bytes) catch {
    e => fail("write pdf sample failed: " + e.to_string())
  }

  let docx = run_cli(
    cli_options(docx_path, None, None, @convert.OutputFormat::Markdown),
  )
  let pptx = run_cli(
    cli_options(pptx_path, None, None, @convert.OutputFormat::Markdown),
  )
  let xlsx = run_cli(
    cli_options(xlsx_path, None, None, @convert.OutputFormat::Markdown),
  )
  let epub = run_cli(
    cli_options(
      "samples/fixtures/contracts/epub/epub_basic_package.epub",
      None,
      None,
      @convert.OutputFormat::Markdown,
    ),
  )
  let pdf = run_cli(
    cli_options(pdf_path, None, None, @convert.OutputFormat::Markdown),
  )
  match docx {
    Ok(value) => {
      assert_true(value.contains("![Figure alt text](assets/image01.png)"))
      assert_true(value.contains("*Figure title text*"))
    }
    Err(msg) => fail("docx should be restored: " + msg)
  }
  match pptx {
    Ok(value) => {
      assert_true(value.contains("## Slide 1"))
      assert_true(value.contains("### Third"))
      assert_true(!value.contains("(hidden)"))
      assert_true(!value.contains("## Slide 2"))
    }
    Err(msg) => fail("pptx should be restored: " + msg)
  }
  match xlsx {
    Ok(value) => {
      assert_true(value.contains("## Sheet1"))
      assert_true(value.contains("| Name | Value | 备注 |"))
      assert_true(value.contains("## Data"))
    }
    Err(msg) => fail("xlsx should be restored: " + msg)
  }
  match epub {
    Ok(value) => {
      assert_true(value.contains("# OPS/chapter.xhtml"))
      assert_true(value.contains("# Basic Chapter"))
    }
    Err(msg) => fail("epub should be restored: " + msg)
  }
  match pdf {
    Ok(value) =>
      assert_eq(
        value.trim_end().to_owned(),
        read_utf8_text(
          "samples/fixtures/contracts/pdf/root_native_text_baseline.expected.md",
        )
        .trim_end()
        .to_owned(),
      )
    Err(msg) => fail("pdf should be restored on main cli: " + msg)
  }
}

///|
test "main cli persists html local assets only at output boundary" {
  let root = test_tmp_root() + "/main-cli-html-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let input_dir = root + "/input"
  let image_dir = input_dir + "/img"
  let out_dir = root + "/out"
  ensure_dir_tree(image_dir)
  ensure_dir_tree(out_dir)
  let input_path = input_dir + "/sample.html"
  let output_path = out_dir + "/sample.md"
  write_utf8_text(
    input_path,
    "<p><img src=\"img/img_red.jpg\" alt=\"single\"></p>\n" +
    "<p><img src=\"https://example.com/remote.png\" alt=\"remote\"></p>\n",
  )
  let source_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/html/img_red.jpg",
  ) catch {
    e => fail("read html asset sample failed: " + e.to_string())
  }
  @fs.write_bytes_to_file(image_dir + "/img_red.jpg", source_bytes) catch {
    e => fail("write html asset sample failed: " + e.to_string())
  }

  let rendered = match
    run_cli(
      cli_options(
        input_path,
        Some(output_path),
        Some(@input.DetectedFormat::Html),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current html cli asset persistence failed: " + msg)
  }

  assert_true(rendered.contains("![single](assets/image01.jpg)"))
  assert_true(rendered.contains("[remote]"))
  let persisted_markdown = read_utf8_text(output_path)
  assert_true(persisted_markdown.contains("![single](assets/image01.jpg)"))
  assert_true(persisted_markdown.contains("[remote]"))
  let copied_asset_path = out_dir + "/assets/image01.jpg"
  assert_true(@fs.path_exists(copied_asset_path))
  assert_true(!@fs.path_exists(out_dir + "/assets/image02.png"))
  let copied_bytes = @fs.read_file_to_bytes(copied_asset_path) catch {
    e => fail("read copied html asset failed: " + e.to_string())
  }
  assert_true(copied_bytes.to_array() == source_bytes.to_array())
}

///|
test "main cli converts yaml and yml through isolated product shell" {
  let root = test_tmp_root() + "/main-cli-yaml"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let yaml_path = root + "/demo.yaml"
  let yml_path = root + "/demo.yml"
  write_utf8_text(yaml_path, "name: Alice\nrole: Engineer\n")
  write_utf8_text(yml_path, "kind: sample\nstatus: true\n")

  let yaml = match
    run_cli(cli_options(yaml_path, None, None, @convert.OutputFormat::Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current yaml cli failed: " + msg)
  }
  let yml = match
    run_cli(cli_options(yml_path, None, None, @convert.OutputFormat::Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current yml cli failed: " + msg)
  }

  assert_true(yaml.contains("| Key | Value |"))
  assert_true(yaml.contains("| name | Alice |"))
  assert_true(yml.contains("| Key | Value |"))
  assert_true(yml.contains("| kind | sample |"))
}
