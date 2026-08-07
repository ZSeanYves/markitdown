///|
pub struct AudioTranscriptMetadata {
  duration_ms : Int?
  sample_rate_hz : Int?
  channel_count : Int?
  codec : String?
  language : String?
}

///|
pub struct AudioTranscriptSegment {
  segment_id : String
  start_ms : Int
  end_ms : Int
  text : String
  speaker : String?
  channel : Int?
  confidence : Double?
  language : String?
}

///|
pub struct AudioTranscriptResult {
  provider_name : String
  provider_version : String?
  metadata : AudioTranscriptMetadata
  segments : Array[AudioTranscriptSegment]
  diagnostics : Array[String]
}

///|
pub(all) enum AudioTranscribeError {
  NotConfigured(String)
  CommandUnavailable(String)
  ExecutionFailed(String)
  OutputParseFailed(String)
  EmptyResult(String)
} derive(Eq)

///|
pub impl Show for AudioTranscribeError with fn to_string(
  self : AudioTranscribeError,
) -> String {
  match self {
    NotConfigured(msg) => msg
    CommandUnavailable(msg) => msg
    ExecutionFailed(msg) => msg
    OutputParseFailed(msg) => msg
    EmptyResult(msg) => msg
  }
}

///|
pub fn make_audio_transcript_metadata(
  duration_ms? : Int? = None,
  sample_rate_hz? : Int? = None,
  channel_count? : Int? = None,
  codec? : String? = None,
  language? : String? = None,
) -> AudioTranscriptMetadata {
  { duration_ms, sample_rate_hz, channel_count, codec, language }
}

///|
pub fn make_audio_transcript_segment(
  segment_id : String,
  start_ms : Int,
  end_ms : Int,
  text : String,
  speaker? : String? = None,
  channel? : Int? = None,
  confidence? : Double? = None,
  language? : String? = None,
) -> AudioTranscriptSegment {
  { segment_id, start_ms, end_ms, text, speaker, channel, confidence, language }
}

///|
pub fn make_audio_transcript_result(
  provider_name : String,
  metadata : AudioTranscriptMetadata,
  segments : Array[AudioTranscriptSegment],
  provider_version? : String? = None,
  diagnostics? : Array[String] = [],
) -> AudioTranscriptResult {
  { provider_name, provider_version, metadata, segments, diagnostics }
}
