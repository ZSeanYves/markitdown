///|
pub fn audio_transcribe_command_env_var() -> String {
  "MARKITDOWN_AUDIO_TRANSCRIBE_CMD"
}

///|
pub fn audio_backend_transport_name() -> String {
  "command_bridge"
}

///|
pub fn audio_transcribe_install_hint() -> String {
  "Set `" +
  audio_transcribe_command_env_var() +
  "` to an adapter command that accepts `<audio_path> --format <wav|mp3|m4a> [--lang <LANG>]` and prints transcript JSON."
}

///|
pub fn audio_transcribe_not_configured_message() -> String {
  "Audio transcription bridge is not configured on this runtime. Set `" +
  audio_transcribe_command_env_var() +
  "` to an adapter command.\n\n" +
  audio_transcribe_install_hint()
}

///|
pub fn build_audio_transcribe_command(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  language : String?,
) -> Result[(String, Array[String]), AudioTranscribeError] {
  match normalized_env_var(audio_transcribe_command_env_var()) {
    Some(command) =>
      build_audio_transcribe_command_with_adapter(
        source, format, language, command,
      )
    None =>
      Err(
        AudioTranscribeError::NotConfigured(
          audio_transcribe_not_configured_message(),
        ),
      )
  }
}

///|
pub fn build_audio_transcribe_command_with_adapter(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  language : String?,
  adapter_command : String,
) -> Result[(String, Array[String]), AudioTranscribeError] {
  let audio_path = match source.path {
    Some(path) => {
      let trimmed = path.trim().to_owned()
      if trimmed == "" {
        return Err(
          AudioTranscribeError::NotConfigured(
            "audio transcription requires a local file path source",
          ),
        )
      }
      trimmed
    }
    None =>
      return Err(
        AudioTranscribeError::NotConfigured(
          "audio transcription requires a local file path source",
        ),
      )
  }
  let trimmed = adapter_command.trim().to_owned()
  if trimmed == "" {
    return Err(
      AudioTranscribeError::NotConfigured(
        audio_transcribe_not_configured_message(),
      ),
    )
  }
  let parts = trimmed
    .split(" ")
    .to_array()
    .map(part => part.trim().to_owned())
    .filter(part => part != "")
  if parts.length() == 0 {
    return Err(
      AudioTranscribeError::NotConfigured(
        audio_transcribe_not_configured_message(),
      ),
    )
  }
  let argv : Array[String] = []
  argv.append(parts[1:][:])
  argv.push(audio_path)
  argv.push("--format")
  argv.push(@input.detected_format_name(format))
  match language {
    Some(value) => {
      let trimmed_language = value.trim().to_owned()
      if trimmed_language != "" {
        argv.push("--lang")
        argv.push(trimmed_language)
      }
    }
    None => ()
  }
  Ok((parts[0], argv))
}

