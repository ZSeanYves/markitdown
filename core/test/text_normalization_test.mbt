///|
fn change_count(
  result : @cor.TextNormalizationResult,
  kind : @cor.TextNormalizationChangeKind,
) -> Int {
  for change in result.summary.changes {
    if change.kind == kind {
      return change.count
    }
  }
  0
}

///|
fn has_stage(
  result : @cor.TextNormalizationResult,
  stage : @cor.TextNormalizationStage,
  expected_applied : Bool,
) -> Bool {
  for summary in result.summary.stages {
    if summary.stage == stage && summary.applied == expected_applied {
      return true
    }
  }
  false
}

///|
fn rule_count(
  result : @cor.TextNormalizationResult,
  rule : @cor.TextNormalizationRuleId,
) -> Int {
  for summary in result.summary.rules {
    if summary.rule == rule {
      return summary.total_changes
    }
  }
  0
}

///|
fn has_rule(
  result : @cor.TextNormalizationResult,
  rule : @cor.TextNormalizationRuleId,
  expected_applied : Bool,
) -> Bool {
  for summary in result.summary.rules {
    if summary.rule == rule && summary.applied == expected_applied {
      return true
    }
  }
  false
}

///|
fn warning_count(
  result : @cor.TextNormalizationResult,
  kind : @cor.TextNormalizationWarningKind,
) -> Int {
  let mut total = 0
  for warning in result.summary.warnings {
    if warning.kind == kind {
      total = total + 1
    }
  }
  total
}

///|
test "cleanup literal profile only normalizes line endings" {
  let text = "alpha\r\nbeta\rgamma\u{00A0}delta"
  let normalized = @cor.normalize_text_with_profile(
    text,
    @cor.NormalizeProfile::Literal,
  )
  assert_eq(normalized, "alpha\nbeta\ngamma\u{00A0}delta")
}

///|
test "cleanup general text profile normalizes nbsp and zero width conservatively" {
  let text = "A\u{00A0}B\u{200B}C"
  let normalized = @cor.normalize_text_with_profile(
    text,
    @cor.NormalizeProfile::GeneralText,
  )
  assert_eq(normalized, "A BC")
}

///|
test "cleanup pdf profile expands ligatures and removes soft hyphen" {
  let text = "o\u{FB03}ce hy\u{00AD}phen"
  let normalized = @cor.normalize_text_with_profile(
    text,
    @cor.NormalizeProfile::PdfText,
  )
  assert_eq(normalized, "office hyphen")
}

///|
test "cleanup pdf compare profile is stronger than pdf output profile" {
  let text = "中 文\r\nFigure\u{00A0}1\tA"
  let pdf_text = @cor.normalize_text_with_profile(
    text,
    @cor.NormalizeProfile::PdfText,
  )
  let pdf_compare = @cor.normalize_text_with_profile(
    text,
    @cor.NormalizeProfile::PdfCompareText,
  )

  assert_eq(pdf_text, "中 文\nFigure 1\tA")
  assert_eq(pdf_compare, "中文 Figure 1 A")
}

///|
test "cleanup literal profile keeps ligatures by default" {
  let text = "of\u{FB01}ce"
  let normalized = @cor.normalize_text_with_profile(
    text,
    @cor.NormalizeProfile::Literal,
  )
  assert_eq(normalized, text)
}

///|
test "cleanup structured data profile preserves quote and dash variants by default" {
  let text = "“value” — still literal"
  let normalized = @cor.normalize_text_with_profile(
    text,
    @cor.NormalizeProfile::StructuredDataText,
  )
  assert_eq(normalized, text)
}

///|
test "cleanup explicit quote and dash options are opt in" {
  let options = {
    ..@cor.default_text_normalization_options(
      @cor.NormalizeProfile::StructuredDataText,
    ),
    normalize_quotes: true,
    normalize_dashes: true,
    record_changes: true,
    record_summary: true,
  }
  let result = @cor.normalize_text_with_options_summary(
    "“A” — B",
    @cor.NormalizeProfile::StructuredDataText,
    options,
  )
  assert_eq(result.text, "\"A\" - B")
  assert_eq(change_count(result, @cor.TextNormalizationChangeKind::Quotes), 2)
  assert_eq(change_count(result, @cor.TextNormalizationChangeKind::Dashes), 1)
  assert_true(
    has_stage(
      result,
      @cor.TextNormalizationStage::CompatibilityGlyphStage,
      true,
    ),
  )
}

