///|
test "pdf lower layer core cleanup expands ligatures and strips soft hyphen" {
  let normalized = @text.normalize_unicode_compat("o\u{FB03}ce hy\u{00AD}phen")
  assert_eq(normalized, "office hyphen")
}

///|
test "pdf lower layer core cleanup removes zero width and normalizes nbsp" {
  let normalized = @text.normalize_unicode_compat("A\u{00A0}B\u{200B}C")
  assert_eq(normalized, "A BC")
}

///|
test "pdf lower layer shared cleanup preserves previous basic space collapse behavior before pdf specific post step" {
  let normalized = @cor.normalize_pdf_text_cleanup(
    " \r\nA\u{00A0}\u{2009}B\u{200B}hy\u{00AD}phen\tﬁ  ",
  )
  assert_eq(normalized, "A Bhyphen fi")
}
