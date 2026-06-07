///|
pub(all) suberror PptxError {
  OpenFailed(String)
  OoxmlFailure(String)
  ParseError(String)
}

///|
pub impl Show for PptxError with fn output(self, logger) {
  match self {
    OpenFailed(msg) => logger.write_string("pptx open failed: " + msg)
    OoxmlFailure(msg) => logger.write_string("pptx ooxml failure: " + msg)
    ParseError(msg) => logger.write_string("pptx parse error: " + msg)
  }
}

///|
pub struct PptxSourceKey {
  part_name : String
  node_key : String
}

///|
pub struct PptxSourceSpan {
  part_name : String
  node_key : String
  start_offset : Int?
  end_offset : Int?
}

///|
pub(all) enum PptxWarningSeverity {
  Info
  Warning
  Error
} derive(Eq)

///|
pub(all) enum PptxWarningKind {
  MissingPresentation
  MissingSlideRelationship
  MissingSlidePart
  MissingRelationshipTarget
  MissingMediaPart
  UnsupportedObject
  UnsupportedMedia
  ExternalMedia
  MissingCommentAuthor
  OverBudget
  MalformedXml
} derive(Eq)

///|
pub struct PptxCustomProperty {
  name : String
  value : String
  value_type : String?
}

///|
pub struct PptxDocumentMetadata {
  title : String?
  subject : String?
  creator : String?
  description : String?
  keywords : String?
  created : String?
  modified : String?
  application : String?
  pages : String?
  words : String?
  slides : String?
  sheets : String?
  custom_properties : Array[PptxCustomProperty]
}

///|
pub struct PptxWarning {
  kind : PptxWarningKind
  severity : PptxWarningSeverity
  message : String
  source_span : PptxSourceSpan?
  relationship_id : String?
  object_ref : String?
}

///|
pub(all) enum PptxTargetMode {
  Internal
  External
} derive(Eq)

///|
pub struct PptxRelationshipV2 {
  source_part : String
  id : String
  rel_type : String
  target : String
  target_mode : PptxTargetMode
  resolved_target : String
}

///|
pub struct PptxPartInfoV2 {
  part_name : String
  content_type : String?
  size : Int
  is_relationships_part : Bool
  has_relationships : Bool
}

///|
pub struct PptxRelationshipSetV2 {
  source_part : String
  relationships : Array[PptxRelationshipV2]
}

///|
pub struct PptxPartGraph {
  parts : Array[PptxPartInfoV2]
  relationships : Array[PptxRelationshipSetV2]
  root_presentation_part : String?
  warnings : Array[PptxWarning]
}

///|
pub struct PptxSlideRefV2 {
  slide_id : String?
  slide_index : Int
  part_name : String
  relationship_id : String?
  hidden : Bool
  source_key : PptxSourceKey
}

///|
pub struct PptxSourcePresentation {
  part_name : String
  slide_refs : Array[PptxSlideRefV2]
  source_key : PptxSourceKey
}

///|
pub(all) enum PptxSourceObjectKind {
  Shape
  TextBox
  Picture
  GraphicFrame
  Table
  Chart
  SmartArt
  Ole
  Group
  Connector
  Unknown
} derive(Eq)

///|
pub(all) enum PptxObjectKind {
  Shape
  TextBox
  Picture
  Table
  Chart
  SmartArt
  Ole
  Group
  Connector
  Unsupported
} derive(Eq)

///|
pub(all) enum PptxPlaceholderKind {
  Title
  CenterTitle
  Subtitle
  Body
  Footer
  Date
  SlideNumber
  Picture
  Table
  Unknown
} derive(Eq)

///|
pub(all) enum PptxPlaceholderResolutionSource {
  Direct
  LayoutTypeIndex
  MasterTypeIndex
  TypeOnly
  GeometryNameInference
  Unknown
} derive(Eq)

///|
pub(all) enum PptxConfidence {
  High
  Medium
  Low
} derive(Eq)

///|
pub struct PptxPlaceholder {
  kind : PptxPlaceholderKind
  index : String?
  raw_type : String?
}

///|
pub struct PptxResolvedPlaceholderHint {
  kind : PptxPlaceholderKind
  index : String?
  source : PptxPlaceholderResolutionSource
  confidence : PptxConfidence
  reason : String
  trace : Array[PptxSourceKey]
}

///|
pub struct PptxGeometry {
  x : Int?
  y : Int?
  width : Int?
  height : Int?
  rotation : Int?
}

///|
pub(all) enum PptxReadingBucket {
  Title
  Subtitle
  Body
  Table
  Image
  CaptionLike
  NoteLike
  Footer
  Decorative
  Unknown
} derive(Eq)

///|
pub struct PptxReadingOrderHint {
  bucket : PptxReadingBucket
  priority : Int
  order_key : String
  confidence : PptxConfidence
  reason : String
}

