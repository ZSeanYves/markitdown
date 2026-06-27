///|
pub(all) enum OfficeDocumentKind {
  Docx
  Pptx
  Xlsx
  Unknown
} derive(Eq)

///|
pub(all) enum OfficeSecurityFinding {
  UnsafePartPath
  DuplicateNormalizedPart
  MissingRelationshipTarget
  UnsupportedRelationship
  ExternalRelationship
  EncryptedEntry
  UnsupportedCompression
  ResourceLimitHit
  PathTraversal
} derive(Eq)

///|
pub(all) enum OfficeAssetCopyPolicy {
  MaterializeAtOutputBoundary
  ReferenceOnly
  RejectUnsafePath
} derive(Eq)

///|
pub struct OfficePart {
  part_name : String
  normalized_part_name : String?
  content_type : String?
  relationship_type : String?
  size : Int?
  source_ref : @core.SourceRef?
  security_findings : Array[OfficeSecurityFinding]
}

///|
pub struct OfficeRelationship {
  source_part : String
  relationship_id : String
  relationship_type : String
  target : String
  target_mode : String
  normalized_target : String?
  is_external : Bool
  source_ref : @core.SourceRef?
  security_findings : Array[OfficeSecurityFinding]
}

///|
pub struct OfficeContentType {
  extension : String?
  part_name : String?
  content_type : String
  source_ref : @core.SourceRef?
}

///|
pub struct OfficeMediaAsset {
  part_name : String
  content_type : String?
  relationship_id : String?
  source_part : String?
  size : Int?
  source_ref : @core.SourceRef?
}

///|
pub struct OfficeAssetPlan {
  media_part : String
  output_relative_path : String
  copy_policy : OfficeAssetCopyPolicy
  source_ref : @core.SourceRef?
}

///|
pub struct OfficePackage {
  document_kind : OfficeDocumentKind
  container_path : String?
  source_id : String?
  parts : Array[OfficePart]
  relationships : Array[OfficeRelationship]
  content_types : Array[OfficeContentType]
  media_assets : Array[OfficeMediaAsset]
  diagnostics : @core.Diagnostics
  source_ref : @core.SourceRef?
}

///|
pub struct OfficeSemanticPlan {
  document_kind : OfficeDocumentKind
  office_package : OfficePackage
  semantic_model_kind : String
  ordered_units : Array[String]
  asset_plans : Array[OfficeAssetPlan]
  diagnostics : @core.Diagnostics
}

///|
pub(all) enum PptxSlideVisibility {
  Visible
  Hidden
} derive(Eq)

///|
pub(all) enum PptxShapeType {
  Title
  Subtitle
  Body
  TextBox
  Picture
  Table
  Chart
  SmartArt
  Media
  Connector
  Group
  Placeholder
  NotesAnchor
  Decorative
  Unknown
} derive(Eq)

///|
pub(all) enum PptxPlaceholderOrigin {
  DirectSlide
  LayoutPlaceholder
  MasterPlaceholder
  GeometryInference
  Unresolved
} derive(Eq)

///|
pub(all) enum PptxReadingOrderStrategy {
  PresentationOrder
  PlaceholderThenGeometry
  GeometryOnly
  ExplicitZOrder
  Unknown
} derive(Eq)

///|
pub struct PptxThemeModel {
  theme_name : String?
  part_name : String?
  color_scheme_name : String?
  font_scheme_name : String?
  source_ref : @core.SourceRef?
}

///|
pub struct PptxMasterModel {
  master_name : String?
  part_name : String?
  theme_part : String?
  placeholder_count : Int
  source_ref : @core.SourceRef?
}

///|
pub struct PptxLayoutModel {
  layout_name : String?
  part_name : String?
  master_part : String?
  theme_part : String?
  placeholder_count : Int
  source_ref : @core.SourceRef?
}

///|
pub struct PptxPlaceholderModel {
  placeholder_type : String
  placeholder_index : String?
  placeholder_name : String?
  resolved_from : PptxPlaceholderOrigin
  source_ref : @core.SourceRef?
}

///|
pub struct PptxTextRunModel {
  text : String
  hyperlink_target : String?
  relationship_id : String?
  source_ref : @core.SourceRef?
}

///|
pub struct PptxParagraphModel {
  paragraph_index : Int
  runs : Array[PptxTextRunModel]
  level : Int?
  bullet_kind : String?
  source_ref : @core.SourceRef?
}

///|
pub struct PptxImageModel {
  asset_part : String?
  content_type : String?
  alt_text : String?
  title : String?
  relationship_id : String?
  source_ref : @core.SourceRef?
}

