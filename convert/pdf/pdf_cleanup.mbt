///|
/// Keep cleanup isolated from quality judgement.
fn cleanup_pdf_text(text : String) -> String {
  let canonical_newline =
    text.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
  normalize_pdf_decoded_text(canonical_newline)
}

///|
/// PDF native text normalization entry:
/// 1) Unicode compatibility normalization (NFKC-like fallback map)
/// 2) PDF extraction specific post-fixes
fn normalize_pdf_decoded_text(text : String) -> String {
  let unicode_normalized = normalize_unicode_compat(text)
  normalize_pdf_text_special_cases(unicode_normalized)
}

///|
/// MoonBit stdlib currently has no built-in NFKC API in this project scope.
/// Keep a focused compatibility map as a minimal, maintainable fallback.
fn normalize_unicode_compat(text : String) -> String {
  let mut out = text

  // Latin ligatures (high-frequency in PDF extraction)
  out = out.replace(old="\u{FB00}", new="ff")
  out = out.replace(old="\u{FB01}", new="fi")
  out = out.replace(old="\u{FB02}", new="fl")
  out = out.replace(old="\u{FB03}", new="ffi")
  out = out.replace(old="\u{FB04}", new="ffl")

  // Frequently observed compatibility forms in current native samples
  out = out.replace(old="⼀", new="一")
  out = out.replace(old="⾸", new="首")
  out = out.replace(old="⽂", new="文")
  out = out.replace(old="⽬", new="目")
  out = out.replace(old="⽤", new="用")
  out = out.replace(old="⽀", new="支")
  out = out.replace(old="⽅", new="方")
  out = out.replace(old="⽣", new="生")
  out
}

///|
/// Keep PDF-oriented fixes centralized and explicitly layered.
fn normalize_pdf_text_special_cases(text : String) -> String {
  collapse_space_between_cjk_chars(text)
}

///|
fn collapse_space_between_cjk_chars(text : String) -> String {
  let chars = text.to_array()
  let n = chars.length()
  let mut out = ""
  let mut i = 0
  while i < n {
    let c = chars[i]
    if (c == ' ' || c == '\t') && i > 0 && i + 1 < n {
      if is_cjk_ideograph(chars[i - 1]) && is_cjk_ideograph(chars[i + 1]) {
        i = i + 1
        continue
      }
    }
    out = out + c.to_string()
    i = i + 1
  }
  out
}

///|
fn is_cjk_ideograph(c : Char) -> Bool {
  let v = c.to_int()
  (v >= 0x3400 && v <= 0x4DBF) ||
  (v >= 0x4E00 && v <= 0x9FFF) ||
  (v >= 0xF900 && v <= 0xFAFF) ||
  (v >= 0x20000 && v <= 0x2A6DF) ||
  (v >= 0x2A700 && v <= 0x2B73F) ||
  (v >= 0x2B740 && v <= 0x2B81F) ||
  (v >= 0x2B820 && v <= 0x2CEAF) ||
  (v >= 0x2CEB0 && v <= 0x2EBEF) ||
  (v >= 0x30000 && v <= 0x3134F)
}
