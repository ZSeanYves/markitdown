///|
test "pdf v2 text output normalizer trims and collapses spaces" {
  let normalized = pdf_v2_normalize_paragraph_text(
    "  Alpha\u{00A0}\u{2009} Beta   Gamma  ",
  )

  assert_true(normalized == "Alpha Beta Gamma")
}

///|
test "pdf v2 text output normalizer preserves CJK and fixes observed radicals" {
  let normalized = pdf_v2_normalize_paragraph_text("中 ⽂ 换 ⾏ 第 ⻚")

  assert_true(normalized == "中文换行第页")
}

///|
test "pdf v2 text output normalizer keeps punctuation spacing literal-safe" {
  let normalized = pdf_v2_normalize_paragraph_text(
    "hello , world 。 下一句",
  )

  assert_true(normalized == "hello, world。下一句")
}

///|
test "pdf v2 text output normalizer expands ligatures without semantic markdown" {
  let normalized = pdf_v2_normalize_paragraph_text(
    "uniﬁed ﬂow # plain ![not-image](x)",
  )

  assert_true(normalized.contains("unified flow"))
  assert_true(normalized.contains("# plain"))
  assert_true(!normalized.contains("!["))
  assert_true(normalized.contains("! [not-image](x)"))
}

///|
test "pdf v2 text output normalizer repairs common split ligature words" {
  let normalized = pdf_v2_normalize_paragraph_text(
    "This is the fi rst fl ow and Con fi dential text.",
  )

  assert_true(normalized == "This is the first flow and Confidential text.")
}

///|
test "pdf v2 text output normalizer recognizes split cjk fraction page labels" {
  assert_true(pdf_v2_is_page_number_like_noise("3/1"))
  assert_true(pdf_v2_is_page_number_like_noise("第页3/1"))
}