///|
pub(all) enum PptxLayoutRegionKind {
  TitleLike
  BodyLike
  TwoColumn
  TableLike
  GridLike
  CardLike
  CaptionLike
  ImageCaptionPair
  FooterLike
  Decorative
  Unknown
} derive(Eq)

///|
pub struct PptxLayoutRegionHint {
  kind : PptxLayoutRegionKind
  members : Array[PptxSourceKey]
  confidence : PptxConfidence
  reason : String
  order_key : String
}

///|
pub struct PptxImageCaptionPair {
  owning_slide_part : String
  picture_key : PptxSourceKey
  caption_key : PptxSourceKey
  caption_text : String
  image_shape_id : String?
  image_name : String?
  image_alt_text : String?
  image_title : String?
  image_geometry : PptxGeometry?
  confidence : PptxConfidence
  reason : String
}

///|
pub(all) enum PptxBulletKind {
  Unordered
  Ordered
} derive(Eq)

///|
pub struct PptxListHint {
  level : Int
  bullet : PptxBulletKind?
  source : String
  confidence : PptxConfidence
}

///|
pub struct PptxHyperlink {
  relationship_id : String?
  target : String?
  anchor : String?
  is_external : Bool
  broken : Bool
  source_key : PptxSourceKey
}

///|
pub(all) enum PptxInline {
  Text(String)
  Break
  Field(String)
  Hyperlink(PptxHyperlink, String)
  Unsupported(PptxUnsupported)
}

///|
pub struct PptxRun {
  inlines : Array[PptxInline]
  source_key : PptxSourceKey
}

///|
pub struct PptxParagraph {
  runs : Array[PptxRun]
  list_hint : PptxListHint?
  source_key : PptxSourceKey
}

///|
pub struct PptxTextBody {
  paragraphs : Array[PptxParagraph]
  source_key : PptxSourceKey
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
  source_part : String
  target : String?
  resolved_target : String?
  target_mode : PptxTargetMode?
  content_type : String?
  original_extension : String?
  resolved_extension : String?
  alt_text : String?
  title : String?
  kind : PptxMediaKind
  is_external : Bool
  unsupported : Bool
  data : Bytes?
  alternate_media : Array[PptxMediaRef]
  source_key : PptxSourceKey
}

///|
pub struct PptxTableCell {
  row_index : Int
  column_index : Int
  paragraphs : Array[PptxParagraph]
  grid_span : Int?
  row_span : Int?
  merge_hint : String?
  source_key : PptxSourceKey
}

///|
pub struct PptxTableRow {
  row_index : Int
  cells : Array[PptxTableCell]
  source_key : PptxSourceKey
}

///|
pub struct PptxTable {
  rows : Array[PptxTableRow]
  geometry : PptxGeometry?
  source_key : PptxSourceKey
}

///|
pub struct PptxChartRef {
  relationship_id : String?
  target_part : String?
  title : String?
  cached_text : Array[String]
  cached_categories : Array[String]
  cached_values : Array[String]
  cached_series : Array[PptxChartSeries]
  source_key : PptxSourceKey
}

///|
pub struct PptxChartSeries {
  name : String?
  categories : Array[String]
  values : Array[String]
  text : Array[String]
}

///|
pub struct PptxSmartArtRef {
  relationship_id : String?
  target_part : String?
  source_key : PptxSourceKey
}

///|
pub struct PptxOleRef {
  relationship_id : String?
  target_part : String?
  source_key : PptxSourceKey
}

///|
pub struct PptxConnector {
  shape_id : String?
  name : String?
  geometry : PptxGeometry?
  source_key : PptxSourceKey
}

///|
pub struct PptxUnsupported {
  kind : String
  message : String
  source_key : PptxSourceKey
}

///|
pub struct PptxShape {
  shape_id : String?
  name : String?
  shape_type : String?
  object_ref : String?
  geometry : PptxGeometry?
  direct_placeholder : PptxPlaceholder?
  placeholder : PptxResolvedPlaceholderHint?
  text_body : PptxTextBody?
  hyperlinks : Array[PptxHyperlink]
  reading_order : PptxReadingOrderHint?
  source_key : PptxSourceKey
}

///|
pub struct PptxPicture {
  shape_id : String?
  name : String?
  object_ref : String?
  media : PptxMediaRef?
  geometry : PptxGeometry?
  reading_order : PptxReadingOrderHint?
  source_key : PptxSourceKey
}

///|
pub struct PptxGroupShape {
  shape_id : String?
  name : String?
  object_ref : String?
  geometry : PptxGeometry?
  children : Array[PptxObject]
  reading_order : PptxReadingOrderHint?
  source_key : PptxSourceKey
}

///|
pub(all) enum PptxObject {
  Shape(PptxShape)
  Group(PptxGroupShape)
  Picture(PptxPicture)
  Table(PptxTable)
  Chart(PptxChartRef)
  SmartArt(PptxSmartArtRef)
  Ole(PptxOleRef)
  Connector(PptxConnector)
  Unsupported(PptxUnsupported)
}

