///|
const AUDIO_TMP_ROOT : String = ".tmp/tests/audio_native"

///|
pub fn audio_command_env_var() -> String {
  "MARKITDOWN_AUDIO_CMD"
}

///|
pub fn ffmpeg_command_env_var() -> String {
  "MARKITDOWN_FFMPEG_BIN"
}

///|
pub fn audio_model_path_env_var() -> String {
  "MARKITDOWN_AUDIO_MODEL_PATH"
}

///|
fn runtime_python_env_var() -> String {
  "MARKITDOWN_RUNTIME_PYTHON"
}

///|
pub fn audio_backend_transport_name() -> String {
  "native_cli"
}

///|
pub fn audio_backend_name() -> String {
  "vosk"
}

///|
fn audio_default_model_path() -> String {
  @rtcmd.resolve_repo_relative_path("env/models/vosk/model")
}

///|
fn audio_runtime_tmp_root() -> String {
  match @rtcmd.normalized_env_var("MARKITDOWN_TMP_DIR") {
    Some(path) => path + "/audio_native"
    None => AUDIO_TMP_ROOT
  }
}

///|
fn audio_resolved_model_path() -> String {
  match @rtcmd.normalized_env_var(audio_model_path_env_var()) {
    Some(path) => path
    None => audio_default_model_path()
  }
}

///|
fn audio_default_wrapper_path() -> String {
  @rtcmd.resolve_repo_relative_path(
    "tools/env/wrappers/audio_transcribe_wrapper.py",
  )
}

///|
fn repo_local_runtime_python_path() -> String {
  @rtcmd.resolve_repo_relative_path("env/.venv-markitdown-audio/bin/python")
}

///|
fn official_audio_wrapper_missing_message() -> String {
  "Audio transcription requires the checked-in wrapper at `" +
  audio_default_wrapper_path() +
  "` when using the repo-managed runtime or `" +
  runtime_python_env_var() +
  "`.\n\n" +
  audio_transcribe_install_hint()
}

///|
fn audio_split_command_config_error(
  env_var : String,
  error : @rtcmd.ShellCommandSplitError,
) -> AudioTranscribeError {
  let detail = match error {
    @rtcmd.ShellCommandSplitError::TrailingEscape =>
      "ends with a trailing escape."
    @rtcmd.ShellCommandSplitError::UnterminatedQuotes =>
      "contains unterminated quotes."
  }
  AudioTranscribeError::NotConfigured(
    "Audio command configured through `" +
    env_var +
    "` is not shell-parseable on this runtime. It " +
    detail +
    "\n\n" +
    audio_transcribe_install_hint(),
  )
}

///|
priv struct WrapperCommandResolution {
  command : @rtcmd.ResolvedCommand
  argv_prefix : Array[String]
}

///|
fn audio_wrapper_resolution_from_parts(
  parts : Array[String],
  source : @rtcmd.ResolvedCommandSource,
) -> WrapperCommandResolution {
  let resolved = match @rtcmd.resolved_command_from_parts(parts, source) {
    Some(value) => value
    None => abort("wrapper resolution requires at least one command part")
  }
  let argv_prefix : Array[String] = []
  argv_prefix.append(parts[1:][:])
  { command: resolved, argv_prefix }
}

///|
pub fn audio_transcribe_install_hint() -> String {
  [
    "Preferred: run `./tools/env/optional_deps.sh install audio` and let repo-root runs use the repo-managed virtualenv plus `tools/env/wrappers/audio_transcribe_wrapper.py` by default.",
    "Custom audio wrapper commands still work through `" +
    audio_command_env_var() +
    "`, but that is lower priority than the repo-managed runtime.",
    "If the repo-managed runtime is unavailable, `" +
    runtime_python_env_var() +
    "` can point at a Python executable that should launch the checked-in audio wrapper.",
    "Python dependencies should live in the repo-local virtualenv under `./env/`, not in your global Python environment.",
    "Recommended model directory: " + audio_default_model_path(),
    "Set `" +
    audio_model_path_env_var() +
    "` to point at the extracted model directory when needed.",
    "Plain PCM `wav` is the lightest supported route. `m4a` still requires local `ffmpeg`; repo-managed records under `./env/managed-paths/ffmpeg` win first, then `" +
    ffmpeg_command_env_var() +
    "`, then `PATH`.",
  ].join("\n")
}

