///|
/// Product policy path: parser facts can expose noise candidates, but
/// skip/preserve decisions for navigation/sidebar/footer/search chrome remain
/// convert-owned behavior.
fn find_skippable_html_noise_subtree_end(
  bs : Bytes,
  open_idx : Int,
  open_tag_end_idx : Int,
  tag : String,
) -> Int? {
  let tag_name = html_open_tag_name(tag)
  match tag_name {
    None => None
    Some(name) =>
      if !html_should_skip_noise_subtree(name, tag) {
        None
      } else {
        match find_matching_tag_end(bs, open_idx, name) {
          None => None
          Some(close_idx) => {
            let inner = bs[open_tag_end_idx + 1:close_idx].to_owned()
            if html_noise_subtree_should_be_preserved(name, tag, inner) {
              None
            } else {
              Some(close_idx + ("</" + name + ">").length())
            }
          }
        }
      }
  }
}

///|
fn html_should_skip_noise_subtree(tag_name : String, tag : String) -> Bool {
  if tag_name == "nav" || tag_name == "footer" {
    return true
  }

  if html_role_is_noise(tag) {
    return true
  }

  if html_attr_value_has_noise_token(tag, "id") ||
    html_attr_value_has_noise_token(tag, "class") {
    return true
  }

  false
}

///|
fn html_noise_subtree_should_be_preserved(
  tag_name : String,
  tag : String,
  inner : Bytes,
) -> Bool {
  if !html_tag_has_navigation_like_noise_token(tag_name, tag) {
    return false
  }
  html_noise_subtree_has_substantial_prose(inner)
}

///|
fn html_tag_has_navigation_like_noise_token(
  tag_name : String,
  tag : String,
) -> Bool {
  if tag_name == "nav" {
    return true
  }

  if html_role_is_navigation_like(tag) {
    return true
  }

  html_attr_value_has_navigation_like_noise_token(tag, "id") ||
  html_attr_value_has_navigation_like_noise_token(tag, "class")
}

///|
fn html_role_is_navigation_like(tag : String) -> Bool {
  let role = read_html_attr_value(tag, "role")
    .map(fn(value) { value.to_lower().trim().to_owned() })
    .unwrap_or("")
  role == "navigation" || role == "menu"
}

///|
fn html_attr_value_has_navigation_like_noise_token(
  tag : String,
  attr_name : String,
) -> Bool {
  match read_html_attr_value(tag, attr_name) {
    None => false
    Some(value) => html_contains_navigation_like_noise_token(value.to_lower())
  }
}

///|
fn html_contains_navigation_like_noise_token(value : String) -> Bool {
  value.contains("toc") ||
  value.contains("table-of-contents") ||
  value.contains("navbox") ||
  value.contains("navbar") ||
  value.contains("navigation") ||
  value.contains("menu") ||
  value.contains("breadcrumb") ||
  value.contains("vector-menu")
}

///|
fn html_noise_subtree_has_substantial_prose(inner : Bytes) -> Bool {
  if find_bytes(inner, pat("<p"), 0) is None {
    return false
  }

  let text = html_pre_text_from_bytes(inner)
  text.length() >= 80
}

///|
fn html_role_is_noise(tag : String) -> Bool {
  let role = read_html_attr_value(tag, "role")
    .map(fn(value) { value.to_lower().trim().to_owned() })
    .unwrap_or("")
  role == "navigation" ||
  role == "banner" ||
  role == "contentinfo" ||
  role == "search"
}

///|
fn html_attr_value_has_noise_token(tag : String, attr_name : String) -> Bool {
  match read_html_attr_value(tag, attr_name) {
    None => false
    Some(value) => html_contains_noise_token(value.to_lower())
  }
}

///|
fn html_contains_noise_token(value : String) -> Bool {
  value.contains("toc") ||
  value.contains("table-of-contents") ||
  value.contains("navbox") ||
  value.contains("navbar") ||
  value.contains("navigation") ||
  value.contains("sidebar") ||
  value.contains("side-bar") ||
  value.contains("infobox") ||
  value.contains("metadata") ||
  value.contains("mw-editsection") ||
  value.contains("editsection") ||
  value.contains("reflist") ||
  value.contains("authority-control") ||
  value.contains("catlinks") ||
  value.contains("portal") ||
  value.contains("footer") ||
  value.contains("search") ||
  value.contains("menu") ||
  value.contains("toolbar") ||
  value.contains("breadcrumb") ||
  value.contains("language") ||
  value.contains("languages") ||
  value.contains("interlanguage") ||
  value.contains("vector-menu") ||
  value.contains("mw-jump") ||
  value.contains("sitenotice") ||
  value.contains("centralnotice") ||
  value.contains("printfooter") ||
  value.contains("sistersitebox") ||
  value.contains("vertical-navbox")
}
