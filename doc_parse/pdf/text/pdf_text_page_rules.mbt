///|
/// Page-number and page-label rules shared by PDF text line merge and block
/// grouping.
///
/// Keep this package-local: these are parser cleanup signals, not public text
/// classification API.
fn is_page_number_candidate(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if t.length() <= 4 && all_ascii_digits(t) {
    return true
  }

  if looks_like_simple_english_page_label(t) {
    return true
  }

  if looks_like_simple_cjk_page_label(t) {
    return true
  }

  if looks_like_fraction_page_label(t) {
    return true
  }

  if looks_like_dash_page_label(t) {
    return true
  }

  false
}

///|
fn looks_like_simple_english_page_label(text : String) -> Bool {
  let t = text.trim().to_owned()

  if !(t.has_prefix("Page ") || t.has_prefix("page ")) {
    return false
  }

  let tail = t[5:].trim().to_owned()
  tail != "" && tail.length() <= 4 && all_ascii_digits(tail)
}

///|
fn looks_like_simple_cjk_page_label(text : String) -> Bool {
  let t = text.trim().to_owned()

  if !(t.has_prefix("第") && (t.has_suffix("页") || t.has_suffix("⻚"))) {
    return false
  }

  let mid = t
    .replace_all(old="第", new="")
    .replace_all(old="页", new="")
    .replace_all(old="⻚", new="")
    .trim()
    .to_owned()

  mid != "" && mid.length() <= 4 && all_ascii_digits(mid)
}

///|
fn looks_like_fraction_page_label(text : String) -> Bool {
  let t = text.trim().to_owned()

  let parts : Array[String] = Array::new()
  for part in t.split("/") {
    parts.push(part.to_owned())
  }

  if parts.length() != 2 {
    return false
  }

  let left = parts[0].trim().to_owned()
  let right = parts[1].trim().to_owned()

  left != "" &&
  right != "" &&
  left.length() <= 4 &&
  right.length() <= 4 &&
  all_ascii_digits(left) &&
  all_ascii_digits(right)
}

///|
fn looks_like_page_prefixed_section_heading(text : String) -> Bool {
  let t = text.trim().to_owned()
  let lt = t.to_lower()

  if !lt.has_prefix("page ") {
    return false
  }

  let words : Array[String] = Array::new()
  for sv in t.split(" ") {
    let w = sv.trim().to_owned()
    if w != "" {
      words.push(w)
    }
  }

  if words.length() < 4 || words.length() > 6 {
    return false
  }

  if words[0].to_lower() != "page" {
    return false
  }

  if !all_ascii_digits(words[1]) {
    return false
  }

  true
}

///|
fn looks_like_dash_page_label(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.length() > 12 {
    return false
  }

  let normalized = t.replace_all(old=" ", new="")
  if !normalized.contains("-") {
    return false
  }

  let parts = normalized.split("-")
  let mut non_empty = 0

  for p in parts {
    let s = p.trim().to_owned()
    if s != "" {
      if !all_ascii_digits(s) {
        return false
      }
      non_empty += 1
    }
  }

  non_empty >= 1 && non_empty <= 2
}

///|
fn is_page_noise_like(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if t.has_prefix("第") && t.contains("页") {
    return true
  }

  if t.has_prefix("Page ") || t.has_prefix("page ") {
    return true
  }

  if t.contains("/") {
    return true
  }

  if t.contains("-") && contains_any_ascii_digit(t.to_string()) {
    return true
  }

  false
}

///|
fn contains_any_ascii_digit(text : String) -> Bool {
  for ch in text {
    if ch >= '0' && ch <= '9' {
      return true
    }
  }
  false
}

///|
fn all_ascii_digits(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  for ch in text {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}
