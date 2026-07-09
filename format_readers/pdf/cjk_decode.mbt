///|
pub(all) enum PdfRawCjkEncodingKind {
  Gb2312
  EucJp
  ShiftJis
} derive(Eq)

///|
pub(all) struct PdfRawCjkDecodeResult {
  text : String
  decoded_cjk_count : Int
  decoded_two_byte_count : Int
  invalid_byte_count : Int
  has_high_bytes : Bool
}

///|
pub fn pdf_decode_gb2312_first_bytes(
  bytes : Array[Int],
) -> PdfRawCjkDecodeResult {
  pdf_decode_raw_cjk_bytes(bytes, PdfRawCjkEncodingKind::Gb2312)
}

///|
pub fn pdf_decode_raw_cjk_bytes(
  bytes : Array[Int],
  encoding_kind : PdfRawCjkEncodingKind,
) -> PdfRawCjkDecodeResult {
  let codepoints : Array[Int] = []
  let mut decoded_cjk_count = 0
  let mut decoded_two_byte_count = 0
  let mut invalid_byte_count = 0
  let mut has_high_bytes = false
  let mut index = 0
  while index < bytes.length() {
    let byte = bytes[index]
    if byte >= 0 && byte <= 0x7F {
      if pdf_raw_cjk_is_safe_ascii_byte(byte) {
        codepoints.push(byte)
      } else {
        invalid_byte_count += 1
      }
      index += 1
      continue
    }
    has_high_bytes = true
    if index + 1 >= bytes.length() {
      invalid_byte_count += 1
      break
    }
    let lead = byte
    let trail = bytes[index + 1]
    match pdf_raw_cjk_lookup_codepoint(encoding_kind, lead, trail) {
      Some(codepoint) => {
        codepoints.push(codepoint)
        decoded_two_byte_count += 1
        if pdf_raw_cjk_is_cjk_signal_codepoint(codepoint) {
          decoded_cjk_count += 1
        }
      }
      None => invalid_byte_count += 2
    }
    index += 2
  }
  {
    text: pdf_raw_cjk_string_from_codepoints(codepoints),
    decoded_cjk_count,
    decoded_two_byte_count,
    invalid_byte_count,
    has_high_bytes,
  }
}

///|
pub fn pdf_raw_cjk_decode_result_is_confident_gb2312(
  result : PdfRawCjkDecodeResult,
) -> Bool {
  pdf_raw_cjk_decode_result_is_confident(result)
}

///|
pub fn pdf_raw_cjk_decode_result_is_confident(
  result : PdfRawCjkDecodeResult,
) -> Bool {
  result.invalid_byte_count == 0 &&
  result.has_high_bytes &&
  result.decoded_two_byte_count > 0 &&
  result.decoded_cjk_count > 0
}

///|
pub fn pdf_raw_cjk_bytes_need_decode(
  bytes : Array[Int],
  encoding_kind : PdfRawCjkEncodingKind,
) -> Bool {
  let mut index = 0
  let mut saw_pair = false
  while index < bytes.length() {
    let byte = bytes[index]
    if byte >= 0 && byte <= 0x7F {
      index += 1
      continue
    }
    if index + 1 >= bytes.length() {
      return false
    }
    if pdf_raw_cjk_lookup_codepoint(encoding_kind, byte, bytes[index + 1])
      is Some(_) {
      saw_pair = true
      index += 2
    } else {
      return false
    }
  }
  saw_pair
}

///|
fn pdf_raw_cjk_lookup_codepoint(
  encoding_kind : PdfRawCjkEncodingKind,
  lead : Int,
  trail : Int,
) -> Int? {
  match encoding_kind {
    PdfRawCjkEncodingKind::Gb2312 =>
      pdf_native_gb2312_lookup_codepoint(lead, trail)
    PdfRawCjkEncodingKind::EucJp =>
      pdf_native_euc_jp_lookup_codepoint(lead, trail)
    PdfRawCjkEncodingKind::ShiftJis =>
      pdf_native_shift_jis_lookup_codepoint(lead, trail)
  }
}

///|
fn pdf_raw_cjk_is_safe_ascii_byte(byte : Int) -> Bool {
  byte == '\t'.to_int() ||
  byte == '\n'.to_int() ||
  byte == '\r'.to_int() ||
  (byte >= 0x20 && byte <= 0x7E)
}

///|
fn pdf_raw_cjk_is_cjk_signal_codepoint(codepoint : Int) -> Bool {
  (codepoint >= 0x4E00 && codepoint <= 0x9FFF) ||
  (codepoint >= 0x3400 && codepoint <= 0x4DBF) ||
  (codepoint >= 0x3040 && codepoint <= 0x30FF) ||
  (codepoint >= 0x31F0 && codepoint <= 0x31FF) ||
  (codepoint >= 0xAC00 && codepoint <= 0xD7AF) ||
  (codepoint >= 0xF900 && codepoint <= 0xFAFF)
}

