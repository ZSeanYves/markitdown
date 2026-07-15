///|
fn odf_repeated_count(element : @dxml.XmlElement, name : String) -> Int raise {
  odf_parse_repeated_count(odf_attr(element, name), name)
}

///|
fn odf_parse_repeated_count(raw_value : String?, name : String) -> Int raise {
  match raw_value {
    Some(raw) => {
      let count = @string.parse_int(raw.trim().to_owned()) catch {
        _ => raise ParseError("invalid ODF repeated count for " + name)
      }
      let limit = if name == "table:number-rows-repeated" {
        1_048_576
      } else {
        16_384
      }
      if count <= 0 || count > limit {
        raise ParseError("ODF repeated count exceeds limit for " + name)
      }
      count
    }
    None => 1
  }
}

///|
fn odf_attr(element : @dxml.XmlElement, name : String) -> String? {
  for attr in element.attributes {
    if attr.name == name {
      return Some(attr.value)
    }
  }
  None
}

///|
fn odf_bounded_repeat_count(
  element : @dxml.XmlElement,
  name : String,
  limit : Int,
) -> Int {
  let count = match odf_attr(element, name) {
    Some(raw) => @string.parse_int(raw.trim().to_owned()) catch { _ => 1 }
    None => 1
  }
  if count <= 0 {
    1
  } else if count > limit {
    limit
  } else {
    count
  }
}

///|
fn odf_collect_text(element : @dxml.XmlElement) -> String {
  let out : Array[String] = []
  odf_collect_text_into(element, out)
  out.join("")
}

///|
fn odf_collect_text_into(
  element : @dxml.XmlElement,
  out : Array[String],
) -> Unit {
  for child in element.children {
    match child {
      Text(text) => out.push(text.text)
      CData(text) => out.push(text.text)
      Element(next) =>
        if next.name == "text:line-break" {
          out.push("\n")
        } else if next.name == "text:s" {
          out.push(" ".repeat(odf_bounded_repeat_count(next, "text:c", 1_024)))
        } else if next.name == "text:tab" {
          out.push("\t")
        } else {
          odf_collect_text_into(next, out)
        }
      _ => ()
    }
  }
}

///|
fn odf_collect_odt_inlines(element : @dxml.XmlElement) -> Array[OdtInline] {
  let out : Array[OdtInline] = []
  odf_collect_odt_inlines_into(element, out)
  odf_compact_odt_inlines(out)
}

///|
fn odf_collect_odt_inlines_into(
  element : @dxml.XmlElement,
  out : Array[OdtInline],
) -> Unit {
  for child in element.children {
    match child {
      Text(text) =>
        if text.text != "" {
          out.push(odf_plain_odt_inline(text.text))
        }
      CData(text) =>
        if text.text != "" {
          out.push(odf_plain_odt_inline(text.text))
        }
      Element(next) =>
        if next.name == "text:a" {
          let text = odf_collect_text(next)
          if text != "" {
            out.push({
              text,
              href: odf_attr(next, "xlink:href"),
              note_id: None,
              note_kind: None,
              note_marker: None,
              note_body: None,
            })
          }
        } else if next.name == "office:annotation" {
          match odf_extract_comment_inline(next) {
            Some(comment) => out.push(comment)
            None => ()
          }
        } else if next.name == "text:note" {
          match odf_extract_note(next) {
            Some(note) =>
              out.push({
                text: note.citation,
                href: None,
                note_id: Some(note.id),
                note_kind: Some(note.kind),
                note_marker: Some(note.citation),
                note_body: Some(note.body),
              })
            None => ()
          }
        } else if next.name == "text:line-break" {
          out.push(odf_plain_odt_inline("\n"))
        } else if next.name == "text:s" {
          out.push(
            odf_plain_odt_inline(
              " ".repeat(odf_bounded_repeat_count(next, "text:c", 1_024)),
            ),
          )
        } else if next.name == "text:tab" {
          out.push(odf_plain_odt_inline("\t"))
        } else {
          odf_collect_odt_inlines_into(next, out)
        }
      _ => ()
    }
  }
}

///|
fn odf_plain_odt_inline(text : String) -> OdtInline {
  {
    text,
    href: None,
    note_id: None,
    note_kind: None,
    note_marker: None,
    note_body: None,
  }
}

