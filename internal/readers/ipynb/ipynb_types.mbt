///|
pub(all) suberror IpynbError {
  ParseError(String)
}

///|
pub(all) enum IpynbCellKind {
  Markdown
  Code
  Raw
  Unknown
} derive(Eq)

///|
pub(all) enum IpynbOutputKind {
  Stream
  DisplayData
  ExecuteResult
  Error
  Unknown
} derive(Eq)

///|
pub struct IpynbNotebookSummary {
  nbformat : Int?
  nbformat_minor : Int?
  kernelspec_name : String?
  kernelspec_display_name : String?
  language_name : String?
  language_version : String?
  cell_count : Int
}

///|
pub struct IpynbMimeEntry {
  mime_type : String
  text : String?
  json_value : @djson.JsonValue?
  raw_json_text : String?
}

///|
pub struct IpynbAttachment {
  name : String
  mime_entries : Array[IpynbMimeEntry]
}

///|
pub struct IpynbOutput {
  kind : IpynbOutputKind
  output_type : String
  name : String?
  execution_count : Int?
  text : String?
  mime_entries : Array[IpynbMimeEntry]
  ename : String?
  evalue : String?
  traceback : Array[String]
  display_id : String?
  clear_wait : Bool?
  json_pointer : String
}

///|
pub struct IpynbCell {
  index : Int
  kind : IpynbCellKind
  cell_type : String
  cell_id : String?
  metadata : @djson.JsonValue?
  source : String
  execution_count : Int?
  attachments : Array[IpynbAttachment]
  outputs : Array[IpynbOutput]
  json_pointer : String
}

///|
pub struct IpynbNotebook {
  summary : IpynbNotebookSummary
  metadata : @djson.JsonValue?
  cells : Array[IpynbCell]
  raw_root : @djson.JsonDocument
}

///|
pub struct IpynbInspectReport {
  nbformat : Int?
  nbformat_minor : Int?
  cell_count : Int
  markdown_cell_count : Int
  code_cell_count : Int
  raw_cell_count : Int
  output_count : Int
  stream_output_count : Int
  display_data_count : Int
  execute_result_count : Int
  error_output_count : Int
  attachment_count : Int
  mime_entry_count : Int
  asset_candidate_count : Int
  max_cell_source_chars : Int
  max_output_text_chars : Int
}

///|
pub impl Show for IpynbError with fn to_string(self : IpynbError) -> String {
  match self {
    ParseError(msg) => "ipynb parse error: " + msg
  }
}

///|
pub impl Show for IpynbError with fn output(self : IpynbError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
