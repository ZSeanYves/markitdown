///|
test "bytes and int array conversions" {
  let bytes = bytes_of_list([65, 66, 67])
  assert_eq(bytes_size(bytes), 3)
  assert_eq(string_of_bytes(bytes), "ABC")
  let ints = int_array_of_bytes(bytes)
  assert_eq(ints.length(), 3)
  assert_eq(ints[0], 65)
  assert_eq(ints[2], 67)
  let roundtrip = bytes_of_int_array(ints)
  assert_eq(string_of_bytes(roundtrip), "ABC")
}

///|
test "string_of_int_arrays flattens" {
  let s = string_of_int_arrays([[65], [66, 67]])
  assert_eq(s, "ABC")
}

///|
test "input_of_string supports read_line" {
  let input = Input::of_string("first\nsecond")
  assert_eq(input.read_line(), "first")
  assert_eq(input.read_line(), "second")
  let res : Result[String, Error] = try? input.read_line()
  assert_true(res is Err(_))
}

///|
test "peek_char and read_char_back" {
  let input = Input::of_string("ab")
  assert_eq(input.peek_char(), Some('a'))
  let _ = (input.input_char)()
  let back = input.read_char_back()
  assert_eq(back, Some('a'))
}

///|
test "read_lines reads all lines" {
  let input = Input::of_string("first\nsecond\n")
  let lines = input.read_lines()
  assert_eq(lines, ["first", "second"])
}

///|
test "setinit and bytes_of_input read slices" {
  let input = Input::of_string("abcd")
  let buf = mkbytes(4)
  input.setinit(buf, 0, 4)
  assert_eq(string_of_bytes(buf), "abcd")
  let input2 = Input::of_string("abcd")
  let slice = input2.bytes_of_input(1, 2)
  assert_eq(string_of_bytes(slice), "bc")
  let res : Result[Unit, Error] = try? input2.setinit(buf, 10, 1)
  assert_true(res is Err(_))
}

///|
test "string_of_input and getinit write output" {
  let input = Input::of_string("xyz")
  assert_eq(input.to_string(), "xyz")
  let data = bytes_of_string("hi")
  let (output, buffer) = Output::of_bytes(2)
  output.getinit(data, 0, data.length())
  let out = output.extract_bytes(buffer)
  assert_eq(string_of_bytes(out), "hi")
}