///|
fn odf_compact_odt_inlines(inlines : Array[OdtInline]) -> Array[OdtInline] {
  let out : Array[OdtInline] = []
  for inline in inlines {
    if inline.text == "" {
      continue
    }
    if out.length() == 0 {
      out.push(inline)
      continue
    }
    let last = out[out.length() - 1]
    if last.href == inline.href &&
      last.note_id == inline.note_id &&
      last.note_kind == inline.note_kind &&
      last.note_marker == inline.note_marker &&
      last.note_body == inline.note_body {
      out[out.length() - 1] = {
        text: last.text + inline.text,
        href: last.href,
        note_id: last.note_id,
        note_kind: last.note_kind,
        note_marker: last.note_marker,
        note_body: last.note_body,
      }
    } else {
      out.push(inline)
    }
  }
  out
}

///|
fn odf_text_from_inlines(inlines : Array[OdtInline]) -> String {
  let out : Array[String] = []
  for inline in inlines {
    out.push(inline.text)
  }
  out.join("")
}

///|
fn odf_extract_note(element : @dxml.XmlElement) -> OdtNote? {
  let kind = match odf_attr(element, "text:note-class") {
    Some(value) =>
      if value.trim().to_lower() == "endnote" {
        "endnote"
      } else {
        "footnote"
      }
    None => "footnote"
  }
  let id = odf_attr(element, "text:id").unwrap_or(
    kind + "-" + element.span.line_start.to_string(),
  )
  let mut citation = ""
  let mut body = ""
  for child in element.children {
    match child {
      Element(node) =>
        if node.name == "text:note-citation" {
          citation = odf_collect_text(node).trim().to_owned()
        } else if node.name == "text:note-body" {
          body = odf_collect_text(node).trim().to_owned()
        }
      _ => ()
    }
  }
  if body == "" {
    return None
  }
  let marker = if citation == "" {
    if kind == "endnote" {
      "[^e1]"
    } else {
      "[^1]"
    }
  } else if kind == "endnote" {
    "[^e" + citation + "]"
  } else {
    "[^" + citation + "]"
  }
  Some({ id, kind, citation: marker, body, author: None })
}

///|
fn odf_extract_comment_inline(element : @dxml.XmlElement) -> OdtInline? {
  let author = odf_extract_annotation_child_text(element, "dc:creator")
  let date = odf_extract_annotation_child_text(element, "dc:date")
  let body = odf_extract_annotation_body_text(element)
  if body == "" {
    return None
  }
  let id = "comment-" + element.span.line_start.to_string()
  let marker = "[comment " + element.span.line_start.to_string() + "]"
  Some({
    text: marker,
    href: None,
    note_id: Some(id),
    note_kind: Some("comment"),
    note_marker: Some(marker),
    note_body: Some(odf_compose_annotation_body(author, date, body)),
  })
}

///|
fn odf_extract_annotation_child_text(
  element : @dxml.XmlElement,
  name : String,
) -> String? {
  for child in element.children {
    match child {
      Element(node) =>
        if node.name == name {
          let text = odf_collect_text(node).trim().to_owned()
          if text != "" {
            return Some(text)
          }
        }
      _ => ()
    }
  }
  None
}

///|
fn odf_compose_annotation_body(
  author : String?,
  date : String?,
  body : String,
) -> String {
  let parts : Array[String] = []
  match author {
    Some(value) => parts.push(value)
    None => ()
  }
  match date {
    Some(value) => parts.push("(" + value + ")")
    None => ()
  }
  parts.push(body)
  parts.join(": ")
}

///|
fn odf_extract_annotation_body_text(element : @dxml.XmlElement) -> String {
  let body_parts : Array[String] = []
  for child in element.children {
    match child {
      Element(node) =>
        if node.name == "text:p" {
          let text = odf_collect_text(node).trim().to_owned()
          if text != "" {
            body_parts.push(text)
          }
        }
      _ => ()
    }
  }
  body_parts.join("\n").trim().to_owned()
}

///|
fn odf_extract_metadata(doc : @dxml.XmlDocument) -> OdfMetadataSummary {
  {
    title: odf_find_first_text(doc, "dc:title"),
    subject: odf_find_first_text(doc, "dc:subject"),
    description: odf_find_first_text(doc, "dc:description"),
    language: odf_find_first_text(doc, "dc:language"),
  }
}

///|
fn odf_find_first_text(doc : @dxml.XmlDocument, name : String) -> String? {
  match doc.root {
    Some(root) => odf_find_first_text_in_element(root, name)
    None => None
  }
}

