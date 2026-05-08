///|
/// Shared text normalization profiles.
///
/// Responsibility boundary:
/// - document cleanup profiles are for low-risk cross-format cleanup such as
///   CRLF/CR, NBSP, Unicode spaces, zero-width, soft hyphen, common ligatures,
///   and conservative whitespace cleanup
/// - canonical Unicode normalization remains explicit and opt-in
/// - format-specific post-processing such as PDF span glue, line merge,
///   hyphen-wrap repair, CJK spacing repair, heading/noise/caption/table, and
///   cross-page merge must stay in format layers rather than this facade
pub(all) enum NormalizeProfile {
  Literal
  GeneralText
  PdfText
  PdfCompareText
  HtmlText
  OoxmlText
  StructuredDataText
} derive(Eq)

///|
/// Explicit canonical Unicode normalization forms exposed through the facade.
///
/// These forms are never part of the repository's default converter behavior.
/// Callers must opt in explicitly. Until conformance coverage such as
/// `NormalizationTest.txt` is added, this facade should not be described as a
/// full standards-conformance claim for project-wide normalization behavior.
pub(all) enum CanonicalNormalizationForm {
  Disabled
  NFD
  NFC
  NFKD
  NFKC
} derive(Eq)

///|
pub(all) enum CjkSpacingPolicy {
  Preserve
  RemoveBetweenCjk
} derive(Eq)

///|
pub(all) enum TextNormalizationStage {
  ValidateScalarStage
  CanonicalUnicodeStage
  CompatibilityGlyphStage
  WhitespaceStage
  InvisibleCharStage
  SoftHyphenStage
  LineEndingStage
  PdfGlyphStage
  PdfCompareStage
} derive(Eq)

///|
pub(all) enum TextNormalizationChangeKind {
  LineEndings
  Tabs
  Nbsp
  UnicodeSpaces
  SpaceLikeRuns
  ZeroWidth
  SoftHyphen
  Ligatures
  Quotes
  Dashes
  Fullwidth
  CjkPunctuation
  CjkPunctuationSpacing
  AsciiPunctuationSpacing
  BulletMarkerSpacing
  NumberedMarkerSpacing
  Canonical
  Compatibility
  PdfGlyph
  CjkSpacing
  PdfComparisonWhitespace
} derive(Eq)

///|
pub(all) enum TextNormalizationWarningKind {
  UnsupportedNormalization
  InvalidScalar
  SkippedDueToLiteralContext
} derive(Eq)

///|
pub(all) struct TextNormalizationOptions {
  canonical_form : CanonicalNormalizationForm
  normalize_line_endings : Bool
  normalize_nbsp : Bool
  normalize_unicode_spaces : Bool
  collapse_space_like_runs : Bool
  remove_zero_width : Bool
  remove_soft_hyphen : Bool
  expand_ligatures : Bool
  normalize_quotes : Bool
  normalize_dashes : Bool
  normalize_fullwidth : Bool
  normalize_cjk_punctuation : Bool
  remove_spaces_around_cjk_punctuation : Bool
  normalize_ascii_punctuation_spacing : Bool
  normalize_bullet_marker_spacing : Bool
  normalize_numbered_marker_spacing : Bool
  preserve_newlines : Bool
  preserve_tabs : Bool
  cjk_spacing_policy : CjkSpacingPolicy
  pdf_private_glyph_fallback : Bool
  apply_pdf_compare_cleanup : Bool
  record_summary : Bool
  record_changes : Bool
}

///|
pub(all) struct TextNormalizationChange {
  kind : TextNormalizationChangeKind
  before : String
  after : String
  count : Int
} derive(Eq)

///|
pub(all) struct TextNormalizationWarning {
  kind : TextNormalizationWarningKind
  message : String
} derive(Eq)

///|
pub(all) struct TextNormalizationStageSummary {
  stage : TextNormalizationStage
  changed : Bool
  total_changes : Int
  applied : Bool
} derive(Eq)

///|
pub(all) struct TextNormalizationSummary {
  total_changes : Int
  changes : Array[TextNormalizationChange]
  rules : Array[TextNormalizationRuleSummary]
  stages : Array[TextNormalizationStageSummary]
  warnings : Array[TextNormalizationWarning]
} derive(Eq)

///|
pub(all) struct TextNormalizationResult {
  text : String
  changed : Bool
  profile : NormalizeProfile
  summary : TextNormalizationSummary
  changes : Array[TextNormalizationChange]
} derive(Eq)

///|
priv struct StageCounters {
  mut line_endings : Int
  mut tabs : Int
  mut nbsp : Int
  mut unicode_spaces : Int
  mut space_like_runs : Int
  mut zero_width : Int
  mut soft_hyphen : Int
  mut ligatures : Int
  mut quotes : Int
  mut dashes : Int
  mut fullwidth : Int
  mut cjk_punctuation : Int
  mut cjk_punctuation_spacing : Int
  mut ascii_punctuation_spacing : Int
  mut bullet_marker_spacing : Int
  mut numbered_marker_spacing : Int
  mut canonical : Int
  mut compatibility : Int
  mut pdf_glyph : Int
  mut cjk_spacing : Int
  mut pdf_compare_whitespace : Int
}

///|
fn empty_stage_counters() -> StageCounters {
  {
    line_endings: 0,
    tabs: 0,
    nbsp: 0,
    unicode_spaces: 0,
    space_like_runs: 0,
    zero_width: 0,
    soft_hyphen: 0,
    ligatures: 0,
    quotes: 0,
    dashes: 0,
    fullwidth: 0,
    cjk_punctuation: 0,
    cjk_punctuation_spacing: 0,
    ascii_punctuation_spacing: 0,
    bullet_marker_spacing: 0,
    numbered_marker_spacing: 0,
    canonical: 0,
    compatibility: 0,
    pdf_glyph: 0,
    cjk_spacing: 0,
    pdf_compare_whitespace: 0,
  }
}

