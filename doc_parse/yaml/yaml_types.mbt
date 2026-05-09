///|
pub(all) suberror YamlError {
  ParseError(String)
}

///|
pub(all) enum YamlValue {
  Mapping(Array[YamlMember])
  Sequence(Array[YamlValue])
  String(String)
  Bool(Bool)
  Null
}

///|
pub struct YamlMember {
  key : String
  value : YamlValue
}

///|
pub struct YamlDocument {
  root : YamlValue?
}

///|
pub(all) enum YamlErrorKind {
  UnexpectedEnd
  UnexpectedIndentation
  TrailingContent
  UnsupportedFeature
  EmptyKey
  ExpectedMappingEntry
  ExpectedSequenceItem
  UnterminatedQuotedScalar
  InvalidEscape
  TabsUnsupported
  MultiDocumentUnsupported
  Unknown
} derive(Eq)

///|
pub struct YamlErrorInfo {
  kind : YamlErrorKind
  detail : String
}

///|
pub struct YamlInspectReport {
  is_empty : Bool
  node_count : Int
  mapping_count : Int
  sequence_count : Int
  scalar_count : Int
  max_depth : Int
  root_kind : String?
}

///|
pub impl Show for YamlError with to_string(self : YamlError) -> String {
  match self {
    ParseError(msg) => "yaml parse error: " + msg
  }
}

///|
pub impl Show for YamlError with output(self : YamlError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
