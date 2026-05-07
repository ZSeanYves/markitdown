///|
pub(all) enum NormalizeProfile {
  Literal
  GeneralText
  PdfText
  HtmlText
  OoxmlText
  StructuredDataText
} derive(Eq)

///|
pub(all) enum CjkSpacingPolicy {
  Preserve
  RemoveBetweenCjk
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
  CjkSpacing
} derive(Eq)

///|
pub(all) struct TextNormalizationOptions {
  normalize_line_endings : Bool
  normalize_nbsp : Bool
  collapse_unicode_spaces : Bool
  remove_zero_width : Bool
  remove_soft_hyphen : Bool
  expand_ligatures : Bool
  normalize_quotes : Bool
  normalize_dashes : Bool
  preserve_line_breaks : Bool
  preserve_tabs : Bool
  cjk_spacing_policy : CjkSpacingPolicy
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
pub(all) struct TextNormalizationResult {
  text : String
  changed : Bool
  changes : Array[TextNormalizationChange]
} derive(Eq)

///|
pub fn default_text_normalization_options(
  profile : NormalizeProfile,
) -> TextNormalizationOptions {
  match profile {
    NormalizeProfile::Literal =>
      {
        normalize_line_endings: true,
        normalize_nbsp: false,
        collapse_unicode_spaces: false,
        remove_zero_width: false,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        preserve_line_breaks: true,
        preserve_tabs: true,
        cjk_spacing_policy: CjkSpacingPolicy::Preserve,
        record_changes: false,
      }
    NormalizeProfile::GeneralText =>
      {
        normalize_line_endings: true,
        normalize_nbsp: true,
        collapse_unicode_spaces: false,
        remove_zero_width: true,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        preserve_line_breaks: true,
        preserve_tabs: true,
        cjk_spacing_policy: CjkSpacingPolicy::Preserve,
        record_changes: false,
      }
    NormalizeProfile::PdfText =>
      {
        normalize_line_endings: true,
        normalize_nbsp: true,
        collapse_unicode_spaces: true,
        remove_zero_width: true,
        remove_soft_hyphen: true,
        expand_ligatures: true,
        normalize_quotes: false,
        normalize_dashes: false,
        preserve_line_breaks: true,
        preserve_tabs: true,
        cjk_spacing_policy: CjkSpacingPolicy::Preserve,
        record_changes: false,
      }
    NormalizeProfile::HtmlText =>
      {
        normalize_line_endings: true,
        normalize_nbsp: true,
        collapse_unicode_spaces: false,
        remove_zero_width: true,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        preserve_line_breaks: true,
        preserve_tabs: true,
        cjk_spacing_policy: CjkSpacingPolicy::Preserve,
        record_changes: false,
      }
    NormalizeProfile::OoxmlText =>
      {
        normalize_line_endings: true,
        normalize_nbsp: true,
        collapse_unicode_spaces: false,
        remove_zero_width: true,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        preserve_line_breaks: true,
        preserve_tabs: true,
        cjk_spacing_policy: CjkSpacingPolicy::Preserve,
        record_changes: false,
      }
    NormalizeProfile::StructuredDataText =>
      {
        normalize_line_endings: true,
        normalize_nbsp: false,
        collapse_unicode_spaces: false,
        remove_zero_width: false,
        remove_soft_hyphen: false,
        expand_ligatures: false,
        normalize_quotes: false,
        normalize_dashes: false,
        preserve_line_breaks: true,
        preserve_tabs: true,
        cjk_spacing_policy: CjkSpacingPolicy::Preserve,
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
    default_text_normalization_options(profile),
  ).text
}

///|
pub fn normalize_text_with_profile_summary(
  text : String,
  profile : NormalizeProfile,
) -> TextNormalizationResult {
  let options = default_text_normalization_options(profile)
  normalize_text_with_options_summary(text, { ..options, record_changes: true })
}

///|
pub fn normalize_text_with_options(
  text : String,
  options : TextNormalizationOptions,
) -> String {
  normalize_text_with_options_summary(text, options).text
}

///|
pub fn normalize_text_with_options_summary(
  text : String,
  options : TextNormalizationOptions,
) -> TextNormalizationResult {
  let chars = text.to_array()
  let out = StringBuilder::new()
  let mut i = 0
  let mut line_endings_count = 0
  let mut tabs_count = 0
  let mut nbsp_count = 0
  let mut unicode_spaces_count = 0
  let mut zero_width_count = 0
  let mut soft_hyphen_count = 0
  let mut ligatures_count = 0
  let mut quotes_count = 0
  let mut dashes_count = 0

  while i < chars.length() {
    let ch = chars[i]

    if options.normalize_line_endings && ch == '\r' {
      if options.preserve_line_breaks {
        out.write_char('\n')
      } else {
        out.write_char(' ')
      }
      line_endings_count = line_endings_count + 1
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i = i + 2
      } else {
        i = i + 1
      }
      continue
    }

    if options.normalize_line_endings && ch == '\n' {
      if options.preserve_line_breaks {
        out.write_char('\n')
      } else {
        out.write_char(' ')
      }
      line_endings_count = line_endings_count + 1
      i = i + 1
      continue
    }

    if ch == '\t' && !options.preserve_tabs {
      out.write_char(' ')
      tabs_count = tabs_count + 1
      i = i + 1
      continue
    }

    if options.normalize_nbsp && ch == '\u{00A0}' {
      out.write_char(' ')
      nbsp_count = nbsp_count + 1
      i = i + 1
      continue
    }

    if options.collapse_unicode_spaces && is_unicode_space_separator(ch) {
      out.write_char(' ')
      unicode_spaces_count = unicode_spaces_count + 1
      i = i + 1
      continue
    }

    if options.remove_zero_width && is_zero_width_char(ch) {
      zero_width_count = zero_width_count + 1
      i = i + 1
      continue
    }

    if options.remove_soft_hyphen && ch == '\u{00AD}' {
      soft_hyphen_count = soft_hyphen_count + 1
      i = i + 1
      continue
    }

    match map_ligature_char(ch, options.expand_ligatures) {
      Some(mapped) => {
        out.write_string(mapped)
        ligatures_count = ligatures_count + 1
        i = i + 1
        continue
      }
      None => ()
    }

    match map_quote_char(ch, options.normalize_quotes) {
      Some(mapped) => {
        out.write_string(mapped)
        quotes_count = quotes_count + 1
        i = i + 1
        continue
      }
      None => ()
    }

    match map_dash_char(ch, options.normalize_dashes) {
      Some(mapped) => {
        out.write_string(mapped)
        dashes_count = dashes_count + 1
        i = i + 1
        continue
      }
      None => ()
    }

    out.write_char(ch)
    i = i + 1
  }

  let stage1 = out.to_string()
  let (final_text, cjk_spacing_count) = match options.cjk_spacing_policy {
    CjkSpacingPolicy::Preserve => (stage1, 0)
    CjkSpacingPolicy::RemoveBetweenCjk =>
      remove_spaces_between_cjk(stage1, options.record_changes)
  }

  let changed = final_text != text
  let changes : Array[TextNormalizationChange] = []

  if options.record_changes {
    push_change(
      changes,
      TextNormalizationChangeKind::LineEndings,
      "\\r\\n/\\r",
      "\\n",
      line_endings_count,
    )
    push_change(
      changes,
      TextNormalizationChangeKind::Tabs,
      "\\t",
      " ",
      tabs_count,
    )
    push_change(
      changes,
      TextNormalizationChangeKind::Nbsp,
      "\\u00A0",
      " ",
      nbsp_count,
    )
    push_change(
      changes,
      TextNormalizationChangeKind::UnicodeSpaces,
      "unicode_space",
      " ",
      unicode_spaces_count,
    )
    push_change(
      changes,
      TextNormalizationChangeKind::ZeroWidth,
      "zero_width",
      "",
      zero_width_count,
    )
    push_change(
      changes,
      TextNormalizationChangeKind::SoftHyphen,
      "\\u00AD",
      "",
      soft_hyphen_count,
    )
    push_change(
      changes,
      TextNormalizationChangeKind::Ligatures,
      "ligature",
      "expanded",
      ligatures_count,
    )
    push_change(
      changes,
      TextNormalizationChangeKind::Quotes,
      "smart_quote",
      "straight_quote",
      quotes_count,
    )
    push_change(
      changes,
      TextNormalizationChangeKind::Dashes,
      "dash_variant",
      "-",
      dashes_count,
    )
    push_change(
      changes,
      TextNormalizationChangeKind::CjkSpacing,
      "CJK space",
      "",
      cjk_spacing_count,
    )
  }

  { text: final_text, changed, changes }
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
fn remove_spaces_between_cjk(
  text : String,
  _record_changes : Bool,
) -> (String, Int) {
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
