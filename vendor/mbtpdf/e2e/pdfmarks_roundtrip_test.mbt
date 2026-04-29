///|
async test "pdfmarks bookmark string roundtrip through file output" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Café",
      target: @pdfdest.Destination::NullDestination,
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf_with = @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
  let dir = "tmp/pdfmarks"
  if !@fs.exists(dir) {
    @fs.mkdir(dir, permission=0o755, recursive=true)
  }
  let filename = dir + "/bookmark_string_test.pdf"
  let file = @fs.open(filename, mode=WriteOnly, create=0o644, truncate=true)
  defer file.close()
  @pdfwritefs.PdfWriteFs::new().pdf_to_channel(None, true, pdf_with, file)
  let parsed = @pdfreadfs.PdfReadFs::new().pdf_of_file(None, None, filename)
  let parsed_marks = @pdfmarks.PdfMarks::new(parsed).read_bookmarks()
  assert_eq(parsed_marks.length(), 1)
  assert_eq(parsed_marks[0].text, "Café")
  let _ : Result[Unit, Error] = try? @fs.remove(filename)

}
