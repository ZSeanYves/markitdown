///|
/// PDF date representation.
pub struct Date {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
  hour_offset : Int
  minute_offset : Int
} derive(Debug)

///|
/// Raised when parsing a PDF date fails.
pub suberror BadDate

///|
fn Date::check(self : Date) -> Unit raise BadDate {
  if self.year < 0 ||
    self.year > 9999 ||
    self.month < 1 ||
    self.month > 12 ||
    self.day < 1 ||
    self.day > 31 ||
    self.hour < 0 ||
    self.hour > 23 ||
    self.minute < 0 ||
    self.minute > 59 ||
    self.second < 0 ||
    self.second > 59 ||
    self.hour_offset < -23 ||
    self.hour_offset > 23 ||
    self.minute_offset < -59 ||
    self.minute_offset > 59 {
    raise BadDate
  }
}

///|
fn abs_int(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn pad_int(value : Int, width : Int) -> String {
  let s = value.to_string()
  if s.length() >= width {
    s
  } else {
    "0".repeat(width - s.length()) + s
  }
}

///|
fn is_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn parse_digits(
  chars : Array[Char],
  pos : Int,
  count : Int,
) -> (Int, Int) raise BadDate {
  if pos + count > chars.length() {
    raise BadDate
  }
  let mut value = 0
  for i in 0..<count {
    let ch = chars[pos + i]
    if !is_digit(ch) {
      raise BadDate
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  (value, pos + count)
}

///|
fn optional_twochar_no_tz(
  chars : Array[Char],
  pos : Int,
  def : Int,
) -> (Int, Int) {
  if pos + 1 < chars.length() &&
    is_digit(chars[pos]) &&
    is_digit(chars[pos + 1]) {
    let value = (chars[pos].to_int() - '0'.to_int()) * 10 +
      (chars[pos + 1].to_int() - '0'.to_int())
    (value, pos + 2)
  } else {
    (def, chars.length())
  }
}

///|
fn parse_local_time(
  chars : Array[Char],
  pos : Int,
  hour_offset : Ref[Int],
  minute_offset : Ref[Int],
  sign : Ref[Int],
) -> Unit {
  if pos >= chars.length() {
    return
  }
  let ch = chars[pos]
  let o = if ch == '+' {
    1
  } else if ch == '-' {
    -1
  } else if ch == 'Z' {
    0
  } else {
    0
  }
  sign.val = o
  if o == 0 {
    return
  }
  let (h, pos1) = optional_twochar_no_tz(chars, pos + 1, 0)
  let mut m = 0
  if pos1 < chars.length() {
    let (m_val, _) = optional_twochar_no_tz(chars, pos1 + 1, 0)
    m = m_val
  }
  hour_offset.val = h
  minute_offset.val = m
}

///|
fn optional_twochar(
  chars : Array[Char],
  pos : Int,
  def : Int,
  hour_offset : Ref[Int],
  minute_offset : Ref[Int],
  sign : Ref[Int],
) -> (Int, Int) {
  if pos >= chars.length() {
    return (def, chars.length())
  }
  let ch = chars[pos]
  if ch == '-' || ch == '+' || ch == 'Z' {
    parse_local_time(chars, pos, hour_offset, minute_offset, sign)
    return (def, chars.length())
  }
  if pos + 1 < chars.length() &&
    is_digit(chars[pos]) &&
    is_digit(chars[pos + 1]) {
    let value = (chars[pos].to_int() - '0'.to_int()) * 10 +
      (chars[pos + 1].to_int() - '0'.to_int())
    (value, pos + 2)
  } else {
    (def, chars.length())
  }
}

///|
/// Build a string from a date.
pub fn Date::to_pdf_string(self : Date) -> String raise BadDate {
  self.check()
  let offset_str = if self.hour_offset < 0 {
    "-" +
    pad_int(abs_int(self.hour_offset), 2) +
    "'" +
    pad_int(abs_int(self.minute_offset), 2) +
    "'"
  } else if self.hour_offset > 0 {
    "+" +
    pad_int(abs_int(self.hour_offset), 2) +
    "'" +
    pad_int(abs_int(self.minute_offset), 2) +
    "'"
  } else {
    "Z"
  }
  "D:" +
  pad_int(self.year, 4) +
  pad_int(self.month, 2) +
  pad_int(self.day, 2) +
  pad_int(self.hour, 2) +
  pad_int(self.minute, 2) +
  pad_int(self.second, 2) +
  offset_str
}

///|
/// Build a date by parsing a PDF date string.
pub fn Date::of_pdf_string(s : String) -> Date raise BadDate {
  let chars = Array::new(capacity=s.length())
  for ch in s {
    chars.push(ch)
  }
  let mut pos = 0
  match chars {
    ['D', ':', ..] => pos = 2
    _ => ()
  }
  let year = if pos + 5 <= chars.length() &&
    chars[pos] == '1' &&
    chars[pos + 1] == '9' &&
    chars[pos + 2] == '1' &&
    chars[pos + 3] == '0' &&
    chars[pos + 4] == '0' {
    pos = pos + 5
    2000
  } else {
    let (value, next) = parse_digits(chars, pos, 4)
    pos = next
    value
  }
  let hour_offset = Ref::new(0)
  let minute_offset = Ref::new(0)
  let sign = Ref::new(0)
  let (month, pos) = optional_twochar(
    chars, pos, 1, hour_offset, minute_offset, sign,
  )
  let (day, pos) = optional_twochar(
    chars, pos, 1, hour_offset, minute_offset, sign,
  )
  let (hour, pos) = optional_twochar(
    chars, pos, 0, hour_offset, minute_offset, sign,
  )
  let (minute, pos) = optional_twochar(
    chars, pos, 0, hour_offset, minute_offset, sign,
  )
  let (second, pos) = optional_twochar(
    chars, pos, 0, hour_offset, minute_offset, sign,
  )
  parse_local_time(chars, pos, hour_offset, minute_offset, sign)
  let date : Date = {
    year,
    month,
    day,
    hour,
    minute,
    second,
    hour_offset: hour_offset.val * sign.val,
    minute_offset: minute_offset.val * sign.val,
  }
  date.check()
  date
}
