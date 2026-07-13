///|
test "native path cursor reads chunks without materializing the whole file" {
  let path = "input/README.md"
  let expected = @fs.read_file_to_bytes(path) catch {
    error => fail(error.to_string())
  }
  let cursor = @input.open_source_cursor(@input.input_from_path(path)).unwrap()
  assert_true(cursor.size == Some(expected.length().to_int64()))
  let prefix = @input.source_cursor_read_at(cursor, 0L, length=17).unwrap()
  assert_true(prefix == expected.view(end=17).to_owned())
  assert_true(
    @input.open_source_cursor(@input.input_from_path(path), max_bytes=1L)
    is Err(_),
  )
}

///|
test "ZIP detection reads prefix tail and central directory through Reader" {
  let bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/docx/golden.docx",
  ) catch {
    error => fail(error.to_string())
  }
  let max_request = Ref(0)
  let read_tail = Ref(false)
  let reader = @input.make_input_reader(
    fn(offset, length) {
      max_request.val = max_request.val.max(length)
      if offset > 0L {
        read_tail.val = true
      }
      let start = offset.to_int()
      let end = (start + length).min(bytes.length())
      Ok(bytes.view(start~, end~).to_owned())
    },
    size=bytes.length().to_int64(),
  )
  let detected = @input.detect_format(
    @input.input_from_reader(reader, source_name="office-blob"),
  )
  assert_true(detected.format == @input.DetectedFormat::Docx)
  assert_true(read_tail.val)
  assert_true(max_request.val < bytes.length())
}
