///|
priv enum ListKind {
  Bullet
  Ordered
}

///|
priv struct ParagraphListInfo {
  num_id : Int
  ilvl : Int
}

///|
priv struct DocxNumbering {
  num_to_abs : Map[Int, Int]
  fmt_by_abs_ilvl : Map[String, String]
}

///|
priv struct DocxStyles {
  heading_by_style : Map[String, Int]
  name_by_style : Map[String, String]
}
