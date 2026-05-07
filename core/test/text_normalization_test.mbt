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
test "literal profile only normalizes line endings" {
  let text = "alpha\r\nbeta\rgamma\u{00A0}delta"
  let normalized = @cor.normalize_text_with_profile(
    text,
    @cor.NormalizeProfile::Literal,
  )
  assert_eq(normalized, "alpha\nbeta\ngamma\u{00A0}delta")
}

///|
test "general text profile normalizes nbsp and zero width conservatively" {
  let text = "A\u{00A0}B\u{200B}C"
  let normalized = @cor.normalize_text_with_profile(
    text,
    @cor.NormalizeProfile::GeneralText,
  )
  assert_eq(normalized, "A BC")
}

///|
test "pdf profile expands ligatures and removes soft hyphen" {
  let text = "o\u{FB03}ce hy\u{00AD}phen"
  let normalized = @cor.normalize_text_with_profile(
    text,
    @cor.NormalizeProfile::PdfText,
  )
  assert_eq(normalized, "office hyphen")
}

///|
test "pdf compare profile is stronger than pdf output profile" {
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
test "literal profile keeps ligatures by default" {
  let text = "of\u{FB01}ce"
  let normalized = @cor.normalize_text_with_profile(
    text,
    @cor.NormalizeProfile::Literal,
  )
  assert_eq(normalized, text)
}

///|
test "structured data profile preserves quote and dash variants by default" {
  let text = "“value” — still literal"
  let normalized = @cor.normalize_text_with_profile(
    text,
    @cor.NormalizeProfile::StructuredDataText,
  )
  assert_eq(normalized, text)
}

///|
test "explicit quote and dash options are opt in" {
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
test "fullwidth and cjk punctuation normalization stay opt in" {
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
test "unsupported canonical normalization is warning only" {
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

  assert_eq(result.text, "ﬁ")
  assert_eq(
    warning_count(
      result,
      @cor.TextNormalizationWarningKind::UnsupportedNormalization,
    ),
    1,
  )
}

///|
test "literal canonical request records literal warning" {
  let options = {
    ..@cor.default_text_normalization_options(@cor.NormalizeProfile::Literal),
    canonical_form: @cor.CanonicalNormalizationForm::NFC,
    record_summary: true,
  }
  let result = @cor.normalize_text_with_options_summary(
    "raw",
    @cor.NormalizeProfile::Literal,
    options,
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
test "normalization summary records staged pdf changes" {
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
test "profile summary includes compare cleanup stage" {
  let result = @cor.normalize_text_with_profile_summary(
    "A\t\r\nB",
    @cor.NormalizeProfile::PdfCompareText,
  )

  assert_eq(result.text, "A B")
  assert_true(
    has_stage(result, @cor.TextNormalizationStage::PdfCompareStage, true),
  )
}
