///|
fn nodes_to_blocks(nodes : Array[HtmlNode], max_h : Int) -> Array[@cor.Block] {
  let out : Array[@cor.Block] = []

  for node in nodes {
    match node {
      HtmlNode::Heading(level, xs) =>
        out.push(
          @cor.Block::Heading(clamp_heading(level, max_h), render_inlines(xs)),
        )
      HtmlNode::Paragraph(xs) =>
        out.push(@cor.Block::Paragraph(render_inlines(xs)))
      HtmlNode::ListItem(ordered, level, xs) =>
        out.push(@cor.Block::ListItem(ordered, level, render_inlines(xs)))
      HtmlNode::BlockQuote(xs) =>
        out.push(@cor.Block::BlockQuote(render_inlines(xs)))
      HtmlNode::CodeBlock(text) => out.push(@cor.Block::CodeBlock(text))
      HtmlNode::Table(rows) => {
        let out_rows : Array[Array[String]] = []
        for row in rows {
          let out_row : Array[String] = []
          for cell in row {
            out_row.push(render_inlines(cell))
          }
          out_rows.push(out_row)
        }
        out.push(@cor.Block::Table(out_rows))
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
