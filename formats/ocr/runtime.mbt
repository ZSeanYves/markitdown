///|
const OCR_RUNTIME_TMP_ROOT : String = ".tmp/tests/ocr_runtime"

///|
const OCR_MAX_IN_MEMORY_IMAGE_BYTES : Int = 32 * 1024 * 1024

///|
priv struct OcrPreparedProviderInput {
  path : String
  cleanup_dir : String?
}

///|
fn ocr_prepare_provider_input(
  source : @input.InputSource,
  format : @input.DetectedFormat,
) -> Result[OcrPreparedProviderInput, String] {
  match source.path {
    Some(path) => Ok({ path, cleanup_dir: None })
    None =>
      match source.bytes {
        Some(bytes) => {
          if bytes.length() > OCR_MAX_IN_MEMORY_IMAGE_BYTES {
            return Err(
              "in-memory OCR image exceeds 32 MiB limit: " +
              bytes.length().to_string(),
            )
          }
          if !ocr_image_bytes_match_format(bytes, format) {
            return Err(
              "in-memory OCR image signature does not match " +
              @input.detected_format_name(format),
            )
          }
          let dir = ocr_runtime_tmp_root() + "/input_" + @env.now().to_string()
          ocr_runtime_ensure_dir_tree(dir) catch {
            err =>
              return Err(
                "failed to create in-memory OCR input directory: " +
                err.to_string(),
              )
          }
          let path = dir + "/image." + @input.detected_format_name(format)
          @fs.write_bytes_to_file(path, bytes) catch {
            err => {
              ocr_runtime_cleanup_temp_dir(dir)
              return Err(
                "failed to materialize in-memory OCR image: " + err.to_string(),
              )
            }
          }
          Ok({ path, cleanup_dir: Some(dir) })
        }
        None => Err("OCR input has neither path nor bytes")
      }
  }
}

///|
fn ocr_cleanup_provider_input(input : OcrPreparedProviderInput) -> Unit {
  match input.cleanup_dir {
    Some(path) => ocr_runtime_cleanup_temp_dir(path)
    None => ()
  }
}

///|
fn ocr_image_bytes_match_format(
  bytes : Bytes,
  format : @input.DetectedFormat,
) -> Bool {
  match format {
    @input.DetectedFormat::Image(@input.ImageFormat::Png) =>
      bytes.length() >= 8 &&
      bytes[0].to_int() == 0x89 &&
      bytes[1].to_int() == 0x50 &&
      bytes[2].to_int() == 0x4E &&
      bytes[3].to_int() == 0x47
    @input.DetectedFormat::Image(@input.ImageFormat::Jpg)
    | @input.DetectedFormat::Image(@input.ImageFormat::Jpeg) =>
      bytes.length() >= 3 &&
      bytes[0].to_int() == 0xFF &&
      bytes[1].to_int() == 0xD8 &&
      bytes[2].to_int() == 0xFF
    @input.DetectedFormat::Image(@input.ImageFormat::Bmp) =>
      bytes.length() >= 2 &&
      bytes[0].to_int() == 0x42 &&
      bytes[1].to_int() == 0x4D
    @input.DetectedFormat::Image(@input.ImageFormat::Webp) =>
      bytes.length() >= 12 &&
      bytes[0].to_int() == 0x52 &&
      bytes[1].to_int() == 0x49 &&
      bytes[2].to_int() == 0x46 &&
      bytes[3].to_int() == 0x46 &&
      bytes[8].to_int() == 0x57 &&
      bytes[9].to_int() == 0x45 &&
      bytes[10].to_int() == 0x42 &&
      bytes[11].to_int() == 0x50
    @input.DetectedFormat::Image(@input.ImageFormat::Tif)
    | @input.DetectedFormat::Image(@input.ImageFormat::Tiff) =>
      bytes.length() >= 4 &&
      (
        (
          bytes[0].to_int() == 0x49 &&
          bytes[1].to_int() == 0x49 &&
          bytes[2].to_int() == 0x2A &&
          bytes[3].to_int() == 0
        ) ||
        (
          bytes[0].to_int() == 0x4D &&
          bytes[1].to_int() == 0x4D &&
          bytes[2].to_int() == 0 &&
          bytes[3].to_int() == 0x2A
        )
      )
    _ => false
  }
}

///|
pub fn run_ocr_provider(
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  match request.provider_kind {
    OcrProviderKind::Tesseract => run_tesseract_provider(request)
    OcrProviderKind::PaddleOcr => run_paddle_ocr_provider(request)
  }
}

///|
pub fn paddle_ocr_runtime_available() -> Bool {
  resolve_repo_managed_paddle_wrapper() is Some(_) ||
  @rtcmd.normalized_env_var(paddle_ocr_command_env_var()) is Some(_) ||
  @rtcmd.normalized_env_var(runtime_python_env_var()) is Some(_)
}

///|
pub async fn run_ocr_provider_async(
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  match request.provider_kind {
    OcrProviderKind::Tesseract => run_tesseract_provider_async(request)
    OcrProviderKind::PaddleOcr => run_paddle_ocr_provider_async(request)
  }
}

