///|
test "subtitle reader parses vtt note style region and cue settings" {
  let doc = @vtt.parse_vtt_document(
    "\u{FEFF}WEBVTT Example\r\n\r\n" +
    "NOTE metadata\r\n" +
    "keep note\r\n\r\n" +
    "STYLE\r\n" +
    "::cue { color: lime; }\r\n\r\n" +
    "REGION\r\n" +
    "id:main\r\n" +
    "lines:3\r\n\r\n" +
    "intro\r\n" +
    "00:00:00.000 --> 00:00:01.500 align:start position:10%\r\n" +
    "Hello VTT.\r\n",
  )
  let report = @vtt.inspect_subtitle_document(doc)
  assert_eq(doc.cues.length(), 4)
  assert_eq(doc.cues[0].note_kind.unwrap_or(""), "note")
  assert_eq(doc.cues[1].note_kind.unwrap_or(""), "style")
  assert_eq(doc.cues[2].note_kind.unwrap_or(""), "region")
  assert_eq(doc.cues[3].identifier.unwrap_or(""), "intro")
  assert_eq(doc.cues[3].cue_settings.unwrap_or(""), "align:start position:10%")
  assert_eq(doc.cues[3].time_range, "00:00:00.000 --> 00:00:01.500")
  assert_eq(report.note_count, 3)
  assert_eq(report.style_count, 1)
  assert_eq(report.region_count, 1)
}
