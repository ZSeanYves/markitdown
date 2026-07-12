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

///|
test "subtitle reader preserves malformed vtt blocks between valid cues" {
  let doc = @vtt.parse_vtt_document(
    "WEBVTT\n\nbad cue\nwithout timing\n\nok\n00:00:01.000 --> 00:00:02.000\nText\n",
  )
  assert_eq(doc.cues.length(), 2)
  assert_eq(doc.cues[0].note_kind.unwrap_or(""), "invalid")
  assert_eq(doc.cues[1].identifier.unwrap_or(""), "ok")
}

///|
test "vtt reader accepts minimal header and cue without identifier" {
  let doc = @vtt.parse_vtt_document(
    "WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nBody\n",
  )
  assert_eq(doc.cues.length(), 1)
  assert_true(doc.cues[0].identifier is None)
  assert_eq(doc.cues[0].text_lines.length(), 1)
  assert_eq(doc.cues[0].text_lines[0], "Body")
}

///|
test "vtt reader retains vertical line position size and align settings" {
  let doc = @vtt.parse_vtt_document(
    "WEBVTT\n\nsettings\n00:00:00.000 --> 00:00:01.000 vertical:rl line:20% position:30% size:40% align:end\nBody\n",
  )
  let settings = doc.cues[0].cue_settings.unwrap_or("")
  assert_true(settings.contains("vertical:rl"))
  assert_true(settings.contains("line:20%"))
  assert_true(settings.contains("align:end"))
}

///|
test "vtt reader preserves voice class ruby and language tags" {
  let doc = @vtt.parse_vtt_document(
    "WEBVTT\n\n00:00:00.000 --> 00:00:01.000\n<v Ada><c.red>Hello</c> <ruby>漢<rt>kan</rt></ruby> <lang en>world</lang>\n",
  )
  assert_true(doc.cues[0].text_lines[0].contains("<v Ada>"))
  assert_true(doc.cues[0].text_lines[0].contains("<ruby>"))
  assert_true(doc.cues[0].text_lines[0].contains("<lang en>"))
}

///|
test "vtt reader accepts NOTE without payload" {
  let doc = @vtt.parse_vtt_document(
    "WEBVTT\n\nNOTE\n\n00:00:00.000 --> 00:00:01.000\nBody\n",
  )
  assert_eq(doc.cues.length(), 2)
  assert_eq(doc.cues[0].note_kind.unwrap_or(""), "note")
  assert_eq(doc.cues[0].note_payload.unwrap_or(""), "")
}

///|
test "vtt reader accepts BOM CRLF header metadata and multiline cue" {
  let doc = @vtt.parse_vtt_document(
    "\u{FEFF}WEBVTT metadata\r\n\r\nid\r\n00:00:00.000 --> 00:00:02.000\r\nFirst\r\nSecond\r\n",
  )
  assert_eq(doc.cues.length(), 1)
  assert_eq(doc.cues[0].identifier.unwrap_or(""), "id")
  assert_eq(doc.cues[0].text_lines.length(), 2)
}