///|
pub fn default_text_normalization_options(
  profile : NormalizeProfile,
) -> TextNormalizationOptions {
  match profile {
    NormalizeProfile::Literal =>
      {
        canonical_form: CanonicalNormalizationForm::Disabled,
        normalize_line_endings: true,
        normalize_nbsp: false,
        normalize_unicode_spaces: false,
        collapse_space_like_runs: false,
        remove_zero_width: false,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        normalize_fullwidth: false,
        normalize_cjk_punctuation: false,
        remove_spaces_around_cjk_punctuation: false,
        normalize_ascii_punctuation_spacing: false,
        normalize_bullet_marker_spacing: false,
        normalize_numbered_marker_spacing: false,
        preserve_newlines: true,
        preserve_tabs: true,
        cjk_spacing_policy: CjkSpacingPolicy::Preserve,
        pdf_private_glyph_fallback: false,
        apply_pdf_compare_cleanup: false,
        record_summary: false,
        record_changes: false,
      }
    NormalizeProfile::GeneralText =>
      {
        canonical_form: CanonicalNormalizationForm::Disabled,
        normalize_line_endings: true,
        normalize_nbsp: true,
        normalize_unicode_spaces: false,
        collapse_space_like_runs: false,
        remove_zero_width: true,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        normalize_fullwidth: false,
        normalize_cjk_punctuation: false,
        remove_spaces_around_cjk_punctuation: false,
        normalize_ascii_punctuation_spacing: false,
        normalize_bullet_marker_spacing: false,
        normalize_numbered_marker_spacing: false,
        preserve_newlines: true,
        preserve_tabs: true,
        cjk_spacing_policy: CjkSpacingPolicy::Preserve,
        pdf_private_glyph_fallback: false,
        apply_pdf_compare_cleanup: false,
        record_summary: false,
        record_changes: false,
      }
    NormalizeProfile::PdfText =>
      {
        canonical_form: CanonicalNormalizationForm::Disabled,
        normalize_line_endings: true,
        normalize_nbsp: true,
        normalize_unicode_spaces: true,
        collapse_space_like_runs: false,
        remove_zero_width: true,
        remove_soft_hyphen: true,
        expand_ligatures: true,
        normalize_quotes: false,
        normalize_dashes: false,
        normalize_fullwidth: false,
        normalize_cjk_punctuation: false,
        remove_spaces_around_cjk_punctuation: false,
        normalize_ascii_punctuation_spacing: false,
        normalize_bullet_marker_spacing: false,
        normalize_numbered_marker_spacing: false,
        preserve_newlines: true,
        preserve_tabs: true,
        cjk_spacing_policy: CjkSpacingPolicy::Preserve,
        pdf_private_glyph_fallback: true,
        apply_pdf_compare_cleanup: false,
        record_summary: false,
        record_changes: false,
      }
    NormalizeProfile::PdfCompareText =>
      {
        canonical_form: CanonicalNormalizationForm::Disabled,
        normalize_line_endings: true,
        normalize_nbsp: true,
        normalize_unicode_spaces: true,
        collapse_space_like_runs: false,
        remove_zero_width: true,
        remove_soft_hyphen: true,
        expand_ligatures: true,
        normalize_quotes: false,
        normalize_dashes: false,
        normalize_fullwidth: false,
        normalize_cjk_punctuation: false,
        remove_spaces_around_cjk_punctuation: false,
        normalize_ascii_punctuation_spacing: false,
        normalize_bullet_marker_spacing: false,
        normalize_numbered_marker_spacing: false,
        preserve_newlines: false,
        preserve_tabs: false,
        cjk_spacing_policy: CjkSpacingPolicy::RemoveBetweenCjk,
        pdf_private_glyph_fallback: true,
        apply_pdf_compare_cleanup: true,
        record_summary: false,
        record_changes: false,
      }
    NormalizeProfile::HtmlText =>
      {
        canonical_form: CanonicalNormalizationForm::Disabled,
        normalize_line_endings: true,
        normalize_nbsp: true,
        normalize_unicode_spaces: false,
        collapse_space_like_runs: false,
        remove_zero_width: true,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        normalize_fullwidth: false,
        normalize_cjk_punctuation: false,
        remove_spaces_around_cjk_punctuation: false,
        normalize_ascii_punctuation_spacing: false,
        normalize_bullet_marker_spacing: false,
        normalize_numbered_marker_spacing: false,
        preserve_newlines: true,
        preserve_tabs: true,
        cjk_spacing_policy: CjkSpacingPolicy::Preserve,
        pdf_private_glyph_fallback: false,
        apply_pdf_compare_cleanup: false,
        record_summary: false,
        record_changes: false,
      }
    NormalizeProfile::OoxmlText =>
      {
        canonical_form: CanonicalNormalizationForm::Disabled,
        normalize_line_endings: true,
        normalize_nbsp: true,
        normalize_unicode_spaces: false,
        collapse_space_like_runs: false,
        remove_zero_width: true,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        normalize_fullwidth: false,
        normalize_cjk_punctuation: false,
        remove_spaces_around_cjk_punctuation: false,
        normalize_ascii_punctuation_spacing: false,
        normalize_bullet_marker_spacing: false,
        normalize_numbered_marker_spacing: false,
        preserve_newlines: true,
        preserve_tabs: true,
        cjk_spacing_policy: CjkSpacingPolicy::Preserve,
        pdf_private_glyph_fallback: false,
        apply_pdf_compare_cleanup: false,
        record_summary: false,
        record_changes: false,
      }
    NormalizeProfile::StructuredDataText =>
      {
        canonical_form: CanonicalNormalizationForm::Disabled,
        normalize_line_endings: true,
        normalize_nbsp: false,
        normalize_unicode_spaces: false,
        collapse_space_like_runs: false,
        remove_zero_width: false,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        normalize_fullwidth: false,
        normalize_cjk_punctuation: false,
        remove_spaces_around_cjk_punctuation: false,
        normalize_ascii_punctuation_spacing: false,
        normalize_bullet_marker_spacing: false,
        normalize_numbered_marker_spacing: false,
        preserve_newlines: true,
        preserve_tabs: true,
        cjk_spacing_policy: CjkSpacingPolicy::Preserve,
        pdf_private_glyph_fallback: false,
        apply_pdf_compare_cleanup: false,
        record_summary: false,
        record_changes: false,
      }
  }
}

