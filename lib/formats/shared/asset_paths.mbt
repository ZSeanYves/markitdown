///|
pub fn text_markup_asset_output_path(
  family : String,
  source_path : String,
) -> String {
  let out = StringBuilder::new()
  for ch in source_path.replace_all(old="\\", new="/") {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '.' ||
      ch == '-' ||
      ch == '_' {
      out.write_char(ch)
    } else {
      let value = ch.to_int()
      out.write_char('_')
      out.write_char(asset_hex_digit((value >> 4) & 0xF))
      out.write_char(asset_hex_digit(value & 0xF))
    }
  }
  let encoded = out.to_string()
  let safe_name = if encoded == "" { "image.bin" } else { encoded }
  "assets/" + family + "-" + safe_name
}

///|
fn asset_hex_digit(value : Int) -> Char {
  if value < 10 {
    Int::unsafe_to_char('0'.to_int() + value)
  } else {
    Int::unsafe_to_char('a'.to_int() + value - 10)
  }
}
