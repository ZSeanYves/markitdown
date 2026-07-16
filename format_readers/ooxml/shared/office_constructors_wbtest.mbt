///|
test "Office constructor enum names cover every public variant" {
  assert_true(
    [
      office_document_kind_name(Docx),
      office_document_kind_name(Pptx),
      office_document_kind_name(Xlsx),
      office_document_kind_name(Unknown),
    ] ==
    ["docx", "pptx", "xlsx", "unknown"],
  )
  let findings = [
    OfficeSecurityFinding::UnsafePartPath,
    DuplicateNormalizedPart,
    MissingRelationshipTarget,
    UnsupportedRelationship,
    ExternalRelationship,
    EncryptedEntry,
    UnsupportedCompression,
    ResourceLimitHit,
    PathTraversal,
  ].map(office_security_finding_name)
  assert_eq(findings.length(), 9)
  assert_true(findings.contains("path_traversal"))
  assert_true(
    [
      office_asset_copy_policy_name(MaterializeAtOutputBoundary),
      office_asset_copy_policy_name(ReferenceOnly),
      office_asset_copy_policy_name(RejectUnsafePath),
    ] ==
    ["materialize_at_output_boundary", "reference_only", "reject_unsafe_path"],
  )
  assert_true(
    [pptx_slide_visibility_name(Visible), pptx_slide_visibility_name(Hidden)] ==
    ["visible", "hidden"],
  )
  let shape_names = [
    PptxShapeType::Title,
    Subtitle,
    Body,
    TextBox,
    Picture,
    Table,
    Chart,
    SmartArt,
    Media,
    Connector,
    Group,
    Placeholder,
    NotesAnchor,
    Decorative,
    Unknown,
  ].map(pptx_shape_type_name)
  assert_eq(shape_names.length(), 15)
  assert_true(
    shape_names.contains("text_box") && shape_names.contains("unknown"),
  )
  assert_true(
    [
      pptx_placeholder_origin_name(DirectSlide),
      pptx_placeholder_origin_name(LayoutPlaceholder),
      pptx_placeholder_origin_name(MasterPlaceholder),
      pptx_placeholder_origin_name(GeometryInference),
      pptx_placeholder_origin_name(Unresolved),
    ] ==
    [
      "direct_slide", "layout_placeholder", "master_placeholder", "geometry_inference",
      "unresolved",
    ],
  )
  assert_true(
    [
      pptx_reading_order_strategy_name(PresentationOrder),
      pptx_reading_order_strategy_name(PlaceholderThenGeometry),
      pptx_reading_order_strategy_name(GeometryOnly),
      pptx_reading_order_strategy_name(ExplicitZOrder),
      pptx_reading_order_strategy_name(Unknown),
    ] ==
    [
      "presentation_order", "placeholder_then_geometry", "geometry_only", "explicit_z_order",
      "unknown",
    ],
  )
  assert_true(
    [
      xlsx_sheet_visibility_name(Visible),
      xlsx_sheet_visibility_name(Hidden),
      xlsx_sheet_visibility_name(VeryHidden),
    ] ==
    ["visible", "hidden", "very_hidden"],
  )
  let cell_names = [
    XlsxCellType::Blank,
    String,
    SharedString,
    InlineString,
    Number,
    Bool,
    Error,
    DateLike,
    Formula,
  ].map(xlsx_cell_type_name)
  assert_eq(cell_names.length(), 9)
  assert_true(
    cell_names.contains("shared_string") && cell_names.contains("date_like"),
  )
}

///|
test "Office model constructors preserve defaults and nested contracts" {
  let part = make_office_part(
    "word/document.xml",
    content_type=Some("xml"),
    size=Some(12),
  )
  let rel = make_office_relationship(
    "", "rId1", "officeDocument", "word/document.xml",
  )
  let content_type = make_office_content_type(
    "application/xml",
    extension=Some("xml"),
  )
  let media = make_office_media_asset(
    "word/media/a.png",
    content_type=Some("image/png"),
  )
  let asset_plan = make_office_asset_plan("word/media/a.png", "assets/a.png")
  let office_package = make_office_package(
    Docx,
    [part],
    [rel],
    [content_type],
    [media],
    container_path=Some("sample.docx"),
  )
  let semantic = make_office_semantic_plan(
    Docx,
    office_package,
    "document",
    ["word/document.xml"],
    [asset_plan],
  )
  assert_eq(semantic.office_package.parts.length(), 1)
  assert_true(
    semantic.asset_plans[0].copy_policy == MaterializeAtOutputBoundary,
  )
  let theme = make_pptx_theme_model(theme_name=Some("Office"))
  let master = make_pptx_master_model(master_name=Some("Master"))
  let layout = make_pptx_layout_model(layout_name=Some("Title"))
  let placeholder = make_pptx_placeholder_model("title")
  let run = make_pptx_text_run_model("Hello")
  let paragraph = make_pptx_paragraph_model(0, [run])
  let image = make_pptx_image_model(asset_part=Some("ppt/media/a.png"))
  let cell = make_pptx_table_cell_model(0, 0, "A")
  let table = make_pptx_table_model([make_pptx_table_row_model(0, [cell])])
  let shape = make_pptx_shape_model(
    Title,
    text_paragraphs=[paragraph],
    image=Some(image),
    table=Some(table),
    placeholder=Some(placeholder),
  )
  let notes = make_pptx_notes_model(["note"])
  let comment = make_pptx_comment_model("1", "comment")
  let order = make_pptx_reading_order_item(0, 1, PresentationOrder)
  let slide = make_pptx_slide_model(
    1,
    [shape],
    notes=Some(notes),
    comments=[comment],
    reading_order=[order],
  )
  let presentation = make_pptx_presentation_model(
    [slide],
    themes=[theme],
    masters=[master],
    layouts=[layout],
  )
  let plan = make_pptx_presentation_plan(presentation, ["1"])
  assert_eq(plan.presentation.slides.length(), 1)
  let shared = make_xlsx_shared_string(0, "Hello")
  let formula = make_xlsx_formula("SUM(A1:A2)", cached_value=Some("3"))
  let merged = make_xlsx_merged_range("A1:B1", "A1", "B1")
  let xcell = make_xlsx_cell_model("A1", 1, 1, Formula, formula=Some(formula))
  let row = make_xlsx_row_model(1, [xcell])
  let sheet = make_xlsx_sheet_model("Sheet1", [row], merged_ranges=[merged])
  let workbook = make_xlsx_workbook_model([sheet], shared_strings=[shared])
  let workbook_plan = make_xlsx_workbook_plan(workbook, ["Sheet1"])
  assert_eq(workbook_plan.workbook.sheets[0].rows[0].cells.length(), 1)
}