///|
pub struct PptxTableCellModel {
  row_index : Int
  column_index : Int
  text : String
  row_span : Int?
  column_span : Int?
  source_ref : @core.SourceRef?
}

///|
pub struct PptxTableRowModel {
  row_index : Int
  cells : Array[PptxTableCellModel]
  source_ref : @core.SourceRef?
}

///|
pub struct PptxTableModel {
  rows : Array[PptxTableRowModel]
  source_ref : @core.SourceRef?
}

///|
pub struct PptxShapeModel {
  shape_id : String?
  shape_name : String?
  shape_type : PptxShapeType
  bbox : @core.BBox?
  text_paragraphs : Array[PptxParagraphModel]
  table : PptxTableModel?
  image : PptxImageModel?
  placeholder : PptxPlaceholderModel?
  source_ref : @core.SourceRef?
  diagnostics : @core.Diagnostics
}

///|
pub struct PptxNotesModel {
  notes_part : String?
  text_blocks : Array[String]
  source_ref : @core.SourceRef?
}

///|
pub struct PptxCommentModel {
  comment_id : String
  author : String?
  text : String
  source_ref : @core.SourceRef?
}

///|
pub struct PptxReadingOrderItem {
  reading_order_index : Int
  slide_index : Int
  shape_id : String?
  strategy : PptxReadingOrderStrategy
  confidence : String?
  source_ref : @core.SourceRef?
}

///|
pub struct PptxSlideModel {
  slide_index : Int
  slide_id : String?
  slide_part : String?
  visibility : PptxSlideVisibility
  layout_part : String?
  master_part : String?
  theme_part : String?
  shapes : Array[PptxShapeModel]
  notes : PptxNotesModel?
  comments : Array[PptxCommentModel]
  reading_order : Array[PptxReadingOrderItem]
  source_ref : @core.SourceRef?
  diagnostics : @core.Diagnostics
}

///|
pub struct PptxPresentationModel {
  slides : Array[PptxSlideModel]
  themes : Array[PptxThemeModel]
  masters : Array[PptxMasterModel]
  layouts : Array[PptxLayoutModel]
  diagnostics : @core.Diagnostics
  source_ref : @core.SourceRef?
}

///|
pub struct PptxPresentationPlan {
  presentation : PptxPresentationModel
  ordered_slide_ids : Array[String]
  hidden_slide_ids : Array[String]
  diagnostics : @core.Diagnostics
  source_ref : @core.SourceRef?
}

///|
pub(all) enum XlsxSheetVisibility {
  Visible
  Hidden
  VeryHidden
} derive(Eq)

///|
pub(all) enum XlsxCellType {
  Blank
  String
  SharedString
  InlineString
  Number
  Bool
  Error
  DateLike
  Formula
} derive(Eq)

///|
pub struct XlsxSharedString {
  string_index : Int
  value : String
  source_ref : @core.SourceRef?
}

///|
pub struct XlsxFormula {
  formula_text : String
  cached_value : String?
  formula_ref : String?
  is_array_formula : Bool
  is_shared_formula : Bool
  source_ref : @core.SourceRef?
}

///|
pub struct XlsxMergedRange {
  range_ref : String
  start_cell : String
  end_cell : String
  source_ref : @core.SourceRef?
}

///|
pub struct XlsxCellModel {
  cell_ref : String
  row_index : Int
  column_index : Int
  cell_type : XlsxCellType
  raw_value : String?
  display_value : String?
  shared_string_index : Int?
  style_ref : @core.StyleRef?
  formula : XlsxFormula?
  source_ref : @core.SourceRef?
  diagnostics : @core.Diagnostics
}

///|
pub struct XlsxRowModel {
  row_index : Int
  cells : Array[XlsxCellModel]
  source_ref : @core.SourceRef?
}

///|
pub struct XlsxSheetModel {
  sheet_name : String
  sheet_id : String?
  relationship_id : String?
  part_name : String?
  visibility : XlsxSheetVisibility
  dimension_ref : String?
  rows : Array[XlsxRowModel]
  merged_ranges : Array[XlsxMergedRange]
  source_ref : @core.SourceRef?
  diagnostics : @core.Diagnostics
}

///|
pub struct XlsxWorkbookModel {
  sheets : Array[XlsxSheetModel]
  shared_strings : Array[XlsxSharedString]
  styles_summary : Map[String, @core.JsonValue]
  defined_names : Array[String]
  diagnostics : @core.Diagnostics
  source_ref : @core.SourceRef?
}

///|
pub struct XlsxWorkbookPlan {
  workbook : XlsxWorkbookModel
  included_sheet_names : Array[String]
  skipped_sheet_names : Array[String]
  diagnostics : @core.Diagnostics
  source_ref : @core.SourceRef?
}
