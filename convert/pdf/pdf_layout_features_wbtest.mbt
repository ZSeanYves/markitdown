///|
test "pdf layout feature separator signal keeps bare dash divider out of list bucket" {
  assert_true(looks_like_separator_signal("- -"))
  assert_true(!looks_like_separator_signal("- item"))
}

///|
test "pdf layout feature dotted identifier signal treats qualified tokens as path-like" {
  assert_true(contains_path_like_signal("BookReporter.TabDelimitedFile"))
  assert_true(!contains_path_like_signal("U.S."))
}

///|
test "pdf layout feature clause punctuation signal catches CJK short sentence cues" {
  assert_true(
    contains_clause_punctuation_signal("全世界无产者，联合起来 A"),
  )
  assert_true(!contains_clause_punctuation_signal("技术路线"))
}

///|
test "pdf layout feature form key heuristic rejects long narrative lead-ins" {
  assert_true(form_key_value_signal("Product Desc:"))
  assert_true(
    !form_key_value_signal("BookReporter produced the following output:"),
  )
}

///|
test "pdf layout feature option-like signal separates cli syntax from changelog bullets" {
  assert_true(
    option_like_signal(
      "- - timeout nnn in seconds. NOTE: This setting is ignored unless you are using Python 3.3 or later",
    ),
  )
  assert_true(
    !option_like_signal(
      "- - added reference to: 'OEBPS/Lars_9780307272300_epub_css_r1.css'Manifest item ID: 'toc'",
    ),
  )
}

///|
test "pdf layout feature toc-like anchor signal catches dotted leader destinations" {
  assert_true(
    toc_like_anchor_signal(
      "1. INTRODUCTION.............................................5 2. DEFINITIONS.............................................5",
    ),
  )
  assert_true(
    toc_like_anchor_signal(
      "Figure 1: The ECB Mode................................................9",
    ),
  )
  assert_true(!toc_like_anchor_signal("1. Introduction to the standard"))
}

///|
test "pdf layout feature caption lead-in signal separates figure references from captions" {
  assert_true(
    caption_lead_in_signal(
      "Figure 6 illustrates the effect of the SubBytes() transformation on the State.",
    ),
  )
  assert_true(
    caption_lead_in_signal("Figure 1 below shows the basic full TLS handshake:"),
  )
  assert_true(!caption_lead_in_signal("Figure 1. PDF caption"))
}

///|
test "pdf layout feature reference sentence signals keep figure and section mentions in paragraph bucket" {
  assert_true(
    figure_reference_sentence_signal(
      "Figure 6 illustrates the effect of the SubBytes() transformation on the State.",
    ),
  )
  assert_true(
    figure_reference_sentence_signal(
      "ρ for the case w=8 is given in Figure 4 below.",
    ),
  )
  assert_true(
    section_reference_sentence_signal(
      "AutoGen provides ready-to-use implementations and also allows easy extension and experimentation for both steps. (Section 2.2)",
    ),
  )
  assert_true(
    !figure_reference_sentence_signal("Figure 6. SubBytes transformation"),
  )
}

///|
test "pdf layout feature caption reference-only signal keeps inline mentions out of caption bucket" {
  assert_true(
    caption_reference_only_signal(
      "As shown in Figure 4, the final round omits MixColumns.",
    ),
  )
  assert_true(!caption_reference_only_signal("Table 2. AES test vectors"))
}

///|
test "pdf layout feature metadata noise signal catches asset-like sidecars" {
  assert_true(
    asset_metadata_noise_signal("550e8400-e29b-41d4-a716-446655440000.png"),
  )
  assert_true(!asset_metadata_noise_signal("BookReporter.TabDelimitedFile"))
  assert_true(!asset_metadata_noise_signal("Figure 1. PDF caption"))
}

///|
test "pdf layout feature email/url boundary rejects receipt qty price rows" {
  assert_true(!contains_email_signal("AUDIO-5521 1 @ $349.99"))
  assert_true(contains_email_signal("hello@example.com"))
}

///|
test "pdf layout feature technical literal signals catch generic code-ish tokens" {
  assert_true(identifier_like_signal("BookReporter.TabDelimitedFile"))
  assert_true(!identifier_like_signal("www.techmart.example.com"))
  assert_true(
    technical_literal_signal(
      "applicationJar=APPJAR if specified, the named jar will be used; if not specified, Z: \\work\\ePubCheck\\com.adobe.epubcheck\\target",
    ),
  )
  assert_true(!technical_literal_signal("11/23/2024 14:32:18 PST"))
  assert_true(
    !technical_literal_signal(
      "- - added reference to: 'OEBPS/Lars_9780307272300_epub_css_r1.css'Manifest item ID: 'toc'",
    ),
  )
  assert_true(
    !technical_literal_signal(
      "Figure 1: Parts of the state array, organized by dimension [8]",
    ),
  )
  assert_true(
    !technical_literal_signal(
      "AutoGen provides ready-to-use implementations and also allows easy extension and experimentation for both steps. (Section 2.2)",
    ),
  )
  assert_true(
    !technical_literal_signal(
      "[1] AES page available via http://www.nist.gov/CryptoToolkit.",
    ),
  )
  assert_true(
    !technical_literal_signal("ρ for the case w=8 is given in Figure 4 below."),
  )
}

///|
test "pdf layout feature citation sentence signals keep reference paragraphs out of keep-as-text" {
  assert_true(
    citation_reference_signal(
      "[1] AES page available via http://www.nist.gov/CryptoToolkit.",
    ),
  )
  assert_true(
    sentence_like_signal(
      "[1] AES page available via http://www.nist.gov/CryptoToolkit.",
    ),
  )
  assert_true(
    sentence_like_signal(
      "AutoGen provides ready-to-use implementations and also allows easy extension and experimentation for both steps. (Section 2.2)",
    ),
  )
  assert_true(
    sentence_like_signal("ρ for the case w=8 is given in Figure 4 below."),
  )
  assert_true(
    technical_sentence_guard_signal(
      "AutoGen provides ready-to-use implementations and also allows easy extension and experimentation for both steps. (Section 2.2)",
    ),
  )
}

///|
test "pdf layout feature receipt signals separate sku line items from payment rows" {
  assert_true(sku_like_signal("AUDIO-5521 1 @ $349.99"))
  assert_true(quantity_price_signal("AUDIO-5521 1 @ $349.99"))
  assert_true(payment_card_signal("Visa Card ending in 4782"))
}

///|
test "pdf layout feature page label pattern catches generated shell headings" {
  assert_true(page_label_pattern_signal("Body paragraph page 1"))
  assert_true(!page_label_pattern_signal("Project Report"))
}
