///|
fn test_tmp_root() -> String {
  ".tmp/tests/cli"
}

///|
fn recreate_clean_dir(path : String) -> Unit raise {
  @therm.recreate_clean_dir(path)
}

///|
fn cleanup_temp_dir(path : String) -> Unit {
  @therm.cleanup_temp_dir(path)
}

///|
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @therm.write_utf8_text(path, text)
}

///|
fn read_utf8_text(path : String) -> String {
  @therm.read_utf8_text(path)
}

///|
fn run_cli_without_emitting_warnings(
  opts : CliOptions,
) -> Result[String, String] {
  let requested_format = cli_requested_format(opts)
  if !cli_is_supported_format(requested_format) {
    return Err(
      cli_fail_closed_format_message(
        opts.input,
        requested_format,
        cli_requested_format_label(opts),
        opts.ocr_options,
        opts.fidelity_mode,
      ),
    )
  }
  let convert_options = @convert.make_convert_options(
    opts.convert_mode,
    opts.output_format,
    opts.explicit_format,
    opts.ocr_options,
    @convert.default_resource_limits(),
    audio_options=opts.audio_options,
    fidelity_mode=opts.fidelity_mode,
    output_mode=opts.output_mode,
    stream_requested=opts.stream_requested,
    rag_options=opts.rag_options,
  )
  let execution = match
    @convert.convert_input_with_provenance_and_image_ocr_provider(
      @input.input_from_path(opts.input),
      convert_options,
      @focr.run_ocr_provider,
    ) {
    Ok(value) => value
    Err(err) => return Err(err.to_string())
  }
  persist_cli_provenance(opts, execution.provenance) catch {
    err => return Err("write provenance failed: " + err.to_string())
  }
  cli_render_convert_result(opts, execution.result)
}

///|
fn fake_cli_pdf_rasterizer(
  page_count : Int,
) -> (@input.InputSource) -> Result[
  (@fpdf.PdfRasterResult, String),
  @fpdf.PdfRasterizerError,
] {
  fn(source : @input.InputSource) {
    @fpdf.rasterize_pdf_with_pdftoppm(source, fn(
      _cmd : String,
      args : Array[String],
    ) {
      let output_prefix = args[2]
      let parts = output_prefix
        .split("/")
        .to_array()
        .map(fn(part) { part.to_owned() })
      let output_dir = parts[:parts.length() - 1].join("/")
      @therm.ensure_dir_tree(output_dir) catch {
        e =>
          return Err(
            @fpdf.PdfRasterizerError::ExecutionFailed(
              "failed to create fake raster output dir: " + e.to_string(),
            ),
          )
      }
      for i in 0..<page_count {
        let page_name = output_dir + "/page-" + (i + 1).to_string() + ".png"
        @fs.write_bytes_to_file(page_name, Bytes::from_array([])) catch {
          e =>
            return Err(
              @fpdf.PdfRasterizerError::ExecutionFailed(
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
fn fake_cli_failing_image_provider(
  expected_input : String,
  expected_language : String?,
  error : @focr.OcrProviderError,
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
    Err(error)
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
  audio_options? : @parser.AudioOptions = @parser.default_audio_options(),
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
    rag_options=@rag.default_rag_options(),
    audio_options~,
  )
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
fn fake_cli_pdf_ocr_provider(
  expected_language : String?,
  expected_pages : Int,
) -> (@focr.OcrProviderRequest) -> Result[
  @focr.OcrProviderResult,
  @focr.OcrProviderError,
] {
  fn(request : @focr.OcrProviderRequest) {
    if request.language != expected_language {
      abort("unexpected OCR language")
    }
    if request.image_paths.length() != expected_pages {
      abort("unexpected OCR page count")
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
        abort("expected fake cli PDF OCR TSV parse success: " + err.to_string())
    }
    let page_model = parsed.pages[0]
    let jobs = request.image_paths.map(fn(path) {
      @focr.make_ocr_provider_job_result(path, [page_model])
    })
    Ok(@focr.make_ocr_provider_result([], "mock_paddle", jobs~))
  }
}
