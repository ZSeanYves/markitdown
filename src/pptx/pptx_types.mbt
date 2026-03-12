///|
priv enum PptxBlock {
  Heading(String)
  Paragraph(String)
  ListItem(Bool, Int, String) // ordered, level, text
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
  text : String
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
