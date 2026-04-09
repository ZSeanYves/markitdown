///|
test "html blockquote paragraph with br keeps inline breaks" {
  let nodes = [
    HtmlNode::BlockQuote([
      HtmlNode::Paragraph([
        HtmlInline::Text("Line 1"),
        HtmlInline::Break,
        HtmlInline::Text("Line 2"),
      ]),
    ]),
  ]

  let blocks = nodes_to_blocks(nodes, 6)

  assert_eq(blocks.length(), 1)
  match blocks[0] {
    @cor.Block::BlockQuote(text) => assert_eq(text, "Line 1<br>Line 2")
    _ => assert_eq(false, true)
  }
}