///|
pub fn resolved_ocr_provider_kind_for_target(
  target : OcrProviderSelectionTarget,
) -> OcrProviderKind {
  default_ocr_provider_kind_for_target(target)
}

///|
pub fn ocr_provider_fallback_for_target(
  target : OcrProviderSelectionTarget,
) -> (OcrProviderKind, OcrProviderKind)? {
  match target {
    OcrProviderSelectionTarget::DirectImageAccurate =>
      Some((OcrProviderKind::PaddleOcr, OcrProviderKind::Tesseract))
    _ => None
  }
}

///|
pub fn ocr_provider_target_requires_fallback(
  target : OcrProviderSelectionTarget,
) -> Bool {
  ocr_provider_fallback_for_target(target) is Some(_)
}

///|
pub fn paddle_ocr_command_env_var() -> String {
  "MARKITDOWN_PADDLE_OCR_CMD"
}

///|
fn runtime_python_env_var() -> String {
  "MARKITDOWN_RUNTIME_PYTHON"
}

///|
fn paddle_ocr_default_wrapper_path() -> String {
  @rtcmd.resolve_repo_relative_path("tools/env/wrappers/paddle_ocr_wrapper.py")
}

///|
fn repo_local_runtime_python_path() -> String {
  @rtcmd.resolve_repo_relative_path("env/.venv-markitdown-accurate/bin/python")
}

///|
fn official_paddle_wrapper_missing_message() -> String {
  "PaddleOCR requires the checked-in wrapper at `" +
  paddle_ocr_default_wrapper_path() +
  "` when using the repo-managed runtime or `" +
  runtime_python_env_var() +
  "`.\n\n" +
  paddle_ocr_install_hint()
}

///|
fn paddle_ocr_split_command_config_error(
  env_var : String,
  error : @rtcmd.ShellCommandSplitError,
) -> OcrProviderError {
  let detail = match error {
    @rtcmd.ShellCommandSplitError::TrailingEscape =>
      "ends with a trailing escape."
    @rtcmd.ShellCommandSplitError::UnterminatedQuotes =>
      "contains unterminated quotes."
  }
  OcrProviderError::NotConfigured(
    "PaddleOCR provider command configured through `" +
    env_var +
    "` is not shell-parseable on this runtime. It " +
    detail +
    "\n\n" +
    paddle_ocr_install_hint(),
  )
}

///|
priv struct PaddleWrapperCommandResolution {
  command : @rtcmd.ResolvedCommand
  argv_prefix : Array[String]
}

///|
fn paddle_wrapper_resolution_from_parts(
  parts : Array[String],
  source : @rtcmd.ResolvedCommandSource,
) -> PaddleWrapperCommandResolution {
  let resolved = match @rtcmd.resolved_command_from_parts(parts, source) {
    Some(value) => value
    None =>
      abort("paddle wrapper resolution requires at least one command part")
  }
  let argv_prefix : Array[String] = []
  argv_prefix.append(parts[1:][:])
  { command: resolved, argv_prefix }
}

///|
fn ocr_runtime_tmp_root() -> String {
  match @rtcmd.normalized_env_var("MARKITDOWN_TMP_DIR") {
    Some(path) => path + "/ocr_runtime"
    None => OCR_RUNTIME_TMP_ROOT
  }
}

///|
fn ocr_runtime_ensure_dir_tree(path : String) -> Unit raise @fs.IOError {
  let normalized = path.trim().to_owned()
  if normalized == "" || normalized == "." {
    return
  }
  if @fs.path_exists(normalized) {
    return
  }
  let parts = normalized.split("/")
  let mut current = if normalized.has_prefix("/") { "/" } else { "" }
  for raw in parts {
    let part = raw.trim().to_owned()
    if part == "" || part == "." {
      continue
    }
    if current == "" || current == "/" {
      current = if current == "/" { "/" + part } else { part }
    } else {
      current = current + "/" + part
    }
    if !@fs.path_exists(current) {
      @fs.create_dir(current)
    }
  }
}

///|
fn ocr_runtime_remove_dir_recursive(path : String) -> Unit raise @fs.IOError {
  if !@fs.path_exists(path) {
    return
  }
  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      ocr_runtime_remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }
  @fs.remove_dir(path)
}

///|
fn ocr_runtime_cleanup_temp_dir(path : String) -> Unit {
  ignore(
    try ocr_runtime_remove_dir_recursive(path) |> Ok catch {
      _ => Err(())
    },
  )
}

///|
fn ocr_runtime_request_temp_dir(request : OcrProviderRequest) -> String {
  let first_path = if request.image_paths.length() > 0 {
    request.image_paths[0]
  } else {
    "empty"
  }
  let sanitized = first_path
    .split("/")
    .last()
    .unwrap_or("ocr")
    .to_owned()
    .replace(old=".", new="_")
  ocr_runtime_tmp_root() + "/paddle_" + sanitized + "_" + @env.now().to_string()
}

