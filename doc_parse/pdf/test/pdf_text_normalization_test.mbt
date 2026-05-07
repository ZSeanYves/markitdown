///|
test "pdf lower layer expands ligatures and strips soft hyphen" {
  let normalized = @text.normalize_unicode_compat("o\u{FB03}ce hy\u{00AD}phen")
  assert_eq(normalized, "office hyphen")
}

///|
test "pdf lower layer removes zero width and normalizes nbsp" {
  let normalized = @text.normalize_unicode_compat("A\u{00A0}B\u{200B}C")
  assert_eq(normalized, "A BC")
}