///|
test "cleanup fullwidth and cjk punctuation normalization stay opt in" {
  let text = "Ａ，Ｂ！"
  let literal = @cor.normalize_text_with_profile(
    text,
    @cor.NormalizeProfile::GeneralText,
  )
  let fullwidth_options = {
    ..@cor.default_text_normalization_options(
      @cor.NormalizeProfile::GeneralText,
    ),
    normalize_fullwidth: true,
    record_summary: true,
  }
  let punct_options = {
    ..@cor.default_text_normalization_options(
      @cor.NormalizeProfile::GeneralText,
    ),
    normalize_cjk_punctuation: true,
    record_summary: true,
  }
  let fullwidth_result = @cor.normalize_text_with_options_summary(
    text,
    @cor.NormalizeProfile::GeneralText,
    fullwidth_options,
  )
  let punct_result = @cor.normalize_text_with_options_summary(
    "A。B",
    @cor.NormalizeProfile::GeneralText,
    punct_options,
  )

  assert_eq(literal, text)
  assert_eq(fullwidth_result.text, "A,B!")
  assert_eq(
    change_count(fullwidth_result, @cor.TextNormalizationChangeKind::Fullwidth),
    4,
  )
  assert_eq(
    change_count(
      fullwidth_result,
      @cor.TextNormalizationChangeKind::Compatibility,
    ),
    4,
  )
  assert_eq(punct_result.text, "A.B")
  assert_eq(
    change_count(punct_result, @cor.TextNormalizationChangeKind::CjkPunctuation),
    1,
  )
}

///|
test "canonical facade exposes direct unicode normalization helpers" {
  assert_eq(@cor.normalize_nfd("\u{00E9}"), "e\u{0301}")
  assert_eq(@cor.normalize_nfc("e\u{0301}"), "\u{00E9}")
  assert_eq(@cor.normalize_nfkc("\u{FB03}"), "ffi")
  assert_eq(@cor.normalize_nfkc("\u{FF21}"), "A")
  assert_true(@cor.is_normalized_nfc("\u{00E9}"))
  assert_false(@cor.is_normalized_nfc("e\u{0301}"))
  assert_true(@cor.is_normalized_nfkc("A"))
  assert_false(@cor.is_normalized_nfkc("\u{FF21}"))
}

///|
test "canonical curated cases cover combining mark ordering and hangul" {
  assert_eq(
    @cor.normalize_nfd("\u{1E0C}\u{0323}\u{0307}"),
    "D\u{0323}\u{0323}\u{0307}",
  )
  assert_eq(@cor.normalize_nfc("D\u{0307}\u{0323}"), "\u{1E0C}\u{0307}")
  assert_eq(@cor.normalize_nfd("\u{AC00}"), "\u{1100}\u{1161}")
  assert_eq(@cor.normalize_nfc("\u{1100}\u{1161}"), "\u{AC00}")
}

///|
test "canonical curated is_normalized checks cover hangul and reordered marks" {
  assert_true(@cor.is_normalized_nfd("\u{1100}\u{1161}"))
  assert_false(@cor.is_normalized_nfd("\u{AC00}"))
  assert_true(@cor.is_normalized_nfc("\u{AC00}"))
  assert_false(@cor.is_normalized_nfc("D\u{0307}\u{0323}"))
}

///|
test "canonical normalization options now use unicode backend" {
  let options = {
    ..@cor.default_text_normalization_options(
      @cor.NormalizeProfile::GeneralText,
    ),
    canonical_form: @cor.CanonicalNormalizationForm::NFKC,
    record_summary: true,
  }
  let result = @cor.normalize_text_with_options_summary(
    "ﬁ",
    @cor.NormalizeProfile::GeneralText,
    options,
  )

  assert_eq(result.text, "fi")
  assert_eq(
    change_count(result, @cor.TextNormalizationChangeKind::Canonical),
    1,
  )
  assert_eq(
    warning_count(
      result,
      @cor.TextNormalizationWarningKind::UnsupportedNormalization,
    ),
    0,
  )
}

