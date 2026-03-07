///|
fn nodes_to_blocks(nodes : Array[HtmlNode], max_h : Int) -> Array[@cor.Block] {
  let out : Array[@cor.Block] = []

  for node in nodes {
    match node {
      HtmlNode::Heading(level, text) => {
        out.push(@cor.Block::Heading(clamp_heading(level, max_h), text))
        out.push(@cor.Block::BlankLine)
      }
      HtmlNode::Paragraph(text) => {
        out.push(@cor.Block::Paragraph(text))
        out.push(@cor.Block::BlankLine)
      }
      HtmlNode::ListItem(text) => {
        out.push(@cor.Block::Paragraph("- " + text))
      }
      HtmlNode::BlockQuote(text) => {
        out.push(@cor.Block::Paragraph("> " + text))
        out.push(@cor.Block::BlankLine)
      }
      HtmlNode::CodeBlock(text) => {
        out.push(@cor.Block::Paragraph("```"))
        for sv in text.split("\n") {
          out.push(@cor.Block::Paragraph(sv.to_string()))
        }
        out.push(@cor.Block::Paragraph("```"))
        out.push(@cor.Block::BlankLine)
      }
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