///|
pub fn audio_transcribe_not_configured_message() -> String {
  "Audio transcription backend is not available on this runtime.\n\n" +
  audio_transcribe_install_hint()
}

///|
priv struct AudioCommandPlan {
  backend_command : @rtcmd.ResolvedCommand
  argv : Array[String]
  result_json_path : String
  temp_dir : String
  preprocess_invocation_count : Int
  preprocess_wall_ms : UInt64
  preprocess_kinds : Array[String]
  preprocess_command : @rtcmd.ResolvedCommand?
}

///|
priv struct AudioRuntimeMetrics {
  external_process_invocation_count : Int
  external_process_wall_ms : UInt64
  external_process_kind : String
  audio_backend_wall_ms : UInt64
  audio_normalization_used : Bool
}

///|
pub fn build_audio_transcribe_command(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  language : String?,
) -> Result[(String, Array[String]), AudioTranscribeError] {
  match build_audio_transcribe_plan(source, format, language) {
    Ok(plan) => Ok((plan.backend_command.program, plan.argv))
    Err(error) => Err(error)
  }
}

///|
fn build_audio_transcribe_plan(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  language : String?,
) -> Result[AudioCommandPlan, AudioTranscribeError] {
  let local_path = match audio_local_source_path(source) {
    Ok(path) => path
    Err(error) => return Err(error)
  }
  let detected_audio_format = match format {
    @input.DetectedFormat::Audio(audio_format) => audio_format
    _ =>
      return Err(
        AudioTranscribeError::ExecutionFailed(
          "audio transcription only accepts detected audio formats",
        ),
      )
  }
  let temp_dir = audio_temp_dir_name(source)
  audio_ensure_dir_tree(temp_dir) catch {
    e =>
      return Err(
        AudioTranscribeError::ExecutionFailed(
          "failed to create audio temp dir: " + e.to_string(),
        ),
      )
  }
  let prepared_input = match
    audio_prepare_input_for_backend(local_path, detected_audio_format, temp_dir) {
    Ok(value) => value
    Err(error) => {
      audio_cleanup_temp_dir(temp_dir)
      return Err(error)
    }
  }
  let model_path = match audio_validate_model_path() {
    Ok(value) => value
    Err(error) => {
      audio_cleanup_temp_dir(temp_dir)
      return Err(error)
    }
  }
  let output_base = temp_dir + "/transcript"
  let result_json_path = output_base + ".json"
  let (backend_command, argv) = match
    audio_backend_command_plan(
      prepared_input, result_json_path, language, model_path, temp_dir,
    ) {
    Ok(value) => value
    Err(error) => {
      audio_cleanup_temp_dir(temp_dir)
      return Err(error)
    }
  }
  Ok({
    backend_command,
    argv,
    result_json_path,
    temp_dir,
    preprocess_invocation_count: prepared_input.preprocess_invocation_count,
    preprocess_wall_ms: prepared_input.preprocess_wall_ms,
    preprocess_kinds: prepared_input.preprocess_kinds,
    preprocess_command: prepared_input.preprocess_command,
  })
}

///|
fn audio_backend_command_plan(
  prepared_input : PreparedAudioInput,
  result_json_path : String,
  language : String?,
  model_path : String,
  temp_dir : String,
) -> Result[(@rtcmd.ResolvedCommand, Array[String]), AudioTranscribeError] {
  match resolve_repo_managed_audio_wrapper() {
    Some(wrapper) =>
      return build_audio_transcribe_command_with_wrapper_resolution(
        prepared_input, result_json_path, language, model_path, temp_dir, wrapper,
      )
    None => ()
  }
  match resolve_audio_wrapper_command_from_env() {
    Ok(Some(wrapper)) =>
      return build_audio_transcribe_command_with_wrapper_resolution(
        prepared_input, result_json_path, language, model_path, temp_dir, wrapper,
      )
    Ok(None) => ()
    Err(error) => return Err(error)
  }
  match resolve_audio_wrapper_from_runtime_python_env() {
    Ok(Some(wrapper)) =>
      return build_audio_transcribe_command_with_wrapper_resolution(
        prepared_input, result_json_path, language, model_path, temp_dir, wrapper,
      )
    Ok(None) =>
      Err(
        AudioTranscribeError::NotConfigured(
          audio_transcribe_not_configured_message(),
        ),
      )
    Err(error) => Err(error)
  }
}

