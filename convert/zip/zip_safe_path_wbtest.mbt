///|
test "zip normalize rejects unsafe paths" {
  assert_true(normalize_zip_entry_path("../evil.txt") is None)
  assert_true(normalize_zip_entry_path("/abs.txt") is None)
  assert_true(normalize_zip_entry_path("C:/evil.txt") is None)
  assert_true(normalize_zip_entry_path("a/../evil.txt") is None)
  assert_true(normalize_zip_entry_path("") is None)
}

///|
test "zip normalize converts backslashes" {
  match normalize_zip_entry_path("dir\\file.md") {
    Some(path) => assert_eq(path, "dir/file.md")
    None => fail("expected normalized path")
  }
}

///|
test "zip extracted entry path stays inside root" {
  let out = extracted_entry_path("/tmp/zip-root", "site/img/pic.png")
  assert_eq(out, "/tmp/zip-root/site/img/pic.png")

  let bad = try? extracted_entry_path("/tmp/zip-root", "../secret.png")
  assert_true(bad is Err(_))
}

///|
test "zip html local image src safety stays conservative" {
  assert_eq(is_local_html_image_src("img/pic.png"), true)
  assert_eq(is_local_html_image_src("img/pic.png?cache=1"), true)
  assert_eq(is_local_html_image_src("img/pic.png#preview"), true)
  assert_eq(is_local_html_image_src("https://example.com/pic.png"), false)
  assert_eq(is_local_html_image_src("data:image/png;base64,abcd"), false)
  assert_eq(is_local_html_image_src("//cdn.example.com/pic.png"), false)
  assert_eq(is_local_html_image_src("/img/pic.png"), false)
  assert_eq(is_local_html_image_src("../secret.png"), false)
  assert_eq(is_local_html_image_src("img\\pic.png"), false)
  assert_eq(is_local_html_image_src("file:pic.png"), false)
  assert_eq(is_local_html_image_src("ftp://example.com/pic.png"), false)
  assert_eq(is_local_html_image_src("C:/pic.png"), false)
}

///|
test "zip hidden macos metadata strategy" {
  assert_eq(is_hidden_or_macos_metadata("__MACOSX/._file"), true)
  assert_eq(is_hidden_or_macos_metadata("dir/.DS_Store"), true)
  assert_eq(is_hidden_or_macos_metadata("dir/._image.png"), true)
  assert_eq(is_hidden_or_macos_metadata("dir/.env"), false)
}

///|
test "zip entry extension classification" {
  assert_eq(is_supported_entry_ext("json"), true)
  assert_eq(is_supported_entry_ext("docx"), true)
  assert_eq(is_supported_entry_ext("pdf"), true)
  assert_eq(is_supported_entry_ext("pptx"), true)
  assert_eq(is_supported_entry_ext("txt"), true)
  assert_eq(is_supported_entry_ext("xml"), true)
  assert_eq(is_html_entry_ext("html"), true)
  assert_eq(is_html_entry_ext("pdf"), false)
  assert_eq(is_nested_archive_ext("zip"), true)
  assert_eq(is_nested_archive_ext("epub"), true)
}
