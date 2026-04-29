///|
fn is_hex_digit(c : Char) -> Bool {
  c is ('0'..='9' | 'a'..='f' | 'A'..='F')
}

///|
fn hex_value(c : Char) -> Int? {
  match c {
    '0'..='9' => Some(c.to_int() - '0'.to_int())
    'a'..='f' => Some(10 + c.to_int() - 'a'.to_int())
    'A'..='F' => Some(10 + c.to_int() - 'A'.to_int())
    _ => None
  }
}

///|
let lex_syntax : PdfSyntax = PdfSyntax::new()

///|
/// Lex a name.
pub fn PdfSyntax::lex_name(
  _self : PdfSyntax,
  input : @pdfio.Input,
) -> Token raise {
  let bytes : @pdfio.MutableBytes = Array::new()
  let _ = (input.input_byte)()
  bytes.push('/'.to_int().to_byte())
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      done = true
    } else {
      let c = b.to_byte().to_char()
      if lex_syntax.is_whitespace_or_delimiter(c) {
        input.rewind()
        done = true
      } else if c == '#' {
        let h1 = (input.input_byte)()
        let h2 = (input.input_byte)()
        if h1 == @pdfio.no_more || h2 == @pdfio.no_more {
          let message = @pdf.input_pdferror(
            input, "lex_name: truncated hex escape",
          )
          raise @pdf.PdfError::Msg(message)
        }
        let c1 = h1.to_byte().to_char()
        let c2 = h2.to_byte().to_char()
        if !is_hex_digit(c1) || !is_hex_digit(c2) {
          let hex = String::from_array([c1, c2])
          let message = @pdf.input_pdferror(
            input,
            "lex_name: bad hex escape #\{hex}",
          )
          raise @pdf.PdfError::Msg(message)
        }
        match (hex_value(c1), hex_value(c2)) {
          (Some(hi), Some(lo)) => bytes.push(((hi << 4) + lo).to_byte())
          _ => {
            let hex = String::from_array([c1, c2])
            let message = @pdf.input_pdferror(
              input,
              "lex_name: bad hex escape #\{hex}",
            )
            raise @pdf.PdfError::Msg(message)
          }
        }
      } else {
        bytes.push(b.to_byte())
      }
    }
  }
  LexName(@pdfio.string_of_bytes(bytes))
}

///|
/// Lex a number.
pub fn PdfSyntax::lex_number(
  _self : PdfSyntax,
  input : @pdfio.Input,
) -> Token raise {
  let s = lex_syntax.getuntil_white_or_delimiter_string(input)
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
          _ => LexNone
        } noraise {
          f => LexReal(f)
        }
    } noraise {
      i => LexInt(i)
    }
  } else {
    try @strconv.parse_double(number) catch {
      _ => LexNone
    } noraise {
      f => LexReal(f)
    }
  }
}

///|
/// Lex a string.
pub fn PdfSyntax::lex_string(
  _self : PdfSyntax,
  input : @pdfio.Input,
) -> Token raise {
  let bytes : @pdfio.MutableBytes = Array::new()
  let mut paren = 1
  let first = (input.input_byte)()
  if first != '('.to_int() {
    raise @pdf.PdfError::Msg("lex_string: expected '('")
  }
  while paren > 0 {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      raise @pdf.PdfError::Msg("lex_string: unexpected EOF")
    }
    let c = b.to_byte().to_char()
    match c {
      '(' => {
        paren = paren + 1
        bytes.push(b.to_byte())
      }
      ')' => {
        paren = paren - 1
        if paren > 0 {
          bytes.push(b.to_byte())
        }
      }
      '\\' => {
        let esc = (input.input_byte)()
        if esc == @pdfio.no_more {
          raise @pdf.PdfError::Msg("lex_string: unexpected EOF")
        }
        match esc.to_byte().to_char() {
          'n' => bytes.push('\n'.to_int().to_byte())
          'r' => bytes.push('\r'.to_int().to_byte())
          't' => bytes.push('\t'.to_int().to_byte())
          'b' => bytes.push('\b'.to_int().to_byte())
          'f' => bytes.push('\f'.to_int().to_byte())
          '\r' => {
            let next = (input.input_byte)()
            if next != '\n'.to_int() {
              input.rewind()
            }
          }
          '\n' => ()
          digit if digit >= '0' && digit <= '7' => {
            let digits : Array[Char] = Array::new()
            digits.push(digit)
            let b2 = (input.input_byte)()
            if b2 != @pdfio.no_more {
              let c2 = b2.to_byte().to_char()
              if c2 >= '0' && c2 <= '7' {
                digits.push(c2)
                let b3 = (input.input_byte)()
                if b3 != @pdfio.no_more {
                  let c3 = b3.to_byte().to_char()
                  if c3 >= '0' && c3 <= '7' {
                    digits.push(c3)
                  } else {
                    input.rewind()
                  }
                }
              } else {
                input.rewind()
              }
            }
            let octal = digits.map(c => c.to_string()).join("")
            let mut value = 0
            for ch in octal {
              value = value * 8 + (ch.to_int() - '0'.to_int())
            }
            bytes.push(value.to_byte())
          }
          other => bytes.push(other.to_int().to_byte())
        }
      }
      _ => bytes.push(b.to_byte())
    }
  }
  LexString(@pdfio.string_of_bytes(bytes))
}

