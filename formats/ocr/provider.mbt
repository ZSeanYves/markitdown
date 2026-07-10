///|
/// OCR backends currently supported by the product runtime.
pub(all) enum OcrProviderKind {
  Tesseract
  PaddleOcr
} derive(Eq)

///|
/// Coarse execution status categories returned by OCR providers.
pub(all) enum OcrProviderStatus {
  NotConfigured
  CommandUnavailable
  ExecutionFailed
  OutputParseFailed
  EmptyResult
} derive(Eq)

///|
/// OCR request passed to a concrete provider implementation.
///
/// `image_path` is kept for single-image compatibility, while `image_paths`
/// carries the canonical batch payload.
pub struct OcrProviderRequest {
  image_path : String
  image_paths : Array[String]
  language : String?
  provider_kind : OcrProviderKind
}

///|
/// Per-image provider result used for batch OCR execution summaries.
pub struct OcrProviderJobResult {
  image_path : String
  status : String
  error_kind : String?
  error_message : String?
  pages : Array[OcrPageModel]
  diagnostics : Array[String]
}

///|
/// Aggregated OCR provider result returned to parser code.
///
/// `jobs` keeps per-image execution details, while `pages` exposes the
/// flattened OCR page models consumed by the parser and lowering logic.
pub struct OcrProviderResult {
  pages : Array[OcrPageModel]
  provider_name : String
  provider_version : String?
  diagnostics : Array[String]
  jobs : Array[OcrProviderJobResult]
}

///|
/// Provider error categories surfaced through runtime boundaries.
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
/// Construct a single-image OCR provider request.
pub fn make_ocr_provider_request(
  image_path : String,
  provider_kind : OcrProviderKind,
  language? : String? = None,
) -> OcrProviderRequest {
  { image_path, image_paths: [image_path], language, provider_kind }
}

///|
/// Construct a batch OCR provider request.
pub fn make_ocr_provider_batch_request(
  image_paths : Array[String],
  provider_kind : OcrProviderKind,
  language? : String? = None,
) -> OcrProviderRequest {
  let first_path = if image_paths.length() > 0 { image_paths[0] } else { "" }
  { image_path: first_path, image_paths, language, provider_kind }
}

///|
/// Return the first image path carried by a provider request.
pub fn ocr_provider_request_first_image_path(
  request : OcrProviderRequest,
) -> String {
  request.image_paths[0]
}

///|
/// Construct one per-image OCR job result.
pub fn make_ocr_provider_job_result(
  image_path : String,
  status? : String = "ok",
  error_kind? : String? = None,
  error_message? : String? = None,
  pages : Array[OcrPageModel],
  diagnostics? : Array[String] = [],
) -> OcrProviderJobResult {
  { image_path, status, error_kind, error_message, pages, diagnostics }
}

///|
/// Construct one aggregated OCR provider result.
pub fn make_ocr_provider_result(
  pages : Array[OcrPageModel],
  provider_name : String,
  provider_version? : String? = None,
  diagnostics? : Array[String] = [],
  jobs? : Array[OcrProviderJobResult] = [],
) -> OcrProviderResult {
  { pages, provider_name, provider_version, diagnostics, jobs }
}

///|
/// Stable diagnostics/provenance label for one OCR provider kind.
pub fn ocr_provider_kind_name(kind : OcrProviderKind) -> String {
  match kind {
    OcrProviderKind::Tesseract => "tesseract"
    OcrProviderKind::PaddleOcr => "paddle_ocr"
  }
}

///|
/// Product-level selection targets that decide which OCR backend should be
/// preferred or allowed to fall back.
pub(all) enum OcrProviderSelectionTarget {
  DirectImageBalanced
  DirectImageAccurate
  PdfAccurate
} derive(Eq)

///|
/// Return the default OCR backend for one selection target.
pub fn default_ocr_provider_kind_for_target(
  target : OcrProviderSelectionTarget,
) -> OcrProviderKind {
  match target {
    OcrProviderSelectionTarget::DirectImageBalanced =>
      OcrProviderKind::Tesseract
    OcrProviderSelectionTarget::DirectImageAccurate =>
      OcrProviderKind::PaddleOcr
    OcrProviderSelectionTarget::PdfAccurate => OcrProviderKind::PaddleOcr
  }
}

