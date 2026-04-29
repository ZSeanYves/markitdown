///|
test "PdfName basics" {
  let n1 = PdfName::of_string("/Type")
  assert_true(n1.equal_string_bytes("/Type"))
  assert_eq(n1.to_string_bytes(), "/Type")

  // Missing leading slash gets normalized on construction.
  let n2 = @pdfe.with_logger(_ => (), fn() { PdfName::of_string("Type") })
  assert_true(n2.equal_string_bytes("/Type"))
  assert_eq(n2.to_string_bytes(), "/Type")
}

///|
test "PdfName lexical compare" {
  let a = PdfName::of_string("/A")
  let ab = PdfName::of_string("/AB")
  let b = PdfName::of_string("/B")
  assert_true(a.lexical_compare(ab) < 0) // prefix is smaller
  assert_true(ab.lexical_compare(a) > 0)
  assert_true(a.lexical_compare(b) < 0)
  assert_true(a.lexical_compare(a) == 0)
}
