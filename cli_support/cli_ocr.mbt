///|
/// Main-CLI OCR policy and image OCR execution.
///
/// The normal document path stays deterministic and native by default. This
/// file keeps explicit image OCR policy, fail-closed PDF/non-image OCR behavior,
/// and temporary OCR workspace handling away from the main conversion flow.
pub enum OcrPolicy {
  Auto
  Force
  Disable
} derive(Eq)

///|
pub struct OcrDecision {
  use_ocr : Bool
  continue_native : Bool
  reason : String
  fail_closed_message : String?
}

///|
pub fn default_ocr_policy() -> OcrPolicy {
  OcrPolicy::Auto
}

///|
pub fn force_ocr_policy() -> OcrPolicy {
  OcrPolicy::Force
}

///|
pub fn disable_ocr_policy() -> OcrPolicy {
  OcrPolicy::Disable
}

///|
pub fn parse_ocr_policy_flags(
  force_ocr : Bool,
  disable_ocr : Bool,
) -> Result[OcrPolicy, String] {
  if force_ocr && disable_ocr {
    return Err("--ocr and --no-ocr cannot be used together")
  }
  if force_ocr {
    return Ok(OcrPolicy::Force)
  }
  if disable_ocr {
    return Ok(OcrPolicy::Disable)
  }
  Ok(OcrPolicy::Auto)
}

///|
pub fn decide_ocr_policy(input : String, policy : OcrPolicy) -> OcrDecision {
  match detect_ocr_image_format(input) {
    Some(_) => decide_image_ocr_policy(policy)
    None => {
      let format = detect_input_format(input)
      if format == "pdf" {
        decide_pdf_ocr_policy(policy)
      } else {
        decide_non_image_ocr_policy(policy)
      }
    }
  }
}

///|
fn decide_image_ocr_policy(policy : OcrPolicy) -> OcrDecision {
  match policy {
    OcrPolicy::Auto | OcrPolicy::Force =>
      {
        use_ocr: true,
        continue_native: false,
        reason: "image_ocr_execute",
        fail_closed_message: None,
      }
    OcrPolicy::Disable =>
      {
        use_ocr: false,
        continue_native: false,
        reason: "image_ocr_disabled_no_native_path",
        fail_closed_message: Some(image_ocr_disabled_message()),
      }
  }
}

///|
fn decide_pdf_ocr_policy(policy : OcrPolicy) -> OcrDecision {
  match policy {
    OcrPolicy::Force =>
      {
        use_ocr: true,
        continue_native: false,
        reason: "pdf_ocr_not_wired",
        fail_closed_message: Some(pdf_ocr_not_wired_message()),
      }
    OcrPolicy::Auto | OcrPolicy::Disable =>
      {
        use_ocr: false,
        continue_native: true,
        reason: "native_pdf_path",
        fail_closed_message: None,
      }
  }
}

///|
fn decide_non_image_ocr_policy(policy : OcrPolicy) -> OcrDecision {
  match policy {
    OcrPolicy::Force =>
      {
        use_ocr: true,
        continue_native: false,
        reason: "force_ocr_non_image_not_supported",
        fail_closed_message: Some(non_image_force_ocr_not_supported_message()),
      }
    OcrPolicy::Auto | OcrPolicy::Disable =>
      {
        use_ocr: false,
        continue_native: true,
        reason: "native_document_path",
        fail_closed_message: None,
      }
  }
}

///|
fn image_ocr_disabled_message() -> String {
  "OCR disabled for image input; no native image-to-markdown conversion is available."
}

///|
fn pdf_ocr_not_wired_message() -> String {
  "PDF OCR is not wired in this build. Image OCR will use the main CLI OCR path; PDF OCR will require an explicit PDF OCR provider."
}

///|
fn non_image_force_ocr_not_supported_message() -> String {
  "OCR is only recognized for image inputs in this build; PDF OCR is not wired."
}

