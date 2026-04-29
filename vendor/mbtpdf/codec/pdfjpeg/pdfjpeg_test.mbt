///|
test "get_jpeg_data reads until EOI marker" {
  let bytes = @pdfio.bytes_of_list([0xff, 0xd8, 0x00, 0xff, 0xd9, 0x00])
  let input = @pdfio.Input::of_bytes(bytes)
  let data = @pdfjpeg.PdfJpeg::new().get_jpeg_data(input)
  assert_eq(@pdfio.bytes_size(data), 5)
  assert_eq(@pdfio.bget_unsafe(data, 0), 0xff)
  assert_eq(@pdfio.bget_unsafe(data, 1), 0xd8)
  assert_eq(@pdfio.bget_unsafe(data, 3), 0xff)
  assert_eq(@pdfio.bget_unsafe(data, 4), 0xd9)
}

///|
test "get_jpeg_data errors on missing EOI" {
  let bytes = @pdfio.bytes_of_list([0x00, 0x01, 0x02])
  let input = @pdfio.Input::of_bytes(bytes)
  let res : Result[@pdfio.MutableBytes, Error] = try? @pdfjpeg.PdfJpeg::new().get_jpeg_data(
    input,
  )
  assert_true(res is Err(_))
}

///|
test "get_jpeg_data treats stray 0xD9 as data" {
  let bytes = @pdfio.bytes_of_list([
    0xff, 0xd8, 0x00, 0xd9, 0x00, 0xff, 0xd9, 0x00,
  ])
  let input = @pdfio.Input::of_bytes(bytes)
  let data = @pdfjpeg.PdfJpeg::new().get_jpeg_data(input)
  assert_eq(@pdfio.bytes_size(data), 7)
  assert_eq(@pdfio.bget_unsafe(data, 3), 0xd9)
  assert_eq(@pdfio.bget_unsafe(data, 5), 0xff)
  assert_eq(@pdfio.bget_unsafe(data, 6), 0xd9)
}
