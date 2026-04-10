///|
pub suberror PdfParseError {
  UnexpectedEOF(String)
  InvalidHeader(String)
  InvalidStructure(String)
  UnsupportedFeature(String)
  ObjectNotFound(Int, Int)
  TypeMismatch(String)
}

///|
pub(all) suberror PdfNativeError {
  UnsupportedFeature(String)
  ExtractionFailed(String)
}

///|
pub impl Show for PdfParseError with to_string(self : PdfParseError) -> String {
  match self {
    UnexpectedEOF(ctx) => "unexpected EOF: " + ctx
    InvalidHeader(msg) => "invalid pdf header: " + msg
    InvalidStructure(msg) => "invalid pdf structure: " + msg
    UnsupportedFeature(msg) => "unsupported pdf feature in phase-1: " + msg
    ObjectNotFound(obj, gen) =>
      "pdf object not found: " + obj.to_string() + " " + gen.to_string() + " R"
    TypeMismatch(msg) => "pdf type mismatch: " + msg
  }
}

///|
pub impl Show for PdfNativeError with to_string(self : PdfNativeError) -> String {
  match self {
    UnsupportedFeature(msg) => "pdf native unsupported: " + msg
    ExtractionFailed(msg) => "pdf native extraction failed: " + msg
  }
}

///|
pub impl Show for PdfNativeError with output(
  self : PdfNativeError,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for PdfParseError with output(
  self : PdfParseError,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub enum PdfValue {
  Null
  Bool(Bool)
  Int(Int)
  Real(Double)
  Name(String)
  String(String)
  HexString(Bytes)
  Array(Array[PdfValue])
  Dict(Map[String, PdfValue])
  Ref(Int, Int)
}

///|
pub struct PdfIndirectObject {
  obj_num : Int
  gen : Int
  value : PdfValue
  stream : Bytes?
}

///|
pub struct PdfXrefEntry {
  entry_type : Int
  offset : Int
  gen : Int
  in_use : Bool
  objstm_obj : Int?
  objstm_index : Int?
}

///|
pub struct PdfXrefTable {
  entries : Map[String, PdfXrefEntry]
}

///|
pub struct PdfDocument {
  bytes : Bytes
  version : String
  startxref : Int
  trailer : Map[String, PdfValue]
  xref : PdfXrefTable
}
