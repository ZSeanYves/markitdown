///|
/// Hard parse failures for the JSON parser.
pub(all) suberror JsonError {
  ParseError(String)
}

///|
/// Source-native JSON values.
pub(all) enum JsonValue {
  Object(Array[JsonMember])
  Array(Array[JsonValue])
  String(String)
  Number(String)
  Bool(Bool)
  Null
}

///|
pub struct JsonMember {
  key : String
  value : JsonValue
}

///|
/// A parsed JSON document rooted at a single JSON value.
pub struct JsonDocument {
  root : JsonValue
}

///|
pub(all) enum JsonErrorKind {
  UnexpectedEnd
  TrailingContent
  UnexpectedCharacter
  ObjectKeyMustBeString
  UnterminatedString
  InvalidEscape
  InvalidUnicodeEscape
  InvalidUnicodeSurrogate
  InvalidNumber
  InvalidFraction
  InvalidExponent
  RawNewlineInString
  RawControlCharacterInString
  ExpectedToken
  Unknown
} derive(Eq)

///|
pub extend JsonErrorKind with Eq::{equal, not_equal}

///|
/// Stable classification for hard JSON parse failures.
pub struct JsonErrorInfo {
  kind : JsonErrorKind
  detail : String
}

///|
/// Structural summary for a parsed JSON document.
pub struct JsonInspectReport {
  node_count : Int32
  object_count : Int32
  array_count : Int32
  scalar_count : Int32
  member_count : Int32
  max_depth : Int32
  root_kind : String
}

///|
pub(all) enum JsonStreamEventKind {
  ObjectStart
  ObjectEnd
  ArrayStart
  ArrayEnd
  Key
  StringValue
  NumberValue
  BoolValue
  NullValue
} derive(Eq)

///|
pub extend JsonStreamEventKind with Eq::{equal, not_equal}

///|
/// Positions refer to the parser's BOM-stripped, CR/CRLF-normalized text.
/// byte_start/end are zero-based half-open UTF8 positions in that decoded
/// representation, not raw physical-file, UTF16 or scalar indices.
pub struct JsonStreamSource {
  line : Int32
  column : Int32
  byte_start : Int32
  byte_end : Int32
}

///|
pub struct JsonStreamEvent {
  kind : JsonStreamEventKind
  pointer : String
  depth : Int32
  text : String?
  source : JsonStreamSource
}

///|
pub struct JsonStreamSummary {
  token_count : Int32
  object_count : Int32
  array_count : Int32
  scalar_count : Int32
  max_depth : Int32
  root_kind : String
}

///|
pub struct JsonStreamDocument {
  events : Array[JsonStreamEvent]
  summary : JsonStreamSummary
}

///|
pub impl Show for JsonError with fn to_string(self : JsonError) -> String {
  match self {
    ParseError(msg) => "json parse error: " + msg
  }
}

///|
pub impl Show for JsonError with fn output(self : JsonError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
