///|
/// Hard open and parse failures for the WordprocessingML semantic layer.
pub(all) suberror DocxError {
  OpenFailed(String)
  OoxmlFailure(String)
  ParseError(String)
}

///|
/// Relationship target mode preserved from OOXML relationships.
pub(all) enum DocxTargetMode {
  Internal
  External
} derive(Eq)

///|
/// Raw Word style classes preserved without final output policy.
pub(all) enum DocxStyleType {
  Paragraph
  Character
  Table
  Numbering
  Unknown
} derive(Eq)

///|
pub(all) enum DocxHeaderFooterRefType {
  Default
  First
  Even
  Unknown
} derive(Eq)

///|
pub(all) enum DocxTextBoxContext {
  Body
  Header
  Footer
} derive(Eq)

///|
/// Raw inline inventory preserved inside DOCX runs.
pub(all) enum DocxInline {
  Text(String)
  Tab
  LineBreak
  Hyperlink(DocxHyperlink)
  FootnoteRef(Int)
  EndnoteRef(Int)
  CommentRef(Int)
  DrawingRef(DocxMediaRef)
  Unsupported(String)
}

///|
/// Source-native top-level body blocks preserved from the main document body.
pub(all) enum DocxBodyBlock {
  Paragraph(DocxParagraph)
  Table(DocxTable)
}

///|
/// Parsed relationship entry with resolved OOXML target information.
pub struct DocxRelationship {
  id : String
  rel_type : String
  target : String
  target_mode : DocxTargetMode
  resolved_target : String
}

///|
/// Relationship lookup index for hyperlinks and part-local references.
pub struct DocxRelationshipIndex {
  relationships : Array[DocxRelationship]
  targets_by_rid : Map[String, String]
  hyperlink_targets_by_rid : Map[String, String]
}

///|
/// Raw numbering reference preserved on paragraphs and styles.
pub struct DocxNumberingRef {
  num_id : Int
  ilvl : Int
  num_format : String?
}

///|
/// Raw style definition preserved from `styles.xml`.
pub struct DocxStyle {
  style_id : String
  name : String?
  style_type : DocxStyleType
  based_on : String?
  raw_heading_level : Int?
  linked_numbering : DocxNumberingRef?
}

///|
/// Parsed DOCX style inventory.
pub struct DocxStyles {
  styles : Array[DocxStyle]
}

///|
pub struct DocxNumberingLevel {
  ilvl : Int
  num_format : String?
}

///|
pub struct DocxAbstractNumbering {
  abstract_num_id : Int
  levels : Array[DocxNumberingLevel]
}

///|
pub struct DocxNumberingInstance {
  num_id : Int
  abstract_num_id : Int
}

///|
/// Parsed numbering inventory preserved from `numbering.xml`.
pub struct DocxNumbering {
  abstract_numbers : Array[DocxAbstractNumbering]
  numbering_instances : Array[DocxNumberingInstance]
}

///|
/// Raw hyperlink signal preserved from WordprocessingML.
pub struct DocxHyperlink {
  relationship_id : String?
  anchor : String?
  target : String?
  text : String
  is_external : Bool
}

///|
/// Raw media reference preserved from drawings and relationship lookups.
pub struct DocxMediaRef {
  relationship_id : String?
  target_part : String?
  content_type : String?
  alt_text : String?
  title : String?
  source_part : String?
}

///|
/// Source-native DOCX run model.
pub struct DocxRun {
  style_id : String?
  inlines : Array[DocxInline]
}

///|
/// Source-native DOCX paragraph model.
pub struct DocxParagraph {
  style_id : String?
  numbering_ref : DocxNumberingRef?
  runs : Array[DocxRun]
  hyperlink_refs : Array[DocxHyperlink]
  media_refs : Array[DocxMediaRef]
}

///|
/// Source-native DOCX table cell model with nested body blocks.
pub struct DocxTableCell {
  body_blocks : Array[DocxBodyBlock]
  grid_span : Int?
  vertical_merge : String?
}

///|
pub struct DocxTableRow {
  cells : Array[DocxTableCell]
}

///|
/// Source-native DOCX table model.
pub struct DocxTable {
  rows : Array[DocxTableRow]
}

///|
pub struct DocxFootnote {
  id : Int
  body_blocks : Array[DocxBodyBlock]
  text : String
}

///|
pub struct DocxEndnote {
  id : Int
  body_blocks : Array[DocxBodyBlock]
  text : String
}

///|
pub struct DocxComment {
  id : Int
  author : String?
  body_blocks : Array[DocxBodyBlock]
  text : String
}