///|
pub fn normalize_text_with_profile(
  text : String,
  profile : NormalizeProfile,
) -> String {
  normalize_text_with_options_summary(
    text,
    profile,
    default_text_normalization_options(profile),
  ).text
}

///|
/// Cross-format low-risk character cleanup.
///
/// This is the shared document-cleanup layer:
/// - line endings are normalized
/// - Unicode space variants are mapped to ASCII space
/// - zero-width and soft hyphen are removed
/// - common ligatures are expanded
/// - newlines and tabs are preserved
///
/// It is appropriate for gradual adoption by DOCX/HTML/TXT/Markdown and other
/// non-PDF formats that want conservative cleanup without format-specific
/// structure repair.
pub fn normalize_document_text_cleanup(text : String) -> String {
  let options = {
    ..default_text_normalization_options(NormalizeProfile::GeneralText),
    normalize_unicode_spaces: true,
    remove_soft_hyphen: true,
    expand_ligatures: true,
  }
  normalize_text_with_options(text, options)
}

///|
/// Normalize NBSP and common Unicode space variants to ASCII space.
///
/// This helper does not perform canonical normalization, ligature expansion,
/// layout repair, or format-specific post-processing.
pub fn normalize_unicode_spaces(text : String) -> String {
  let options = {
    ..default_text_normalization_options(NormalizeProfile::Literal),
    normalize_line_endings: false,
    normalize_nbsp: true,
    normalize_unicode_spaces: true,
  }
  normalize_text_with_options(text, options)
}

///|
/// Expand common presentation ligatures such as `ﬁ`, `ﬂ`, `ﬀ`, `ﬃ`, and `ﬄ`.
///
/// This helper intentionally stays at compatibility cleanup level and does not
/// imply canonical Unicode normalization.
pub fn normalize_common_ligatures(text : String) -> String {
  let options = {
    ..default_text_normalization_options(NormalizeProfile::Literal),
    normalize_line_endings: false,
    expand_ligatures: true,
  }
  normalize_text_with_options(text, options)
}

///|
/// Collapse repeated space-like characters to a single ASCII space and trim the
/// result.
///
/// This helper is conservative and text-only. It does not inspect geometry,
/// span boundaries, pagination, or document structure.
pub fn collapse_space_like_runs(text : String) -> String {
  let out = StringBuilder::new()
  let mut prev_space = false

  for ch in text {
    if is_space_like_for_collapse(ch) {
      if !prev_space {
        out.write_char(' ')
        prev_space = true
      }
    } else {
      out.write_char(ch)
      prev_space = false
    }
  }

  out.to_string().trim().to_owned()
}

///|
/// Shared PDF text cleanup before layout-specific post-processing.
///
/// This helper is the boundary between shared cleanup and PDF-only recovery:
/// - it owns core string-level cleanup shared through the core facade
/// - it may apply PDF output-safe spacing repair such as CJK spacing,
///   punctuation spacing, and marker spacing through the rule engine
/// - it must not absorb PDF span glue, line merge, hyphen-wrap repair,
///   page-artifact removal, heading/noise/caption/table logic, or cross-page
///   merge behavior
pub fn normalize_pdf_text_cleanup(text : String) -> String {
  let options = {
    ..default_text_normalization_options(NormalizeProfile::PdfText),
    collapse_space_like_runs: true,
    cjk_spacing_policy: CjkSpacingPolicy::RemoveBetweenCjk,
    remove_spaces_around_cjk_punctuation: true,
    normalize_ascii_punctuation_spacing: true,
    normalize_bullet_marker_spacing: true,
    normalize_numbered_marker_spacing: true,
  }
  normalize_text_with_options_summary(text, NormalizeProfile::PdfText, options).text
}

///|
/// Explicit NFD normalization through the facade backend.
///
/// This is opt-in canonical normalization, not default document cleanup.
pub fn normalize_nfd(text : String) -> String {
  @unicode_normalization.nfd(text)
}

///|
/// Explicit NFC normalization through the facade backend.
///
/// This is opt-in canonical normalization, not default document cleanup.
pub fn normalize_nfc(text : String) -> String {
  @unicode_normalization.nfc(text)
}

///|
/// Explicit NFKD normalization through the facade backend.
///
/// This is opt-in canonical normalization, not default document cleanup.
pub fn normalize_nfkd(text : String) -> String {
  @unicode_normalization.nfkd(text)
}

///|
/// Explicit NFKC normalization through the facade backend.
///
/// This is opt-in canonical normalization, not default document cleanup.
pub fn normalize_nfkc(text : String) -> String {
  @unicode_normalization.nfkc(text)
}

///|
/// Facade quick check for explicit NFD normalization state.
pub fn is_normalized_nfd(text : String) -> Bool {
  @unicode_normalization.is_normalized(text, @unicode_normalization.NFD)
}

///|
/// Facade quick check for explicit NFC normalization state.
pub fn is_normalized_nfc(text : String) -> Bool {
  @unicode_normalization.is_normalized(text, @unicode_normalization.NFC)
}

