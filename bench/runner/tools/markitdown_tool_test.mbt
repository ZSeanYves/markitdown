///|
test "markitdown tool explicit path failure stays unavailable" {
  let tool = markitdown_tool(
    explicit_path=Some("/definitely/missing/markitdown"),
  )
  assert_true(!tool.is_available())
  match tool.availability_note {
    Some(note) =>
      assert_true(
        note.contains(
          "--markitdown-path path does not exist: /definitely/missing/markitdown",
        ),
      )
    None => fail("expected explicit path failure note")
  }
}

///|
test "markitdown tool explicit path success records source" {
  let tool = markitdown_tool(explicit_path=Some("/bin/sh"))
  assert_true(tool.is_available())
  assert_true(tool.tool_version == Some("path=/bin/sh;source=explicit_arg"))
  let rows = @manifest.select_rows(
    @manifest.make_select_request(
      "smoke",
      [],
      [],
      ["txt"],
      Some(1),
      @manifest.SelectOutput::Jsonl,
      false,
    ),
  )
  assert_eq(rows.length(), 1)
  let row = rows[0]
  let command = tool.build_command(row, "/tmp/out.md", 60)
  assert_eq(command.program, "/bin/sh")
  assert_true(command.args == [row.input_path, "-o", "/tmp/out.md"])
}