///|
/// Parsed footnotes, endnotes, and comments preserved as raw semantic
/// structures.
pub struct DocxNotes {
  footnotes : Array[DocxFootnote]
  endnotes : Array[DocxEndnote]
  comments : Array[DocxComment]
}

///|
pub struct DocxHeader {
  ref_type : DocxHeaderFooterRefType
  relationship_id : String
  part_name : String
  body_blocks : Array[DocxBodyBlock]
}

///|
pub struct DocxFooter {
  ref_type : DocxHeaderFooterRefType
  relationship_id : String
  part_name : String
  body_blocks : Array[DocxBodyBlock]
}

///|
/// Parsed text box content preserved from body, header, or footer context.
pub struct DocxTextBox {
  context : DocxTextBoxContext
  source_part : String
  relationship_id : String?
  textbox_index : Int
  body_blocks : Array[DocxBodyBlock]
}

///|
/// Source-native WordprocessingML semantic document model.
pub struct DocxDocument {
  body_blocks : Array[DocxBodyBlock]
  relationships : DocxRelationshipIndex
  styles : DocxStyles
  numbering : DocxNumbering
  notes : DocxNotes
  headers : Array[DocxHeader]
  footers : Array[DocxFooter]
  text_boxes : Array[DocxTextBox]
  media_refs : Array[DocxMediaRef]
  hyperlink_refs : Array[DocxHyperlink]
  issues : Array[DocxValidationIssue]
}

///|
pub(all) enum DocxErrorKind {
  OpenFailed
  OoxmlFailure
  MissingMainDocument
  MalformedDocumentXml
  MalformedStylesXml
  MalformedNumberingXml
  Unknown
} derive(Eq)

///|
/// Stable classification for hard DOCX open and parse failures.
pub struct DocxErrorInfo {
  kind : DocxErrorKind
  detail : String
}

///|
pub(all) enum DocxValidationSeverity {
  Warning
  Error
} derive(Eq)

///|
pub(all) enum DocxValidationIssueKind {
  MissingRelationshipTarget
  MissingMediaPart
  MissingStyle
  MissingNumbering
  UnsupportedElement
  UnsupportedDrawing
  Unknown
} derive(Eq)

///|
/// Validation issues surfaced after a successful DOCX semantic parse.
pub struct DocxValidationIssue {
  kind : DocxValidationIssueKind
  severity : DocxValidationSeverity
  part_name : String?
  relationship_id : String?
  style_id : String?
  num_id : Int?
  message : String
}

///|
/// Aggregated validation report for a parsed DOCX document.
pub struct DocxValidationReport {
  issue_count : Int
  warning_count : Int
  error_count : Int
  issues : Array[DocxValidationIssue]
}

///|
/// Structural summary for a parsed DOCX semantic document.
pub struct DocxInspectReport {
  paragraph_count : Int
  run_count : Int
  text_run_count : Int
  table_count : Int
  table_row_count : Int
  table_cell_count : Int
  hyperlink_count : Int
  media_ref_count : Int
  image_ref_count : Int
  numbering_ref_count : Int
  style_count : Int
  note_count : Int
  header_count : Int
  footer_count : Int
  text_box_count : Int
  issue_count : Int
  warning_count : Int
  error_count : Int
}

///|
priv struct DocxHeaderFooterReference {
  is_header : Bool
  ref_type : DocxHeaderFooterRefType
  relationship_id : String
  part_name : String
}

///|
priv struct DocxPartParseContext {
  pkg : @ox.OoxmlPackage
  rels : DocxRelationshipIndex
  source_part : String
  issues : Array[DocxValidationIssue]
  profile_totals : DocxParseProfileTotals?
}

///|
fn empty_docx_relationship_index() -> DocxRelationshipIndex {
  {
    relationships: [],
    targets_by_rid: Map::new(),
    hyperlink_targets_by_rid: Map::new(),
  }
}

///|
fn empty_docx_styles() -> DocxStyles {
  { styles: [] }
}

///|
fn empty_docx_numbering() -> DocxNumbering {
  { abstract_numbers: [], numbering_instances: [] }
}

///|
fn docx_issue(
  kind : DocxValidationIssueKind,
  severity : DocxValidationSeverity,
  part_name : String?,
  relationship_id : String?,
  style_id : String?,
  num_id : Int?,
  message : String,
) -> DocxValidationIssue {
  { kind, severity, part_name, relationship_id, style_id, num_id, message }
}

///|
pub impl Show for DocxError with to_string(self : DocxError) -> String {
  match self {
    OpenFailed(msg) => "docx open failed: " + msg
    OoxmlFailure(msg) => "docx ooxml failure: " + msg
    ParseError(msg) => "docx parse error: " + msg
  }
}

///|
pub impl Show for DocxError with output(self : DocxError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
