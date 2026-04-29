///|
async test "root facade read_file" {
  let pdf = read_file("testdata/logo.pdf")
  assert_true(pdf.objcard() > 0)
}

///|
async test "root facade write_file" {
  let pdf = @pdf.Pdf::empty()
  let filename = "tmp/mbtpdf_facade_write_test.pdf"
  write_file(pdf, filename)
  assert_true(@fs.exists(filename))
  @fs.remove(filename)
}
