///|
async test "channel io helpers roundtrip" {
  let input_path = "pdfio_async_input.txt"
  @fs.write_file(input_path, "hello", create=0o644, truncate=true)
  let in_file = @fs.open(input_path, mode=ReadOnly)
  let input = @pdfiofs.input_of_channel(in_file)
  assert_eq(input.to_string(), "hello")
  in_file.close()
  let in_file2 = @fs.open(input_path, mode=ReadOnly)
  let bytes = @pdfiofs.bytes_of_input_channel(in_file2)
  assert_eq(@pdfio.string_of_bytes(bytes), "hello")
  in_file2.close()
  let out_path = "pdfio_async_output_bytes.txt"
  let out_file = @fs.open(out_path, mode=WriteOnly, create=0o644, truncate=true)
  let payload = @pdfio.bytes_of_string("out")
  @pdfiofs.bytes_to_output_channel(out_file, payload)
  out_file.close()
  let out_path2 = "pdfio_async_output_channel.txt"
  let out_file2 = @fs.open(
    out_path2,
    mode=WriteOnly,
    create=0o644,
    truncate=true,
  )
  let output = @pdfiofs.output_of_channel(out_file2)
  let big = "a".repeat(5000)
  (output.output_string)(big)
  (output.seek_out)(0)
  (output.output_byte)('b'.to_int())
  let out_len = (output.out_channel_length)()
  assert_true(out_len >= 1)
  (output.flush)()
  ignore(out_len)
  out_file2.close()
  @fs.remove(input_path)
  @fs.remove(out_path)
  @fs.remove(out_path2)
}
