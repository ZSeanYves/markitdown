///|
fn parse_nav_points(xml : String) -> Array[EpubNavPoint] {
  let out : Array[EpubNavPoint] = []
  let nav_tag = first_start_tag_with_attr(xml, "nav", "epub:type", "toc")
  let nav_region = match nav_tag {
    Some(tag) =>
      match tag_content(xml, tag, "nav") {
        Some(body) => body
        None => return out
      }
    None => return out
  }

  let links = collect_start_tags(nav_region, "a")
  for tag in links {
    let attrs = parse_tag_attributes(tag)
    let href = get_optional_attr(attrs, "href").trim().to_owned()
    if href == "" {
      continue
    }
    match tag_content(nav_region, tag, "a") {
      Some(text) => {
        let label = xml_entity_decode(text.trim().to_owned())
        if label != "" {
          out.push({ label, href, depth: 0, source_path: None })
        }
      }
      None => ()
    }
  }
  out
}

///|
fn parse_ncx_nav_points(
  xml : String,
  source_path : String,
) -> Array[EpubNavPoint] {
  let nav_map_tags = collect_start_tags(xml, "navMap")
  if nav_map_tags.length() == 0 {
    return []
  }
  let nav_map_region = match tag_content(xml, nav_map_tags[0], "navMap") {
    Some(body) => body
    None => return []
  }
  parse_ncx_nav_points_from_elements(
    collect_direct_child_elements(nav_map_region, "navPoint"),
    source_path,
    0,
  )
}

///|
fn parse_ncx_nav_points_from_elements(
  elements : Array[String],
  source_path : String,
  depth : Int,
) -> Array[EpubNavPoint] {
  let out : Array[EpubNavPoint] = []
  for nav_point_xml in elements {
    let label = match tag_text(nav_point_xml, "text") {
      Some(v) => v.trim().to_owned()
      None => ""
    }
    let href = match extract_safe_ncx_href(nav_point_xml, source_path) {
      Some(v) => v
      None => ""
    }
    if label != "" && href != "" {
      out.push({ label, href, depth, source_path: Some(source_path) })
    }

    let child_nav_points = collect_direct_child_elements(
      inner_element_content(nav_point_xml, "navPoint"),
      "navPoint",
    )
    if child_nav_points.length() > 0 {
      out.append(
        parse_ncx_nav_points_from_elements(
          child_nav_points,
          source_path,
          depth + 1,
        ),
      )
    }
  }
  out
}

///|
fn inner_element_content(xml : String, local_name : String) -> String {
  let tags = collect_start_tags(xml, local_name)
  if tags.length() == 0 {
    return ""
  }
  match tag_content(xml, tags[0], local_name) {
    Some(body) => body
    None => ""
  }
}

///|
fn extract_safe_ncx_href(
  nav_point_xml : String,
  source_path : String,
) -> String? {
  let content_tags = collect_start_tags(nav_point_xml, "content")
  if content_tags.length() == 0 {
    return None
  }
  let attrs = parse_tag_attributes(content_tags[0])
  let raw_href = get_optional_attr(attrs, "src").trim().to_owned()
  if raw_href == "" {
    return None
  }
  if raw_href.has_prefix("#") {
    return Some(raw_href)
  }
  let ncx_dir = dirname_of_part(source_path)
  let validated = try resolve_opf_href(ncx_dir, raw_href) |> Ok catch {
    e => Err(e)
  }
  match validated {
    Ok(_) => Some(raw_href)
    Err(_) => None
  }
}

///|
fn collect_direct_child_elements(
  xml : String,
  local_name : String,
) -> Array[String] {
  collect_direct_child_elements_in_parent(xml, local_name)
}

///|
fn collect_direct_child_elements_in_parent(
  xml : String,
  local_name : String,
) -> Array[String] {
  let out : Array[String] = []
  let chars = xml.to_array()
  let n = chars.length()
  let mut i = 0
  let mut depth = 0
  let mut element_start = -1

  while i < n {
    if chars[i] != '<' {
      i += 1
      continue
    }
    if i + 1 < n && (chars[i + 1] == '?' || chars[i + 1] == '!') {
      i += 1
      continue
    }

    let mut tag_end = i + 1
    while tag_end < n && chars[tag_end] != '>' {
      tag_end += 1
    }
    if tag_end >= n {
      break
    }

    let tag = xml[i:tag_end + 1].to_owned()
    if i + 1 < n && chars[i + 1] == '/' {
      if end_tag_local_name(tag) == local_name {
        depth -= 1
        if depth == 0 && element_start >= 0 {
          out.push(xml[element_start:tag_end + 1].to_owned())
          element_start = -1
        }
      }
      i = tag_end + 1
      continue
    }

    if start_tag_local_name(tag) == local_name {
      if depth == 0 {
        element_start = i
      }
      if start_tag_is_self_closing(tag) {
        if depth == 0 {
          out.push(xml[i:tag_end + 1].to_owned())
          element_start = -1
        }
      } else {
        depth += 1
      }
    }
    i = tag_end + 1
  }

  out
}
