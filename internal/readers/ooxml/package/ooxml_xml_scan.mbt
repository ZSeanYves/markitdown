///|
/// Convert ZIP entry bytes to XML text.
///
/// Reject invalid UTF-8 before package XML enters the text caches.
fn bytes_to_xml_text(bytes : Bytes) -> String raise OoxmlError {
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise InvalidEncoding("utf8 decode failed")
  }
}
