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
    match pdf_native_gb2312_lookup_codepoint(lead, trail) {
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
  result.invalid_byte_count == 0 &&
  result.has_high_bytes &&
  result.decoded_two_byte_count > 0 &&
  result.decoded_cjk_count > 0
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
