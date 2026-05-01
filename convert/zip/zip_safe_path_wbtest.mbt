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
test "zip hidden macos metadata strategy" {
  assert_eq(is_hidden_or_macos_metadata("__MACOSX/._file"), true)
  assert_eq(is_hidden_or_macos_metadata("dir/.DS_Store"), true)
  assert_eq(is_hidden_or_macos_metadata("dir/._image.png"), true)
  assert_eq(is_hidden_or_macos_metadata("dir/.env"), false)
}

///|
test "zip entry extension classification" {
  assert_eq(is_supported_entry_ext("json"), true)
  assert_eq(is_supported_entry_ext("txt"), false)
  assert_eq(is_explicitly_deferred_ext("pdf"), true)
  assert_eq(is_nested_archive_ext("zip"), true)
  assert_eq(is_nested_archive_ext("epub"), true)
}
