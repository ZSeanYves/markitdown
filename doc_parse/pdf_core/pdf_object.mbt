///|
fn parse_pdf_value(bs : Bytes, pos : Int) -> (PdfValue, Int) raise {
  let (tok, next) = match read_token(bs, pos) {
    Some(v) => v
    None => raise UnexpectedEOF("value")
  }

  match tok {
    PdfToken::LDict => parse_dict(bs, next)
    PdfToken::LArray => parse_array(bs, next)
    PdfToken::LParen => parse_literal_string(bs, next)
    PdfToken::Lt => parse_hex_string(bs, next)
    PdfToken::Name(name) => (PdfValue::Name(name), next)
    PdfToken::Keyword(k) => parse_keyword_value(k, next)
    PdfToken::Number(raw) => parse_number_or_ref(bs, raw, next)
    _ => raise InvalidStructure("unexpected token while parsing value")
  }
}

///|
fn parse_keyword_value(
  k : String,
  next : Int,
) -> (PdfValue, Int) raise PdfParseError {
  if k == "null" {
    return (PdfValue::Null, next)
  }
  if k == "true" {
    return (PdfValue::Bool(true), next)
  }
  if k == "false" {
    return (PdfValue::Bool(false), next)
  }
  raise InvalidStructure("unknown keyword as value: " + k)
}

///|
fn parse_number_or_ref(
  bs : Bytes,
  raw : String,
  next : Int,
) -> (PdfValue, Int) raise {
  let s = skip_ws_and_comment(bs, next)
  match read_token(bs, s) {
    Some((PdfToken::Number(raw2), next2)) => {
      let s2 = skip_ws_and_comment(bs, next2)
      match read_token(bs, s2) {
        Some((PdfToken::Keyword(k), next3)) if k == "R" => {
          let obj = @string.parse_int(raw) catch {
            _ => raise InvalidStructure("invalid ref obj num: " + raw)
          }
          let gen = @string.parse_int(raw2) catch {
            _ => raise InvalidStructure("invalid ref gen: " + raw2)
          }
          return (PdfValue::Ref(obj, gen), next3)
        }
        _ => ()
      }
    }
    _ => ()
  }

  if raw.contains(".") {
    let v = @string.parse_double(raw) catch {
      _ => raise InvalidStructure("invalid real: " + raw)
    }
    (PdfValue::Real(v), next)
  } else {
    let v = @string.parse_int(raw) catch {
      _ => raise InvalidStructure("invalid int: " + raw)
    }
    (PdfValue::Int(v), next)
  }
}

///|
fn parse_array(bs : Bytes, pos : Int) -> (PdfValue, Int) raise {
  let arr : Array[PdfValue] = []
  let mut i = pos

  while true {
    let j = skip_ws_and_comment(bs, i)
    match read_token(bs, j) {
      Some((PdfToken::RArray, next)) => break (PdfValue::Array(arr), next)
      Some(_) => {
        let (v, n) = parse_pdf_value(bs, j)
        arr.push(v)
        i = n
      }
      None => raise UnexpectedEOF("array")
    }
  } nobreak {
    raise UnexpectedEOF("array")
  }
}

///|
fn parse_dict(bs : Bytes, pos : Int) -> (PdfValue, Int) raise {
  let dict : Map[String, PdfValue] = Map::new()
  let mut i = pos

  while true {
    let j = skip_ws_and_comment(bs, i)
    match read_token(bs, j) {
      Some((PdfToken::RDict, next)) => break (PdfValue::Dict(dict), next)
      Some((PdfToken::Name(name), n1)) => {
        let (v, n2) = parse_pdf_value(bs, n1)
        dict.set(name, v)
        i = n2
      }
      Some(_) => raise InvalidStructure("dictionary key must be /Name")
      None => raise UnexpectedEOF("dictionary")
    }
  } nobreak {
    raise UnexpectedEOF("dictionary")
  }
}

///|
fn parse_literal_string(bs : Bytes, pos : Int) -> (PdfValue, Int) raise {
  let mut depth = 1
  let mut i = pos
  let mut out = ""

  while i < bs.length() {
    let ch = bs[i]
    if ch == '\\'.to_int().to_byte() {
      if i + 1 >= bs.length() {
        raise UnexpectedEOF("literal string escape")
      }
      let n = bs[i + 1]
      if n == 'n'.to_int().to_byte() {
        out = out + "\n"
      } else if n == 'r'.to_int().to_byte() {
        out = out + "\r"
      } else if n == 't'.to_int().to_byte() {
        out = out + "\t"
      } else {
        out = out + bytes_to_string(bs, i + 1, i + 2)
      }
      i = i + 2
      continue
    }
    if ch == '('.to_int().to_byte() {
      depth = depth + 1
      out = out + "("
      i = i + 1
      continue
    }
    if ch == ')'.to_int().to_byte() {
      depth = depth - 1
      if depth == 0 {
        return (PdfValue::String(out), i + 1)
      }
      out = out + ")"
      i = i + 1
      continue
    }
    out = out + bytes_to_string(bs, i, i + 1)
    i = i + 1
  }

  raise UnexpectedEOF("literal string")
}

///|
fn parse_hex_string(
  bs : Bytes,
  pos : Int,
) -> (PdfValue, Int) raise PdfParseError {
  let mut i = pos
  while i < bs.length() {
    if bs[i] == '>'.to_int().to_byte() {
      return (PdfValue::HexString(bs[pos:i].to_bytes()), i + 1)
    }
    i = i + 1
  }
  raise UnexpectedEOF("hex string")
}

///|
fn parse_indirect_object_at(
  bytes : Bytes,
  offset : Int,
) -> PdfIndirectObject raise {
  let (obj_num, p1) = match
    read_int_ascii(bytes, skip_ws_and_comment(bytes, offset)) {
    Some(v) => v
    None => raise InvalidStructure("invalid indirect object number")
  }
  let (gen, p2) = match read_int_ascii(bytes, skip_ws_and_comment(bytes, p1)) {
    Some(v) => v
    None => raise InvalidStructure("invalid indirect generation")
  }
  let p3 = skip_ws_and_comment(bytes, p2)
  if !starts_with_at(bytes, p3, "obj") {
    raise InvalidStructure("expected obj keyword")
  }

  let body_start = p3 + 3
  let (value, body_next_old) = parse_pdf_value(bytes, body_start)
  let mut body_next = body_next_old
  body_next = skip_ws_and_comment(bytes, body_next)

  let mut stream : Bytes? = None
  if starts_with_at(bytes, body_next, "stream") {
    let (sb, se) = parse_stream_bounds(bytes, value, body_next)
    stream = Some(bytes[sb:se].to_bytes())
    body_next = skip_ws_and_comment(bytes, se)
    if !starts_with_at(bytes, body_next, "endstream") {
      raise InvalidStructure("missing endstream")
    }
    body_next = skip_ws_and_comment(bytes, body_next + 9)
  }

  if !starts_with_at(bytes, body_next, "endobj") {
    raise InvalidStructure("missing endobj")
  }

  { obj_num, gen, value, stream }
}
