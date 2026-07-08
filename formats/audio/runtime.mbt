///|
const AUDIO_TMP_ROOT : String = ".tmp/tests/audio_native"

///|
pub fn audio_command_env_var() -> String {
  "MARKITDOWN_AUDIO_CMD"
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
  let cache_root = match normalized_env_var("XDG_CACHE_HOME") {
    Some(path) => path
    None =>
      match normalized_env_var("HOME") {
        Some(home) => home + "/.cache"
        None => ".cache"
      }
  }
  cache_root + "/markitdown/vosk/model"
}

///|
fn audio_runtime_tmp_root() -> String {
  match normalized_env_var("MARKITDOWN_TMP_DIR") {
    Some(path) => path + "/audio_native"
    None => AUDIO_TMP_ROOT
  }
}

///|
fn audio_resolved_model_path() -> String {
  match normalized_env_var(audio_model_path_env_var()) {
    Some(path) => path
    None => audio_default_model_path()
  }
}

///|
fn audio_default_wrapper_path() -> String {
  "samples/env/audio/audio_transcribe_wrapper.py"
}

///|
fn repo_local_runtime_python_path() -> String {
  "env/.venv-markitdown-runtime/bin/python"
}

///|
fn resolved_runtime_python_command() -> String? {
  match normalized_env_var(runtime_python_env_var()) {
    Some(path) => if @fs.path_exists(path) { Some(path) } else { None }
    None => {
      let repo_local = repo_local_runtime_python_path()
      if @fs.path_exists(repo_local) {
        Some(repo_local)
      } else {
        None
      }
    }
  }
}

///|
fn shell_quote_command_part(part : String) -> String {
  let mut needs_quote = false
  for ch in part.to_array() {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '"' || ch == '\\' {
      needs_quote = true
    }
  }
  if !needs_quote {
    return part
  }
  let out : Array[Char] = ['"']
  for ch in part.to_array() {
    if ch == '"' || ch == '\\' {
      out.push('\\')
    }
    out.push(ch)
  }
  out.push('"')
  String::from_array(out)
}

///|
fn audio_default_wrapper_command() -> String {
  let python_cmd = match resolved_runtime_python_command() {
    Some(path) => path
    None => "python3"
  }
  shell_quote_command_part(python_cmd) +
  " " +
  shell_quote_command_part(audio_default_wrapper_path())
}

///|
pub fn audio_transcribe_install_hint() -> String {
  [
    "Preferred: configure `" +
    audio_command_env_var() +
    "` with the official helper `samples/env/audio/audio_transcribe_wrapper.py`, or leave it unset to use that wrapper by default.",
    "Recommended setup from the repo root: `./samples/env/install_audio_deps.sh`. If you run from the repo root, the runtime auto-detects the repo-local virtualenv; `source ./env/audio.env.sh` is only needed when you want those paths exported into another shell.",
    "Python dependencies should live in the repo-local virtualenv under `./env/`, not in your global `python3` environment.",
    "Recommended model directory: " + audio_default_model_path(),
    "Set `" +
    audio_model_path_env_var() +
    "` to point at the extracted model directory when needed.",
    "Plain PCM `wav` is the lightest supported route. `m4a` still requires local `ffmpeg`, and the wrapper may also use `ffmpeg` when it needs to normalize compressed audio.",
  ].join("\n")
}

///|
pub fn audio_transcribe_not_configured_message() -> String {
  "Audio transcription backend is not available on this runtime.\n\n" +
  audio_transcribe_install_hint()
}

///|
priv struct AudioCommandPlan {
  backend_cmd : String
  argv : Array[String]
  output_json_path : String
  temp_dir : String
}

