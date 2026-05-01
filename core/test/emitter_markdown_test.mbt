///|
test "rich table with explicit header row emits markdown header" {
  let doc = @cor.new_document()
  @cor.push(
    doc,
    @cor.Block::RichTable({
      rows: [["Name", "Role"], ["Ada", "Engineer"], ["Grace", "Admiral"]],
      header_rows: 1,
    }),
  )

  let expected = "| Name | Role |\n| --- | --- |\n| Ada | Engineer |\n| Grace | Admiral |\n"
  assert_eq(@cor.emit_markdown(doc), expected)
}

///|
test "rich table without header emits synthetic markdown headers" {
  let doc = @cor.new_document()
  @cor.push(
    doc,
    @cor.Block::RichTable({
      rows: [["Ada", "Engineer"], ["Grace", "Admiral"]],
      header_rows: 0,
    }),
  )

  let expected = "| Column 1 | Column 2 |\n| --- | --- |\n| Ada | Engineer |\n| Grace | Admiral |\n"
  assert_eq(@cor.emit_markdown(doc), expected)
}
