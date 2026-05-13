///|
pub enum OcrProviderKind {
  Noop
  ExternalCommand
} derive(Eq)

///|
pub enum OcrProviderErrorKind {
  UnknownProvider
  Unavailable
  NotImplemented
  RecognitionFailed
} derive(Eq)

///|
pub struct OcrProviderInfo {
  name : String
  version : String?
  license : String?
  kind : OcrProviderKind
  available : Bool
  unavailable_reason : String?
  probed : Bool
}

///|
pub struct OcrOptions {
  languages : Array[String]
  page_range : String?
  output_text_only : Bool
}

///|
pub struct OcrPageResult {
  page_index : Int
  text : String
  confidence : Double?
  language : String?
  warnings : Array[String]
}

///|
#warnings("-struct_never_constructed")
pub struct OcrDocumentResult {
  provider : OcrProviderInfo
  pages : Array[OcrPageResult]
  warnings : Array[String]
}

///|
pub struct OcrProviderError {
  kind : OcrProviderErrorKind
  message : String
}

///|
pub fn default_ocr_options() -> OcrOptions {
  { languages: [], page_range: None, output_text_only: true }
}

///|
pub fn make_ocr_options(
  languages : Array[String],
  page_range : String?,
  output_text_only : Bool,
) -> OcrOptions {
  { languages, page_range, output_text_only }
}

///|
pub fn noop_ocr_provider_info() -> OcrProviderInfo {
  {
    name: "noop",
    version: None,
    license: None,
    kind: OcrProviderKind::Noop,
    available: true,
    unavailable_reason: None,
    probed: false,
  }
}

///|
pub fn list_known_ocr_providers() -> Array[OcrProviderInfo] {
  [
    noop_ocr_provider_info(),
    deferred_external_ocr_provider_info(
      "tesseract-cli",
      Some("Apache-2.0"),
      "explicit external CLI candidate; not probed in normal mode",
    ),
    deferred_external_ocr_provider_info(
      "ocrmypdf-cli",
      Some("MPL-2.0"),
      "explicit PDF-wrapper OCR candidate; not probed in normal mode",
    ),
    deferred_external_ocr_provider_info(
      "paddleocr",
      Some("Apache-2.0 (code); models/runtime require separate review"),
      "heavy optional provider candidate; not probed in normal mode",
    ),
  ]
}

///|
pub async fn probe_known_ocr_provider(name : String) -> OcrProviderInfo? {
  let _ = @async.now()
  match canonical_ocr_provider_name(name) {
    Some("noop") => Some({ ..noop_ocr_provider_info(), probed: true })
    Some("tesseract-cli") =>
      Some(
        probe_external_ocr_provider(
          "tesseract-cli",
          Some("Apache-2.0"),
          provider_command_path("tesseract-cli", "tesseract"),
          ["--version"],
        ),
      )
    Some("ocrmypdf-cli") =>
      Some(
        probe_external_ocr_provider(
          "ocrmypdf-cli",
          Some("MPL-2.0"),
          "ocrmypdf",
          ["--version"],
        ),
      )
    Some("paddleocr") =>
      Some(
        probe_external_ocr_provider(
          "paddleocr",
          Some("Apache-2.0 (code); models/runtime require separate review"),
          "paddleocr",
          ["--help"],
        ),
      )
    _ => None
  }
}

///|
pub async fn recognize_page_with_ocr_provider(
  provider_name : String,
  page_index : Int,
  page_image_path : String,
  options : OcrOptions,
) -> Result[OcrPageResult, OcrProviderError] {
  match canonical_ocr_provider_name(provider_name) {
    Some("noop") =>
      Err(
        ocr_provider_error(
          OcrProviderErrorKind::NotImplemented,
          "noop OCR provider does not perform recognition",
        ),
      )
    Some("tesseract-cli") =>
      recognize_page_with_tesseract(page_index, page_image_path, options)
    Some("ocrmypdf-cli") | Some("paddleocr") =>
      Err(
        ocr_provider_error(
          OcrProviderErrorKind::Unavailable,
          "OCR provider skeleton does not execute external runtimes yet",
        ),
      )
    _ =>
      Err(
        ocr_provider_error(
          OcrProviderErrorKind::UnknownProvider,
          "unknown OCR provider: " + provider_name,
        ),
      )
  }
}

///|
pub fn recognize_pdf_with_ocr_provider(
  provider_name : String,
  input_path : String,
  _options : OcrOptions,
) -> Result[OcrDocumentResult, OcrProviderError] {
  match canonical_ocr_provider_name(provider_name) {
    Some("noop") =>
      Err(
        ocr_provider_error(
          OcrProviderErrorKind::NotImplemented,
          "noop OCR provider does not perform recognition",
        ),
      )
    Some("tesseract-cli") =>
      Err(
        ocr_provider_error(
          OcrProviderErrorKind::NotImplemented,
          "tesseract-cli provider currently supports page-image OCR only: " +
          input_path,
        ),
      )
    Some("ocrmypdf-cli") | Some("paddleocr") =>
      Err(
        ocr_provider_error(
          OcrProviderErrorKind::Unavailable,
          "OCR provider skeleton does not execute external runtimes yet",
        ),
      )
    _ =>
      Err(
        ocr_provider_error(
          OcrProviderErrorKind::UnknownProvider,
          "unknown OCR provider: " + provider_name,
        ),
      )
  }
}

