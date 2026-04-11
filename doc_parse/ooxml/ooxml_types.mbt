///|
pub(all) suberror OoxmlError {
  ZipError(String)
  MissingPart(String)
  InvalidXml(String)
  InvalidPartPath(String)
  RelationshipNotFound(String, String)
}

///|
pub impl Show for OoxmlError with to_string(self : OoxmlError) -> String {
  match self {
    ZipError(msg) => "zip error: " + msg
    MissingPart(path) => "missing OOXML part: " + path
    InvalidXml(msg) => "invalid OOXML xml: " + msg
    InvalidPartPath(path) => "invalid OOXML part path: " + path
    RelationshipNotFound(source_part, rel_id) =>
      "relationship not found: source=" + source_part + ", rel_id=" + rel_id
  }
}

///|
pub impl Show for OoxmlError with output(self : OoxmlError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub struct OoxmlRelationship {
  id : String
  rel_type : String
  target : String
  target_mode : String
  resolved_target : String
}

///|
pub struct OoxmlPackage {
  archive : @zip.ZipArchive
  part_index : Map[String, Int]
  content_types_default : Map[String, String]
  content_types_override : Map[String, String]
}
