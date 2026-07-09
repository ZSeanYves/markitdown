///|
fn test_tmp_root() -> String {
  ".tmp/tests/audio_runtime"
}

///|
#warnings("-deprecated")
fn cleanup_temp_dir(path : String) -> Unit {
  @therm.cleanup_temp_dir(path)
}

///|
fn recreate_clean_dir(path : String) -> Unit raise {
  @therm.recreate_clean_dir(path)
}

///|
fn ensure_dir_tree(path : String) -> Unit raise {
  @therm.ensure_dir_tree(path)
}

///|
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @therm.write_utf8_text(path, text)
}

///|
fn read_utf8_text(path : String) -> String {
  @therm.read_utf8_text(path)
}

///|
fn make_fake_model(path : String) -> Unit raise {
  ensure_dir_tree(path)
  write_utf8_text(path + "/README", "fake vosk model\n")
}

///|
fn audio_wbtest_repo_local_runtime_python_path() -> String {
  @therm.repo_local_runtime_python_path()
}

///|
fn absolute_test_path(path : String) -> String {
  @therm.absolute_test_path(path)
}

///|
fn chmod_plus_x(path : String) -> Unit raise {
  @therm.chmod_plus_x(path)
}

///|
fn with_repo_local_runtime_python_stub(body : () -> Unit raise) -> Unit raise {
  @therm.with_repo_local_runtime_python_stub(body)
}

///|
fn with_repo_local_runtime_python_hidden(body : () -> Unit raise) -> Unit raise {
  @therm.with_repo_local_runtime_python_hidden(body)
}

///|
fn with_managed_command_record(
  name : String,
  value : String?,
  body : () -> Unit raise,
) -> Unit raise {
  @therm.with_managed_command_record(name, value, body)
}

///|
fn with_env_var(
  name : String,
  value : String,
  body : () -> Unit raise,
) -> Unit raise {
  @therm.with_env_var(name, value, body)
}

///|
fn with_unset_env_var(name : String, body : () -> Unit raise) -> Unit raise {
  @therm.with_unset_env_var(name, body)
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
  "  \"diagnostics\": [\"mock=true\", \"metric|audio_backend_wall_ms|11\", \"metric|external_process_invocation_count|1\", \"metric|external_process_kind|audio_backend\"]\n" +
  "}\n"
}

///|
fn with_audio_model_env(path : String, body : () -> Unit raise) -> Unit raise {
  let previous = @env.get_env_var(audio_model_path_env_var())
  @env.set_env_var(audio_model_path_env_var(), path)
  defer (match previous {
    Some(old) => @env.set_env_var(audio_model_path_env_var(), old)
    None => @env.unset_env_var(audio_model_path_env_var())
  })
  body()
}

///|
fn find_arg_value(args : Array[String], flag : String) -> String {
  for i in 0..<args.length() {
    if args[i] == flag && i + 1 < args.length() {
      return args[i + 1]
    }
  }
  abort("missing flag in args: " + flag)
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
  with_repo_local_runtime_python_stub(fn() raise {
    with_unset_env_var("MARKITDOWN_RUNTIME_PYTHON", fn() raise {
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
          assert_eq(built.0, audio_wbtest_repo_local_runtime_python_path())
          assert_true(
            built.1[0] == "samples/env/audio/audio_transcribe_wrapper.py",
          )
          let request_json = read_utf8_text(built.1[2])
          assert_true(
            request_json.contains("\"input_audio_path\":\"" + fake_audio + "\""),
          )
          assert_true(request_json.contains("\"language\":\"zh\""))
          assert_true(
            request_json.contains("\"model_path\":\"" + fake_model + "\""),
          )
        })
      })
    })
  })
}

///|
test "audio runtime repo-managed wrapper beats MARKITDOWN_RUNTIME_PYTHON and MARKITDOWN_AUDIO_CMD" {
  let root = test_tmp_root() + "/runtime_python_override"
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
  let fake_python = root + "/python3"
  write_utf8_text(fake_python, "#!/bin/sh\n") catch {
    e => fail(e.to_string())
  }
  with_repo_local_runtime_python_stub(fn() raise {
    with_env_var("MARKITDOWN_RUNTIME_PYTHON", fake_python, fn() raise {
      with_env_var(audio_command_env_var(), "python3 wrapper.py", fn() raise {
        with_audio_model_env(fake_model, fn() raise {
          let built = match
            build_audio_transcribe_command(
              @input.input_from_path(fake_audio),
              @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
              Some("eng"),
            ) {
            Ok(value) => value
            Err(err) =>
              fail(
                "expected repo-managed audio command plan: " + err.to_string(),
              )
          }
          assert_eq(built.0, audio_wbtest_repo_local_runtime_python_path())
          assert_true(
            built.1[0] == "samples/env/audio/audio_transcribe_wrapper.py",
          )
        })
      })
    })
  })
}

