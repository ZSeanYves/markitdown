///|
pub type PdfNativeTextSpan = @dpdfnative.PdfNativeTextSpan

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
  @dpdfnative.make_pdf_native_text_span(
    text,
    bbox,
    source_ref~,
    confidence~,
    font_name~,
    font_size~,
    reading_order_index~,
  )
}

///|
pub type PdfNativeTextLine = @dpdfnative.PdfNativeTextLine

///|
pub fn make_pdf_native_text_line(
  spans : Array[PdfNativeTextSpan],
  bbox : PdfBBox,
  source_ref? : @core.SourceRef? = None,
  reading_order_index? : Int? = None,
) -> PdfNativeTextLine {
  @dpdfnative.make_pdf_native_text_line(
    spans,
    bbox,
    source_ref~,
    reading_order_index~,
  )
}

///|
pub type PdfNativeTextBlock = @dpdfnative.PdfNativeTextBlock

///|
pub fn make_pdf_native_text_block(
  lines : Array[PdfNativeTextLine],
  bbox : PdfBBox,
  source_ref? : @core.SourceRef? = None,
  reading_order_index? : Int? = None,
) -> PdfNativeTextBlock {
  @dpdfnative.make_pdf_native_text_block(
    lines,
    bbox,
    source_ref~,
    reading_order_index~,
  )
}

///|
pub type PdfNativeImageCandidate = @dpdfnative.PdfNativeImageCandidate

///|
pub fn make_pdf_native_image_candidate(
  bbox : PdfBBox,
  source_ref? : @core.SourceRef? = None,
  asset_ref? : @core.AssetRef? = None,
  reading_order_index? : Int? = None,
) -> PdfNativeImageCandidate {
  @dpdfnative.make_pdf_native_image_candidate(
    bbox,
    source_ref~,
    asset_ref~,
    reading_order_index~,
  )
}

///|
pub type PdfNativeLinkCandidate = @dpdfnative.PdfNativeLinkCandidate

///|
pub fn make_pdf_native_link_candidate(
  bbox : PdfBBox,
  href : String,
  text? : String? = None,
  source_ref? : @core.SourceRef? = None,
  annotation_index? : Int? = None,
  annotation_object_id? : Int? = None,
) -> PdfNativeLinkCandidate {
  @dpdfnative.make_pdf_native_link_candidate(
    bbox,
    href,
    text~,
    source_ref~,
    annotation_index~,
    annotation_object_id~,
  )
}

///|
pub type PdfNativeDestination = @dpdfnative.PdfNativeDestination

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
  @dpdfnative.make_pdf_native_destination(
    page_index~,
    target_page_index~,
    target_page_object_id~,
    kind~,
    raw_value~,
    name~,
    source_ref~,
    object_id~,
  )
}

///|
pub type PdfNativeAnnotation = @dpdfnative.PdfNativeAnnotation

///|
pub fn make_pdf_native_annotation(
  page_index : Int,
  subtype : String,
  bbox? : PdfBBox? = None,
  text? : String? = None,
  title? : String? = None,
  subject? : String? = None,
  file_name? : String? = None,
  name? : String? = None,
  modified_at? : String? = None,
  action_kind? : String? = None,
  target? : String? = None,
  destination? : PdfNativeDestination? = None,
  source_ref? : @core.SourceRef? = None,
  annotation_index? : Int? = None,
  object_id? : Int? = None,
) -> PdfNativeAnnotation {
  @dpdfnative.make_pdf_native_annotation(
    page_index,
    subtype,
    bbox~,
    text~,
    title~,
    subject~,
    file_name~,
    name~,
    modified_at~,
    action_kind~,
    target~,
    destination~,
    source_ref~,
    annotation_index~,
    object_id~,
  )
}

///|
pub type PdfNativeFormField = @dpdfnative.PdfNativeFormField

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
  @dpdfnative.make_pdf_native_form_field(
    page_index~,
    field_type~,
    field_name~,
    alternate_name~,
    value~,
    default_value~,
    options~,
    bbox~,
    source_ref~,
    object_id~,
    widget_object_id~,
    flags~,
  )
}

///|
pub type PdfNativeOutlineItem = @dpdfnative.PdfNativeOutlineItem

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
  @dpdfnative.make_pdf_native_outline_item(
    title,
    level,
    order_index,
    page_index~,
    action_kind~,
    target~,
    destination~,
    source_ref~,
    object_id~,
  )
}

///|
pub type PdfNativeTableCandidate = @dpdfnative.PdfNativeTableCandidate

///|
pub fn make_pdf_native_table_candidate(
  bbox : PdfBBox,
  source_ref? : @core.SourceRef? = None,
  row_count? : Int? = None,
  column_count? : Int? = None,
  cell_bboxes? : Array[PdfBBox] = [],
) -> PdfNativeTableCandidate {
  @dpdfnative.make_pdf_native_table_candidate(
    bbox,
    source_ref~,
    row_count~,
    column_count~,
    cell_bboxes~,
  )
}

///|
pub type PdfNativeArtifactCandidate = @dpdfnative.PdfNativeArtifactCandidate

///|
pub fn make_pdf_native_artifact_candidate(
  kind : String,
  bbox : PdfBBox,
  source_ref? : @core.SourceRef? = None,
) -> PdfNativeArtifactCandidate {
  @dpdfnative.make_pdf_native_artifact_candidate(kind, bbox, source_ref~)
}

///|
pub type PdfNativePage = @dpdfnative.PdfNativePage

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
  @dpdfnative.make_pdf_native_page(
    geometry,
    text_blocks~,
    image_candidates~,
    link_candidates~,
    annotations~,
    destinations~,
    table_candidates~,
    artifact_candidates~,
    diagnostics~,
  )
}

///|
pub type PdfNativeDocument = @dpdfnative.PdfNativeDocument

///|
pub fn make_pdf_native_document(
  pages? : Array[PdfNativePage] = [],
  form_fields? : Array[PdfNativeFormField] = [],
  outline_items? : Array[PdfNativeOutlineItem] = [],
  named_destinations? : Array[PdfNativeDestination] = [],
  metadata? : Map[String, @core.JsonValue] = Map([]),
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
) -> PdfNativeDocument {
  @dpdfnative.make_pdf_native_document(
    pages~,
    form_fields~,
    outline_items~,
    named_destinations~,
    metadata~,
    diagnostics~,
  )
}
