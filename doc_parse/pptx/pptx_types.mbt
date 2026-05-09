///|
pub(all) suberror PptxError {
  OpenFailed(String)
  OoxmlFailure(String)
  ParseError(String)
}

///|
pub(all) enum PptxTargetMode {
  Internal
  External
} derive(Eq)

///|
pub struct PptxRelationship {
  id : String
  rel_type : String
  target : String
  target_mode : PptxTargetMode
  resolved_target : String
}

///|
pub struct PptxRelationshipIndex {
  relationships : Array[PptxRelationship]
  notes_part : String?
  notes_relationship_id : String?
}

///|
pub struct PptxHyperlink {
  relationship_id : String?
  target : String?
  is_external : Bool
}

///|
pub(all) enum PptxBulletKind {
  Unordered
  Ordered
} derive(Eq)

///|
pub(all) enum PptxTextRunKind {
  Text
  Field
  LineBreak
  Unsupported
} derive(Eq)

///|
pub struct PptxTextRun {
  kind : PptxTextRunKind
  text : String
  relationship_id : String?
  target : String?
  is_external : Bool
}

///|
pub struct PptxTextParagraph {
  runs : Array[PptxTextRun]
  level : Int
  bullet_kind : PptxBulletKind?
  source_shape_ref : String?
  hyperlink_refs : Array[PptxHyperlink]
}

///|
pub struct PptxTableCell {
  row_index : Int
  column_index : Int
  paragraphs : Array[PptxTextParagraph]
}

///|
pub struct PptxTableRow {
  row_index : Int
  cells : Array[PptxTableCell]
}

///|
pub struct PptxTable {
  object_ref : String?
  rows : Array[PptxTableRow]
}

///|
pub(all) enum PptxMediaKind {
  Image
  Audio
  Video
  Other
} derive(Eq)

///|
pub struct PptxMediaRef {
  relationship_id : String?
  target_part : String?
  content_type : String?
  kind : PptxMediaKind
  alt_text : String?
  title : String?
  source_shape_ref : String?
  source_part : String?
}

///|
pub(all) enum PptxShapeKind {
  Shape
  TextBox
  Picture
  Table
  Group
  Placeholder
  Unknown
} derive(Eq)

///|
pub struct PptxShape {
  shape_id : String?
  name : String?
  kind : PptxShapeKind
  object_ref : String?
  x : Int
  y : Int
  w : Int
  h : Int
  is_title_shape : Bool
  is_body_shape : Bool
  children : Array[PptxShape]
  text_paragraphs : Array[PptxTextParagraph]
  table : PptxTable?
  media_ref : PptxMediaRef?
  hyperlink_refs : Array[PptxHyperlink]
}

///|
pub struct PptxNotes {
  part_path : String
  paragraphs : Array[PptxTextParagraph]
}

///|
pub struct PptxSlide {
  index : Int
  slide_id : String?
  relationship_id : String?
  part_path : String
  hidden : Bool
  relationships : PptxRelationshipIndex
  shape_tree : Array[PptxShape]
  paragraphs : Array[PptxTextParagraph]
  tables : Array[PptxTable]
  media_refs : Array[PptxMediaRef]
  hyperlink_refs : Array[PptxHyperlink]
  notes : PptxNotes?
  issues : Array[PptxValidationIssue]
}

///|
pub struct PptxPresentation {
  slides : Array[PptxSlide]
  relationships : PptxRelationshipIndex
  media_refs : Array[PptxMediaRef]
  hyperlink_refs : Array[PptxHyperlink]
  issues : Array[PptxValidationIssue]
}

///|
pub(all) enum PptxErrorKind {
  OpenFailed
  OoxmlFailure
  MissingPresentation
  MalformedPresentationXml
  MalformedSlideXml
  Unknown
} derive(Eq)

///|
pub struct PptxErrorInfo {
  kind : PptxErrorKind
  detail : String
}

///|
pub(all) enum PptxValidationSeverity {
  Warning
  Error
} derive(Eq)

///|
pub(all) enum PptxValidationIssueKind {
  MissingSlidePart
  MissingRelationshipTarget
  MissingMediaPart
  UnsupportedShape
  UnsupportedTable
  Unknown
} derive(Eq)

///|
pub struct PptxValidationIssue {
  kind : PptxValidationIssueKind
  severity : PptxValidationSeverity
  part_path : String?
  relationship_id : String?
  object_ref : String?
  message : String
}

///|
pub struct PptxValidationReport {
  issue_count : Int
  warning_count : Int
  error_count : Int
  issues : Array[PptxValidationIssue]
}

///|
pub struct PptxInspectReport {
  slide_count : Int
  hidden_slide_count : Int
  shape_count : Int
  group_shape_count : Int
  text_shape_count : Int
  paragraph_count : Int
  text_run_count : Int
  table_count : Int
  image_ref_count : Int
  media_ref_count : Int
  hyperlink_count : Int
  notes_count : Int
  issue_count : Int
  warning_count : Int
  error_count : Int
}

///|
priv struct PptxSlideEntry {
  slide_id : String?
  part_name : String
  rel_id : String?
  hidden : Bool
}

///|
priv struct PptxGroupContext {
  offset_x : Int
  offset_y : Int
  scale_x_num : Int
  scale_x_den : Int
  scale_y_num : Int
  scale_y_den : Int
  group_ref_prefix : String?
}

///|
priv struct PptxShapeParseContext {
  pkg : @ox.OoxmlPackage
  rels : PptxRelationshipIndex
  source_part : String
  issues : Array[PptxValidationIssue]
}

///|
fn empty_pptx_relationship_index() -> PptxRelationshipIndex {
  { relationships: [], notes_part: None, notes_relationship_id: None }
}

///|
fn pptx_issue(
  kind : PptxValidationIssueKind,
  severity : PptxValidationSeverity,
  part_path : String?,
  relationship_id : String?,
  object_ref : String?,
  message : String,
) -> PptxValidationIssue {
  { kind, severity, part_path, relationship_id, object_ref, message }
}

///|
pub impl Show for PptxError with to_string(self : PptxError) -> String {
  match self {
    OpenFailed(msg) => "pptx open failed: " + msg
    OoxmlFailure(msg) => "pptx ooxml failure: " + msg
    ParseError(msg) => "pptx parse error: " + msg
  }
}

///|
pub impl Show for PptxError with output(self : PptxError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
