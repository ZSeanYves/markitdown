///|
type Token = @pdfgenlex.Token

///|
test "string_of_lexeme renders tokens" {
  let syntax = @pdfsyntax.PdfSyntax::new()
  assert_eq(syntax.string_of_lexeme(LexNull), "null")
  assert_eq(syntax.string_of_lexeme(LexBool(true)), "true")
  assert_eq(syntax.string_of_lexeme(LexBool(false)), "false")
  assert_eq(syntax.string_of_lexeme(LexInt(12)), "12")
  assert_eq(syntax.string_of_lexeme(LexName("/Name")), "/Name")
  assert_eq(syntax.string_of_lexeme(LexLeftSquare), "[")
  assert_eq(syntax.string_of_lexeme(LexRightSquare), "]")
  assert_eq(syntax.string_of_lexeme(LexLeftDict), "<<")
  assert_eq(syntax.string_of_lexeme(LexRightDict), ">>")
  assert_eq(syntax.string_of_lexeme(LexEndStream), "EndStream")
  assert_eq(syntax.string_of_lexeme(LexObj), "obj")
  assert_eq(syntax.string_of_lexeme(LexEndObj), "endobj")
  assert_eq(syntax.string_of_lexeme(LexR), "R")
  assert_eq(syntax.string_of_lexeme(StopLexing), "StopLexing")
  assert_eq(syntax.string_of_lexeme(LexNone), "LexNone")
}

///|
test "string_of_lexeme escapes string data" {
  let value = "a(b)\\\n"
  let token : Token = LexString(value)
  let syntax = @pdfsyntax.PdfSyntax::new()
  assert_eq(syntax.string_of_lexeme(token), "(a\\(b\\)\\\\\\n)")
}

///|
test "string_of_lexeme escapes more control characters" {
  let token : Token = LexString("\r\t\b\f")
  let syntax = @pdfsyntax.PdfSyntax::new()
  assert_eq(syntax.string_of_lexeme(token), "(\\r\\t\\b\\f)")
}

///|
test "string_of_lexeme prints comments and streams" {
  let syntax = @pdfsyntax.PdfSyntax::new()
  assert_eq(syntax.string_of_lexeme(LexComment("note")), "\n%note\n")
  let stream = @pdf.Stream::Got(@pdfio.bytes_of_string("data"))
  assert_eq(syntax.string_of_lexeme(LexStream(stream)), "LexStream")
}

///|
test "string_of_lexeme formats scientific real" {
  let candidates : Array[Double] = [1.0e-40, -1.0e-40, 1.0e40]
  let mut picked : Double? = None
  for candidate in candidates {
    let raw = candidate.to_string()
    if raw.contains("e") || raw.contains("E") {
      picked = Some(candidate)
    }
  }
  let value = match picked {
    Some(v) => v
    None => fail("expected scientific notation in Double::to_string")
  }
  let syntax = @pdfsyntax.PdfSyntax::new()
  let formatted = syntax.string_of_lexeme(LexReal(value))
  assert_true(!formatted.contains("e") && !formatted.contains("E"))
}

///|
test "string_of_lexeme expands small scientific real to leading zeros" {
  let candidates : Array[Double] = [
    1.0e-5, 1.0e-40, 1.0e-100, 1.0e-200, 1.0e-300,
  ]
  let mut picked : Double? = None
  for candidate in candidates {
    let raw = candidate.to_string()
    if raw.contains("e-") || raw.contains("E-") {
      picked = Some(candidate)
      break
    }
  }
  let value = match picked {
    Some(v) => v
    None => fail("expected scientific negative exponent in Double::to_string")
  }
  let syntax = @pdfsyntax.PdfSyntax::new()
  let formatted = syntax.string_of_lexeme(LexReal(value))
  assert_true(
    formatted.has_prefix("0.") &&
    !formatted.contains("e") &&
    !formatted.contains("E"),
  )
}