///|
/// Lex a hex string.
pub fn PdfSyntax::lex_hexstring(
  _self : PdfSyntax,
  input : @pdfio.Input,
) -> Token raise {
  let _ = (input.input_byte)()
  let bytes : @pdfio.MutableBytes = Array::new()
  let mut pending : Int? = None
  let mut done = false
  while !done {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      done = true
    } else {
      let c = b.to_byte().to_char()
      if c == '>' {
        done = true
      } else if is_whitespace(c) {
        ()
      } else {
        match hex_value(c) {
          Some(v) =>
            match pending {
              None => pending = Some(v)
              Some(hi) => {
                bytes.push(((hi << 4) + v).to_byte())
                pending = None
              }
            }
          None =>
            raise @pdf.PdfError::Msg(
              @pdf.input_pdferror(input, "lex_hexstring"),
            )
        }
      }
    }
  }
  match pending {
    None => ()
    Some(hi) => bytes.push((hi << 4).to_byte())
  }
  LexString(@pdfio.string_of_bytes(bytes))
}

///|
/// Lex a comment.
pub fn PdfSyntax::lex_comment(
  _self : PdfSyntax,
  input : @pdfio.Input,
) -> Token raise {
  lex_syntax.ignoreuntil(false, is_newline, input)
  LexComment("")
}

///|
fn ignoreuntilwhite(input : @pdfio.Input) -> Unit raise {
  lex_syntax.ignoreuntil(true, is_whitespace, input)
}

///|
pub fn PdfSyntax::read_chunk(
  _self : PdfSyntax,
  count : Int,
  input : @pdfio.Input,
) -> String raise {
  let pos = (input.pos_in)()
  let sb = StringBuilder::new()
  let mut i = 0
  while i < count {
    match (input.input_char)() {
      Some(ch) => sb.write_char(ch)
      None => {
        (input.seek_in)(pos)
        fail("read_chunk")
      }
    }
    i = i + 1
  }
  (input.seek_in)(pos)
  sb.to_string()
}

///|
fn is_malformed(input : @pdfio.Input) -> Bool {
  try {
    if lex_syntax.read_chunk(9, input) == "endstream" {
      false
    } else if lex_syntax.read_chunk(10, input) == "\nendstream" ||
      lex_syntax.read_chunk(10, input) == "\rendstream" {
      false
    } else if lex_syntax.read_chunk(11, input) == "\r\nendstream" {
      false
    } else {
      true
    }
  } catch {
    _ => true
  }
}

///|
fn skip_stream_beginning(input : @pdfio.Input) -> Unit raise {
  ignoreuntilwhite(input)
  lex_syntax.ignoreuntil(
    true,
    c => {
      let v = c.to_int()
      v != 32 && v != 0 && v != 12 && v != 9
    },
    input,
  )
  let first = (input.input_byte)()
  if first == '\r'.to_int() {
    let second = (input.input_byte)()
    if second != '\n'.to_int() {
      input.rewind()
    }
  } else if first == '\n'.to_int() {
    ()
  } else {
    input.rewind()
  }
}

