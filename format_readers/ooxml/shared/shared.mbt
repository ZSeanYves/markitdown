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

///|
pub fn office_document_kind_name(kind : OfficeDocumentKind) -> String {
  match kind {
    OfficeDocumentKind::Docx => "docx"
    OfficeDocumentKind::Pptx => "pptx"
    OfficeDocumentKind::Xlsx => "xlsx"
    OfficeDocumentKind::Unknown => "unknown"
  }
}

///|
pub fn office_security_finding_name(finding : OfficeSecurityFinding) -> String {
  match finding {
    OfficeSecurityFinding::UnsafePartPath => "unsafe_part_path"
    OfficeSecurityFinding::DuplicateNormalizedPart =>
      "duplicate_normalized_part"
    OfficeSecurityFinding::MissingRelationshipTarget =>
      "missing_relationship_target"
    OfficeSecurityFinding::UnsupportedRelationship => "unsupported_relationship"
    OfficeSecurityFinding::ExternalRelationship => "external_relationship"
    OfficeSecurityFinding::EncryptedEntry => "encrypted_entry"
    OfficeSecurityFinding::UnsupportedCompression => "unsupported_compression"
    OfficeSecurityFinding::ResourceLimitHit => "resource_limit_hit"
    OfficeSecurityFinding::PathTraversal => "path_traversal"
  }
}

///|
pub fn office_asset_copy_policy_name(policy : OfficeAssetCopyPolicy) -> String {
  match policy {
    OfficeAssetCopyPolicy::MaterializeAtOutputBoundary =>
      "materialize_at_output_boundary"
    OfficeAssetCopyPolicy::ReferenceOnly => "reference_only"
    OfficeAssetCopyPolicy::RejectUnsafePath => "reject_unsafe_path"
  }
}

///|
pub fn make_office_part(
  part_name : String,
  normalized_part_name? : String? = None,
  content_type? : String? = None,
  relationship_type? : String? = None,
  size? : Int? = None,
  source_ref? : @core.SourceRef? = None,
  security_findings? : Array[OfficeSecurityFinding] = [],
) -> OfficePart {
  {
    part_name,
    normalized_part_name,
    content_type,
    relationship_type,
    size,
    source_ref,
    security_findings,
  }
}

///|
pub fn make_office_relationship(
  source_part : String,
  relationship_id : String,
  relationship_type : String,
  target : String,
  target_mode? : String = "Internal",
  normalized_target? : String? = None,
  is_external? : Bool = false,
  source_ref? : @core.SourceRef? = None,
  security_findings? : Array[OfficeSecurityFinding] = [],
) -> OfficeRelationship {
  {
    source_part,
    relationship_id,
    relationship_type,
    target,
    target_mode,
    normalized_target,
    is_external,
    source_ref,
    security_findings,
  }
}

///|
pub fn make_office_content_type(
  content_type : String,
  extension? : String? = None,
  part_name? : String? = None,
  source_ref? : @core.SourceRef? = None,
) -> OfficeContentType {
  { extension, part_name, content_type, source_ref }
}

///|
pub fn make_office_media_asset(
  part_name : String,
  content_type? : String? = None,
  relationship_id? : String? = None,
  source_part? : String? = None,
  size? : Int? = None,
  source_ref? : @core.SourceRef? = None,
) -> OfficeMediaAsset {
  { part_name, content_type, relationship_id, source_part, size, source_ref }
}

///|
pub fn make_office_asset_plan(
  media_part : String,
  output_relative_path : String,
  copy_policy? : OfficeAssetCopyPolicy = OfficeAssetCopyPolicy::MaterializeAtOutputBoundary,
  source_ref? : @core.SourceRef? = None,
) -> OfficeAssetPlan {
  { media_part, output_relative_path, copy_policy, source_ref }
}

///|
pub fn make_office_package(
  document_kind : OfficeDocumentKind,
  parts : Array[OfficePart],
  relationships : Array[OfficeRelationship],
  content_types : Array[OfficeContentType],
  media_assets : Array[OfficeMediaAsset],
  container_path? : String? = None,
  source_id? : String? = None,
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
  source_ref? : @core.SourceRef? = None,
) -> OfficePackage {
  {
    document_kind,
    container_path,
    source_id,
    parts,
    relationships,
    content_types,
    media_assets,
    diagnostics,
    source_ref,
  }
}

///|
pub fn make_office_semantic_plan(
  document_kind : OfficeDocumentKind,
  office_package : OfficePackage,
  semantic_model_kind : String,
  ordered_units : Array[String],
  asset_plans : Array[OfficeAssetPlan],
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
) -> OfficeSemanticPlan {
  {
    document_kind,
    office_package,
    semantic_model_kind,
    ordered_units,
    asset_plans,
    diagnostics,
  }
}

