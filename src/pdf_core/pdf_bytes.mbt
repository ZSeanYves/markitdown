///|
fn b(s : String) -> Bytes {
  @utf8.encode(s)
}

///|
fn is_ws(ch : Byte) -> Bool {
  ch == b'\x00' ||
  ch == b'\x09' ||
  ch == b'\x0A' ||
  ch == b'\x0C' ||
  ch == b'\x0D' ||
  ch == b'\x20'
}

///|
fn is_digit(ch : Byte) -> Bool {
  ch >= '0'.to_int().to_byte() && ch <= '9'.to_int().to_byte()
}

///|
fn is_delim(ch : Byte) -> Bool {
  ch == '('.to_int().to_byte() ||
  ch == ')'.to_int().to_byte() ||
  ch == '<'.to_int().to_byte() ||
  ch == '>'.to_int().to_byte() ||
  ch == '['.to_int().to_byte() ||
  ch == ']'.to_int().to_byte() ||
  ch == '{'.to_int().to_byte() ||
  ch == '}'.to_int().to_byte() ||
  ch == '/'.to_int().to_byte() ||
  ch == '%'.to_int().to_byte()
}

///|
fn bytes_to_string(bs : Bytes, start : Int, end_ : Int) -> String raise{
  if end_ <= start {
    return ""
  }
  @cor.utf8_bytes_to_string(bs[start:end_].to_bytes())
}

///|
fn starts_with_at(bs : Bytes, pos : Int, pat : String) -> Bool {
  let pb = b(pat)
  if pos < 0 || pos + pb.length() > bs.length() {
    return false
  }
  let mut i = 0
  while i < pb.length() {
    if bs[pos + i] != pb[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn skip_ws_and_comment(bs : Bytes, pos : Int) -> Int {
  let n = bs.length()
  let mut i = pos
  while i < n {
    let ch = bs[i]
    if is_ws(ch) {
      i = i + 1
      continue
    }
    if ch == '%'.to_int().to_byte() {
      i = i + 1
      while i < n && bs[i] != b'\x0A' && bs[i] != b'\x0D' {
        i = i + 1
      }
      continue
    }
    break
  }
  i
}

///|
fn find_last(bs : Bytes, pat : String) -> Int? {
  let pb = b(pat)
  let n = bs.length()
  let m = pb.length()
  if m == 0 || n < m {
    return None
  }

  let mut i = n - m
  while i >= 0 {
    let mut ok = true
    let mut j = 0
    while j < m {
      if bs[i + j] != pb[j] {
        ok = false
        break
      }
      j = j + 1
    }
    if ok {
      return Some(i)
    }
    i = i - 1
  }
  None
}

///|
fn read_int_ascii(bs : Bytes, pos : Int) -> (Int, Int)? {
  let n = bs.length()
  let mut i = pos
  if i >= n {
    return None
  }

  let mut sign = 1
  if bs[i] == '-'.to_int().to_byte() {
    sign = -1
    i = i + 1
  } else if bs[i] == '+'.to_int().to_byte() {
    i = i + 1
  }

  if i >= n || !is_digit(bs[i]) {
    return None
  }

  let mut v = 0
  while i < n && is_digit(bs[i]) {
    v = v * 10 + (bs[i].to_int() - '0'.to_int())
    i = i + 1
  }

  Some((sign * v, i))
}

///|
fn make_obj_key(obj_num : Int, gen : Int) -> String {
  obj_num.to_string() + ":" + gen.to_string()
}