///|
fn paddle_ocr_batch_request_json(request : OcrProviderRequest) -> String {
  let jobs : Array[String] = []
  for i in 0..<request.image_paths.length() {
    let image_path = request.image_paths[i]
    let language = match request.language {
      Some(value) => value
      None => ""
    }
    jobs.push(
      "{" +
      "\"job_id\":" +
      paddle_json_quote_string("job-" + i.to_string()) +
      "," +
      "\"image_path\":" +
      paddle_json_quote_string(image_path) +
      "," +
      "\"language\":" +
      paddle_json_quote_string(language) +
      "}",
    )
  }
  "{" +
  "\"provider\":\"paddle_ocr\"," +
  "\"version\":\"v2\"," +
  "\"jobs\":[" +
  jobs.join(",") +
  "]}"
}

///|
priv struct PaddleOcrCommandPlan {
  command : @rtcmd.ResolvedCommand
  argv : Array[String]
  temp_dir : String
  result_json_path : String
}

///|
fn paddle_json_quote_string(text : String) -> String {
  let out : Array[Char] = ['"']
  for ch in text.to_array() {
    match ch {
      '"' => {
        out.push('\\')
        out.push('"')
      }
      '\\' => {
        out.push('\\')
        out.push('\\')
      }
      '\n' => {
        out.push('\\')
        out.push('n')
      }
      '\r' => {
        out.push('\\')
        out.push('r')
      }
      '\t' => {
        out.push('\\')
        out.push('t')
      }
      _ => out.push(ch)
    }
  }
  out.push('"')
  String::from_array(out)
}

///|
pub fn paddle_ocr_not_configured_message() -> String {
  "PaddleOCR provider is not configured on this runtime.\n\n" +
  paddle_ocr_install_hint()
}

///|
pub fn build_paddle_ocr_command(
  request : OcrProviderRequest,
) -> Result[(String, Array[String]), OcrProviderError] {
  match build_paddle_ocr_command_plan(request) {
    Ok(plan) => Ok((plan.command.program, plan.argv))
    Err(error) => Err(error)
  }
}

///|
fn build_paddle_ocr_command_plan(
  request : OcrProviderRequest,
) -> Result[PaddleOcrCommandPlan, OcrProviderError] {
  match resolve_repo_managed_paddle_wrapper() {
    Some(wrapper) =>
      return build_paddle_ocr_command_plan_with_wrapper_resolution(
        request, wrapper,
      )
    None => ()
  }
  match resolve_paddle_wrapper_command_from_env() {
    Ok(Some(wrapper)) =>
      return build_paddle_ocr_command_plan_with_wrapper_resolution(
        request, wrapper,
      )
    Ok(None) => ()
    Err(error) => return Err(error)
  }
  match resolve_paddle_wrapper_from_runtime_python_env() {
    Ok(Some(wrapper)) =>
      return build_paddle_ocr_command_plan_with_wrapper_resolution(
        request, wrapper,
      )
    Ok(None) =>
      Err(OcrProviderError::NotConfigured(paddle_ocr_not_configured_message()))
    Err(error) => Err(error)
  }
}

///|
pub fn build_paddle_ocr_command_with_wrapper(
  request : OcrProviderRequest,
  wrapper_command : String,
) -> Result[(String, Array[String]), OcrProviderError] {
  match build_paddle_ocr_command_plan_with_wrapper(request, wrapper_command) {
    Ok(plan) => Ok((plan.command.program, plan.argv))
    Err(error) => Err(error)
  }
}

///|
fn build_paddle_ocr_command_plan_with_wrapper(
  request : OcrProviderRequest,
  wrapper_command : String,
) -> Result[PaddleOcrCommandPlan, OcrProviderError] {
  let trimmed = wrapper_command.trim().to_owned()
  if trimmed == "" {
    return Err(
      OcrProviderError::NotConfigured(paddle_ocr_not_configured_message()),
    )
  }
  let parts = match @rtcmd.split_shell_command(trimmed) {
    Ok(value) => value
    Err(error) =>
      return Err(
        paddle_ocr_split_command_config_error(
          paddle_ocr_command_env_var(),
          error,
        ),
      )
  }
  if parts.length() == 0 {
    return Err(
      OcrProviderError::NotConfigured(paddle_ocr_not_configured_message()),
    )
  }
  build_paddle_ocr_command_plan_with_wrapper_resolution(
    request,
    paddle_wrapper_resolution_from_parts(
      parts,
      @rtcmd.ResolvedCommandSource::EnvVar,
    ),
  )
}

///|
fn resolve_repo_managed_paddle_wrapper() -> PaddleWrapperCommandResolution? {
  let python_path = repo_local_runtime_python_path()
  if !@fs.path_exists(paddle_ocr_default_wrapper_path()) ||
    !@rtcmd.is_executable_file(python_path) {
    return None
  }
  Some(
    paddle_wrapper_resolution_from_parts(
      [python_path, paddle_ocr_default_wrapper_path()],
      @rtcmd.ResolvedCommandSource::RepoManaged,
    ),
  )
}

