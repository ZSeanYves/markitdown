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

///|
test "pdf lower layer shared cleanup repairs missing ascii punctuation spaces in prose-like text" {
  assert_eq(
    @cor.normalize_pdf_text_cleanup("capacities?We desire"),
    "capacities? We desire",
  )
  assert_eq(
    @cor.normalize_pdf_text_cleanup("collaboration?(2)"),
    "collaboration? (2)",
  )
  assert_eq(@cor.normalize_pdf_text_cleanup("models(LLMs)"), "models (LLMs)")
  assert_eq(@cor.normalize_pdf_text_cleanup("e.g., GPT-4"), "e.g., GPT-4")
  assert_eq(@cor.normalize_pdf_text_cleanup("human(s)"), "human(s)")
  assert_eq(
    @cor.normalize_pdf_text_cleanup("Uses drawImage(), which should work."),
    "Uses drawImage(), which should work.",
  )
  assert_eq(
    @cor.normalize_pdf_text_cleanup("Print Date 12/15/2024 14: 30: 22"),
    "Print Date 12/15/2024 14:30:22",
  )
  assert_eq(@cor.normalize_pdf_text_cleanup("$11, 250.00"), "$11,250.00")
}
