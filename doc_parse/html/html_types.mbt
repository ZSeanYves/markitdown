///|
pub(all) suberror HtmlError {
  ParseError(String)
}

///|
pub struct HtmlSourceSpan {
  line_start : Int
  line_end : Int
}

///|
pub(all) enum HtmlAttributeQuoteStyle {
  DoubleQuoted
  SingleQuoted
  Unquoted
} derive(Eq)

///|
pub(all) enum HtmlToken {
  StartTag(String, Array[HtmlAttribute], Bool, HtmlSourceSpan)
  EndTag(String, HtmlSourceSpan)
  Text(String, HtmlSourceSpan)
  Comment(String, HtmlSourceSpan)
  Doctype(String, HtmlSourceSpan)
}

///|
pub(all) enum HtmlNode {
  Element(HtmlElement)
  Text(HtmlText)
  Comment(HtmlComment)
  Doctype(HtmlDoctype)
}

///|
pub struct HtmlAttribute {
  name : String
  value : String
  quote_style : HtmlAttributeQuoteStyle
  span : HtmlSourceSpan
}

///|
pub struct HtmlElement {
  tag_name : String
  attributes : Array[HtmlAttribute]
  children : Array[HtmlNode]
  self_closing : Bool
  span : HtmlSourceSpan
}

///|
pub struct HtmlText {
  text : String
  span : HtmlSourceSpan
}

///|
pub struct HtmlComment {
  text : String
  span : HtmlSourceSpan
}

///|
pub struct HtmlDoctype {
  text : String
  span : HtmlSourceSpan
}

///|
pub struct HtmlDocument {
  nodes : Array[HtmlNode]
  source_length : Int
  has_doctype : Bool
  issues : Array[HtmlValidationIssue]
}

///|
pub(all) enum HtmlErrorKind {
  UnexpectedEOF
  InvalidToken
  InvalidName
  MalformedAttribute
  UnterminatedComment
  UnterminatedTag
  Unknown
} derive(Eq)

///|
pub struct HtmlErrorInfo {
  kind : HtmlErrorKind
  detail : String
}

///|
pub(all) enum HtmlValidationSeverity {
  Warning
  Error
} derive(Eq)

///|
pub(all) enum HtmlValidationIssueKind {
  DuplicateAttribute
  UnclosedElement
  UnexpectedClosingTag
  MalformedTag
  UnsafeUrl
  ScriptElement
  StyleElement
  EmptyDocument
} derive(Eq)

///|
pub struct HtmlValidationIssue {
  kind : HtmlValidationIssueKind
  severity : HtmlValidationSeverity
  line_start : Int?
  line_end : Int?
  tag_name : String?
  message : String
}

///|
pub struct HtmlValidationReport {
  issue_count : Int
  warning_count : Int
  error_count : Int
  issues : Array[HtmlValidationIssue]
}

///|
pub struct HtmlInspectReport {
  node_count : Int
  element_count : Int
  text_node_count : Int
  comment_count : Int
  doctype_count : Int
  attribute_count : Int
  link_element_count : Int
  image_element_count : Int
  heading_element_count : Int
  table_element_count : Int
  list_element_count : Int
  form_element_count : Int
  script_element_count : Int
  style_element_count : Int
  pre_element_count : Int
  code_element_count : Int
  max_depth : Int
  has_doctype : Bool
  issue_count : Int
  warning_count : Int
  error_count : Int
  is_empty : Bool
}

///|
pub impl Show for HtmlError with to_string(self : HtmlError) -> String {
  match self {
    ParseError(msg) => "html parse error: " + msg
  }
}

///|
pub impl Show for HtmlError with output(self : HtmlError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
