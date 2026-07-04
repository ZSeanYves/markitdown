///|
pub(all) enum TextMarkupFormat {
  Tex
  Rst
  Asciidoc
} derive(Eq)

///|
pub(all) enum TextMarkupBlockKind {
  Heading
  Paragraph
  ListItem
  Code
  Table
  BlockQuote
  NoteDefinition
  Semantic
  Raw
} derive(Eq)

///|
pub(all) enum TextMarkupInlineKind {
  Text
  Link
  Code
} derive(Eq)

///|
pub struct TextMarkupBlock {
  kind : TextMarkupBlockKind
  text : String
  level : Int
  ordered : Bool
  line_start : Int
  line_end : Int
  meta : Map[String, String]
}

///|
pub struct TextMarkupInline {
  kind : TextMarkupInlineKind
  text : String
  href : String?
}

///|
pub struct TextMarkupTable {
  header : Array[String]
  rows : Array[Array[String]]
}

///|
pub struct TextMarkupDocument {
  format : TextMarkupFormat
  blocks : Array[TextMarkupBlock]
}

///|
pub struct TextMarkupInspectReport {
  block_count : Int
  heading_count : Int
  list_item_count : Int
  code_count : Int
  table_count : Int
  blockquote_count : Int
  raw_count : Int
  paragraph_count : Int
  line_count : Int
  char_count : Int
}