///|
pub fn pptx_slide_visibility_name(visibility : PptxSlideVisibility) -> String {
  match visibility {
    PptxSlideVisibility::Visible => "visible"
    PptxSlideVisibility::Hidden => "hidden"
  }
}

///|
pub fn pptx_shape_type_name(shape_type : PptxShapeType) -> String {
  match shape_type {
    PptxShapeType::Title => "title"
    PptxShapeType::Subtitle => "subtitle"
    PptxShapeType::Body => "body"
    PptxShapeType::TextBox => "text_box"
    PptxShapeType::Picture => "picture"
    PptxShapeType::Table => "table"
    PptxShapeType::Chart => "chart"
    PptxShapeType::SmartArt => "smart_art"
    PptxShapeType::Media => "media"
    PptxShapeType::Connector => "connector"
    PptxShapeType::Group => "group"
    PptxShapeType::Placeholder => "placeholder"
    PptxShapeType::NotesAnchor => "notes_anchor"
    PptxShapeType::Decorative => "decorative"
    PptxShapeType::Unknown => "unknown"
  }
}

///|
pub fn pptx_placeholder_origin_name(origin : PptxPlaceholderOrigin) -> String {
  match origin {
    PptxPlaceholderOrigin::DirectSlide => "direct_slide"
    PptxPlaceholderOrigin::LayoutPlaceholder => "layout_placeholder"
    PptxPlaceholderOrigin::MasterPlaceholder => "master_placeholder"
    PptxPlaceholderOrigin::GeometryInference => "geometry_inference"
    PptxPlaceholderOrigin::Unresolved => "unresolved"
  }
}

///|
pub fn pptx_reading_order_strategy_name(
  strategy : PptxReadingOrderStrategy,
) -> String {
  match strategy {
    PptxReadingOrderStrategy::PresentationOrder => "presentation_order"
    PptxReadingOrderStrategy::PlaceholderThenGeometry =>
      "placeholder_then_geometry"
    PptxReadingOrderStrategy::GeometryOnly => "geometry_only"
    PptxReadingOrderStrategy::ExplicitZOrder => "explicit_z_order"
    PptxReadingOrderStrategy::Unknown => "unknown"
  }
}

///|
pub fn make_pptx_theme_model(
  theme_name? : String? = None,
  part_name? : String? = None,
  color_scheme_name? : String? = None,
  font_scheme_name? : String? = None,
  source_ref? : @core.SourceRef? = None,
) -> PptxThemeModel {
  { theme_name, part_name, color_scheme_name, font_scheme_name, source_ref }
}

///|
pub fn make_pptx_master_model(
  master_name? : String? = None,
  part_name? : String? = None,
  theme_part? : String? = None,
  placeholder_count? : Int = 0,
  source_ref? : @core.SourceRef? = None,
) -> PptxMasterModel {
  { master_name, part_name, theme_part, placeholder_count, source_ref }
}

///|
pub fn make_pptx_layout_model(
  layout_name? : String? = None,
  part_name? : String? = None,
  master_part? : String? = None,
  theme_part? : String? = None,
  placeholder_count? : Int = 0,
  source_ref? : @core.SourceRef? = None,
) -> PptxLayoutModel {
  {
    layout_name,
    part_name,
    master_part,
    theme_part,
    placeholder_count,
    source_ref,
  }
}

///|
pub fn make_pptx_placeholder_model(
  placeholder_type : String,
  placeholder_index? : String? = None,
  placeholder_name? : String? = None,
  resolved_from? : PptxPlaceholderOrigin = PptxPlaceholderOrigin::Unresolved,
  source_ref? : @core.SourceRef? = None,
) -> PptxPlaceholderModel {
  {
    placeholder_type,
    placeholder_index,
    placeholder_name,
    resolved_from,
    source_ref,
  }
}

///|
pub fn make_pptx_text_run_model(
  text : String,
  hyperlink_target? : String? = None,
  relationship_id? : String? = None,
  source_ref? : @core.SourceRef? = None,
) -> PptxTextRunModel {
  { text, hyperlink_target, relationship_id, source_ref }
}

///|
pub fn make_pptx_paragraph_model(
  paragraph_index : Int,
  runs : Array[PptxTextRunModel],
  level? : Int? = None,
  bullet_kind? : String? = None,
  source_ref? : @core.SourceRef? = None,
) -> PptxParagraphModel {
  { paragraph_index, runs, level, bullet_kind, source_ref }
}

