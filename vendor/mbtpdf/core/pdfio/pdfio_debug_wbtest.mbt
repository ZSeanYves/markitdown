///|
async test "input_output_of_bytes supports seek and flush" {
  let (output, buffer) = Output::of_bytes(1)
  (output.output_string)("abc")
  (output.seek_out)(0)
  (output.output_byte)('z'.to_int())
  (output.seek_out)(3)
  assert_eq((output.out_channel_length)(), 3)
  (output.flush)()
  let out = output.extract_bytes(buffer)
  assert_eq(string_of_bytes(out), "zbc")
}

///|
test "debug_next_n_chars rewinds input" {
  let input = Input::of_string("abc")
  let prev_logger = @pdfe.logger.val
  @pdfe.logger.val = _ => ()
  defer {
    @pdfe.logger.val = prev_logger
  }
  debug_next_n_chars(2, input)
  match (input.input_char)() {
    Some('a') => ()
    _ => fail("expected rewind to start")
  }
}