///|
fn resolve_repo_managed_audio_wrapper() -> WrapperCommandResolution? {
  let python_path = repo_local_runtime_python_path()
  if !@fs.path_exists(audio_default_wrapper_path()) ||
    !@rtcmd.is_executable_file(python_path) {
    return None
  }
  Some(
    audio_wrapper_resolution_from_parts(
      [python_path, audio_default_wrapper_path()],
      @rtcmd.ResolvedCommandSource::RepoManaged,
    ),
  )
}

///|
fn resolve_audio_wrapper_command_from_env() -> Result[
  WrapperCommandResolution?,
  AudioTranscribeError,
] {
  match @rtcmd.normalized_env_var(audio_command_env_var()) {
    Some(command) => {
      let parts = match @rtcmd.split_shell_command(command) {
        Ok(value) => value
        Err(error) =>
          return Err(
            audio_split_command_config_error(audio_command_env_var(), error),
          )
      }
      if parts.length() == 0 {
        return Err(
          AudioTranscribeError::NotConfigured(
            audio_transcribe_not_configured_message(),
          ),
        )
      }
      Ok(
        Some(
          audio_wrapper_resolution_from_parts(
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
fn resolve_audio_wrapper_from_runtime_python_env() -> Result[
  WrapperCommandResolution?,
  AudioTranscribeError,
] {
  match @rtcmd.normalized_env_var(runtime_python_env_var()) {
    Some(path) =>
      match
        resolve_checked_in_audio_wrapper(
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
fn resolve_checked_in_audio_wrapper(
  python_path : String,
  label : String,
  source : @rtcmd.ResolvedCommandSource,
) -> Result[WrapperCommandResolution, AudioTranscribeError] {
  if !@fs.path_exists(audio_default_wrapper_path()) {
    return Err(
      AudioTranscribeError::NotConfigured(
        official_audio_wrapper_missing_message(),
      ),
    )
  }
  let python = match
    @rtcmd.resolve_executable_path(python_path, label, source) {
    Ok(value) => value
    Err(msg) =>
      return Err(
        AudioTranscribeError::NotConfigured(
          msg + "\n\n" + audio_transcribe_install_hint(),
        ),
      )
  }
  Ok(
    audio_wrapper_resolution_from_parts(
      [python.program, audio_default_wrapper_path()],
      source,
    ),
  )
}

///|
fn build_audio_transcribe_command_with_wrapper_resolution(
  prepared_input : PreparedAudioInput,
  result_json_path : String,
  language : String?,
  model_path : String,
  temp_dir : String,
  wrapper : WrapperCommandResolution,
) -> Result[(@rtcmd.ResolvedCommand, Array[String]), AudioTranscribeError] {
  let request_json_path = temp_dir + "/request.json"
  @fs.write_string_to_file(
    request_json_path,
    audio_transcribe_request_json(prepared_input, language, model_path),
    encoding="utf8",
  ) catch {
    e =>
      return Err(
        AudioTranscribeError::ExecutionFailed(
          "failed to write audio request JSON on this runtime: " + e.to_string(),
        ),
      )
  }
  let argv : Array[String] = []
  argv.append(wrapper.argv_prefix[:])
  argv.push("--request-json")
  argv.push(request_json_path)
  argv.push("--result-json")
  argv.push(result_json_path)
  Ok((wrapper.command, argv))
}

///|
fn audio_transcribe_request_json(
  prepared_input : PreparedAudioInput,
  language : String?,
  model_path : String,
) -> String {
  "{" +
  "\"provider\":\"vosk\"," +
  "\"version\":\"v2\"," +
  "\"input_audio_path\":" +
  audio_json_quote_string(prepared_input.input_audio_path) +
  "," +
  "\"normalized_audio_path\":" +
  audio_json_optional_string(prepared_input.normalized_audio_path) +
  "," +
  "\"output_mode\":\"transcript_json\"," +
  "\"language\":" +
  audio_json_quote_string(audio_request_language(language)) +
  "," +
  "\"model_path\":" +
  audio_json_quote_string(model_path) +
  "}"
}

///|
fn audio_request_language(language : String?) -> String {
  match language {
    Some(value) => {
      let trimmed = value.trim().to_owned().to_lower()
      if trimmed == "" {
        "auto"
      } else {
        trimmed
      }
    }
    None => "auto"
  }
}

///|
priv struct PreparedAudioInput {
  input_audio_path : String
  normalized_audio_path : String?
  preprocess_invocation_count : Int
  preprocess_wall_ms : UInt64
  preprocess_kinds : Array[String]
  preprocess_command : @rtcmd.ResolvedCommand?
}

///|
fn resolve_ffmpeg_command() -> Result[
  @rtcmd.ResolvedCommand,
  AudioTranscribeError,
] {
  match @rtcmd.resolve_repo_managed_command("ffmpeg") {
    Some(command) => return Ok(command)
    None => ()
  }
  match @rtcmd.normalized_env_var(ffmpeg_command_env_var()) {
    Some(path) =>
      match
        @rtcmd.resolve_executable_path(
          path,
          ffmpeg_command_env_var(),
          @rtcmd.ResolvedCommandSource::EnvVar,
        ) {
        Ok(command) => return Ok(command)
        Err(msg) =>
          return Err(
            AudioTranscribeError::CommandUnavailable(
              msg + "\n\n" + audio_transcribe_install_hint(),
            ),
          )
      }
    None => ()
  }
  match @rtcmd.resolve_path_command("ffmpeg") {
    Some(command) => Ok(command)
    None => Ok(@rtcmd.fallback_command("ffmpeg"))
  }
}

///|
fn audio_prepare_input_for_backend(
  source_path : String,
  audio_format : @input.AudioFormat,
  temp_dir : String,
) -> Result[PreparedAudioInput, AudioTranscribeError] {
  match audio_format {
    @input.AudioFormat::M4a => {
      let ffmpeg_command = match resolve_ffmpeg_command() {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let normalized_wav_path = temp_dir + "/normalized.wav"
      let started = @env.now()
      let delegated = match
        collect_audio_transcribe_output(
          ffmpeg_command,
          [
            "-y", "-i", source_path, "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le",
            normalized_wav_path,
          ],
          "ffmpeg",
        ) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let wall_ms = @env.now() - started
      match delegated {
        (0, stdout, stderr) => {
          if !@fs.path_exists(normalized_wav_path) {
            return Err(
              AudioTranscribeError::ExecutionFailed(
                "ffmpeg reported success but produced no normalized wav output on this runtime.\nResolved command: " +
                @rtcmd.resolved_command_context(ffmpeg_command),
              ),
            )
          }
          let diagnostics : Array[String] = []
          let stdout_text = stdout.trim().to_owned()
          let stderr_text = stderr.trim().to_owned()
          if stdout_text != "" {
            diagnostics.push(stdout_text)
          }
          if stderr_text != "" {
            diagnostics.push(stderr_text)
          }
          ignore(diagnostics)
          Ok({
            input_audio_path: source_path,
            normalized_audio_path: Some(normalized_wav_path),
            preprocess_invocation_count: 1,
            preprocess_wall_ms: wall_ms,
            preprocess_kinds: ["ffmpeg"],
            preprocess_command: Some(ffmpeg_command),
          })
        }
        (code, stdout, stderr) => {
          let stderr_text = stderr.trim().to_owned()
          let stdout_text = stdout.trim().to_owned()
          let raw_message = if stderr_text != "" {
            stderr_text
          } else if stdout_text != "" {
            stdout_text
          } else {
            "ffmpeg exited with code " + code.to_string()
          }
          let lowered = raw_message.to_lower()
          if lowered.contains("command not found") ||
            lowered.contains("not found") ||
            lowered.contains("no such file") {
            Err(
              AudioTranscribeError::CommandUnavailable(
                "ffmpeg is required for `m4a` audio input on this runtime: " +
                raw_message +
                "\nResolved command: " +
                @rtcmd.resolved_command_context(ffmpeg_command) +
                "\n\n" +
                audio_transcribe_install_hint(),
              ),
            )
          } else {
            Err(
              AudioTranscribeError::ExecutionFailed(
                "ffmpeg failed to normalize `m4a` audio on this runtime: " +
                raw_message +
                "\nResolved command: " +
                @rtcmd.resolved_command_context(ffmpeg_command),
              ),
            )
          }
        }
      }
    }
    _ =>
      Ok({
        input_audio_path: source_path,
        normalized_audio_path: None,
        preprocess_invocation_count: 0,
        preprocess_wall_ms: 0,
        preprocess_kinds: [],
        preprocess_command: None,
      })
  }
}

///|
fn audio_validate_model_path() -> Result[String, AudioTranscribeError] {
  let model_path = audio_resolved_model_path()
  let model_is_dir = @fs.is_dir(model_path) catch { _ => false }
  if @fs.path_exists(model_path) && model_is_dir {
    Ok(model_path)
  } else {
    Err(
      AudioTranscribeError::NotConfigured(
        "Vosk model directory is not available on this runtime: " +
        model_path +
        "\n\n" +
        audio_transcribe_install_hint(),
      ),
    )
  }
}

///|
pub fn run_audio_transcribe_command(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  language : String?,
) -> Result[AudioTranscriptResult, AudioTranscribeError] {
  let plan = match build_audio_transcribe_plan(source, format, language) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  defer audio_cleanup_temp_dir(plan.temp_dir)
  let backend_started = @env.now()
  let delegated = match
    collect_audio_transcribe_output(
      plan.backend_command,
      plan.argv,
      "audio backend command",
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let backend_wall_ms = @env.now() - backend_started
  finalize_audio_transcribe_command_result(
    delegated,
    plan,
    plan.result_json_path,
    format,
    language,
    audio_runtime_metrics(plan, backend_wall_ms),
  )
}

///|
pub fn run_audio_transcribe_command_with_collect(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  language : String?,
  collect_output : (String, Array[String]) -> Result[
    (Int, String, String),
    AudioTranscribeError,
  ],
) -> Result[AudioTranscriptResult, AudioTranscribeError] {
  let plan = match build_audio_transcribe_plan(source, format, language) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  defer audio_cleanup_temp_dir(plan.temp_dir)
  let backend_started = @env.now()
  let delegated = match
    collect_output(plan.backend_command.program, plan.argv) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let backend_wall_ms = @env.now() - backend_started
  finalize_audio_transcribe_command_result(
    delegated,
    plan,
    plan.result_json_path,
    format,
    language,
    audio_runtime_metrics(plan, backend_wall_ms),
  )
}

///|
fn finalize_audio_transcribe_command_result(
  delegated : (Int, String, String),
  plan : AudioCommandPlan,
  result_json_path : String,
  format : @input.DetectedFormat,
  requested_language : String?,
  runtime_metrics : AudioRuntimeMetrics,
) -> Result[AudioTranscriptResult, AudioTranscribeError] {
  match delegated {
    (0, stdout, stderr) => {
      let payload = @fs.read_file_to_string(result_json_path, encoding="utf8") catch {
        e =>
          return Err(
            AudioTranscribeError::OutputParseFailed(
              "audio backend did not produce a readable JSON transcript on this runtime: " +
              e.to_string(),
            ),
          )
      }
      let parsed = match
        parse_audio_transcript_json_payload(payload, format, requested_language) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let diagnostics = parsed.diagnostics.copy()
      let stdout_text = stdout.trim().to_owned()
      let stderr_text = stderr.trim().to_owned()
      if stdout_text != "" {
        diagnostics.push("audio_backend_stdout=" + stdout_text)
      }
      if stderr_text != "" {
        diagnostics.push("audio_backend_stderr=" + stderr_text)
      }
      diagnostics.push(
        "audio_backend_command_source=" +
        @rtcmd.resolved_command_source_label(plan.backend_command.source),
      )
      diagnostics.push(
        "audio_backend_command=" + plan.backend_command.display_command,
      )
      match plan.preprocess_command {
        Some(command) => {
          diagnostics.push(
            "ffmpeg_command_source=" +
            @rtcmd.resolved_command_source_label(command.source),
          )
          diagnostics.push("ffmpeg_command=" + command.display_command)
        }
        None => ()
      }
      diagnostics.push(
        audio_metric_diagnostic(
          "audio_backend_wall_ms",
          runtime_metrics.audio_backend_wall_ms.to_string(),
        ),
      )
      diagnostics.push(
        audio_metric_diagnostic(
          "external_process_invocation_count",
          runtime_metrics.external_process_invocation_count.to_string(),
        ),
      )
      diagnostics.push(
        audio_metric_diagnostic(
          "external_process_kind",
          runtime_metrics.external_process_kind,
        ),
      )
      diagnostics.push(
        audio_metric_diagnostic(
          "external_process_wall_ms",
          runtime_metrics.external_process_wall_ms.to_string(),
        ),
      )
      diagnostics.push(
        audio_metric_diagnostic("external_process_batch_job_count", "1"),
      )
      diagnostics.push(
        audio_metric_diagnostic("external_process_cache_hit", "false"),
      )
      diagnostics.push(
        audio_metric_diagnostic(
          "audio_normalization_used",
          if runtime_metrics.audio_normalization_used {
            "true"
          } else {
            "false"
          },
        ),
      )
      Ok({ ..parsed, diagnostics, })
    }
    (code, stdout, stderr) => {
      let raw_message = audio_process_raw_message(
        "audio backend exited with code " + code.to_string(),
        stdout,
        stderr,
      )
      let lowered = raw_message.to_lower()
      if audio_raw_message_suggests_missing_command(raw_message) ||
        lowered.contains("ffmpeg is required") {
        Err(
          AudioTranscribeError::CommandUnavailable(
            "audio backend command is unavailable on this runtime: " +
            raw_message +
            "\nResolved command: " +
            @rtcmd.resolved_command_context(plan.backend_command) +
            "\n\n" +
            audio_transcribe_install_hint(),
          ),
        )
      } else if lowered.contains("vosk model directory is unavailable") ||
        lowered.contains("vosk python package is unavailable") {
        Err(
          AudioTranscribeError::NotConfigured(
            "audio backend is not fully configured on this runtime: " +
            raw_message +
            "\nResolved command: " +
            @rtcmd.resolved_command_context(plan.backend_command) +
            "\n\n" +
            audio_transcribe_install_hint(),
          ),
        )
      } else {
        Err(
          AudioTranscribeError::ExecutionFailed(
            "audio backend command failed on this runtime: " +
            raw_message +
            "\nResolved command: " +
            @rtcmd.resolved_command_context(plan.backend_command) +
            "\n\n" +
            audio_transcribe_install_hint(),
          ),
        )
      }
    }
  }
}

///|
fn audio_runtime_metrics(
  plan : AudioCommandPlan,
  backend_wall_ms : UInt64,
) -> AudioRuntimeMetrics {
  let kinds = plan.preprocess_kinds.copy()
  kinds.push("audio_backend")
  {
    external_process_invocation_count: plan.preprocess_invocation_count + 1,
    external_process_wall_ms: plan.preprocess_wall_ms + backend_wall_ms,
    external_process_kind: kinds.join(","),
    audio_backend_wall_ms: backend_wall_ms,
    audio_normalization_used: plan.preprocess_invocation_count > 0,
  }
}