///|
pub fn build_audio_transcribe_command(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  language : String?,
) -> Result[(String, Array[String]), AudioTranscribeError] {
  match build_audio_transcribe_plan(source, format, language) {
    Ok(plan) => Ok((plan.backend_cmd, plan.argv))
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
  let output_base = temp_dir + "/transcript"
  let output_json_path = output_base + ".json"
  let (backend_cmd, argv) = match
    audio_backend_command_plan(
      prepared_input.invoked_input_path,
      output_json_path,
      language,
    ) {
    Ok(value) => value
    Err(error) => {
      audio_cleanup_temp_dir(temp_dir)
      return Err(error)
    }
  }
  Ok({ backend_cmd, argv, output_json_path, temp_dir })
}

///|
fn audio_backend_command_plan(
  prepared_input_path : String,
  output_json_path : String,
  language : String?,
) -> Result[(String, Array[String]), AudioTranscribeError] {
  match normalized_env_var(audio_command_env_var()) {
    Some(command) =>
      build_audio_transcribe_command_with_wrapper(
        prepared_input_path, output_json_path, language, command,
      )
    None =>
      build_audio_transcribe_direct_command(
        prepared_input_path, output_json_path, language,
      )
  }
}

///|
fn build_audio_transcribe_direct_command(
  prepared_input_path : String,
  output_json_path : String,
  language : String?,
) -> Result[(String, Array[String]), AudioTranscribeError] {
  let _model_path = match audio_validate_model_path() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  build_audio_transcribe_command_with_wrapper(
    prepared_input_path,
    output_json_path,
    language,
    audio_default_wrapper_command(),
  )
}

///|
fn build_audio_transcribe_command_with_wrapper(
  prepared_input_path : String,
  output_json_path : String,
  language : String?,
  wrapper_command : String,
) -> Result[(String, Array[String]), AudioTranscribeError] {
  let trimmed = wrapper_command.trim().to_owned()
  if trimmed == "" {
    return Err(
      AudioTranscribeError::NotConfigured(
        audio_transcribe_not_configured_message(),
      ),
    )
  }
  let parts = match audio_command_parts(trimmed) {
    Ok(value) => value
    Err(msg) => return Err(AudioTranscribeError::NotConfigured(msg))
  }
  if parts.length() == 0 {
    return Err(
      AudioTranscribeError::NotConfigured(
        audio_transcribe_not_configured_message(),
      ),
    )
  }
  let argv : Array[String] = []
  argv.append(parts[1:][:])
  argv.push(prepared_input_path)
  argv.push(output_json_path)
  audio_append_wrapper_language(argv, language)
  Ok((parts[0], argv))
}

///|
fn audio_append_wrapper_language(
  argv : Array[String],
  language : String?,
) -> Unit {
  match language {
    Some(value) => {
      let trimmed = value.trim().to_owned().to_lower()
      argv.push("--lang")
      argv.push(if trimmed == "" { "auto" } else { trimmed })
    }
    None => {
      argv.push("--lang")
      argv.push("auto")
    }
  }
}

///|
priv struct PreparedAudioInput {
  invoked_input_path : String
}

///|
fn audio_prepare_input_for_backend(
  source_path : String,
  audio_format : @input.AudioFormat,
  temp_dir : String,
) -> Result[PreparedAudioInput, AudioTranscribeError] {
  match audio_format {
    @input.AudioFormat::M4a => {
      let normalized_wav_path = temp_dir + "/normalized.wav"
      let delegated = match
        collect_audio_transcribe_output("ffmpeg", [
          "-y", "-i", source_path, "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le",
          normalized_wav_path,
        ]) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      match delegated {
        (0, stdout, stderr) => {
          if !@fs.path_exists(normalized_wav_path) {
            return Err(
              AudioTranscribeError::ExecutionFailed(
                "ffmpeg reported success but produced no normalized wav output on this runtime.",
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
          Ok({ invoked_input_path: normalized_wav_path })
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
                "\n\n" +
                audio_transcribe_install_hint(),
              ),
            )
          } else {
            Err(
              AudioTranscribeError::ExecutionFailed(
                "ffmpeg failed to normalize `m4a` audio on this runtime: " +
                raw_message,
              ),
            )
          }
        }
      }
    }
    _ => Ok({ invoked_input_path: source_path })
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
fn audio_command_parts(command : String) -> Result[Array[String], String] {
  if @fs.path_exists(command) {
    return Ok([command])
  }
  let parts : Array[String] = []
  let current : Array[Char] = []
  let chars = command.to_array()
  let mut in_single_quote = false
  let mut in_double_quote = false
  let mut escape_next = false

  fn flush_current(parts : Array[String], current : Array[Char]) -> Unit {
    if current.length() == 0 {
      return
    }
    parts.push(String::from_array(current))
    current.clear()
  }

  for ch in chars {
    if escape_next {
      current.push(ch)
      escape_next = false
      continue
    }
    if ch == '\\' && !in_single_quote {
      escape_next = true
      continue
    }
    if ch == '\'' && !in_double_quote {
      in_single_quote = !in_single_quote
      continue
    }
    if ch == '"' && !in_single_quote {
      in_double_quote = !in_double_quote
      continue
    }
    if (ch == ' ' || ch == '\t' || ch == '\n') &&
      !in_single_quote &&
      !in_double_quote {
      flush_current(parts, current)
      continue
    }
    current.push(ch)
  }

  if escape_next || in_single_quote || in_double_quote {
    return Err(
      "Audio command configured through `" +
      audio_command_env_var() +
      "` is not shell-parseable on this runtime.\n\n" +
      audio_transcribe_install_hint(),
    )
  }

  flush_current(parts, current)
  Ok(parts)
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
  let delegated = match
    collect_audio_transcribe_output(plan.backend_cmd, plan.argv) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_audio_transcribe_command_result(
    delegated,
    plan.output_json_path,
    format,
    language,
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
  let delegated = match collect_output(plan.backend_cmd, plan.argv) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_audio_transcribe_command_result(
    delegated,
    plan.output_json_path,
    format,
    language,
  )
}

///|
fn finalize_audio_transcribe_command_result(
  delegated : (Int, String, String),
  output_json_path : String,
  format : @input.DetectedFormat,
  requested_language : String?,
) -> Result[AudioTranscriptResult, AudioTranscribeError] {
  match delegated {
    (0, stdout, stderr) => {
      let payload = @fs.read_file_to_string(output_json_path, encoding="utf8") catch {
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
            "\n\n" +
            audio_transcribe_install_hint(),
          ),
        )
      } else {
        Err(
          AudioTranscribeError::ExecutionFailed(
            "audio backend command failed on this runtime: " +
            raw_message +
            "\n\n" +
            audio_transcribe_install_hint(),
          ),
        )
      }
    }
  }
}

///|
fn parse_audio_transcript_json_payload(
  payload : String,
  format : @input.DetectedFormat,
  requested_language : String?,
) -> Result[AudioTranscriptResult, AudioTranscribeError] {
  let trimmed = payload.trim().to_owned()
  if trimmed == "" {
    return Err(
      AudioTranscribeError::EmptyResult(
        "audio backend produced an empty JSON transcript on this runtime.",
      ),
    )
  }
  let root = @djson.parse_json_document(trimmed) catch {
    err =>
      return Err(
        AudioTranscribeError::OutputParseFailed(
          "audio backend emitted invalid JSON on this runtime: " +
          err.to_string(),
        ),
      )
  }
  let root_object = match root.root {
    @djson.JsonValue::Object(entries) => json_object_from_members(entries)
    _ =>
      return Err(
        AudioTranscribeError::OutputParseFailed(
          "audio transcript JSON root must be an object on this runtime.",
        ),
      )
  }
  let segments_payload = match root_object.get("segments") {
    Some(@djson.JsonValue::Array(items)) => items
    _ =>
      return Err(
        AudioTranscribeError::OutputParseFailed(
          "audio transcript JSON must include a `segments` array on this runtime.",
        ),
      )
  }
  let metadata = audio_transcript_metadata_from_object(
    root_object, format, requested_language,
  )
  let provider_name = match
    audio_trimmed_optional(json_string_optional(root_object, "provider_name")) {
    Some(value) => value
    None => audio_backend_name()
  }
  let provider_version = audio_trimmed_optional(
    json_string_optional(root_object, "provider_version"),
  )
  let segments = match
    audio_transcript_segments(segments_payload, metadata.language) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if segments.length() == 0 {
    return Err(
      AudioTranscribeError::EmptyResult(
        "audio backend produced zero transcript segments on this runtime.",
      ),
    )
  }
  let diagnostics : Array[String] = [
    "backend=" + provider_name,
    "transport=" + audio_backend_transport_name(),
    "model_path=" + audio_resolved_model_path(),
  ]
  for item in json_string_array_optional(root_object, "diagnostics") {
    diagnostics.push(item)
  }
  let requested_trimmed = audio_trimmed_optional(requested_language)
  match requested_trimmed {
    Some(value) => diagnostics.push("requested_lang=" + value)
    None => diagnostics.push("requested_lang=none")
  }
  Ok(
    make_audio_transcript_result(
      provider_name,
      metadata,
      segments,
      provider_version~,
      diagnostics~,
    ),
  )
}

///|
fn audio_transcript_metadata_from_object(
  payload : Map[String, @djson.JsonValue],
  format : @input.DetectedFormat,
  requested_language : String?,
) -> AudioTranscriptMetadata {
  let metadata_object = match payload.get("metadata") {
    Some(@djson.JsonValue::Object(entries)) =>
      Some(json_object_from_members(entries))
    _ => None
  }
  let metadata = metadata_object.unwrap_or(Map([]))
  let language = match
    audio_trimmed_optional(json_string_optional(metadata, "language")) {
    Some("auto") | None => audio_trimmed_optional(requested_language)
    some => some
  }
  let codec = match
    audio_trimmed_optional(json_string_optional(metadata, "codec")) {
    Some(value) => Some(value)
    None => Some(@input.detected_format_name(format))
  }
  make_audio_transcript_metadata(
    duration_ms=json_int_optional(metadata, "duration_ms"),
    sample_rate_hz=json_int_optional(metadata, "sample_rate_hz"),
    channel_count=json_int_optional(metadata, "channel_count"),
    codec~,
    language~,
  )
}

///|
fn audio_transcript_segments(
  items : Array[@djson.JsonValue],
  default_language : String?,
) -> Result[Array[AudioTranscriptSegment], AudioTranscribeError] {
  let segments : Array[AudioTranscriptSegment] = []
  for i in 0..<items.length() {
    let object = match items[i] {
      @djson.JsonValue::Object(entries) => json_object_from_members(entries)
      _ =>
        return Err(
          AudioTranscribeError::OutputParseFailed(
            "audio transcript segments must be JSON objects on this runtime.",
          ),
        )
    }
    let text = match json_string_required(object, "text") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let start_ms = match json_int_required(object, "start_ms") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let end_ms = match json_int_required(object, "end_ms") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if start_ms < 0 || end_ms < start_ms {
      return Err(
        AudioTranscribeError::OutputParseFailed(
          "audio transcript segments must carry non-negative ordered timestamps on this runtime.",
        ),
      )
    }
    let confidence = json_double_optional(object, "confidence")
    let trimmed_text = text.trim().to_owned()
    if trimmed_text == "" {
      continue
    }
    let segment_language = match
      audio_trimmed_optional(json_string_optional(object, "language")) {
      Some(value) => Some(value)
      None => default_language
    }
    segments.push(
      make_audio_transcript_segment(
        json_string_optional(object, "segment_id").unwrap_or(
          "seg-" + (i + 1).to_string(),
        ),
        start_ms,
        end_ms,
        trimmed_text,
        speaker=json_string_optional(object, "speaker"),
        channel=json_int_optional(object, "channel"),
        confidence~,
        language=segment_language,
      ),
    )
  }
  Ok(segments)
}

///|
fn audio_local_source_path(
  source : @input.InputSource,
) -> Result[String, AudioTranscribeError] {
  match source.path {
    Some(path) => {
      let trimmed = path.trim().to_owned()
      if trimmed == "" {
        Err(
          AudioTranscribeError::ExecutionFailed(
            "audio transcription requires a local file path source",
          ),
        )
      } else if !@fs.path_exists(trimmed) {
        Err(
          AudioTranscribeError::ExecutionFailed(
            "audio input path does not exist on this runtime: " + trimmed,
          ),
        )
      } else if !(@fs.is_file(trimmed) catch { _ => false }) {
        Err(
          AudioTranscribeError::ExecutionFailed(
            "audio transcription requires a local file path source",
          ),
        )
      } else {
        Ok(trimmed)
      }
    }
    None =>
      Err(
        AudioTranscribeError::ExecutionFailed(
          "audio transcription requires a local file path source",
        ),
      )
  }
}

///|
fn audio_ensure_dir_tree(path : String) -> Unit raise @fs.IOError {
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
fn audio_remove_dir_recursive(path : String) -> Unit raise @fs.IOError {
  if !@fs.path_exists(path) {
    return
  }
  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      audio_remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }
  @fs.remove_dir(path)
}

///|
fn audio_cleanup_temp_dir(path : String) -> Unit {
  ignore(
    try audio_remove_dir_recursive(path) |> Ok catch {
      _ => Err(())
    },
  )
}

///|
fn audio_temp_dir_name(source : @input.InputSource) -> String {
  let raw = match source.path {
    Some(path) => path
    None => source.source_name
  }
  let safe : Array[Char] = []
  for ch in raw.to_array() {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') {
      safe.push(ch)
    } else {
      safe.push('_')
    }
  }
  let normalized = String::from_array(safe).trim().to_owned()
  let base = if normalized == "" { "input" } else { normalized }
  audio_runtime_tmp_root() + "/" + base + "_" + @env.now().to_string()
}

///|
fn audio_process_raw_message(
  fallback : String,
  stdout : String,
  stderr : String,
) -> String {
  let stderr_text = stderr.trim().to_owned()
  if stderr_text != "" {
    return stderr_text
  }
  let stdout_text = stdout.trim().to_owned()
  if stdout_text != "" {
    stdout_text
  } else {
    fallback
  }
}

///|
fn audio_raw_message_suggests_missing_command(message : String) -> Bool {
  let lowered = message.to_lower()
  lowered.contains("command not found") ||
  lowered.contains("not found") ||
  lowered.contains("no such file")
}

///|
fn audio_trimmed_optional(value : String?) -> String? {
  match value {
    Some(text) => {
      let trimmed = text.trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
fn json_object_from_members(
  entries : Array[@djson.JsonMember],
) -> Map[String, @djson.JsonValue] {
  let object : Map[String, @djson.JsonValue] = Map([])
  for entry in entries {
    object.set(entry.key, entry.value)
  }
  object
}

///|
fn json_string_required(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> Result[String, AudioTranscribeError] {
  match payload.get(key) {
    Some(@djson.JsonValue::String(value)) => Ok(value)
    _ =>
      Err(
        AudioTranscribeError::OutputParseFailed(
          "audio transcript payload is missing required string field `" +
          key +
          "` on this runtime.",
        ),
      )
  }
}

///|
fn json_string_optional(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> String? {
  match payload.get(key) {
    Some(@djson.JsonValue::String(value)) => Some(value)
    _ => None
  }
}

///|
fn json_int_required(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> Result[Int, AudioTranscribeError] {
  match payload.get(key) {
    Some(@djson.JsonValue::Number(value)) =>
      Ok(
        @string.parse_int(value) catch {
          _ =>
            return Err(
              AudioTranscribeError::OutputParseFailed(
                "audio transcript numeric field `" +
                key +
                "` is not a valid integer on this runtime.",
              ),
            )
        },
      )
    _ =>
      Err(
        AudioTranscribeError::OutputParseFailed(
          "audio transcript payload is missing required numeric field `" +
          key +
          "` on this runtime.",
        ),
      )
  }
}

///|
fn json_int_optional(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> Int? {
  match payload.get(key) {
    Some(@djson.JsonValue::Number(value)) =>
      Some(@string.parse_int(value) catch { _ => return None })
    _ => None
  }
}

///|
fn json_double_optional(
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
fn json_string_array_optional(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> Array[String] {
  let values : Array[String] = []
  match payload.get(key) {
    Some(@djson.JsonValue::Array(items)) =>
      for item in items {
        match item {
          @djson.JsonValue::String(value) => values.push(value)
          _ => ()
        }
      }
    _ => ()
  }
  values
}

///|
#warnings("-deprecated")
fn collect_audio_transcribe_output(
  cmd : String,
  args : Array[String],
) -> Result[(Int, String, String), AudioTranscribeError] {
  let collected : Ref[Result[(Int, String, String), AudioTranscribeError]?] = {
    val: None,
  }
  @async.with_event_loop(_group => {
    let delegated = @process.collect_output(cmd, args) catch {
      e => {
        collected.val = Some(
          Err(
            AudioTranscribeError::ExecutionFailed(
              "launch audio command failed on this runtime: " + e.to_string(),
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
                AudioTranscribeError::OutputParseFailed(
                  "failed to decode audio command stdout as UTF-8 on this runtime: " +
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
                AudioTranscribeError::OutputParseFailed(
                  "failed to decode audio command stderr as UTF-8 on this runtime: " +
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
        AudioTranscribeError::ExecutionFailed(
          "launch audio command failed on this runtime: " + e.to_string(),
        ),
      )
  }
  match collected.val {
    Some(result) => result
    None =>
      Err(
        AudioTranscribeError::ExecutionFailed(
          "launch audio command failed on this runtime: event loop returned no result",
        ),
      )
  }
}

///|
fn normalized_env_var(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}
