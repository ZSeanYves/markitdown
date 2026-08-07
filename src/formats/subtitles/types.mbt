///|
pub(all) enum SubtitleFormat {
  Srt
  Vtt
} derive(Eq)

///|
pub struct SubtitleCue {
  index : Int
  identifier : String?
  time_range : String
  time_start : String?
  time_end : String?
  text_lines : Array[String]
  note_kind : String?
  note_payload : String?
  cue_settings : String?
  line_start : Int
  line_end : Int
}

///|
pub struct SubtitleDocument {
  format : SubtitleFormat
  cues : Array[SubtitleCue]
}

///|
pub struct SubtitleInspectReport {
  cue_count : Int
  note_count : Int
  style_count : Int
  region_count : Int
  multiline_cue_count : Int
  blank_line_count : Int
  char_count : Int
  max_lines_per_cue : Int
}
