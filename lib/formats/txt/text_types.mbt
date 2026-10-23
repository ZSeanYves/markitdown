///|
/// Hard failures for byte-to-text decoding.
pub(all) suberror TextError {
  Utf8DecodeFailed(String)
}

///|
pub(all) enum TextNewlineStyle {
  None
  LF
  CRLF
  CR
  Mixed
} derive(Eq)

///|
pub extend TextNewlineStyle with Eq::{equal, not_equal}

///|
/// Source-native line inventory for parsed text.
pub struct TextLine {
  text : String
  line_no : Int32
}

///|
/// Paragraph spans reconstructed from blank-line-separated text.
pub struct TextParagraph {
  text : String
  line_start : Int32
  line_end : Int32
}

///|
/// Parsed plain-text document with normalized newlines.
pub struct TextDocument {
  text : String
  byte_count : Int32?
  newline_style : TextNewlineStyle
  lines : Array[TextLine]
  paragraphs : Array[TextParagraph]
}

///|
pub(all) enum TextErrorKind {
  Utf8DecodeFailed
  Unknown
} derive(Eq)

///|
pub extend TextErrorKind with Eq::{equal, not_equal}

///|
/// Stable classification for hard text decoding failures.
pub struct TextErrorInfo {
  kind : TextErrorKind
  detail : String
}

///|
/// Structural summary for a parsed text document.
pub struct TextInspectReport {
  byte_count : Int32?
  char_count : Int32
  line_count : Int32
  paragraph_count : Int32
  empty_line_count : Int32
  newline_style : TextNewlineStyle
  is_empty : Bool
  is_low_signal : Bool
}

///|
pub impl Show for TextError with fn to_string(self : TextError) -> String {
  match self {
    Utf8DecodeFailed(msg) => "text decode failed: " + msg
  }
}

///|
pub impl Show for TextError with fn output(self : TextError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
