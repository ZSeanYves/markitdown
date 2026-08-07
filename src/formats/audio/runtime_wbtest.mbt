///|
fn fake_audio_transcript_json(
  requested_language : String,
  result_language? : String = "en",
  text0? : String = "hello",
  text1? : String = "world",
) -> String {
  "{\n" +
  "  \"provider_name\": \"mock_audio\",\n" +
  "  \"provider_version\": \"0.test\",\n" +
  "  \"metadata\": {\n" +
  "    \"duration_ms\": 7200,\n" +
  "    \"sample_rate_hz\": 16000,\n" +
  "    \"channel_count\": 1,\n" +
  "    \"codec\": \"wav\",\n" +
  "    \"language\": \"" +
  result_language +
  "\"\n" +
  "  },\n" +
  "  \"segments\": [\n" +
  "    {\n" +
  "      \"segment_id\": \"seg-1\",\n" +
  "      \"start_ms\": 0,\n" +
  "      \"end_ms\": 3200,\n" +
  "      \"text\": \"" +
  text0 +
  "\",\n" +
  "      \"speaker\": \"speaker-1\",\n" +
  "      \"channel\": 0,\n" +
  "      \"confidence\": 0.98,\n" +
  "      \"language\": \"" +
  requested_language +
  "\"\n" +
  "    },\n" +
  "    {\n" +
  "      \"segment_id\": \"seg-2\",\n" +
  "      \"start_ms\": 3200,\n" +
  "      \"end_ms\": 7200,\n" +
  "      \"text\": \"" +
  text1 +
  "\",\n" +
  "      \"confidence\": 0.97,\n" +
  "      \"language\": \"" +
  requested_language +
  "\"\n" +
  "    }\n" +
  "  ],\n" +
  "  \"diagnostics\": [\"mock=true\", \"metric|audio_backend_wall_ms|11\", \"metric|external_process_invocation_count|1\", \"metric|external_process_kind|audio_backend\"]\n" +
  "}\n"
}

///|
test "audio runtime fails closed on invalid json and empty transcription" {
  match
    parse_audio_transcript_json_payload("not-json", Audio(Wav), Some("eng")) {
    Err(OutputParseFailed(msg)) => assert_true(msg.contains("invalid JSON"))
    _ => fail("expected invalid json failure")
  }

  match
    parse_audio_transcript_json_payload(
      "{\n\"provider_name\":\"mock_audio\",\n\"metadata\":{\"language\":\"en\"},\n\"segments\":[]\n}\n",
      Audio(Wav),
      Some("eng"),
    ) {
    Err(EmptyResult(msg)) =>
      assert_true(msg.contains("zero transcript segments"))
    _ => fail("expected empty transcription failure")
  }
}

///|
test "audio parser lowers transcript into media pipeline document with segment refs" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/audio/contract.m4a",
  )
  let detected = @input.DetectedFormat::Audio(M4a)
  let context = @parser.parse_context_with_audio_options(
    @parser.new_parse_context(detected),
    @parser.explicit_audio_options(language=Some("eng")),
  )
  let parsed = match
    audio_parser_result_with_runtime(source, detected, context, fn(
      _source,
      _format,
      _language,
    ) {
      parse_audio_transcript_json_payload(
        fake_audio_transcript_json("eng", result_language="eng"),
        detected,
        Some("eng"),
      )
    }) {
    Ok(value) => value
    Err(msg) => fail("expected audio parser success: " + msg)
  }
  assert_true(parsed.mode == MediaPipeline)
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_eq(document.blocks[2].text, "Transcript")
  let segment = document.blocks[3]
  let source_ref = segment.source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(source_ref.time_start == Some("00:00:00.000"))
  assert_true(source_ref.time_end == Some("00:00:03.200"))
  assert_true(source_ref.extra.get("audio_segment_id") == Some("seg-1"))
  assert_true(
    parsed.diagnostics.metrics.get("audio_segment_count") == Some("2"),
  )
}