///|
async fn run_image_ocr_conversion(
  input : String,
  output : String?,
  with_metadata : Bool,
  ocr_lang : String?,
) -> Result[Unit, String] {
  let temp_root = image_ocr_temp_root_for_input(input)
  image_ocr_recreate_clean_dir(temp_root) catch {
    e =>
      return Err("Image OCR failed: prepare temp dir failed: " + e.to_string())
  }
  defer cleanup_image_ocr_temp_root(Some(temp_root))

  let signal_output_base = join_path(temp_root, "tesseract/output")
  let signal_output_dir = dirname_of_path(signal_output_base)
  ensure_dir_tree(signal_output_dir) catch {
    e =>
      return Err("Image OCR failed: prepare temp dir failed: " + e.to_string())
  }

  let page = match
    @vision.run_tesseract_tsv_signal(
      input,
      signal_output_base,
      @vision.make_tesseract_signal_options(
        lang=match ocr_lang {
          Some(lang) => lang
          None => ""
        },
      ),
    ) {
    Ok(page) => page
    Err(err) => return Err(map_image_ocr_signal_error(err))
  }
  let resegmented = @vision.resegment_ocr_page_lines_from_words(page)
  let layout = @vision.recover_ocr_layout_page(resegmented)
  let doc = @vision.convert_ocr_layout_page_to_ir(layout)
  write_document_output(input, "image-ocr", doc, output, with_metadata)
}

///|
fn map_image_ocr_signal_error(err : @vision.TesseractSignalError) -> String {
  match err.kind {
    @vision.TesseractSignalErrorKind::CommandFailed =>
      "Image OCR failed: tesseract executable was not available or failed. Install tesseract and language data, or use --no-ocr to disable image OCR."
    @vision.TesseractSignalErrorKind::MissingTsvOutput =>
      "Image OCR failed: tesseract executable was not available or failed. Install tesseract and language data, or use --no-ocr to disable image OCR."
    @vision.TesseractSignalErrorKind::InvalidOutputBase =>
      "Image OCR failed: invalid temporary OCR output path."
    @vision.TesseractSignalErrorKind::TsvParseFailed =>
      "Image OCR failed: tesseract produced invalid TSV output for this image."
  }
}

///|
fn validate_ocr_lang_usage(
  input : String,
  policy : OcrPolicy,
  raw : String?,
) -> Result[String?, String] {
  let normalized = match normalize_ocr_lang_cli_value(raw) {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  match normalized {
    None => Ok(None)
    Some(lang) => {
      if policy == OcrPolicy::Disable {
        return Err("--ocr-lang cannot be used when --no-ocr is set")
      }
      if detect_ocr_image_format(input) is Some(_) {
        return Ok(Some(lang))
      }
      if detect_input_format(input) == "pdf" && policy == OcrPolicy::Force {
        return Ok(Some(lang))
      }
      Err("--ocr-lang can only be used with image OCR in this build")
    }
  }
}

///|
fn normalize_ocr_lang_cli_value(raw : String?) -> Result[String?, String] {
  match raw {
    None => Ok(None)
    Some(value) => {
      let langs = parse_ocr_lang_arg(Some(value))
      if langs.length() == 0 {
        return Err("--ocr-lang must not be blank")
      }
      Ok(Some(langs.join("+")))
    }
  }
}

///|
fn image_ocr_temp_root_for_input(input : String) -> String {
  let base_root = match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(path) => if path.trim() == "" { ".tmp" } else { path }
    None => ".tmp"
  }
  base_root +
  "/helpers/ocr_cli/" +
  sanitize_image_ocr_path_component(input_stem(input)) +
  "-" +
  now_us().to_string()
}

///|
fn sanitize_image_ocr_path_component(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text {
    if is_image_ocr_path_safe_char(ch) {
      out.write_char(ch)
    } else {
      out.write_char('_')
    }
  }
  let sanitized = out.to_string()
  if sanitized.trim() == "" {
    "input"
  } else {
    sanitized
  }
}

///|
fn is_image_ocr_path_safe_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == '_' ||
  ch == '.'
}

///|
fn image_ocr_recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    image_ocr_remove_dir_recursive(path)
  }
  ensure_dir_tree(path)
}

///|
fn cleanup_image_ocr_temp_root(path : String?) -> Unit {
  match path {
    Some(root) =>
      ignore(
        try image_ocr_remove_dir_recursive(root) |> Ok catch {
          e => Err(e)
        },
      )
    None => ()
  }
}

///|
fn image_ocr_remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }

  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      image_ocr_remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }

  @fs.remove_dir(path)
}

///|
pub fn detect_ocr_image_format(path : String) -> String? {
  @clicom.detect_ocr_image_format(path)
}

///|
pub fn parse_ocr_lang_arg(raw : String?) -> Array[String] {
  @clicom.parse_ocr_lang_arg(raw)
}
