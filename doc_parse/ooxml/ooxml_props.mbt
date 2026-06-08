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
    last_modified_by: tag_text(xml, "lastModifiedBy"),
    description: tag_text(xml, "description"),
    keywords: tag_text(xml, "keywords"),
    category: tag_text(xml, "category"),
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
    company: tag_text(xml, "Company"),
    manager: tag_text(xml, "Manager"),
    pages: tag_text(xml, "Pages"),
    words: tag_text(xml, "Words"),
    slides: tag_text(xml, "Slides"),
    sheets: tag_text(xml, "Worksheets"),
  }
}

///|
/// Read lightweight custom document properties.
///
/// Missing `docProps/custom.xml` is represented by an empty array.
pub fn read_custom_properties(pkg : OoxmlPackage) -> Array[OoxmlCustomProperty] {
  let xml = read_optional_xml_text(pkg, "docProps/custom.xml")
  if xml == "" {
    return []
  }
  parse_custom_properties_xml(xml)
}

///|
fn parse_custom_properties_xml(xml : String) -> Array[OoxmlCustomProperty] {
  let props : Array[OoxmlCustomProperty] = []
  let mut cursor = 0
  while true {
    let start = find_substring_from(xml, "<property", cursor)
    match start {
      None => break
      Some(prop_start) => {
        let end = find_substring_from(xml, "</property>", prop_start)
        match end {
          None => break
          Some(prop_end) => {
            let block = xml[
              prop_start:prop_end + "</property>".length()
            ].to_owned()
            match parse_custom_property_block(block) {
              Some(prop) => props.push(prop)
              None => ()
            }
            cursor = prop_end + "</property>".length()
          }
        }
      }
    }
  }
  props
}

///|
fn parse_custom_property_block(block : String) -> OoxmlCustomProperty? {
  let open_end = find_substring_from(block, ">", 0)
  let open_tag = match open_end {
    Some(pos) => block[0:pos + 1].to_owned()
    None => return None
  }
  let attrs = parse_tag_attributes(open_tag)
  let name = match attrs.get("name") {
    Some(value) =>
      if value.trim() == "" {
        return None
      } else {
        xml_entity_decode(value.trim().to_owned())
      }
    None => return None
  }

  let vt_start = find_substring_from(block, "<vt:", open_tag.length())
  let value_type = match vt_start {
    Some(pos) => {
      let vt_end = find_substring_from(block, ">", pos)
      match vt_end {
        Some(end_pos) => {
          let tag = block[pos:end_pos + 1].to_owned()
          let local_name = start_tag_local_name(tag)
          if local_name == "" {
            None
          } else {
            Some(local_name)
          }
        }
        None => None
      }
    }
    None => None
  }
  let value = match value_type {
    Some(kind) => tag_text(block, kind).unwrap_or("")
    None => ""
  }
  Some({ name, value, value_type })
}

///|
fn find_substring_from(
  haystack : String,
  needle : String,
  start : Int,
) -> Int? {
  if needle == "" {
    return Some(start)
  }
  if start < 0 || start >= haystack.length() {
    return None
  }
  let rest = haystack[start:].to_owned()
  let idx = find_substring(rest, needle)
  if idx < 0 {
    None
  } else {
    Some(start + idx)
  }
}

///|
fn read_optional_xml_text(pkg : OoxmlPackage, part_name : String) -> String {
  read_part_text(pkg, part_name) catch {
    _ => ""
  }
}
