///|
pub(all) enum OcrProviderKind {
  Tesseract
} derive(Eq)

///|
pub(all) enum OcrProviderStatus {
  NotConfigured
  CommandUnavailable
  ExecutionFailed
  OutputParseFailed
  EmptyResult
} derive(Eq)

///|
pub struct OcrProviderRequest {
  image_path : String
  language : String?
  provider_kind : OcrProviderKind
}

///|
pub struct OcrProviderResult {
  pages : Array[OcrPageModel]
  provider_name : String
  provider_version : String?
  diagnostics : Array[String]
}

///|
pub(all) enum OcrProviderError {
  NotConfigured(String)
  CommandUnavailable(String)
  ExecutionFailed(String)
  OutputParseFailed(String)
  EmptyResult(String)
} derive(Eq)

///|
pub impl Show for OcrProviderError with fn to_string(self : OcrProviderError) -> String {
  match self {
    NotConfigured(msg) => msg
    CommandUnavailable(msg) => msg
    ExecutionFailed(msg) => msg
    OutputParseFailed(msg) => msg
    EmptyResult(msg) => msg
  }
}

///|
pub fn make_ocr_provider_request(
  image_path : String,
  provider_kind : OcrProviderKind,
  language? : String? = None,
) -> OcrProviderRequest {
  { image_path, language, provider_kind }
}

///|
pub fn make_ocr_provider_result(
  pages : Array[OcrPageModel],
  provider_name : String,
  provider_version? : String? = None,
  diagnostics? : Array[String] = [],
) -> OcrProviderResult {
  { pages, provider_name, provider_version, diagnostics }
}

///|
pub fn ocr_provider_kind_name(kind : OcrProviderKind) -> String {
  match kind {
    OcrProviderKind::Tesseract => "tesseract"
  }
}

///|
pub fn ocr_provider_status_name(status : OcrProviderStatus) -> String {
  match status {
    OcrProviderStatus::NotConfigured => "not_configured"
    OcrProviderStatus::CommandUnavailable => "command_unavailable"
    OcrProviderStatus::ExecutionFailed => "execution_failed"
    OcrProviderStatus::OutputParseFailed => "output_parse_failed"
    OcrProviderStatus::EmptyResult => "empty_result"
  }
}

///|
pub fn ocr_provider_error_status(error : OcrProviderError) -> OcrProviderStatus {
  match error {
    OcrProviderError::NotConfigured(_) => OcrProviderStatus::NotConfigured
    OcrProviderError::CommandUnavailable(_) =>
      OcrProviderStatus::CommandUnavailable
    OcrProviderError::ExecutionFailed(_) => OcrProviderStatus::ExecutionFailed
    OcrProviderError::OutputParseFailed(_) =>
      OcrProviderStatus::OutputParseFailed
    OcrProviderError::EmptyResult(_) => OcrProviderStatus::EmptyResult
  }
}

///|
pub fn ocr_provider_language_label(language : String?) -> String {
  match language {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        "none"
      } else {
        trimmed
      }
    }
    None => "none"
  }
}