///|
/// Facade quick check for explicit NFKD normalization state.
pub fn is_normalized_nfkd(text : String) -> Bool {
  @unicode_normalization.is_normalized(text, @unicode_normalization.NFKD)
}

///|
/// Facade quick check for explicit NFKC normalization state.
pub fn is_normalized_nfkc(text : String) -> Bool {
  @unicode_normalization.is_normalized(text, @unicode_normalization.NFKC)
}

///|
pub fn normalize_text_with_profile_summary(
  text : String,
  profile : NormalizeProfile,
) -> TextNormalizationResult {
  let options = default_text_normalization_options(profile)
  normalize_text_with_options_summary(text, profile, {
    ..options,
    record_summary: true,
    record_changes: true,
  })
}

///|
pub fn normalize_text_with_options(
  text : String,
  options : TextNormalizationOptions,
) -> String {
  normalize_text_with_options_summary(
    text,
    NormalizeProfile::GeneralText,
    options,
  ).text
}

///|
pub fn normalize_text_with_options_summary(
  text : String,
  profile : NormalizeProfile,
  options : TextNormalizationOptions,
) -> TextNormalizationResult {
  let counters = empty_stage_counters()
  let stages : Array[TextNormalizationStageSummary] = []
  let rules : Array[TextNormalizationRuleSummary] = []
  let warnings : Array[TextNormalizationWarning] = []

  let stage0 = run_validate_scalar_stage(text, warnings)
  push_stage_summary(
    stages,
    TextNormalizationStage::ValidateScalarStage,
    false,
    false,
    0,
    options,
  )

  let stage1 = run_line_ending_stage(stage0, options, counters, rules)
  push_stage_summary(
    stages,
    TextNormalizationStage::LineEndingStage,
    options.normalize_line_endings,
    stage1 != stage0,
    counters.line_endings + counters.tabs,
    options,
  )

  let stage2 = run_canonical_stage(
    stage1, profile, options, counters, warnings, rules,
  )
  push_stage_summary(
    stages,
    TextNormalizationStage::CanonicalUnicodeStage,
    options.canonical_form != CanonicalNormalizationForm::Disabled,
    stage2 != stage1,
    counters.canonical,
    options,
  )

  let stage3 = run_compatibility_stage(stage2, options, counters, rules)
  push_stage_summary(
    stages,
    TextNormalizationStage::CompatibilityGlyphStage,
    options.expand_ligatures ||
    options.normalize_quotes ||
    options.normalize_dashes ||
    options.normalize_fullwidth ||
    options.normalize_cjk_punctuation,
    stage3 != stage2,
    counters.ligatures +
    counters.quotes +
    counters.dashes +
    counters.fullwidth +
    counters.cjk_punctuation +
    counters.compatibility,
    options,
  )

  let stage4 = run_whitespace_stage(stage3, options, counters, rules)
  push_stage_summary(
    stages,
    TextNormalizationStage::WhitespaceStage,
    options.normalize_nbsp ||
    options.normalize_unicode_spaces ||
    options.collapse_space_like_runs ||
    options.cjk_spacing_policy == CjkSpacingPolicy::RemoveBetweenCjk ||
    options.remove_spaces_around_cjk_punctuation ||
    options.normalize_ascii_punctuation_spacing ||
    options.normalize_bullet_marker_spacing ||
    options.normalize_numbered_marker_spacing,
    stage4 != stage3,
    counters.nbsp +
    counters.unicode_spaces +
    counters.space_like_runs +
    counters.cjk_spacing +
    counters.cjk_punctuation_spacing +
    counters.ascii_punctuation_spacing +
    counters.bullet_marker_spacing +
    counters.numbered_marker_spacing,
    options,
  )

  let stage5 = run_invisible_char_stage(stage4, options, counters, rules)
  push_stage_summary(
    stages,
    TextNormalizationStage::InvisibleCharStage,
    options.remove_zero_width,
    stage5 != stage4,
    counters.zero_width,
    options,
  )

  let stage6 = run_soft_hyphen_stage(stage5, options, counters, rules)
  push_stage_summary(
    stages,
    TextNormalizationStage::SoftHyphenStage,
    options.remove_soft_hyphen,
    stage6 != stage5,
    counters.soft_hyphen,
    options,
  )

  let stage7 = run_pdf_glyph_stage(stage6, options, counters, rules)
  push_stage_summary(
    stages,
    TextNormalizationStage::PdfGlyphStage,
    options.pdf_private_glyph_fallback,
    stage7 != stage6,
    counters.pdf_glyph,
    options,
  )

  let stage8 = run_pdf_compare_stage(stage7, options, counters, rules)
  push_stage_summary(
    stages,
    TextNormalizationStage::PdfCompareStage,
    options.apply_pdf_compare_cleanup,
    stage8 != stage7,
    counters.pdf_compare_whitespace,
    options,
  )

  let changes = build_changes(counters, options)
  let total_changes = total_change_count(changes)
  let summary = { total_changes, changes, rules, stages, warnings }

  { text: stage8, changed: stage8 != text, profile, summary, changes }
}

///|
fn push_stage_summary(
  stages : Array[TextNormalizationStageSummary],
  stage : TextNormalizationStage,
  applied : Bool,
  changed : Bool,
  total_changes : Int,
  options : TextNormalizationOptions,
) -> Unit {
  if options.record_summary {
    stages.push({ stage, changed, total_changes, applied })
  }
}

///|
fn run_validate_scalar_stage(
  text : String,
  warnings : Array[TextNormalizationWarning],
) -> String {
  if text.contains("\u{FFFD}") {
    warnings.push({
      kind: TextNormalizationWarningKind::InvalidScalar,
      message: "replacement character detected in extracted text",
    })
  }
  text
}

