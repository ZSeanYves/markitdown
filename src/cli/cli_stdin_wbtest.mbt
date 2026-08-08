///|
#cfg(target="native")
test "main cli routes dash input through the stdin source" {
  let source = cli_input_source(cli_options("-", None, Some(Txt), Markdown))
  assert_true(@input.input_path(source) is None)
  assert_true(@input.input_bytes(source) is Some(_))
}