///|
fn deferred_external_ocr_provider_info(
  name : String,
  license : String?,
  reason : String,
) -> OcrProviderInfo {
  {
    name,
    version: None,
    license,
    kind: OcrProviderKind::ExternalCommand,
    available: false,
    unavailable_reason: Some(reason),
    probed: false,
  }
}

///|
async fn recognize_page_with_tesseract(
  page_index : Int,
  page_image_path : String,
  options : OcrOptions,
) -> Result[OcrPageResult, OcrProviderError] {
  let langs = normalized_ocr_languages(options.languages)
  let cmd = provider_command_path("tesseract-cli", "tesseract")
  let args = build_tesseract_page_args(page_image_path, langs)
  run_tesseract_page_command(cmd, args, page_index, langs)
}

///|
async fn run_tesseract_page_command(
  command : String,
  args : Array[String],
  page_index : Int,
  langs : String,
) -> Result[OcrPageResult, OcrProviderError] {
  match collect_process_output(command, args) {
    Ok((status, stdout, stderr)) =>
      if status == 0 {
        let warnings = collect_ocr_warnings(stderr)
        Ok({
          page_index,
          text: stdout,
          confidence: None,
          language: Some(langs),
          warnings,
        })
      } else {
        Err(
          ocr_provider_error(
            OcrProviderErrorKind::RecognitionFailed,
            render_tesseract_failure_message(status, stderr, langs),
          ),
        )
      }
    Err(err) =>
      Err(
        ocr_provider_error(
          OcrProviderErrorKind::Unavailable,
          "tesseract-cli unavailable: " + err,
        ),
      )
  }
}

///|
async fn probe_external_ocr_provider(
  name : String,
  license : String?,
  command : String,
  version_args : Array[String],
) -> OcrProviderInfo {
  match collect_process_output(command, version_args) {
    Ok((status, stdout, stderr)) =>
      if status == 0 {
        {
          name,
          version: first_nonempty_line_either(stdout, stderr),
          license,
          kind: OcrProviderKind::ExternalCommand,
          available: true,
          unavailable_reason: None,
          probed: true,
        }
      } else {
        {
          name,
          version: first_nonempty_line_either(stdout, stderr),
          license,
          kind: OcrProviderKind::ExternalCommand,
          available: false,
          unavailable_reason: Some(
            "probe command exited with status " + status.to_string(),
          ),
          probed: true,
        }
      }
    Err(err) =>
      {
        name,
        version: None,
        license,
        kind: OcrProviderKind::ExternalCommand,
        available: false,
        unavailable_reason: Some(err),
        probed: true,
      }
  }
}

///|
fn build_tesseract_page_args(
  page_image_path : String,
  langs : String,
) -> Array[String] {
  [page_image_path, "stdout", "-l", langs]
}

///|
fn normalized_ocr_languages(languages : Array[String]) -> String {
  let kept : Array[String] = []
  for raw in languages {
    let lang = raw.trim().to_owned()
    if lang == "" || !is_valid_ocr_language_token(lang) {
      continue
    }
    kept.push(lang)
  }
  if kept.length() == 0 {
    "eng"
  } else {
    kept.join("+")
  }
}

///|
fn is_valid_ocr_language_token(token : String) -> Bool {
  for ch in token.to_array() {
    if !is_valid_ocr_language_char(ch) {
      return false
    }
  }
  token != ""
}

///|
fn is_valid_ocr_language_char(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  ch == '_' ||
  ch == '-' ||
  ch == '.'
}

///|
fn collect_ocr_warnings(stderr : String) -> Array[String] {
  let warnings : Array[String] = []
  match first_nonempty_line(stderr) {
    Some(line) => warnings.push(line)
    None => ()
  }
  warnings
}

///|
fn render_tesseract_failure_message(
  status : Int,
  stderr : String,
  langs : String,
) -> String {
  let base = "tesseract-cli recognition failed with status " +
    status.to_string() +
    " (langs=" +
    langs +
    ")"
  match first_nonempty_line(stderr) {
    Some(line) => base + ": " + line
    None => base
  }
}

///|
fn provider_command_path(name : String, default_command : String) -> String {
  let env_name = provider_command_path_env_name(name)
  match @sys.get_env_var(env_name) {
    Some(raw) => {
      let trimmed = raw.trim().to_owned()
      if trimmed == "" {
        default_command
      } else {
        trimmed
      }
    }
    None => default_command
  }
}

///|
fn provider_command_path_env_name(name : String) -> String {
  "MARKITDOWN_OCR_PROVIDER_CMD_" +
  name.replace(old="-", new="_").replace(old=".", new="_").to_upper()
}

///|
fn first_nonempty_line_either(stdout : String, stderr : String) -> String? {
  match first_nonempty_line(stdout) {
    Some(line) => Some(line)
    None => first_nonempty_line(stderr)
  }
}

///|
fn first_nonempty_line(text : String) -> String? {
  for sv in text.split("\n") {
    let line = sv.trim().to_owned()
    if line != "" {
      return Some(line)
    }
  }
  None
}

///|
fn canonical_ocr_provider_name(name : String) -> String? {
  let t = name.trim().to_owned()
  if t == "noop" {
    Some(t)
  } else if t == "tesseract-cli" {
    Some(t)
  } else if t == "ocrmypdf-cli" {
    Some(t)
  } else if t == "paddleocr" {
    Some(t)
  } else {
    None
  }
}

///|
fn ocr_provider_error(
  kind : OcrProviderErrorKind,
  message : String,
) -> OcrProviderError {
  { kind, message }
}
