///|
pub(all) suberror OdfError {
  ParseError(String)
}

///|
pub(all) enum OdfDocumentKind {
  Odt
  Ods
  Odp
} derive(Eq)

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
  level : Int?
  list_depth : Int?
  rows : Array[OdtTableRow]
  image : OdtImageRef?
  inlines : Array[OdtInline]
  note : OdtNote?
  content_path : String
  xml_path : String
  line_start : Int?
  line_end : Int?
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
  block_count : Int
  heading_count : Int
  paragraph_count : Int
  list_item_count : Int
  code_block_count : Int
  raw_block_count : Int
  table_count : Int
  image_count : Int
  note_count : Int
  comment_count : Int
  max_heading_level : Int
}

///|
pub struct OdsCell {
  text : String
  formula : String?
  covered : Bool
  col_span : Int
  row_span : Int
  repeat_count : Int
}

///|
pub struct OdsRow {
  cells : Array[OdsCell]
  row_index : Int
  hidden : Bool
  repeat_count : Int
}

///|
pub struct OdsSheet {
  name : String
  rows : Array[OdsRow]
  visible : Bool
}

///|
pub struct OdsDocument {
  package_info : OdfPackageInfo
  metadata : OdfMetadataSummary
  sheets : Array[OdsSheet]
}

///|
pub struct OdsInspectReport {
  sheet_count : Int
  visible_sheet_count : Int
  hidden_sheet_count : Int
  row_count : Int
  non_empty_row_count : Int
  cell_count : Int
  used_cell_count : Int
  hidden_row_count : Int
  covered_cell_count : Int
  max_sheet_rows : Int
  max_sheet_cols : Int
  max_used_cols : Int
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
  line_start : Int?
  line_end : Int?
  attrs : Map[String, String]
}

///|
pub struct OdpSlide {
  index : Int
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
  slide_count : Int
  block_count : Int
  heading_count : Int
  paragraph_count : Int
  list_item_count : Int
  table_count : Int
  image_count : Int
  notes_count : Int
  raw_block_count : Int
}

///|
pub impl Show for OdfError with fn to_string(self : OdfError) -> String {
  match self {
    ParseError(msg) => "odf parse error: " + msg
  }
}

///|
pub impl Show for OdfError with fn output(self : OdfError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