///|
fn find_endstream(input : @pdfio.Input) -> Int {
  fn match_chunk(s : String, input : @pdfio.Input) -> Bool {
    let pos = (input.pos_in)()
    let ok = try lex_syntax.read_chunk(s.length(), input) == s catch {
      _ => false
    }
    (input.seek_in)(pos)
    ok
  }

  let mut done = false
  let mut found_pos = (input.pos_in)()
  while !done {
    let pos = (input.pos_in)()
    if match_chunk("endstream", input) ||
      match_chunk("\nendstream", input) ||
      match_chunk("\r\nendstream", input) ||
      match_chunk("\rendstream", input) {
      done = true
      found_pos = pos
    } else if pos == input.in_channel_length {
      done = true
      found_pos = pos
    } else {
      input.nudge()
    }
  }
  found_pos
}

///|
pub fn PdfSyntax::lex_keyword(
  _self : PdfSyntax,
  input : @pdfio.Input,
) -> Token raise {
  let kw = lex_syntax.getuntil_white_or_delimiter_string(input)
  match kw {
    "obj" => LexObj
    "endobj" => LexEndObj
    "R" => LexR
    "null" => LexNull
    "endstream" => LexEndStream
    "true" => LexBool(true)
    "false" => LexBool(false)
    _ =>
      if kw.has_prefix("endobj") && kw.length() > 6 {
        let extra = kw.length() - 6
        let mut i = 0
        while i < extra {
          input.rewind()
          i = i + 1
        }
        LexEndObj
      } else {
        LexNone
      }
  }
}

///|
fn lex_malformed_stream_data(input : @pdfio.Input) -> Token raise {
  skip_stream_beginning(input)
  let curr = (input.pos_in)()
  let pos = find_endstream(input)
  (input.seek_in)(curr)
  let len = pos - curr
  let bytes = @pdfio.mkbytes(len)
  for i in 0..<len {
    bytes[i] = (input.input_byte)().to_byte()
  }
  LexStream(@pdf.Stream::Got(bytes))
}

///|
pub fn PdfSyntax::lex_stream_data(
  _self : PdfSyntax,
  input : @pdfio.Input,
  length : Int,
  read_data : Bool,
) -> Token raise {
  let original_pos = (input.pos_in)()
  skip_stream_beginning(input)
  let pos = (input.pos_in)()
  if read_data {
    let bytes = @pdfio.mkbytes(length)
    if length > 0 {
      input.setinit(bytes, 0, length)
    }
    (input.seek_in)(pos + length)
    if is_malformed(input) {
      (input.seek_in)(original_pos)
      lex_malformed_stream_data(input)
    } else {
      (input.seek_in)(pos + length)
      LexStream(@pdf.Stream::Got(bytes))
    }
  } else {
    (input.seek_in)(pos + length)
    if is_malformed(input) {
      (input.seek_in)(original_pos)
      lex_malformed_stream_data(input)
    } else {
      let toget : @pdf.ToGet = {
        input,
        position: pos,
        length,
        crypt: @pdf.ToGetCrypt::NoChange,
      }
      LexStream(@pdf.Stream::ToGet(toget))
    }
  }
}

///|
fn reverse_tokens(tokens : Array[Token]) -> Array[Token] {
  let out = Array::new(capacity=tokens.length())
  for t in tokens[:].rev_iter() {
    out.push(t)
  }
  out
}

///|
fn take_dict_lexemes(previous_lexemes : Array[Token]) -> Array[Token] {
  let collected = Array::new()
  for t in previous_lexemes[:].rev_iter() {
    if t is LexObj {
      break
    }
    collected.push(t)
  }
  reverse_tokens(collected)
}

