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
      HtmlNode::BlockQuote(children) =>
        out.push(
          @cor.Block::BlockQuote(quote_children_to_text(children, max_h)),
        )
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
fn quote_children_to_text(children : Array[HtmlNode], max_h : Int) -> String {
  let mut out = ""
  let mut first = true

  for node in children {
    let s = quote_node_to_text(node, max_h)
    if s.trim() != "" {
      if first {
        out = s
        first = false
      } else {
        out = out + "\n\n" + s
      }
    }
  }

  out
}

///|
fn quote_node_to_text(node : HtmlNode, max_h : Int) -> String {
  match node {
    HtmlNode::Heading(level, xs) => {
      let h = clamp_heading(level, max_h)
      let mut prefix = ""
      let mut i = 0
      while i < h {
        prefix = prefix + "#"
        i = i + 1
      }
      prefix + " " + render_inlines(xs)
    }
    HtmlNode::Paragraph(xs) => render_inlines(xs)
    HtmlNode::ListItem(ordered, level, xs) => {
      let mut indent = ""
      let mut i = 0
      while i < level {
        indent = indent + "  "
        i = i + 1
      }
      if ordered {
        indent + "1. " + render_inlines(xs)
      } else {
        indent + "- " + render_inlines(xs)
      }
    }
    HtmlNode::BlockQuote(children) =>
      // 先递归压平成文本，再交给外层 quote renderer
      quote_children_to_text(children, max_h)
    HtmlNode::CodeBlock(text) => "```\n" + text + "\n```"
    HtmlNode::Table(rows) => render_table_markdown(rows)
  }
}

///|
fn render_table_markdown(rows : Array[Array[Array[HtmlInline]]]) -> String {
  if rows.length() == 0 {
    return ""
  }

  let mut out = ""

  let header = rows[0]
  out = out + "|"
  for cell in header {
    out = out + " " + render_inlines(cell) + " |"
  }

  out = out + "\n|"
  for _ in header {
    out = out + " --- |"
  }

  let mut i = 1
  while i < rows.length() {
    let row = rows[i]
    out = out + "\n|"
    for cell in row {
      out = out + " " + render_inlines(cell) + " |"
    }
    i = i + 1
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
