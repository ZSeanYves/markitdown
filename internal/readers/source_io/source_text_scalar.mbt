///|
/// Read one Unicode scalar at a UTF16 offset in a validated decoded chunk.
/// The returned offset is also UTF16; it never points inside a surrogate pair.
pub fn source_text_scalar_at(
  text : String,
  offset : Int32,
) -> Result[(Char, Int32), String] {
  match text.get_char(offset) {
    Some(ch) => {
      let width = if ch.to_int() > 0xFFFF { 2 } else { 1 }
      Ok((ch, offset + width))
    }
    None => Err("invalid Unicode scalar boundary in decoded source text")
  }
}
