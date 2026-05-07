///|
test "pdf noise key uses shared pdf text normalization" {
  let key = normalize_noise_key("Page\u{00A0}1\u{200B}2")
  assert_eq(key, "page ##")
}

///|
test "pdf caption prefix detection accepts nbsp separated figure label" {
  assert_eq(looks_like_image_caption_prefix("Figure\u{00A0}1"), true)
  assert_eq(looks_like_table_caption_prefix("Table\u{00A0}2"), true)
}

///|
test "pdf comparison text collapses line breaks and tabs for heuristics" {
  let text = normalize_pdf_comparison_text("Figure\r\n1\tOverview")
  assert_eq(text, "Figure 1 Overview")
}

///|
test "pdf comparison text removes cjk comparison spacing" {
  let text = normalize_pdf_comparison_text("中 文\u{00A0}标题")
  assert_eq(text, "中文标题")
}
