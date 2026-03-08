///|
fn nodes_to_blocks(nodes : Array[HtmlNode], max_h : Int) -> Array[@cor.Block] {
  let out : Array[@cor.Block] = []

  for node in nodes {
    match node {
      HtmlNode::Heading(level, text) =>
        out.push(@cor.Block::Heading(clamp_heading(level, max_h), text))
      HtmlNode::Paragraph(text) => out.push(@cor.Block::Paragraph(text))
      HtmlNode::ListItem(text) => out.push(@cor.Block::ListItem(false, 0, text))
      HtmlNode::BlockQuote(text) => out.push(@cor.Block::BlockQuote(text))
      HtmlNode::CodeBlock(text) => out.push(@cor.Block::CodeBlock(text))
      HtmlNode::Table(rows) => out.push(@cor.Block::Table(rows))
    }
  }

  out
}

///|
fn clamp_heading(level : Int, max_h : Int) -> Int {
  if level < 1 {
    1
  } else if level > max_h {
    max_h
  } else {
    level
  }
}
