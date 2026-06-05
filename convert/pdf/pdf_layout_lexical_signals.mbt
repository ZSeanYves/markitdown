///|
/// Lexical/token helpers shared by PDF layout text signal extraction.
fn looks_like_us_state_zip_suffix(text : String) -> Bool {
  let chars = text.to_array()
  for i = 0; i + 7 < chars.length(); i = i + 1 {
    if chars[i] == ',' &&
      chars[i + 1] == ' ' &&
      is_ascii_upper(chars[i + 2]) &&
      is_ascii_upper(chars[i + 3]) &&
      chars[i + 4] == ' ' &&
      is_ascii_digit(chars[i + 5]) &&
      is_ascii_digit(chars[i + 6]) &&
      is_ascii_digit(chars[i + 7]) {
      return true
    }
  }
  false
}

///|
fn has_dotted_leader_page_token_signal(text : String) -> Bool {
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '.' || chars[i] == '…' {
      let mut j = i
      while j < chars.length() && (chars[j] == '.' || chars[j] == '…') {
        j += 1
      }
      if j - i >= 4 {
        let mut k = j
        while k < chars.length() && is_feature_whitespace(chars[k]) {
          k += 1
        }
        let mut page_token_len = 0
        while k + page_token_len < chars.length() &&
              !is_feature_whitespace(chars[k + page_token_len]) &&
              page_token_len < 8 {
          page_token_len += 1
        }
        if page_token_len > 0 &&
          looks_like_page_token_chars(chars[k:k + page_token_len].to_owned()) {
          return true
        }
      }
      i = j
    } else {
      i += 1
    }
  }
  false
}

///|
fn looks_like_page_token_chars(chars : Array[Char]) -> Bool {
  if chars.is_empty() {
    return false
  }
  let token = String::from_array(chars)
  if all_ascii_digits_feature(token) {
    return true
  }
  let lower = token.to_lower()
  for ch in lower.to_array() {
    if !(ch == 'i' ||
      ch == 'v' ||
      ch == 'x' ||
      ch == 'l' ||
      ch == 'c' ||
      ch == 'd' ||
      ch == 'm') {
      return false
    }
  }
  true
}

///|
fn count_char_feature(text : String, target : Char) -> Int {
  let mut count = 0
  for ch in text.to_array() {
    if ch == target {
      count += 1
    }
  }
  count
}

///|
fn repeated_separator_symbol_run(symbols : Array[Char]) -> Bool {
  if symbols.is_empty() {
    return false
  }
  let first = symbols[0]
  if !short_separator_char(first) {
    return false
  }
  for ch in symbols {
    if ch != first {
      return false
    }
  }
  true
}

///|
fn short_separator_char(ch : Char) -> Bool {
  ch == '-' || ch == '_' || ch == '=' || ch == '~' || ch == '*' || ch == '.'
}

///|
fn looks_like_dotted_identifier_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" ||
    trimmed.contains(" ") ||
    trimmed.contains("\t") ||
    trimmed.contains("/") ||
    trimmed.contains("\\") ||
    trimmed.contains("://") ||
    contains_email_signal(trimmed) {
    return false
  }
  let mut alpha_parts = 0
  let mut long_parts = 0
  let mut dot_count = 0
  let mut part_len = 0
  let mut has_alpha = false
  for ch in trimmed.to_array() {
    if ch == '.' {
      if part_len == 0 {
        return false
      }
      if part_len >= 2 {
        long_parts += 1
      }
      if has_alpha {
        alpha_parts += 1
      }
      dot_count += 1
      part_len = 0
      has_alpha = false
      continue
    }
    if !dotted_identifier_char(ch) {
      return false
    }
    part_len += 1
    if is_ascii_alpha(ch) {
      has_alpha = true
    }
  }
  if part_len == 0 {
    return false
  }
  if part_len >= 2 {
    long_parts += 1
  }
  if has_alpha {
    alpha_parts += 1
  }
  dot_count >= 1 && alpha_parts >= 2 && long_parts >= 2
}

///|
fn contains_camel_case_token_signal(text : String) -> Bool {
  for part in text.trim().split(" ") {
    if camel_case_token_signal(part.trim().to_owned()) {
      return true
    }
  }
  false
}

