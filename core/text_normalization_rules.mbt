///|
pub(all) enum TextNormalizationRuleScope {
  CharacterCleanup
  CanonicalUnicode
  CompatibilityGlyph
  WhitespaceCleanup
  PunctuationSpacing
  MarkerSpacing
  CjkSpacing
  PdfCleanup
  CompareOnly
} derive(Eq)

///|
pub(all) enum TextNormalizationRuleId {
  NormalizeLineEndings
  NormalizeTabs
  CanonicalUnicode
  ExpandLigatures
  NormalizeQuotes
  NormalizeDashes
  NormalizeFullwidth
  NormalizeCjkPunctuation
  NormalizeNbsp
  NormalizeUnicodeSpaces
  CollapseSpaceLikeRuns
  RemoveSpacesBetweenCjk
  RemoveSpacesAroundCjkPunctuation
  NormalizeAsciiPunctuationSpacing
  NormalizeBulletMarkerSpacing
  NormalizeNumberedMarkerSpacing
  RemoveZeroWidth
  RemoveSoftHyphen
  PdfPrivateGlyphFallback
  CollapsePdfComparisonWhitespace
} derive(Eq)

///|
pub(all) struct TextNormalizationRuleSummary {
  rule : TextNormalizationRuleId
  scope : TextNormalizationRuleScope
  applied : Bool
  changed : Bool
  total_changes : Int
} derive(Eq)

///|
priv struct TextNormalizationRuleApplyResult {
  text : String
  count : Int
}

///|
fn push_rule_summary(
  rules : Array[TextNormalizationRuleSummary],
  rule : TextNormalizationRuleId,
  scope : TextNormalizationRuleScope,
  applied : Bool,
  changed : Bool,
  total_changes : Int,
  options : TextNormalizationOptions,
) -> Unit {
  if options.record_summary {
    rules.push({ rule, scope, applied, changed, total_changes })
  }
}

///|
fn apply_char_mapping_rule(
  text : String,
  enabled : Bool,
  mapper : (Char) -> String?,
) -> TextNormalizationRuleApplyResult {
  if !enabled {
    return { text, count: 0 }
  }

  let out = StringBuilder::new()
  let mut count = 0

  for ch in text {
    match mapper(ch) {
      Some(mapped) => {
        out.write_string(mapped)
        count = count + 1
      }
      None => out.write_char(ch)
    }
  }

  if count > 0 {
    { text: out.to_string(), count }
  } else {
    { text, count: 0 }
  }
}

///|
fn apply_nbsp_rule(
  text : String,
  enabled : Bool,
) -> TextNormalizationRuleApplyResult {
  if !enabled {
    return { text, count: 0 }
  }

  let out = StringBuilder::new()
  let mut count = 0

  for ch in text {
    if ch == '\u{00A0}' {
      out.write_char(' ')
      count = count + 1
    } else {
      out.write_char(ch)
    }
  }

  if count > 0 {
    { text: out.to_string(), count }
  } else {
    { text, count: 0 }
  }
}

///|
fn apply_unicode_space_rule(
  text : String,
  enabled : Bool,
) -> TextNormalizationRuleApplyResult {
  if !enabled {
    return { text, count: 0 }
  }

  let out = StringBuilder::new()
  let mut count = 0

  for ch in text {
    if is_unicode_space_separator(ch) {
      out.write_char(' ')
      count = count + 1
    } else {
      out.write_char(ch)
    }
  }

  if count > 0 {
    { text: out.to_string(), count }
  } else {
    { text, count: 0 }
  }
}

///|
fn apply_remove_spaces_between_cjk_rule(
  text : String,
  enabled : Bool,
) -> TextNormalizationRuleApplyResult {
  if !enabled {
    return { text, count: 0 }
  }

  let (out, count) = remove_spaces_between_cjk(text)
  { text: out, count }
}

///|
fn apply_remove_spaces_around_cjk_punctuation_rule(
  text : String,
  enabled : Bool,
) -> TextNormalizationRuleApplyResult {
  if !enabled {
    return { text, count: 0 }
  }

  let chars = text.to_array()
  if chars.length() <= 1 {
    return { text, count: 0 }
  }

  let out = StringBuilder::new()
  let mut count = 0
  let mut i = 0

  while i < chars.length() {
    let ch = chars[i]
    if ch == ' ' &&
      i > 0 &&
      i + 1 < chars.length() &&
      (is_cjk_spacing_punct(chars[i - 1]) || is_cjk_spacing_punct(chars[i + 1])) {
      count = count + 1
      i = i + 1
      continue
    }

    out.write_char(ch)
    i = i + 1
  }

  if count > 0 {
    { text: out.to_string(), count }
  } else {
    { text, count: 0 }
  }
}