///|
test "audio parser fail closes on malformed timestamps and empty transcript text" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/audio/contract.wav",
  )
  let detected = @input.DetectedFormat::Audio(Wav)
  let context = @parser.new_parse_context(detected)

  match
    audio_parser_result_with_runtime(source, detected, context, fn(
      _source,
      _format,
      _language,
    ) {
      Ok(
        make_audio_transcript_result("mock", make_audio_transcript_metadata(), [
          make_audio_transcript_segment("seg-1", 4000, 1000, "oops"),
        ]),
      )
    }) {
    Err(msg) =>
      assert_true(msg.contains("malformed transcript segment timestamps"))
    Ok(_) => fail("expected malformed timestamps to fail closed")
  }

  match
    audio_parser_result_with_runtime(source, detected, context, fn(
      _source,
      _format,
      _language,
    ) {
      Ok(
        make_audio_transcript_result("mock", make_audio_transcript_metadata(), [
          make_audio_transcript_segment("seg-1", 0, 1000, "   "),
        ]),
      )
    }) {
    Err(msg) => assert_true(msg.contains("empty text only"))
    Ok(_) => fail("expected empty transcript text to fail closed")
  }
}

///|
test "audio transcript JSON ABI covers defaults optional values and validation" {
  let format = @input.DetectedFormat::Audio(Wav)
  let payload =
    #|{
    #|  "metadata": {"language":"auto", "duration_ms":1000, "sample_rate_hz":16000, "channel_count":2},
    #|  "segments": [
    #|    {"start_ms":0, "end_ms":500, "text":"  first  ", "confidence":1, "channel":1},
    #|    {"segment_id":"named", "start_ms":500, "end_ms":1000, "text":"second", "speaker":"Ada", "language":"fr"},
    #|    {"start_ms":1000, "end_ms":1000, "text":"   "}
    #|  ],
    #|  "diagnostics": ["wrapper=true", 7]
    #|}
  let result = parse_audio_transcript_json_payload(
    payload,
    format,
    Some(" eng "),
  ).unwrap()
  assert_eq(result.provider_name, "vosk")
  assert_true(result.provider_version is None)
  assert_true(result.metadata.language == Some("eng"))
  assert_true(
    result.metadata.codec == Some(@input.detected_format_name(format)),
  )
  assert_eq(result.segments.length(), 2)
  assert_eq(result.segments[0].segment_id, "seg-1")
  assert_eq(result.segments[0].text, "first")
  assert_true(result.segments[1].language == Some("fr"))
  assert_true(result.diagnostics.contains("wrapper=true"))
}

///|
test "audio transcript JSON malformed shapes fail closed by taxonomy" {
  let format = @input.DetectedFormat::Audio(Mp3)
  let malformed = [
    "", "[]", "{}", "{\"segments\":{}}", "{\"segments\":[1]}", "{\"segments\":[{}]}",
    "{\"segments\":[{\"text\":1,\"start_ms\":0,\"end_ms\":1}]}", "{\"segments\":[{\"text\":\"x\",\"start_ms\":\"0\",\"end_ms\":1}]}",
    "{\"segments\":[{\"text\":\"x\",\"start_ms\":0,\"end_ms\":\"1\"}]}", "{\"segments\":[{\"text\":\"x\",\"start_ms\":-1,\"end_ms\":1}]}",
    "{\"segments\":[{\"text\":\"x\",\"start_ms\":2,\"end_ms\":1}]}", "{\"segments\":[{\"text\":\"   \",\"start_ms\":0,\"end_ms\":1}]}",
  ]
  for payload in malformed {
    assert_true(
      parse_audio_transcript_json_payload(payload, format, None) is Err(_),
    )
  }
}

