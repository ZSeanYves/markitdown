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