///|
pub fn make_pptx_image_model(
  asset_part? : String? = None,
  content_type? : String? = None,
  alt_text? : String? = None,
  title? : String? = None,
  relationship_id? : String? = None,
  source_ref? : @core.SourceRef? = None,
) -> PptxImageModel {
  { asset_part, content_type, alt_text, title, relationship_id, source_ref }
}

///|
pub fn make_pptx_table_cell_model(
  row_index : Int,
  column_index : Int,
  text : String,
  row_span? : Int? = None,
  column_span? : Int? = None,
  source_ref? : @core.SourceRef? = None,
) -> PptxTableCellModel {
  { row_index, column_index, text, row_span, column_span, source_ref }
}

///|
pub fn make_pptx_table_row_model(
  row_index : Int,
  cells : Array[PptxTableCellModel],
  source_ref? : @core.SourceRef? = None,
) -> PptxTableRowModel {
  { row_index, cells, source_ref }
}

///|
pub fn make_pptx_table_model(
  rows : Array[PptxTableRowModel],
  source_ref? : @core.SourceRef? = None,
) -> PptxTableModel {
  { rows, source_ref }
}

///|
pub fn make_pptx_shape_model(
  shape_type : PptxShapeType,
  text_paragraphs? : Array[PptxParagraphModel] = [],
  shape_id? : String? = None,
  shape_name? : String? = None,
  bbox? : @core.BBox? = None,
  table? : PptxTableModel? = None,
  image? : PptxImageModel? = None,
  placeholder? : PptxPlaceholderModel? = None,
  source_ref? : @core.SourceRef? = None,
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
) -> PptxShapeModel {
  {
    shape_id,
    shape_name,
    shape_type,
    bbox,
    text_paragraphs,
    table,
    image,
    placeholder,
    source_ref,
    diagnostics,
  }
}

///|
pub fn make_pptx_notes_model(
  text_blocks : Array[String],
  notes_part? : String? = None,
  source_ref? : @core.SourceRef? = None,
) -> PptxNotesModel {
  { notes_part, text_blocks, source_ref }
}

///|
pub fn make_pptx_comment_model(
  comment_id : String,
  text : String,
  author? : String? = None,
  source_ref? : @core.SourceRef? = None,
) -> PptxCommentModel {
  { comment_id, author, text, source_ref }
}

///|
pub fn make_pptx_reading_order_item(
  reading_order_index : Int,
  slide_index : Int,
  strategy : PptxReadingOrderStrategy,
  shape_id? : String? = None,
  confidence? : String? = None,
  source_ref? : @core.SourceRef? = None,
) -> PptxReadingOrderItem {
  {
    reading_order_index,
    slide_index,
    shape_id,
    strategy,
    confidence,
    source_ref,
  }
}

///|
pub fn make_pptx_slide_model(
  slide_index : Int,
  shapes : Array[PptxShapeModel],
  slide_id? : String? = None,
  slide_part? : String? = None,
  visibility? : PptxSlideVisibility = PptxSlideVisibility::Visible,
  layout_part? : String? = None,
  master_part? : String? = None,
  theme_part? : String? = None,
  notes? : PptxNotesModel? = None,
  comments? : Array[PptxCommentModel] = [],
  reading_order? : Array[PptxReadingOrderItem] = [],
  source_ref? : @core.SourceRef? = None,
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
) -> PptxSlideModel {
  {
    slide_index,
    slide_id,
    slide_part,
    visibility,
    layout_part,
    master_part,
    theme_part,
    shapes,
    notes,
    comments,
    reading_order,
    source_ref,
    diagnostics,
  }
}

///|
pub fn make_pptx_presentation_model(
  slides : Array[PptxSlideModel],
  themes? : Array[PptxThemeModel] = [],
  masters? : Array[PptxMasterModel] = [],
  layouts? : Array[PptxLayoutModel] = [],
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
  source_ref? : @core.SourceRef? = None,
) -> PptxPresentationModel {
  { slides, themes, masters, layouts, diagnostics, source_ref }
}

///|
pub fn make_pptx_presentation_plan(
  presentation : PptxPresentationModel,
  ordered_slide_ids : Array[String],
  hidden_slide_ids? : Array[String] = [],
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
  source_ref? : @core.SourceRef? = None,
) -> PptxPresentationPlan {
  { presentation, ordered_slide_ids, hidden_slide_ids, diagnostics, source_ref }
}