///|
fn odf_find_first_text_in_element(
  element : @dxml.XmlElement,
  name : String,
) -> String? {
  if element.name == name {
    let text = odf_collect_text(element).trim().to_owned()
    if text != "" {
      return Some(text)
    }
  }
  for child in element.children {
    match child {
      Element(next) =>
        match odf_find_first_text_in_element(next, name) {
          Some(value) => return Some(value)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn odf_media_type_for_href(
  archive : @dzip.ZipArchive,
  href : String,
) -> String? {
  let trimmed = href.trim()
  if trimmed == "" {
    return None
  }
  let ext = match trimmed.split(".").to_array().last() {
    Some(value) => value.trim().to_lower().to_owned()
    None => ""
  }
  match ext {
    "png" => Some("image/png")
    "jpg" => Some("image/jpeg")
    "jpeg" => Some("image/jpeg")
    "gif" => Some("image/gif")
    "svg" => Some("image/svg+xml")
    _ =>
      if @dzip.has_entry(archive, trimmed.to_owned()) {
        Some("application/octet-stream")
      } else {
        None
      }
  }
}

///|
fn odf_read_entry_optional(archive : @dzip.ZipArchive, path : String) -> Bytes? {
  let normalized = path.trim().to_owned()
  if normalized == "" || !@dzip.has_entry(archive, normalized) {
    return None
  }
  try @dzip.read_entry(archive, path.trim().to_owned()) |> Some catch {
    _ => None
  }
}

///|
fn odf_paragraph_is_code_like(
  element : @dxml.XmlElement,
  styles : Map[String, OdfTextStyle],
) -> Bool {
  match odf_attr(element, "text:style-name") {
    Some(name) =>
      odf_resolved_style_names(name, styles).any(value => {
        let lower = value.to_lower()
        lower.contains("code") ||
        lower.contains("pre") ||
        lower.contains("source")
      })
    None => false
  }
}

///|
fn odf_paragraph_heading_level(
  element : @dxml.XmlElement,
  styles : Map[String, OdfTextStyle],
) -> Int? {
  match odf_attr(element, "text:style-name") {
    Some(name) => {
      let mut heading_seen = false
      for value in odf_resolved_style_names(name, styles) {
        let normalized = value.replace_all(old="_20_", new=" ").to_lower()
        if normalized.contains("heading") || normalized.contains("title") {
          heading_seen = true
          for level in 1..<=7 {
            if normalized.contains(level.to_string()) {
              return Some(level)
            }
          }
        }
      }
      if heading_seen {
        Some(1)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn odf_resolved_style_names(
  initial : String,
  styles : Map[String, OdfTextStyle],
) -> Array[String] {
  let names : Array[String] = []
  let mut current : String? = Some(initial)
  let mut depth = 0
  while current is Some(_) && depth < 32 {
    let name = current.unwrap()
    if names.contains(name) {
      break
    }
    names.push(name)
    match styles.get(name) {
      Some(style) => {
        match style.display_name {
          Some(display) if !names.contains(display) => names.push(display)
          _ => ()
        }
        current = style.parent_name
      }
      None => current = None
    }
    depth += 1
  }
  names
}

///|
fn odf_collect_text_styles(
  archive : @dzip.ZipArchive,
  package_info : OdfPackageInfo,
  content : @dxml.XmlDocument,
) -> Map[String, OdfTextStyle] {
  let styles : Map[String, OdfTextStyle] = Map([])
  match content.root {
    Some(root) => odf_collect_text_styles_from_element(root, styles)
    None => ()
  }
  match package_info.styles_path {
    Some(path) => {
      let parsed = try
        @dxml.parse_xml_document(odf_read_entry_text(archive, path)) |> Ok
      catch {
        _ => Err(())
      }
      match parsed {
        Ok(doc) =>
          match doc.root {
            Some(root) => odf_collect_text_styles_from_element(root, styles)
            None => ()
          }
        Err(_) => ()
      }
    }
    None => ()
  }
  styles
}

///|
fn odf_collect_text_styles_from_element(
  element : @dxml.XmlElement,
  styles : Map[String, OdfTextStyle],
) -> Unit {
  if element.name == "style:style" &&
    odf_attr(element, "style:family") == Some("paragraph") {
    match odf_attr(element, "style:name") {
      Some(name) =>
        styles.set(name, {
          display_name: odf_attr(element, "style:display-name"),
          parent_name: odf_attr(element, "style:parent-style-name"),
        })
      None => ()
    }
  }
  for child in element.children {
    match child {
      Element(next) => odf_collect_text_styles_from_element(next, styles)
      _ => ()
    }
  }
}