///|
/// Stable diagnostics/provenance label for one provider selection target.
pub fn ocr_provider_selection_target_name(
  target : OcrProviderSelectionTarget,
) -> String {
  match target {
    OcrProviderSelectionTarget::DirectImageBalanced => "direct_image_balanced"
    OcrProviderSelectionTarget::DirectImageAccurate => "direct_image_accurate"
    OcrProviderSelectionTarget::PdfAccurate => "pdf_accurate"
  }
}

///|
/// Stable diagnostics/provenance label for one provider status.
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
/// Map a provider error to its coarse status category.
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
/// Return a stable printable language label for diagnostics and provenance.
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
    "paddle_ocr_wrapper"
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
    "Direct image OCR and Tesseract-backed fallback routes require a local Tesseract runtime on this machine.",
    ["./tools/env/install_ocr_balance_deps.sh"],
    ["./tools/env/install_ocr_balance_deps.sh"],
    footer=Some(
      "The install script records the repo-managed Tesseract path under `./env/managed-paths/tesseract`. Custom overrides can still use `MARKITDOWN_TESSERACT_BIN`, but repo-managed defaults win first.",
    ),
  )
}

///|
pub fn tesseract_ocr_dependency_diagnostic() -> @core.DependencyDiagnostic {
  dependency_diagnostic_entry(
    "Missing dependency: Tesseract OCR",
    "Direct image OCR and Tesseract-backed fallback routes require a local Tesseract runtime on this machine.",
    ["./tools/env/install_ocr_balance_deps.sh"],
    ["./tools/env/install_ocr_balance_deps.sh"],
    footer=Some(
      "The install script records the repo-managed Tesseract path under `./env/managed-paths/tesseract`. Custom overrides can still use `MARKITDOWN_TESSERACT_BIN`, but repo-managed defaults win first.",
    ),
  )
}

///|
pub fn paddle_ocr_install_hint() -> String {
  dependency_diagnostic_card(
    "Missing dependency: PaddleOCR wrapper",
    "Accurate OCR and Accurate PDF OCR require a Paddle-backed wrapper command. Repo-root runs prefer the official repo-managed runtime after `./tools/env/install_ocr_pdf_accurate_deps.sh`; `MARKITDOWN_PADDLE_OCR_CMD` remains the lower-priority custom wrapper command, and `MARKITDOWN_RUNTIME_PYTHON` is the secondary official-wrapper fallback when the repo-managed runtime is unavailable.",
    [
      "./tools/env/install_ocr_pdf_accurate_deps.sh", "source ./env/accurate-ocr-pdf.env.sh",
    ],
    [
      "./tools/env/install_ocr_pdf_accurate_deps.sh", "source ./env/accurate-ocr-pdf.env.sh",
    ],
    footer=Some(
      "The install script keeps Paddle Python packages in the repo-local virtualenv under `./env/`, and records repo-managed `tesseract`/`pdftoppm` paths under `./env/managed-paths/`. If you run from the repo root, `source ./env/accurate-ocr-pdf.env.sh` is optional; use it when you want the wrapper paths exported into another shell.",
    ),
  )
}

///|
pub fn paddle_ocr_dependency_diagnostic() -> @core.DependencyDiagnostic {
  dependency_diagnostic_entry(
    "Missing dependency: PaddleOCR wrapper",
    "Accurate OCR and Accurate PDF OCR require a Paddle-backed wrapper command. Repo-root runs prefer the official repo-managed runtime after `./tools/env/install_ocr_pdf_accurate_deps.sh`; `MARKITDOWN_PADDLE_OCR_CMD` remains the lower-priority custom wrapper command, and `MARKITDOWN_RUNTIME_PYTHON` is the secondary official-wrapper fallback when the repo-managed runtime is unavailable.",
    [
      "./tools/env/install_ocr_pdf_accurate_deps.sh", "source ./env/accurate-ocr-pdf.env.sh",
    ],
    [
      "./tools/env/install_ocr_pdf_accurate_deps.sh", "source ./env/accurate-ocr-pdf.env.sh",
    ],
    footer=Some(
      "The install script keeps Paddle Python packages in the repo-local virtualenv under `./env/`, and records repo-managed `tesseract`/`pdftoppm` paths under `./env/managed-paths/`. If you run from the repo root, `source ./env/accurate-ocr-pdf.env.sh` is optional; use it when you want the wrapper paths exported into another shell.",
    ),
  )
}