///|
test "audio runtime falls back to MARKITDOWN_RUNTIME_PYTHON when repo-managed runtime is unavailable" {
  let root = test_tmp_root() + "/runtime_python_fallback"
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
  let fake_python = root + "/python3"
  write_utf8_text(fake_python, "#!/bin/sh\nexit 0\n") catch {
    e => fail(e.to_string())
  }
  chmod_plus_x(fake_python) catch {
    e => fail(e.to_string())
  }
  with_repo_local_runtime_python_hidden(fn() raise {
    with_env_var("MARKITDOWN_RUNTIME_PYTHON", fake_python, fn() raise {
      with_unset_env_var(audio_command_env_var(), fn() raise {
        with_audio_model_env(fake_model, fn() raise {
          let built = match
            build_audio_transcribe_command(
              @input.input_from_path(fake_audio),
              @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
              Some("zh"),
            ) {
            Ok(value) => value
            Err(err) =>
              fail("expected runtime python fallback plan: " + err.to_string())
          }
          assert_eq(built.0, fake_python)
          assert_true(
            built.1[0] == "samples/env/audio/audio_transcribe_wrapper.py",
          )
        })
      })
    })
  })
}

///|
test "audio runtime wrapper command parse failure stays fail closed" {
  with_repo_local_runtime_python_hidden(fn() raise {
    with_unset_env_var("MARKITDOWN_RUNTIME_PYTHON", fn() raise {
      with_env_var(audio_command_env_var(), "\"unterminated", fn() raise {
        match
          build_audio_transcribe_command(
            @input.input_from_path(
              "samples/fixtures/contracts/audio/contract.wav",
            ),
            @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
            Some("eng"),
          ) {
          Err(AudioTranscribeError::NotConfigured(msg)) =>
            assert_true(msg.contains("MARKITDOWN_AUDIO_CMD"))
          _ => fail("expected wrapper parse failure")
        }
      })
    })
  })
}

///|
test "audio runtime fails closed when model path is missing" {
  with_repo_local_runtime_python_stub(fn() raise {
    with_unset_env_var(audio_command_env_var(), fn() raise {
      with_env_var(
        audio_model_path_env_var(),
        ".tmp/tests/audio_runtime/missing-model/not-installed",
        fn() raise {
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
        },
      )
    })
  })
}

///|
test "audio runtime no longer falls back to python3 when repo-managed runtime is unavailable" {
  let root = test_tmp_root() + "/no_python3_fallback"
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
  let fake_bin = root + "/bin"
  recreate_clean_dir(fake_bin) catch {
    e => fail(e.to_string())
  }
  let fake_python3 = fake_bin + "/python3"
  write_utf8_text(fake_python3, "#!/bin/sh\nexit 0\n") catch {
    e => fail(e.to_string())
  }
  chmod_plus_x(fake_python3) catch {
    e => fail(e.to_string())
  }
  let old_path = @env.get_env_var("PATH").unwrap_or("")
  with_repo_local_runtime_python_hidden(fn() raise {
    with_env_var("PATH", fake_bin + ":" + old_path, fn() raise {
      with_unset_env_var("MARKITDOWN_RUNTIME_PYTHON", fn() raise {
        with_unset_env_var(audio_command_env_var(), fn() raise {
          with_audio_model_env(fake_model, fn() raise {
            match
              build_audio_transcribe_command(
                @input.input_from_path(fake_audio),
                @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
                Some("eng"),
              ) {
              Err(AudioTranscribeError::NotConfigured(msg)) =>
                assert_true(
                  msg.contains("Audio transcription backend is not available"),
                )
              _ => fail("expected no-python3 fallback failure")
            }
          })
        })
      })
    })
  })
}

