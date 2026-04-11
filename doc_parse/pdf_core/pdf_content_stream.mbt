///|
pub(all) enum PdfContentOperand {
  Number(Double)
  Name(String)
  String(String)
  HexString(Bytes)
  Array(Array[PdfContentOperand])
}

///|
pub enum PdfContentToken {
  Number(Double)
  Name(String)
  String(String)
  HexString(Bytes)
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
  let mut _last_token_debug = ""
  let mut _last_token_start = -1
  let mut _last_token_end = -1
  let mut _current_stream_len = 0
  _current_stream_len = stream.length()
  let out : Array[PdfContentToken] = []
  let mut i = 0
  while true {
    let p = skip_ws_and_comment(stream, i)
    if p >= stream.length() {
      break
    }
    let (tok, n) = parse_content_token(stream, p)
    _last_token_debug = debug_token_label(tok)
    _last_token_start = p
    _last_token_end = n
    out.push(tok)
    i = n
  }
  out
}

///|
fn debug_token_label(tok : PdfContentToken) -> String {
  match tok {
    PdfContentToken::Number(_) => "Number"
    PdfContentToken::Name(v) => "Name(" + v + ")"
    PdfContentToken::String(_) => "String"
    PdfContentToken::HexString(_) => "HexString"
    PdfContentToken::Array(_) => "Array"
    PdfContentToken::Operator(op) => "Operator(" + op + ")"
  }
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
      PdfContentToken::HexString(v) =>
        operands.push(PdfContentOperand::HexString(v))
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
      out = out + text_from_tj_operands(op.operands)
      continue
    }
    if op.op == "TJ" {
      out = out + text_from_tj_array_operands(op.operands)
      continue
    }
    if op.op == "Td" || op.op == "TD" || op.op == "Tm" || op.op == "T*" {
      out = append_line_break(out)
      continue
    }
  }

  trim_surrounding_line_breaks(out)
}

///|
pub fn extract_plain_text_from_page_streams(
  streams : Array[Bytes],
) -> String raise {
  let mut out = ""
  for s in streams {
    let t = extract_plain_text_from_page_stream(s)
    if t != "" {
      if out != "" {
        out = out + "\n"
      }
      out = out + t
    }
  }
  out
}

///|
fn parse_content_token(
  stream : Bytes,
  pos : Int,
) -> (PdfContentToken, Int) raise {
  let ch = stream[pos]
  if ch == '<'.to_int().to_byte() {
    if pos + 1 < stream.length() && stream[pos + 1] == '<'.to_int().to_byte() {
      return (PdfContentToken::Operator("<<"), pos + 2)
    }
    let (v, n) = parse_content_hex_string(stream, pos + 1)
    return (PdfContentToken::HexString(v), n)
  }
  if ch == '>'.to_int().to_byte() &&
    pos + 1 < stream.length() &&
    stream[pos + 1] == '>'.to_int().to_byte() {
    return (PdfContentToken::Operator(">>"), pos + 2)
  }
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
  if is_delim(ch) {
    if ch == '{'.to_int().to_byte() || ch == '}'.to_int().to_byte() {
      raise InvalidStructure(
        "invalid delimiter in content stream: " + bytes_to_string(stream, pos, pos + 1),
      )
    }
    return (
      PdfContentToken::Operator(bytes_to_string(stream, pos, pos + 1)),
      pos + 1,
    )
  }
  if is_num_start(ch) {
    let (v, n) = parse_content_number(stream, pos)
    return (PdfContentToken::Number(v), n)
  }
  let (op, n) = parse_content_keyword(stream, pos)
  (PdfContentToken::Operator(op), n)
}

///|
fn parse_content_name(stream : Bytes, pos : Int) -> (String, Int) {
  let mut i = pos
  while i < stream.length() && !is_ws(stream[i]) && !is_delim(stream[i]) {
    i = i + 1
  }
  (bytes_to_string(stream, pos, i), i)
}