///|
fn run_line_ending_stage(
  text : String,
  options : TextNormalizationOptions,
  counters : StageCounters,
  rules : Array[TextNormalizationRuleSummary],
) -> String {
  if !options.normalize_line_endings {
    push_rule_summary(
      rules,
      TextNormalizationRuleId::NormalizeLineEndings,
      TextNormalizationRuleScope::CharacterCleanup,
      false,
      false,
      0,
      options,
    )
    push_rule_summary(
      rules,
      TextNormalizationRuleId::NormalizeTabs,
      TextNormalizationRuleScope::WhitespaceCleanup,
      false,
      false,
      0,
      options,
    )
    return text
  }

  let chars = text.to_array()
  let out = StringBuilder::new()
  let mut i = 0

  while i < chars.length() {
    let ch = chars[i]

    if ch == '\r' {
      write_whitespace_substitute(out, options.preserve_newlines)
      counters.line_endings = counters.line_endings + 1
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i = i + 2
      } else {
        i = i + 1
      }
      continue
    }

    if ch == '\n' {
      if !options.preserve_newlines {
        out.write_char(' ')
        counters.line_endings = counters.line_endings + 1
      } else {
        out.write_char('\n')
      }
      i = i + 1
      continue
    }

    if ch == '\t' && !options.preserve_tabs {
      out.write_char(' ')
      counters.tabs = counters.tabs + 1
      i = i + 1
      continue
    }

    out.write_char(ch)
    i = i + 1
  }

  let stage = out.to_string()
  push_rule_summary(
    rules,
    TextNormalizationRuleId::NormalizeLineEndings,
    TextNormalizationRuleScope::CharacterCleanup,
    true,
    counters.line_endings > 0,
    counters.line_endings,
    options,
  )
  push_rule_summary(
    rules,
    TextNormalizationRuleId::NormalizeTabs,
    TextNormalizationRuleScope::WhitespaceCleanup,
    !options.preserve_tabs,
    counters.tabs > 0,
    counters.tabs,
    options,
  )
  stage
}

///|
fn write_whitespace_substitute(
  out : StringBuilder,
  preserve_newlines : Bool,
) -> Unit {
  if preserve_newlines {
    out.write_char('\n')
  } else {
    out.write_char(' ')
  }
}

///|
fn run_canonical_stage(
  text : String,
  profile : NormalizeProfile,
  options : TextNormalizationOptions,
  counters : StageCounters,
  warnings : Array[TextNormalizationWarning],
  rules : Array[TextNormalizationRuleSummary],
) -> String {
  let out = match options.canonical_form {
    CanonicalNormalizationForm::Disabled => text
    CanonicalNormalizationForm::NFD =>
      apply_canonical_result(
        text,
        normalize_nfd(text),
        profile,
        counters,
        warnings,
      )
    CanonicalNormalizationForm::NFC =>
      apply_canonical_result(
        text,
        normalize_nfc(text),
        profile,
        counters,
        warnings,
      )
    CanonicalNormalizationForm::NFKD =>
      apply_canonical_result(
        text,
        normalize_nfkd(text),
        profile,
        counters,
        warnings,
      )
    CanonicalNormalizationForm::NFKC =>
      apply_canonical_result(
        text,
        normalize_nfkc(text),
        profile,
        counters,
        warnings,
      )
  }

  push_rule_summary(
    rules,
    TextNormalizationRuleId::CanonicalUnicode,
    TextNormalizationRuleScope::CanonicalUnicode,
    options.canonical_form != CanonicalNormalizationForm::Disabled,
    out != text,
    counters.canonical,
    options,
  )
  out
}

///|
fn apply_canonical_result(
  original : String,
  normalized : String,
  profile : NormalizeProfile,
  counters : StageCounters,
  warnings : Array[TextNormalizationWarning],
) -> String {
  if profile == NormalizeProfile::Literal {
    warnings.push({
      kind: TextNormalizationWarningKind::SkippedDueToLiteralContext,
      message: "literal profile keeps cleanup conservative; explicit canonical normalization request is applied via facade backend",
    })
  }
  if normalized != original {
    counters.canonical = counters.canonical + 1
  }
  normalized
}

