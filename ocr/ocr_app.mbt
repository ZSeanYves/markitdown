///|
async fn cmd_ocr(
  input : String,
  output : String?,
  provider_name : String?,
  lang_arg : String?,
  with_metadata : Bool,
) -> Unit {
  match run_ocr_cli(input, output, provider_name, lang_arg, with_metadata) {
    Ok(_) => ()
    Err(msg) => @clicom.exit_error(msg)
  }
}

///|
async fn run_ocr_cli(
  input : String,
  output : String?,
  provider_name : String?,
  lang_arg : String?,
  with_metadata : Bool,
) -> Result[Unit, String] {
  let provider = provider_name
    .map(fn(name) { name.trim().to_owned() })
    .unwrap_or("tesseract-cli")
  let langs = @clicom.parse_ocr_lang_arg(lang_arg)
  let image_format = @clicom.detect_ocr_image_format(input)

  if image_format != None {
    let options = @pdfocr.make_ocr_options(langs, None, !with_metadata)
    return run_image_ocr_cli(provider, input, output, options)
  }

  if @clicom.detect_input_format(input) == "pdf" {
    if provider == "tesseract-cli" || provider == "" {
      let doc = @pdfocr.parse_pdf_via_ocr(input, "", 6, false)
      return @clicom.write_document_output(
        input, "pdf", doc, output, with_metadata,
      )
    }

    return Err(
      "direct PDF OCR is not implemented for provider " +
      provider +
      "; use image input or a future OCRmyPDF/provider route",
    )
  }

  Err(
    "OCR input type is unsupported for provider mode: " +
    input +
    " (supported image inputs: png/jpg/jpeg/tif/tiff/bmp/webp; PDF stays on explicit PDF OCR path)",
  )
}

///|
async fn run_image_ocr_cli(
  provider_name : String,
  input : String,
  output : String?,
  options : @pdfocr.OcrOptions,
) -> Result[Unit, String] {
  let provider = if provider_name.trim() == "" {
    "tesseract-cli"
  } else {
    provider_name.trim().to_owned()
  }

  if !is_known_image_ocr_provider(provider) {
    return Err("unknown OCR provider: " + provider)
  }

  let probed = @pdfocr.probe_known_ocr_provider(provider)
  match probed {
    Some(info) =>
      if !info.available {
        return Err(render_unavailable_ocr_provider_message(info))
      }
    None => ()
  }

  let page = match
    @pdfocr.recognize_page_with_ocr_provider(provider, 0, input, options) {
    Ok(page) => page
    Err(err) => return Err(render_ocr_provider_error(provider, err))
  }

  match output {
    Some(path) => {
      let parent = @clicom.dirname_of_path(path)
      @clicom.ensure_dir_tree(parent) catch {
        e => return Err("create OCR output dir failed: " + e.to_string())
      }
      @fs.write_string_to_file(path, page.text, encoding="utf8") catch {
        e => return Err("write OCR output failed: " + e.to_string())
      }
    }
    None => println(page.text)
  }

  Ok(())
}

///|
fn is_known_image_ocr_provider(name : String) -> Bool {
  name == "noop" ||
  name == "tesseract-cli" ||
  name == "ocrmypdf-cli" ||
  name == "paddleocr"
}

///|
fn render_unavailable_ocr_provider_message(
  info : @pdfocr.OcrProviderInfo,
) -> String {
  let base = info.name +
    " unavailable: install Tesseract and language data, or choose another provider"
  match info.unavailable_reason {
    Some(reason) =>
      if reason.trim() == "" {
        base
      } else {
        base + " (" + reason + ")"
      }
    None => base
  }
}

///|
fn render_ocr_provider_error(
  provider_name : String,
  err : @pdfocr.OcrProviderError,
) -> String {
  match err.kind {
    @pdfocr.OcrProviderErrorKind::UnknownProvider =>
      "unknown OCR provider: " + provider_name
    @pdfocr.OcrProviderErrorKind::Unavailable => err.message
    @pdfocr.OcrProviderErrorKind::NotImplemented => err.message
    @pdfocr.OcrProviderErrorKind::RecognitionFailed => err.message
  }
}
