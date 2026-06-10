///|
pub(all) enum PdfV2ImageDecodeStatus {
  MetadataOnly
  DecodeAvailable
  Unsupported
  NotAttempted
} derive(Eq)

///|
pub(all) enum PdfV2ResourceKind {
  Font
  XObject
  ImageXObject
  FormXObject
  ColorSpace
  Pattern
  ExtGState
  ProcedureSet
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2MetadataKind {
  Info
  Xmp
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2ImageCandidate {
  page_index : Int?
  object_ref : String?
  width : Int?
  height : Int?
  color_space : String?
  bits_per_component : Int?
  filters : Array[String]
  image_mask : Bool?
  mask_present : Bool
  smask_present : Bool
  inline : Bool
  bbox : PdfV2BBox?
  source_ref : PdfV2SourceRef
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
  decode_status : PdfV2ImageDecodeStatus
}

///|
pub(all) struct PdfV2InlineImageCandidate {
  page_index : Int?
  width : Int?
  height : Int?
  color_space : String?
  bits_per_component : Int?
  filters : Array[String]
  image_mask : Bool?
  decode_params_present : Bool
  bbox : PdfV2BBox?
  source_ref : PdfV2SourceRef
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
  decode_status : PdfV2ImageDecodeStatus
}

///|
pub(all) struct PdfV2AnnotationCandidate {
  page_index : Int?
  object_ref : String?
  subtype : String?
  rect : PdfV2BBox?
  uri : String?
  dest : String?
  source_ref : PdfV2SourceRef
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2LinkCandidate {
  page_index : Int?
  object_ref : String?
  subtype : String?
  rect : PdfV2BBox?
  uri : String?
  dest : String?
  source_ref : PdfV2SourceRef
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2FormCandidate {
  page_index : Int?
  object_ref : String?
  field_name : String?
  alternate_name : String?
  value : String?
  rect : PdfV2BBox?
  appearance_ref : String?
  source_ref : PdfV2SourceRef
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2OutlineCandidate {
  title : String?
  dest : String?
  action : String?
  target_page : String?
  source_ref : PdfV2SourceRef
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2DestinationCandidate {
  title : String?
  dest : String?
  action : String?
  target_page : String?
  source_ref : PdfV2SourceRef
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2ResourceCandidate {
  page_index : Int?
  resource_kind : PdfV2ResourceKind
  name : String
  object_ref : String?
  source_ref : PdfV2SourceRef
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2MetadataCandidate {
  kind : PdfV2MetadataKind
  key : String?
  value : String?
  object_ref : String?
  source_ref : PdfV2SourceRef
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) enum PdfV2ObjectCandidateFact {
  ImageObjectFact(PdfV2ImageCandidate)
  InlineImageObjectFact(PdfV2InlineImageCandidate)
  AnnotationObjectFact(PdfV2AnnotationCandidate)
  LinkObjectFact(PdfV2LinkCandidate)
  FormObjectFact(PdfV2FormCandidate)
  OutlineObjectFact(PdfV2OutlineCandidate)
  DestinationObjectFact(PdfV2DestinationCandidate)
  ResourceObjectFact(PdfV2ResourceCandidate)
  MetadataObjectFact(PdfV2MetadataCandidate)
}

///|
pub(all) struct PdfV2ObjectSummary {
  image_count : Int
  inline_image_count : Int
  annotation_count : Int
  link_count : Int
  form_count : Int
  outline_count : Int
  destination_count : Int
  resource_count : Int
  metadata_count : Int
  unsupported_object_count : Int
  warning_count : Int
  risk_count : Int
}

///|
pub fn pdf_v2_empty_object_summary() -> PdfV2ObjectSummary {
  {
    image_count: 0,
    inline_image_count: 0,
    annotation_count: 0,
    link_count: 0,
    form_count: 0,
    outline_count: 0,
    destination_count: 0,
    resource_count: 0,
    metadata_count: 0,
    unsupported_object_count: 0,
    warning_count: 0,
    risk_count: 0,
  }
}