///|
test "audio runtime helpers classify process messages paths and request JSON" {
  assert_eq(audio_request_language(None), "auto")
  assert_eq(audio_request_language(Some("  ")), "auto")
  assert_eq(audio_request_language(Some(" eng ")), "eng")
  assert_eq(audio_process_raw_message("fallback", " out ", " err "), "err")
  assert_eq(audio_process_raw_message("fallback", " out ", ""), "out")
  assert_eq(audio_process_raw_message("fallback", "", ""), "fallback")
  for message in ["command not found", "No such file or directory"] {
    assert_true(audio_raw_message_suggests_missing_command(message))
  }
  assert_true(!audio_raw_message_suggests_missing_command("model invalid"))
  assert_true(audio_trimmed_optional(Some(" value ")) == Some("value"))
  assert_true(audio_trimmed_optional(Some("  ")) is None)
  assert_true(audio_trimmed_optional(None) is None)
  assert_eq(
    audio_json_quote_string("a\"b\\c\nd\re\tf"),
    "\"a\\\"b\\\\c\\nd\\re\\tf\"",
  )
  assert_eq(audio_json_optional_string(None), "null")
  assert_eq(audio_json_optional_string(Some("eng")), "\"eng\"")
  assert_eq(audio_metric_diagnostic("key", "value"), "metric|key|value")
  let request = audio_transcribe_request_json(
    {
      input_audio_path: "input.wav",
      normalized_audio_path: Some("normalized.wav"),
      preprocess_invocation_count: 1,
      preprocess_wall_ms: 2UL,
      preprocess_kinds: ["ffmpeg"],
      preprocess_command: None,
    },
    Some("eng"),
    "model-path",
  )
  assert_true(request.contains("\"language\":\"eng\""))
  assert_true(request.contains("\"model_path\":\"model-path\""))
  assert_true(
    audio_local_source_path(@input.input_from_text("bytes")) is Err(_),
  )
  assert_true(
    audio_local_source_path(
      @input.input_from_path("/definitely/missing/audio.wav"),
    )
    is Err(_),
  )
}

///|
test "audio command finalization records resources and classifies process failures" {
  let temp_dir = ".tmp/tests/audio_native/finalize_contract"
  audio_cleanup_temp_dir(temp_dir)
  audio_ensure_dir_tree(temp_dir) catch {
    err => fail("create audio finalize temp dir: " + err.to_string())
  }
  defer audio_cleanup_temp_dir(temp_dir)
  let result_path = temp_dir + "/result.json"
  @fs.write_string_to_file(
    result_path,
    fake_audio_transcript_json("eng"),
    encoding="utf8",
  ) catch {
    err => fail("write audio finalize result: " + err.to_string())
  }
  let backend = @rtcmd.make_resolved_command(
    "mock-audio",
    "mock-audio --json",
    ExplicitArg,
  )
  let ffmpeg = @rtcmd.make_resolved_command(
    "mock-ffmpeg",
    "mock-ffmpeg -i input",
    Path,
  )
  let plan : AudioCommandPlan = {
    backend_command: backend,
    argv: [],
    result_json_path: result_path,
    temp_dir,
    preprocess_invocation_count: 1,
    preprocess_wall_ms: 4UL,
    preprocess_kinds: ["ffmpeg"],
    preprocess_command: Some(ffmpeg),
  }
  let metrics : AudioRuntimeMetrics = {
    external_process_invocation_count: 2,
    external_process_wall_ms: 9UL,
    external_process_kind: "ffmpeg,audio_backend",
    audio_backend_wall_ms: 5UL,
    audio_normalization_used: true,
  }
  let format = @input.DetectedFormat::Audio(Wav)
  let success = finalize_audio_transcribe_command_result(
    (0, "stdout note", "stderr note"),
    plan,
    result_path,
    format,
    Some("eng"),
    metrics,
  ).unwrap()
  assert_true(success.diagnostics.contains("audio_backend_stdout=stdout note"))
  assert_true(success.diagnostics.contains("audio_backend_stderr=stderr note"))
  assert_true(
    success.diagnostics.contains("ffmpeg_command=mock-ffmpeg -i input"),
  )
  assert_true(
    success.diagnostics.contains("metric|audio_normalization_used|true"),
  )
  let missing = finalize_audio_transcribe_command_result(
    (0, "", ""),
    plan,
    temp_dir + "/missing.json",
    format,
    None,
    metrics,
  )
  assert_true(missing is Err(OutputParseFailed(_)))
  assert_true(
    finalize_audio_transcribe_command_result(
      (127, "", "command not found"),
      plan,
      result_path,
      format,
      None,
      metrics,
    )
    is Err(CommandUnavailable(_)),
  )
  assert_true(
    finalize_audio_transcribe_command_result(
      (2, "", "Vosk model directory is unavailable"),
      plan,
      result_path,
      format,
      None,
      metrics,
    )
    is Err(NotConfigured(_)),
  )
  assert_true(
    finalize_audio_transcribe_command_result(
      (3, "decode failed", ""),
      plan,
      result_path,
      format,
      None,
      metrics,
    )
    is Err(ExecutionFailed(_)),
  )
  let derived = audio_runtime_metrics(plan, 6UL)
  assert_eq(derived.external_process_invocation_count, 2)
  assert_eq(derived.external_process_kind, "ffmpeg,audio_backend")
  assert_true(derived.audio_normalization_used)
}

