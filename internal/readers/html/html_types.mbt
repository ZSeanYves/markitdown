///|
/// Hard parse failures for the tolerant HTML parser foundation.
pub(all) suberror HtmlError {
  ParseError(String)
}

///|
/// Line-based source span for HTML tokens and nodes.
pub struct HtmlSourceSpan {
  line_start : Int32
  line_end : Int32
  byte_start : Int32
  byte_end : Int32
}

///|
pub(all) enum HtmlAttributeQuoteStyle {
  DoubleQuoted
  SingleQuoted
  Unquoted
} derive(Eq)

///|
pub extend HtmlAttributeQuoteStyle with Eq::{equal, not_equal}

///|
/// Public tokenizer output for tolerant HTML scanning.
pub(all) enum HtmlToken {
  StartTag(String, Array[HtmlAttribute], Bool, HtmlSourceSpan)
  EndTag(String, HtmlSourceSpan)
  Text(String, HtmlSourceSpan)
  Comment(String, HtmlSourceSpan)
  Doctype(String, HtmlSourceSpan)
}

///|
pub(all) enum HtmlTokenEventKind {
  StartTag
  EndTag
  Text
  Comment
  Doctype
} derive(Eq)

///|
pub extend HtmlTokenEventKind with Eq::{equal, not_equal}

///|
pub struct HtmlTokenEvent {
  kind : HtmlTokenEventKind
  tag_name : String
  attributes : Array[HtmlAttribute]
  self_closing : Bool
  source_start : Int32
  source_end : Int32
  span : HtmlSourceSpan
}

///|
pub fn make_html_token_event(
  kind : HtmlTokenEventKind,
  tag_name : String,
  attributes : Array[HtmlAttribute],
  self_closing : Bool,
  source_start : Int32,
  source_end : Int32,
  line_start : Int32,
  line_end : Int32,
  byte_start~ : Int32 = source_start,
  byte_end~ : Int32 = source_end,
) -> HtmlTokenEvent {
  {
    kind,
    tag_name,
    attributes,
    self_closing,
    source_start,
    source_end,
    span: { line_start, line_end, byte_start, byte_end, },
  }
}

///|
pub struct HtmlTokenEventSummary {
  node_count : Int32
  block_scope_count : Int32
  structural_scope_count : Int32
  max_depth : Int32
  char_count : Int32
}

///|
pub struct HtmlTokenSourceRange {
  source_start : Int32
  source_end : Int32
}

///|
pub struct HtmlSourceAnalysis {
  document : HtmlDocument
  events : Array[HtmlTokenEvent]
}

///|
/// Parser-owned semantic block categories for future HTML lowering.
pub(all) enum HtmlBlockKind {
  Heading(Int32)
  Paragraph
  List(Bool)
  ListItem
  Table
  TableRow
  TableCell(Bool)
  BlockQuote
  Pre
  CodeBlock
  Figure
  FigCaption
  HorizontalRule
  UnknownBlock
  UnsupportedBlock
} derive(Eq)

///|
pub extend HtmlBlockKind with Eq::{equal, not_equal}

///|
pub(all) enum HtmlSemanticWarningKind {
  TextPreviewTruncated
  AttributeSummaryTruncated
  AttributeValuePreviewTruncated
  UnsupportedElement
  DepthLimitExceeded
  UnsafeUrl
  EmptyUrl
  RemoteImage
  DataUriImage
  EmptyImageSource
  TableSizeLimitExceeded
  MalformedTableStructure
  BrokenNoteTarget
  MissingNoteTarget
  DuplicateNoteTarget
  MalformedDocumentScope
} derive(Eq)

///|
pub extend HtmlSemanticWarningKind with Eq::{equal, not_equal}

///|
pub(all) enum HtmlWarningSeverity {
  Info
  Warning
  Error
} derive(Eq)

///|
pub extend HtmlWarningSeverity with Eq::{equal, not_equal}

///|
pub(all) enum HtmlUnsupportedKind {
  Script
  Style
  Iframe
  Embed
  Object
  Svg
  Math
  Template
  Form
  Input
  Select
  TextArea
  Button
  Video
  Audio
  Source
  Canvas
  RemoteImage
  DataImage
  UnsafeUrl
  EmptyUrl
  BrokenLocalImage
  UnsupportedCharset
  HugeTextNode
  HugeAttributeValue
  DeepNesting
  HugeTable
  MalformedTag
  UnknownUnsupported
} derive(Eq)

