///|
test "stdin reader returns an empty payload for a zero-byte probe" {
  assert_eq(cli_read_stdin(0).length(), 0)
}
