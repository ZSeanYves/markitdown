///|
pub(all) enum TextMarkupFormat {
  Tex
  Rst
  Asciidoc
} derive(Eq)

///|
pub extend TextMarkupFormat with Eq::{equal, not_equal}

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
pub extend TextMarkupBlockKind with Eq::{equal, not_equal}

///|
pub(all) enum TextMarkupInlineKind {
  Text
  Link
  Code
} derive(Eq)

///|
pub extend TextMarkupInlineKind with Eq::{equal, not_equal}

///|
pub struct TextMarkupBlock {
  kind : TextMarkupBlockKind
  text : String
  level : Int32
  ordered : Bool
  line_start : Int32
  line_end : Int32
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
  block_count : Int32
  heading_count : Int32
  list_item_count : Int32
  code_count : Int32
  table_count : Int32
  blockquote_count : Int32
  raw_count : Int32
  paragraph_count : Int32
  line_count : Int32
  char_count : Int32
}
