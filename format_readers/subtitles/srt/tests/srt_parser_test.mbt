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
test "subtitle reader preserves a malformed cue and continues" {
  let doc = @srt.parse_srt_document(
    "1\nHello only\n\n2\n00:00:02,000 --> 00:00:03,000\nRecovered\n",
  )
  assert_eq(doc.cues.length(), 2)
  assert_eq(doc.cues[0].note_kind.unwrap_or(""), "invalid")
  assert_true(doc.cues[0].note_payload.unwrap_or("").contains("Hello only"))
  assert_eq(doc.cues[1].identifier.unwrap_or(""), "2")
}

///|
test "srt reader accepts BOM CRLF and dot timestamps" {
  let doc = @srt.parse_srt_document(
    "\u{FEFF}cue-a\r\n00:00:00.000 --> 00:00:01.250\r\nVisible\r\n",
  )
  assert_eq(doc.cues.length(), 1)
  assert_eq(doc.cues[0].identifier.unwrap_or(""), "cue-a")
  assert_eq(doc.cues[0].time_range, "00:00:00.000 --> 00:00:01.250")
}

///|
test "srt reader accepts cue without identifier" {
  let doc = @srt.parse_srt_document("00:00:01,000 --> 00:00:02,000\nBody\n")
  assert_eq(doc.cues.length(), 1)
  assert_true(doc.cues[0].identifier is None)
  assert_eq(doc.cues[0].text_lines.length(), 1)
  assert_eq(doc.cues[0].text_lines[0], "Body")
}

///|
test "srt reader preserves common inline tags for lowering" {
  let doc = @srt.parse_srt_document(
    "1\n00:00:00,000 --> 00:00:01,000\n<b>bold</b> <i>italic</i> <u>under</u>\n",
  )
  assert_eq(doc.cues[0].text_lines[0], "<b>bold</b> <i>italic</i> <u>under</u>")
}

///|
test "srt reader reports overlapping and reversed cue timing text deterministically" {
  let doc = @srt.parse_srt_document(
    "1\n00:00:02,000 --> 00:00:01,000\nReversed\n\n2\n00:00:01,000 --> 00:00:03,000\nOverlap\n",
  )
  assert_eq(doc.cues.length(), 2)
  assert_true(doc.cues[0].time_range.contains("00:00:02,000"))
  assert_true(doc.cues[1].time_range.contains("00:00:03,000"))
}

///|
test "srt reader keeps empty cue body visible as a cue record" {
  let doc = @srt.parse_srt_document("empty\n00:00:00,000 --> 00:00:01,000\n")
  assert_eq(doc.cues.length(), 1)
  assert_eq(doc.cues[0].identifier.unwrap_or(""), "empty")
  assert_eq(doc.cues[0].text_lines.length(), 0)
}