///|
test "audio runtime prefers repo-managed ffmpeg record over MARKITDOWN_FFMPEG_BIN" {
  let root = test_tmp_root() + "/ffmpeg_repo_managed"
  recreate_clean_dir(root) catch {
    e => fail(e.to_string())
  }
  defer cleanup_temp_dir(root)
  let fake_model = root + "/model"
  make_fake_model(fake_model) catch {
    e => fail(e.to_string())
  }
  let fake_audio = root + "/sample.m4a"
  write_utf8_text(fake_audio, "fake m4a") catch {
    e => fail(e.to_string())
  }
  let repo_ffmpeg = root + "/repo-ffmpeg"
  write_utf8_text(
    repo_ffmpeg, "#!/bin/sh\n: > \"${10}\"\nprintf 'repo-managed ffmpeg\\n' >&2\n",
  ) catch {
    e => fail(e.to_string())
  }
  chmod_plus_x(repo_ffmpeg) catch {
    e => fail(e.to_string())
  }
  let env_ffmpeg = root + "/env-ffmpeg"
  write_utf8_text(
    env_ffmpeg, "#!/bin/sh\n: > \"${10}\"\nprintf 'env ffmpeg\\n' >&2\n",
  ) catch {
    e => fail(e.to_string())
  }
  chmod_plus_x(env_ffmpeg) catch {
    e => fail(e.to_string())
  }
  with_repo_local_runtime_python_stub(fn() raise {
    with_managed_command_record(
      "ffmpeg",
      Some(absolute_test_path(repo_ffmpeg)),
      fn() raise {
        with_env_var(ffmpeg_command_env_var(), env_ffmpeg, fn() raise {
          with_audio_model_env(fake_model, fn() raise {
            let result = run_audio_transcribe_command_with_collect(
              @input.input_from_path(fake_audio),
              @input.DetectedFormat::Audio(@input.AudioFormat::M4a),
              Some("eng"),
              fn(_cmd, args) {
                let result_json = find_arg_value(args, "--result-json")
                write_utf8_text(result_json, fake_audio_transcript_json("eng")) catch {
                  e =>
                    abort("failed to write transcript result: " + e.to_string())
                }
                Ok((0, "", ""))
              },
            )
            match result {
              Ok(parsed) => {
                assert_true(
                  parsed.diagnostics.contains(
                    "ffmpeg_command_source=repo_managed",
                  ),
                )
                assert_true(
                  parsed.diagnostics.contains(
                    "ffmpeg_command=" + absolute_test_path(repo_ffmpeg),
                  ),
                )
              }
              Err(err) =>
                fail("expected repo-managed ffmpeg success: " + err.to_string())
            }
          })
        })
      },
    )
  })
}

///|
test "audio runtime requires ffmpeg for m4a when no resolver is available" {
  let root = test_tmp_root() + "/missing_ffmpeg"
  recreate_clean_dir(root) catch {
    e => fail(e.to_string())
  }
  defer cleanup_temp_dir(root)
  let fake_model = root + "/model"
  make_fake_model(fake_model) catch {
    e => fail(e.to_string())
  }
  let fake_audio = root + "/sample.m4a"
  write_utf8_text(fake_audio, "fake m4a") catch {
    e => fail(e.to_string())
  }
  let old_path = @env.get_env_var("PATH").unwrap_or("")
  with_repo_local_runtime_python_stub(fn() raise {
    with_managed_command_record("ffmpeg", None, fn() raise {
      with_unset_env_var(ffmpeg_command_env_var(), fn() raise {
        with_env_var("PATH", "", fn() raise {
          with_audio_model_env(fake_model, fn() raise {
            match
              build_audio_transcribe_command(
                @input.input_from_path(fake_audio),
                @input.DetectedFormat::Audio(@input.AudioFormat::M4a),
                Some("eng"),
              ) {
              Err(AudioTranscribeError::CommandUnavailable(msg)) =>
                assert_true(msg.contains("ffmpeg"))
              Err(AudioTranscribeError::ExecutionFailed(msg)) =>
                assert_true(msg.contains("ffmpeg"))
              _ => fail("expected missing ffmpeg failure")
            }
          })
        })
      })
    })
  })
  ignore(old_path)
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
  let fake_audio = root + "/sample.wav"
  write_utf8_text(fake_audio, "RIFFfakeWAVE") catch {
    e => fail(e.to_string())
  }
  let source = @input.input_from_path(fake_audio)
  let format = @input.DetectedFormat::Audio(@input.AudioFormat::Wav)
  with_repo_local_runtime_python_stub(fn() raise {
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
