///|
test "read_header finds version at offset" {
  let input = @pdfio.Input::of_string("junk%PDF-1.7\n")
  let (major, minor) = read_header(PdfRead::new(), input)
  assert_eq(major, 1)
  assert_eq(minor, 7)
}

///|
test "read_header returns default on malformed major" {
  let input = @pdfio.Input::of_string("%PDF-x.y")
  let (major, minor) = read_header(PdfRead::new(), input)
  assert_eq(major, 2)
  assert_eq(minor, 0)
}

///|
test "read_header errors on missing minor digits" {
  let input = @pdfio.Input::of_string("%PDF-1.X")
  let res : Result[(Int, Int), Error] = try? read_header(PdfRead::new(), input)
  assert_true(res is Err(_))
}

///|
test "is_linearized detects dictionary flag" {
  let input = @pdfio.Input::of_string("%PDF-1.4\n<< /Linearized 1 >>")
  assert_true(PdfRead::new().is_linearized(input))
}
