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
    "This is the fi rst fl ow, di ff erent, and Con fi dential text.",
  )

  assert_true(
    normalized == "This is the first flow, different, and Confidential text.",
  )
}

///|
test "pdf v2 text output normalizer keeps split ligature repair closed" {
  let arbitrary = pdf_v2_normalize_paragraph_text(
    "The d i f f e r e n t spaced letters stay visible.",
  )
  let normal_words = pdf_v2_normalize_paragraph_text(
    "normal words with spaces stay unchanged",
  )

  assert_true(arbitrary.contains("d i f f e r e n t"))
  assert_true(!arbitrary.contains("different spaced"))
  assert_true(normal_words == "normal words with spaces stay unchanged")
}

///|
test "pdf v2 text output normalizer recognizes split cjk fraction page labels" {
  assert_true(pdf_v2_is_page_number_like_noise("3/1"))
  assert_true(pdf_v2_is_page_number_like_noise("第页3/1"))
}

///|
test "pdf v2 text output normalizer guards heading tail split scope" {
  assert_true(
    pdf_v2_candidate_strip_heading_tail_body(
      "1.1 研究目标本节说明研究目标和验证范围。",
    ) ==
    "1.1 研究目标",
  )
  assert_true(
    pdf_v2_candidate_strip_heading_tail_body(
      "第一段：这是一个用于验证 PDF 文本抽取的样例。",
    ) ==
    "第一段：这是一个用于验证 PDF 文本抽取的样例。",
  )
  assert_true(
    !pdf_v2_numbered_section_heading_waits_across_blank(
      "第一段：", "这是正文",
    ),
  )
}

///|
test "pdf v2 text output normalizer joins conservative CJK hardwrap continuations" {
  assert_true(
    pdf_v2_output_line_continues_hardwrap("用于验证 PDF", "文本抽取"),
  )
  assert_true(
    pdf_v2_output_line_continues_hardwrap("首先完成统一", "IR，"),
  )
  assert_true(
    pdf_v2_output_line_continues_hardwrap(
      "下一段：", "中文也可能被硬换行",
    ),
  )
}

///|
test "pdf v2 text output normalizer keeps unsafe CJK ASCII breaks separate" {
  assert_true(
    !pdf_v2_output_line_continues_hardwrap("用于验证 pdf", "文本抽取"),
  )
  assert_true(
    !pdf_v2_output_line_continues_hardwrap("完整句子。", "下一段正文"),
  )
  assert_true(
    !pdf_v2_cross_page_output_line_continues("Heading", "下一段正文"),
  )
}

///|
test "pdf v2 text output normalizer rejects cross page structural starts" {
  assert_true(
    !pdf_v2_cross_page_output_line_continues(
      "continues across the page", "- list item",
    ),
  )
  assert_true(
    !pdf_v2_cross_page_output_line_continues(
      "continues across the page", "Next Section",
    ),
  )
  assert_true(
    !pdf_v2_cross_page_output_line_continues("continues across the page", "3"),
  )
}

///|
test "pdf v2 text output normalizer allows only unfinished cross page continuation" {
  assert_true(
    pdf_v2_cross_page_output_line_continues(
      "continues across the page", "break and resumes",
    ),
  )
  assert_true(
    !pdf_v2_cross_page_output_line_continues(
      "This section ends cleanly here.", "Next topic",
    ),
  )
}

///|
fn text_output_normalizer_test_has_paragraph(
  paragraphs : Array[PdfV2TextOutputParagraph],
  text : String,
) -> Bool {
  for paragraph in paragraphs {
    if paragraph.text == text {
      return true
    }
  }
  false
}

///|
fn text_output_normalizer_test_paragraph(
  fragment_index : Int,
  text : String,
) -> PdfV2TextOutputParagraph {
  {
    text,
    fragment_index,
    line_count: 1,
    source_refs: [],
    reason_tags: ["text_output_normalizer_test"],
  }
}

///|
test "pdf v2 text output normalizer requires repeated artifact evidence" {
  let options = default_pdf_v2_product_bridge_options()
  let single = pdf_v2_filter_repeated_artifact_paragraphs(
    [
      text_output_normalizer_test_paragraph(0, "Project Report"),
      text_output_normalizer_test_paragraph(1, "Confidential"),
      text_output_normalizer_test_paragraph(
        2, "This body sentence remains visible.",
      ),
    ],
    options,
  )
  let repeated_artifact = pdf_v2_filter_repeated_artifact_paragraphs(
    [
      text_output_normalizer_test_paragraph(0, "Project Report"),
      text_output_normalizer_test_paragraph(
        1, "This body sentence remains visible.",
      ),
      text_output_normalizer_test_paragraph(2, "Project Report"),
    ],
    options,
  )
  let repeated_title = pdf_v2_filter_repeated_artifact_paragraphs(
    [
      text_output_normalizer_test_paragraph(0, "Project Overview"),
      text_output_normalizer_test_paragraph(
        1, "This body sentence remains visible.",
      ),
      text_output_normalizer_test_paragraph(2, "Project Overview"),
    ],
    options,
  )

  assert_true(
    text_output_normalizer_test_has_paragraph(single, "Project Report"),
  )
  assert_true(text_output_normalizer_test_has_paragraph(single, "Confidential"))
  assert_true(
    !text_output_normalizer_test_has_paragraph(
      repeated_artifact, "Project Report",
    ),
  )
  assert_true(
    text_output_normalizer_test_has_paragraph(
      repeated_title, "Project Overview",
    ),
  )
}