///|
pub fn xlsx_sheet_visibility_name(visibility : XlsxSheetVisibility) -> String {
  match visibility {
    XlsxSheetVisibility::Visible => "visible"
    XlsxSheetVisibility::Hidden => "hidden"
    XlsxSheetVisibility::VeryHidden => "very_hidden"
  }
}

///|
pub fn xlsx_cell_type_name(cell_type : XlsxCellType) -> String {
  match cell_type {
    XlsxCellType::Blank => "blank"
    XlsxCellType::String => "string"
    XlsxCellType::SharedString => "shared_string"
    XlsxCellType::InlineString => "inline_string"
    XlsxCellType::Number => "number"
    XlsxCellType::Bool => "bool"
    XlsxCellType::Error => "error"
    XlsxCellType::DateLike => "date_like"
    XlsxCellType::Formula => "formula"
  }
}

///|
pub fn make_xlsx_shared_string(
  string_index : Int,
  value : String,
  source_ref? : @core.SourceRef? = None,
) -> XlsxSharedString {
  { string_index, value, source_ref }
}

///|
pub fn make_xlsx_formula(
  formula_text : String,
  cached_value? : String? = None,
  formula_ref? : String? = None,
  is_array_formula? : Bool = false,
  is_shared_formula? : Bool = false,
  source_ref? : @core.SourceRef? = None,
) -> XlsxFormula {
  {
    formula_text,
    cached_value,
    formula_ref,
    is_array_formula,
    is_shared_formula,
    source_ref,
  }
}

///|
pub fn make_xlsx_merged_range(
  range_ref : String,
  start_cell : String,
  end_cell : String,
  source_ref? : @core.SourceRef? = None,
) -> XlsxMergedRange {
  { range_ref, start_cell, end_cell, source_ref }
}

///|
pub fn make_xlsx_cell_model(
  cell_ref : String,
  row_index : Int,
  column_index : Int,
  cell_type : XlsxCellType,
  raw_value? : String? = None,
  display_value? : String? = None,
  shared_string_index? : Int? = None,
  style_ref? : @core.StyleRef? = None,
  formula? : XlsxFormula? = None,
  source_ref? : @core.SourceRef? = None,
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
) -> XlsxCellModel {
  {
    cell_ref,
    row_index,
    column_index,
    cell_type,
    raw_value,
    display_value,
    shared_string_index,
    style_ref,
    formula,
    source_ref,
    diagnostics,
  }
}

///|
pub fn make_xlsx_row_model(
  row_index : Int,
  cells : Array[XlsxCellModel],
  source_ref? : @core.SourceRef? = None,
) -> XlsxRowModel {
  { row_index, cells, source_ref }
}

///|
pub fn make_xlsx_sheet_model(
  sheet_name : String,
  rows : Array[XlsxRowModel],
  sheet_id? : String? = None,
  relationship_id? : String? = None,
  part_name? : String? = None,
  visibility? : XlsxSheetVisibility = XlsxSheetVisibility::Visible,
  dimension_ref? : String? = None,
  merged_ranges? : Array[XlsxMergedRange] = [],
  source_ref? : @core.SourceRef? = None,
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
) -> XlsxSheetModel {
  {
    sheet_name,
    sheet_id,
    relationship_id,
    part_name,
    visibility,
    dimension_ref,
    rows,
    merged_ranges,
    source_ref,
    diagnostics,
  }
}

///|
pub fn make_xlsx_workbook_model(
  sheets : Array[XlsxSheetModel],
  shared_strings? : Array[XlsxSharedString] = [],
  styles_summary? : Map[String, @core.JsonValue] = Map([]),
  defined_names? : Array[String] = [],
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
  source_ref? : @core.SourceRef? = None,
) -> XlsxWorkbookModel {
  {
    sheets,
    shared_strings,
    styles_summary,
    defined_names,
    diagnostics,
    source_ref,
  }
}

///|
pub fn make_xlsx_workbook_plan(
  workbook : XlsxWorkbookModel,
  included_sheet_names : Array[String],
  skipped_sheet_names? : Array[String] = [],
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
  source_ref? : @core.SourceRef? = None,
) -> XlsxWorkbookPlan {
  {
    workbook,
    included_sheet_names,
    skipped_sheet_names,
    diagnostics,
    source_ref,
  }
}

///|
pub fn office_source_ref_extra_keys() -> Array[String] {
  [
    "ooxml_part_type", "part_name", "relationship_id", "relationship_type", "target_mode",
    "sheet_name", "sheet_id", "sheet_visibility", "cell_ref", "cell_range", "row_index",
    "column_index", "formula_ref", "shared_string_index", "style_id", "merge_range",
    "slide_index", "slide_id", "slide_part", "layout_part", "master_part", "theme_part",
    "shape_id", "shape_name", "shape_type", "placeholder_type", "placeholder_idx",
    "reading_order_index", "notes_part", "comment_id", "bbox", "paragraph_index",
    "run_index", "block_index",
  ]
}

