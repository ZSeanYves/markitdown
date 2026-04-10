///|
pub enum PdfContentOperand {
  Number(Double)
  Name(String)
  String(String)
  Array(Array[PdfContentOperand])
}

///|
pub enum PdfContentToken {
  Number(Double)
  Name(String)
  String(String)
  Array(Array[PdfContentOperand])
  Operator(String)
}

///|
pub struct PdfTextOp {
  op : String
  operands : Array[PdfContentOperand]
}

///|
pub fn parse_page_content_tokens(
  stream : Bytes,
) -> Array[PdfContentToken] raise {
  let out : Array[PdfContentToken] = []
  let mut i = 0
  while true {
    let p = skip_ws_and_comment(stream, i)
    if p >= stream.length() {
      break
    }
    let (tok, n) = parse_content_token(stream, p)
    out.push(tok)
    i = n
  }
  out
}

///|
fn clone_operands(xs : Array[PdfContentOperand]) -> Array[PdfContentOperand] {
  let out : Array[PdfContentOperand] = []
  for x in xs {
    out.push(x)
  }
  out
}

///|
pub fn extract_text_ops_from_page_stream(
  stream : Bytes,
) -> Array[PdfTextOp] raise {
  let tokens = parse_page_content_tokens(stream)
  let operands : Array[PdfContentOperand] = []
  let out : Array[PdfTextOp] = []

  for tok in tokens {
    match tok {
      PdfContentToken::Number(v) => operands.push(PdfContentOperand::Number(v))
      PdfContentToken::Name(v) => operands.push(PdfContentOperand::Name(v))
      PdfContentToken::String(v) => operands.push(PdfContentOperand::String(v))
      PdfContentToken::Array(v) => operands.push(PdfContentOperand::Array(v))
      PdfContentToken::Operator(op) => {
        if is_min_text_operator(op) {
          out.push({ op, operands: clone_operands(operands) })
        }
        operands.clear()
      }
    }
  }
  out
}

///|
pub fn extract_plain_text_from_page_stream(stream : Bytes) -> String raise {
  let ops = extract_text_ops_from_page_stream(stream)
  let mut out = ""
  let mut in_text = false

  for op in ops {
    if op.op == "BT" {
      in_text = true
      continue
    }
    if op.op == "ET" {
      in_text = false
      out = append_line_break(out)
      continue
    }
    if !in_text {
      continue
    }

    if op.op == "Tj" {
      if op.operands.length() >= 1 {
        out = out + text_from_operand(op.operands[0])
      }
      continue
    }
    if op.op == "TJ" {
      if op.operands.length() >= 1 {
        out = out + text_from_operand(op.operands[0])
      }
      continue
    }
    if op.op == "Td" || op.op == "TD" || op.op == "Tm" || op.op == "T*" {
      out = append_line_break(out)
      continue
    }
  }

  out.trim().to_string()
}

///|
fn parse_content_token(
  stream : Bytes,
  pos : Int,
) -> (PdfContentToken, Int) raise {
  let ch = stream[pos]
  if ch == '/'.to_int().to_byte() {
    let (v, n) = parse_content_name(stream, pos + 1)
    return (PdfContentToken::Name(v), n)
  }
  if ch == '('.to_int().to_byte() {
    let (v, n) = parse_content_literal_string(stream, pos + 1)
    return (PdfContentToken::String(v), n)
  }
  if ch == '['.to_int().to_byte() {
    let (arr, n) = parse_content_array(stream, pos + 1)
    return (PdfContentToken::Array(arr), n)
  }
  if is_num_start(ch) {
    let (v, n) = parse_content_number(stream, pos)
    return (PdfContentToken::Number(v), n)
  }
  let (op, n) = parse_content_keyword(stream, pos)
  (PdfContentToken::Operator(op), n)
}

///|
fn parse_content_name(stream : Bytes, pos : Int) -> (String, Int) raise {
  let mut i = pos
  while i < stream.length() && !is_ws(stream[i]) && !is_delim(stream[i]) {
    i = i + 1
  }
  (bytes_to_string(stream, pos, i), i)
}

///|
fn parse_content_keyword(stream : Bytes, pos : Int) -> (String, Int) raise {
  let mut i = pos
  while i < stream.length() && !is_ws(stream[i]) && !is_delim(stream[i]) {
    i = i + 1
  }
  if i <= pos {
    raise InvalidStructure("empty operator token in content stream")
  }
  (bytes_to_string(stream, pos, i), i)
}

