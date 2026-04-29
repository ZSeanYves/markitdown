///|
/// Read lightweight core document properties.
///
/// Missing `docProps/core.xml` is represented by a struct whose fields are
/// `None`.
pub fn read_core_properties(pkg : OoxmlPackage) -> OoxmlCoreProperties {
  let xml = read_optional_xml_text(pkg, "docProps/core.xml")
  {
    title: tag_text(xml, "title"),
    subject: tag_text(xml, "subject"),
    creator: tag_text(xml, "creator"),
    description: tag_text(xml, "description"),
    keywords: tag_text(xml, "keywords"),
    created: tag_text(xml, "created"),
    modified: tag_text(xml, "modified"),
  }
}

///|
/// Read lightweight app document properties.
///
/// Missing `docProps/app.xml` is represented by a struct whose fields are
/// `None`.
pub fn read_app_properties(pkg : OoxmlPackage) -> OoxmlAppProperties {
  let xml = read_optional_xml_text(pkg, "docProps/app.xml")
  {
    application: tag_text(xml, "Application"),
    pages: tag_text(xml, "Pages"),
    words: tag_text(xml, "Words"),
    slides: tag_text(xml, "Slides"),
    sheets: tag_text(xml, "Worksheets"),
  }
}

///|
fn read_optional_xml_text(pkg : OoxmlPackage, part_name : String) -> String {
  let bytes = read_part_bytes(pkg, part_name) catch { _ => return "" }
  bytes_to_xml_text(bytes)
}
