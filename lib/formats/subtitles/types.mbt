///|
pub(all) enum SubtitleFormat {
  Srt
  Vtt
} derive(Eq)

///|
pub extend SubtitleFormat with Eq::{equal, not_equal}

///|
pub struct SubtitleCue {
  index : Int32
  identifier : String?
  time_range : String
  time_start : String?
  time_end : String?
  text_lines : Array[String]
  note_kind : String?
  note_payload : String?
  cue_settings : String?
  line_start : Int32
  line_end : Int32
}

///|
pub struct SubtitleDocument {
  format : SubtitleFormat
  cues : Array[SubtitleCue]
}

///|
pub struct SubtitleInspectReport {
  cue_count : Int32
  note_count : Int32
  style_count : Int32
  region_count : Int32
  multiline_cue_count : Int32
  blank_line_count : Int32
  char_count : Int32
  max_lines_per_cue : Int32
}
