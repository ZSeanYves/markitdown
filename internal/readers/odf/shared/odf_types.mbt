///|
pub(all) suberror OdfError {
  ParseError(String)
  InvalidEncoding(String)
}

///|
pub(all) enum OdfDocumentKind {
  Odt
  Ods
  Odp
} derive(Eq)

///|
pub extend OdfDocumentKind with Eq::{equal, not_equal}

///|
pub struct OdfPackageInfo {
  document_kind : OdfDocumentKind
  mimetype : String
  manifest_seen : Bool
  content_path : String
  meta_path : String?
  styles_path : String?
}

///|
pub struct OdfMetadataSummary {
  title : String?
  subject : String?
  description : String?
  language : String?
}

///|
pub(all) enum OdtBlockKind {
  Heading
  Paragraph
  ListItem
  Code
  Raw
  Table
  Image
  NoteDefinition
} derive(Eq)

///|
pub extend OdtBlockKind with Eq::{equal, not_equal}

///|
pub struct OdtTableCell {
  text : String
}

///|
pub struct OdtInline {
  text : String
  href : String?
  note_id : String?
  note_kind : String?
  note_marker : String?
  note_body : String?
}

///|
pub struct OdtNote {
  id : String
  kind : String
  citation : String
  body : String
  author : String?
}

///|
pub struct OdtTableRow {
  cells : Array[OdtTableCell]
}

///|
pub struct OdtImageRef {
  href : String
  media_type : String?
  alt : String?
  bytes : Bytes?
}

///|
pub struct OdtBlock {
  kind : OdtBlockKind
  text : String
  level : Int32?
  list_depth : Int32?
  rows : Array[OdtTableRow]
  image : OdtImageRef?
  inlines : Array[OdtInline]
  note : OdtNote?
  content_path : String
  xml_path : String
  line_start : Int32?
  line_end : Int32?
  attrs : Map[String, String]
}

///|
pub struct OdtDocument {
  package_info : OdfPackageInfo
  metadata : OdfMetadataSummary
  blocks : Array[OdtBlock]
  assets : Array[OdtImageRef]
}

///|
pub struct OdtInspectReport {
  block_count : Int32
  heading_count : Int32
  paragraph_count : Int32
  list_item_count : Int32
  code_block_count : Int32
  raw_block_count : Int32
  table_count : Int32
  image_count : Int32
  note_count : Int32
  comment_count : Int32
  max_heading_level : Int32
}

///|
pub struct OdsCell {
  text : String
  formula : String?
  covered : Bool
  col_span : Int32
  row_span : Int32
  repeat_count : Int32
}

///|
pub struct OdsRow {
  cells : Array[OdsCell]
  row_index : Int32
  hidden : Bool
  repeat_count : Int32
}

///|
pub struct OdsSheet {
  name : String
  rows : Array[OdsRow]
  visible : Bool
  images : Array[OdtImageRef]
}

///|
pub struct OdsDocument {
  package_info : OdfPackageInfo
  metadata : OdfMetadataSummary
  sheets : Array[OdsSheet]
  assets : Array[OdtImageRef]
}

///|
pub struct OdsInspectReport {
  sheet_count : Int32
  visible_sheet_count : Int32
  hidden_sheet_count : Int32
  row_count : Int32
  non_empty_row_count : Int32
  cell_count : Int32
  used_cell_count : Int32
  hidden_row_count : Int32
  covered_cell_count : Int32
  max_sheet_rows : Int32
  max_sheet_cols : Int32
  max_used_cols : Int32
}

///|
pub(all) enum OdpBlockKind {
  Heading
  Paragraph
  ListItem
  Table
  Image
  Notes
  Raw
} derive(Eq)

///|
pub extend OdpBlockKind with Eq::{equal, not_equal}

///|
pub struct OdpTableCell {
  text : String
}

///|
pub struct OdpTableRow {
  cells : Array[OdpTableCell]
}

///|
pub struct OdpImageRef {
  href : String
  media_type : String?
  alt : String?
  bytes : Bytes?
}

///|
pub struct OdpSlideBlock {
  kind : OdpBlockKind
  text : String
  rows : Array[OdpTableRow]
  image : OdpImageRef?
  content_path : String
  xml_path : String
  line_start : Int32?
  line_end : Int32?
  attrs : Map[String, String]
}

///|
pub struct OdpSlide {
  index : Int32
  name : String?
  blocks : Array[OdpSlideBlock]
}

///|
pub struct OdpDocument {
  package_info : OdfPackageInfo
  metadata : OdfMetadataSummary
  slides : Array[OdpSlide]
  assets : Array[OdpImageRef]
}

///|
pub struct OdpInspectReport {
  slide_count : Int32
  block_count : Int32
  heading_count : Int32
  paragraph_count : Int32
  list_item_count : Int32
  table_count : Int32
  image_count : Int32
  notes_count : Int32
  raw_block_count : Int32
}

///|
pub impl Show for OdfError with fn to_string(self : OdfError) -> String {
  match self {
    ParseError(msg) => "odf parse error: " + msg
    InvalidEncoding(msg) => "invalid ODF encoding: " + msg
  }
}

///|
pub impl Show for OdfError with fn output(self : OdfError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
