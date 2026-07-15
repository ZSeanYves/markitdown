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
  match @input.input_path(source) {
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
fn audio_cleanup_temp_dir(path : String) -> Unit {
  ignore(
    try audio_remove_dir_recursive(path) |> Ok catch {
      _ => Err(())
    },
  )
}

///|
fn audio_temp_dir_name(source : @input.InputSource) -> String {
  let raw = match @input.input_path(source) {
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
fn audio_json_quote_string(text : String) -> String {
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
fn audio_json_optional_string(value : String?) -> String {
  match value {
    Some(text) => audio_json_quote_string(text)
    None => "null"
  }
}

///|
fn audio_metric_diagnostic(key : String, value : String) -> String {
  "metric|" + key + "|" + value
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
fn collect_audio_transcribe_output(
  command : @rtcmd.ResolvedCommand,
  args : Array[String],
  command_label : String,
) -> Result[(Int, String, String), AudioTranscribeError] {
  match @rtcmd.run_resolved_command(command, args) {
    Ok(output) => {
      if output.timed_out {
        return Err(
          AudioTranscribeError::ExecutionFailed(
            command_label + " timed out after 300000 ms",
          ),
        )
      }
      if output.stdout_limit_exceeded || output.stderr_limit_exceeded {
        return Err(
          AudioTranscribeError::ExecutionFailed(
            command_label + " output exceeded 8 MiB limit",
          ),
        )
      }
      Ok((output.exit_code, output.stdout, output.stderr))
    }
    Err(message) =>
      Err(
        AudioTranscribeError::ExecutionFailed(
          "launch " +
          command_label +
          " failed on this runtime: " +
          message +
          "\nResolved command: " +
          @rtcmd.resolved_command_context(command),
        ),
      )
  }
}