///|
fn pdf_raw_cjk_string_from_codepoints(codepoints : Array[Int]) -> String {
  let chars : Array[Char] = []
  for codepoint in codepoints {
    chars.push(Int::unsafe_to_char(codepoint))
  }
  String::from_array(chars)
}

///|
fn pdf_native_euc_jp_lookup_codepoint(lead : Int, trail : Int) -> Int? {
  match lead {
    0xA1 => pdf_native_euc_jp_row_a1(trail)
    0xA3 =>
      if trail >= 0xB0 && trail <= 0xB9 {
        Some(0xFF10 + (trail - 0xB0))
      } else if trail >= 0xC1 && trail <= 0xDA {
        Some(0xFF21 + (trail - 0xC1))
      } else if trail >= 0xE1 && trail <= 0xFA {
        Some(0xFF41 + (trail - 0xE1))
      } else {
        None
      }
    0xA4 =>
      if trail >= 0xA1 && trail <= 0xF3 {
        Some(0x3041 + (trail - 0xA1))
      } else {
        None
      }
    0xA5 =>
      if trail >= 0xA1 && trail <= 0xF6 {
        Some(0x30A1 + (trail - 0xA1))
      } else {
        None
      }
    _ => None
  }
}

///|
fn pdf_native_shift_jis_lookup_codepoint(lead : Int, trail : Int) -> Int? {
  match lead {
    0x81 => pdf_native_shift_jis_row_81(trail)
    0x82 =>
      if trail >= 0x4F && trail <= 0x58 {
        Some(0xFF10 + (trail - 0x4F))
      } else if trail >= 0x60 && trail <= 0x79 {
        Some(0xFF21 + (trail - 0x60))
      } else if trail >= 0x81 && trail <= 0x9A {
        Some(0xFF41 + (trail - 0x81))
      } else if trail >= 0x9F && trail <= 0xF1 {
        Some(0x3041 + (trail - 0x9F))
      } else {
        None
      }
    0x83 =>
      if trail >= 0x40 && trail <= 0x7E {
        Some(0x30A1 + (trail - 0x40))
      } else if trail >= 0x80 && trail <= 0x96 {
        Some(0x30C1 + (trail - 0x80))
      } else {
        None
      }
    _ => None
  }
}

///|
fn pdf_native_euc_jp_row_a1(trail : Int) -> Int? {
  match trail {
    0xA1 => Some(0x3000)
    0xA2 => Some(0x3001)
    0xA3 => Some(0x3002)
    0xA4 => Some(0xFF0C)
    0xA5 => Some(0xFF0E)
    0xA6 => Some(0x30FB)
    0xA7 => Some(0xFF1A)
    0xA8 => Some(0xFF1B)
    0xA9 => Some(0xFF1F)
    0xAA => Some(0xFF01)
    0xAB => Some(0x309B)
    0xAC => Some(0x309C)
    0xAD => Some(0x00B4)
    0xAE => Some(0xFF40)
    0xAF => Some(0x00A8)
    0xB0 => Some(0xFF3E)
    0xB1 => Some(0xFFE3)
    0xB2 => Some(0xFF3F)
    0xB3 => Some(0x30FD)
    0xB4 => Some(0x30FE)
    0xB5 => Some(0x309D)
    0xB6 => Some(0x309E)
    0xB7 => Some(0x3003)
    0xB8 => Some(0x4EDD)
    0xB9 => Some(0x3005)
    0xBA => Some(0x3006)
    0xBB => Some(0x3007)
    0xBC => Some(0x30FC)
    _ => None
  }
}

///|
fn pdf_native_shift_jis_row_81(trail : Int) -> Int? {
  match trail {
    0x40 => Some(0x3000)
    0x41 => Some(0x3001)
    0x42 => Some(0x3002)
    0x43 => Some(0xFF0C)
    0x44 => Some(0xFF0E)
    0x45 => Some(0x30FB)
    0x46 => Some(0xFF1A)
    0x47 => Some(0xFF1B)
    0x48 => Some(0xFF1F)
    0x49 => Some(0xFF01)
    0x4A => Some(0x309B)
    0x4B => Some(0x309C)
    0x4C => Some(0x00B4)
    0x4D => Some(0xFF40)
    0x4E => Some(0x00A8)
    0x4F => Some(0xFF3E)
    0x50 => Some(0xFFE3)
    0x51 => Some(0xFF3F)
    0x52 => Some(0x30FD)
    0x53 => Some(0x30FE)
    0x54 => Some(0x309D)
    0x55 => Some(0x309E)
    0x56 => Some(0x3003)
    0x57 => Some(0x4EDD)
    0x58 => Some(0x3005)
    0x59 => Some(0x3006)
    0x5A => Some(0x3007)
    0x5B => Some(0x30FC)
    _ => None
  }
}
