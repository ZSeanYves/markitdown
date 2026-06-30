///|
pub(all) suberror DocxError {
  OoxmlFailure(String)
  MissingMainDocument
  MalformedDocument(String)
}

///|
pub(all) enum DocxSourceBlockKind {
  Paragraph
  Table
  ContentControl
  Structural
  Unknown
} derive(Eq)

///|
pub(all) enum DocxSourceWarningKind {
  MissingMainDocument
  MalformedDocumentXml
  MissingHyperlinkTarget
  MissingMediaTarget
  MissingMediaPart
  UnsupportedMedia
  UnsupportedMath
  MissingStylesPart
  MissingNumberingPart
  MissingContainerPart
  NestedTable
  UnsupportedTextbox
  UnknownBodyNode
  UnsupportedTable
  UnsupportedField
  UnsupportedBookmark
  TrackedChange
  UnsupportedInline
  UnresolvedFootnoteRef
  UnresolvedEndnoteRef
  UnresolvedCommentRef
} derive(Eq)

///|
pub(all) enum DocxWarningKind {
  MissingMainDocument
  MalformedDocumentXml
  MissingHyperlinkTarget
  MissingMediaTarget
  MissingMediaPart
  UnsupportedMedia
  UnsupportedMath
  MissingStylesPart
  MissingNumberingPart
  MissingContainerPart
  NestedTable
  UnsupportedTextbox
  UnknownBodyNode
  UnsupportedTable
  UnsupportedField
  UnsupportedBookmark
  TrackedChange
  UnsupportedInline
  UnresolvedFootnoteRef
  UnresolvedEndnoteRef
  UnresolvedCommentRef
} derive(Eq)

///|
pub(all) enum DocxWarningSeverity {
  Warning
  Error
} derive(Eq)

///|
pub struct DocxSourceKey {
  part_name : String
  block_index : Int
  node_key : String
}

///|
pub struct DocxSourceWarning {
  kind : DocxSourceWarningKind
  message : String
  source_key : DocxSourceKey?
}

///|
pub struct DocxCoreProperties {
  title : String?
  subject : String?
  creator : String?
  last_modified_by : String?
  created : String?
  modified : String?
  keywords : String?
  description : String?
  category : String?
}

///|
pub struct DocxAppProperties {
  company : String?
  manager : String?
  application : String?
  pages : String?
  words : String?
  slides : String?
  sheets : String?
}

///|
pub struct DocxCustomProperty {
  name : String
  value : String
  value_type : String?
}

///|
pub struct DocxDocumentMetadata {
  core : DocxCoreProperties
  app : DocxAppProperties
  custom_properties : Array[DocxCustomProperty]
}

///|
pub(all) enum DocxTargetMode {
  Internal
  External
} derive(Eq)

///|
pub struct DocxNumberingRef {
  num_id : String
  ilvl : String?
}

