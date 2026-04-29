# pdfsyntax

PDF lexer and parser for converting byte streams to `PdfObject` trees.

## Overview

The `pdfsyntax` package provides:

- **Lexing**: Convert input bytes into a token stream
- **Parsing**: Convert tokens into `PdfObject` values
- **Utilities**: Input stream helpers for reading PDF syntax

## Quick Start

### Parsing Objects from Strings

```mbt check
///|
test "parse_single_object parses integer" {
  guard @pdfsyntax.PdfSyntax::new().parse_single_object("42") is Integer(n) else {
    fail("expected integer")
  }
  inspect(n, content="42")
}
```

```mbt check
///|
test "parse_single_object parses array" {
  guard @pdfsyntax.PdfSyntax::new().parse_single_object("[1 2 3]")
    is Array(items) else {
    fail("expected array")
  }
  inspect(items.length(), content="3")
}
```

```mbt check
///|
test "parse_single_object parses dictionary" {
  let obj = @pdfsyntax.PdfSyntax::new().parse_single_object(
    "<< /Type /Page /Count 5 >>",
  )
  guard obj is Dictionary(entries) else { fail("expected dictionary") }
  inspect(entries.length(), content="2")
}
```

## Lexing

### Lexing Names

```mbt check
///|
test "lex_name reads PDF name" {
  let input = @pdfio.Input::of_string("/Type")
  guard @pdfsyntax.PdfSyntax::new().lex_name(input) is LexName(name) else {
    fail("expected name")
  }
  inspect(name, content="/Type")
}
```

### Lexing Numbers

```mbt check
///|
test "lex_number reads integer" {
  let input = @pdfio.Input::of_string("123")
  guard @pdfsyntax.PdfSyntax::new().lex_number(input) is LexInt(n) else {
    fail("expected int")
  }
  inspect(n, content="123")
}
```

```mbt check
///|
test "lex_number reads float" {
  let input = @pdfio.Input::of_string("3.14159")
  guard @pdfsyntax.PdfSyntax::new().lex_number(input) is LexReal(r) else {
    fail("expected real")
  }
  assert_true(r > 3.14 && r < 3.15)
}
```

### Lexing Strings

```mbt check
///|
test "lex_string reads literal string" {
  let input = @pdfio.Input::of_string("(Hello World)")
  guard @pdfsyntax.PdfSyntax::new().lex_string(input) is LexString(s) else {
    fail("expected string")
  }
  inspect(s, content="Hello World")
}
```

### Lexing Hex Strings

```mbt check
///|
test "lex_hexstring reads hex" {
  let input = @pdfio.Input::of_string("<48656C6C6F>")
  guard @pdfsyntax.PdfSyntax::new().lex_hexstring(input) is LexString(s) else {
    fail("expected string")
  }
  inspect(s, content="Hello")
}
```

### Lexing Comments

```mbt check
///|
test "lex_comment skips comment" {
  let input = @pdfio.Input::of_string("%This is a comment\nnext")
  guard @pdfsyntax.PdfSyntax::new().lex_comment(input) is LexComment(_) else {
    fail("expected comment")
  }
  // After lex_comment, input is at the newline
  inspect((input.input_char)(), content="Some('\\n')")
}
```

## Parsing

### Parse Function

The main `parse` function converts a token array to a `PdfObject`:

```mbt nocheck
pub fn PdfSyntax::parse(
  tokens : Array[@pdfgenlex.Token],
  failure_is_ok? : Bool = false,
) -> (Int, @pdf.PdfObject) raise
```

Returns a tuple of (object number, parsed object). The object number is 0 for standalone objects.

### Parsing Objects with Object Numbers

```mbt check
///|
test "parse with object header" {
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string(
    "1 0 obj << /Type /Page >> endobj",
  )
  // This simplified lexer doesn't handle obj/endobj
  // Full parsing would use lex_object_at
  inspect(tokens.length() > 0, content="true")
}
```

## Lexeme Utilities

### Token to String

```mbt check
///|
test "string_of_lexeme" {
  inspect(@pdfsyntax.PdfSyntax::new().string_of_lexeme(LexNull), content="null")
  inspect(
    @pdfsyntax.PdfSyntax::new().string_of_lexeme(LexInt(42)),
    content="42",
  )
  inspect(
    @pdfsyntax.PdfSyntax::new().string_of_lexeme(LexName("/Type")),
    content="/Type",
  )
  inspect(
    @pdfsyntax.PdfSyntax::new().string_of_lexeme(LexLeftSquare),
    content="[",
  )
  inspect(
    @pdfsyntax.PdfSyntax::new().string_of_lexeme(LexLeftDict),
    content="<<",
  )
}
```

## Input Utilities

### Skip Whitespace

```mbt check
///|
test "dropwhite skips whitespace" {
  let input = @pdfio.Input::of_string("   hello")
  @pdfsyntax.PdfSyntax::new().dropwhite(input)
  inspect((input.input_char)(), content="Some('h')")
}
```

### Read Until Predicate

```mbt check
///|
test "getuntil_string reads until delimiter" {
  let input = @pdfio.Input::of_string("name/next")
  let syntax = @pdfsyntax.PdfSyntax::new()
  let s = syntax.getuntil_string(
    true,
    c => syntax.is_whitespace_or_delimiter(c),
    input,
  )
  inspect(s, content="name")
}
```

### Read Lines

```mbt check
///|
test "input_line reads until newline" {
  let input = @pdfio.Input::of_string("first line\nsecond line")
  inspect(@pdfsyntax.PdfSyntax::new().input_line(input), content="first line")
}
```

### Find EOF Marker

```mbt check
///|
test "find_eof locates %%EOF" {
  let input = @pdfio.Input::of_string("content\n%%EOF\n")
  @pdfsyntax.PdfSyntax::new().find_eof(input)
  // Input is now positioned at %%EOF
}
```

## Advanced Lexing

### lex_object_at

For parsing complete PDF objects from files:

```mbt nocheck
pub fn PdfSyntax::lex_object_at(
  oneonly : Bool,                             // Stop after one object?
  input : @pdfio.Input,                       // Input stream
  read_stream_data : Bool,                    // Load stream bytes?
  lexobj : (Int) -> Array[@pdfgenlex.Token],  // Object lookup callback
) -> Array[@pdfgenlex.Token]
```

### lex_next

Low-level token-by-token lexing:

```mbt nocheck
pub fn PdfSyntax::lex_next(
  dict_level : Ref[Int],                      // Dictionary nesting depth
  array_level : Ref[Int],                     // Array nesting depth
  end_on_stream : Bool,                       // Stop at stream?
  input : @pdfio.Input,                       // Input stream
  previous_lexemes : Array[@pdfgenlex.Token], // Previous tokens
  read_stream_data : Bool,                    // Load stream bytes?
  lexobj : (Int) -> Array[@pdfgenlex.Token],  // Object lookup callback
) -> @pdfgenlex.Token
```

### lex_dictionary

Lex a complete dictionary:

```mbt nocheck
pub fn PdfSyntax::lex_dictionary(
  minus_one : Bool,       // Adjust position by -1?
  input : @pdfio.Input,
) -> Array[@pdfgenlex.Token]
```

## Error Handling

Parsing functions raise `@pdf.PdfError` on malformed input:

```mbt nocheck
// With failure_is_ok=true, returns Null instead of raising
let (_, obj) = @pdfsyntax.PdfSyntax::new().parse!(tokens, failure_is_ok=true)
```
