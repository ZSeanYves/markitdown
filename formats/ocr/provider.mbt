///|
pub(all) enum OcrProviderKind {
  Tesseract
  PaddleOcr
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
    OcrProviderKind::PaddleOcr => "paddle_ocr"
  }
}

///|
pub(all) enum OcrProviderSelectionTarget {
  DirectImageBalanced
  DirectImageAccurate
  PdfBalanced
  PdfAccurate
} derive(Eq)

///|
pub fn default_ocr_provider_kind_for_target(
  target : OcrProviderSelectionTarget,
) -> OcrProviderKind {
  match target {
    OcrProviderSelectionTarget::DirectImageBalanced =>
      OcrProviderKind::Tesseract
    OcrProviderSelectionTarget::DirectImageAccurate =>
      OcrProviderKind::PaddleOcr
    OcrProviderSelectionTarget::PdfBalanced => OcrProviderKind::Tesseract
    OcrProviderSelectionTarget::PdfAccurate => OcrProviderKind::PaddleOcr
  }
}

///|
pub fn ocr_provider_selection_target_name(
  target : OcrProviderSelectionTarget,
) -> String {
  match target {
    OcrProviderSelectionTarget::DirectImageBalanced => "direct_image_balanced"
    OcrProviderSelectionTarget::DirectImageAccurate => "direct_image_accurate"
    OcrProviderSelectionTarget::PdfBalanced => "pdf_balanced"
    OcrProviderSelectionTarget::PdfAccurate => "pdf_accurate"
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

///|
fn dependency_card_lines(
  title : String,
  summary : String,
  macos_commands : Array[String],
  ubuntu_commands : Array[String],
  footer? : String? = None,
) -> Array[String] {
  let lines = [title, summary, "", "macOS:"]
  for command in macos_commands {
    lines.push("  " + command)
  }
  lines.push("")
  lines.push("Ubuntu:")
  for command in ubuntu_commands {
    lines.push("  " + command)
  }
  match footer {
    Some(note) => {
      let trimmed = note.trim().to_owned()
      if trimmed != "" {
        lines.push("")
        lines.push(trimmed)
      }
    }
    None => ()
  }
  lines
}

///|
fn dependency_diagnostic_kind_from_title(title : String) -> String {
  let lowered = title.to_lower()
  if lowered.contains("tesseract") {
    "tesseract_ocr"
  } else if lowered.contains("paddle") {
    "paddle_ocr_bridge"
  } else if lowered.contains("pdftoppm") || lowered.contains("poppler") {
    "pdftoppm"
  } else {
    let trimmed = lowered.trim().to_owned()
    let out : Array[Char] = []
    for ch in trimmed {
      if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
        out.push(ch)
      } else if ch == ' ' || ch == ':' || ch == '/' || ch == '-' {
        out.push('_')
      }
    }
    String::from_array(out)
  }
}

///|
pub fn dependency_diagnostic_card(
  title : String,
  summary : String,
  macos_commands : Array[String],
  ubuntu_commands : Array[String],
  footer? : String? = None,
) -> String {
  dependency_card_lines(
    title,
    summary,
    macos_commands,
    ubuntu_commands,
    footer~,
  ).join("\n")
}

///|
pub fn dependency_diagnostic_entry(
  title : String,
  summary : String,
  macos_commands : Array[String],
  ubuntu_commands : Array[String],
  footer? : String? = None,
) -> @core.DependencyDiagnostic {
  @core.make_dependency_diagnostic(
    dependency_diagnostic_kind_from_title(title),
    title,
    summary,
    @core.DependencyDiagnosticStatus::Missing,
    macos_commands,
    ubuntu_commands,
    footer~,
  )
}

///|
pub fn ocr_dependency_diagnostic_for_kind(
  kind : OcrProviderKind,
) -> @core.DependencyDiagnostic {
  match kind {
    OcrProviderKind::Tesseract => tesseract_ocr_dependency_diagnostic()
    OcrProviderKind::PaddleOcr => paddle_ocr_dependency_diagnostic()
  }
}

///|
pub fn ocr_dependency_diagnostic_for_target(
  target : OcrProviderSelectionTarget,
) -> @core.DependencyDiagnostic {
  ocr_dependency_diagnostic_for_kind(
    resolved_ocr_provider_kind_for_target(target),
  )
}

///|
pub fn tesseract_ocr_install_hint() -> String {
  dependency_diagnostic_card(
    "Missing dependency: Tesseract OCR",
    "Balanced OCR and Balanced PDF OCR require a local Tesseract runtime on this machine.",
    ["brew install tesseract", "brew install tesseract-lang"],
    ["sudo apt install tesseract-ocr", "sudo apt install tesseract-ocr-eng"],
    footer=Some(
      "Install extra language packs only when needed, for example `tesseract-ocr-chi-sim` or `tesseract-ocr-jpn`.",
    ),
  )
}

///|
pub fn tesseract_ocr_dependency_diagnostic() -> @core.DependencyDiagnostic {
  dependency_diagnostic_entry(
    "Missing dependency: Tesseract OCR",
    "Balanced OCR and Balanced PDF OCR require a local Tesseract runtime on this machine.",
    ["brew install tesseract", "brew install tesseract-lang"],
    ["sudo apt install tesseract-ocr", "sudo apt install tesseract-ocr-eng"],
    footer=Some(
      "Install extra language packs only when needed, for example `tesseract-ocr-chi-sim` or `tesseract-ocr-jpn`.",
    ),
  )
}

///|
pub fn paddle_ocr_install_hint() -> String {
  dependency_diagnostic_card(
    "Missing dependency: PaddleOCR bridge",
    "Accurate OCR and Accurate PDF OCR require a Paddle-backed bridge command configured through `MARKITDOWN_PADDLE_OCR_CMD`.",
    [
      "python3 -m pip install paddlepaddle paddleocr", "chmod +x samples/helpers/paddle_ocr_bridge.py",
      "export MARKITDOWN_PADDLE_OCR_CMD=\"$PWD/samples/helpers/paddle_ocr_bridge.py\"",
    ],
    [
      "python3 -m pip install paddlepaddle paddleocr", "chmod +x samples/helpers/paddle_ocr_bridge.py",
      "export MARKITDOWN_PADDLE_OCR_CMD=\"$PWD/samples/helpers/paddle_ocr_bridge.py\"",
    ],
    footer=Some(
      "The adapter receives `<image_path> [--lang <LANG>]` and must print the JSON payload expected by the current Paddle bridge contract.",
    ),
  )
}

///|
pub fn paddle_ocr_dependency_diagnostic() -> @core.DependencyDiagnostic {
  dependency_diagnostic_entry(
    "Missing dependency: PaddleOCR bridge",
    "Accurate OCR and Accurate PDF OCR require a Paddle-backed bridge command configured through `MARKITDOWN_PADDLE_OCR_CMD`.",
    [
      "python3 -m pip install paddlepaddle paddleocr", "chmod +x samples/helpers/paddle_ocr_bridge.py",
      "export MARKITDOWN_PADDLE_OCR_CMD=\"$PWD/samples/helpers/paddle_ocr_bridge.py\"",
    ],
    [
      "python3 -m pip install paddlepaddle paddleocr", "chmod +x samples/helpers/paddle_ocr_bridge.py",
      "export MARKITDOWN_PADDLE_OCR_CMD=\"$PWD/samples/helpers/paddle_ocr_bridge.py\"",
    ],
    footer=Some(
      "The adapter receives `<image_path> [--lang <LANG>]` and must print the JSON payload expected by the current Paddle bridge contract.",
    ),
  )
}
