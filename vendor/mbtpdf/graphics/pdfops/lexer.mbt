///|
fn is_delimiter_char(chr : Char) -> Bool {
  match chr {
    '(' | ')' | '<' | '>' | '[' | ']' | '{' | '}' | '/' | '%' => true
    _ => false
  }
}

///|
fn string_first_char(value : String) -> Char? {
  value.get_char(0)
}

///|
fn string_last_char(value : String) -> Char? {
  let length = value.length()
  if length <= 0 {
    None
  } else {
    value.get_char(length - 1)
  }
}

///|
fn strip_dict_markers(value : String) -> String {
  if value.length() < 4 {
    value
  } else {
    try value[2:value.length() - 2] catch {
      _ => value
    } noraise {
      view => view.to_string()
    }
  }
}

///|
fn lex_name(input : @pdfio.Input) -> Lexeme raise {
  input.nudge()
  Lexeme::Obj(
    Token::LexName(
      "/" + PdfSyntax::new().getuntil_white_or_delimiter_string(input),
    ),
  )
}

///|
fn nocontent(input : @pdfio.Input) -> Unit raise {
  @pdfe.log("Failed to understand content on page\n")
  if @pdfe.read_debug.val {
    @pdfio.debug_next_n_chars(20, input)
  }
  raise CouldntHandleContent
}

///|
fn lex_number(input : @pdfio.Input) -> Lexeme raise {
  match (PdfSyntax::new().lex_number(input) : Token) {
    LexReal(value) => Obj(Token::LexReal(value))
    LexInt(value) => Obj(Token::LexReal(Double::from_int(value)))
    _ => {
      nocontent(input)
      Obj(Token::LexReal(0.0))
    }
  }
}

///|
fn get_dictionary(input : @pdfio.Input) -> Lexeme raise {
  Lexeme::PdfObj(
    PdfSyntax::new().parse(PdfSyntax::new().lex_dictionary(false, input)).1,
  )
}

///|
fn lex_string(input : @pdfio.Input) -> Lexeme raise {
  match (PdfSyntax::new().lex_string(input) : Token) {
    LexString(text) => Obj(Token::LexString(text))
    _ => {
      nocontent(input)
      Obj(Token::LexString(""))
    }
  }
}

///|
fn lex_hexstring(input : @pdfio.Input) -> Lexeme raise {
  match (PdfSyntax::new().lex_hexstring(input) : Token) {
    LexString(text) => Obj(Token::LexString(text))
    _ => {
      nocontent(input)
      Obj(Token::LexString(""))
    }
  }
}

///|
fn lex_next(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  input : @pdfio.Input,
) -> Lexeme raise {
  try {
    PdfSyntax::new().dropwhite(input)
    let next = input.peek_byte()
    if next == @pdfio.no_more {
      raise LexingEnd
    }
    let chr_opt = next.to_char()
    match chr_opt {
      Some('/') => lex_name(input)
      Some('+' | '-' | '.' | '0'..='9') => lex_number(input)
      Some('A'..='Z' | 'a'..='z') => lex_keyword(pdf, resources, input)
      Some('\'') | Some('\"') => lex_keyword(pdf, resources, input)
      Some('(') => lex_string(input)
      Some('[') => {
        input.nudge()
        Obj(Token::LexLeftSquare)
      }
      Some(']') => {
        input.nudge()
        Obj(Token::LexRightSquare)
      }
      Some('<') => {
        input.nudge()
        let next_char = input.peek_char()
        input.rewind()
        match next_char {
          Some('<') => get_dictionary(input)
          _ => lex_hexstring(input)
        }
      }
      Some('%') => {
        ignore(PdfSyntax::new().lex_comment(input))
        LexComment
      }
      _ => raise @pdf.PdfError::Msg("Lexing failure in content stream")
    }
  } catch {
    @pdf.PdfError::Msg(message) =>
      raise @pdf.PdfError::Msg("Pdfpages.lex_next => \{message}")
    CouldntHandleContent => raise @pdf.PdfError::Msg("Malformed page content")
    err => raise err
  }
}

///|
fn lex_stream(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  input : @pdfio.Input,
) -> Array[Lexeme] raise {
  let lexemes : Array[Lexeme] = Array::new()
  try {
    while true {
      let lexeme = lex_next(pdf, resources, input)
      match lexeme {
        Lexeme::LexComment => ()
        _ => lexemes.push(lexeme)
      }
    }
    lexemes
  } catch {
    LexingEnd => lexemes
    err => raise err
  }
}

///|
/// Parse a single byte stream to an operator list.
pub fn Op::parse_single_stream(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  stream : @pdfio.MutableBytes,
) -> Array[Op] raise {
  let input = @pdfio.Input::of_bytes(stream)
  let lexemes = lex_stream(pdf, resources, input)
  parse_lexemes({ val: 0 }, lexemes)
}
