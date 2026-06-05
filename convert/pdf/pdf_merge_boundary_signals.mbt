///|
/// Cross-page merge boundary and continuation signal helpers.
fn looks_like_heading_start(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)

  if t == "" {
    return false
  }

  if t.has_prefix("第") && (t.contains("章") || t.contains("节")) {
    return true
  }

  if t.has_prefix("Chapter") ||
    t.has_prefix("Section") ||
    t.has_prefix("Introduction") ||
    t.has_prefix("Method") ||
    t.has_prefix("Conclusion") ||
    t.has_prefix("Next Section") {
    return true
  }

  false
}

///|
fn looks_like_numbered_list_start(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  if t == "" {
    return false
  }

  let arr = t.to_array()
  if arr.is_empty() {
    return false
  }

  let first = arr[0]
  if !is_digit_char(first) {
    return false
  }

  t.contains(". ") || t.contains(") ")
}

///|
fn looks_like_list_start(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  t.has_prefix("•") ||
  t.has_prefix("- ") ||
  t.has_prefix("* ") ||
  looks_like_numbered_list_start(t)
}

///|
fn looks_like_page_start_continuation(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  if t == "" {
    return false
  }

  if looks_like_heading_start(t) {
    return false
  }

  if looks_like_list_start(t) {
    return false
  }

  if is_page_label_like(t) {
    return false
  }

  let c = first_non_space_char(t)
  match c {
    Some(ch) => {
      if ch >= 'a' && ch <= 'z' {
        return true
      }
      if ch == '，' ||
        ch == ',' ||
        ch == '、' ||
        ch == ')' ||
        ch == '）' ||
        ch == ';' ||
        ch == '；' {
        return true
      }
      starts_with_continuation_phrase(t)
    }
    _ => false
  }
}

///|
fn starts_with_continuation_phrase(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  t.has_prefix("and ") ||
  t.has_prefix("or ") ||
  t.has_prefix("but ") ||
  t.has_prefix("because ") ||
  t.has_prefix("which ") ||
  t.has_prefix("that ") ||
  t.has_prefix("then ") ||
  t.has_prefix("therefore ") ||
  t.has_prefix("so ") ||
  t.has_prefix("to ") ||
  t.has_prefix("without ") ||
  t.has_prefix("with ")
}

///|
fn looks_like_new_section_after_page_break(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  if t == "" {
    return false
  }

  if looks_like_heading_start(t) {
    return true
  }

  if starts_with_numbered_section_heading(t) {
    return true
  }

  false
}

///|
fn starts_with_numbered_section_heading(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  let arr = t.to_array()
  if arr.length() < 3 {
    return false
  }

  (arr[0] >= '0' && arr[0] <= '9') &&
  (arr[1] == '.' || arr[1] == ')') &&
  arr[2] == ' '
}

///|
fn first_non_space_char(text : String) -> Char? {
  for ch in text {
    if ch != ' ' && ch != '\t' {
      return Some(ch)
    }
  }
  None
}

///|
fn font_size_close(left : Double?, right : Double?) -> Bool {
  match (left, right) {
    (Some(a), Some(b)) => abs_f64(a - b) <= 0.75
    _ => true
  }
}

///|
fn indent_close(left : Double?, right : Double?) -> Bool {
  match (left, right) {
    (Some(a), Some(b)) => abs_f64(a - b) <= 12.0
    _ => true
  }
}

///|
fn alignment_compatible(left : String?, right : String?) -> Bool {
  match (left, right) {
    (Some(a), Some(b)) => a == b
    _ => true
  }
}

///|
fn gap_looks_like_new_paragraph(
  gap_before : Double?,
  line_height : Double?,
) -> Bool {
  match (gap_before, line_height) {
    (Some(g), Some(h)) => h > 0.0 && g > h * 1.5
    _ => false
  }
}
