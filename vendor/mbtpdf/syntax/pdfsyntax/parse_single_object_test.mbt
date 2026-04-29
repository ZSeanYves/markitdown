///|
test "parse_single_object numbers" {
  let syntax = @pdfsyntax.PdfSyntax::new()
  let obj = syntax.parse_single_object("123")
  match (obj : @pdf.PdfObject) {
    Integer(123) => ()
    _ => fail("expected integer")
  }
  let obj2 = syntax.parse_single_object("-3.5")
  match (obj2 : @pdf.PdfObject) {
    Real(r) => if r != -3.5 { fail("expected -3.5") }
    _ => fail("expected real")
  }
}

///|
test "parse_single_object collections" {
  let syntax = @pdfsyntax.PdfSyntax::new()
  let obj = syntax.parse_single_object("[1 2 3]")
  match (obj : @pdf.PdfObject) {
    Array(values) => if values.length() != 3 { fail("expected array length 3") }
    _ => fail("expected array")
  }
  let obj2 = syntax.parse_single_object("<< /Type /Example /Count 2 >>")
  match (obj2 : @pdf.PdfObject) {
    Dictionary(entries) =>
      if entries.length() != 2 {
        fail("expected dictionary length 2")
      }
    _ => fail("expected dictionary")
  }
}

///|
test "parse_single_object names, strings, and atoms" {
  let syntax = @pdfsyntax.PdfSyntax::new()
  let name_obj = syntax.parse_single_object("/A#20B")
  match (name_obj : @pdf.PdfObject) {
    Name(name) => assert_eq(name.to_string_bytes(), "/A B")
    _ => fail("expected name")
  }
  let str_obj = syntax.parse_single_object("(hello\\nworld)")
  match (str_obj : @pdf.PdfObject) {
    String(value) => assert_eq(value, "hello\nworld")
    _ => fail("expected string")
  }
  let bool_obj = syntax.parse_single_object("true")
  match (bool_obj : @pdf.PdfObject) {
    Boolean(true) => ()
    _ => fail("expected true")
  }
  let null_obj = syntax.parse_single_object("null")
  match (null_obj : @pdf.PdfObject) {
    Null => ()
    _ => fail("expected null")
  }
}