///|
fn resolve_paddle_wrapper_command_from_env() -> Result[
  PaddleWrapperCommandResolution?,
  OcrProviderError,
] {
  match @rtcmd.normalized_env_var(paddle_ocr_command_env_var()) {
    Some(command) => {
      let parts = match @rtcmd.split_shell_command(command) {
        Ok(value) => value
        Err(error) =>
          return Err(
            paddle_ocr_split_command_config_error(
              paddle_ocr_command_env_var(),
              error,
            ),
          )
      }
      if parts.length() == 0 {
        return Err(
          OcrProviderError::NotConfigured(paddle_ocr_not_configured_message()),
        )
      }
      Ok(
        Some(
          paddle_wrapper_resolution_from_parts(
            parts,
            @rtcmd.ResolvedCommandSource::EnvVar,
          ),
        ),
      )
    }
    None => Ok(None)
  }
}

///|
fn resolve_paddle_wrapper_from_runtime_python_env() -> Result[
  PaddleWrapperCommandResolution?,
  OcrProviderError,
] {
  match @rtcmd.normalized_env_var(runtime_python_env_var()) {
    Some(path) =>
      match
        resolve_checked_in_paddle_wrapper(
          path,
          runtime_python_env_var(),
          @rtcmd.ResolvedCommandSource::EnvVar,
        ) {
        Ok(wrapper) => Ok(Some(wrapper))
        Err(error) => Err(error)
      }
    None => Ok(None)
  }
}

///|
fn resolve_checked_in_paddle_wrapper(
  python_path : String,
  label : String,
  source : @rtcmd.ResolvedCommandSource,
) -> Result[PaddleWrapperCommandResolution, OcrProviderError] {
  if !@fs.path_exists(paddle_ocr_default_wrapper_path()) {
    return Err(
      OcrProviderError::NotConfigured(official_paddle_wrapper_missing_message()),
    )
  }
  let python = match
    @rtcmd.resolve_executable_path(python_path, label, source) {
    Ok(value) => value
    Err(msg) =>
      return Err(
        OcrProviderError::NotConfigured(
          msg + "\n\n" + paddle_ocr_install_hint(),
        ),
      )
  }
  Ok(
    paddle_wrapper_resolution_from_parts(
      [python.program, paddle_ocr_default_wrapper_path()],
      source,
    ),
  )
}

///|
fn build_paddle_ocr_command_plan_with_wrapper_resolution(
  request : OcrProviderRequest,
  wrapper : PaddleWrapperCommandResolution,
) -> Result[PaddleOcrCommandPlan, OcrProviderError] {
  let temp_dir = ocr_runtime_request_temp_dir(request)
  ocr_runtime_ensure_dir_tree(temp_dir) catch {
    e =>
      return Err(
        OcrProviderError::ExecutionFailed(
          "failed to create PaddleOCR runtime temp dir: " + e.to_string(),
        ),
      )
  }
  let request_json_path = temp_dir + "/request.json"
  let result_json_path = temp_dir + "/result.json"
  @fs.write_string_to_file(
    request_json_path,
    paddle_ocr_batch_request_json(request),
    encoding="utf8",
  ) catch {
    e =>
      return Err(
        OcrProviderError::ExecutionFailed(
          "failed to write PaddleOCR batch request JSON: " + e.to_string(),
        ),
      )
  }
  let argv : Array[String] = []
  argv.append(wrapper.argv_prefix[:])
  argv.push("--batch-json")
  argv.push(request_json_path)
  argv.push("--result-json")
  argv.push(result_json_path)
  Ok({ command: wrapper.command, argv, temp_dir, result_json_path })
}

///|
pub fn run_paddle_ocr_provider(
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = match build_paddle_ocr_command_plan(request) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  defer ocr_runtime_cleanup_temp_dir(plan.temp_dir)
  let delegated = match collect_paddle_ocr_output(plan.command, plan.argv) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_paddle_ocr_command_result(
    delegated,
    plan.command,
    plan.result_json_path,
    request,
  )
}

///|
pub async fn run_paddle_ocr_provider_async(
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = match build_paddle_ocr_command_plan(request) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  defer ocr_runtime_cleanup_temp_dir(plan.temp_dir)
  let delegated = match
    collect_paddle_ocr_output_async(plan.command, plan.argv) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_paddle_ocr_command_result(
    delegated,
    plan.command,
    plan.result_json_path,
    request,
  )
}

///|
pub fn run_paddle_ocr_provider_with_command(
  request : OcrProviderRequest,
  collect_output : (String, Array[String]) -> Result[
    (Int, String, String),
    OcrProviderError,
  ],
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = match build_paddle_ocr_command_plan(request) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  defer ocr_runtime_cleanup_temp_dir(plan.temp_dir)
  let delegated = match collect_output(plan.command.program, plan.argv) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_paddle_ocr_command_result(
    delegated,
    plan.command,
    plan.result_json_path,
    request,
  )
}

///|
pub async fn run_paddle_ocr_provider_with_async_command(
  request : OcrProviderRequest,
  collect_output : async (String, Array[String]) -> Result[
    (Int, String, String),
    OcrProviderError,
  ],
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = match build_paddle_ocr_command_plan(request) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  defer ocr_runtime_cleanup_temp_dir(plan.temp_dir)
  let delegated = match collect_output(plan.command.program, plan.argv) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_paddle_ocr_command_result(
    delegated,
    plan.command,
    plan.result_json_path,
    request,
  )
}

