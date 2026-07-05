///|
/// Hard parse failures for the YAML-subset parser.
pub(all) suberror YamlError {
  ParseError(String)
}

///|
/// Source-native YAML-subset values.
///
/// This model stays intentionally small and does not aim to cover full YAML.
pub(all) enum YamlValue {
  Mapping(Array[YamlMember])
  Sequence(Array[YamlValue])
  String(String)
  Number(String)
  Bool(Bool)
  Null
}

///|
/// Source-native structure event kind for conservative YAML-subset streaming.
pub(all) enum YamlStructureEventKind {
  MappingStart
  MappingEnd
  SequenceStart
  SequenceEnd
  Key
  StringValue
  NumberValue
  BoolValue
  NullValue
}

///|
pub struct YamlMember {
  key : String
  value : YamlValue
}

///|
/// A parsed YAML document with an optional root node.
pub struct YamlDocument {
  root : YamlValue?
}

///|
/// Source location for a YAML-subset structure event.
pub struct YamlStructureSource {
  line_start : Int
  line_end : Int
  path : String
  depth : Int
}

///|
/// Source-native structure event for conservative YAML-subset streaming.
pub struct YamlStructureEvent {
  kind : YamlStructureEventKind
  text : String?
  source : YamlStructureSource
}

///|
/// Parsed YAML document plus deterministic structure events.
pub struct YamlStructureDocument {
  document : YamlDocument
  events : Array[YamlStructureEvent]
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
/// Stable classification for hard YAML parse failures.
pub struct YamlErrorInfo {
  kind : YamlErrorKind
  detail : String
}

///|
/// Structural summary for a parsed YAML-subset document.
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
pub impl Show for YamlError with fn to_string(self : YamlError) -> String {
  match self {
    ParseError(msg) => "yaml parse error: " + msg
  }
}

///|
pub impl Show for YamlError with fn output(self : YamlError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
