///|
fn test_tmp_root() -> String {
  ".tmp/tests/audio_runtime"
}

///|
fn remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }
  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }
  @fs.remove_dir(path)
}

///|
fn recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    remove_dir_recursive(path)
  }
  ensure_dir_tree(path)
}

///|
fn cleanup_temp_dir(path : String) -> Unit {
  ignore(
    try remove_dir_recursive(path) |> Ok catch {
      _ => Err(())
    },
  )
}

///|
fn ensure_dir_tree(path : String) -> Unit raise {
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
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @fs.write_string_to_file(path, text, encoding="utf8") catch {
    e => fail("write failed: " + e.to_string())
  }
}

///|
fn make_fake_model(path : String) -> Unit raise {
  ensure_dir_tree(path)
  write_utf8_text(path + "/README", "fake vosk model\n")
}

///|
fn with_env_var(
  name : String,
  value : String,
  body : () -> Unit raise,
) -> Unit raise {
  let previous = @env.get_env_var(name)
  @env.set_env_var(name, value)
  defer (match previous {
    Some(old) => @env.set_env_var(name, old)
    None => @env.unset_env_var(name)
  })
  body()
}

///|
fn with_unset_env_var(name : String, body : () -> Unit raise) -> Unit raise {
  let previous = @env.get_env_var(name)
  @env.unset_env_var(name)
  defer (match previous {
    Some(old) => @env.set_env_var(name, old)
    None => ()
  })
  body()
}

///|
fn fake_audio_transcript_json(
  requested_language : String,
  result_language? : String = "en",
  text0? : String = "hello",
  text1? : String = "world",
) -> String {
  "{\n" +
  "  \"provider_name\": \"vosk\",\n" +
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
  "  \"diagnostics\": [\"mock=true\"]\n" +
  "}\n"
}

///|
fn with_audio_model_env(path : String, body : () -> Unit raise) -> Unit raise {
  @env.set_env_var(audio_model_path_env_var(), path)
  defer @env.unset_env_var(audio_model_path_env_var())
  body()
}

///|
test "audio runtime default backend identity stays native vosk" {
  assert_eq(audio_backend_transport_name(), "native_cli")
  assert_eq(audio_backend_name(), "vosk")
  assert_eq(audio_command_env_var(), "MARKITDOWN_AUDIO_CMD")
  assert_eq(audio_model_path_env_var(), "MARKITDOWN_AUDIO_MODEL_PATH")
}

///|
test "audio runtime command builder defaults to official wrapper and model dir" {
  let root = test_tmp_root() + "/command_builder"
  recreate_clean_dir(root) catch {
    e => fail(e.to_string())
  }
  defer cleanup_temp_dir(root)
  let fake_model = root + "/model"
  make_fake_model(fake_model) catch {
    e => fail(e.to_string())
  }
  let fake_audio = root + "/sample.wav"
  write_utf8_text(fake_audio, "RIFFfakeWAVE") catch {
    e => fail(e.to_string())
  }
  let mock_bin = root + "/bin"
  recreate_clean_dir(mock_bin) catch {
    e => fail(e.to_string())
  }
  let old_path = @env.get_env_var("PATH").unwrap_or("")
  with_env_var("PATH", mock_bin + ":" + old_path, fn() raise {
    with_unset_env_var(audio_command_env_var(), fn() raise {
      with_audio_model_env(fake_model, fn() raise {
        let built = match
          build_audio_transcribe_command(
            @input.input_from_path(fake_audio),
            @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
            Some("zh"),
          ) {
          Ok(value) => value
          Err(err) => fail("expected audio command plan: " + err.to_string())
        }
        assert_eq(built.0, "python3")
        assert_true(built.1[0] == "samples/helpers/audio_transcribe_wrapper.py")
        assert_eq(built.1[1], fake_audio)
        assert_true(built.1[2].contains("transcript.json"))
        assert_true(built.1.contains("--lang"))
        assert_true(built.1.contains("zh"))
        assert_true(!built.1.contains("-m"))
        assert_true(!built.1.contains("-l"))
      })
    })
  })
}

