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
    parse_audio_transcript_json_payload(
      "not-json",
      @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
      Some("eng"),
    ) {
    Err(AudioTranscribeError::OutputParseFailed(msg)) =>
      assert_true(msg.contains("invalid JSON"))
    _ => fail("expected invalid json failure")
  }

  match
    parse_audio_transcript_json_payload(
      "{\n\"provider_name\":\"mock_audio\",\n\"metadata\":{\"language\":\"en\"},\n\"segments\":[]\n}\n",
      @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
      Some("eng"),
    ) {
    Err(AudioTranscribeError::EmptyResult(msg)) =>
      assert_true(msg.contains("zero transcript segments"))
    _ => fail("expected empty transcription failure")
  }
}

///|
test "audio parser lowers transcript into media pipeline document with segment refs" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/audio/contract.m4a",
  )
  let detected = @input.DetectedFormat::Audio(@input.AudioFormat::M4a)
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
  assert_true(parsed.mode == @parser.ParserMode::MediaPipeline)
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
