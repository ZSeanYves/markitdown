///|
/// 从 TJ 数组里抽 string 片段。
///
/// PDF `TJ` 数组里的数值不是稳定的“空格宽度”，只是文本位置调整。
/// 这里用保守启发式只恢复明显的英文词边界：
/// - 只看足够大的负 adjustment（常见于把下一个词往右推开）
/// - CJK / 标点前 / 连字符 / 小 kerning 不补空格
/// - 显式空格 glyph 已存在时不重复补
fn extract_text_fragments_from_tj_array(
  obj : @pdf.PdfObject,
  font_size : Double?,
) -> Array[String] {
  let out = Array::new()
  match obj {
    @pdf.PdfObject::Array(values) => {
      let mut previous_text : String? = None
      let mut pending_adjustment : Double? = None
      for value in values {
        match value {
          @pdf.PdfObject::String(text) => {
            match (previous_text, pending_adjustment) {
              (Some(left_text), Some(adjustment)) =>
                if should_insert_pdf_tj_word_space(
                    left_text, text, adjustment, font_size,
                  ) {
                  out.push(" ")
                }
              _ => ()
            }
            out.push(text)
            previous_text = Some(text)
            pending_adjustment = None
          }
          @pdf.PdfObject::Integer(n) =>
            pending_adjustment = if previous_text is Some(_) {
              Some(n.to_double())
            } else {
              None
            }
          @pdf.PdfObject::Real(x) =>
            pending_adjustment = if previous_text is Some(_) {
              Some(x)
            } else {
              None
            }
          _ => pending_adjustment = None
        }
      }
    }
    @pdf.PdfObject::String(text) => out.push(text)
    _ => ()
  }
  out
}

///|
fn should_insert_pdf_tj_word_space(
  left_text : String,
  right_text : String,
  adjustment : Double,
  font_size : Double?,
) -> Bool {
  if !tj_spacing_value_needs_word_space(adjustment, font_size) {
    return false
  }

  if has_explicit_space_boundary_tj(left_text, right_text) {
    return false
  }

  match (last_char_opt_tj(left_text), first_char_opt_tj(right_text)) {
    (Some(a), Some(b)) => {
      if is_cjk_char_tj(a) && is_cjk_char_tj(b) {
        return false
      }

      if is_right_tight_punct_tj(b) {
        return false
      }

      if is_hyphen_join_boundary_tj(a, b) {
        return false
      }

      if is_decimal_join_boundary_tj(a, b) {
        return false
      }

      (is_ascii_wordish_tj(a) && is_ascii_wordish_tj(b)) ||
      (is_left_space_worthy_punct_tj(a) && is_ascii_wordish_tj(b))
    }
    _ => false
  }
}

///|
fn tj_spacing_value_needs_word_space(
  adjustment : Double,
  font_size : Double?,
) -> Bool {
  if adjustment >= 0.0 {
    return false
  }

  let fs = font_size.unwrap_or(12.0)
  // `TJ` adjustments are text-space thousandths, not a true space-width metric.
  // We therefore keep a conservative heuristic threshold and only treat clearly
  // large negative values as likely word boundaries.
  let threshold = fs * 12.0
  adjustment <= -threshold
}

///|
fn has_explicit_space_boundary_tj(left : String, right : String) -> Bool {
  match (last_char_opt_tj(left), first_char_opt_tj(right)) {
    (Some(a), Some(b)) => is_space_like_char_tj(a) || is_space_like_char_tj(b)
    (Some(a), None) => is_space_like_char_tj(a)
    (None, Some(b)) => is_space_like_char_tj(b)
    (None, None) => false
  }
}

///|
fn last_char_opt_tj(text : String) -> Char? {
  let mut last : Char? = None
  for ch in text {
    last = Some(ch)
  }
  last
}

///|
fn first_char_opt_tj(text : String) -> Char? {
  for ch in text {
    return Some(ch)
  }
  None
}

///|
fn is_ascii_letter_tj(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn is_ascii_digit_tj(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_ascii_wordish_tj(ch : Char) -> Bool {
  is_ascii_letter_tj(ch) || is_ascii_digit_tj(ch)
}

///|
fn is_cjk_char_tj(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn is_space_like_char_tj(ch : Char) -> Bool {
  ch == ' ' ||
  ch == '\t' ||
  ch == '\n' ||
  ch == '\r' ||
  ch == '\u{00A0}' ||
  ch == '\u{2002}' ||
  ch == '\u{2003}' ||
  ch == '\u{2009}' ||
  ch == '　'
}

///|
fn is_right_tight_punct_tj(ch : Char) -> Bool {
  ch == '.' ||
  ch == ',' ||
  ch == ':' ||
  ch == ';' ||
  ch == '!' ||
  ch == '?' ||
  ch == ')' ||
  ch == ']' ||
  ch == '}' ||
  ch == '，' ||
  ch == '。' ||
  ch == '：' ||
  ch == '；' ||
  ch == '！' ||
  ch == '？' ||
  ch == '）' ||
  ch == '】' ||
  ch == '》'
}

///|
fn is_left_space_worthy_punct_tj(ch : Char) -> Bool {
  ch == ')' ||
  ch == ']' ||
  ch == '}' ||
  ch == ':' ||
  ch == ';' ||
  ch == ',' ||
  ch == '.'
}

///|
fn is_word_join_hyphen_char_tj(ch : Char) -> Bool {
  ch == '-' || ch == '\u{2010}' || ch == '\u{2011}'
}

///|
fn is_hyphen_join_boundary_tj(left : Char, right : Char) -> Bool {
  (is_ascii_wordish_tj(left) && is_word_join_hyphen_char_tj(right)) ||
  (is_word_join_hyphen_char_tj(left) && is_ascii_wordish_tj(right))
}

///|
fn is_decimal_join_boundary_tj(left : Char, right : Char) -> Bool {
  left == '.' && is_ascii_digit_tj(right)
}
