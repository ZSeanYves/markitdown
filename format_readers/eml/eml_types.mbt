///|
pub(all) suberror EmlError {
  ParseError(String)
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
pub(all) enum EmlDispositionKind {
  Inline
  Attachment
  Other(String)
} derive(Eq)

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
  bytes : Bytes?
  decoded_text : String?
  raw_text : String
  summary : EmlPartSummary
}

///|
pub struct EmlPart {
  index : Int
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
  part_count : Int
  multipart_count : Int
  text_part_count : Int
  html_part_count : Int
  attachment_count : Int
  inline_image_count : Int
  nested_message_count : Int
  max_depth : Int
  max_part_chars : Int
}

///|
pub impl Show for EmlError with fn to_string(self : EmlError) -> String {
  match self {
    ParseError(msg) => "eml parse error: " + msg
  }
}

///|
pub impl Show for EmlError with fn output(self : EmlError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
