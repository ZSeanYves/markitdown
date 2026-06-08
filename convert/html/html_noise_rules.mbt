///|
/// Product policy path: parser facts can expose noise candidates, but
/// skip/preserve decisions for navigation/sidebar/footer/search chrome remain
/// convert-owned behavior.
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