///|
fn parse_content_number(stream : Bytes, pos : Int) -> (Double, Int) raise {
  let mut i = pos
  if i < stream.length() &&
    (stream[i] == '+'.to_int().to_byte() || stream[i] == '-'.to_int().to_byte()) {
    i = i + 1
  }
  let mut has_digit = false
  let mut has_dot = false
  while i < stream.length() {
    let ch = stream[i]
    if ch >= '0'.to_int().to_byte() && ch <= '9'.to_int().to_byte() {
      has_digit = true
      i = i + 1
      continue
    }
    if ch == '.'.to_int().to_byte() && !has_dot {
      has_dot = true
      i = i + 1
      continue
    }
    break
  }

  if !has_digit {
    raise InvalidStructure("invalid content stream number")
  }
  let raw = bytes_to_string(stream, pos, i)
  let v = @string.parse_double(raw) catch {
    _ => raise InvalidStructure("invalid content stream number: " + raw)
  }
  (v, i)
}

///|
fn parse_content_array(
  stream : Bytes,
  pos : Int,
) -> (Array[PdfContentOperand], Int) raise {
  let out : Array[PdfContentOperand] = []
  let mut i = pos
  while true {
    let p = skip_ws_and_comment(stream, i)
    if p >= stream.length() {
      raise UnexpectedEOF("content stream array")
    }
    if stream[p] == ']'.to_int().to_byte() {
      return (out, p + 1)
    }
    let (v, n) = parse_content_operand(stream, p)
    out.push(v)
    i = n
  } nobreak {
    raise UnexpectedEOF("content stream array")
  }
}

///|
fn parse_content_operand(
  stream : Bytes,
  pos : Int,
) -> (PdfContentOperand, Int) raise {
  let ch = stream[pos]
  if ch == '/'.to_int().to_byte() {
    let (v, n) = parse_content_name(stream, pos + 1)
    return (PdfContentOperand::Name(v), n)
  }
  if ch == '('.to_int().to_byte() {
    let (v, n) = parse_content_literal_string(stream, pos + 1)
    return (PdfContentOperand::String(v), n)
  }
  if ch == '['.to_int().to_byte() {
    let (v, n) = parse_content_array(stream, pos + 1)
    return (PdfContentOperand::Array(v), n)
  }
  if is_num_start(ch) {
    let (v, n) = parse_content_number(stream, pos)
    return (PdfContentOperand::Number(v), n)
  }
  raise InvalidStructure("unsupported operand token in content stream")
}

///|
fn parse_content_literal_string(
  stream : Bytes,
  pos : Int,
) -> (String, Int) raise {
  let mut depth = 1
  let mut i = pos
  let mut out = ""

  while i < stream.length() {
    let ch = stream[i]
    if ch == '\\'.to_int().to_byte() {
      if i + 1 >= stream.length() {
        raise UnexpectedEOF("content stream literal string escape")
      }
      let n = stream[i + 1]
      if n == 'n'.to_int().to_byte() {
        out = out + "\n"
      } else if n == 'r'.to_int().to_byte() {
        out = out + "\r"
      } else if n == 't'.to_int().to_byte() {
        out = out + "\t"
      } else if n == 'b'.to_int().to_byte() {
        out = out + "\b"
      } else if n == 'f'.to_int().to_byte() {
        out = out + "\u000C"
      } else {
        out = out + bytes_to_string(stream, i + 1, i + 2)
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
        return (out, i + 1)
      }
      out = out + ")"
      i = i + 1
      continue
    }
    out = out + bytes_to_string(stream, i, i + 1)
    i = i + 1
  }
  raise UnexpectedEOF("content stream literal string")
}

///|
fn text_from_operand(v : PdfContentOperand) -> String {
  match v {
    PdfContentOperand::String(s) => s
    PdfContentOperand::Array(items) => {
      let mut out = ""
      for item in items {
        match item {
          PdfContentOperand::String(s) => out = out + s
          _ => ()
        }
      }
      out
    }
    _ => ""
  }
}

///|
fn append_line_break(s : String) -> String {
  if s == "" || s.ends_with("\n") {
    return s
  }
  s + "\n"
}

///|
fn is_num_start(ch : Byte) -> Bool {
  (ch >= '0'.to_int().to_byte() && ch <= '9'.to_int().to_byte()) ||
  ch == '+'.to_int().to_byte() ||
  ch == '-'.to_int().to_byte() ||
  ch == '.'.to_int().to_byte()
}

///|
fn is_min_text_operator(op : String) -> Bool {
  op == "BT" ||
  op == "ET" ||
  op == "Tj" ||
  op == "TJ" ||
  op == "Td" ||
  op == "TD" ||
  op == "Tm" ||
  op == "T*"
}
