///|
async test "EPUB text decoder reports typed hard encoding failures without caching" {
  let pkg = wb_open_inline_epub()
  let result = try
    decode_part_text(pkg, "OPS/chapter1.xhtml", b"<p>\xFF</p>") |> Ok
  catch {
    error => Err(error)
  }
  match result {
    Err(InvalidEncoding(_)) => ()
    _ => fail("invalid UTF8 must have the explicit encoding domain")
  }
  assert_true(classify_epub_error(result.unwrap_err()).kind == InvalidEncoding)
  assert_true(@zip.archive_hard_failure(pkg.archive) is Some(_))
  assert_eq(pkg.text_part_cache.length(), 0)
}
