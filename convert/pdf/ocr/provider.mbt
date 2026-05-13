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
          "tesseract",
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
pub fn recognize_page_with_ocr_provider(
  provider_name : String,
  _page_index : Int,
  _page_image_path : String,
  _options : OcrOptions,
) -> Result[OcrPageResult, OcrProviderError] {
  match canonical_ocr_provider_name(provider_name) {
    Some("noop") =>
      Err(
        ocr_provider_error(
          OcrProviderErrorKind::NotImplemented,
          "noop OCR provider does not perform recognition",
        ),
      )
    Some("tesseract-cli") | Some("ocrmypdf-cli") | Some("paddleocr") =>
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
  _input_path : String,
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
    Some("tesseract-cli") | Some("ocrmypdf-cli") | Some("paddleocr") =>
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
