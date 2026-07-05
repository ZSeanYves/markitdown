///|
const AUDIO_TMP_ROOT : String = ".tmp/audio_native"

///|
pub fn audio_model_path_env_var() -> String {
  "MARKITDOWN_AUDIO_MODEL_PATH"
}

///|
pub fn audio_backend_transport_name() -> String {
  "native_cli"
}

///|
pub fn audio_backend_name() -> String {
  "whisper_cpp"
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
  cache_root + "/markitdown/whisper.cpp/ggml-base.bin"
}

///|
fn audio_resolved_model_path() -> String {
  match normalized_env_var(audio_model_path_env_var()) {
    Some(path) => path
    None => audio_default_model_path()
  }
}

///|
fn audio_whisper_candidate_commands() -> Array[String] {
  ["whisper-cli", "main"]
}

///|
pub fn audio_transcribe_install_hint() -> String {
  [
    "Install local `whisper.cpp` and make `whisper-cli` available on PATH.",
    "The runtime also accepts `main` as a compatibility fallback binary name.",
    "Download the multilingual `ggml-base` model locally.",
    "Default model path: " + audio_default_model_path(),
    "Override model path with `" + audio_model_path_env_var() + "` when needed.",
    "Install local `ffmpeg` when you need `m4a` input support.",
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
  let backend_cmd = match audio_discover_backend_command() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let model_path = match audio_validate_model_path() {
    Ok(value) => value
    Err(error) => return Err(error)
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
  let argv : Array[String] = [
    "-m",
    model_path,
    "-f",
    prepared_input.invoked_input_path,
    "-ojf",
    "-of",
    output_base,
    "-np",
  ]
  match language {
    Some(value) => {
      let trimmed = value.trim().to_owned().to_lower()
      if trimmed != "" {
        argv.push("-l")
        argv.push(trimmed)
      } else {
        argv.push("-l")
        argv.push("auto")
      }
    }
    None => {
      argv.push("-l")
      argv.push("auto")
    }
  }
  Ok({ backend_cmd, argv, output_json_path, temp_dir })
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
  let model_is_file = @fs.is_file(model_path) catch { _ => false }
  if @fs.path_exists(model_path) && model_is_file {
    Ok(model_path)
  } else {
    Err(
      AudioTranscribeError::NotConfigured(
        "Whisper model is not available on this runtime: " +
        model_path +
        "\n\n" +
        audio_transcribe_install_hint(),
      ),
    )
  }
}

///|
fn audio_discover_backend_command() -> Result[String, AudioTranscribeError] {
  for candidate in audio_whisper_candidate_commands() {
    match collect_audio_transcribe_output(candidate, ["--help"]) {
      Ok((0, _stdout, _stderr)) => return Ok(candidate)
      Ok((code, stdout, stderr)) => {
        let raw_message = audio_process_raw_message(
          candidate + " exited with code " + code.to_string(),
          stdout,
          stderr,
        )
        if !audio_raw_message_suggests_missing_command(raw_message) {
          return Ok(candidate)
        }
      }
      Err(AudioTranscribeError::ExecutionFailed(msg)) =>
        if audio_raw_message_suggests_missing_command(msg) {
          ()
        } else {
          return Ok(candidate)
        }
      Err(AudioTranscribeError::CommandUnavailable(msg)) =>
        if audio_raw_message_suggests_missing_command(msg) {
          ()
        } else {
          return Ok(candidate)
        }
      Err(_other) => return Ok(candidate)
    }
  }
  Err(
    AudioTranscribeError::CommandUnavailable(
      "whisper.cpp CLI is unavailable on this runtime. Expected `whisper-cli` or `main` on PATH.\n\n" +
      audio_transcribe_install_hint(),
    ),
  )
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
              "whisper.cpp did not produce a readable JSON transcript on this runtime: " +
              e.to_string(),
            ),
          )
      }
      let parsed = match
        parse_whisper_cpp_json_payload(payload, format, requested_language) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let diagnostics = parsed.diagnostics.copy()
      let stdout_text = stdout.trim().to_owned()
      let stderr_text = stderr.trim().to_owned()
      if stdout_text != "" {
        diagnostics.push("whisper_stdout=" + stdout_text)
      }
      if stderr_text != "" {
        diagnostics.push("whisper_stderr=" + stderr_text)
      }
      Ok({ ..parsed, diagnostics, })
    }
    (code, stdout, stderr) => {
      let raw_message = audio_process_raw_message(
        "whisper.cpp exited with code " + code.to_string(),
        stdout,
        stderr,
      )
      if audio_raw_message_suggests_missing_command(raw_message) {
        Err(
          AudioTranscribeError::CommandUnavailable(
            "whisper.cpp CLI is unavailable on this runtime: " +
            raw_message +
            "\n\n" +
            audio_transcribe_install_hint(),
          ),
        )
      } else {
        Err(
          AudioTranscribeError::ExecutionFailed(
            "whisper.cpp CLI failed on this runtime: " +
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
fn parse_whisper_cpp_json_payload(
  payload : String,
  format : @input.DetectedFormat,
  requested_language : String?,
) -> Result[AudioTranscriptResult, AudioTranscribeError] {
  let trimmed = payload.trim().to_owned()
  if trimmed == "" {
    return Err(
      AudioTranscribeError::EmptyResult(
        "whisper.cpp produced an empty JSON transcript on this runtime.",
      ),
    )
  }
  let root = @djson.parse_json_document(trimmed) catch {
    err =>
      return Err(
        AudioTranscribeError::OutputParseFailed(
          "whisper.cpp emitted invalid JSON on this runtime: " + err.to_string(),
        ),
      )
  }
  let root_object = match root.root {
    @djson.JsonValue::Object(entries) => json_object_from_members(entries)
    _ =>
      return Err(
        AudioTranscribeError::OutputParseFailed(
          "whisper.cpp JSON root must be an object on this runtime.",
        ),
      )
  }
  let transcription = match root_object.get("transcription") {
    Some(@djson.JsonValue::Array(items)) => items
    _ =>
      return Err(
        AudioTranscribeError::OutputParseFailed(
          "whisper.cpp JSON must include a `transcription` array on this runtime.",
        ),
      )
  }
  let metadata = whisper_cpp_metadata_from_object(
    root_object, format, requested_language,
  )
  let segments = match whisper_cpp_segments(transcription, metadata.language) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if segments.length() == 0 {
    return Err(
      AudioTranscribeError::EmptyResult(
        "whisper.cpp produced zero transcript segments on this runtime.",
      ),
    )
  }
  let diagnostics : Array[String] = [
    "backend=" + audio_backend_name(),
    "transport=" + audio_backend_transport_name(),
    "model_path=" + audio_resolved_model_path(),
  ]
  let requested_trimmed = audio_trimmed_optional(requested_language)
  match requested_trimmed {
    Some(value) => diagnostics.push("requested_lang=" + value)
    None => diagnostics.push("requested_lang=none")
  }
  Ok(
    make_audio_transcript_result(
      audio_backend_name(),
      metadata,
      segments,
      provider_version=None,
      diagnostics~,
    ),
  )
}

///|
fn whisper_cpp_metadata_from_object(
  payload : Map[String, @djson.JsonValue],
  format : @input.DetectedFormat,
  requested_language : String?,
) -> AudioTranscriptMetadata {
  let result_language = match payload.get("result") {
    Some(@djson.JsonValue::Object(entries)) =>
      json_string_optional(json_object_from_members(entries), "language")
    _ => None
  }
  let params_language = match payload.get("params") {
    Some(@djson.JsonValue::Object(entries)) =>
      json_string_optional(json_object_from_members(entries), "language")
    _ => None
  }
  let language = match audio_trimmed_optional(result_language) {
    Some("auto") | None =>
      match audio_trimmed_optional(params_language) {
        Some("auto") | None => audio_trimmed_optional(requested_language)
        some => some
      }
    some => some
  }
  make_audio_transcript_metadata(
    codec=Some(@input.detected_format_name(format)),
    language~,
  )
}

///|
fn whisper_cpp_segments(
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
            "whisper.cpp transcript segments must be JSON objects on this runtime.",
          ),
        )
    }
    let text = match json_string_required(object, "text") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let offsets = match object.get("offsets") {
      Some(@djson.JsonValue::Object(entries)) =>
        json_object_from_members(entries)
      _ =>
        return Err(
          AudioTranscribeError::OutputParseFailed(
            "whisper.cpp transcript segments must include `offsets` on this runtime.",
          ),
        )
    }
    let start_ms = match json_int_required(offsets, "from") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let end_ms = match json_int_required(offsets, "to") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let confidence = whisper_cpp_segment_confidence(object)
    let segment_language = match
      audio_trimmed_optional(json_string_optional(object, "language")) {
      Some(value) => Some(value)
      None => default_language
    }
    segments.push(
      make_audio_transcript_segment(
        "seg-" + (i + 1).to_string(),
        start_ms,
        end_ms,
        text,
        speaker=json_string_optional(object, "speaker"),
        confidence~,
        language=segment_language,
      ),
    )
  }
  Ok(segments)
}

///|
fn whisper_cpp_segment_confidence(
  payload : Map[String, @djson.JsonValue],
) -> Double? {
  let direct = json_double_optional(payload, "confidence")
  if direct is Some(_) {
    return direct
  }
  let tokens = match payload.get("tokens") {
    Some(@djson.JsonValue::Array(items)) => items
    _ => return None
  }
  let mut total = 0.0
  let mut count = 0
  for item in tokens {
    let object = match item {
      @djson.JsonValue::Object(entries) => json_object_from_members(entries)
      _ => continue
    }
    match json_double_optional(object, "p") {
      Some(value) => {
        total += value
        count += 1
      }
      None => ()
    }
  }
  if count == 0 {
    None
  } else {
    Some(total / count.to_double())
  }
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
  AUDIO_TMP_ROOT + "/" + base + "_" + @env.now().to_string()
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
