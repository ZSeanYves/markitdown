///|
const PRODUCT_NAME : String = "markitdown-mb"

///|
const PRODUCT_VERSION : String = "0.5.0"

///|
/// Parsed CLI options normalized into the convert-layer request model.
pub struct CliOptions {
  input : String
  output : String?
  provenance_output : String?
  explicit_format : @input.DetectedFormat?
  ocr_options : @parser.OcrOptions
  audio_options : @parser.AudioOptions
  fidelity_mode : @convert.FidelityMode
  convert_mode : @convert.ConvertMode
  output_mode : @convert.OutputMode
  stream_requested : Bool
  output_format : @convert.OutputFormat
  pdf_cleanup_mode : @convert.PdfCleanupMode
  pdf_table_mode : @convert.PdfTableMode
  rag_options : @rag.RagOptions
}

///|
pub(all) enum BatchTaskStatus {
  Success
  Failed
  Skipped
} derive(Eq)

///|
struct BatchTaskResult {
  input_path : String
  relative_path : String
  status : BatchTaskStatus
  detected_format : String
  convert_mode : String
  fidelity_mode : String
  output_mode : String
  output_path : String?
  selected_route : String?
  parser_mode : String?
  route_reason : String?
  warning_count : Int
  degraded_features : Array[String]
  error : String?
}

///|
fn batch_task_status_name(status : BatchTaskStatus) -> String {
  match status {
    BatchTaskStatus::Success => "success"
    BatchTaskStatus::Failed => "failed"
    BatchTaskStatus::Skipped => "skipped"
  }
}

///|
fn batch_task_result_to_json(entry : BatchTaskResult) -> Json {
  Json::object({
    "input_path": entry.input_path.to_json(),
    "relative_path": entry.relative_path.to_json(),
    "status": batch_task_status_name(entry.status).to_json(),
    "detected_format": entry.detected_format.to_json(),
    "convert_mode": entry.convert_mode.to_json(),
    "fidelity_mode": entry.fidelity_mode.to_json(),
    "output_mode": entry.output_mode.to_json(),
    "output_path": entry.output_path.to_json(),
    "selected_route": entry.selected_route.to_json(),
    "parser_mode": entry.parser_mode.to_json(),
    "route_reason": entry.route_reason.to_json(),
    "warning_count": entry.warning_count.to_json(),
    "degraded_features": entry.degraded_features.to_json(),
    "error": entry.error.to_json(),
  })
}

///|
fn cli_is_supported_format(format : @input.DetectedFormat) -> Bool {
  @formats.cli_supported_for_format(format)
}

///|
fn cli_product_name() -> String {
  PRODUCT_NAME
}

///|
fn cli_product_version() -> String {
  PRODUCT_VERSION
}

///|
/// Build a normalized CLI options record after argument parsing.
pub fn make_cli_options(
  input : String,
  output : String?,
  provenance_output : String?,
  explicit_format : @input.DetectedFormat?,
  ocr_options : @parser.OcrOptions,
  fidelity_mode : @convert.FidelityMode,
  convert_mode : @convert.ConvertMode,
  output_mode : @convert.OutputMode,
  stream_requested : Bool,
  output_format : @convert.OutputFormat,
  pdf_cleanup_mode? : @convert.PdfCleanupMode = @convert.default_pdf_cleanup_mode(),
  pdf_table_mode? : @convert.PdfTableMode = @convert.default_pdf_table_mode(),
  rag_options? : @rag.RagOptions = @rag.default_rag_options(),
  audio_options? : @parser.AudioOptions = @parser.default_audio_options(),
) -> CliOptions {
  {
    input,
    output,
    provenance_output,
    explicit_format,
    ocr_options,
    audio_options,
    fidelity_mode,
    convert_mode,
    output_mode,
    stream_requested,
    output_format,
    pdf_cleanup_mode,
    pdf_table_mode,
    rag_options,
  }
}
