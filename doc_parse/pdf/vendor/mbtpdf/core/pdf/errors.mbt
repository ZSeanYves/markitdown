///|
/// Core error used across the PDF surface.
pub(all) suberror PdfError {
  Msg(String)
}

///|
/// PDF whitespace predicate.
pub fn is_whitespace(c : Char) -> Bool {
  let v = c.to_int()
  v == 0 || v == 9 || v == 10 || v == 12 || v == 13 || v == 32
}

///|
/// Build an error string which includes the input source and position.
pub fn input_pdferror(input : @pdfio.Input, message : String) -> String {
  "\{message} whilst reading file \{input.source} at position \{(input.pos_in)()}"
}
