///|
pub(all) suberror EmlError {
  ParseError(String)
  InvalidEncoding(String)
  LimitExceeded(EmlStructuralLimitKind, observed~ : Int64, limit~ : Int64)
}

///|
pub(all) enum EmlStructuralLimitKind {
  NestingDepth
  MultipartParts
}

///|
pub(all) enum EmlTransferEncoding {
  SevenBit
  EightBit
  Binary
  Base64
  QuotedPrintable
  Other(String)
} derive(Eq)

///|
pub extend EmlTransferEncoding with Eq::{equal, not_equal}

///|
pub(all) enum EmlDispositionKind {
  Inline
  Attachment
  Other(String)
} derive(Eq)

///|
pub extend EmlDispositionKind with Eq::{equal, not_equal}

///|
pub struct EmlHeader {
  name : String
  value : String
}

///|
pub struct EmlHeaderMap {
  subject : String?
  from : String?
  to : String?
  cc : String?
  date : String?
  message_id : String?
  in_reply_to : String?
  references : String?
  mime_version : String?
  content_type : String?
  content_transfer_encoding : String?
}

///|
pub struct EmlBodyText {
  text : String
  decoded : Bool
  charset : String?
}

///|
pub struct EmlPartSummary {
  content_type : String
  mime_type : String
  media_type : String
  charset : String?
  boundary : String?
  name : String?
  disposition : EmlDispositionKind?
  disposition_filename : String?
  transfer_encoding : EmlTransferEncoding
  content_id : String?
  location : String?
  json_pointer : String
}

///|
pub struct EmlAttachment {
  file_name : String?
  mime_type : String
  disposition : EmlDispositionKind?
  content_id : String?
  location : String?
  transfer_encoding : EmlTransferEncoding
  payload_decoded : Bool
  bytes : Bytes?
  decoded_text : String?
  raw_text : String
  summary : EmlPartSummary
}

///|
pub struct EmlPart {
  index : Int32
  headers : Array[EmlHeader]
  header_map : EmlHeaderMap
  summary : EmlPartSummary
  body_text : EmlBodyText?
  attachments : Array[EmlAttachment]
  child_message : EmlMessage?
  children : Array[EmlPart]
  raw_body : String
}

///|
pub struct EmlMessage {
  headers : Array[EmlHeader]
  header_map : EmlHeaderMap
  summary : EmlPartSummary
  text_plain : Array[EmlPart]
  text_html : Array[EmlPart]
  attachments : Array[EmlAttachment]
  inline_images : Array[EmlAttachment]
  children : Array[EmlPart]
  raw_source : String
}

///|
pub struct EmlInspectReport {
  part_count : Int32
  multipart_count : Int32
  text_part_count : Int32
  html_part_count : Int32
  attachment_count : Int32
  inline_image_count : Int32
  nested_message_count : Int32
  max_depth : Int32
  max_part_chars : Int32
}

///|
pub impl Show for EmlError with fn to_string(self : EmlError) -> String {
  match self {
    ParseError(msg) => "eml parse error: " + msg
    InvalidEncoding(msg) => "eml encoding error: " + msg
    LimitExceeded(kind, observed~, limit~) =>
      "eml resource limit exceeded: " +
      (match kind {
        NestingDepth => "mime_nesting_depth"
        MultipartParts => "mime_multipart_parts"
      }) +
      "; observed=" +
      observed.to_string() +
      "; limit=" +
      limit.to_string()
  }
}

///|
pub impl Show for EmlError with fn output(self : EmlError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