///|
fn run_compatibility_stage(
  text : String,
  options : TextNormalizationOptions,
  counters : StageCounters,
  rules : Array[TextNormalizationRuleSummary],
) -> String {
  let ligature_result = apply_char_mapping_rule(
    text,
    options.expand_ligatures,
    fn(ch) { map_ligature_char(ch, true) },
  )
  counters.ligatures = counters.ligatures + ligature_result.count
  counters.compatibility = counters.compatibility + ligature_result.count
  push_rule_summary(
    rules,
    TextNormalizationRuleId::ExpandLigatures,
    TextNormalizationRuleScope::CompatibilityGlyph,
    options.expand_ligatures,
    ligature_result.count > 0,
    ligature_result.count,
    options,
  )

  let quote_result = apply_char_mapping_rule(
    ligature_result.text,
    options.normalize_quotes,
    fn(ch) { map_quote_char(ch, true) },
  )
  counters.quotes = counters.quotes + quote_result.count
  counters.compatibility = counters.compatibility + quote_result.count
  push_rule_summary(
    rules,
    TextNormalizationRuleId::NormalizeQuotes,
    TextNormalizationRuleScope::CompatibilityGlyph,
    options.normalize_quotes,
    quote_result.count > 0,
    quote_result.count,
    options,
  )

  let dash_result = apply_char_mapping_rule(
    quote_result.text,
    options.normalize_dashes,
    fn(ch) { map_dash_char(ch, true) },
  )
  counters.dashes = counters.dashes + dash_result.count
  counters.compatibility = counters.compatibility + dash_result.count
  push_rule_summary(
    rules,
    TextNormalizationRuleId::NormalizeDashes,
    TextNormalizationRuleScope::CompatibilityGlyph,
    options.normalize_dashes,
    dash_result.count > 0,
    dash_result.count,
    options,
  )

  let fullwidth_result = apply_char_mapping_rule(
    dash_result.text,
    options.normalize_fullwidth,
    fn(ch) { map_fullwidth_char(ch, true) },
  )
  counters.fullwidth = counters.fullwidth + fullwidth_result.count
  counters.compatibility = counters.compatibility + fullwidth_result.count
  push_rule_summary(
    rules,
    TextNormalizationRuleId::NormalizeFullwidth,
    TextNormalizationRuleScope::CompatibilityGlyph,
    options.normalize_fullwidth,
    fullwidth_result.count > 0,
    fullwidth_result.count,
    options,
  )

  let cjk_punct_result = apply_char_mapping_rule(
    fullwidth_result.text,
    options.normalize_cjk_punctuation,
    fn(ch) { map_cjk_punctuation_char(ch, true) },
  )
  counters.cjk_punctuation = counters.cjk_punctuation + cjk_punct_result.count
  counters.compatibility = counters.compatibility + cjk_punct_result.count
  push_rule_summary(
    rules,
    TextNormalizationRuleId::NormalizeCjkPunctuation,
    TextNormalizationRuleScope::CompatibilityGlyph,
    options.normalize_cjk_punctuation,
    cjk_punct_result.count > 0,
    cjk_punct_result.count,
    options,
  )

  cjk_punct_result.text
}

///|
fn run_whitespace_stage(
  text : String,
  options : TextNormalizationOptions,
  counters : StageCounters,
  rules : Array[TextNormalizationRuleSummary],
) -> String {
  let nbsp_result = apply_nbsp_rule(text, options.normalize_nbsp)
  counters.nbsp = counters.nbsp + nbsp_result.count
  push_rule_summary(
    rules,
    TextNormalizationRuleId::NormalizeNbsp,
    TextNormalizationRuleScope::WhitespaceCleanup,
    options.normalize_nbsp,
    nbsp_result.count > 0,
    nbsp_result.count,
    options,
  )

  let unicode_space_result = apply_unicode_space_rule(
    nbsp_result.text,
    options.normalize_unicode_spaces,
  )
  counters.unicode_spaces = counters.unicode_spaces + unicode_space_result.count
  push_rule_summary(
    rules,
    TextNormalizationRuleId::NormalizeUnicodeSpaces,
    TextNormalizationRuleScope::WhitespaceCleanup,
    options.normalize_unicode_spaces,
    unicode_space_result.count > 0,
    unicode_space_result.count,
    options,
  )

  let collapse_result = apply_collapse_space_like_runs_rule(
    unicode_space_result.text,
    options.collapse_space_like_runs,
  )
  counters.space_like_runs = counters.space_like_runs + collapse_result.count
  push_rule_summary(
    rules,
    TextNormalizationRuleId::CollapseSpaceLikeRuns,
    TextNormalizationRuleScope::WhitespaceCleanup,
    options.collapse_space_like_runs,
    collapse_result.count > 0,
    collapse_result.count,
    options,
  )

  let remove_between_cjk_result = apply_remove_spaces_between_cjk_rule(
    collapse_result.text,
    options.cjk_spacing_policy == CjkSpacingPolicy::RemoveBetweenCjk,
  )
  counters.cjk_spacing = counters.cjk_spacing + remove_between_cjk_result.count
  push_rule_summary(
    rules,
    TextNormalizationRuleId::RemoveSpacesBetweenCjk,
    TextNormalizationRuleScope::CjkSpacing,
    options.cjk_spacing_policy == CjkSpacingPolicy::RemoveBetweenCjk,
    remove_between_cjk_result.count > 0,
    remove_between_cjk_result.count,
    options,
  )

  let remove_cjk_punct_result = apply_remove_spaces_around_cjk_punctuation_rule(
    remove_between_cjk_result.text,
    options.remove_spaces_around_cjk_punctuation,
  )
  counters.cjk_punctuation_spacing = counters.cjk_punctuation_spacing +
    remove_cjk_punct_result.count
  push_rule_summary(
    rules,
    TextNormalizationRuleId::RemoveSpacesAroundCjkPunctuation,
    TextNormalizationRuleScope::CjkSpacing,
    options.remove_spaces_around_cjk_punctuation,
    remove_cjk_punct_result.count > 0,
    remove_cjk_punct_result.count,
    options,
  )

  let ascii_punct_result = apply_normalize_ascii_punctuation_spacing_rule(
    remove_cjk_punct_result.text,
    options.normalize_ascii_punctuation_spacing,
  )
  counters.ascii_punctuation_spacing = counters.ascii_punctuation_spacing +
    ascii_punct_result.count
  push_rule_summary(
    rules,
    TextNormalizationRuleId::NormalizeAsciiPunctuationSpacing,
    TextNormalizationRuleScope::PunctuationSpacing,
    options.normalize_ascii_punctuation_spacing,
    ascii_punct_result.count > 0,
    ascii_punct_result.count,
    options,
  )

  let bullet_result = apply_normalize_bullet_marker_spacing_rule(
    ascii_punct_result.text,
    options.normalize_bullet_marker_spacing,
  )
  counters.bullet_marker_spacing = counters.bullet_marker_spacing +
    bullet_result.count
  push_rule_summary(
    rules,
    TextNormalizationRuleId::NormalizeBulletMarkerSpacing,
    TextNormalizationRuleScope::MarkerSpacing,
    options.normalize_bullet_marker_spacing,
    bullet_result.count > 0,
    bullet_result.count,
    options,
  )

  let numbered_result = apply_normalize_numbered_marker_spacing_rule(
    bullet_result.text,
    options.normalize_numbered_marker_spacing,
  )
  counters.numbered_marker_spacing = counters.numbered_marker_spacing +
    numbered_result.count
  push_rule_summary(
    rules,
    TextNormalizationRuleId::NormalizeNumberedMarkerSpacing,
    TextNormalizationRuleScope::MarkerSpacing,
    options.normalize_numbered_marker_spacing,
    numbered_result.count > 0,
    numbered_result.count,
    options,
  )

  numbered_result.text
}