///|
pub struct PptxLayoutRef {
  part_name : String
  relationship_id : String?
}

///|
pub struct PptxMasterRef {
  part_name : String
  relationship_id : String?
}

///|
pub struct PptxPlaceholderCandidate {
  placeholder : PptxPlaceholder
  shape_id : String?
  name : String?
  geometry : PptxGeometry?
  source_key : PptxSourceKey
}

///|
pub struct PptxSourceLayout {
  part_name : String
  master_ref : PptxMasterRef?
  placeholders : Array[PptxPlaceholderCandidate]
  source_key : PptxSourceKey
}

///|
pub struct PptxSourceMaster {
  part_name : String
  placeholders : Array[PptxPlaceholderCandidate]
  source_key : PptxSourceKey
}

///|
pub struct PptxSourceSlide {
  slide_ref : PptxSlideRefV2
  layout_ref : PptxLayoutRef?
  master_ref : PptxMasterRef?
  objects : Array[PptxObject]
  notes : PptxNotesSlide?
  comments : Array[PptxComment]
  warnings : Array[PptxWarning]
  source_key : PptxSourceKey
}

///|
pub struct PptxSourceDocument {
  metadata : PptxDocumentMetadata
  part_graph : PptxPartGraph
  presentation : PptxSourcePresentation
  slides : Array[PptxSourceSlide]
  layouts : Array[PptxSourceLayout]
  masters : Array[PptxSourceMaster]
  comment_authors : Array[PptxCommentAuthor]
  warnings : Array[PptxWarning]
}

///|
pub struct PptxSlide {
  slide_id : String?
  slide_index : Int
  part_name : String
  relationship_id : String?
  hidden : Bool
  layout_ref : PptxLayoutRef?
  master_ref : PptxMasterRef?
  objects : Array[PptxObject]
  notes : PptxNotesSlide?
  comments : Array[PptxComment]
  layout_regions : Array[PptxLayoutRegionHint]
  image_caption_pairs : Array[PptxImageCaptionPair]
  reading_order : Array[PptxSourceKey]
  warnings : Array[PptxWarning]
  source_key : PptxSourceKey
}

///|
pub struct PptxDocument {
  metadata : PptxDocumentMetadata
  part_graph : PptxPartGraph
  presentation : PptxSourcePresentation
  slides : Array[PptxSlide]
  layouts : Array[PptxSourceLayout]
  masters : Array[PptxSourceMaster]
  media : Array[PptxMediaRef]
  comment_authors : Array[PptxCommentAuthor]
  warnings : Array[PptxWarning]
}

///|
pub struct PptxNotesSlide {
  part_name : String
  owning_slide_part : String
  paragraphs : Array[PptxParagraph]
  source_key : PptxSourceKey
}

///|
pub struct PptxCommentAuthor {
  id : String
  name : String
  initials : String?
}

///|
pub struct PptxComment {
  author_id : String
  author_name : String?
  text : String
  idx : String?
  datetime : String?
  source_key : PptxSourceKey
}

///|
priv struct PptxParseBudget {
  max_slides : Int
  max_shapes_per_slide : Int
  max_group_depth : Int
  max_child_shapes_per_group : Int
  max_table_cells : Int
  max_table_text_runs : Int
  max_notes_comments_per_slide : Int
  max_relationships_per_part : Int
  max_media_exports_per_deck : Int
  max_layout_master_candidates : Int
  max_geometry_comparisons : Int
  max_custom_properties : Int
  max_total_source_nodes : Int
}

///|
fn default_pptx_parse_budget() -> PptxParseBudget {
  {
    max_slides: 500,
    max_shapes_per_slide: 3000,
    max_group_depth: 24,
    max_child_shapes_per_group: 1000,
    max_table_cells: 10000,
    max_table_text_runs: 50000,
    max_notes_comments_per_slide: 1000,
    max_relationships_per_part: 5000,
    max_media_exports_per_deck: 5000,
    max_layout_master_candidates: 3000,
    max_geometry_comparisons: 200000,
    max_custom_properties: 256,
    max_total_source_nodes: 200000,
  }
}

///|
fn touch_pptx_parse_budget(budget : PptxParseBudget) -> Unit {
  ignore(budget.max_slides)
  ignore(budget.max_shapes_per_slide)
  ignore(budget.max_group_depth)
  ignore(budget.max_child_shapes_per_group)
  ignore(budget.max_table_cells)
  ignore(budget.max_table_text_runs)
  ignore(budget.max_notes_comments_per_slide)
  ignore(budget.max_relationships_per_part)
  ignore(budget.max_media_exports_per_deck)
  ignore(budget.max_layout_master_candidates)
  ignore(budget.max_geometry_comparisons)
  ignore(budget.max_custom_properties)
  ignore(budget.max_total_source_nodes)
}
