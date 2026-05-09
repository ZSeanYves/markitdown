///|
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
pub struct TextLine {
  text : String
  line_no : Int
}

///|
pub struct TextParagraph {
  text : String
  line_start : Int
  line_end : Int
}

///|
pub struct TextDocument {
  text : String
  byte_count : Int?
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
pub struct TextErrorInfo {
  kind : TextErrorKind
  detail : String
}

///|
pub struct TextInspectReport {
  byte_count : Int?
  char_count : Int
  line_count : Int
  paragraph_count : Int
  empty_line_count : Int
  newline_style : TextNewlineStyle
  is_empty : Bool
  is_low_signal : Bool
}

///|
pub impl Show for TextError with to_string(self : TextError) -> String {
  match self {
    Utf8DecodeFailed(msg) => "text decode failed: " + msg
  }
}

///|
pub impl Show for TextError with output(self : TextError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
