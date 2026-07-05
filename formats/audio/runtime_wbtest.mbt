///|
fn audio_json_payload(
  format_name : String,
  text0? : String = "hello",
  text1? : String = "world",
) -> String {
  "{\n" +
  "  \"provider_name\": \"mock_audio_bridge\",\n" +
  "  \"provider_version\": \"p0\",\n" +
  "  \"metadata\": {\n" +
  "    \"duration_ms\": 7200,\n" +
  "    \"sample_rate_hz\": 16000,\n" +
  "    \"channel_count\": 1,\n" +
  "    \"codec\": \"" +
  format_name +
  "\",\n" +
  "    \"language\": \"eng\"\n" +
  "  },\n" +
  "  \"segments\": [\n" +
  "    {\n" +
  "      \"segment_id\": \"seg-1\",\n" +
  "      \"start_ms\": 0,\n" +
  "      \"end_ms\": 3200,\n" +
  "      \"text\": \"" +
  text0 +
  "\",\n" +
  "      \"confidence\": 0.98,\n" +
  "      \"language\": \"eng\"\n" +
  "    },\n" +
  "    {\n" +
  "      \"segment_id\": \"seg-2\",\n" +
  "      \"start_ms\": 3200,\n" +
  "      \"end_ms\": 7200,\n" +
  "      \"text\": \"" +
  text1 +
  "\",\n" +
  "      \"confidence\": 0.97,\n" +
  "      \"language\": \"eng\"\n" +
  "    }\n" +
  "  ],\n" +
  "  \"diagnostics\": [\"adapter=mock\"]\n" +
  "}\n"
}

///|
test "audio runtime command builder requires adapter and passes path format language" {
  assert_eq(
    audio_transcribe_command_env_var(),
    "MARKITDOWN_AUDIO_TRANSCRIBE_CMD",
  )
  let source = @input.input_from_path(
    "samples/fixtures/contracts/audio/contract.wav",
  )
  let built = match
    build_audio_transcribe_command_with_adapter(
      source,
      @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
      Some("eng"),
      "adapter --mode transcribe",
    ) {
    Ok(value) => value
    Err(err) =>
      fail("expected adapter-aware audio command plan: " + err.to_string())
  }
  assert_eq(built.0, "adapter")
  assert_true(
    built.1 ==
    [
      "--mode", "transcribe", "samples/fixtures/contracts/audio/contract.wav", "--format",
      "wav", "--lang", "eng",
    ],
  )
}

///|
test "audio runtime command builder reads configured env and fails closed when unset" {
  @env.unset_env_var(audio_transcribe_command_env_var())
  match
    build_audio_transcribe_command(
      @input.input_from_path("samples/fixtures/contracts/audio/contract.wav"),
      @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
      Some("eng"),
    ) {
    Err(AudioTranscribeError::NotConfigured(msg)) =>
      assert_true(msg.contains("MARKITDOWN_AUDIO_TRANSCRIBE_CMD"))
    _ => fail("expected env-missing audio command build failure")
  }

  @env.set_env_var(
    audio_transcribe_command_env_var(),
    "adapter --mode transcribe",
  )
  defer @env.unset_env_var(audio_transcribe_command_env_var())
  let built = match
    build_audio_transcribe_command(
      @input.input_from_path("samples/fixtures/contracts/audio/contract.wav"),
      @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
      Some("eng"),
    ) {
    Ok(value) => value
    Err(err) =>
      fail("expected env-backed audio command plan: " + err.to_string())
  }
  assert_eq(built.0, "adapter")
}

///|
test "audio bridge payload parser lowers json adapter output into transcript result" {
  let parsed = match
    parse_audio_transcribe_bridge_payload(audio_json_payload("wav")) {
    Ok(value) => value
    Err(err) => fail("expected audio payload success: " + err.to_string())
  }
  assert_eq(parsed.provider_name, "mock_audio_bridge")
  assert_true(parsed.provider_version == Some("p0"))
  assert_true(parsed.metadata.duration_ms == Some(7200))
  assert_true(parsed.metadata.sample_rate_hz == Some(16000))
  assert_true(parsed.metadata.channel_count == Some(1))
  assert_true(parsed.metadata.codec == Some("wav"))
  assert_true(parsed.metadata.language == Some("eng"))
  assert_eq(parsed.segments.length(), 2)
  assert_eq(parsed.segments[0].segment_id, "seg-1")
  assert_eq(parsed.segments[0].start_ms, 0)
  assert_eq(parsed.segments[0].end_ms, 3200)
}