///|
test "canonical literal request records literal warning" {
  let options = {
    ..@cor.default_text_normalization_options(@cor.NormalizeProfile::Literal),
    canonical_form: @cor.CanonicalNormalizationForm::NFC,
    record_summary: true,
  }
  let result = @cor.normalize_text_with_options_summary(
    "e\u{0301}",
    @cor.NormalizeProfile::Literal,
    options,
  )

  assert_eq(result.text, "\u{00E9}")
  assert_eq(
    change_count(result, @cor.TextNormalizationChangeKind::Canonical),
    1,
  )
  assert_eq(
    warning_count(
      result,
      @cor.TextNormalizationWarningKind::SkippedDueToLiteralContext,
    ),
    1,
  )
}

///|
test "cleanup summary records staged pdf changes" {
  let result = @cor.normalize_text_with_profile_summary(
    "A\u{00A0}\u{200B}hy\u{00AD}phen \u{FB01}\r\n⻅",
    @cor.NormalizeProfile::PdfText,
  )

  match result.profile {
    @cor.NormalizeProfile::PdfText => ()
    _ => fail("expected PdfText profile")
  }
  assert_eq(result.text, "A hyphen fi\n见")
  assert_eq(result.changed, true)
  assert_eq(result.summary.total_changes, 7)
  assert_eq(change_count(result, @cor.TextNormalizationChangeKind::Nbsp), 1)
  assert_eq(
    change_count(result, @cor.TextNormalizationChangeKind::ZeroWidth),
    1,
  )
  assert_eq(
    change_count(result, @cor.TextNormalizationChangeKind::SoftHyphen),
    1,
  )
  assert_eq(
    change_count(result, @cor.TextNormalizationChangeKind::Ligatures),
    1,
  )
  assert_eq(
    change_count(result, @cor.TextNormalizationChangeKind::LineEndings),
    1,
  )
  assert_eq(change_count(result, @cor.TextNormalizationChangeKind::PdfGlyph), 1)
  assert_true(
    has_stage(result, @cor.TextNormalizationStage::PdfGlyphStage, true),
  )
}

///|
test "cleanup profile summary includes compare cleanup stage" {
  let result = @cor.normalize_text_with_profile_summary(
    "A\t\r\nB",
    @cor.NormalizeProfile::PdfCompareText,
  )

  assert_eq(result.text, "A B")
  assert_true(
    has_stage(result, @cor.TextNormalizationStage::PdfCompareStage, true),
  )
  assert_true(
    has_rule(
      result,
      @cor.TextNormalizationRuleId::CollapsePdfComparisonWhitespace,
      true,
    ),
  )
}

///|
test "canonical default cleanup profiles do not implicitly enable canonical normalization" {
  assert_eq(
    @cor.normalize_text_with_profile(
      "e\u{0301}",
      @cor.NormalizeProfile::Literal,
    ),
    "e\u{0301}",
  )
  assert_eq(
    @cor.normalize_text_with_profile("Ａ", @cor.NormalizeProfile::GeneralText),
    "Ａ",
  )
}

///|
test "cleanup document cleanup normalizes line endings unicode spaces invisibles and ligatures" {
  let text = "A\r\nB\rC\u{00A0}D\u{2009}E\u{2007}F\u{202F}G\u{200B}hy\u{00AD}phen ﬁﬂﬀﬃﬄ"
  let normalized = @cor.normalize_document_text_cleanup(text)

  assert_eq(normalized, "A\nB\nC D E F Ghyphen fiflffffiffl")
}

///|
test "cleanup unicode spaces helper maps common unicode spaces to ascii space only" {
  let text = "A\u{00A0}B\u{2009}C\u{2007}D\u{202F}E"
  let normalized = @cor.normalize_unicode_spaces(text)

  assert_eq(normalized, "A B C D E")
}