///|
fn parse_content_keyword(stream : Bytes, pos : Int) -> (String, Int) raise {
  let mut i = pos
    let mut _last_token_debug = ""
  let mut _last_token_start = -1
  let mut _last_token_end = -1
  let mut _current_stream_len = 0
  while i < stream.length() && !is_ws(stream[i]) && !is_delim(stream[i]) {
    i = i + 1
  }
  if i <= pos {
    let ch = stream[pos]
    let lo = if pos - 16 >= 0 { pos - 16 } else { 0 }
    let hi = if pos + 16 < stream.length() {
      pos + 16
    } else {
      stream.length() - 1
    }
    let prev = if _last_token_start >= 0 {
      _last_token_debug +
      "@" +
      _last_token_start.to_string() +
      "-" +
      _last_token_end.to_string()
    } else {
      "<none>"
    }
    println(
      "[pdf-content-debug] empty keyword at pos=" +
      pos.to_string() +
      " byte=" +
      ch.to_int().to_string() +
      " printable=" +
      debug_printable_byte(ch) +
      " window_ascii=" +
      debug_window_ascii(stream, lo, hi + 1) +
      " window_hex=" +
      debug_window_hex(stream, lo, hi + 1) +
      " prev_token=" +
      prev +
      " stream_len=" +
      _current_stream_len.to_string(),
    )
    raise InvalidStructure("empty operator token in content stream")
  }
  (bytes_to_string(stream, pos, i), i)
}

///|
fn debug_printable_byte(ch : Byte) -> String {
  let v = ch.to_int()
  if v >= 32 && v <= 126 {
    "'" + Int::unsafe_to_char(v).to_string() + "'"
  } else {
    "."
  }
}

///|
fn debug_window_ascii(stream : Bytes, start : Int, end_ : Int) -> String {
  let mut out = ""
  let mut i = start
  while i < end_ {
    let v = stream[i].to_int()
    if v >= 32 && v <= 126 {
      out = out + Int::unsafe_to_char(v).to_string()
    } else {
      out = out + "."
    }
    i = i + 1
  }
  out
}

///|
fn debug_hex_nibble(v : Int) -> String {
  if v < 10 {
    Int::unsafe_to_char('0'.to_int() + v).to_string()
  } else {
    Int::unsafe_to_char('a'.to_int() + v - 10).to_string()
  }
}

