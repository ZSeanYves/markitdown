///|
pub(all) suberror JsonError {
  ParseError(String)
}

///|
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
pub struct JsonErrorInfo {
  kind : JsonErrorKind
  detail : String
}

///|
pub struct JsonInspectReport {
  node_count : Int
  object_count : Int
  array_count : Int
  scalar_count : Int
  member_count : Int
  max_depth : Int
  root_kind : String
}

///|
pub impl Show for JsonError with to_string(self : JsonError) -> String {
  match self {
    ParseError(msg) => "json parse error: " + msg
  }
}

///|
pub impl Show for JsonError with output(self : JsonError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