///|
test "audio runtime collect path keeps fail closed taxonomy" {
  @env.set_env_var(
    audio_transcribe_command_env_var(),
    "adapter --mode transcribe",
  )
  defer @env.unset_env_var(audio_transcribe_command_env_var())
  let source = @input.input_from_path(
    "samples/fixtures/contracts/audio/contract.mp3",
  )
  let format = @input.DetectedFormat::Audio(@input.AudioFormat::Mp3)
  match
    run_audio_transcribe_command_with_collect(source, format, Some("eng"), fn(
      _cmd,
      _args,
    ) {
      Err(AudioTranscribeError::CommandUnavailable("boom"))
    }) {
    Err(AudioTranscribeError::CommandUnavailable(msg)) =>
      assert_true(msg.contains("boom"))
    _ => fail("expected command unavailable")
  }

  match
    run_audio_transcribe_command_with_collect(source, format, Some("eng"), fn(
      _cmd,
      _args,
    ) {
      Ok((1, "", "failed"))
    }) {
    Err(AudioTranscribeError::ExecutionFailed(msg)) =>
      assert_true(msg.contains("failed"))
    _ => fail("expected execution failed")
  }

  match
    run_audio_transcribe_command_with_collect(source, format, Some("eng"), fn(
      _cmd,
      _args,
    ) {
      Ok((0, "not-json", ""))
    }) {
    Err(AudioTranscribeError::OutputParseFailed(msg)) =>
      assert_true(msg.contains("invalid JSON"))
    _ => fail("expected parse failure")
  }

  match
    run_audio_transcribe_command_with_collect(source, format, Some("eng"), fn(
      _cmd,
      _args,
    ) {
      Ok((0, "{\"provider_name\":\"x\",\"metadata\":{},\"segments\":[]}", ""))
    }) {
    Err(AudioTranscribeError::EmptyResult(msg)) =>
      assert_true(msg.contains("zero transcript segments"))
    _ => fail("expected empty result")
  }
}

///|
test "audio parser lowers transcript into media pipeline document with segment refs" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/audio/contract.m4a",
  )
  let detected = @input.DetectedFormat::Audio(@input.AudioFormat::M4a)
  let context = @parser.parse_context_with_ocr_options(
    @parser.new_parse_context(detected),
    @parser.explicit_ocr_options(language=Some("eng")),
  )
  let parsed = match
    audio_parser_result_with_runtime(source, detected, context, fn(
      _source,
      _format,
      _language,
    ) {
      match parse_audio_transcribe_bridge_payload(audio_json_payload("m4a")) {
        Ok(value) => Ok(value)
        Err(err) =>
          abort("expected audio transcript payload success: " + err.to_string())
      }
    }) {
    Ok(value) => value
    Err(msg) => fail("expected audio parser success: " + msg)
  }
  assert_true(parsed.mode == @parser.ParserMode::MediaPipeline)
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_eq(document.blocks.length(), 5)
  assert_eq(document.blocks[0].text, "contract.m4a")
  assert_eq(document.blocks[2].text, "Transcript")
  assert_true(document.metadata.get("audio_format") is Some(_))
  assert_true(document.metadata.get("audio_backend_name") is Some(_))
  let segment = document.blocks[3]
  assert_true(segment.attrs.get("audio_segment") == Some("true"))
  let source_ref = segment.source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(source_ref.time_start == Some("00:00:00.000"))
  assert_true(source_ref.time_end == Some("00:00:03.200"))
  assert_true(source_ref.extra.get("audio_segment_id") == Some("seg-1"))
  assert_true(source_ref.extra.get("audio_start_ms") == Some("0"))
  assert_true(source_ref.extra.get("audio_end_ms") == Some("3200"))
  assert_true(
    parsed.diagnostics.metrics.get("audio_backend_transport") ==
    Some("command_bridge"),
  )
  assert_true(
    parsed.diagnostics.metrics.get("audio_segment_count") == Some("2"),
  )
}

///|
test "audio parser fail closes on malformed timestamps and empty transcript text" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/audio/contract.wav",
  )
  let detected = @input.DetectedFormat::Audio(@input.AudioFormat::Wav)
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