///|
fn run_invisible_char_stage(
  text : String,
  options : TextNormalizationOptions,
  counters : StageCounters,
  rules : Array[TextNormalizationRuleSummary],
) -> String {
  if !options.remove_zero_width {
    push_rule_summary(
      rules,
      TextNormalizationRuleId::RemoveZeroWidth,
      TextNormalizationRuleScope::CharacterCleanup,
      false,
      false,
      0,
      options,
    )
    return text
  }

  let out = StringBuilder::new()
  let mut changed = false
  for ch in text {
    if is_zero_width_char(ch) {
      counters.zero_width = counters.zero_width + 1
      changed = true
    } else {
      out.write_char(ch)
    }
  }

  let result = if changed { out.to_string() } else { text }
  push_rule_summary(
    rules,
    TextNormalizationRuleId::RemoveZeroWidth,
    TextNormalizationRuleScope::CharacterCleanup,
    true,
    changed,
    counters.zero_width,
    options,
  )
  result
}

///|
fn run_soft_hyphen_stage(
  text : String,
  options : TextNormalizationOptions,
  counters : StageCounters,
  rules : Array[TextNormalizationRuleSummary],
) -> String {
  if !options.remove_soft_hyphen {
    push_rule_summary(
      rules,
      TextNormalizationRuleId::RemoveSoftHyphen,
      TextNormalizationRuleScope::CharacterCleanup,
      false,
      false,
      0,
      options,
    )
    return text
  }

  let out = StringBuilder::new()
  let mut changed = false
  for ch in text {
    if ch == '\u{00AD}' {
      counters.soft_hyphen = counters.soft_hyphen + 1
      changed = true
    } else {
      out.write_char(ch)
    }
  }

  let result = if changed { out.to_string() } else { text }
  push_rule_summary(
    rules,
    TextNormalizationRuleId::RemoveSoftHyphen,
    TextNormalizationRuleScope::CharacterCleanup,
    true,
    changed,
    counters.soft_hyphen,
    options,
  )
  result
}

///|
fn run_pdf_glyph_stage(
  text : String,
  options : TextNormalizationOptions,
  counters : StageCounters,
  rules : Array[TextNormalizationRuleSummary],
) -> String {
  if !options.pdf_private_glyph_fallback {
    push_rule_summary(
      rules,
      TextNormalizationRuleId::PdfPrivateGlyphFallback,
      TextNormalizationRuleScope::PdfCleanup,
      false,
      false,
      0,
      options,
    )
    return text
  }

  let out = StringBuilder::new()
  let mut changed = false
  for ch in text {
    match map_pdf_private_glyph(ch) {
      Some(mapped) => {
        out.write_string(mapped)
        counters.pdf_glyph = counters.pdf_glyph + 1
        changed = true
      }
      None => out.write_char(ch)
    }
  }

  let result = if changed { out.to_string() } else { text }
  push_rule_summary(
    rules,
    TextNormalizationRuleId::PdfPrivateGlyphFallback,
    TextNormalizationRuleScope::PdfCleanup,
    true,
    changed,
    counters.pdf_glyph,
    options,
  )
  result
}

///|
fn run_pdf_compare_stage(
  text : String,
  options : TextNormalizationOptions,
  counters : StageCounters,
  rules : Array[TextNormalizationRuleSummary],
) -> String {
  let result = apply_pdf_compare_whitespace_rule(
    text,
    options.apply_pdf_compare_cleanup,
  )
  counters.pdf_compare_whitespace = counters.pdf_compare_whitespace +
    result.count
  push_rule_summary(
    rules,
    TextNormalizationRuleId::CollapsePdfComparisonWhitespace,
    TextNormalizationRuleScope::CompareOnly,
    options.apply_pdf_compare_cleanup,
    result.count > 0,
    result.count,
    options,
  )
  result.text
}

///|
fn collapse_pdf_comparison_whitespace(text : String) -> String {
  let out = StringBuilder::new()
  let mut prev_space = false

  for ch in text {
    if is_collapse_space_char(ch) {
      if !prev_space {
        out.write_char(' ')
        prev_space = true
      }
    } else {
      out.write_char(ch)
      prev_space = false
    }
  }

  out.to_string()
}

