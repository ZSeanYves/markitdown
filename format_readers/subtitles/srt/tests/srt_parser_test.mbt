///|
test "subtitle reader parses srt multiline and indexes" {
  let doc = @srt.parse_srt_document(
    "1\n" +
    "00:00:00,000 --> 00:00:02,000\n" +
    "Hello world.\n" +
    "Second line.\n\n" +
    "2\n" +
    "00:00:02,500 --> 00:00:04,000\n" +
    "Final cue.\n",
  )
  let report = @srt.inspect_subtitle_document(doc)
  assert_eq(doc.cues.length(), 2)
  assert_eq(doc.cues[0].identifier.unwrap_or(""), "1")
  assert_eq(doc.cues[0].text_lines.length(), 2)
  assert_eq(doc.cues[1].identifier.unwrap_or(""), "2")
  assert_eq(report.cue_count, 2)
  assert_eq(report.multiline_cue_count, 1)
  assert_true(report.char_count > 0)
}

///|
test "subtitle reader rejects missing time range after identifier" {
  assert_true(
    (try @srt.parse_srt_document("1\nHello only\n") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )
}
