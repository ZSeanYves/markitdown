///|
fn parse_hex_int(s : String) -> Int {
  let mut v : Int = 0
  for c in s.to_array() {
    let d = if c >= '0' && c <= '9' {
      c.to_int() - '0'.to_int()
    } else if c >= 'A' && c <= 'F' {
      10 + c.to_int() - 'A'.to_int()
    } else if c >= 'a' && c <= 'f' {
      10 + c.to_int() - 'a'.to_int()
    } else {
      -1
    }
    if d < 0 {
      return v
    }
    v = v * 16 + d
  }
  v
}

///|
fn all_hex_between_angles(line : String) -> Array[String] {
  let out : Array[String] = []
  let mut i = 0
  while i < line.length() {
    let mut l = i
    while l < line.length() && line[l] != '<' {
      l = l + 1
    }
    if l >= line.length() {
      break
    }
    let mut r = l + 1
    while r < line.length() && line[r] != '>' {
      r = r + 1
    }
    if r >= line.length() {
      break
    }
    out.push(line[l + 1:r].to_string())
    i = r + 1
  }
  out
}

///|
fn decode_utf16be_hex(hex : String) -> String raise {
  if hex.length() % 4 != 0 {
    return ""
  }
  let mut out = ""
  let mut i = 0
  while i + 3 < hex.length() {
    let cp_hex = hex[i:i + 4].to_string()
    let cp = parse_hex_int(cp_hex)
    if cp >= 0xD800 && cp <= 0xDFFF {
      return ""
    }
    if cp >= 0 && cp <= 0x10FFFF {
      out = out + Int::unsafe_to_char(cp).to_string()
    }
    i = i + 4
  }
  out
}

///|
pub fn parse_tounicode_cmap(stream : Bytes) -> Map[Int, String] raise {
  let text = @utf8.decode(stream)
  let out : Map[Int, String] = Map::new()
  let lines = text.split("\n")

  for sv in lines {
    let line = sv.to_string().trim().to_string()
    if line.contains("beginbfchar") {
      continue
    }
    if line.contains("beginbfrange") {
      continue
    }

    let hs = all_hex_between_angles(line)
    if hs.length() == 2 {
      let src = parse_hex_int(hs[0])
      let dst = decode_utf16be_hex(hs[1])
      if dst != "" {
        out.set(src, dst)
      }
      continue
    }

    if hs.length() == 3 {
      let start = parse_hex_int(hs[0])
      let end_ = parse_hex_int(hs[1])
      let dst_start = parse_hex_int(hs[2])
      if end_ >= start {
        let mut i = 0
        while start + i <= end_ {
          let cp = dst_start + i
          if cp >= 0 && cp <= 0x10FFFF {
            out.set(start + i, Int::unsafe_to_char(cp).to_string())
          }
          i = i + 1
        }
      }
    }
  }

  out
}