///|
pub async fn run_paddle_ocr_provider_with_async_command_with_wrapper(
  request : OcrProviderRequest,
  wrapper_command : String,
  collect_output : async (String, Array[String]) -> Result[
    (Int, String, String),
    OcrProviderError,
  ],
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = match
    build_paddle_ocr_command_plan_with_wrapper(request, wrapper_command) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  defer ocr_runtime_cleanup_temp_dir(plan.temp_dir)
  let delegated = match collect_output(plan.command.program, plan.argv) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_paddle_ocr_command_result(
    delegated,
    plan.command,
    plan.result_json_path,
    request,
  )
}

///|
pub fn run_paddle_ocr_provider_with_command_with_wrapper(
  request : OcrProviderRequest,
  wrapper_command : String,
  collect_output : (String, Array[String]) -> Result[
    (Int, String, String),
    OcrProviderError,
  ],
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = match
    build_paddle_ocr_command_plan_with_wrapper(request, wrapper_command) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  defer ocr_runtime_cleanup_temp_dir(plan.temp_dir)
  let delegated = match collect_output(plan.command.program, plan.argv) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_paddle_ocr_command_result(
    delegated,
    plan.command,
    plan.result_json_path,
    request,
  )
}

///|
fn finalize_paddle_ocr_command_result(
  delegated : (Int, String, String),
  command : @rtcmd.ResolvedCommand,
  result_json_path : String,
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  match delegated {
    (0, stdout, stderr) => {
      let payload = @fs.read_file_to_string(result_json_path, encoding="utf8") catch {
        e =>
          return Err(
            OcrProviderError::OutputParseFailed(
              "PaddleOCR wrapper did not produce a readable result JSON on this runtime: " +
              e.to_string(),
            ),
          )
      }
      let parsed = match parse_paddle_ocr_wrapper_payload(payload, request) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let diagnostics = parsed.diagnostics.copy()
      let stdout_text = stdout.trim().to_owned()
      let stderr_text = stderr.trim().to_owned()
      if stdout_text != "" {
        diagnostics.push("paddle_ocr_stdout=" + stdout_text)
      }
      if stderr_text != "" {
        diagnostics.push("paddle_ocr_stderr=" + stderr_text)
      }
      diagnostics.push(
        "paddle_ocr_command_source=" +
        @rtcmd.resolved_command_source_label(command.source),
      )
      diagnostics.push("paddle_ocr_command=" + command.display_command)
      Ok({ ..parsed, diagnostics, })
    }
    (code, stdout, stderr) => {
      let stderr_text = stderr.trim().to_owned()
      let stdout_text = stdout.trim().to_owned()
      let raw_message = if stderr_text != "" {
        stderr_text
      } else if stdout_text != "" {
        stdout_text
      } else {
        "paddle wrapper exited with code " + code.to_string()
      }
      let lowered = raw_message.to_lower()
      if lowered.contains("command not found") ||
        lowered.contains("not found") ||
        lowered.contains("no such file") {
        Err(
          OcrProviderError::CommandUnavailable(
            "PaddleOCR wrapper command is unavailable on this runtime: " +
            raw_message +
            "\nResolved command: " +
            @rtcmd.resolved_command_context(command) +
            "\n\n" +
            paddle_ocr_install_hint(),
          ),
        )
      } else {
        Err(
          OcrProviderError::ExecutionFailed(
            "PaddleOCR wrapper command failed on this runtime: " +
            raw_message +
            "\nResolved command: " +
            @rtcmd.resolved_command_context(command) +
            "\n\n" +
            paddle_ocr_install_hint(),
          ),
        )
      }
    }
  }
}

