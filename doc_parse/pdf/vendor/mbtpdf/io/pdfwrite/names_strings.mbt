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
fn make_pdf_name(ctx : PdfWrite, name : String) -> String {
  let normalized = match name.get_char(0) {
    Some('/') => name
    _ => {
      (ctx.logger)("warning: bad name |\{name}|\n")
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
      sb.write_char(b.to_byte().to_char())
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
      '\f' => sb.write_string("\\f")
      _ => sb.write_char(ch)
    }
  }
  sb.write_char(')')
  sb.to_string()
}

///|
/// Convert a PDF string to hex representation.
fn make_hex_pdf_string(value : String) -> String {
  let bytes = @pdfio.bytes_of_string(value)
  let sb = StringBuilder::new()
  sb.write_char('<')
  for b in bytes {
    sb.write_string(b.to_hex())
  }
  sb.write_char('>')
  sb.to_string()
}
