///|
priv enum PptxBlock {
  Heading(String, Array[@cor.Inline])
  Paragraph(String, Array[@cor.Inline])
  ListItem(Bool, Int, String, Array[@cor.Inline]) // ordered, level, text, inlines
}

///|
priv struct PptxSlideEntry {
  part_name : String
  rel_id : String?
  hidden : Bool
}

///|
priv struct PptxSlideRelContext {
  rels : Array[@ox.OoxmlRelationship]
  hyperlinks : Map[String, String]
  notes_part : String?
  notes_relationship_id : String?
}

///|
priv struct SlideShape {
  xml : Bytes
  x : Int
  y : Int
  w : Int
  h : Int
  is_title : Bool
  is_body : Bool
  object_ref : String?
}

///|
priv struct LayoutShape {
  shape : SlideShape
  right : Int
  bottom : Int
  center_x : Int
  center_y : Int
}

///|
priv enum ShapeGroupKind {
  Normal
  CaptionLike
  TableLike
}

///|
priv struct ShapeGroup {
  shapes : Array[LayoutShape]
  top : Int
  left : Int
  kind : ShapeGroupKind
}

///|
priv struct SlideParagraph {
  source_para_id : Int
  text : String
  inlines : Array[@cor.Inline]
  bullet_kind : BulletKind?
  level : Int
  from_title_shape : Bool
  from_body_shape : Bool
  associated_with_image_caption : Bool
}

///|
priv struct PptxTableFrame {
  rows : Array[Array[String]]
  header_rows : Int
  object_ref : String?
}

///|
priv struct PptxRawPictureShape {
  xml : Bytes
  object_ref : String?
}

///|
priv struct PptxRawGraphicFrame {
  xml : Bytes
  object_ref : String?
}

///|
priv struct PptxCollectedSlideObjects {
  text_shapes : Array[SlideShape]
  picture_shapes : Array[PptxRawPictureShape]
  graphic_frames : Array[PptxRawGraphicFrame]
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
priv enum BulletKind {
  Unordered
  Ordered
}

///|
const PPTX_SLIDE_DEBUG = false

///|
impl Eq for ShapeGroupKind with equal(
  self : ShapeGroupKind,
  other : ShapeGroupKind,
) -> Bool {
  match (self, other) {
    (Normal, Normal) => true
    (CaptionLike, CaptionLike) => true
    (TableLike, TableLike) => true
    _ => false
  }
}
