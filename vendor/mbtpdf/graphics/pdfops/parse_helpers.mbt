///|
fn split_lexemes(lexemes : Array[Lexeme], start : Int) -> (Array[Lexeme], Int) {
  let section : Array[Lexeme] = Array::new()
  let mut i = start
  let len = lexemes.length()
  while i < len {
    let lexeme = lexemes[i]
    section.push(lexeme)
    match lexeme {
      Lexeme::Op(_) | Lexeme::LexInlineImage(_) => return (section, i + 1)
      _ => ()
    }
    i = i + 1
  }
  (section, i)
}

///|
fn lexeme_real(lexeme : Lexeme) -> Double? {
  match lexeme {
    Obj(LexReal(value)) => Some(value)
    Obj(LexInt(value)) => Some(Double::from_int(value))
    _ => None
  }
}

///|
fn lexeme_int(lexeme : Lexeme) -> Int? {
  match lexeme {
    Obj(LexInt(value)) => Some(value)
    Obj(LexReal(value)) => Some(value.to_int())
    _ => None
  }
}

///|
fn lexeme_name(lexeme : Lexeme) -> String? {
  match lexeme {
    Obj(LexName(name)) => Some(name)
    _ => None
  }
}

///|
fn lexeme_string(lexeme : Lexeme) -> String? {
  match lexeme {
    Obj(LexString(text)) => Some(text)
    _ => None
  }
}

///|
fn lexeme_pdfobj(lexeme : Lexeme) -> @pdf.PdfObject? raise {
  match lexeme {
    Lexeme::PdfObj(obj) => Some(obj)
    Lexeme::Obj(token) => Some(PdfSyntax::new().parse([token]).1)
    _ => None
  }
}

///|
fn reals_of_lexemes(
  lexemes : ArrayView[Lexeme],
  errtext : String,
) -> Array[Double] {
  let out : Array[Double] = Array::new()
  for lexeme in lexemes {
    match lexeme_real(lexeme) {
      Some(value) => out.push(value)
      None => {
        @pdfe.log(errtext + "\n")
        return [0.0, 0.0, 0.0]
      }
    }
  }
  out
}

///|
fn parse_dash_op(section : Array[Lexeme]) -> Op raise {
  if section.length() < 4 {
    raise @pdf.PdfError::Msg("malformed 'd' op")
  }
  let op = section[section.length() - 1]
  if op is Lexeme::Op("d") {
    let phase = lexeme_real(section[section.length() - 2])
    if phase is None {
      raise @pdf.PdfError::Msg("malformed 'd' op")
    }
    let right = section[section.length() - 3]
    if right is Obj(LexRightSquare) {
      let mut left_index = -1
      for i in 0..<(section.length() - 3) {
        match section[i] {
          Obj(LexLeftSquare) => left_index = i
          _ => ()
        }
      }
      if left_index < 0 {
        raise @pdf.PdfError::Msg("malformed 'd' op")
      }
      let values : Array[Double] = Array::new()
      for idx in (left_index + 1)..<(section.length() - 3) {
        match lexeme_real(section[idx]) {
          Some(value) => values.push(value)
          None => raise @pdf.PdfError::Msg("malformed 'd' op")
        }
      }
      match phase {
        Some(value) => return Op::Opd(values, value)
        None => raise @pdf.PdfError::Msg("malformed 'd' op")
      }
    }
  }
  raise @pdf.PdfError::Msg("malformed 'd' op")
}

///|
fn parse_tj_op(section : Array[Lexeme]) -> Op raise {
  let op = section[section.length() - 1]
  if op is Lexeme::Op("TJ") {
    if section.length() < 3 {
      raise @pdf.PdfError::Msg("malformed TJ op")
    }
    let right = section[section.length() - 2]
    if right is Obj(LexRightSquare) {
      let mut left_index = -1
      for i in 0..<(section.length() - 2) {
        match section[i] {
          Obj(LexLeftSquare) => left_index = i
          _ => ()
        }
      }
      if left_index < 0 {
        raise @pdf.PdfError::Msg("malformed TJ op")
      }
      let elements : Array[@pdf.PdfObject] = Array::new()
      for idx in (left_index + 1)..<(section.length() - 2) {
        match section[idx] {
          Obj(LexReal(value)) => elements.push(PdfObject::Real(value))
          Obj(LexInt(value)) =>
            elements.push(PdfObject::Real(Double::from_int(value)))
          Obj(LexString(text)) => elements.push(PdfObject::String(text))
          _ => @pdfe.log("Warning: malformed TJ element; skipping\n")
        }
      }
      return Op::OpTJ(PdfObject::Array(elements))
    }
  }
  raise @pdf.PdfError::Msg("malformed TJ op")
}
