///|
fn trim_trailing_zeros(value : String) -> String {
  let dot = value.find(".")
  match dot {
    None => value
    Some(_) => {
      let chars = value[:]
      let mut end = chars.length() - 1
      while end >= 0 && chars[end] == '0' {
        end = end - 1
      }
      if end >= 0 && chars[end] == '.' {
        end = end - 1
      }
      if end < 0 {
        "0"
      } else {
        slice_range(value, 0, end + 1)
      }
    }
  }
}

///|
fn slice_from(value : String, start : Int) -> String {
  try value[start:] catch {
    _ => ""
  } noraise {
    view => view.to_string()
  }
}

///|
fn slice_range(value : String, start : Int, end : Int) -> String {
  try value[start:end] catch {
    _ => ""
  } noraise {
    view => view.to_string()
  }
}

///|
fn parse_signed_int(value : String) -> Int {
  let chars = value[:]
  if chars.length() == 0 {
    return 0
  }
  let mut sign = 1
  let mut i = 0
  match chars[0] {
    '-' => {
      sign = -1
      i = 1
    }
    '+' => i = 1
    _ => ()
  }
  let mut result = 0
  while i < chars.length() {
    let c = chars[i]
    if c < '0' || c > '9' {
      break
    }
    result = result * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  sign * result
}

///|
fn expand_scientific(value : String) -> String {
  let (sign, body) = match value.get_char(0) {
    Some('-') => ("-", slice_from(value, 1))
    _ => ("", value)
  }
  let exp_index = match body.find("e") {
    Some(i) => Some(i)
    None => body.find("E")
  }
  match exp_index {
    None => sign + trim_trailing_zeros(body)
    Some(idx) => {
      let mantissa = slice_range(body, 0, idx)
      let exp_str = slice_from(body, idx + 1)
      let exp = parse_signed_int(exp_str)
      let digits = Array::new()
      let mut int_len = 0
      let mut saw_dot = false
      for ch in mantissa {
        if ch == '.' {
          saw_dot = true
        } else {
          if !saw_dot {
            int_len = int_len + 1
          }
          digits.push(ch)
        }
      }
      if digits.length() == 0 {
        sign + "0"
      } else {
        let new_pos = int_len + exp
        let sb = StringBuilder::new()
        sb.write_string(sign)
        if new_pos <= 0 {
          sb.write_string("0.")
          for _ in 0..<-new_pos {
            sb.write_char('0')
          }
          for ch in digits {
            sb.write_char(ch)
          }
        } else if new_pos >= digits.length() {
          for ch in digits {
            sb.write_char(ch)
          }
          for _ in 0..<(new_pos - digits.length()) {
            sb.write_char('0')
          }
        } else {
          for i in 0..<digits.length() {
            if i == new_pos {
              sb.write_char('.')
            }
            sb.write_char(digits[i])
          }
        }
        trim_trailing_zeros(sb.to_string())
      }
    }
  }
}

///|
fn format_real(value : Double) -> String {
  if value == 0.0 {
    return "0"
  }
  let raw = value.to_string()
  if raw.contains("e") || raw.contains("E") {
    expand_scientific(raw)
  } else {
    trim_trailing_zeros(raw)
  }
}
