///|
/// Keep cleanup isolated from quality judgement.
fn cleanup_pdf_text(text : String) -> String {
  let canonical_newline = text
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
  normalize_pdf_decoded_text(canonical_newline)
}

///|
/// PDF native text normalization entry:
/// 1) Unicode compatibility normalization (minimal fallback map)
/// 2) Minimal residual compatibility fixes only (no token join here)
fn normalize_pdf_decoded_text(text : String) -> String {
  let unicode_normalized = normalize_unicode_compat(text)
  normalize_pdf_text_special_cases(unicode_normalized)
}

///|
/// MoonBit stdlib currently has no built-in NFKC API in this project scope.
/// Keep a focused compatibility map as a minimal, maintainable fallback.
fn normalize_unicode_compat(text : String) -> String {
  let mut out = text

  // Latin ligatures
  out = out.replace(old="\u{FB00}", new="ff")
  out = out.replace(old="\u{FB01}", new="fi")
  out = out.replace(old="\u{FB02}", new="fl")
  out = out.replace(old="\u{FB03}", new="ffi")
  out = out.replace(old="\u{FB04}", new="ffl")

  // Frequently observed compatibility forms in current native regressions
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
  normalize_pdf_compat_residual(text)
}

///|
/// PDF residual compatibility glyphs seen in current regressions.
fn normalize_pdf_compat_residual(text : String) -> String {
  text.replace(old="⼆", new="二").replace(old="⾏", new="行")
}
