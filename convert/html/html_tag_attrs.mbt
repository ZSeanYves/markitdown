///|
/// Low-level helper path for existing guarded scanners that still read raw tag
/// strings. New parser-fact consumers should use structured parser attrs.
fn html_open_tag_name(tag : String) -> String? {
  @dphtml.html_tag_name(tag)
}

///|
fn read_html_attr_value(tag : String, attr_name : String) -> String? {
  @dphtml.html_raw_attr_value(tag, attr_name)
}