///|
test "cleanup common ligatures helper expands common latin ligatures only" {
  let normalized = @cor.normalize_common_ligatures(
    "ﬁ ﬂ ﬀ ﬃ ﬄ plain 中文",
  )
  assert_eq(normalized, "fi fl ff ffi ffl plain 中文")
}

///|
test "cleanup collapse space like runs preserves normal text content" {
  let normalized = @cor.collapse_space_like_runs(
    "  Alpha\r\n\tBeta\u{00A0}\u{2009}Gamma  中文  ",
  )
  assert_eq(normalized, "Alpha Beta Gamma 中文")
}

///|
test "cleanup pdf text cleanup helper stays conservative about plain ascii and cjk text" {
  assert_eq(
    @cor.normalize_pdf_text_cleanup("Plain ASCII text"),
    "Plain ASCII text",
  )
  assert_eq(@cor.normalize_pdf_text_cleanup("中文标题"), "中文标题")
}

///|
test "cleanup document cleanup does not implicitly enable canonical normalization" {
  assert_eq(@cor.normalize_document_text_cleanup("e\u{0301}"), "e\u{0301}")
  assert_eq(@cor.normalize_document_text_cleanup("Ａ"), "Ａ")
}

///|
test "cleanup pdf helper applies rule driven cjk punctuation and marker spacing" {
  let options = {
    ..@cor.default_text_normalization_options(@cor.NormalizeProfile::PdfText),
    collapse_space_like_runs: true,
    cjk_spacing_policy: @cor.CjkSpacingPolicy::RemoveBetweenCjk,
    remove_spaces_around_cjk_punctuation: true,
    normalize_ascii_punctuation_spacing: true,
    normalize_bullet_marker_spacing: true,
    normalize_numbered_marker_spacing: true,
    record_summary: true,
    record_changes: true,
  }
  let result = @cor.normalize_text_with_options_summary(
    "中 文 ， 标题",
    @cor.NormalizeProfile::PdfText,
    options,
  )

  assert_eq(result.text, "中文，标题")
  assert_true(
    has_rule(result, @cor.TextNormalizationRuleId::RemoveSpacesBetweenCjk, true),
  )
  assert_eq(
    rule_count(result, @cor.TextNormalizationRuleId::RemoveSpacesBetweenCjk),
    1,
  )
  assert_eq(
    rule_count(
      result,
      @cor.TextNormalizationRuleId::RemoveSpacesAroundCjkPunctuation,
    ),
    2,
  )
}

///|
test "cleanup pdf helper normalizes marker spacing and preserves numbering decimals" {
  assert_eq(@cor.normalize_pdf_text_cleanup("•First item"), "• First item")
  assert_eq(@cor.normalize_pdf_text_cleanup("1)another"), "1) another")
  assert_eq(
    @cor.normalize_pdf_text_cleanup("1.1 研究目标"),
    "1.1 研究目标",
  )
}

///|
test "cleanup pdf helper keeps literal hyphen slash and cjk latin boundaries" {
  assert_eq(@cor.normalize_pdf_text_cleanup("A - B"), "A - B")
  assert_eq(@cor.normalize_pdf_text_cleanup("inter-national"), "inter-national")
  assert_eq(@cor.normalize_pdf_text_cleanup("/1"), "/1")
  assert_eq(@cor.normalize_pdf_text_cleanup("中文 AI"), "中文 AI")
  assert_eq(
    @cor.normalize_text_with_profile("/1", @cor.NormalizeProfile::GeneralText),
    "/1",
  )
}

///|
test "cleanup structured data profile keeps aggressive spacing rules disabled" {
  assert_eq(
    @cor.normalize_text_with_profile(
      "中 文",
      @cor.NormalizeProfile::StructuredDataText,
    ),
    "中 文",
  )
  assert_eq(
    @cor.normalize_text_with_profile(
      "1)another",
      @cor.NormalizeProfile::StructuredDataText,
    ),
    "1)another",
  )
}