///|
pub fn office_diagnostic_metric_keys() -> Array[String] {
  [
    "office_document_kind", "ooxml_part_count", "relationship_count", "external_relationship_count",
    "missing_relationship_target_count", "unsupported_relationship_count", "media_asset_count",
    "materialized_asset_count", "skipped_asset_count", "content_type_count", "total_uncompressed_bytes",
    "path_traversal_count", "duplicate_part_count", "encrypted_entry_count", "unsupported_compression_count",
    "resource_limit_hit", "xml_dtd_count", "xml_external_entity_count", "macro_part_count",
    "ole_object_count", "alt_chunk_count", "docx_paragraph_count", "docx_heading_count",
    "docx_table_count", "docx_list_count", "docx_image_count", "docx_hyperlink_count",
    "docx_header_footer_count", "docx_comment_count", "docx_tracked_change_count",
    "fallback_count", "warning_count", "error_count", "issue_count", "pptx_slide_count",
    "pptx_hidden_slide_count", "pptx_shape_count", "pptx_text_box_count", "pptx_placeholder_count",
    "pptx_table_count", "pptx_image_count", "pptx_notes_count", "pptx_layout_count",
    "pptx_master_count", "pptx_theme_count", "pptx_resolved_placeholder_count", "pptx_unresolved_placeholder_count",
    "pptx_comment_count", "pptx_external_media_count", "pptx_reading_order_strategy",
    "external_link_count", "xlsx_sheet_count", "xlsx_hidden_sheet_count", "xlsx_very_hidden_sheet_count",
    "xlsx_row_count", "xlsx_cell_count", "xlsx_non_empty_cell_count", "xlsx_merged_cell_count",
    "xlsx_formula_count", "xlsx_shared_formula_count", "xlsx_array_formula_count",
    "xlsx_shared_string_count", "xlsx_style_count", "xlsx_drawing_count", "xlsx_image_count",
    "fallback_trace", "pass_trace",
  ]
}

///|
pub fn office_resource_limit_keys() -> Array[String] {
  [
    "max_ooxml_parts", "max_total_uncompressed_bytes", "max_single_part_bytes", "max_relationships",
    "max_external_relationships", "max_media_assets", "max_xml_depth", "max_xml_nodes",
    "max_text_bytes", "max_docx_blocks", "max_pptx_slides", "max_pptx_shapes", "max_pptx_text_runs",
    "max_pptx_tables", "max_pptx_images", "max_pptx_notes", "max_pptx_comments",
    "max_xlsx_sheets", "max_xlsx_rows", "max_xlsx_columns", "max_xlsx_cells", "max_xlsx_non_empty_cells",
    "max_shared_strings", "max_formula_count", "max_merged_ranges", "max_materialized_assets",
  ]
}

///|
pub fn office_relationship_guardrails() -> Array[String] {
  [
    "relationship target resolution is package-local by default", "TargetMode=External is no-fetch",
    "relationship traversal outside package-safe normalized boundaries is forbidden",
    "missing targets are diagnosed", "unsupported relationship types are diagnosed",
  ]
}

///|
pub fn office_asset_write_guardrails() -> Array[String] {
  [
    "media asset plans are carried as root-pipeline contracts", "asset writes only happen at the CLI/output boundary",
    "no parser/orchestrator file writes", "no external fetch", "relative output paths only",
  ]
}

///|
pub fn office_asset_output_path_is_safe(path : String) -> Bool {
  let trimmed = path.trim()
  if trimmed == "" {
    return false
  }
  if trimmed.contains("\\") {
    return false
  }
  if trimmed.has_prefix("/") {
    return false
  }
  if trimmed == ".." || trimmed.has_prefix("../") || trimmed.contains("../") {
    return false
  }
  if trimmed.contains("/..") {
    return false
  }
  let chars = trimmed.to_array()
  if chars.length() >= 2 && chars[1] == ':' {
    return false
  }
  true
}

///|
pub fn office_asset_plan_is_safe(plan : OfficeAssetPlan) -> Bool {
  office_asset_output_path_is_safe(plan.output_relative_path)
}

///|
pub fn office_relationship_is_no_fetch(rel : OfficeRelationship) -> Bool {
  rel.is_external || rel.target_mode.trim().to_lower() == "external"
}