///|
pub extend HtmlUnsupportedKind with Eq::{equal, not_equal}

///|
pub struct HtmlSemanticWarning {
  kind : HtmlSemanticWarningKind
  severity : HtmlWarningSeverity
  source_key : String
  tag_name : String
  message : String
}

///|
pub struct HtmlSemanticAttributeSummary {
  name : String
  value_preview : String
  quote_style : HtmlAttributeQuoteStyle
  span : HtmlSourceSpan
}

///|
pub struct HtmlUnsupportedFact {
  kind : HtmlUnsupportedKind
  severity : HtmlWarningSeverity
  source_key : String
  related_source_key : String?
  tag_name : String
  source_order : Int32
  depth : Int32
  parent_source_key : String?
  text_preview : String
  attributes : Array[HtmlSemanticAttributeSummary]
  url : String?
  span : HtmlSourceSpan
  message : String
}

///|
pub struct HtmlBlockFact {
  kind : HtmlBlockKind
  source_key : String
  tag_name : String
  source_order : Int32
  depth : Int32
  parent_source_key : String?
  text_preview : String
  attributes : Array[HtmlSemanticAttributeSummary]
  span : HtmlSourceSpan
  children : Array[String]
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlParagraphFact {
  source_key : String
  block_source_key : String
  tag_name : String
  source_order : Int32
  depth : Int32
  parent_block_source_key : String?
  inline_child_keys : Array[String]
  raw_text_preview : String
  normalized_text_preview : String
  has_meaningful_text : Bool
  has_links : Bool
  has_images : Bool
  has_code : Bool
  has_emphasis : Bool
  has_strong : Bool
  has_breaks : Bool
  has_repeated_whitespace : Bool
  has_newline : Bool
  is_candidate : Bool
  text_preview : String
  attributes : Array[HtmlSemanticAttributeSummary]
  span : HtmlSourceSpan
  warnings : Array[HtmlSemanticWarning]
}

///|
pub(all) enum HtmlInlineKind {
  Text
  Emphasis
  Strong
  Code
  Link
  Image
  Break
  Span
  InlineContainer
  UnsupportedInline
  UnknownInline
} derive(Eq)

///|
pub extend HtmlInlineKind with Eq::{equal, not_equal}

///|
pub(all) enum HtmlLinkKind {
  Internal
  External
  Mailto
  Tel
  Data
  Unsafe
  Empty
  Unknown
} derive(Eq)

///|
pub extend HtmlLinkKind with Eq::{equal, not_equal}

///|
pub(all) enum HtmlImageKind {
  Local
  Remote
  DataUri
  Empty
  Unsafe
  Unknown
} derive(Eq)

///|
pub extend HtmlImageKind with Eq::{equal, not_equal}

///|
pub(all) enum HtmlNoteKind {
  Footnote
  EndnoteLike
  Reference
  BackReference
  Unknown
} derive(Eq)

///|
pub extend HtmlNoteKind with Eq::{equal, not_equal}

///|
pub(all) enum HtmlNoteRelationConfidence {
  High
  Medium
  Low
  Broken
} derive(Eq)

///|
pub extend HtmlNoteRelationConfidence with Eq::{equal, not_equal}

///|
pub(all) enum HtmlDocumentScopeSource {
  Body
  Main
  Article
  DocumentRoot
  Fragment
  Heuristic
} derive(Eq)

///|
pub extend HtmlDocumentScopeSource with Eq::{equal, not_equal}

///|
pub(all) enum HtmlNoiseCandidateReason {
  NavLike
  FooterLike
  SidebarLike
  Hiddenish
  ScriptStyleTemplate
  RepeatedBoilerplate
  Unknown
} derive(Eq)

///|
pub extend HtmlNoiseCandidateReason with Eq::{equal, not_equal}

///|
pub(all) enum HtmlNoiseCandidateConfidence {
  High
  Medium
  Low
} derive(Eq)

///|
pub extend HtmlNoiseCandidateConfidence with Eq::{equal, not_equal}

///|
pub struct HtmlInlineFact {
  kind : HtmlInlineKind
  source_key : String
  tag_name : String
  source_order : Int32
  depth : Int32
  parent_block_source_key : String?
  parent_inline_source_key : String?
  raw_text_preview : String
  normalized_text_preview : String
  text_preview : String
  has_leading_whitespace : Bool
  has_trailing_whitespace : Bool
  contains_newline : Bool
  contains_repeated_whitespace : Bool
  is_whitespace_only : Bool
  preserves_whitespace : Bool
  has_surrounding_text : Bool
  attributes : Array[HtmlSemanticAttributeSummary]
  span : HtmlSourceSpan
  children : Array[String]
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlLinkFact {
  source_key : String
  inline_source_key : String
  parent_block_source_key : String?
  href : String
  title : String?
  target : String?
  rel : String?
  text_preview : String
  inline_child_keys : Array[String]
  image_source_keys : Array[String]
  has_nested_inline : Bool
  has_image : Bool
  is_note_ref : Bool
  is_back_reference : Bool
  kind : HtmlLinkKind
  span : HtmlSourceSpan
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlImageFact {
  source_key : String
  inline_source_key : String
  parent_block_source_key : String?
  parent_inline_source_key : String?
  parent_link_source_key : String?
  src : String
  srcset : String?
  alt : String?
  title : String?
  width : String?
  height : String?
  loading : String?
  decoding : String?
  picture_source_keys : Array[String]
  alt_complete : Bool
  title_complete : Bool
  kind : HtmlImageKind
  span : HtmlSourceSpan
  warnings : Array[HtmlSemanticWarning]
}

///|
pub(all) enum HtmlTableSectionKind {
  Head
  Body
  Foot
  Unknown
} derive(Eq)

///|
pub extend HtmlTableSectionKind with Eq::{equal, not_equal}

///|
pub(all) enum HtmlTableCellKind {
  Header
  Data
  Unknown
} derive(Eq)

///|
pub extend HtmlTableCellKind with Eq::{equal, not_equal}

///|
pub(all) enum HtmlListKind {
  Ordered
  Unordered
  Unknown
} derive(Eq)

///|
pub extend HtmlListKind with Eq::{equal, not_equal}

///|
pub struct HtmlTableFact {
  source_key : String
  block_source_key : String
  tag_name : String
  source_order : Int32
  depth : Int32
  parent_block_source_key : String?
  caption_source_key : String?
  caption_text_preview : String?
  sections : Array[String]
  rows : Array[String]
  cells : Array[String]
  row_count : Int32
  cell_count : Int32
  max_column_count : Int32
  has_ragged_rows : Bool
  has_span : Bool
  has_caption : Bool
  has_nested_table : Bool
  has_complex_cell : Bool
  span_cell_count : Int32
  ragged_row_count : Int32
  nested_table_cell_count : Int32
  complex_cell_count : Int32
  image_cell_count : Int32
  block_child_cell_count : Int32
  malformed_warning_count : Int32
  safe_simple_table_candidate : Bool
  text_preview : String
  attributes : Array[HtmlSemanticAttributeSummary]
  span : HtmlSourceSpan
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlTableSectionFact {
  source_key : String
  table_source_key : String
  block_source_key : String
  kind : HtmlTableSectionKind
  tag_name : String
  source_order : Int32
  depth : Int32
  row_source_keys : Array[String]
  row_count : Int32
  text_preview : String
  attributes : Array[HtmlSemanticAttributeSummary]
  span : HtmlSourceSpan
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlTableRowFact {
  source_key : String
  table_source_key : String
  section_source_key : String?
  block_source_key : String
  source_order : Int32
  depth : Int32
  row_index : Int32
  cell_source_keys : Array[String]
  cell_count : Int32
  text_preview : String
  attributes : Array[HtmlSemanticAttributeSummary]
  span : HtmlSourceSpan
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlTableCellFact {
  source_key : String
  table_source_key : String
  section_source_key : String?
  row_source_key : String
  block_source_key : String
  source_order : Int32
  depth : Int32
  row_index : Int32
  cell_index : Int32
  kind : HtmlTableCellKind
  tag_name : String
  colspan : String?
  rowspan : String?
  colspan_value : Int32
  rowspan_value : Int32
  headers : String?
  scope : String?
  inline_child_keys : Array[String]
  direct_child_block_keys : Array[String]
  text_complete : Bool
  has_complex_block : Bool
  has_nested_table : Bool
  has_image : Bool
  has_list : Bool
  has_blockquote : Bool
  has_pre : Bool
  has_figure : Bool
  has_unsupported_warning : Bool
  safe_simple_cell_candidate : Bool
  text_preview : String
  attributes : Array[HtmlSemanticAttributeSummary]
  span : HtmlSourceSpan
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlListFact {
  source_key : String
  block_source_key : String
  kind : HtmlListKind
  tag_name : String
  source_order : Int32
  depth : Int32
  list_depth : Int32
  parent_list_source_key : String?
  parent_item_source_key : String?
  item_source_keys : Array[String]
  item_count : Int32
  start : String?
  type_attr : String?
  reversed : Bool
  text_preview : String
  attributes : Array[HtmlSemanticAttributeSummary]
  span : HtmlSourceSpan
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlListItemFact {
  source_key : String
  block_source_key : String
  list_source_key : String?
  parent_item_source_key : String?
  source_order : Int32
  depth : Int32
  list_depth : Int32
  item_order : Int32
  child_list_source_keys : Array[String]
  text_preview : String
  attributes : Array[HtmlSemanticAttributeSummary]
  span : HtmlSourceSpan
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlBlockQuoteFact {
  source_key : String
  block_source_key : String
  source_order : Int32
  depth : Int32
  quote_depth : Int32
  parent_quote_source_key : String?
  child_block_source_keys : Array[String]
  cite : String?
  text_preview : String
  attributes : Array[HtmlSemanticAttributeSummary]
  span : HtmlSourceSpan
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlCodeBlockFact {
  source_key : String
  block_source_key : String
  code_block_source_key : String?
  tag_name : String
  source_order : Int32
  depth : Int32
  language_hint : String?
  class_hint : String?
  code_text : String
  code_text_complete : Bool
  whitespace_preview : String
  text_preview : String
  attributes : Array[HtmlSemanticAttributeSummary]
  span : HtmlSourceSpan
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlFigureFact {
  source_key : String
  block_source_key : String
  source_order : Int32
  depth : Int32
  child_block_source_keys : Array[String]
  caption_block_source_key : String?
  caption_text_preview : String?
  image_source_keys : Array[String]
  link_source_keys : Array[String]
  inline_child_keys : Array[String]
  text_preview : String
  attributes : Array[HtmlSemanticAttributeSummary]
  span : HtmlSourceSpan
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlNoteRefFact {
  source_key : String
  inline_source_key : String
  parent_block_source_key : String?
  href : String
  target_id : String?
  ref_text_preview : String
  inline_child_keys : Array[String]
  kind : HtmlNoteKind
  source_order : Int32
  relation_confidence : HtmlNoteRelationConfidence
  is_broken : Bool
  is_back_reference : Bool
  span : HtmlSourceSpan
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlNoteBodyFact {
  source_key : String
  block_source_key : String
  source_order : Int32
  kind : HtmlNoteKind
  note_id : String?
  marker : String?
  body_text_preview : String
  inline_child_keys : Array[String]
  owning_block_source_key : String?
  ref_source_keys : Array[String]
  duplicate_target : Bool
  span : HtmlSourceSpan
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlNoteFact {
  source_key : String
  note_id : String?
  kind : HtmlNoteKind
  ref_source_key : String?
  body_source_key : String?
  href : String?
  ref_text_preview : String
  body_text_preview : String
  source_order : Int32
  relation_confidence : HtmlNoteRelationConfidence
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlDocumentScopeFact {
  source_key : String
  html_node_key : String?
  head_node_key : String?
  body_node_key : String?
  selected_content_root_key : String?
  scope_source : HtmlDocumentScopeSource
  title_text_preview : String?
  meta_charset : String?
  meta_viewport : String?
  meta_description : String?
  malformed_root_warning : Bool
  multiple_body_warning : Bool
  missing_body_warning : Bool
  selected_scope_reason : String
  noise_candidate_source_keys : Array[String]
  warnings : Array[HtmlSemanticWarning]
}

///|
pub struct HtmlNoiseCandidateFact {
  source_key : String
  block_source_key : String?
  parent_source_key : String?
  tag_name : String
  source_order : Int32
  depth : Int32
  text_preview : String
  attributes : Array[HtmlSemanticAttributeSummary]
  reasons : Array[HtmlNoiseCandidateReason]
  confidence : HtmlNoiseCandidateConfidence
  span : HtmlSourceSpan
}

///|
pub struct HtmlSemanticDocument {
  blocks : Array[HtmlBlockFact]
  paragraphs : Array[HtmlParagraphFact]
  inlines : Array[HtmlInlineFact]
  links : Array[HtmlLinkFact]
  images : Array[HtmlImageFact]
  tables : Array[HtmlTableFact]
  table_sections : Array[HtmlTableSectionFact]
  table_rows : Array[HtmlTableRowFact]
  table_cells : Array[HtmlTableCellFact]
  lists : Array[HtmlListFact]
  list_items : Array[HtmlListItemFact]
  blockquotes : Array[HtmlBlockQuoteFact]
  code_blocks : Array[HtmlCodeBlockFact]
  figures : Array[HtmlFigureFact]
  note_refs : Array[HtmlNoteRefFact]
  note_bodies : Array[HtmlNoteBodyFact]
  notes : Array[HtmlNoteFact]
  scope : Array[HtmlDocumentScopeFact]
  noise_candidates : Array[HtmlNoiseCandidateFact]
  unsupported : Array[HtmlUnsupportedFact]
  warnings : Array[HtmlSemanticWarning]
  max_depth : Int32
}

///|
pub struct HtmlSemanticInspectReport {
  block_count : Int32
  heading_count : Int32
  paragraph_count : Int32
  list_count : Int32
  list_item_count : Int32
  table_count : Int32
  table_row_count : Int32
  table_cell_count : Int32
  blockquote_count : Int32
  pre_count : Int32
  code_block_count : Int32
  figure_count : Int32
  figcaption_count : Int32
  horizontal_rule_count : Int32
  unknown_block_count : Int32
  unsupported_block_count : Int32
  paragraph_fact_count : Int32
  paragraph_with_link_count : Int32
  paragraph_with_image_count : Int32
  paragraph_with_code_count : Int32
  paragraph_with_emphasis_count : Int32
  paragraph_with_strong_count : Int32
  paragraph_with_break_count : Int32
  paragraph_meaningful_text_count : Int32
  paragraph_candidate_count : Int32
  paragraph_repeated_whitespace_count : Int32
  paragraph_newline_count : Int32
  inline_count : Int32
  text_inline_count : Int32
  emphasis_inline_count : Int32
  strong_inline_count : Int32
  code_inline_count : Int32
  link_inline_count : Int32
  image_inline_count : Int32
  break_inline_count : Int32
  span_inline_count : Int32
  inline_container_count : Int32
  unsupported_inline_count : Int32
  unknown_inline_count : Int32
  whitespace_only_text_inline_count : Int32
  leading_whitespace_inline_count : Int32
  trailing_whitespace_inline_count : Int32
  repeated_whitespace_inline_count : Int32
  newline_inline_count : Int32
  whitespace_preserving_inline_count : Int32
  inline_with_surrounding_text_count : Int32
  link_count : Int32
  internal_link_count : Int32
  external_link_count : Int32
  mailto_link_count : Int32
  tel_link_count : Int32
  data_link_count : Int32
  unsafe_link_count : Int32
  empty_link_count : Int32
  image_count : Int32
  local_image_count : Int32
  remote_image_count : Int32
  data_uri_image_count : Int32
  empty_image_count : Int32
  unsafe_image_count : Int32
  linked_image_count : Int32
  image_in_link_count : Int32
  note_ref_inline_count : Int32
  srcset_image_count : Int32
  picture_source_count : Int32
  note_fact_count : Int32
  note_ref_fact_count : Int32
  note_body_fact_count : Int32
  broken_note_ref_count : Int32
  duplicate_note_body_count : Int32
  backref_note_count : Int32
  table_fact_count : Int32
  table_section_count : Int32
  table_head_section_count : Int32
  table_body_section_count : Int32
  table_foot_section_count : Int32
  table_unknown_section_count : Int32
  table_caption_count : Int32
  table_fact_row_count : Int32
  table_fact_cell_count : Int32
  table_header_cell_count : Int32
  table_data_cell_count : Int32
  table_unknown_cell_count : Int32
  max_table_row_count : Int32
  max_table_cell_count : Int32
  table_span_cell_count : Int32
  table_ragged_row_count : Int32
  table_nested_cell_count : Int32
  table_complex_cell_count : Int32
  table_image_cell_count : Int32
  table_block_child_cell_count : Int32
  table_malformed_warning_count : Int32
  table_warning_count : Int32
  scope_fact_count : Int32
  scope_body_count : Int32
  scope_main_count : Int32
  scope_article_count : Int32
  scope_document_root_count : Int32
  scope_fragment_count : Int32
  scope_heuristic_count : Int32
  scope_missing_body_count : Int32
  scope_multiple_body_count : Int32
  scope_malformed_root_count : Int32
  noise_candidate_count : Int32
  noise_nav_like_count : Int32
  noise_footer_like_count : Int32
  noise_sidebar_like_count : Int32
  noise_hiddenish_count : Int32
  noise_script_style_template_count : Int32
  noise_repeated_boilerplate_count : Int32
  list_fact_count : Int32
  ordered_list_fact_count : Int32
  unordered_list_fact_count : Int32
  list_item_fact_count : Int32
  max_list_depth : Int32
  blockquote_fact_count : Int32
  max_quote_depth : Int32
  code_block_fact_count : Int32
  code_block_language_hint_count : Int32
  figure_fact_count : Int32
  figure_caption_count : Int32
  figure_image_count : Int32
  max_depth : Int32
  warning_count : Int32
  warning_info_count : Int32
  warning_warning_count : Int32
  warning_error_count : Int32
  unsupported_fact_count : Int32
  unsupported_info_count : Int32
  unsupported_warning_count : Int32
  unsupported_error_count : Int32
  unsupported_script_count : Int32
  unsupported_style_count : Int32
  unsupported_iframe_count : Int32
  unsupported_embed_count : Int32
  unsupported_object_count : Int32
  unsupported_svg_count : Int32
  unsupported_math_count : Int32
  unsupported_template_count : Int32
  unsupported_form_count : Int32
  unsupported_input_count : Int32
  unsupported_select_count : Int32
  unsupported_textarea_count : Int32
  unsupported_button_count : Int32
  unsupported_video_count : Int32
  unsupported_audio_count : Int32
  unsupported_source_count : Int32
  unsupported_canvas_count : Int32
  unsupported_remote_image_count : Int32
  unsupported_data_image_count : Int32
  unsupported_unsafe_url_count : Int32
  unsupported_empty_url_count : Int32
  unsupported_broken_local_image_count : Int32
  unsupported_charset_count : Int32
  unsupported_huge_text_node_count : Int32
  unsupported_huge_attribute_value_count : Int32
  unsupported_deep_nesting_count : Int32
  unsupported_huge_table_count : Int32
  unsupported_malformed_tag_count : Int32
  unsupported_unknown_count : Int32
}

///|
/// Source-native HTML nodes preserved by the DOM-ish parser.
pub(all) enum HtmlNode {
  Element(HtmlElement)
  Text(HtmlText)
  Comment(HtmlComment)
  Doctype(HtmlDoctype)
}

///|
/// Parsed HTML attributes with raw quote-style provenance.
pub struct HtmlAttribute {
  name : String
  value : String
  quote_style : HtmlAttributeQuoteStyle
  span : HtmlSourceSpan
}

///|
/// Parsed HTML element nodes with preserved child structure.
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
/// Tolerantly parsed HTML document with validation issues kept explicitly.
pub struct HtmlDocument {
  nodes : Array[HtmlNode]
  source_length : Int32
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
pub extend HtmlErrorKind with Eq::{equal, not_equal}

///|
/// Stable classification for hard HTML parse failures.
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
pub extend HtmlValidationSeverity with Eq::{equal, not_equal}

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
pub extend HtmlValidationIssueKind with Eq::{equal, not_equal}

///|
/// Validation issues surfaced after a successful tolerant HTML parse.
pub struct HtmlValidationIssue {
  kind : HtmlValidationIssueKind
  severity : HtmlValidationSeverity
  line_start : Int32?
  line_end : Int32?
  tag_name : String?
  message : String
}

///|
/// Aggregated validation report for a parsed HTML document.
pub struct HtmlValidationReport {
  issue_count : Int32
  warning_count : Int32
  error_count : Int32
  issues : Array[HtmlValidationIssue]
}

///|
/// Structural summary for a parsed HTML document.
pub struct HtmlInspectReport {
  node_count : Int32
  element_count : Int32
  text_node_count : Int32
  comment_count : Int32
  doctype_count : Int32
  attribute_count : Int32
  link_element_count : Int32
  image_element_count : Int32
  heading_element_count : Int32
  table_element_count : Int32
  list_element_count : Int32
  form_element_count : Int32
  script_element_count : Int32
  style_element_count : Int32
  pre_element_count : Int32
  code_element_count : Int32
  max_depth : Int32
  has_doctype : Bool
  issue_count : Int32
  warning_count : Int32
  error_count : Int32
  is_empty : Bool
}

///|
pub impl Show for HtmlError with fn to_string(self : HtmlError) -> String {
  match self {
    ParseError(msg) => "html parse error: " + msg
  }
}

///|
pub impl Show for HtmlError with fn output(self : HtmlError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