///|
pub fn parse_paddle_ocr_wrapper_payload(
  payload : String,
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  let trimmed = payload.trim().to_owned()
  if trimmed == "" {
    return Err(
      OcrProviderError::EmptyResult(
        "PaddleOCR wrapper produced an empty payload on this runtime.",
      ),
    )
  }
  let root = @djson.parse_json_document(trimmed) catch {
    err =>
      return Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR wrapper emitted invalid JSON on this runtime: " +
          err.to_string(),
        ),
      )
  }
  let root_object = match root.root {
    @djson.JsonValue::Object(entries) => paddle_json_object(entries)
    _ =>
      return Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR wrapper payload root must be a JSON object on this runtime.",
        ),
      )
  }
  let provider_name = match
    paddle_json_string_required(root_object, "provider_name") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let jobs = match root_object.get("jobs") {
    Some(@djson.JsonValue::Array(items)) =>
      match paddle_json_job_results(items, request) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    _ =>
      return Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR wrapper payload must include a `jobs` array on this runtime.",
        ),
      )
  }
  let pages : Array[OcrPageModel] = []
  let mut has_ok_job = false
  let mut has_empty_job = false
  let mut has_error_job = false
  for job in jobs {
    match job.status {
      "ok" => {
        has_ok_job = true
        pages.append(job.pages[:])
      }
      "empty" => has_empty_job = true
      _ => has_error_job = true
    }
  }
  let diagnostics = match root_object.get("diagnostics") {
    Some(@djson.JsonValue::Array(items)) => paddle_json_string_array(items)
    _ => []
  }
  if pages.length() == 0 {
    if has_empty_job && !has_ok_job && !has_error_job {
      return Err(
        OcrProviderError::EmptyResult(
          "PaddleOCR wrapper produced zero pages on this runtime.",
        ),
      )
    }
    if request.image_paths.length() == 1 && has_error_job && !has_ok_job {
      let mut first_error_message = "unknown error"
      for job in jobs {
        if job.status == "error" {
          match job.error_message {
            Some(message) => first_error_message = message
            None => ()
          }
          break
        }
      }
      return Err(
        OcrProviderError::ExecutionFailed(
          "PaddleOCR wrapper job failed on this runtime: " + first_error_message,
        ),
      )
    }
  }
  Ok(
    make_ocr_provider_result(
      pages,
      provider_name,
      provider_version=paddle_json_string_optional(
        root_object, "provider_version",
      ),
      diagnostics~,
      jobs~,
    ),
  )
}

///|
fn paddle_json_job_results(
  items : Array[@djson.JsonValue],
  request : OcrProviderRequest,
) -> Result[Array[OcrProviderJobResult], OcrProviderError] {
  let jobs : Array[OcrProviderJobResult] = []
  for item in items {
    let job_object = match item {
      @djson.JsonValue::Object(entries) => paddle_json_object(entries)
      _ =>
        return Err(
          OcrProviderError::OutputParseFailed(
            "PaddleOCR wrapper job entries must be JSON objects on this runtime.",
          ),
        )
    }
    jobs.push(
      match paddle_json_job_result(job_object, request) {
        Ok(value) => value
        Err(error) => return Err(error)
      },
    )
  }
  Ok(jobs)
}

///|
fn paddle_json_job_result(
  payload : Map[String, @djson.JsonValue],
  request : OcrProviderRequest,
) -> Result[OcrProviderJobResult, OcrProviderError] {
  let job_id = match paddle_json_string_required(payload, "job_id") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let status = match paddle_json_string_required(payload, "status") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let page_items = match payload.get("pages") {
    Some(@djson.JsonValue::Array(items)) => items
    _ =>
      return Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR wrapper job payload must include a `pages` array on this runtime.",
        ),
      )
  }
  let pages = match paddle_json_pages(page_items) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let image_path = match paddle_job_image_path(request, job_id) {
    Some(path) => path
    None => ""
  }
  Ok(
    make_ocr_provider_job_result(
      image_path,
      status~,
      error_kind=paddle_json_string_optional(payload, "error_kind"),
      error_message=paddle_json_string_optional(payload, "error_message"),
      pages,
      diagnostics=match payload.get("diagnostics") {
        Some(@djson.JsonValue::Array(items)) => paddle_json_string_array(items)
        _ => []
      },
    ),
  )
}

///|
fn paddle_job_image_path(
  request : OcrProviderRequest,
  job_id : String,
) -> String? {
  let prefix = "job-"
  if !job_id.has_prefix(prefix) {
    return None
  }
  let suffix = job_id[prefix.length():]
  let index = @string.parse_int(suffix) catch { _ => return None }
  if index < 0 || index >= request.image_paths.length() {
    None
  } else {
    Some(request.image_paths[index])
  }
}

///|
fn paddle_json_pages(
  items : Array[@djson.JsonValue],
) -> Result[Array[OcrPageModel], OcrProviderError] {
  let pages : Array[OcrPageModel] = []
  for item in items {
    let page_object = match item {
      @djson.JsonValue::Object(entries) => paddle_json_object(entries)
      _ =>
        return Err(
          OcrProviderError::OutputParseFailed(
            "PaddleOCR wrapper page entries must be JSON objects on this runtime.",
          ),
        )
    }
    pages.push(
      match paddle_json_page(page_object) {
        Ok(value) => value
        Err(error) => return Err(error)
      },
    )
  }
  Ok(pages)
}

///|
fn paddle_json_page(
  payload : Map[String, @djson.JsonValue],
) -> Result[OcrPageModel, OcrProviderError] {
  let page_index = match paddle_json_int_required(payload, "page_index") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let blocks = match payload.get("blocks") {
    Some(@djson.JsonValue::Array(items)) =>
      match paddle_json_blocks(items) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    _ =>
      return Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR wrapper page payload must include a `blocks` array on this runtime.",
        ),
      )
  }
  Ok({
    page_index,
    width: paddle_json_double_optional(payload, "width"),
    height: paddle_json_double_optional(payload, "height"),
    blocks,
    provider: Some(
      make_ocr_provider_info(
        "paddle_ocr",
        version=paddle_json_string_optional(payload, "provider_version"),
        language=paddle_json_string_optional(payload, "language"),
      ),
    ),
    diagnostics: match payload.get("diagnostics") {
      Some(@djson.JsonValue::Array(items)) => paddle_json_string_array(items)
      _ => []
    },
  })
}

