///|
/// PDF object serialization functions.

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
  let first = chars[0]
  if first is '-' {
    sign = -1
    i = 1
  } else if first is '+' {
    i = 1
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

///|
fn is_delimiter_byte(b : Int) -> Bool {
  match b {
    b if b == '('.to_int() => true
    b if b == ')'.to_int() => true
    b if b == '<'.to_int() => true
    b if b == '>'.to_int() => true
    b if b == '['.to_int() => true
    b if b == ']'.to_int() => true
    b if b == '{'.to_int() => true
    b if b == '}'.to_int() => true
    b if b == '/'.to_int() => true
    b if b == '%'.to_int() => true
    _ => false
  }
}

///|
fn hex_digit(value : Int) -> Char {
  match value {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'A'
    11 => 'B'
    12 => 'C'
    13 => 'D'
    14 => 'E'
    15 => 'F'
    _ => '0'
  }
}

///|
fn needs_processing_name(bytes : @pdfio.MutableBytes) -> Bool {
  if bytes.length() < 2 {
    return false
  }
  for i in 1..<bytes.length() {
    let b = bytes[i].to_int()
    if b < 33 || b > 126 || is_delimiter_byte(b) || b == '#'.to_int() {
      return true
    }
  }
  false
}

///|
fn make_pdf_name(name : String) -> String {
  let normalized = match name.get_char(0) {
    Some('/') => name
    _ => {
      @pdfe.log("warning: bad name |\{name}|\n")
      "/" + name
    }
  }
  let bytes = @pdfio.bytes_of_string(normalized)
  if !needs_processing_name(bytes) {
    return normalized
  }
  let sb = StringBuilder::new()
  sb.write_char('/')
  for i in 1..<bytes.length() {
    let b = bytes[i].to_int()
    if b < 33 || b > 126 || is_delimiter_byte(b) || b == '#'.to_int() {
      sb.write_char('#')
      sb.write_char(hex_digit(b / 16))
      sb.write_char(hex_digit(b % 16))
    } else {
      sb.write_char(b.unsafe_to_char())
    }
  }
  sb.to_string()
}

///|
fn make_pdf_string(value : String) -> String {
  let sb = StringBuilder::new()
  sb.write_char('(')
  for ch in value {
    match ch {
      '(' | ')' | '\\' => {
        sb.write_char('\\')
        sb.write_char(ch)
      }
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      '\b' => sb.write_string("\\b")
      '\u000C' => sb.write_string("\\f")
      _ => sb.write_char(ch)
    }
  }
  sb.write_char(')')
  sb.to_string()
}

///|
fn write_pdf_object(
  obj : PdfObject,
  include_stream_data : Bool,
  warn_on_toget : Bool,
  sb : StringBuilder,
) -> Unit {
  match obj {
    PdfObject::Null => sb.write_string("null")
    PdfObject::Boolean(b) => sb.write_string(if b { "true" } else { "false" })
    PdfObject::Integer(i) => sb.write_string(i.to_string())
    PdfObject::Real(r) => sb.write_string(format_real(r))
    PdfObject::String(s) => sb.write_string(make_pdf_string(s))
    PdfObject::Name(n) => sb.write_string(make_pdf_name(n.to_string_bytes()))
    PdfObject::Array(values) => {
      sb.write_char('[')
      for i in 0..<values.length() {
        if i > 0 {
          sb.write_char(' ')
        }
        write_pdf_object(values[i], include_stream_data, warn_on_toget, sb)
      }
      sb.write_char(']')
    }
    PdfObject::Dictionary(entries) => {
      sb.write_string("<<")
      for i in 0..<entries.length() {
        let (key, value) = entries[i]
        if i > 0 {
          sb.write_char(' ')
        }
        sb.write_string(make_pdf_name(key))
        sb.write_char(' ')
        write_pdf_object(value, include_stream_data, warn_on_toget, sb)
      }
      sb.write_string(">>")
    }
    PdfObject::Stream(r) => {
      let (dict, _) = r.val
      write_pdf_object(dict, include_stream_data, warn_on_toget, sb)
      sb.write_string("\nstream\n")
      if include_stream_data {
        let _ = obj.getstream() catch { _ => () }
        match r.val {
          (_, Stream::Got(bytes)) =>
            sb.write_string(@pdfio.string_of_bytes(bytes))
          _ =>
            if warn_on_toget {
              @pdfe.log("WARNING: toget in string_of_pdfobj_including_data\n")
            }
        }
      }
      sb.write_string("\nendstream")
    }
    PdfObject::Indirect(n) => sb.write_string("\{n} 0 R")
  }
}

///|
/// Convert a PDF object to its string representation.
pub fn PdfObject::to_string(self : PdfObject) -> String {
  let sb = StringBuilder::new()
  write_pdf_object(self, false, false, sb)
  sb.to_string()
}

///|
/// Convert a PDF object to string including stream data.
pub fn PdfObject::to_string_including_data(self : PdfObject) -> String {
  let sb = StringBuilder::new()
  write_pdf_object(self, true, true, sb)
  sb.to_string()
}

///|
test "serialize helpers handle trimming and slicing" {
  assert_eq(trim_trailing_zeros("123"), "123")
  assert_eq(trim_trailing_zeros("1.23000"), "1.23")
  assert_eq(trim_trailing_zeros("0.000"), "0")
  assert_eq(slice_from("x", 2), "")
  assert_eq(slice_range("x", 0, 5), "")
  assert_eq(parse_signed_int(""), 0)
  assert_eq(parse_signed_int("+12x"), 12)
  assert_eq(parse_signed_int("-3"), -3)
}

///|
test "expand_scientific formats exponent strings" {
  assert_eq(expand_scientific("-1.2300"), "-1.23")
  assert_eq(expand_scientific("e1"), "0")
  assert_eq(expand_scientific("1e-3"), "0.001")
  assert_eq(expand_scientific("1e3"), "1000")
  assert_eq(expand_scientific("12.34e1"), "123.4")
}
