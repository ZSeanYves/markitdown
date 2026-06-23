///|
pub struct PdfNativeTextSpan {
  text : String
  bbox : PdfBBox
  source_ref : @core.SourceRef?
  confidence : Int?
  font_name : String?
  font_size : Double?
  reading_order_index : Int?
}

///|
pub fn make_pdf_native_text_span(
  text : String,
  bbox : PdfBBox,
  source_ref? : @core.SourceRef? = None,
  confidence? : Int? = None,
  font_name? : String? = None,
  font_size? : Double? = None,
  reading_order_index? : Int? = None,
) -> PdfNativeTextSpan {
  {
    text,
    bbox,
    source_ref,
    confidence,
    font_name,
    font_size,
    reading_order_index,
  }
}

///|
pub struct PdfNativeTextLine {
  spans : Array[PdfNativeTextSpan]
  bbox : PdfBBox
  source_ref : @core.SourceRef?
  reading_order_index : Int?
}

///|
pub fn make_pdf_native_text_line(
  spans : Array[PdfNativeTextSpan],
  bbox : PdfBBox,
  source_ref? : @core.SourceRef? = None,
  reading_order_index? : Int? = None,
) -> PdfNativeTextLine {
  { spans, bbox, source_ref, reading_order_index }
}

///|
pub struct PdfNativeTextBlock {
  lines : Array[PdfNativeTextLine]
  bbox : PdfBBox
  source_ref : @core.SourceRef?
  reading_order_index : Int?
}

///|
pub fn make_pdf_native_text_block(
  lines : Array[PdfNativeTextLine],
  bbox : PdfBBox,
  source_ref? : @core.SourceRef? = None,
  reading_order_index? : Int? = None,
) -> PdfNativeTextBlock {
  { lines, bbox, source_ref, reading_order_index }
}

///|
pub struct PdfNativeImageCandidate {
  bbox : PdfBBox
  source_ref : @core.SourceRef?
  asset_ref : @core.AssetRef?
  reading_order_index : Int?
}

///|
pub fn make_pdf_native_image_candidate(
  bbox : PdfBBox,
  source_ref? : @core.SourceRef? = None,
  asset_ref? : @core.AssetRef? = None,
  reading_order_index? : Int? = None,
) -> PdfNativeImageCandidate {
  { bbox, source_ref, asset_ref, reading_order_index }
}

///|
pub struct PdfNativeLinkCandidate {
  bbox : PdfBBox
  href : String
  text : String?
  source_ref : @core.SourceRef?
  annotation_index : Int?
  annotation_object_id : Int?
}

///|
pub fn make_pdf_native_link_candidate(
  bbox : PdfBBox,
  href : String,
  text? : String? = None,
  source_ref? : @core.SourceRef? = None,
  annotation_index? : Int? = None,
  annotation_object_id? : Int? = None,
) -> PdfNativeLinkCandidate {
  { bbox, href, text, source_ref, annotation_index, annotation_object_id }
}

///|
pub struct PdfNativeDestination {
  page_index : Int?
  target_page_index : Int?
  target_page_object_id : Int?
  kind : String?
  raw_value : String?
  name : String?
  source_ref : @core.SourceRef?
  object_id : Int?
}

///|
pub fn make_pdf_native_destination(
  page_index? : Int? = None,
  target_page_index? : Int? = None,
  target_page_object_id? : Int? = None,
  kind? : String? = None,
  raw_value? : String? = None,
  name? : String? = None,
  source_ref? : @core.SourceRef? = None,
  object_id? : Int? = None,
) -> PdfNativeDestination {
  {
    page_index,
    target_page_index,
    target_page_object_id,
    kind,
    raw_value,
    name,
    source_ref,
    object_id,
  }
}

///|
pub struct PdfNativeAnnotation {
  page_index : Int
  subtype : String
  bbox : PdfBBox?
  text : String?
  title : String?
  name : String?
  modified_at : String?
  action_kind : String?
  target : String?
  destination : PdfNativeDestination?
  source_ref : @core.SourceRef?
  annotation_index : Int?
  object_id : Int?
}

///|
pub fn make_pdf_native_annotation(
  page_index : Int,
  subtype : String,
  bbox? : PdfBBox? = None,
  text? : String? = None,
  title? : String? = None,
  name? : String? = None,
  modified_at? : String? = None,
  action_kind? : String? = None,
  target? : String? = None,
  destination? : PdfNativeDestination? = None,
  source_ref? : @core.SourceRef? = None,
  annotation_index? : Int? = None,
  object_id? : Int? = None,
) -> PdfNativeAnnotation {
  {
    page_index,
    subtype,
    bbox,
    text,
    title,
    name,
    modified_at,
    action_kind,
    target,
    destination,
    source_ref,
    annotation_index,
    object_id,
  }
}

