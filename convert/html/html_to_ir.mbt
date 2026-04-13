///|
priv struct HtmlImageExportCtx {
  input_dir : String
  out_dir : String
  next_idx : Ref[Int]
  by_src : Map[String, String]
}

///|
fn nodes_to_blocks(
  nodes : Array[HtmlNode],
  max_h : Int,
  input_path : String,
  out_dir : String,
) -> Array[@cor.Block] raise {
  let out : Array[@cor.Block] = []
  let ctx = new_html_image_export_ctx(input_path, out_dir)

  for node in nodes {
    match node {
      HtmlNode::Heading(level, xs) =>
        out.push(
          @cor.Block::Heading(clamp_heading(level, max_h), render_inlines(xs)),
        )
      HtmlNode::Paragraph(xs) => {
        let blocks = paragraph_inlines_to_blocks(xs, ctx)
        for b in blocks {
          out.push(b)
        }
      }
      HtmlNode::ListItem(ordered, level, children) =>
        out.push(
          @cor.Block::ListItem(
            ordered,
            level,
            list_item_children_to_text(children, max_h),
          ),
        )
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
fn paragraph_inlines_to_blocks(
  xs : Array[HtmlInline],
  ctx : HtmlImageExportCtx,
) -> Array[@cor.Block] {
  let out : Array[@cor.Block] = []
  let mut buf = ""

  for x in xs {
    match x {
      HtmlInline::Text(t) => buf = buf + t
      HtmlInline::Break => buf = buf + "<br>"
      HtmlInline::Image(alt, src) => {
        let t = buf.trim().to_string()
        if t != "" {
          out.push(@cor.Block::Paragraph(t))
        }
        buf = ""

        match export_local_html_image(ctx, src) {
          Some(path) => {
            let a = if alt.trim() == "" {
              "image"
            } else {
              alt.trim().to_string()
            }
            out.push(@cor.Block::Image(a, path))
          }
          None => {
            let fallback = if alt.trim() == "" {
              "image"
            } else {
              alt.trim().to_string()
            }
            out.push(@cor.Block::Paragraph("[" + fallback + "]"))
          }
        }
      }
    }
  }

  let tail = buf.trim().to_string()
  if tail != "" {
    out.push(@cor.Block::Paragraph(tail))
  }

  out
}

///|
fn new_html_image_export_ctx(
  input_path : String,
  out_dir : String,
) -> HtmlImageExportCtx raise {
  let ctx : HtmlImageExportCtx = {
    input_dir: dirname_of_path(input_path),
    out_dir,
    next_idx: { val: 0 },
    by_src: Map::new(),
  }

  if out_dir != "" {
    let assets_dir = out_dir + "/assets"
    if !@fs.path_exists(assets_dir) {
      let _ = @fs.create_dir(assets_dir)
    }
  }

  ctx
}

///|
fn export_local_html_image(
  ctx : HtmlImageExportCtx,
  src_raw : String,
) -> String? {
  if ctx.out_dir == "" {
    return None
  }

  let src0 = strip_query_and_hash(src_raw.trim().to_string())
  if src0 == "" {
    return None
  }
  if is_remote_or_unsupported_html_image_src(src0) {
    return None
  }
  if src0.contains("..") {
    return None
  }

  if ctx.by_src.contains(src0) {
    return ctx.by_src.get(src0)
  }

  let abs_path = join_dir_and_rel(ctx.input_dir, src0)
  if !@fs.path_exists(abs_path) {
    return None
  }

  let data = @fs.read_file_to_bytes(abs_path) catch { _ => return None }
  let ext = image_ext_from_src(src0)
  let rel_out = @cor.next_image_asset_rel_path(ctx.next_idx, ext)
  let dst = ctx.out_dir + "/" + rel_out
  @fs.write_bytes_to_file(dst, data) catch {
    _ => return None
  }

  ctx.by_src.set(src0, rel_out)
  Some(rel_out)
}

///|
fn is_remote_or_unsupported_html_image_src(src : String) -> Bool {
  let lower = src.to_lower()
  lower.has_prefix("http://") ||
  lower.has_prefix("https://") ||
  lower.has_prefix("data:") ||
  lower.has_prefix("//") ||
  lower.has_prefix("/")
}

///|
fn strip_query_and_hash(src : String) -> String {
  let mut end = src.length()
  for i in 0..<src.length() {
    if src[i] == '?' || src[i] == '#' {
      end = i
      break
    }
  }
  src[:end].to_string()
}

///|
fn dirname_of_path(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' {
      last = i
    }
  }
  if last < 0 {
    "."
  } else if last == 0 {
    "/"
  } else {
    path[:last].to_string()
  }
}

///|
fn join_dir_and_rel(dir : String, rel : String) -> String {
  if dir == "" || dir == "." {
    rel
  } else if dir.has_suffix("/") {
    dir + rel
  } else {
    dir + "/" + rel
  }
}

///|
fn image_ext_from_src(src : String) -> String {
  let lower = src.to_lower()
  if lower.has_suffix(".png") {
    return "png"
  }
  if lower.has_suffix(".jpg") {
    return "jpg"
  }
  if lower.has_suffix(".jpeg") {
    return "jpeg"
  }
  if lower.has_suffix(".gif") {
    return "gif"
  }
  if lower.has_suffix(".bmp") {
    return "bmp"
  }
  if lower.has_suffix(".webp") {
    return "webp"
  }
  if lower.has_suffix(".tif") || lower.has_suffix(".tiff") {
    return "tiff"
  }
  "img"
}

///|
fn list_item_children_to_text(
  children : Array[HtmlNode],
  max_h : Int,
) -> String {
  let mut out = ""
  let mut first = true

  for node in children {
    let s = list_item_child_to_text(node, max_h)
    if s.trim() != "" {
      if first {
        out = s
        first = false
      } else {
        let sep = if is_list_item_node(node) { "\n" } else { "\n\n" }
        out = out + sep + s
      }
    }
  }

  out
}

///|
fn is_list_item_node(node : HtmlNode) -> Bool {
  match node {
    HtmlNode::ListItem(_, _, _) => true
    _ => false
  }
}

///|
fn list_item_child_to_text(node : HtmlNode, max_h : Int) -> String {
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
    HtmlNode::ListItem(ordered, level, children) => {
      let mut indent = ""
      let mut i = 0
      while i < level {
        indent = indent + "  "
        i = i + 1
      }
      let body = list_item_children_to_text(children, max_h)
      if ordered {
        indent + "1. " + body
      } else {
        indent + "- " + body
      }
    }
    HtmlNode::BlockQuote(children) => quote_children_to_text(children, max_h)
    HtmlNode::CodeBlock(text) => "```\n" + text + "\n```"
    HtmlNode::Table(rows) => render_table_markdown(rows)
  }
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
    HtmlNode::ListItem(ordered, level, children) => {
      let mut indent = ""
      let mut i = 0
      while i < level {
        indent = indent + "  "
        i = i + 1
      }
      let body = list_item_children_to_text(children, max_h)
      if ordered {
        indent + "1. " + body
      } else {
        indent + "- " + body
      }
    }
    HtmlNode::BlockQuote(children) => quote_children_to_text(children, max_h)
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
