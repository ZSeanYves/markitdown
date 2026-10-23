///|
const PRODUCT_NAME : String = "markitdown-mb"

///|
const PRODUCT_VERSION : String = "0.8.0"

///|
/// Parsed CLI options normalized into the convert-layer request model.
///
/// This is the only structure the execution path should need after argument
/// parsing; everything before this point is CLI syntax, everything after this
/// point is product semantics.
pub struct CliOptions {
  input : String
  output : String?
  provenance_output : String?
  explicit_format : @input.DetectedFormat?
  convert_mode : @convert.ConvertMode
  output_mode : @convert.OutputMode
  rag_options : @rag.RagOptions
}

///|
pub(all) enum BatchTaskStatus {
  Success
  Failed
  Skipped
} derive(Eq)

///|
pub extend BatchTaskStatus with Eq::{equal, not_equal}

///|
enum CliFailureKind {
  UsageFailure
  DetectionFailure
  ConversionFailure
  ResourceFailure
  OutputFailure
} derive(Eq)

///|
pub extend CliFailureKind with Eq::{equal, not_equal}

///|
priv struct CliFailure {
  kind : CliFailureKind
  message : String
}

///|
fn cli_failure(kind : CliFailureKind, message : String) -> CliFailure {
  { kind, message, }
}

///|
fn cli_failure_exit_code(failure : CliFailure) -> Int32 {
  match failure.kind {
    UsageFailure => 2
    DetectionFailure => 3
    ConversionFailure => 4
    ResourceFailure => 5
    OutputFailure => 6
  }
}

///|
fn cli_public_result(
  result : Result[String, CliFailure],
) -> Result[String, String] {
  match result {
    Ok(value) => Ok(value)
    Err(failure) => Err(failure.message)
  }
}

///|
/// Per-file batch execution outcome used in manifest and summary generation.
priv struct BatchTaskResult {
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
  warning_count : Int32
  degraded_features : Array[String]
  error : String?
  failure_kind : CliFailureKind?
}

///|
fn batch_task_status_name(status : BatchTaskStatus) -> String {
  match status {
    Success => "success"
    Failed => "failed"
    Skipped => "skipped"
  }
}

///|
fn batch_task_result_to_json(entry : BatchTaskResult) -> Json {
  Json::object({
    "input_path": Json(entry.input_path),
    "relative_path": Json(entry.relative_path),
    "status": Json(batch_task_status_name(entry.status)),
    "detected_format": Json(entry.detected_format),
    "convert_mode": Json(entry.convert_mode),
    "fidelity_mode": Json(entry.fidelity_mode),
    "output_mode": Json(entry.output_mode),
    "output_path": Json(entry.output_path),
    "selected_route": Json(entry.selected_route),
    "parser_mode": Json(entry.parser_mode),
    "route_reason": Json(entry.route_reason),
    "warning_count": Json(entry.warning_count),
    "degraded_features": Json(entry.degraded_features),
    "error": Json(entry.error),
  })
}

///|
fn cli_is_supported_format(format : @input.DetectedFormat) -> Bool {
  @fmeta.cli_supported_for_capability_format(format)
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
  fidelity_mode : @convert.FidelityMode,
  convert_mode : @convert.ConvertMode,
  output_mode : @convert.OutputMode,
  stream_requested : Bool,
  output_format : @convert.OutputFormat,
  rag_options~ : @rag.RagOptions = @rag.default_rag_options(),
) -> CliOptions {
  ignore(output_format)
  ignore(fidelity_mode)
  ignore(stream_requested)
  {
    input,
    output,
    provenance_output,
    explicit_format,
    convert_mode,
    output_mode,
    rag_options,
  }
}
