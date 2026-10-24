///|
/// Traverse a part through the package's existing incremental XML/integrity
/// driver. Consumers own any retained projection; token storage is transient.
/// Ordinary syntax recovery still validates unread UTF8 and ZIP size/CRC.
pub async fn visit_part_xml_tokens(
  pkg : OoxmlPackage,
  part_name : String,
  consume : (@xml.XmlCursorToken) -> Unit raise OoxmlError,
  allow_syntax_recovery~ : Bool = false,
  allow_unbound_prefixes~ : Bool = false,
) -> @xml.XmlCursorStats raise OoxmlError {
  visit_ooxml_xml_tokens(
    pkg.archive,
    normalize_part_name(part_name),
    consume,
    allow_syntax_recovery~,
    allow_unbound_prefixes~,
  )
}
