///|
priv enum PptxBlock {
  Heading(String, Array[@cor.Inline])
  Paragraph(String, Array[@cor.Inline])
  ListItem(Bool, Int, String, Array[@cor.Inline]) // ordered, level, text, inlines
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
