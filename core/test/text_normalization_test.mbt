///|
fn change_count(
  result : @cor.TextNormalizationResult,
  kind : @cor.TextNormalizationChangeKind,
) -> Int {
  for change in result.changes {
    if change.kind == kind {
      return change.count
    }
  }
  0
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
  }
  let result = @cor.normalize_text_with_options_summary(
    "“A” — B", options,
  )
  assert_eq(result.text, "\"A\" - B")
  assert_eq(change_count(result, @cor.TextNormalizationChangeKind::Quotes), 2)
  assert_eq(change_count(result, @cor.TextNormalizationChangeKind::Dashes), 1)
}

///|
test "normalization summary records low risk pdf changes" {
  let result = @cor.normalize_text_with_profile_summary(
    "A\u{00A0}\u{200B}hy\u{00AD}phen \u{FB01}\r\n",
    @cor.NormalizeProfile::PdfText,
  )

  assert_eq(result.text, "A hyphen fi\n")
  assert_eq(result.changed, true)
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
}
