///|
/// Hard parse failures for the safe XML parser.
pub(all) suberror XmlError {
  ParseError(String)
}

///|
/// Line-based source span for XML tokens and nodes.
pub struct XmlSourceSpan {
  line_start : Int
  line_end : Int
}

///|
/// Public tokenizer output for safe XML scanning.
pub(all) enum XmlToken {
  Declaration(String, XmlSourceSpan)
  ProcessingInstruction(String, String, XmlSourceSpan)
  StartTag(String, Array[XmlAttribute], Bool, XmlSourceSpan)
  EndTag(String, XmlSourceSpan)
  Text(String, XmlSourceSpan)
  Comment(String, XmlSourceSpan)
  CData(String, XmlSourceSpan)
  Doctype(String, XmlSourceSpan)
}

///|
/// Source-native XML nodes produced by the parser.
pub(all) enum XmlNode {
  Element(XmlElement)
  Text(XmlText)
  Comment(XmlComment)
  ProcessingInstruction(XmlProcessingInstruction)
  CData(XmlCData)
}

///|
/// Parsed XML attributes with raw quote-style provenance where available.
pub struct XmlAttribute {
  name : String
  value : String
  quote_char : Char?
  span : XmlSourceSpan
}

///|
/// Parsed XML elements with source-native children.
pub struct XmlElement {
  name : String
  attributes : Array[XmlAttribute]
  children : Array[XmlNode]
  self_closing : Bool
  span : XmlSourceSpan
}

///|
pub struct XmlText {
  text : String
  span : XmlSourceSpan
}

///|
pub struct XmlComment {
  text : String
  span : XmlSourceSpan
}

///|
pub struct XmlProcessingInstruction {
  target : String
  body : String
  span : XmlSourceSpan
}

///|
pub struct XmlCData {
  text : String
  span : XmlSourceSpan
}

///|
/// Parsed XML document with root-element and doctype signals.
pub struct XmlDocument {
  nodes : Array[XmlNode]
  root : XmlElement?
  source_length : Int
  has_doctype : Bool
  has_unsupported_doctype : Bool
}

///|
pub(all) enum XmlErrorKind {
  UnexpectedEOF
  InvalidToken
  InvalidName
  MismatchedTag
  UnexpectedClosingTag
  UnclosedTag
  DuplicateAttribute
  UnsupportedDoctype
  UnsupportedEntity
  MalformedEntity
  MultipleRootElements
  EmptyDocument
  Unknown
} derive(Eq)

///|
/// Stable classification for hard XML parse failures.
pub struct XmlErrorInfo {
  kind : XmlErrorKind
  detail : String
}

///|
pub(all) enum XmlValidationSeverity {
  Warning
  Error
} derive(Eq)

///|
pub(all) enum XmlValidationIssueKind {
  UnsupportedDoctype
  MultipleRootElements
  EmptyDocument
} derive(Eq)

///|
/// Validation issues reported after a successful XML parse.
pub struct XmlValidationIssue {
  kind : XmlValidationIssueKind
  severity : XmlValidationSeverity
  line_start : Int?
  line_end : Int?
  message : String
}

///|
/// Aggregated XML validation report.
pub struct XmlValidationReport {
  issue_count : Int
  warning_count : Int
  error_count : Int
  issues : Array[XmlValidationIssue]
}

///|
/// Structural summary for a parsed XML document.
pub struct XmlInspectReport {
  node_count : Int
  element_count : Int
  attribute_count : Int
  text_node_count : Int
  comment_count : Int
  cdata_count : Int
  processing_instruction_count : Int
  max_depth : Int
  has_doctype : Bool
  has_unsupported_doctype : Bool
  issue_count : Int
  warning_count : Int
  error_count : Int
  is_empty : Bool
}

///|
pub impl Show for XmlError with fn to_string(self : XmlError) -> String {
  match self {
    ParseError(msg) => "xml parse error: " + msg
  }
}

///|
pub impl Show for XmlError with fn output(self : XmlError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