///|
fn paddle_json_blocks(
  items : Array[@djson.JsonValue],
) -> Result[Array[OcrBlock], OcrProviderError] {
  let blocks : Array[OcrBlock] = []
  for item in items {
    let block_object = match item {
      @djson.JsonValue::Object(entries) => paddle_json_object(entries)
      _ =>
        return Err(
          OcrProviderError::OutputParseFailed(
            "PaddleOCR wrapper block entries must be JSON objects on this runtime.",
          ),
        )
    }
    blocks.push(
      match paddle_json_block(block_object) {
        Ok(value) => value
        Err(error) => return Err(error)
      },
    )
  }
  Ok(blocks)
}

///|
fn paddle_json_block(
  payload : Map[String, @djson.JsonValue],
) -> Result[OcrBlock, OcrProviderError] {
  let block_index = match paddle_json_int_required(payload, "block_index") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let lines = match payload.get("lines") {
    Some(@djson.JsonValue::Array(items)) =>
      match paddle_json_lines(items) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    _ =>
      return Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR wrapper block payload must include a `lines` array on this runtime.",
        ),
      )
  }
  Ok(
    make_ocr_block(
      block_index,
      lines~,
      bbox=paddle_json_bbox_optional(payload, "bbox"),
      confidence=paddle_json_double_optional(payload, "confidence"),
    ),
  )
}

///|
fn paddle_json_lines(
  items : Array[@djson.JsonValue],
) -> Result[Array[OcrLine], OcrProviderError] {
  let lines : Array[OcrLine] = []
  for item in items {
    let line_object = match item {
      @djson.JsonValue::Object(entries) => paddle_json_object(entries)
      _ =>
        return Err(
          OcrProviderError::OutputParseFailed(
            "PaddleOCR wrapper line entries must be JSON objects on this runtime.",
          ),
        )
    }
    lines.push(
      match paddle_json_line(line_object) {
        Ok(value) => value
        Err(error) => return Err(error)
      },
    )
  }
  Ok(lines)
}

///|
fn paddle_json_line(
  payload : Map[String, @djson.JsonValue],
) -> Result[OcrLine, OcrProviderError] {
  let line_index = match paddle_json_int_required(payload, "line_index") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let text = match paddle_json_string_required(payload, "text") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let words = match payload.get("words") {
    Some(@djson.JsonValue::Array(items)) =>
      match paddle_json_words(items) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    _ =>
      return Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR wrapper line payload must include a `words` array on this runtime.",
        ),
      )
  }
  Ok(
    make_ocr_line(
      line_index,
      text,
      words~,
      bbox=paddle_json_bbox_optional(payload, "bbox"),
      confidence=paddle_json_double_optional(payload, "confidence"),
    ),
  )
}

///|
fn paddle_json_words(
  items : Array[@djson.JsonValue],
) -> Result[Array[OcrWord], OcrProviderError] {
  let words : Array[OcrWord] = []
  for item in items {
    let word_object = match item {
      @djson.JsonValue::Object(entries) => paddle_json_object(entries)
      _ =>
        return Err(
          OcrProviderError::OutputParseFailed(
            "PaddleOCR wrapper word entries must be JSON objects on this runtime.",
          ),
        )
    }
    words.push(
      match paddle_json_word(word_object) {
        Ok(value) => value
        Err(error) => return Err(error)
      },
    )
  }
  Ok(words)
}

///|
fn paddle_json_word(
  payload : Map[String, @djson.JsonValue],
) -> Result[OcrWord, OcrProviderError] {
  let word_index = match paddle_json_int_required(payload, "word_index") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let text = match paddle_json_string_required(payload, "text") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(
    make_ocr_word(
      word_index,
      text,
      bbox=paddle_json_bbox_optional(payload, "bbox"),
      confidence=paddle_json_double_optional(payload, "confidence"),
    ),
  )
}

///|
fn paddle_json_object(
  entries : Array[@djson.JsonMember],
) -> Map[String, @djson.JsonValue] {
  let mapped = Map([])
  for entry in entries {
    mapped[entry.key] = entry.value
  }
  mapped
}

///|
fn paddle_json_string_required(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> Result[String, OcrProviderError] {
  match payload.get(key) {
    Some(@djson.JsonValue::String(value)) => Ok(value)
    _ =>
      Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR wrapper payload is missing required string field `" +
          key +
          "` on this runtime.",
        ),
      )
  }
}

///|
fn paddle_json_string_optional(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> String? {
  match payload.get(key) {
    Some(@djson.JsonValue::String(value)) => Some(value)
    _ => None
  }
}

///|
fn paddle_json_string_array(items : Array[@djson.JsonValue]) -> Array[String] {
  items
  .map(item => {
    match item {
      @djson.JsonValue::String(value) => value
      _ => ""
    }
  })
  .filter(item => item != "")
}

///|
fn paddle_json_int_required(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> Result[Int, OcrProviderError] {
  match payload.get(key) {
    Some(@djson.JsonValue::Number(value)) =>
      Ok(
        @string.parse_int(value) catch {
          _ =>
            return Err(
              OcrProviderError::OutputParseFailed(
                "PaddleOCR wrapper numeric field `" +
                key +
                "` is not a valid integer on this runtime.",
              ),
            )
        },
      )
    _ =>
      Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR wrapper payload is missing required numeric field `" +
          key +
          "` on this runtime.",
        ),
      )
  }
}

