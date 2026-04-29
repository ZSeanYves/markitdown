///|
/// Basic token stream for PDF parsing.
pub(all) enum Token {
  LexNull
  LexBool(Bool)
  LexInt(Int)
  LexReal(Double)
  LexString(String)
  LexName(String)
  LexLeftSquare
  LexRightSquare
  LexLeftDict
  LexRightDict
  LexStream(@pdf.Stream)
  LexEndStream
  LexObj
  LexEndObj
  LexR
  LexComment(String)
  StopLexing
  LexNone
}

///|
pub struct PdfGenLex {
  unit : Unit
}

///|
pub fn PdfGenLex::new() -> PdfGenLex {
  { unit: () }
}

///|
/// String representation of a token (debug only).
pub fn PdfGenLex::string_of_token(_self : PdfGenLex, t : Token) -> String {
  match t {
    LexInt(i) => "Int \{i}"
    LexReal(r) => "Float \{r}"
    LexString(s) => "String \{s}"
    LexName(n) => "Ident \{n}"
    LexNull => "Nothing"
    _ => "GenLexNone"
  }
}

///|
/// String representation of a list of tokens (debug only).
pub fn PdfGenLex::string_of_tokens(
  self : PdfGenLex,
  tokens : Array[Token],
) -> String {
  let parts = tokens.map(token => self.string_of_token(token))
  if parts.length() == 0 {
    ""
  } else {
    "\n " + parts.join("\n ")
  }
}

///|
fn is_delimiter_byte(b : Int) -> Bool {
  match b {
    '(' | ')' | '<' | '>' | '[' | ']' | '{' | '}' | '%' | '/' => true
    _ => false
  }
}

///|
fn is_whitespace_byte(b : Int) -> Bool {
  match b {
    0 | 9 | 10 | 12 | 13 | 32 => true
    _ => false
  }
}

///|
fn is_whitespace_or_delimiter_byte(b : Int) -> Bool {
  is_whitespace_byte(b) || is_delimiter_byte(b)
}

///|
fn dropwhite(input : @pdfio.Input) -> Unit {
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      done = true
    } else if is_whitespace_byte(b) {
      ()
    } else {
      input.rewind()
      done = true
    }
  }
}

///|
fn getuntil(input : @pdfio.Input) -> String {
  let bytes : Array[Byte] = Array::new()
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      done = true
    } else if is_whitespace_or_delimiter_byte(b) {
      input.rewind()
      done = true
    } else {
      bytes.push(b.to_byte())
    }
  }
  @pdfio.string_of_bytes(bytes)
}

///|
fn get_string(input : @pdfio.Input) -> String {
  let bytes : Array[Byte] = Array::new()
  let mut done = false
  let _ = (input.input_byte)()
  bytes.push('"'.to_int().to_byte())
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      done = true
    } else if b == '\\'.to_int() {
      let next = (input.input_byte)()
      if next == @pdfio.no_more {
        done = true
      } else if next == '"'.to_int() {
        bytes.push('"'.to_int().to_byte())
      } else {
        bytes.push('\\'.to_int().to_byte())
        bytes.push(next.to_byte())
      }
    } else if b == '"'.to_int() {
      bytes.push(b.to_byte())
      done = true
    } else {
      bytes.push(b.to_byte())
    }
  }
  @pdfio.string_of_bytes(bytes)
}

///|
fn get_section(input : @pdfio.Input) -> String {
  match input.peek_byte() {
    b if b == @pdfio.no_more => ""
    _ => {
      dropwhite(input)
      match input.peek_byte() {
        b if b == @pdfio.no_more => ""
        '"' => get_string(input)
        b if is_delimiter_byte(b) => {
          input.nudge()
          b.to_byte().to_char().to_string()
        }
        _ => getuntil(input)
      }
    }
  }
}

///|
fn lex_item(s : String) -> Token {
  let len = s.length()
  if len == 0 {
    LexNull
  } else {
    match s.get_char(0) {
      Some(c) if c.is_ascii_alphabetic() => LexName(s)
      Some('"') if len >= 2 => {
        let inner = try s[1:len - 1] catch {
          _ => ""
        } noraise {
          view => view.to_string()
        }
        LexString(inner)
      }
      _ => {
        let mut number = s
        if number.length() > 1 {
          match (number.get_char(0), number.get_char(1)) {
            (Some('-'), Some('-')) =>
              number = try number[1:] catch {
                _ => number
              } noraise {
                view => view.to_string()
              }
            _ => ()
          }
        }
        let has_decimal = number.contains(".") ||
          number.contains("e") ||
          number.contains("E")
        if !has_decimal {
          try @strconv.parse_int(number) catch {
            _ =>
              try @strconv.parse_double(number) catch {
                _ => LexName(s)
              } noraise {
                f => LexReal(f)
              }
          } noraise {
            i => LexInt(i)
          }
        } else {
          try @strconv.parse_double(number) catch {
            _ => LexName(s)
          } noraise {
            f => LexReal(f)
          }
        }
      }
    }
  }
}

///|
/// Lex a single token from input.
pub fn PdfGenLex::lex_single(self : PdfGenLex, input : @pdfio.Input) -> Token {
  let _ = self
  lex_item(get_section(input))
}

///|
/// Lex all tokens from input.
pub fn PdfGenLex::lex(self : PdfGenLex, input : @pdfio.Input) -> Array[Token] {
  let out = Array::new()
  let mut done = false
  while !done {
    let t = self.lex_single(input)
    match t {
      LexNull => done = true
      _ => out.push(t)
    }
  }
  out
}

///|
/// Lex all tokens from a string.
pub fn PdfGenLex::lex_string(self : PdfGenLex, s : String) -> Array[Token] {
  let input = @pdfio.Input::of_string(s)
  self.lex(input)
}
