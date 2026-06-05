///|
priv enum XlsxFormulaToken {
  Number(Double)
  String(String)
  Identifier(String)
  CellRef(String, Int, Int)
  Plus
  Minus
  Star
  Slash
  Caret
  Ampersand
  Eq
  NotEq
  Lt
  Lte
  Gt
  Gte
  Colon
  Comma
  LParen
  RParen
}

///|
priv struct XlsxFormulaParser {
  tokens : Array[XlsxFormulaToken]
  mut pos : Int
}

///|
fn parse_xlsx_formula_text(
  formula_text : String,
) -> Result[XlsxFormulaAst, String] {
  let trimmed = formula_text.trim().to_owned()
  if trimmed == "" {
    return Err("empty formula")
  }
  if trimmed.length() > 512 {
    return Err("formula text too long")
  }

  let tokens = match tokenize_xlsx_formula(trimmed) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if tokens.length() == 0 {
    return Err("empty formula")
  }

  let parser = XlsxFormulaParser::{ tokens, pos: 0 }
  let ast = match parser.parse_expr() {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if parser.pos != parser.tokens.length() {
    return Err("trailing formula tokens")
  }
  Ok(ast)
}

///|
fn XlsxFormulaParser::parse_expr(
  self : XlsxFormulaParser,
) -> Result[XlsxFormulaAst, String] {
  self.parse_comparison()
}

///|
fn XlsxFormulaParser::parse_comparison(
  self : XlsxFormulaParser,
) -> Result[XlsxFormulaAst, String] {
  let left = match self.parse_concat() {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if self.pos >= self.tokens.length() {
    return Ok(left)
  }

  let op = match self.tokens[self.pos] {
    XlsxFormulaToken::Eq => Some("=")
    XlsxFormulaToken::NotEq => Some("<>")
    XlsxFormulaToken::Lt => Some("<")
    XlsxFormulaToken::Lte => Some("<=")
    XlsxFormulaToken::Gt => Some(">")
    XlsxFormulaToken::Gte => Some(">=")
    _ => None
  }
  match op {
    None => Ok(left)
    Some(operator) => {
      self.pos = self.pos + 1
      let right = match self.parse_concat() {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(XlsxFormulaAst::Binary(operator, left, right))
    }
  }
}

///|
fn XlsxFormulaParser::parse_concat(
  self : XlsxFormulaParser,
) -> Result[XlsxFormulaAst, String] {
  let mut expr = match self.parse_additive() {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  while self.pos < self.tokens.length() {
    match self.tokens[self.pos] {
      XlsxFormulaToken::Ampersand => {
        self.pos = self.pos + 1
        let rhs = match self.parse_additive() {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        expr = XlsxFormulaAst::Binary("&", expr, rhs)
      }
      _ => break
    }
  }
  Ok(expr)
}

///|
fn XlsxFormulaParser::parse_additive(
  self : XlsxFormulaParser,
) -> Result[XlsxFormulaAst, String] {
  let mut expr = match self.parse_multiplicative() {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  while self.pos < self.tokens.length() {
    let op = match self.tokens[self.pos] {
      XlsxFormulaToken::Plus => Some("+")
      XlsxFormulaToken::Minus => Some("-")
      _ => None
    }
    match op {
      None => break
      Some(operator) => {
        self.pos = self.pos + 1
        let rhs = match self.parse_multiplicative() {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        expr = XlsxFormulaAst::Binary(operator, expr, rhs)
      }
    }
  }
  Ok(expr)
}

///|
fn XlsxFormulaParser::parse_multiplicative(
  self : XlsxFormulaParser,
) -> Result[XlsxFormulaAst, String] {
  let mut expr = match self.parse_power() {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  while self.pos < self.tokens.length() {
    let op = match self.tokens[self.pos] {
      XlsxFormulaToken::Star => Some("*")
      XlsxFormulaToken::Slash => Some("/")
      _ => None
    }
    match op {
      None => break
      Some(operator) => {
        self.pos = self.pos + 1
        let rhs = match self.parse_power() {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        expr = XlsxFormulaAst::Binary(operator, expr, rhs)
      }
    }
  }
  Ok(expr)
}

///|
fn XlsxFormulaParser::parse_power(
  self : XlsxFormulaParser,
) -> Result[XlsxFormulaAst, String] {
  let expr = match self.parse_unary() {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if self.pos < self.tokens.length() {
    match self.tokens[self.pos] {
      XlsxFormulaToken::Caret => {
        self.pos = self.pos + 1
        let rhs = match self.parse_power() {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        Ok(XlsxFormulaAst::Binary("^", expr, rhs))
      }
      _ => Ok(expr)
    }
  } else {
    Ok(expr)
  }
}

///|
fn XlsxFormulaParser::parse_unary(
  self : XlsxFormulaParser,
) -> Result[XlsxFormulaAst, String] {
  if self.pos < self.tokens.length() {
    match self.tokens[self.pos] {
      XlsxFormulaToken::Plus => {
        self.pos = self.pos + 1
        let inner = match self.parse_unary() {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        return Ok(XlsxFormulaAst::Unary("+", inner))
      }
      XlsxFormulaToken::Minus => {
        self.pos = self.pos + 1
        let inner = match self.parse_unary() {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        return Ok(XlsxFormulaAst::Unary("-", inner))
      }
      _ => ()
    }
  }
  self.parse_primary()
}

///|
fn XlsxFormulaParser::parse_primary(
  self : XlsxFormulaParser,
) -> Result[XlsxFormulaAst, String] {
  if self.pos >= self.tokens.length() {
    return Err("unexpected end of formula")
  }

  match self.tokens[self.pos] {
    XlsxFormulaToken::Number(value) => {
      self.pos = self.pos + 1
      Ok(XlsxFormulaAst::Number(value))
    }
    XlsxFormulaToken::String(value) => {
      self.pos = self.pos + 1
      Ok(XlsxFormulaAst::String(value))
    }
    XlsxFormulaToken::CellRef(label, row, col) => {
      self.pos = self.pos + 1
      if self.pos < self.tokens.length() {
        match self.tokens[self.pos] {
          XlsxFormulaToken::Colon => {
            self.pos = self.pos + 1
            if self.pos >= self.tokens.length() {
              return Err("range missing right-hand reference")
            }
            match self.tokens[self.pos] {
              XlsxFormulaToken::CellRef(label2, row2, col2) => {
                self.pos = self.pos + 1
                Ok(
                  XlsxFormulaAst::RangeRef(label, label2, row, col, row2, col2),
                )
              }
              _ => Err("range right-hand side must be a same-sheet cell ref")
            }
          }
          _ => Ok(XlsxFormulaAst::CellRef(label, row, col))
        }
      } else {
        Ok(XlsxFormulaAst::CellRef(label, row, col))
      }
    }
    XlsxFormulaToken::Identifier(name) => {
      self.pos = self.pos + 1
      let upper = name.to_upper()
      if upper == "TRUE" {
        return Ok(XlsxFormulaAst::Bool(true))
      }
      if upper == "FALSE" {
        return Ok(XlsxFormulaAst::Bool(false))
      }
      if self.pos >= self.tokens.length() {
        return Err("unsupported bare identifier: " + name)
      }
      match self.tokens[self.pos] {
        XlsxFormulaToken::LParen => self.parse_function_call(upper)
        _ => Err("unsupported bare identifier: " + name)
      }
    }
    XlsxFormulaToken::LParen => {
      self.pos = self.pos + 1
      let expr = match self.parse_expr() {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      if self.pos >= self.tokens.length() {
        return Err("unterminated parenthesis")
      }
      match self.tokens[self.pos] {
        XlsxFormulaToken::RParen => {
          self.pos = self.pos + 1
          Ok(expr)
        }
        _ => Err("unterminated parenthesis")
      }
    }
    _ => Err("unexpected token in formula")
  }
}

///|
fn XlsxFormulaParser::parse_function_call(
  self : XlsxFormulaParser,
  name : String,
) -> Result[XlsxFormulaAst, String] {
  self.pos = self.pos + 1
  let args : Array[XlsxFormulaAst] = []

  if self.pos < self.tokens.length() {
    match self.tokens[self.pos] {
      XlsxFormulaToken::RParen => {
        self.pos = self.pos + 1
        return Ok(XlsxFormulaAst::FunctionCall(name, args))
      }
      _ => ()
    }
  }

  while true {
    let arg = match self.parse_expr() {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    args.push(arg)
    if self.pos >= self.tokens.length() {
      return Err("unterminated function call")
    }
    match self.tokens[self.pos] {
      XlsxFormulaToken::Comma => self.pos = self.pos + 1
      XlsxFormulaToken::RParen => {
        self.pos = self.pos + 1
        break
      }
      _ => return Err("expected ',' or ')' in function call")
    }
  }

  Ok(XlsxFormulaAst::FunctionCall(name, args))
}

///|
fn tokenize_xlsx_formula(
  text : String,
) -> Result[Array[XlsxFormulaToken], String] {
  let chars = text.to_array()
  let tokens : Array[XlsxFormulaToken] = []
  let mut i = 0

  while i < chars.length() {
    let ch = chars[i]
    if is_formula_ws(ch) {
      i = i + 1
      continue
    }

    match ch {
      '+' => {
        tokens.push(XlsxFormulaToken::Plus)
        i = i + 1
      }
      '-' => {
        tokens.push(XlsxFormulaToken::Minus)
        i = i + 1
      }
      '*' => {
        tokens.push(XlsxFormulaToken::Star)
        i = i + 1
      }
      '/' => {
        tokens.push(XlsxFormulaToken::Slash)
        i = i + 1
      }
      '^' => {
        tokens.push(XlsxFormulaToken::Caret)
        i = i + 1
      }
      '&' => {
        tokens.push(XlsxFormulaToken::Ampersand)
        i = i + 1
      }
      '(' => {
        tokens.push(XlsxFormulaToken::LParen)
        i = i + 1
      }
      ')' => {
        tokens.push(XlsxFormulaToken::RParen)
        i = i + 1
      }
      ',' => {
        tokens.push(XlsxFormulaToken::Comma)
        i = i + 1
      }
      ':' => {
        tokens.push(XlsxFormulaToken::Colon)
        i = i + 1
      }
      '=' => {
        tokens.push(XlsxFormulaToken::Eq)
        i = i + 1
      }
      '<' =>
        if i + 1 < chars.length() && chars[i + 1] == '=' {
          tokens.push(XlsxFormulaToken::Lte)
          i = i + 2
        } else if i + 1 < chars.length() && chars[i + 1] == '>' {
          tokens.push(XlsxFormulaToken::NotEq)
          i = i + 2
        } else {
          tokens.push(XlsxFormulaToken::Lt)
          i = i + 1
        }
      '>' =>
        if i + 1 < chars.length() && chars[i + 1] == '=' {
          tokens.push(XlsxFormulaToken::Gte)
          i = i + 2
        } else {
          tokens.push(XlsxFormulaToken::Gt)
          i = i + 1
        }
      '"' => {
        let parsed = match parse_formula_string(chars, i) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        tokens.push(XlsxFormulaToken::String(parsed.0))
        i = parsed.1
      }
      _ =>
        if is_formula_digit(ch) || ch == '.' {
          let parsed = match parse_formula_number(chars, i) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          tokens.push(XlsxFormulaToken::Number(parsed.0))
          i = parsed.1
        } else if is_formula_ident_start(ch) || ch == '$' {
          let parsed = match parse_formula_identifier_or_ref(chars, i) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          tokens.push(parsed.0)
          i = parsed.1
        } else {
          return Err("unsupported formula character: " + ch.to_string())
        }
    }
  }

  Ok(tokens)
}

///|
fn parse_formula_string(
  chars : Array[Char],
  start : Int,
) -> Result[(String, Int), String] {
  let out : Array[Char] = []
  let mut i = start + 1
  while i < chars.length() {
    if chars[i] == '"' {
      if i + 1 < chars.length() && chars[i + 1] == '"' {
        out.push('"')
        i = i + 2
        continue
      }
      return Ok((String::from_array(out), i + 1))
    }
    out.push(chars[i])
    i = i + 1
  }
  Err("unterminated string literal")
}

///|
fn parse_formula_number(
  chars : Array[Char],
  start : Int,
) -> Result[(Double, Int), String] {
  let mut i = start
  let mut saw_digit = false
  while i < chars.length() && is_formula_digit(chars[i]) {
    saw_digit = true
    i = i + 1
  }
  if i < chars.length() && chars[i] == '.' {
    i = i + 1
    while i < chars.length() && is_formula_digit(chars[i]) {
      saw_digit = true
      i = i + 1
    }
  }
  if !saw_digit {
    return Err("invalid numeric literal")
  }
  if i < chars.length() && (chars[i] == 'e' || chars[i] == 'E') {
    let mut j = i + 1
    if j < chars.length() && (chars[j] == '+' || chars[j] == '-') {
      j = j + 1
    }
    let exp_start = j
    while j < chars.length() && is_formula_digit(chars[j]) {
      j = j + 1
    }
    if exp_start == j {
      return Err("invalid numeric exponent")
    }
    i = j
  }
  let raw = String::from_array(chars[start:i].to_owned())
  try @string.parse_double(raw) catch {
    _ => Err("invalid numeric literal")
  } noraise {
    value => Ok((value, i))
  }
}

///|
fn parse_formula_identifier_or_ref(
  chars : Array[Char],
  start : Int,
) -> Result[(XlsxFormulaToken, Int), String] {
  let mut i = start
  if chars[i] == '$' {
    i = i + 1
  }
  let col_start = i
  while i < chars.length() && is_formula_letter(chars[i]) {
    i = i + 1
  }
  let has_letters = i > col_start
  let mut j = i
  if j < chars.length() && chars[j] == '$' {
    j = j + 1
  }
  let row_start = j
  while j < chars.length() && is_formula_digit(chars[j]) {
    j = j + 1
  }
  let has_digits = j > row_start

  if has_letters && has_digits {
    let raw = String::from_array(chars[start:j].to_owned())
    if raw.contains("!") || raw.contains("[") || raw.contains("]") {
      return Err("cross-sheet or external references are unsupported")
    }
    let (row, col) = formula_cell_ref_to_rc(raw)
    if row <= 0 || col <= 0 {
      return Err("invalid cell reference")
    }
    return Ok((XlsxFormulaToken::CellRef(raw, row, col), j))
  }

  if !is_formula_ident_start(chars[start]) {
    return Err("unsupported formula token")
  }

  i = start
  while i < chars.length() && is_formula_ident_continue(chars[i]) {
    i = i + 1
  }
  let ident = String::from_array(chars[start:i].to_owned())
  if ident.contains("!") || ident.contains("[") || ident.contains("]") {
    return Err("cross-sheet or external references are unsupported")
  }
  Ok((XlsxFormulaToken::Identifier(ident), i))
}

///|
fn is_formula_ws(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
fn is_formula_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_formula_letter(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

///|
fn is_formula_ident_start(ch : Char) -> Bool {
  is_formula_letter(ch) || ch == '_'
}

///|
fn is_formula_ident_continue(ch : Char) -> Bool {
  is_formula_ident_start(ch) || is_formula_digit(ch) || ch == '.'
}

///|
fn formula_cell_ref_to_rc(r : String) -> (Int, Int) {
  if r == "" {
    return (0, 0)
  }
  let chars = r.to_array()
  let mut i = 0
  let mut col = 0

  while i < chars.length() {
    let ch = chars[i]
    if ch == '$' {
      i = i + 1
      continue
    }
    if ch >= 'A' && ch <= 'Z' {
      col = col * 26 + (ch.to_int() - 'A'.to_int() + 1)
      i += 1
    } else if ch >= 'a' && ch <= 'z' {
      col = col * 26 + (ch.to_int() - 'a'.to_int() + 1)
      i += 1
    } else {
      break
    }
  }

  let mut row = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == '$' {
      i = i + 1
      continue
    }
    if ch >= '0' && ch <= '9' {
      row = row * 10 + (ch.to_int() - '0'.to_int())
      i += 1
    } else {
      break
    }
  }

  (row, col)
}