///|
pub struct DocxSourceStyle {
  style_id : String
  style_type : String?
  name : String?
  based_on : String?
  paragraph_properties : Array[String]
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceStyles {
  part_name : String?
  styles : Array[DocxSourceStyle]
}

///|
pub struct DocxSourceNumberingNum {
  num_id : String
  abstract_num_id : String?
  start_overrides : Array[DocxNumberingStartOverride]
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceNumberingLevel {
  abstract_num_id : String
  ilvl : String
  num_fmt : String?
  start : String?
  lvl_text : String?
  paragraph_style_id : String?
  style_link : String?
  num_style_link : String?
  source_key : DocxSourceKey
}

///|
pub struct DocxNumberingStartOverride {
  ilvl : String
  start : String?
}

///|
pub struct DocxSourceNumbering {
  part_name : String?
  nums : Array[DocxSourceNumberingNum]
  levels : Array[DocxSourceNumberingLevel]
}

///|
pub(all) enum DocxBookmarkKind {
  Start
  End
} derive(Eq)

///|
pub(all) enum DocxNoteKind {
  Footnote
  Endnote
} derive(Eq)

///|
pub(all) enum DocxPartBodyKind {
  Header
  Footer
  Textbox
} derive(Eq)

///|
pub(all) enum DocxPartDiscoverySource {
  Relationship
  ContentType
  ConventionalPath
} derive(Eq)

///|
pub(all) enum DocxDiscoveredPartKind {
  MainDocument
  Footnotes
  Endnotes
  Comments
  Header
  Footer
  Numbering
  Styles
  Media
  Unknown
} derive(Eq)

///|
pub struct DocxDiscoveredPart {
  part_name : String
  kind : DocxDiscoveredPartKind
  source : DocxPartDiscoverySource
  relationship_id : String?
  source_part : String?
  content_type : String?
}

///|
pub struct DocxPartGraph {
  main_part : String
  parts : Array[DocxDiscoveredPart]
}

///|
pub(all) enum DocxStructuralKind {
  SectionProperties
  BookmarkBoundary
  ProofError
  PermissionBoundary
  CommentRangeBoundary
  MoveRangeBoundary
  LastRenderedPageBreak
  UnknownNonVisible
} derive(Eq)

///|
pub(all) enum DocxMediaRelationshipKind {
  Embed
  Link
  Unknown
} derive(Eq)

///|
pub(all) enum DocxMediaContainerKind {
  Drawing
  Pict
} derive(Eq)

///|
pub(all) enum DocxBreakKind {
  Line
  Page
  Column
  TextWrapping
  CarriageReturn
  Unknown
} derive(Eq)

///|
pub(all) enum DocxHyphenKind {
  Soft
  NoBreak
} derive(Eq)

///|
pub struct DocxSourceHyperlink {
  relationship_id : String?
  anchor : String?
  target : String?
  text : String
  target_mode : DocxTargetMode?
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceMediaRef {
  relationship_id : String?
  relationship_kind : DocxMediaRelationshipKind
  container_kind : DocxMediaContainerKind
  target : String?
  resolved_target : String?
  target_mode : DocxTargetMode?
  target_part : String?
  target_exists : Bool?
  content_type : String?
  alt_text : String?
  title : String?
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceTextBoxRef {
  anchor_id : String?
  doc_pr_id : String?
  shape_id : String?
  owner_part : String
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceDrawing {
  anchor_id : String
  owner_part : String
  source_key : DocxSourceKey
  doc_pr_id : String?
  doc_pr_name : String?
  descr : String?
  title : String?
  media : DocxSourceMediaRef?
  alternate_media : Array[DocxSourceMediaRef]
  text_box_ref : DocxSourceTextBoxRef?
  child_inlines : Array[DocxSourceInline]
}

///|
pub struct DocxSourceShape {
  anchor_id : String
  owner_part : String
  source_key : DocxSourceKey
  shape_id : String?
  shape_type : String?
  style : String?
  alt_text : String?
  title : String?
  media : DocxSourceMediaRef?
  text_box_ref : DocxSourceTextBoxRef?
  child_inlines : Array[DocxSourceInline]
}

///|
pub struct DocxSourceField {
  kind : String
  instruction : String?
  field_char_type : String?
  result_text : String?
  child_inlines : Array[DocxSourceInline]
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceMath {
  kind : String
  text_signature : String?
  child_inlines : Array[DocxSourceInline]
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceBookmark {
  kind : DocxBookmarkKind
  bookmark_id : String?
  name : String?
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceTrackedChange {
  kind : String
  text : String
  child_inlines : Array[DocxSourceInline]
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceSymbol {
  font : String?
  char_hex : String?
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceBreak {
  kind : DocxBreakKind
  break_type : String?
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceHyphen {
  kind : DocxHyphenKind
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceUnsupportedInline {
  tag : String
  reason : String
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceSmartTag {
  tag : String
  child_inlines : Array[DocxSourceInline]
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceStructuralMarker {
  kind : DocxStructuralKind
  tag : String
  source_key : DocxSourceKey
}

///|
pub(all) enum DocxSourceInline {
  Text(String)
  Tab
  LineBreak
  Break(DocxSourceBreak)
  Hyperlink(DocxSourceHyperlink)
  Media(DocxSourceMediaRef)
  TextBoxRef(DocxSourceTextBoxRef)
  Drawing(DocxSourceDrawing)
  Shape(DocxSourceShape)
  ContentControl(DocxSourceContentControl)
  FieldUnsupported(DocxSourceField)
  Math(DocxSourceMath)
  Bookmark(DocxSourceBookmark)
  TrackedChange(DocxSourceTrackedChange)
  SmartTag(DocxSourceSmartTag)
  Symbol(DocxSourceSymbol)
  Hyphen(DocxSourceHyphen)
  FootnoteRef(String)
  EndnoteRef(String)
  CommentRef(String)
  StructuralMarker(DocxSourceStructuralMarker)
  UnsupportedInline(DocxSourceUnsupportedInline)
  Unsupported(String)
}

///|
pub struct DocxSourceRun {
  style_id : String?
  bold : Bool
  inlines : Array[DocxSourceInline]
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceTableCell {
  row_index : Int
  cell_index : Int
  blocks : Array[DocxSourceBlock]
  text : String
  grid_span : String?
  vertical_merge : String?
  has_nested_table : Bool
  nesting_depth : Int
  max_nested_depth : Int
  deep_table_guard_triggered : Bool
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceTableRow {
  row_index : Int
  is_header : Bool
  cells : Array[DocxSourceTableCell]
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceTable {
  rows : Array[DocxSourceTableRow]
  nesting_depth : Int
  max_nested_depth : Int
  deep_table_guard_triggered : Bool
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceContentControl {
  tag : String
  blocks : Array[DocxSourceBlock]
  inlines : Array[DocxSourceInline]
  text : String
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceBlock {
  kind : DocxSourceBlockKind
  source_key : DocxSourceKey
  paragraph_style_id : String?
  paragraph_alignment : String?
  numbering_ref : DocxNumberingRef?
  runs : Array[DocxSourceRun]
  table : DocxSourceTable?
  content_control : DocxSourceContentControl?
  text : String
  inlines : Array[DocxSourceInline]
  structural_kind : DocxStructuralKind?
  raw_tag : String?
}

///|
pub struct DocxSourcePart {
  part_name : String
  blocks : Array[DocxSourceBlock]
  warnings : Array[DocxSourceWarning]
}

///|
pub struct DocxSourceDocument {
  main_part : String
  metadata : DocxDocumentMetadata
  part_graph : DocxPartGraph
  parts : Array[DocxSourcePart]
  styles : DocxSourceStyles
  numbering : DocxSourceNumbering
  footnotes : Array[DocxSourceNote]
  endnotes : Array[DocxSourceNote]
  comments : Array[DocxSourceComment]
  headers : Array[DocxSourcePartBody]
  footers : Array[DocxSourcePartBody]
  textboxes : Array[DocxSourceTextBox]
  warnings : Array[DocxSourceWarning]
}

///|
pub struct DocxSourceNote {
  kind : DocxNoteKind
  note_id : String
  part_name : String
  blocks : Array[DocxSourceBlock]
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceComment {
  comment_id : String
  author : String?
  date : String?
  part_name : String
  blocks : Array[DocxSourceBlock]
  source_key : DocxSourceKey
}

///|
pub struct DocxSourcePartBody {
  kind : DocxPartBodyKind
  relationship_id : String?
  slot_type : String?
  part_name : String
  blocks : Array[DocxSourceBlock]
  source_key : DocxSourceKey
}

///|
pub struct DocxSourceTextBox {
  anchor_id : String
  owner_part : String
  relationship_id : String?
  part_name : String
  blocks : Array[DocxSourceBlock]
  source_key : DocxSourceKey
  shape_id : String?
  doc_pr_id : String?
  doc_pr_name : String?
  descr : String?
  title : String?
}

///|
pub(all) enum DocxInline {
  Text(String)
  Tab
  LineBreak
  Break(DocxBreak)
  Hyperlink(DocxHyperlink)
  Media(DocxMediaRef)
  TextBoxRef(DocxTextBoxRef)
  Drawing(DocxDrawing)
  Shape(DocxShape)
  ContentControl(DocxContentControl)
  FieldUnsupported(DocxField)
  Math(DocxMath)
  Bookmark(DocxBookmark)
  TrackedChange(DocxTrackedChange)
  SmartTag(DocxSmartTag)
  Symbol(DocxSymbol)
  Hyphen(DocxHyphen)
  FootnoteRef(String)
  EndnoteRef(String)
  CommentRef(String)
  StructuralMarker(DocxStructuralMarker)
  UnsupportedInline(DocxUnsupportedInline)
  Unsupported(String)
}

///|
pub struct DocxHyperlink {
  relationship_id : String?
  anchor : String?
  target : String?
  text : String
  target_mode : DocxTargetMode?
  source_key : DocxSourceKey
}

///|
pub struct DocxMediaRef {
  relationship_id : String?
  relationship_kind : DocxMediaRelationshipKind
  container_kind : DocxMediaContainerKind
  target : String?
  resolved_target : String?
  target_mode : DocxTargetMode?
  target_part : String?
  target_exists : Bool?
  content_type : String?
  alt_text : String?
  title : String?
  source_key : DocxSourceKey
}

///|
pub struct DocxTextBoxRef {
  anchor_id : String?
  doc_pr_id : String?
  shape_id : String?
  owner_part : String
  source_key : DocxSourceKey
}

///|
pub struct DocxDrawing {
  anchor_id : String
  owner_part : String
  source_key : DocxSourceKey
  doc_pr_id : String?
  doc_pr_name : String?
  descr : String?
  title : String?
  media : DocxMediaRef?
  alternate_media : Array[DocxMediaRef]
  text_box_ref : DocxTextBoxRef?
  child_inlines : Array[DocxInline]
}

///|
pub struct DocxShape {
  anchor_id : String
  owner_part : String
  source_key : DocxSourceKey
  shape_id : String?
  shape_type : String?
  style : String?
  alt_text : String?
  title : String?
  media : DocxMediaRef?
  text_box_ref : DocxTextBoxRef?
  child_inlines : Array[DocxInline]
}

///|
pub struct DocxStyle {
  style_id : String
  style_type : String?
  name : String?
  based_on : String?
  paragraph_properties : Array[String]
  source_key : DocxSourceKey
}

///|
pub struct DocxStyles {
  part_name : String?
  styles : Array[DocxStyle]
}

///|
pub struct DocxNumberingNum {
  num_id : String
  abstract_num_id : String?
  start_overrides : Array[DocxNumberingStartOverride]
  source_key : DocxSourceKey
}

///|
pub struct DocxNumberingLevel {
  abstract_num_id : String
  ilvl : String
  num_fmt : String?
  start : String?
  lvl_text : String?
  paragraph_style_id : String?
  style_link : String?
  num_style_link : String?
  source_key : DocxSourceKey
}

///|
pub struct DocxNumbering {
  part_name : String?
  nums : Array[DocxNumberingNum]
  levels : Array[DocxNumberingLevel]
}

///|
pub struct DocxField {
  kind : String
  instruction : String?
  field_char_type : String?
  result_text : String?
  child_inlines : Array[DocxInline]
  source_key : DocxSourceKey
}

///|
pub struct DocxMath {
  kind : String
  text_signature : String?
  child_inlines : Array[DocxInline]
  source_key : DocxSourceKey
}

///|
pub struct DocxBookmark {
  kind : DocxBookmarkKind
  bookmark_id : String?
  name : String?
  source_key : DocxSourceKey
}

///|
pub struct DocxTrackedChange {
  kind : String
  text : String
  child_inlines : Array[DocxInline]
  source_key : DocxSourceKey
}

///|
pub struct DocxSmartTag {
  tag : String
  child_inlines : Array[DocxInline]
  source_key : DocxSourceKey
}

///|
pub struct DocxSymbol {
  font : String?
  char_hex : String?
  source_key : DocxSourceKey
}

///|
pub struct DocxBreak {
  kind : DocxBreakKind
  break_type : String?
  source_key : DocxSourceKey
}

///|
pub struct DocxHyphen {
  kind : DocxHyphenKind
  source_key : DocxSourceKey
}

///|
pub struct DocxUnsupportedInline {
  tag : String
  reason : String
  source_key : DocxSourceKey
}

///|
pub struct DocxRun {
  style_id : String?
  bold : Bool
  inlines : Array[DocxInline]
  source_key : DocxSourceKey
}

///|
pub struct DocxParagraph {
  style_id : String?
  alignment : String?
  numbering_ref : DocxNumberingRef?
  runs : Array[DocxRun]
  inlines : Array[DocxInline]
  text : String
  source_key : DocxSourceKey
}

///|
pub struct DocxTableCell {
  row_index : Int
  cell_index : Int
  blocks : Array[DocxBlock]
  text : String
  grid_span : String?
  vertical_merge : String?
  has_nested_table : Bool
  nesting_depth : Int
  max_nested_depth : Int
  deep_table_guard_triggered : Bool
  source_key : DocxSourceKey
}

///|
pub struct DocxTableRow {
  row_index : Int
  is_header : Bool
  cells : Array[DocxTableCell]
  source_key : DocxSourceKey
}

///|
pub struct DocxTable {
  rows : Array[DocxTableRow]
  nesting_depth : Int
  max_nested_depth : Int
  deep_table_guard_triggered : Bool
  source_key : DocxSourceKey
}

///|
pub struct DocxTablePlaceholder {
  source_key : DocxSourceKey
}

///|
pub struct DocxStructuralMarker {
  kind : DocxStructuralKind
  tag : String
  source_key : DocxSourceKey
}

///|
pub struct DocxContentControl {
  tag : String
  blocks : Array[DocxBlock]
  inlines : Array[DocxInline]
  text : String
  source_key : DocxSourceKey
}

///|
pub struct DocxWarning {
  kind : DocxWarningKind
  severity : DocxWarningSeverity
  message : String
  source_key : DocxSourceKey?
}

///|
pub(all) enum DocxBlock {
  Paragraph(DocxParagraph)
  Table(DocxTable)
  TablePlaceholder(DocxTablePlaceholder)
  ContentControl(DocxContentControl)
  StructuralMarker(DocxStructuralMarker)
  Unsupported(DocxWarning)
}

///|
pub struct DocxDocument {
  main_part : String
  metadata : DocxDocumentMetadata
  part_graph : DocxPartGraph
  body : Array[DocxBlock]
  styles : DocxStyles
  numbering : DocxNumbering
  footnotes : Array[DocxNote]
  endnotes : Array[DocxNote]
  comments : Array[DocxComment]
  headers : Array[DocxPartBody]
  footers : Array[DocxPartBody]
  textboxes : Array[DocxTextBox]
  warnings : Array[DocxWarning]
}

///|
pub struct DocxNote {
  kind : DocxNoteKind
  note_id : String
  part_name : String
  blocks : Array[DocxBlock]
  source_key : DocxSourceKey
}

///|
pub struct DocxComment {
  comment_id : String
  author : String?
  date : String?
  part_name : String
  blocks : Array[DocxBlock]
  source_key : DocxSourceKey
}

///|
pub struct DocxPartBody {
  kind : DocxPartBodyKind
  relationship_id : String?
  slot_type : String?
  part_name : String
  blocks : Array[DocxBlock]
  source_key : DocxSourceKey
}

///|
pub struct DocxTextBox {
  anchor_id : String
  owner_part : String
  relationship_id : String?
  part_name : String
  blocks : Array[DocxBlock]
  source_key : DocxSourceKey
  shape_id : String?
  doc_pr_id : String?
  doc_pr_name : String?
  descr : String?
  title : String?
}

///|
pub impl Show for DocxError with fn to_string(self : DocxError) -> String {
  match self {
    OoxmlFailure(msg) => "docx ooxml failure: " + msg
    MissingMainDocument => "docx missing main document"
    MalformedDocument(msg) => "docx malformed document: " + msg
  }
}

///|
pub impl Show for DocxError with fn output(self : DocxError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