///|
pub fn PdfSyntax::lex_stream(
  _self : PdfSyntax,
  input : @pdfio.Input,
  previous_lexemes : Array[Token],
  lexobj : (Int) -> Array[Token] raise,
  read_stream_data : Bool,
) -> Token raise {
  fn fail_stream() -> Token raise {
    let message = @pdf.input_pdferror(input, "Failure lexing stream dict")
    raise @pdf.PdfError::Msg(message)
  }

  let dictlexemes = take_dict_lexemes(previous_lexemes)
  let (_, parsed) = lex_syntax.parse(dictlexemes)
  match (parsed : PdfObject) {
    Dictionary(_) => {
      let pos = (input.pos_in)()
      fn findlength(value : PdfObject) -> Int? raise {
        match value {
          Integer(l) => Some(l)
          Indirect(k) => {
            let (_, obj) = lex_syntax.parse(lexobj(k))
            findlength(obj)
          }
          _ => None
        }
      }

      match @pdf.Pdf::empty().lookup_direct("/Length", parsed) {
        None => lex_malformed_stream_data(input)
        Some(v) =>
          match findlength(v) {
            Some(l) => lex_syntax.lex_stream_data(input, l, read_stream_data)
            None => {
              (input.seek_in)(pos)
              lex_malformed_stream_data(input)
            }
          }
      }
    }
    _ => fail_stream()
  }
}

///|
pub fn PdfSyntax::lex_next(
  _self : PdfSyntax,
  dict_level : Ref[Int],
  array_level : Ref[Int],
  end_on_stream : Bool,
  input : @pdfio.Input,
  previous_lexemes : Array[Token],
  read_stream_data : Bool,
  lexobj : (Int) -> Array[Token] raise,
) -> Token {
  try {
    lex_syntax.dropwhite(input)
    let raw = (input.input_byte)()
    if raw == @pdfio.no_more {
      return StopLexing
    }
    let ch = raw.to_byte().to_char()
    input.rewind()
    match ch {
      '%' => lex_syntax.lex_comment(input)
      '/' => lex_syntax.lex_name(input)
      '[' => {
        input.nudge()
        array_level.val = array_level.val + 1
        LexLeftSquare
      }
      ']' => {
        input.nudge()
        array_level.val = array_level.val - 1
        LexRightSquare
      }
      '(' => lex_syntax.lex_string(input)
      '<' => {
        input.nudge()
        match input.peek_byte() {
          b2 if b2 == '<'.to_int() => {
            input.nudge()
            dict_level.val = dict_level.val + 1
            LexLeftDict
          }
          _ => {
            input.rewind()
            lex_syntax.lex_hexstring(input)
          }
        }
      }
      '>' => {
        input.nudge()
        match input.peek_byte() {
          b2 if b2 == '>'.to_int() => {
            input.nudge()
            dict_level.val = dict_level.val - 1
            LexRightDict
          }
          _ => LexNone
        }
      }
      'R' => {
        input.nudge()
        LexR
      }
      's' => {
        let _ = (input.input_byte)()
        let _ = (input.input_byte)()
        let third = (input.input_byte)()
        input.rewind()
        input.rewind()
        input.rewind()
        if third == @pdfio.no_more {
          StopLexing
        } else {
          let c3 = third.to_byte().to_char()
          if c3 == 'a' {
            StopLexing
          } else if end_on_stream {
            StopLexing
          } else {
            lex_syntax.lex_stream(
              input, previous_lexemes, lexobj, read_stream_data,
            )
          }
        }
      }
      'I' => StopLexing
      c if (c >= '0' && c <= '9') || c == '-' || c == '+' || c == '.' =>
        lex_syntax.lex_number(input)
      c if c >= 'a' && c <= 'z' => lex_syntax.lex_keyword(input)
      _ => LexNone
    }
  } catch {
    err => {
      @pdfe.log("Recovering from lex error: \{err}\n")
      StopLexing
    }
  }
}

///|
/// Lex a dictionary. If minus_one is true, assume the opening << was consumed.
pub fn PdfSyntax::lex_dictionary(
  _self : PdfSyntax,
  minus_one : Bool,
  input : @pdfio.Input,
) -> Array[Token] raise {
  let tokens = Array::new()
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let mut done = false
  while !done {
    let t = lex_syntax.lex_next(
      dict_level,
      array_level,
      false,
      input,
      tokens,
      false,
      _ => [],
    )
    tokens.push(t)
    match (t : Token) {
      LexRightDict =>
        if dict_level.val == (if minus_one { -1 } else { 0 }) &&
          array_level.val == 0 {
          done = true
        }
      StopLexing => done = true
      LexNone => {
        let message = @pdf.input_pdferror(input, "Could not read dictionary")
        raise @pdf.PdfError::Msg(message)
      }
      _ => ()
    }
  }
  tokens
}
