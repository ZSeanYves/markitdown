///|
priv enum ParseItem {
  Parsed(PdfObject)
  Lexeme(Token)
}

///|
type PdfObject = @pdf.PdfObject

///|
type Token = @pdfgenlex.Token

///|
fn parse_R(tokens : Array[Token]) -> Array[ParseItem] {
  let out = Array::new(capacity=tokens.length())
  let mut i = 0
  while i < tokens.length() {
    if i + 2 < tokens.length() {
      match (tokens[i], tokens[i + 1], tokens[i + 2]) {
        (LexInt(o), LexInt(_), LexR) => {
          out.push(Parsed(Indirect(o)))
          i = i + 3
          continue
        }
        _ => ()
      }
    }
    match (tokens[i] : Token) {
      LexComment(_) => ()
      LexNull => out.push(Parsed(Null))
      LexBool(b) => out.push(Parsed(Boolean(b)))
      LexInt(v) => out.push(Parsed(Integer(v)))
      LexReal(v) => out.push(Parsed(Real(v)))
      LexString(s) => out.push(Parsed(String(s)))
      LexName(n) => out.push(Parsed(Name(@pdf.PdfName::of_string(n))))
      other => out.push(Lexeme(other))
    }
    i = i + 1
  }
  out
}

///|
fn parse_dictionary(
  items : Array[ParseItem],
  start : Int,
) -> (ParseItem, Int) raise {
  let remaining = items.length() - start
  let entries = Array::new(capacity=remaining / 2)
  let mut i = start + 1
  while i < items.length() {
    match items[i] {
      Lexeme(LexRightDict) => return (Parsed(Dictionary(entries)), i + 1)
      _ => {
        let (key_item, next_i) = parse_value(items, i)
        let (val_item, next_i2) = parse_value(items, next_i)
        match (key_item, val_item) {
          (Parsed(Name(k)), Parsed(v)) => entries.push((k.to_string_bytes(), v))
          _ => raise @pdf.PdfError::Msg("parse_dictionary")
        }
        i = next_i2
      }
    }
  }
  raise @pdf.PdfError::Msg("parse_dictionary")
}

///|
fn parse_array(items : Array[ParseItem], start : Int) -> (ParseItem, Int) raise {
  let remaining = items.length() - start
  let values = Array::new(capacity=remaining)
  let mut i = start + 1
  while i < items.length() {
    match items[i] {
      Lexeme(LexRightSquare) => return (Parsed(Array(values)), i + 1)
      _ => {
        let (val_item, next_i) = parse_value(items, i)
        match val_item {
          Parsed(v) => values.push(v)
          _ => raise @pdf.PdfError::Msg("parse_array")
        }
        i = next_i
      }
    }
  }
  raise @pdf.PdfError::Msg("parse_array")
}

///|
fn parse_value(items : Array[ParseItem], start : Int) -> (ParseItem, Int) raise {
  if start >= items.length() {
    raise @pdf.PdfError::Msg("parse_value")
  }
  match items[start] {
    Lexeme(LexLeftDict) => parse_dictionary(items, start)
    Lexeme(LexLeftSquare) => parse_array(items, start)
    other => (other, start + 1)
  }
}

///|
fn parse_to_tree(items : Array[ParseItem]) -> Array[ParseItem] raise {
  let out = Array::new(capacity=items.length())
  let mut i = 0
  while i < items.length() {
    match items[i] {
      Lexeme(LexLeftDict) => {
        let (parsed, next_i) = parse_dictionary(items, i)
        out.push(parsed)
        i = next_i
      }
      Lexeme(LexLeftSquare) => {
        let (parsed, next_i) = parse_array(items, i)
        out.push(parsed)
        i = next_i
      }
      other => {
        out.push(other)
        i = i + 1
      }
    }
  }
  out
}

///|
fn parse_finish(
  items : Array[ParseItem],
  failure_is_ok : Bool,
) -> (Int, PdfObject) raise {
  match items {
    [Parsed(obj)] => return (0, obj)
    [
      Parsed(Integer(o)),
      Parsed(Integer(_)),
      Lexeme(LexObj),
      Parsed(Dictionary(dict)),
      Lexeme(LexStream(stream)),
      Lexeme(LexEndStream),
      Lexeme(LexEndObj),
      ..,
    ] => return (o, Stream(Ref::new((Dictionary(dict), stream))))
    [
      Parsed(Integer(o)),
      Parsed(Integer(_)),
      Lexeme(LexObj),
      Parsed(obj),
      Lexeme(LexEndObj),
      ..,
    ] => return (o, obj)
    [Parsed(Integer(o)), Parsed(Integer(_)), Lexeme(LexObj), Parsed(obj), ..] =>
      return (o, obj)
    [
      Parsed(Integer(o)),
      Parsed(Integer(_)),
      Lexeme(LexObj),
      Lexeme(LexEndObj),
      ..,
    ] => return (o, Null)
    _ =>
      if failure_is_ok {
        (0, Null)
      } else {
        raise @pdf.PdfError::Msg("Could not extract object")
      }
  }
}

///|
/// Parse a PDF object from tokens.
pub fn PdfSyntax::parse(
  _self : PdfSyntax,
  tokens : Array[Token],
  failure_is_ok? : Bool = false,
) -> (Int, PdfObject) raise {
  parse_finish(parse_to_tree(parse_R(tokens)), failure_is_ok) catch {
    err => if failure_is_ok { (0, Null) } else { raise err }
  }
}