///|
test "audio collector captures real subprocess output and launch failures" {
  let shell = @rtcmd.make_resolved_command("/bin/sh", "/bin/sh", ExplicitArg)
  let collected = collect_audio_transcribe_output(
    shell,
    ["-c", "printf audio-out; printf audio-err >&2; exit 6"],
    "audio contract",
  ).unwrap()
  assert_eq(collected.0, 6)
  assert_eq(collected.1, "audio-out")
  assert_eq(collected.2, "audio-err")
  assert_true(
    collect_audio_transcribe_output(
      @rtcmd.fallback_command("/definitely/missing/audio-wrapper"),
      [],
      "audio contract",
    )
    is Err(ExecutionFailed(_)),
  )
}

///|
test "audio command plan validates model and executes controlled WAV runtime" {
  let root = ".tmp/tests/audio_native/command-plan-contract"
  audio_cleanup_temp_dir(root)
  audio_ensure_dir_tree(root + "/model") catch {
    err => fail("create audio model fixture: " + err.to_string())
  }
  defer audio_cleanup_temp_dir(root)
  let previous_model = @env.get_env_var(audio_model_path_env_var())
  let previous_command = @env.get_env_var(audio_command_env_var())
  @env.set_env_var(audio_model_path_env_var(), root + "/model")
  @env.set_env_var(audio_command_env_var(), "/bin/sh")
  defer {
    match previous_model {
      Some(value) => @env.set_env_var(audio_model_path_env_var(), value)
      None => @env.unset_env_var(audio_model_path_env_var())
    }
    match previous_command {
      Some(value) => @env.set_env_var(audio_command_env_var(), value)
      None => @env.unset_env_var(audio_command_env_var())
    }
  }
  assert_eq(audio_validate_model_path().unwrap(), root + "/model")
  let wav = audio_prepare_input_for_backend(
    "samples/fixtures/contracts/audio/contract.wav",
    Wav,
    root + "/wav",
  ).unwrap()
  assert_true(wav.normalized_audio_path is None)
  assert_eq(wav.preprocess_invocation_count, 0)
  let mp3 = audio_prepare_input_for_backend(
    "samples/fixtures/contracts/audio/contract.mp3",
    Mp3,
    root + "/mp3",
  ).unwrap()
  assert_true(mp3.normalized_audio_path is None)
  let source = @input.input_from_path(
    "samples/fixtures/contracts/audio/contract.wav",
  )
  let command = build_audio_transcribe_command(source, Audio(Wav), Some("eng")).unwrap()
  assert_true(command.1.contains("--request-json"))
  match run_audio_transcribe_command(source, Audio(Wav), Some("eng")) {
    Ok(result) => assert_true(result.segments.length() > 0)
    Err(error) => assert_true(error.to_string() != "")
  }
  assert_true(
    build_audio_transcribe_command(source, Pdf, None) is Err(ExecutionFailed(_)),
  )
  assert_true(
    build_audio_transcribe_command(
      @input.input_from_text("audio"),
      Audio(Wav),
      None,
    )
    is Err(ExecutionFailed(_)),
  )
}