///|
fn apply_normalize_ascii_punctuation_spacing_rule(
  text : String,
  enabled : Bool,
) -> TextNormalizationRuleApplyResult {
  if !enabled {
    return { text, count: 0 }
  }

  let chars = text.to_array()
  if chars.is_empty() {
    return { text, count: 0 }
  }

  let out = StringBuilder::new()
  let mut count = 0
  let mut i = 0

  while i < chars.length() {
    let ch = chars[i]
    out.write_char(ch)

    if is_ascii_spacing_punct(ch) {
      let mut j = i + 1
      while j < chars.length() && chars[j] == ' ' {
        j = j + 1
      }

      if j > i + 1 && j < chars.length() {
        out.write_char(' ')
        count = count + (j - i - 2)
        i = j
        continue
      }
    }

    i = i + 1
  }

  if count > 0 {
    { text: out.to_string(), count }
  } else {
    { text, count: 0 }
  }
}

///|
fn apply_normalize_bullet_marker_spacing_rule(
  text : String,
  enabled : Bool,
) -> TextNormalizationRuleApplyResult {
  if !enabled {
    return { text, count: 0 }
  }

  let chars = text.to_array()
  if chars.length() < 2 {
    return { text, count: 0 }
  }

  if is_bullet_spacing_marker(chars[0]) && chars[1] != ' ' {
    {
      text: chars[0].to_string() +
      " " +
      String::from_array(chars[1:].to_owned()),
      count: 1,
    }
  } else {
    { text, count: 0 }
  }
}

///|
fn apply_normalize_numbered_marker_spacing_rule(
  text : String,
  enabled : Bool,
) -> TextNormalizationRuleApplyResult {
  if !enabled {
    return { text, count: 0 }
  }

  let chars = text.to_array()
  if chars.length() < 3 {
    return { text, count: 0 }
  }

  if !(chars[0] >= '0' && chars[0] <= '9') {
    return { text, count: 0 }
  }

  if !is_numbered_spacing_marker(chars[1]) {
    return { text, count: 0 }
  }

  if chars[1] == '.' && chars[2] >= '0' && chars[2] <= '9' {
    return { text, count: 0 }
  }

  if chars[2] == ' ' {
    return { text, count: 0 }
  }

  {
    text: chars[0].to_string() +
    chars[1].to_string() +
    " " +
    String::from_array(chars[2:].to_owned()),
    count: 1,
  }
}

///|
fn apply_collapse_space_like_runs_rule(
  text : String,
  enabled : Bool,
) -> TextNormalizationRuleApplyResult {
  if !enabled {
    return { text, count: 0 }
  }

  let collapsed = collapse_space_like_runs(text)
  let count = estimate_length_preserving_change_count(text, collapsed)
  { text: collapsed, count }
}

///|
fn apply_pdf_compare_whitespace_rule(
  text : String,
  enabled : Bool,
) -> TextNormalizationRuleApplyResult {
  if !enabled {
    return { text, count: 0 }
  }

  let collapsed = collapse_pdf_comparison_whitespace(text).trim().to_owned()
  let count = estimate_length_preserving_change_count(text, collapsed)
  { text: collapsed, count }
}

///|
fn estimate_length_preserving_change_count(
  before : String,
  after : String,
) -> Int {
  if before == after {
    return 0
  }

  let diff = before.length() - after.length()
  if diff > 0 {
    diff
  } else {
    1
  }
}

///|
fn is_ascii_spacing_punct(ch : Char) -> Bool {
  ch == '.' || ch == ',' || ch == ':' || ch == ';' || ch == '!' || ch == '?'
}

///|
fn is_cjk_spacing_punct(ch : Char) -> Bool {
  ch == '，' ||
  ch == '。' ||
  ch == '：' ||
  ch == '；' ||
  ch == '！' ||
  ch == '？' ||
  ch == '（' ||
  ch == '）' ||
  ch == '《' ||
  ch == '》' ||
  ch == '、' ||
  ch == '【' ||
  ch == '】'
}

///|
fn is_bullet_spacing_marker(ch : Char) -> Bool {
  ch == '•' || ch == '*' || ch == '-'
}

///|
fn is_numbered_spacing_marker(ch : Char) -> Bool {
  ch == ')' || ch == '.' || ch == '、' || ch == '）'
}
