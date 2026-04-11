///|
fn load_tounicode(
  doc : PdfDocument,
  font_ref : PdfFontRef,
) -> (Map[Int, String], Array[Int]) raise {
  match (font_ref.to_unicode_obj, font_ref.to_unicode_gen) {
    (Some(obj), Some(gen)) => {
      let o = get_indirect_object(doc, obj, gen)
      match o.stream {
        Some(bs) => (parse_tounicode_cmap(bs), infer_cmap_code_widths(bs))
        None => (Map::new(), [1])
      }
    }
    _ => (Map::new(), [1])
  }
}

///|
fn cp_to_string(cp : Int) -> String {
  if cp < 0 || cp > 0x10FFFF {
    return ""
  }
  Int::unsafe_to_char(cp).to_string()
}

///|
fn decode_win_ansi_byte(b : Int) -> String {
  let cp = match b {
    0x80 => 0x20AC
    0x82 => 0x201A
    0x83 => 0x0192
    0x84 => 0x201E
    0x85 => 0x2026
    0x86 => 0x2020
    0x87 => 0x2021
    0x88 => 0x02C6
    0x89 => 0x2030
    0x8A => 0x0160
    0x8B => 0x2039
    0x8C => 0x0152
    0x8E => 0x017D
    0x91 => 0x2018
    0x92 => 0x2019
    0x93 => 0x201C
    0x94 => 0x201D
    0x95 => 0x2022
    0x96 => 0x2013
    0x97 => 0x2014
    0x98 => 0x02DC
    0x99 => 0x2122
    0x9A => 0x0161
    0x9B => 0x203A
    0x9C => 0x0153
    0x9E => 0x017E
    0x9F => 0x0178
    _ => b
  }
  cp_to_string(cp)
}

///|
fn decode_mac_roman_byte(b : Int) -> String {
  let cp = match b {
    0x80 => 0x00C4
    0x81 => 0x00C5
    0x82 => 0x00C7
    0x83 => 0x00C9
    0x84 => 0x00D1
    0x85 => 0x00D6
    0x86 => 0x00DC
    0x87 => 0x00E1
    0x88 => 0x00E0
    0x89 => 0x00E2
    0x8A => 0x00E4
    0x8B => 0x00E3
    0x8C => 0x00E5
    0x8D => 0x00E7
    0x8E => 0x00E9
    0x8F => 0x00E8
    0x90 => 0x00EA
    0x91 => 0x00EB
    0x92 => 0x00ED
    0x93 => 0x00EC
    0x94 => 0x00EE
    0x95 => 0x00EF
    0x96 => 0x00F1
    0x97 => 0x00F3
    0x98 => 0x00F2
    0x99 => 0x00F4
    0x9A => 0x00F6
    0x9B => 0x00F5
    0x9C => 0x00FA
    0x9D => 0x00F9
    0x9E => 0x00FB
    0x9F => 0x00FC
    0xD0 => 0x2013
    0xD1 => 0x2014
    0xD2 => 0x201C
    0xD3 => 0x201D
    0xD4 => 0x2018
    0xD5 => 0x2019
    0xD9 => 0x2122
    0xDB => 0x203A
    0xDC => 0x0153
    0xDD => 0x2026
    _ => b
  }
  cp_to_string(cp)
}

///|
fn decode_simple_font_byte(b : Int, encoding : String?) -> String {
  match encoding {
    Some("WinAnsiEncoding") => decode_win_ansi_byte(b)
    Some("MacRomanEncoding") => decode_mac_roman_byte(b)
    _ => cp_to_string(b)
  }
}

///|
fn fallback_decode_bytes(bs : Bytes, font_ref : PdfFontRef) -> String {
  let mut out = ""
  let maybe_type0_identity = match (font_ref.subtype, font_ref.encoding) {
    (Some("Type0"), Some("Identity-H")) => true
    (Some("Type0"), Some("Identity-V")) => true
    _ => false
  }
  if maybe_type0_identity && bs.length() % 2 == 0 {
    let mut i = 0
    while i + 1 < bs.length() {
      let cp = bs[i].to_int() * 256 + bs[i + 1].to_int()
      out = out + cp_to_string(cp)
      i = i + 2
    }
    return out
  }

  for b in bs {
    out = out + decode_simple_font_byte(b.to_int(), font_ref.encoding)
  }
  out
}

///|
pub fn decode_text_operand_with_font(
  doc : PdfDocument,
  font_ref : PdfFontRef,
  operand : PdfContentOperand,
) -> String raise {
  let string_to_pdf_bytes = fn(s : String) -> Bytes {
    let out : Array[Byte] = []
    for ch in s.to_array() {
      let cp = ch.to_int()
      if cp <= 0xFF {
        out.push(cp.to_byte())
      } else {
        for b in @utf8.encode(ch.to_string()) {
          out.push(b)
        }
      }
    }
    Bytes::from_array(out)
  }

  let (cmap, code_widths) = load_tounicode(doc, font_ref)

  let decode_bytes = fn(bs : Bytes) -> String {
    if cmap.length() == 0 {
      return fallback_decode_bytes(bs, font_ref)
    }
    let mut out = ""
    let mut i = 0
    let n = bs.length()
    let maybe_type0_identity = match (font_ref.subtype, font_ref.encoding) {
      (Some("Type0"), Some("Identity-H")) => true
      (Some("Type0"), Some("Identity-V")) => true
      _ => false
    }
    while i < n {
      let mut matched = false
      for w in code_widths {
        if matched {
          continue
        }
        if w <= 0 || i + w > n {
          continue
        }
        let mut code = 0
        let mut j = 0
        while j < w {
          code = code * 256 + bs[i + j].to_int()
          j = j + 1
        }
        match cmap.get(code) {
          Some(ch) => {
            out = out + ch
            i = i + w
            matched = true
          }
          None => ()
        }
      }
      if !matched {
        if maybe_type0_identity && i + 1 < n {
          let cp = bs[i].to_int() * 256 + bs[i + 1].to_int()
          out = out + cp_to_string(cp)
          i = i + 2
        } else {
          out = out + decode_simple_font_byte(bs[i].to_int(), font_ref.encoding)
          i = i + 1
        }
      }
    }
    out
  }

  match operand {
    PdfContentOperand::String(s) => decode_bytes(string_to_pdf_bytes(s))
    PdfContentOperand::HexString(bs) => decode_bytes(bs)
    PdfContentOperand::Array(items) => {
      let mut out = ""
      for item in items {
        match item {
          PdfContentOperand::String(s) =>
            out = out + decode_bytes(string_to_pdf_bytes(s))
          PdfContentOperand::HexString(bs) => out = out + decode_bytes(bs)
          _ => ()
        }
      }
      out
    }
    _ => ""
  }
}
