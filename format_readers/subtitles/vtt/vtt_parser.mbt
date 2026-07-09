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

///|
pub fn prepare_vtt_document_from_source(
  source : @input.InputSource,
) -> Result[@shared.PreparedSubtitleDocument, String] {
  @shared.prepare_vtt_document_from_source(source)
}