///|
test "audio runtime wrapper command path stays stable and shell-parseable" {
  let root = test_tmp_root() + "/wrapper_builder"
  recreate_clean_dir(root) catch {
    e => fail(e.to_string())
  }
  defer cleanup_temp_dir(root)
  let fake_audio = root + "/sample.wav"
  write_utf8_text(fake_audio, "RIFFfakeWAVE") catch {
    e => fail(e.to_string())
  }
  let wrapper = "python3 samples/helpers/audio_transcribe_wrapper.py"
  with_env_var(audio_command_env_var(), wrapper, fn() raise {
    let built = match
      build_audio_transcribe_command(
        @input.input_from_path(fake_audio),
        @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
        Some("zh"),
      ) {
      Ok(value) => value
      Err(err) =>
        fail("expected wrapper audio command plan: " + err.to_string())
    }
    assert_eq(built.0, "python3")
    assert_true(built.1[0] == "samples/helpers/audio_transcribe_wrapper.py")
    assert_true(built.1.contains(fake_audio))
    assert_true(built.1.contains("--lang"))
    assert_true(built.1.contains("zh"))
    assert_true(!built.1.contains("-m"))
    assert_true(!built.1.contains("-l"))
  })
}

///|
test "audio runtime wrapper command parse failure stays fail closed" {
  with_env_var(audio_command_env_var(), "\"unterminated", fn() raise {
    match
      build_audio_transcribe_command(
        @input.input_from_path("samples/fixtures/contracts/audio/contract.wav"),
        @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
        Some("eng"),
      ) {
      Err(AudioTranscribeError::NotConfigured(msg)) =>
        assert_true(msg.contains("MARKITDOWN_AUDIO_CMD"))
      _ => fail("expected wrapper parse failure")
    }
  })
}

///|
test "audio runtime command builder defaults language to auto" {
  let root = test_tmp_root() + "/auto_lang"
  recreate_clean_dir(root) catch {
    e => fail(e.to_string())
  }
  defer cleanup_temp_dir(root)
  let fake_model = root + "/model"
  make_fake_model(fake_model) catch {
    e => fail(e.to_string())
  }
  let fake_audio = root + "/sample.mp3"
  write_utf8_text(fake_audio, "ID3fakeaudio") catch {
    e => fail(e.to_string())
  }
  let mock_bin = root + "/bin"
  recreate_clean_dir(mock_bin) catch {
    e => fail(e.to_string())
  }
  let old_path = @env.get_env_var("PATH").unwrap_or("")
  with_env_var("PATH", mock_bin + ":" + old_path, fn() raise {
    with_unset_env_var(audio_command_env_var(), fn() raise {
      with_audio_model_env(fake_model, fn() raise {
        let built = match
          build_audio_transcribe_command(
            @input.input_from_path(fake_audio),
            @input.DetectedFormat::Audio(@input.AudioFormat::Mp3),
            None,
          ) {
          Ok(value) => value
          Err(err) =>
            fail("expected auto language command plan: " + err.to_string())
        }
        assert_true(built.0 == "python3")
        assert_true(built.1.contains("--lang"))
        assert_true(built.1.contains("auto"))
      })
    })
  })
}

///|
test "audio runtime fails closed when model path is missing" {
  @env.set_env_var(
    audio_model_path_env_var(),
    ".tmp/tests/audio_runtime/missing-model/not-installed",
  )
  defer @env.unset_env_var(audio_model_path_env_var())
  let root = test_tmp_root() + "/missing-model"
  recreate_clean_dir(root) catch {
    e => fail(e.to_string())
  }
  defer cleanup_temp_dir(root)
  let mock_bin = root + "/bin"
  recreate_clean_dir(mock_bin) catch {
    e => fail(e.to_string())
  }
  let old_path = @env.get_env_var("PATH").unwrap_or("")
  with_env_var("PATH", mock_bin + ":" + old_path, fn() raise {
    with_unset_env_var(audio_command_env_var(), fn() raise {
      match
        build_audio_transcribe_command(
          @input.input_from_path(
            "samples/fixtures/contracts/audio/contract.wav",
          ),
          @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
          Some("eng"),
        ) {
        Err(AudioTranscribeError::NotConfigured(msg)) =>
          assert_true(msg.contains("Vosk model directory is not available"))
        _ => fail("expected missing model failure")
      }
    })
  })
}

