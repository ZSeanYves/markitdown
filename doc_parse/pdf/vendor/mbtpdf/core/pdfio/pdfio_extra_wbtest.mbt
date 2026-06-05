///|
test "bytes_of_charlist and bytes_of_arraylist" {
  let bytes = bytes_of_charlist(['A', 'B'])
  assert_eq(string_of_bytes(bytes), "AB")
  let arrays : Array[Array[Int]] = [[65, 66], [67]]
  let bytes2 = bytes_of_arraylist(arrays)
  assert_eq(string_of_bytes(bytes2), "ABC")
}

///|
test "copybytes returns an independent buffer" {
  let bytes = bytes_of_string("ab")
  let copied = copybytes(bytes)
  bset(copied, 0, 'z'.to_int())
  assert_eq(string_of_bytes(copied), "zb")
  assert_eq(string_of_bytes(bytes), "ab")
}
