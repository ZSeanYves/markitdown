///|
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
pub(all) enum CanonicalNormalizationForm {
  Disabled
  NFC
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
  ZeroWidth
  SoftHyphen
  Ligatures
  Quotes
  Dashes
  Fullwidth
  CjkPunctuation
  Canonical
  Compatibility
  PdfGlyph
  CjkSpacing
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
  remove_zero_width : Bool
  remove_soft_hyphen : Bool
  expand_ligatures : Bool
  normalize_quotes : Bool
  normalize_dashes : Bool
  normalize_fullwidth : Bool
  normalize_cjk_punctuation : Bool
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
  mut zero_width : Int
  mut soft_hyphen : Int
  mut ligatures : Int
  mut quotes : Int
  mut dashes : Int
  mut fullwidth : Int
  mut cjk_punctuation : Int
  canonical : Int
  mut compatibility : Int
  mut pdf_glyph : Int
  mut cjk_spacing : Int
}

///|
fn empty_stage_counters() -> StageCounters {
  {
    line_endings: 0,
    tabs: 0,
    nbsp: 0,
    unicode_spaces: 0,
    zero_width: 0,
    soft_hyphen: 0,
    ligatures: 0,
    quotes: 0,
    dashes: 0,
    fullwidth: 0,
    cjk_punctuation: 0,
    canonical: 0,
    compatibility: 0,
    pdf_glyph: 0,
    cjk_spacing: 0,
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
        remove_zero_width: false,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        normalize_fullwidth: false,
        normalize_cjk_punctuation: false,
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
        remove_zero_width: true,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        normalize_fullwidth: false,
        normalize_cjk_punctuation: false,
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
        remove_zero_width: true,
        remove_soft_hyphen: true,
        expand_ligatures: true,
        normalize_quotes: false,
        normalize_dashes: false,
        normalize_fullwidth: false,
        normalize_cjk_punctuation: false,
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
        remove_zero_width: true,
        remove_soft_hyphen: true,
        expand_ligatures: true,
        normalize_quotes: false,
        normalize_dashes: false,
        normalize_fullwidth: false,
        normalize_cjk_punctuation: false,
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
        remove_zero_width: true,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        normalize_fullwidth: false,
        normalize_cjk_punctuation: false,
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
        remove_zero_width: true,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        normalize_fullwidth: false,
        normalize_cjk_punctuation: false,
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
        remove_zero_width: false,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        normalize_fullwidth: false,
        normalize_cjk_punctuation: false,
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

  let stage1 = run_line_ending_stage(stage0, options, counters)
  push_stage_summary(
    stages,
    TextNormalizationStage::LineEndingStage,
    options.normalize_line_endings,
    stage1 != stage0,
    counters.line_endings + counters.tabs,
    options,
  )

  let stage2 = run_canonical_stage(stage1, profile, options, counters, warnings)
  push_stage_summary(
    stages,
    TextNormalizationStage::CanonicalUnicodeStage,
    options.canonical_form != CanonicalNormalizationForm::Disabled,
    stage2 != stage1,
    counters.canonical,
    options,
  )

  let stage3 = run_compatibility_stage(stage2, options, counters)
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

  let stage4 = run_whitespace_stage(stage3, options, counters)
  push_stage_summary(
    stages,
    TextNormalizationStage::WhitespaceStage,
    options.normalize_nbsp ||
    options.normalize_unicode_spaces ||
    options.cjk_spacing_policy == CjkSpacingPolicy::RemoveBetweenCjk,
    stage4 != stage3,
    counters.nbsp + counters.unicode_spaces + counters.cjk_spacing,
    options,
  )

  let stage5 = run_invisible_char_stage(stage4, options, counters)
  push_stage_summary(
    stages,
    TextNormalizationStage::InvisibleCharStage,
    options.remove_zero_width,
    stage5 != stage4,
    counters.zero_width,
    options,
  )

  let stage6 = run_soft_hyphen_stage(stage5, options, counters)
  push_stage_summary(
    stages,
    TextNormalizationStage::SoftHyphenStage,
    options.remove_soft_hyphen,
    stage6 != stage5,
    counters.soft_hyphen,
    options,
  )

  let stage7 = run_pdf_glyph_stage(stage6, options, counters)
  push_stage_summary(
    stages,
    TextNormalizationStage::PdfGlyphStage,
    options.pdf_private_glyph_fallback,
    stage7 != stage6,
    counters.pdf_glyph,
    options,
  )

  let stage8 = run_pdf_compare_stage(stage7, options, counters)
  push_stage_summary(
    stages,
    TextNormalizationStage::PdfCompareStage,
    options.apply_pdf_compare_cleanup,
    stage8 != stage7,
    counters.compatibility,
    options,
  )

  let changes = build_changes(counters, options)
  let total_changes = total_change_count(changes)
  let summary = { total_changes, changes, stages, warnings }

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
) -> String {
  if !options.normalize_line_endings {
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

  out.to_string()
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
) -> String {
  match options.canonical_form {
    CanonicalNormalizationForm::Disabled => text
    CanonicalNormalizationForm::NFC => {
      warnings.push({
        kind: TextNormalizationWarningKind::UnsupportedNormalization,
        message: "NFC requested but MoonBit stdlib normalization API is unavailable; stage kept as no-op",
      })
      maybe_warn_literal(profile, warnings)
      let _ = counters
      text
    }
    CanonicalNormalizationForm::NFKC => {
      warnings.push({
        kind: TextNormalizationWarningKind::UnsupportedNormalization,
        message: "NFKC requested but full compatibility normalization is not implemented in project scope",
      })
      maybe_warn_literal(profile, warnings)
      let _ = counters
      text
    }
  }
}

///|
fn maybe_warn_literal(
  profile : NormalizeProfile,
  warnings : Array[TextNormalizationWarning],
) -> Unit {
  if profile == NormalizeProfile::Literal {
    warnings.push({
      kind: TextNormalizationWarningKind::SkippedDueToLiteralContext,
      message: "literal profile keeps source text conservative; aggressive normalization is skipped",
    })
  }
}

///|
fn run_compatibility_stage(
  text : String,
  options : TextNormalizationOptions,
  counters : StageCounters,
) -> String {
  let out = StringBuilder::new()
  let mut changed = false

  for ch in text {
    match map_compatibility_char(ch, options) {
      Some((mapped, kind)) => {
        out.write_string(mapped)
        record_compatibility_change(counters, kind)
        changed = true
      }
      None => out.write_char(ch)
    }
  }

  if changed {
    out.to_string()
  } else {
    text
  }
}

///|
fn map_compatibility_char(
  ch : Char,
  options : TextNormalizationOptions,
) -> (String, TextNormalizationChangeKind)? {
  match map_ligature_char(ch, options.expand_ligatures) {
    Some(mapped) => Some((mapped, TextNormalizationChangeKind::Ligatures))
    None =>
      match map_quote_char(ch, options.normalize_quotes) {
        Some(mapped) => Some((mapped, TextNormalizationChangeKind::Quotes))
        None =>
          match map_dash_char(ch, options.normalize_dashes) {
            Some(mapped) => Some((mapped, TextNormalizationChangeKind::Dashes))
            None =>
              match map_fullwidth_char(ch, options.normalize_fullwidth) {
                Some(mapped) =>
                  Some((mapped, TextNormalizationChangeKind::Fullwidth))
                None =>
                  match
                    map_cjk_punctuation_char(
                      ch,
                      options.normalize_cjk_punctuation,
                    ) {
                    Some(mapped) =>
                      Some(
                        (mapped, TextNormalizationChangeKind::CjkPunctuation),
                      )
                    None => None
                  }
              }
          }
      }
  }
}

///|
fn record_compatibility_change(
  counters : StageCounters,
  kind : TextNormalizationChangeKind,
) -> Unit {
  counters.compatibility = counters.compatibility + 1
  match kind {
    TextNormalizationChangeKind::Ligatures =>
      counters.ligatures = counters.ligatures + 1
    TextNormalizationChangeKind::Quotes => counters.quotes = counters.quotes + 1
    TextNormalizationChangeKind::Dashes => counters.dashes = counters.dashes + 1
    TextNormalizationChangeKind::Fullwidth =>
      counters.fullwidth = counters.fullwidth + 1
    TextNormalizationChangeKind::CjkPunctuation =>
      counters.cjk_punctuation = counters.cjk_punctuation + 1
    _ => ()
  }
}

///|
fn run_whitespace_stage(
  text : String,
  options : TextNormalizationOptions,
  counters : StageCounters,
) -> String {
  let chars = text.to_array()
  let out = StringBuilder::new()
  let mut i = 0
  let mut changed = false

  while i < chars.length() {
    let ch = chars[i]
    if options.normalize_nbsp && ch == '\u{00A0}' {
      out.write_char(' ')
      counters.nbsp = counters.nbsp + 1
      changed = true
      i = i + 1
      continue
    }

    if options.normalize_unicode_spaces && is_unicode_space_separator(ch) {
      out.write_char(' ')
      counters.unicode_spaces = counters.unicode_spaces + 1
      changed = true
      i = i + 1
      continue
    }

    out.write_char(ch)
    i = i + 1
  }

  let stage1 = if changed { out.to_string() } else { text }
  let (stage2, cjk_spacing_count) = match options.cjk_spacing_policy {
    CjkSpacingPolicy::Preserve => (stage1, 0)
    CjkSpacingPolicy::RemoveBetweenCjk => remove_spaces_between_cjk(stage1)
  }
  counters.cjk_spacing = counters.cjk_spacing + cjk_spacing_count
  stage2
}

///|
fn run_invisible_char_stage(
  text : String,
  options : TextNormalizationOptions,
  counters : StageCounters,
) -> String {
  if !options.remove_zero_width {
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

  if changed {
    out.to_string()
  } else {
    text
  }
}

///|
fn run_soft_hyphen_stage(
  text : String,
  options : TextNormalizationOptions,
  counters : StageCounters,
) -> String {
  if !options.remove_soft_hyphen {
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

  if changed {
    out.to_string()
  } else {
    text
  }
}

///|
fn run_pdf_glyph_stage(
  text : String,
  options : TextNormalizationOptions,
  counters : StageCounters,
) -> String {
  if !options.pdf_private_glyph_fallback {
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

  if changed {
    out.to_string()
  } else {
    text
  }
}

///|
fn run_pdf_compare_stage(
  text : String,
  options : TextNormalizationOptions,
  counters : StageCounters,
) -> String {
  if !options.apply_pdf_compare_cleanup {
    return text
  }

  let collapsed = collapse_pdf_comparison_whitespace(text)
  if collapsed != text {
    counters.compatibility = counters.compatibility + 1
  }
  collapsed.trim().to_owned()
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
