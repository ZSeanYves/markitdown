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
  line_start : Int
  line_end : Int
}

///|
pub struct TomlTable {
  path : String
  segments : Array[String]
  members : Array[TomlMember]
  line_start : Int
  mut line_end : Int
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
/// Stable classification for hard TOML parse failures.
pub struct TomlErrorInfo {
  kind : TomlErrorKind
  detail : String
}

///|
/// Structural summary for a parsed TOML document.
pub struct TomlInspectReport {
  node_count : Int
  scalar_count : Int
  array_count : Int
  table_like_count : Int
  table_count : Int
  max_depth : Int
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
