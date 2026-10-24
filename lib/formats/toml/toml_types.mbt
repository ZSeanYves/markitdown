///|
/// Hard parse failures for the TOML parser.
pub(all) suberror TomlError {
  ParseError(String)
}

///|
/// Source-native TOML values.
pub(all) enum TomlValue {
  Table(Array[TomlMember])
  Array(Array[TomlValue])
  String(String)
  Integer(String)
  Float(String)
  Bool(Bool)
  Datetime(String)
  InlineTable(Array[TomlMember])
}

///|
pub struct TomlMember {
  key : String
  segments : Array[String]
  path : String
  value : TomlValue
  line_start : Int32
  line_end : Int32
}

///|
pub struct TomlTable {
  path : String
  segments : Array[String]
  members : Array[TomlMember]
  line_start : Int32
  mut line_end : Int32
  is_array_item : Bool
}

///|
/// A parsed TOML document rooted at one configuration document.
pub struct TomlDocument {
  root_members : Array[TomlMember]
  tables : Array[TomlTable]
}

///|
pub(all) enum TomlErrorKind {
  UnexpectedEnd
  TrailingContent
  ExpectedToken
  InvalidHeader
  InvalidKey
  DuplicateKey
  InvalidString
  InvalidEscape
  InvalidValue
  UnsupportedFeature
  Unknown
} derive(Eq)

///|
pub extend TomlErrorKind with Eq::{equal, not_equal}

///|
/// Stable classification for hard TOML parse failures.
pub struct TomlErrorInfo {
  kind : TomlErrorKind
  detail : String
}

///|
/// Structural summary for a parsed TOML document.
pub struct TomlInspectReport {
  node_count : Int32
  scalar_count : Int32
  array_count : Int32
  table_like_count : Int32
  table_count : Int32
  max_depth : Int32
  root_kind : String
}

///|
pub impl Show for TomlError with fn to_string(self : TomlError) -> String {
  match self {
    ParseError(msg) => "toml parse error: " + msg
  }
}

///|
pub impl Show for TomlError with fn output(self : TomlError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
