///|
priv enum PdfToken {
  Name(String)
  Number(String)
  Keyword(String)
  LDict
  RDict
  LArray
  RArray
  LParen
  RParen
  Lt
  Gt
}

///|
fn read_token(bs : Bytes, pos : Int) -> (PdfToken, Int)? raise {
  let i = skip_ws_and_comment(bs, pos)
  if i >= bs.length() {
    return None
  }

  let ch = bs[i]
  if ch == '<'.to_int().to_byte() {
    if i + 1 < bs.length() && bs[i + 1] == '<'.to_int().to_byte() {
      return Some((PdfToken::LDict, i + 2))
    }
    return Some((PdfToken::Lt, i + 1))
  }
  if ch == '>'.to_int().to_byte() {
    if i + 1 < bs.length() && bs[i + 1] == '>'.to_int().to_byte() {
      return Some((PdfToken::RDict, i + 2))
    }
    return Some((PdfToken::Gt, i + 1))
  }
  if ch == '['.to_int().to_byte() {
    return Some((PdfToken::LArray, i + 1))
  }
  if ch == ']'.to_int().to_byte() {
    return Some((PdfToken::RArray, i + 1))
  }
  if ch == '('.to_int().to_byte() {
    return Some((PdfToken::LParen, i + 1))
  }
  if ch == ')'.to_int().to_byte() {
    return Some((PdfToken::RParen, i + 1))
  }

  if ch == '/'.to_int().to_byte() {
    let mut j = i + 1
    while j < bs.length() && !is_ws(bs[j]) && !is_delim(bs[j]) {
      j = j + 1
    }
    return Some((PdfToken::Name(bytes_to_string(bs, i + 1, j)), j))
  }

  let mut j = i
  while j < bs.length() && !is_ws(bs[j]) && !is_delim(bs[j]) {
    j = j + 1
  }
  let raw = bytes_to_string(bs, i, j)
  if raw == "" {
    return None
  }

  let is_num = {
    let chars = raw.to_array()
    let mut k = 0
    let mut has_digit = false
    while k < chars.length() {
      let c = chars[k]
      if c >= '0' && c <= '9' {
        has_digit = true
      } else if !(c == '+' || c == '-' || c == '.') {
        has_digit = false
        break
      }
      k = k + 1
    }
    has_digit
  }

  if is_num {
    Some((PdfToken::Number(raw), j))
  } else {
    Some((PdfToken::Keyword(raw), j))
  }
}