///|
pub fn run_audio_transcribe_command(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  language : String?,
) -> Result[AudioTranscriptResult, AudioTranscribeError] {
  run_audio_transcribe_command_with_collect(
    source, format, language, collect_audio_transcribe_output,
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
  let plan = match build_audio_transcribe_command(source, format, language) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let delegated = match collect_output(plan.0, plan.1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_audio_transcribe_command_result(delegated)
}

///|
fn finalize_audio_transcribe_command_result(
  delegated : (Int, String, String),
) -> Result[AudioTranscriptResult, AudioTranscribeError] {
  match delegated {
    (0, stdout, _stderr) => parse_audio_transcribe_bridge_payload(stdout)
    (code, stdout, stderr) => {
      let stderr_text = stderr.trim().to_owned()
      let stdout_text = stdout.trim().to_owned()
      let raw_message = if stderr_text != "" {
        stderr_text
      } else if stdout_text != "" {
        stdout_text
      } else {
        "audio adapter exited with code " + code.to_string()
      }
      let lowered = raw_message.to_lower()
      if lowered.contains("command not found") ||
        lowered.contains("not found") ||
        lowered.contains("no such file") {
        Err(
          AudioTranscribeError::CommandUnavailable(
            "Audio adapter command is unavailable on this runtime: " +
            raw_message +
            "\n\n" +
            audio_transcribe_install_hint(),
          ),
        )
      } else {
        Err(
          AudioTranscribeError::ExecutionFailed(
            "Audio adapter command failed on this runtime: " +
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
pub fn parse_audio_transcribe_bridge_payload(
  payload : String,
) -> Result[AudioTranscriptResult, AudioTranscribeError] {
  let trimmed = payload.trim().to_owned()
  if trimmed == "" {
    return Err(
      AudioTranscribeError::EmptyResult(
        "Audio adapter produced an empty payload on this runtime.",
      ),
    )
  }
  let root = @djson.parse_json_document(trimmed) catch {
    err =>
      return Err(
        AudioTranscribeError::OutputParseFailed(
          "Audio adapter emitted invalid JSON on this runtime: " +
          err.to_string(),
        ),
      )
  }
  let root_object = match root.root {
    @djson.JsonValue::Object(entries) => json_object_from_members(entries)
    _ =>
      return Err(
        AudioTranscribeError::OutputParseFailed(
          "Audio adapter payload root must be a JSON object on this runtime.",
        ),
      )
  }
  let provider_name = match json_string_required(root_object, "provider_name") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let metadata = match root_object.get("metadata") {
    Some(@djson.JsonValue::Object(entries)) =>
      audio_metadata_from_object(json_object_from_members(entries))
    _ =>
      return Err(
        AudioTranscribeError::OutputParseFailed(
          "Audio adapter payload must include a `metadata` object on this runtime.",
        ),
      )
  }
  let segments = match root_object.get("segments") {
    Some(@djson.JsonValue::Array(items)) =>
      match audio_segments(items) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    _ =>
      return Err(
        AudioTranscribeError::OutputParseFailed(
          "Audio adapter payload must include a `segments` array on this runtime.",
        ),
      )
  }
  if segments.length() == 0 {
    return Err(
      AudioTranscribeError::EmptyResult(
        "Audio adapter produced zero transcript segments on this runtime.",
      ),
    )
  }
  Ok(
    make_audio_transcript_result(
      provider_name,
      metadata,
      segments,
      provider_version=json_string_optional(root_object, "provider_version"),
      diagnostics=match root_object.get("diagnostics") {
        Some(@djson.JsonValue::Array(items)) => json_string_array(items)
        _ => []
      },
    ),
  )
}

///|
fn audio_metadata_from_object(
  payload : Map[String, @djson.JsonValue],
) -> AudioTranscriptMetadata {
  make_audio_transcript_metadata(
    duration_ms=json_int_optional(payload, "duration_ms"),
    sample_rate_hz=json_int_optional(payload, "sample_rate_hz"),
    channel_count=json_int_optional(payload, "channel_count"),
    codec=json_string_optional(payload, "codec"),
    language=json_string_optional(payload, "language"),
  )
}

///|
fn audio_segments(
  items : Array[@djson.JsonValue],
) -> Result[Array[AudioTranscriptSegment], AudioTranscribeError] {
  let segments : Array[AudioTranscriptSegment] = []
  for item in items {
    let object = match item {
      @djson.JsonValue::Object(entries) => json_object_from_members(entries)
      _ =>
        return Err(
          AudioTranscribeError::OutputParseFailed(
            "Audio adapter segment entries must be JSON objects on this runtime.",
          ),
        )
    }
    let segment = match audio_segment_from_object(object) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    segments.push(segment)
  }
  Ok(segments)
}

///|
fn audio_segment_from_object(
  payload : Map[String, @djson.JsonValue],
) -> Result[AudioTranscriptSegment, AudioTranscribeError] {
  let segment_id = match json_string_required(payload, "segment_id") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let start_ms = match json_int_required(payload, "start_ms") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let end_ms = match json_int_required(payload, "end_ms") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let text = match json_string_required(payload, "text") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(
    make_audio_transcript_segment(
      segment_id,
      start_ms,
      end_ms,
      text,
      speaker=json_string_optional(payload, "speaker"),
      channel=json_int_optional(payload, "channel"),
      confidence=json_double_optional(payload, "confidence"),
      language=json_string_optional(payload, "language"),
    ),
  )
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
          "Audio adapter payload is missing required string field `" +
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
fn json_string_array(items : Array[@djson.JsonValue]) -> Array[String] {
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
                "Audio adapter numeric field `" +
                key +
                "` is not a valid integer on this runtime.",
              ),
            )
        },
      )
    _ =>
      Err(
        AudioTranscribeError::OutputParseFailed(
          "Audio adapter payload is missing required numeric field `" +
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
              "launch audio adapter failed on this runtime: " +
              e.to_string() +
              "\n\n" +
              audio_transcribe_install_hint(),
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
                  "failed to decode audio adapter stdout as UTF-8 on this runtime: " +
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
                  "failed to decode audio adapter stderr as UTF-8 on this runtime: " +
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
          "launch audio adapter failed on this runtime: " +
          e.to_string() +
          "\n\n" +
          audio_transcribe_install_hint(),
        ),
      )
  }
  match collected.val {
    Some(result) => result
    None =>
      Err(
        AudioTranscribeError::ExecutionFailed(
          "launch audio adapter failed on this runtime: event loop returned no result" +
          "\n\n" +
          audio_transcribe_install_hint(),
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
