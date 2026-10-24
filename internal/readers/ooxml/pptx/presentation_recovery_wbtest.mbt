///|
async test "presentation recovery malformed XML never returns a successful partial slide list" {
  for
    body in [
      "<p:presentation><broken></wrong><p:sldId id='257' r:id='rId1'/></p:presentation>",
      "<p:presentation><p:sldId id='257' r:id='rId1'/><broken></wrong><p:sldId id='258' r:id='rId2'/></p:presentation>",
    ] {
    let ctx = presentation_cursor_fixture(@utf8.encode(body))
    let rejected = try {
      ignore(parse_pptx_source(ctx.pkg))
      false
    } catch {
      PptxError::ParseError(_) => true
      _ => false
    }
    assert_true(rejected)
    assert_true(@dzip.archive_hard_failure(ctx.pkg.archive) is None)
  }
}

///|
async test "presentation recovery syntax before bad tail keeps hard encoding priority" {
  let text = StringBuilder()
  text.write_string(
    "<p:presentation><p:sldId id='257' r:id='rId1'/><broken></wrong>",
  )
  for _ in 0..<70_000 {
    text.write_char(' ')
  }
  let bytes = @utf8.encode(text.to_string()).to_array()
  bytes.push(b'\xff')
  let ctx = presentation_cursor_fixture(Bytes::from_array(bytes))
  let rejected = try {
    ignore(parse_pptx_source(ctx.pkg))
    false
  } catch {
    PptxError::OoxmlFailure(_) => true
    _ => false
  }
  assert_true(rejected)
  assert_true(@dzip.archive_hard_failure(ctx.pkg.archive) is Some(_))
}
