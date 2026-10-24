///|
async fn retirement_assert_subtitle_early_close(vtt : Bool) -> Unit {
  let format = if vtt { @input.DetectedFormat::Vtt } else { Srt }
  let text = if vtt {
    "WEBVTT\n\nNOTE note\nretained😀\n\n00:00:01.000 --> 00:00:02.000\nbody\n"
  } else {
    "1\n00:00:01,000 --> 00:00:02,000\nretained😀\n\n2\n00:00:03,000 --> 00:00:04,000\nbody\n"
  }
  let caller = @input.begin_input_session(@input.input_from_text(text))
  defer @input.end_input_session(caller)
  let opened = if vtt {
    open_vtt_event_stream(caller.source, @parser.new_parse_context(format))
  } else {
    open_srt_event_stream(caller.source, @parser.new_parse_context(format))
  }
  let stream = opened.unwrap().unwrap()
  let first = (stream.next)().unwrap().unwrap()
  let retained = first.text
  stream.close().unwrap()
  stream.close().unwrap()
  assert_true((stream.next)() is Ok(None))
  assert_eq(first.text, retained)
  assert_true(first.text.contains("retained😀"))
  assert_false(
    @input.input_source_budget_context(caller.source).unwrap().account.snapshot().closed,
  )
  assert_true(@input.read_input_text(caller.source) is Ok(_))
}

///|
async test "SRT early close retires pending records" {
  retirement_assert_subtitle_early_close(false)
}

///|
async test "VTT early close retires queued end events" {
  retirement_assert_subtitle_early_close(true)
}

///|
async test "SRT and VTT full consumption preserve cue timing order and summary" {
  for vtt in [false, true] {
    let format = if vtt { @input.DetectedFormat::Vtt } else { Srt }
    let text = if vtt {
      "WEBVTT\r\n\r\n00:00:01.000 --> 00:00:02.000\r\none😀\r\n\r\n00:00:03.000 --> 00:00:04.000\r\ntwo"
    } else {
      "1\r\n00:00:01,000 --> 00:00:02,000\r\none😀\r\n\r\n2\r\n00:00:03,000 --> 00:00:04,000\r\ntwo"
    }
    let opened = if vtt {
      open_vtt_event_stream(
        @input.input_from_text(text),
        @parser.new_parse_context(format),
      )
    } else {
      open_srt_event_stream(
        @input.input_from_text(text),
        @parser.new_parse_context(format),
      )
    }
    let stream = opened.unwrap().unwrap()
    defer ignore(stream.close())
    let events : Array[@core.CoreEvent] = []
    while true {
      match (stream.next)().unwrap() {
        Some(event) => events.push(event)
        None => break
      }
    }
    assert_eq(events.length(), 2)
    assert_true(events[0].text.has_suffix("\none😀"))
    assert_true(events[1].text.has_suffix("\ntwo"))
    assert_true(
      events[0].source_ref.unwrap().time_start ==
      Some(if vtt { "00:00:01.000" } else { "00:00:01,000" }),
    )
    assert_true(
      events[1].source_ref.unwrap().time_end ==
      Some(if vtt { "00:00:04.000" } else { "00:00:04,000" }),
    )
    let summary = (stream.finish)().unwrap()
    assert_true(summary.diagnostics.metrics.get("cue_count") == Some("2"))
  }
}
