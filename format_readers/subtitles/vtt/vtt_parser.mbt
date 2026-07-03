///|
pub type SubtitleCue = @shared.SubtitleCue

///|
pub type SubtitleDocument = @shared.SubtitleDocument

///|
pub type SubtitleFormat = @shared.SubtitleFormat

///|
pub type SubtitleInspectReport = @shared.SubtitleInspectReport

///|
pub fn inspect_subtitle_document(
  doc : SubtitleDocument,
) -> SubtitleInspectReport {
  @shared.inspect_subtitle_document(doc)
}

///|
pub fn parse_vtt_document(text : String) -> SubtitleDocument raise {
  @shared.parse_vtt_document(text)
}