///|
fn camel_case_token_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() < 6 {
    return false
  }
  let mut has_upper = false
  let mut has_lower = false
  let mut has_boundary = false
  let mut prev_alpha = false
  let mut prev_lower = false
  for ch in chars {
    if !(is_ascii_alpha(ch) ||
      is_ascii_digit(ch) ||
      ch == '.' ||
      ch == '_' ||
      ch == '-' ||
      ch == '=' ||
      ch == '\\' ||
      ch == '/') {
      return false
    }
    if is_ascii_alpha(ch) {
      if ch >= 'A' && ch <= 'Z' {
        has_upper = true
        if prev_alpha && prev_lower {
          has_boundary = true
        }
        prev_lower = false
      } else {
        has_lower = true
        prev_lower = true
      }
      prev_alpha = true
    } else {
      prev_alpha = false
      prev_lower = false
    }
  }
  has_upper && has_lower && has_boundary
}

///|
fn dotted_identifier_char(ch : Char) -> Bool {
  is_ascii_alpha(ch) || is_ascii_digit(ch) || ch == '_' || ch == '-'
}

///|
fn assignment_like_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  for i = 1; i + 1 < chars.length(); i = i + 1 {
    if chars[i] != '=' {
      continue
    }
    if is_feature_whitespace(chars[i - 1]) ||
      is_feature_whitespace(chars[i + 1]) {
      continue
    }
    if !contains_ascii_alpha_text(String::from_array(chars[:i].to_owned())) ||
      !contains_ascii_alpha_text(String::from_array(chars[i + 1:].to_owned())) {
      continue
    }
    return true
  }
  false
}

///|
fn technical_separator_count(text : String) -> Int {
  let mut count = 0
  for ch in text.to_array() {
    if ch == '.' || ch == '_' || ch == '\\' || ch == '/' || ch == '=' {
      count += 1
    }
  }
  count
}

///|
fn contains_ascii_alpha_text(text : String) -> Bool {
  for ch in text.to_array() {
    if is_ascii_alpha(ch) {
      return true
    }
  }
  false
}

///|
fn looks_like_windows_drive_path(text : String) -> Bool {
  let chars = text.to_array()
  chars.length() >= 3 &&
  is_ascii_alpha(chars[0]) &&
  chars[1] == ':' &&
  (chars[2] == '\\' || chars[2] == '/')
}

///|
fn looks_like_sku_token(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() < 6 || !trimmed.contains("-") {
    return false
  }
  let mut upper = 0
  let mut lower = 0
  let mut digits = 0
  for ch in chars {
    if ch == '-' {
      continue
    }
    if ch >= 'A' && ch <= 'Z' {
      upper += 1
      continue
    }
    if ch >= 'a' && ch <= 'z' {
      lower += 1
      continue
    }
    if is_ascii_digit(ch) {
      digits += 1
      continue
    }
    return false
  }
  upper >= 2 && lower == 0 && digits >= 2
}

///|
fn count_numeric_runs(text : String) -> Int {
  let mut count = 0
  let mut in_run = false
  for ch in text.to_array() {
    if is_ascii_digit(ch) {
      if !in_run {
        count += 1
        in_run = true
      }
    } else {
      in_run = false
    }
  }
  count
}

///|
fn has_four_digit_run(text : String) -> Bool {
  let mut run = 0
  for ch in text.to_array() {
    if is_ascii_digit(ch) {
      run += 1
      if run >= 4 {
        return true
      }
    } else {
      run = 0
    }
  }
  false
}

///|
fn looks_like_cjk_page_number(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if !trimmed.has_prefix("第") {
    return false
  }
  let chars = trimmed.to_array()
  if chars.length() < 3 {
    return false
  }
  let last = chars[chars.length() - 1]
  if last != '页' && last != '⻚' {
    return false
  }
  let body = String::from_array(chars[1:chars.length() - 1].to_owned())
    .trim()
    .to_owned()
  if body == "" {
    return false
  }
  let digits = body.replace_all(old=" ", new="").replace_all(old="\t", new="")
  all_ascii_digits_feature(digits)
}

///|
fn begins_with_digit(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  is_ascii_digit(trimmed.to_array()[0])
}

///|
fn all_ascii_digits_feature(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  for ch in trimmed.to_array() {
    if !is_ascii_digit(ch) {
      return false
    }
  }
  true
}

///|
fn is_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_ascii_upper(ch : Char) -> Bool {
  ch >= 'A' && ch <= 'Z'
}

///|
fn is_ascii_alpha(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

///|
fn looks_like_uuidish_signal(text : String) -> Bool {
  let lower = text.to_lower()
  let chars = lower.to_array()
  if chars.length() < 24 || count_char_feature(lower, '-') < 3 {
    return false
  }
  let mut hexish = 0
  for ch in chars {
    if (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') {
      hexish += 1
    }
  }
  hexish * 2 >= chars.length()
}
