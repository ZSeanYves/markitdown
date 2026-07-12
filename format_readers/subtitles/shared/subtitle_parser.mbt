///|
pub fn parse_srt_document(text : String) -> SubtitleDocument raise {
  if text.contains("\u{0000}") {
    fail("subtitle input contains NUL bytes")
  }
  parse_subtitle_document(text, SubtitleFormat::Srt)
}

///|
pub fn parse_vtt_document(text : String) -> SubtitleDocument raise {
  if text.contains("\u{0000}") {
    fail("subtitle input contains NUL bytes")
  }
  parse_subtitle_document(text, SubtitleFormat::Vtt)
}

///|
pub fn inspect_subtitle_document(
  doc : SubtitleDocument,
) -> SubtitleInspectReport {
  let mut note_count = 0
  let mut style_count = 0
  let mut region_count = 0
  let mut multiline_cue_count = 0
  let mut blank_line_count = 0
  let mut char_count = 0
  let mut max_lines_per_cue = 0
  for cue in doc.cues {
    if cue.note_kind is Some(_) {
      note_count += 1
      match cue.note_kind.unwrap_or("") {
        "style" => style_count += 1
        "region" => region_count += 1
        _ => ()
      }
    }
    if cue.text_lines.length() > 1 {
      multiline_cue_count += 1
    }
    if cue.text_lines.length() > max_lines_per_cue {
      max_lines_per_cue = cue.text_lines.length()
    }
    for line in cue.text_lines {
      if line.trim() == "" {
        blank_line_count += 1
      }
      char_count += line.length()
    }
  }
  {
    cue_count: doc.cues.length(),
    note_count,
    style_count,
    region_count,
    multiline_cue_count,
    blank_line_count,
    char_count,
    max_lines_per_cue,
  }
}

///|
fn parse_subtitle_document(
  text : String,
  format : SubtitleFormat,
) -> SubtitleDocument {
  let normalized = strip_bom(normalize_subtitle_text(text))
  let cues : Array[SubtitleCue] = []
  let lines = normalized.split("\n").to_array().map(line => line.to_owned())
  let mut i = 0
  let has_webvtt_header = format == SubtitleFormat::Vtt &&
    lines.length() > 0 &&
    strip_bom(lines[0]).trim().has_prefix("WEBVTT")
  if has_webvtt_header {
    i = 1
  }
  let mut cue_index = 0
  while i < lines.length() {
    while i < lines.length() && lines[i].trim() == "" {
      i += 1
    }
    if i >= lines.length() {
      break
    }
    let block_start = i + 1
    let first = lines[i]
    let trimmed_first = first.trim().to_owned()
    if format == SubtitleFormat::Vtt && is_vtt_note_header(trimmed_first) {
      let payload : Array[String] = []
      i += 1
      while i < lines.length() && lines[i].trim() != "" {
        payload.push(lines[i])
        i += 1
      }
      cue_index += 1
      cues.push({
        index: cue_index - 1,
        identifier: None,
        time_range: "",
        time_start: None,
        time_end: None,
        text_lines: [],
        note_kind: Some("note"),
        note_payload: Some(payload.join("\n")),
        cue_settings: None,
        line_start: block_start,
        line_end: i,
      })
      continue
    }
    if format == SubtitleFormat::Vtt && trimmed_first == "STYLE" {
      let payload : Array[String] = []
      i += 1
      while i < lines.length() && lines[i].trim() != "" {
        payload.push(lines[i])
        i += 1
      }
      cue_index += 1
      cues.push({
        index: cue_index - 1,
        identifier: None,
        time_range: "",
        time_start: None,
        time_end: None,
        text_lines: [],
        note_kind: Some("style"),
        note_payload: Some(payload.join("\n")),
        cue_settings: None,
        line_start: block_start,
        line_end: i,
      })
      continue
    }
    if format == SubtitleFormat::Vtt && trimmed_first == "REGION" {
      let payload : Array[String] = []
      i += 1
      while i < lines.length() && lines[i].trim() != "" {
        payload.push(lines[i])
        i += 1
      }
      cue_index += 1
      cues.push({
        index: cue_index - 1,
        identifier: None,
        time_range: "",
        time_start: None,
        time_end: None,
        text_lines: [],
        note_kind: Some("region"),
        note_payload: Some(payload.join("\n")),
        cue_settings: None,
        line_start: block_start,
        line_end: i,
      })
      continue
    }
    let mut identifier : String? = None
    let mut time_line = trimmed_first
    if !time_line.contains(" --> ") {
      identifier = Some(trimmed_first)
      i += 1
      if i >= lines.length() {
        cues.push(invalid_subtitle_block(cue_index, block_start, i, [first]))
        cue_index += 1
        continue
      }
      time_line = lines[i].trim().to_owned()
    }
    if !time_line.contains(" --> ") {
      let payload : Array[String] = [first]
      while i < lines.length() && lines[i].trim() != "" {
        payload.push(lines[i])
        i += 1
      }
      cues.push(invalid_subtitle_block(cue_index, block_start, i, payload))
      cue_index += 1
      continue
    }
    let (normalized_time_range, cue_settings, time_start, time_end) = split_time_range_and_settings(
      time_line,
    )
    i += 1
    let text_lines : Array[String] = []
    while i < lines.length() && lines[i].trim() != "" {
      text_lines.push(lines[i])
      i += 1
    }
    cue_index += 1
    cues.push({
      index: cue_index - 1,
      identifier,
      time_range: normalized_time_range,
      time_start,
      time_end,
      text_lines,
      note_kind: None,
      note_payload: None,
      cue_settings,
      line_start: block_start,
      line_end: i,
    })
  }
  { format, cues }
}

///|
fn invalid_subtitle_block(
  cue_index : Int,
  line_start : Int,
  line_end : Int,
  payload : Array[String],
) -> SubtitleCue {
  {
    index: cue_index,
    identifier: None,
    time_range: "",
    time_start: None,
    time_end: None,
    text_lines: [],
    note_kind: Some("invalid"),
    note_payload: Some(payload.join("\n")),
    cue_settings: None,
    line_start,
    line_end,
  }
}

///|
fn normalize_subtitle_text(text : String) -> String {
  if !text.contains("\r") {
    return text
  }
  text.replace_all(old="\r\n", new="\n").replace_all(old="\r", new="\n")
}

///|
fn strip_bom(text : String) -> String {
  if text.has_prefix("\u{FEFF}") {
    text[1:].to_owned()
  } else {
    text
  }
}

///|
fn is_vtt_note_header(text : String) -> Bool {
  text == "NOTE" || text.has_prefix("NOTE ")
}

///|
fn split_time_range_and_settings(
  time_line : String,
) -> (String, String?, String?, String?) {
  let marker = " --> "
  let parts = time_line.split(marker).to_array()
  if parts.length() != 2 {
    return (time_line, None, None, None)
  }
  let left = parts[0].trim().to_owned()
  let right_trimmed = parts[1].trim().to_owned()
  if !right_trimmed.contains(" ") {
    return (
      left + marker + right_trimmed,
      None,
      Some(left),
      Some(right_trimmed),
    )
  }
  let right_parts = right_trimmed
    .split(" ")
    .to_array()
    .filter(part => part != "")
  if right_parts.length() <= 1 {
    return (
      left + marker + right_trimmed,
      None,
      Some(left),
      Some(right_trimmed),
    )
  }
  let end_time = right_parts[0].to_owned()
  let settings = right_parts[1:].join(" ")
  (left + marker + end_time, Some(settings), Some(left), Some(end_time))
}