///|
fn paddle_json_double_optional(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> Double? {
  match payload.get(key) {
    Some(@djson.JsonValue::Number(value)) =>
      Some(@string.parse_double(value) catch { _ => return None })
    _ => None
  }
}

///|
fn paddle_json_bbox_optional(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> @core.BBox? {
  match payload.get(key) {
    Some(@djson.JsonValue::Object(entries)) =>
      paddle_json_bbox_from_object(paddle_json_object(entries))
    _ => None
  }
}

///|
fn paddle_json_bbox_from_object(
  payload : Map[String, @djson.JsonValue],
) -> @core.BBox? {
  let x0 = match paddle_json_double_optional(payload, "x0") {
    Some(value) => value
    None => return None
  }
  let y0 = match paddle_json_double_optional(payload, "y0") {
    Some(value) => value
    None => return None
  }
  let x1 = match paddle_json_double_optional(payload, "x1") {
    Some(value) => value
    None => return None
  }
  let y1 = match paddle_json_double_optional(payload, "y1") {
    Some(value) => value
    None => return None
  }
  Some({ x0, y0, x1, y1 })
}

///|
async fn collect_paddle_ocr_output_async(
  command : @rtcmd.ResolvedCommand,
  args : Array[String],
) -> Result[(Int, String, String), OcrProviderError] {
  let delegated = @process.collect_output(command.program, args) catch {
    e =>
      return Err(
        OcrProviderError::ExecutionFailed(
          "launch PaddleOCR wrapper failed on this runtime: " +
          e.to_string() +
          "\nResolved command: " +
          @rtcmd.resolved_command_context(command) +
          "\n\n" +
          paddle_ocr_install_hint(),
        ),
      )
  }
  match delegated {
    (code, stdout, stderr) => {
      let stdout_text = stdout.text() catch {
        e =>
          return Err(
            OcrProviderError::OutputParseFailed(
              "failed to decode PaddleOCR wrapper stdout as UTF-8 on this runtime: " +
              e.to_string(),
            ),
          )
      }
      let stderr_text = stderr.text() catch {
        e =>
          return Err(
            OcrProviderError::OutputParseFailed(
              "failed to decode PaddleOCR wrapper stderr as UTF-8 on this runtime: " +
              e.to_string(),
            ),
          )
      }
      Ok((code, stdout_text, stderr_text))
    }
  }
}

///|
#warnings("-deprecated")
fn collect_paddle_ocr_output(
  command : @rtcmd.ResolvedCommand,
  args : Array[String],
) -> Result[(Int, String, String), OcrProviderError] {
  let collected : Ref[Result[(Int, String, String), OcrProviderError]?] = {
    val: None,
  }
  @async.with_event_loop(_group => {
    let delegated = @process.collect_output(command.program, args) catch {
      e => {
        collected.val = Some(
          Err(
            OcrProviderError::ExecutionFailed(
              "launch PaddleOCR wrapper failed on this runtime: " +
              e.to_string() +
              "\nResolved command: " +
              @rtcmd.resolved_command_context(command) +
              "\n\n" +
              paddle_ocr_install_hint(),
            ),
          ),
        )
        return
      }
    }
    match delegated {
      (code, stdout, stderr) => {
        let stdout_text = stdout.text() catch {
          e => {
            collected.val = Some(
              Err(
                OcrProviderError::OutputParseFailed(
                  "failed to decode PaddleOCR wrapper stdout as UTF-8 on this runtime: " +
                  e.to_string(),
                ),
              ),
            )
            return
          }
        }
        let stderr_text = stderr.text() catch {
          e => {
            collected.val = Some(
              Err(
                OcrProviderError::OutputParseFailed(
                  "failed to decode PaddleOCR wrapper stderr as UTF-8 on this runtime: " +
                  e.to_string(),
                ),
              ),
            )
            return
          }
        }
        collected.val = Some(Ok((code, stdout_text, stderr_text)))
      }
    }
  }) catch {
    e =>
      return Err(
        OcrProviderError::ExecutionFailed(
          "launch PaddleOCR wrapper failed on this runtime: " +
          e.to_string() +
          "\nResolved command: " +
          @rtcmd.resolved_command_context(command) +
          "\n\n" +
          paddle_ocr_install_hint(),
        ),
      )
  }
  match collected.val {
    Some(result) => result
    None =>
      Err(
        OcrProviderError::ExecutionFailed(
          "launch PaddleOCR wrapper failed on this runtime: event loop returned no result" +
          "\nResolved command: " +
          @rtcmd.resolved_command_context(command) +
          "\n\n" +
          paddle_ocr_install_hint(),
        ),
      )
  }
}