///|
fn debug_window_hex(stream : Bytes, start : Int, end_ : Int) -> String {
  let mut out = ""
  let mut i = start
  while i < end_ {
    let v = stream[i].to_int() & 0xFF
    let hi = v / 16
    let lo = v % 16
    if out != "" {
      out = out + " "
    }
    out = out + debug_hex_nibble(hi) + debug_hex_nibble(lo)
    i = i + 1
  }
  out
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
  if ch == '<'.to_int().to_byte() {
    let (v, n) = parse_content_hex_string(stream, pos + 1)
    return (PdfContentOperand::HexString(v), n)
  }
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
  let (kw, n) = parse_content_keyword(stream, pos)
  (PdfContentOperand::Name(kw), n)
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
      if n == '\n'.to_int().to_byte() {
        i = i + 2
        continue
      }
      if n == '\r'.to_int().to_byte() {
        if i + 2 < stream.length() && stream[i + 2] == '\n'.to_int().to_byte() {
          i = i + 3
          continue
        }
        i = i + 2
        continue
      }
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
      } else if n == '\\'.to_int().to_byte() {
        out = out + "\\"
        i = i + 2
        if i < stream.length() && stream[i] == '\n'.to_int().to_byte() {
          i = i + 1
        } else if i < stream.length() && stream[i] == '\r'.to_int().to_byte() {
          i = i + 1
          if i < stream.length() && stream[i] == '\n'.to_int().to_byte() {
            i = i + 1
          }
        }
        continue
      } else if n == '('.to_int().to_byte() {
        out = out + "("
      } else if n == ')'.to_int().to_byte() {
        out = out + ")"
      } else if is_octal_digit(n) {
        let (oct, next_idx) = parse_octal_escape_min(stream, i + 1)
        out = out + oct
        i = next_idx
        continue
      } else {
        out = out + bytes_to_string(stream, i + 1, i + 2)
      }
      i = i + 2
      continue
    }
    if ch == '\r'.to_int().to_byte() {
      if i + 1 < stream.length() && stream[i + 1] == '\n'.to_int().to_byte() {
        i = i + 2
      } else {
        i = i + 1
      }
      out = out + "\n"
      continue
    }
    if ch == '\n'.to_int().to_byte() {
      out = out + "\n"
      i = i + 1
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
fn parse_content_hex_string(stream : Bytes, pos : Int) -> (Bytes, Int) raise {
  let out : Array[Byte] = []
  let mut i = pos
  let mut nibble : Int? = None

  while i < stream.length() {
    let ch = stream[i]
    if ch == '>'.to_int().to_byte() {
      match nibble {
        Some(high) => out.push(((high << 4) & 0xFF).to_byte())
        None => ()
      }
      return (Bytes::from_array(out), i + 1)
    }
    if is_ws(ch) {
      i = i + 1
      continue
    }
    let v = hex_digit_value(ch) catch {
      _ =>
        raise InvalidStructure(
          "invalid hex string digit in content stream: " +
          bytes_to_string(stream, i, i + 1),
        )
    }
    match nibble {
      Some(high) => {
        out.push((((high << 4) | v) & 0xFF).to_byte())
        nibble = None
      }
      None => nibble = Some(v)
    }
    i = i + 1
  }

  raise UnexpectedEOF("content stream hex string")
}

///|
fn hex_digit_value(ch : Byte) -> Int raise {
  if ch >= '0'.to_int().to_byte() && ch <= '9'.to_int().to_byte() {
    return ch.to_int() - '0'.to_int()
  }
  if ch >= 'A'.to_int().to_byte() && ch <= 'F'.to_int().to_byte() {
    return ch.to_int() - 'A'.to_int() + 10
  }
  if ch >= 'a'.to_int().to_byte() && ch <= 'f'.to_int().to_byte() {
    return ch.to_int() - 'a'.to_int() + 10
  }
  raise InvalidStructure("invalid hex digit")
}

///|
fn parse_octal_escape_min(stream : Bytes, pos : Int) -> (String, Int) {
  let mut i = pos
  let mut count = 0
  let mut v = 0

  while i < stream.length() && count < 3 && is_octal_digit(stream[i]) {
    v = v * 8 + (stream[i].to_int() - '0'.to_int())
    i = i + 1
    count = count + 1
  }
  let b = (v & 0xFF).to_byte()
  (Int::unsafe_to_char(b.to_int()).to_string(), i)
}

///|
fn is_octal_digit(ch : Byte) -> Bool {
  ch >= '0'.to_int().to_byte() && ch <= '7'.to_int().to_byte()
}

///|
fn text_from_tj_operands(operands : Array[PdfContentOperand]) -> String {
  if operands.length() == 0 {
    return ""
  }
  text_from_operand(operands[operands.length() - 1])
}

///|
fn text_from_tj_array_operands(operands : Array[PdfContentOperand]) -> String {
  if operands.length() == 0 {
    return ""
  }

  let mut idx = operands.length() - 1
  while true {
    match operands[idx] {
      PdfContentOperand::Array(items) =>
        return text_from_operand(PdfContentOperand::Array(items))
      _ => ()
    }
    if idx == 0 {
      break
    }
    idx = idx - 1
  }
  ""
}

///|
fn text_from_operand(v : PdfContentOperand) -> String {
  match v {
    PdfContentOperand::String(s) => s
    PdfContentOperand::HexString(bs) => bytes_to_text_fallback(bs)
    PdfContentOperand::Array(items) => {
      let mut out = ""
      for item in items {
        match item {
          PdfContentOperand::String(s) => out = out + s
          PdfContentOperand::HexString(bs) =>
            out = out + bytes_to_text_fallback(bs)
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
  if s == "" || s.has_suffix("\n") {
    return s
  }
  s + "\n"
}

///|
fn is_line_break_u16(ch : UInt16) -> Bool {
  ch == 10 || ch == 13
}

///|
fn trim_surrounding_line_breaks(s : String) -> String {
  let mut start = 0
  let mut end = s.length()

  while start < end && is_line_break_u16(s[start]) {
    start = start + 1
  }
  while end > start && is_line_break_u16(s[end - 1]) {
    end = end - 1
  }
  s[start:end].to_string()
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
  op == "Tf" ||
  op == "Tj" ||
  op == "TJ" ||
  op == "Td" ||
  op == "TD" ||
  op == "Tm" ||
  op == "T*"
}