///|
test "audio runtime parses transcript json into result" {
  let parsed = match
    parse_audio_transcript_json_payload(
      fake_audio_transcript_json(
        "zh",
        result_language="zh",
        text0="ni hao",
        text1="shi jie",
      ),
      @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
      Some("zh"),
    ) {
    Ok(value) => value
    Err(err) => fail("expected transcript json success: " + err.to_string())
  }
  assert_eq(parsed.provider_name, "vosk")
  assert_true(parsed.provider_version == Some("0.test"))
  assert_true(parsed.metadata.codec == Some("wav"))
  assert_true(parsed.metadata.language == Some("zh"))
  assert_true(parsed.metadata.duration_ms == Some(7200))
  assert_eq(parsed.segments.length(), 2)
  assert_eq(parsed.segments[0].segment_id, "seg-1")
  assert_eq(parsed.segments[0].start_ms, 0)
  assert_eq(parsed.segments[0].end_ms, 3200)
  assert_true(parsed.segments[0].speaker == Some("speaker-1"))
  assert_true(parsed.segments[0].channel == Some(0))
  assert_true(parsed.segments[0].confidence is Some(_))
}

///|
test "audio runtime collect path keeps fail closed taxonomy" {
  let root = test_tmp_root() + "/taxonomy"
  recreate_clean_dir(root) catch {
    e => fail(e.to_string())
  }
  defer cleanup_temp_dir(root)
  let fake_model = root + "/model"
  make_fake_model(fake_model) catch {
    e => fail(e.to_string())
  }
  let fake_audio = root + "/sample.mp3"
  write_utf8_text(fake_audio, "ID3fakeaudio") catch {
    e => fail(e.to_string())
  }
  let source = @input.input_from_path(fake_audio)
  let format = @input.DetectedFormat::Audio(@input.AudioFormat::Mp3)
  with_audio_model_env(fake_model, fn() raise {
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
  })
}

///|
test "audio runtime classifies missing model dir and ffmpeg dependency" {
  let root = test_tmp_root() + "/taxonomy_deps"
  recreate_clean_dir(root) catch {
    e => fail(e.to_string())
  }
  defer cleanup_temp_dir(root)
  let fake_model = root + "/model"
  make_fake_model(fake_model) catch {
    e => fail(e.to_string())
  }
  let fake_audio = root + "/sample.mp3"
  write_utf8_text(fake_audio, "ID3fakeaudio") catch {
    e => fail(e.to_string())
  }
  let source = @input.input_from_path(fake_audio)
  let format = @input.DetectedFormat::Audio(@input.AudioFormat::Mp3)
  with_audio_model_env(fake_model, fn() raise {
    match
      run_audio_transcribe_command_with_collect(source, format, Some("eng"), fn(
        _cmd,
        _args,
      ) {
        Ok((4, "", "Vosk model directory is unavailable"))
      }) {
      Err(AudioTranscribeError::NotConfigured(msg)) =>
        assert_true(msg.contains("not fully configured"))
      _ => fail("expected missing model taxonomy")
    }

    match
      run_audio_transcribe_command_with_collect(source, format, Some("eng"), fn(
        _cmd,
        _args,
      ) {
        Ok((5, "", "ffmpeg is required to normalize compressed audio"))
      }) {
      Err(AudioTranscribeError::CommandUnavailable(msg)) =>
        assert_true(msg.contains("ffmpeg"))
      _ => fail("expected ffmpeg taxonomy")
    }
  })
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
      "{\n\"provider_name\":\"vosk\",\n\"metadata\":{\"language\":\"en\"},\n\"segments\":[]\n}\n",
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
    Some("native_cli"),
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
