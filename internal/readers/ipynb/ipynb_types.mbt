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
pub extend IpynbCellKind with Eq::{equal, not_equal}

///|
pub(all) enum IpynbOutputKind {
  Stream
  DisplayData
  ExecuteResult
  Error
  Unknown
} derive(Eq)

///|
pub extend IpynbOutputKind with Eq::{equal, not_equal}

///|
pub struct IpynbNotebookSummary {
  nbformat : Int32?
  nbformat_minor : Int32?
  kernelspec_name : String?
  kernelspec_display_name : String?
  language_name : String?
  language_version : String?
  cell_count : Int32
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
  execution_count : Int32?
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
  index : Int32
  kind : IpynbCellKind
  cell_type : String
  cell_id : String?
  metadata : @djson.JsonValue?
  source : String
  execution_count : Int32?
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
  nbformat : Int32?
  nbformat_minor : Int32?
  cell_count : Int32
  markdown_cell_count : Int32
  code_cell_count : Int32
  raw_cell_count : Int32
  output_count : Int32
  stream_output_count : Int32
  display_data_count : Int32
  execute_result_count : Int32
  error_output_count : Int32
  attachment_count : Int32
  mime_entry_count : Int32
  asset_candidate_count : Int32
  max_cell_source_chars : Int32
  max_output_text_chars : Int32
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
