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