///|
pub struct PdfNativeFormField {
  page_index : Int?
  field_type : String?
  field_name : String?
  alternate_name : String?
  value : String?
  default_value : String?
  options : Array[String]
  bbox : PdfBBox?
  source_ref : @core.SourceRef?
  object_id : Int?
  widget_object_id : Int?
  flags : Int?
}

///|
pub fn make_pdf_native_form_field(
  page_index? : Int? = None,
  field_type? : String? = None,
  field_name? : String? = None,
  alternate_name? : String? = None,
  value? : String? = None,
  default_value? : String? = None,
  options? : Array[String] = [],
  bbox? : PdfBBox? = None,
  source_ref? : @core.SourceRef? = None,
  object_id? : Int? = None,
  widget_object_id? : Int? = None,
  flags? : Int? = None,
) -> PdfNativeFormField {
  {
    page_index,
    field_type,
    field_name,
    alternate_name,
    value,
    default_value,
    options,
    bbox,
    source_ref,
    object_id,
    widget_object_id,
    flags,
  }
}

///|
pub struct PdfNativeOutlineItem {
  title : String
  level : Int
  order_index : Int
  page_index : Int?
  action_kind : String?
  target : String?
  destination : PdfNativeDestination?
  source_ref : @core.SourceRef?
  object_id : Int?
}

///|
pub fn make_pdf_native_outline_item(
  title : String,
  level : Int,
  order_index : Int,
  page_index? : Int? = None,
  action_kind? : String? = None,
  target? : String? = None,
  destination? : PdfNativeDestination? = None,
  source_ref? : @core.SourceRef? = None,
  object_id? : Int? = None,
) -> PdfNativeOutlineItem {
  {
    title,
    level,
    order_index,
    page_index,
    action_kind,
    target,
    destination,
    source_ref,
    object_id,
  }
}

///|
pub struct PdfNativeTableCandidate {
  bbox : PdfBBox
  source_ref : @core.SourceRef?
  row_count : Int?
  column_count : Int?
  cell_bboxes : Array[PdfBBox]
}

///|
pub fn make_pdf_native_table_candidate(
  bbox : PdfBBox,
  source_ref? : @core.SourceRef? = None,
  row_count? : Int? = None,
  column_count? : Int? = None,
  cell_bboxes? : Array[PdfBBox] = [],
) -> PdfNativeTableCandidate {
  { bbox, source_ref, row_count, column_count, cell_bboxes }
}

///|
pub struct PdfNativeArtifactCandidate {
  kind : String
  bbox : PdfBBox
  source_ref : @core.SourceRef?
}

///|
pub fn make_pdf_native_artifact_candidate(
  kind : String,
  bbox : PdfBBox,
  source_ref? : @core.SourceRef? = None,
) -> PdfNativeArtifactCandidate {
  { kind, bbox, source_ref }
}

///|
pub struct PdfNativePage {
  geometry : PdfPageGeometry
  text_blocks : Array[PdfNativeTextBlock]
  image_candidates : Array[PdfNativeImageCandidate]
  link_candidates : Array[PdfNativeLinkCandidate]
  annotations : Array[PdfNativeAnnotation]
  destinations : Array[PdfNativeDestination]
  table_candidates : Array[PdfNativeTableCandidate]
  artifact_candidates : Array[PdfNativeArtifactCandidate]
  diagnostics : @core.Diagnostics
}

///|
pub fn make_pdf_native_page(
  geometry : PdfPageGeometry,
  text_blocks? : Array[PdfNativeTextBlock] = [],
  image_candidates? : Array[PdfNativeImageCandidate] = [],
  link_candidates? : Array[PdfNativeLinkCandidate] = [],
  annotations? : Array[PdfNativeAnnotation] = [],
  destinations? : Array[PdfNativeDestination] = [],
  table_candidates? : Array[PdfNativeTableCandidate] = [],
  artifact_candidates? : Array[PdfNativeArtifactCandidate] = [],
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
) -> PdfNativePage {
  {
    geometry,
    text_blocks,
    image_candidates,
    link_candidates,
    annotations,
    destinations,
    table_candidates,
    artifact_candidates,
    diagnostics,
  }
}

///|
pub struct PdfNativeDocument {
  pages : Array[PdfNativePage]
  form_fields : Array[PdfNativeFormField]
  outline_items : Array[PdfNativeOutlineItem]
  named_destinations : Array[PdfNativeDestination]
  metadata : Map[String, @core.JsonValue]
  diagnostics : @core.Diagnostics
}

///|
pub fn make_pdf_native_document(
  pages? : Array[PdfNativePage] = [],
  form_fields? : Array[PdfNativeFormField] = [],
  outline_items? : Array[PdfNativeOutlineItem] = [],
  named_destinations? : Array[PdfNativeDestination] = [],
  metadata? : Map[String, @core.JsonValue] = Map([]),
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
) -> PdfNativeDocument {
  {
    pages,
    form_fields,
    outline_items,
    named_destinations,
    metadata,
    diagnostics,
  }
}