///|
fn is_collapse_space_char(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
fn is_space_like_for_collapse(ch : Char) -> Bool {
  ch == ' ' ||
  ch == '\t' ||
  ch == '\n' ||
  ch == '\r' ||
  ch == '\u{00A0}' ||
  is_unicode_space_separator(ch)
}

///|
fn build_changes(
  counters : StageCounters,
  options : TextNormalizationOptions,
) -> Array[TextNormalizationChange] {
  let changes : Array[TextNormalizationChange] = []
  if !(options.record_changes || options.record_summary) {
    return changes
  }

  push_change(
    changes,
    TextNormalizationChangeKind::LineEndings,
    "\\r\\n/\\r/\\n",
    "\\n/space",
    counters.line_endings,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::Tabs,
    "\\t",
    " ",
    counters.tabs,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::Nbsp,
    "\\u00A0",
    " ",
    counters.nbsp,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::UnicodeSpaces,
    "unicode_space",
    " ",
    counters.unicode_spaces,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::SpaceLikeRuns,
    "space_like_run",
    "single_space",
    counters.space_like_runs,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::ZeroWidth,
    "zero_width",
    "",
    counters.zero_width,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::SoftHyphen,
    "\\u00AD",
    "",
    counters.soft_hyphen,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::Ligatures,
    "ligature",
    "expanded",
    counters.ligatures,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::Quotes,
    "smart_quote",
    "straight_quote",
    counters.quotes,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::Dashes,
    "dash_variant",
    "-",
    counters.dashes,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::Fullwidth,
    "fullwidth",
    "ascii",
    counters.fullwidth,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::CjkPunctuation,
    "cjk_punctuation",
    "ascii",
    counters.cjk_punctuation,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::CjkPunctuationSpacing,
    "space around CJK punctuation",
    "",
    counters.cjk_punctuation_spacing,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::AsciiPunctuationSpacing,
    "ascii punctuation spacing",
    "single_space",
    counters.ascii_punctuation_spacing,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::BulletMarkerSpacing,
    "bullet marker",
    "marker + space",
    counters.bullet_marker_spacing,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::NumberedMarkerSpacing,
    "numbered marker",
    "marker + space",
    counters.numbered_marker_spacing,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::Canonical,
    "canonical",
    "normalized",
    counters.canonical,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::Compatibility,
    "compatibility",
    "normalized",
    counters.compatibility,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::PdfGlyph,
    "pdf_glyph",
    "fallback",
    counters.pdf_glyph,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::CjkSpacing,
    "CJK space",
    "",
    counters.cjk_spacing,
  )
  push_change(
    changes,
    TextNormalizationChangeKind::PdfComparisonWhitespace,
    "comparison whitespace",
    "single_space",
    counters.pdf_compare_whitespace,
  )
  changes
}

///|
fn total_change_count(changes : Array[TextNormalizationChange]) -> Int {
  let mut total = 0
  for change in changes {
    total = total + change.count
  }
  total
}

///|
fn push_change(
  changes : Array[TextNormalizationChange],
  kind : TextNormalizationChangeKind,
  before : String,
  after : String,
  count : Int,
) -> Unit {
  if count > 0 {
    changes.push({ kind, before, after, count })
  }
}

///|
fn is_unicode_space_separator(ch : Char) -> Bool {
  ch == '\u{1680}' ||
  ch == '\u{2000}' ||
  ch == '\u{2001}' ||
  ch == '\u{2002}' ||
  ch == '\u{2003}' ||
  ch == '\u{2004}' ||
  ch == '\u{2005}' ||
  ch == '\u{2006}' ||
  ch == '\u{2007}' ||
  ch == '\u{2008}' ||
  ch == '\u{2009}' ||
  ch == '\u{200A}' ||
  ch == '\u{202F}' ||
  ch == '\u{205F}' ||
  ch == '\u{3000}'
}

///|
fn is_zero_width_char(ch : Char) -> Bool {
  ch == '\u{200B}' || ch == '\u{FEFF}'
}

///|
fn map_ligature_char(ch : Char, enabled : Bool) -> String? {
  if !enabled {
    return None
  }

  match ch {
    'ﬀ' => Some("ff")
    'ﬁ' => Some("fi")
    'ﬂ' => Some("fl")
    'ﬃ' => Some("ffi")
    'ﬄ' => Some("ffl")
    'ﬅ' => Some("ft")
    'ﬆ' => Some("st")
    _ => None
  }
}

///|
fn map_quote_char(ch : Char, enabled : Bool) -> String? {
  if !enabled {
    return None
  }

  match ch {
    '“' => Some("\"")
    '”' => Some("\"")
    '„' => Some("\"")
    '‟' => Some("\"")
    '‘' => Some("'")
    '’' => Some("'")
    '‚' => Some("'")
    '‛' => Some("'")
    _ => None
  }
}

///|
fn map_dash_char(ch : Char, enabled : Bool) -> String? {
  if !enabled {
    return None
  }

  match ch {
    '—' => Some("-")
    '–' => Some("-")
    '‒' => Some("-")
    '―' => Some("-")
    '﹣' => Some("-")
    '－' => Some("-")
    _ => None
  }
}

///|
fn map_fullwidth_char(ch : Char, enabled : Bool) -> String? {
  if !enabled {
    return None
  }

  let code = ch.to_int()
  if code == 0x3000 {
    return Some(" ")
  }
  if code >= 0xFF01 && code <= 0xFF5E {
    return Some(Int::unsafe_to_char(code - 0xFEE0).to_string())
  }
  None
}

///|
fn map_cjk_punctuation_char(ch : Char, enabled : Bool) -> String? {
  if !enabled {
    return None
  }

  match ch {
    '，' => Some(",")
    '。' => Some(".")
    '：' => Some(":")
    '；' => Some(";")
    '！' => Some("!")
    '？' => Some("?")
    '（' => Some("(")
    '）' => Some(")")
    '【' => Some("[")
    '】' => Some("]")
    _ => None
  }
}

///|
fn remove_spaces_between_cjk(text : String) -> (String, Int) {
  let chars = text.to_array()
  if chars.length() < 3 {
    return (text, 0)
  }

  let out = StringBuilder::new()
  let mut removed = 0
  let mut i = 0

  while i < chars.length() {
    let ch = chars[i]
    if ch == ' ' &&
      i > 0 &&
      i + 1 < chars.length() &&
      is_cjk_char(chars[i - 1]) &&
      is_cjk_char(chars[i + 1]) {
      removed = removed + 1
      i = i + 1
      continue
    }

    out.write_char(ch)
    i = i + 1
  }

  (out.to_string(), removed)
}

///|
fn is_cjk_char(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}
