///|
fn parse_pdf_list_item(s : String) -> (Bool, Int, String)? {
  let t = s.trim().to_owned()
  if t == "" {
    return None
  }

  if t.has_prefix("• ") || t.has_prefix("- ") || t.has_prefix("* ") {
    return Some((false, 0, t[2:].trim().to_owned()))
  }

  let cs = t.to_array()
  let n = cs.length()
  if n == 0 {
    return None
  }

  let mut i = 0
  let mut has_digit = false
  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    break
  }

  if has_digit && i + 1 < n {
    let c = cs[i]
    if (c == '.' || c == ')' || c == '）' || c == '、') && cs[i + 1] == ' ' {
      let text = String::from_array(cs[i + 2:].to_owned()).trim().to_owned()
      return Some((true, 0, text))
    }
  }

  None
}

///|
fn looks_like_list_item_sentence(s : String) -> Bool {
  let t = s.trim().to_owned()
  if t == "" {
    return false
  }

  if t.has_prefix("- ") || t.has_prefix("* ") || t.has_prefix("• ") {
    return true
  }

  let cs = t.to_array()
  let n = cs.length()
  if n == 0 {
    return false
  }

  let mut i = 0
  let mut has_digit = false
  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    break
  }

  if has_digit && i + 1 < n {
    let c = cs[i]
    if (c == '.' || c == '、' || c == ')' || c == '）') && cs[i + 1] == ' ' {
      return true
    }
  }

  false
}
