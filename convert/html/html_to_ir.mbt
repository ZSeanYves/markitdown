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
          @cor.Block::RichHeading(
            clamp_heading(level, max_h),
            html_inlines_to_ir(xs),
          ),
        )
      HtmlNode::Paragraph(xs) => {
        let blocks = paragraph_inlines_to_blocks(xs, ctx)
        for b in blocks {
          out.push(b)
        }
      }
      HtmlNode::Figure(img, caption) =>
        match figure_to_image_block(img, caption, ctx) {
          Some(b) => out.push(b)
          None => ()
        }
      HtmlNode::ListItem(ordered, level, children) =>
        match list_item_children_to_inlines(children, max_h) {
          Some(inlines) =>
            out.push(@cor.Block::RichListItem(ordered, level, inlines))
          None =>
            out.push(
              @cor.Block::ListItem(
                ordered,
                level,
                list_item_children_to_text(children, max_h),
              ),
            )
        }
      HtmlNode::BlockQuote(children) =>
        match quote_children_to_inlines(children, max_h) {
          Some(inlines) => out.push(@cor.Block::RichBlockQuote(inlines))
          None =>
            out.push(
              @cor.Block::BlockQuote(quote_children_to_text(children, max_h)),
            )
        }
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
  let mut buf : Array[@cor.Inline] = []

  for x in xs {
    match x {
      HtmlInline::Text(t) => buf.push(@cor.Inline::Text(t))
      HtmlInline::Break => buf.push(@cor.Inline::Break)
      HtmlInline::Link(text, href) =>
        buf.push(
          @cor.Inline::Link(text.trim().to_string(), href.trim().to_string()),
        )
      HtmlInline::Image(alt, title, src) => {
        if render_ir_inlines(buf).trim() != "" {
          out.push(@cor.Block::RichParagraph(buf))
        }
        buf = []

        match export_local_html_image(ctx, src) {
          Some(path) =>
            out.push(
              @cor.Block::ImageBlock({
                path,
                alt_text: normalized_optional_text(alt),
                title: normalize_optional_html_attr(title),
                caption: None,
                origin: None,
              }),
            )
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

  if render_ir_inlines(buf).trim() != "" {
    out.push(@cor.Block::RichParagraph(buf))
  }

  out
}

///|
fn html_inlines_to_ir(xs : Array[HtmlInline]) -> Array[@cor.Inline] {
  let out : Array[@cor.Inline] = []
  for x in xs {
    match x {
      HtmlInline::Text(t) => out.push(@cor.Inline::Text(t))
      HtmlInline::Break => out.push(@cor.Inline::Break)
      HtmlInline::Link(text, href) => out.push(@cor.Inline::Link(text, href))
      HtmlInline::Image(alt, _title, _src) =>
        out.push(
          @cor.Inline::Text(
            if alt.trim() == "" {
              "image"
            } else {
              alt.trim().to_string()
            },
          ),
        )
    }
  }
  out
}

///|
fn render_ir_inlines(xs : Array[@cor.Inline]) -> String {
  let mut out = ""
  for x in xs {
    match x {
      @cor.Inline::Text(t) => out = out + t
      @cor.Inline::Break => out = out + "<br>"
      @cor.Inline::Link(text, href) => out = out + text + href
    }
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

  let abs_path_opt = resolve_html_local_image_path(ctx.input_dir, src0)
  match abs_path_opt {
    None => return None
    Some(abs_path) => {
      let data = @fs.read_file_to_bytes(abs_path) catch { _ => return None }
      let ext = image_ext_from_src(src0)
      let rel_out = @cor.next_image_asset_rel_path_unique(
        ctx.next_idx,
        ext,
        ctx.out_dir,
      )
      let dst = ctx.out_dir + "/" + rel_out
      @fs.write_bytes_to_file(dst, data) catch {
        _ => return None
      }

      ctx.by_src.set(src0, rel_out)
      Some(rel_out)
    }
  }
}

///|
/// Resolve local HTML image path conservatively.
/// Prefer same-directory relative paths; if missing, allow a narrow fallback
/// to module-style sample layout where assets live under sibling `image/`.
fn resolve_html_local_image_path(input_dir : String, src0 : String) -> String? {
  let direct = join_dir_and_rel(input_dir, src0)
  if @fs.path_exists(direct) {
    return Some(direct)
  }

  let parent = dirname_of_path(input_dir)
  if parent == "" || parent == input_dir {
    return None
  }

  let sibling_image = join_dir_and_rel(join_dir_and_rel(parent, "image"), src0)
  if @fs.path_exists(sibling_image) {
    return Some(sibling_image)
  }

  None
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
fn list_item_children_to_inlines(
  children : Array[HtmlNode],
  max_h : Int,
) -> Array[@cor.Inline]? {
  let _ = max_h
  // RichListItem is only safe for inline-only simple list items.
  // Any multi-child or block-mixed structure must keep legacy block semantics.
  if children.length() != 1 {
    return None
  }
  match children[0] {
    HtmlNode::Paragraph(xs) =>
      if html_inlines_are_simple_inline_only(xs) {
        let out = html_inlines_to_ir(xs)
        if render_ir_inlines(out).trim() == "" {
          None
        } else {
          Some(out)
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn html_inlines_are_simple_inline_only(xs : Array[HtmlInline]) -> Bool {
  if xs.length() == 0 {
    return false
  }
  for x in xs {
    match x {
      HtmlInline::Text(_) => ()
      HtmlInline::Break => ()
      HtmlInline::Link(_, _) => ()
      HtmlInline::Image(_, _, _) => return false
    }
  }
  true
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
    HtmlNode::Figure(_img, caption) => render_inlines(caption)
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
fn quote_children_to_inlines(
  children : Array[HtmlNode],
  max_h : Int,
) -> Array[@cor.Inline]? {
  let _ = max_h
  // RichBlockQuote is only safe for single-paragraph inline-only blockquote.
  if children.length() != 1 {
    return None
  }
  match children[0] {
    HtmlNode::Paragraph(xs) =>
      if html_inlines_are_simple_inline_only(xs) {
        let out = html_inlines_to_ir(xs)
        if render_ir_inlines(out).trim() == "" {
          None
        } else {
          Some(out)
        }
      } else {
        None
      }
    _ => None
  }
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
    HtmlNode::Figure(_img, caption) => render_inlines(caption)
  }
}

///|
fn figure_to_image_block(
  img : HtmlInline,
  caption : Array[HtmlInline],
  ctx : HtmlImageExportCtx,
) -> @cor.Block? {
  match img {
    HtmlInline::Image(alt, title, src) =>
      match export_local_html_image(ctx, src) {
        Some(path) =>
          Some(
            @cor.Block::ImageBlock({
              path,
              alt_text: normalized_optional_text(alt),
              title: normalize_optional_html_attr(title),
              caption: normalized_optional_text(render_inlines(caption)),
              origin: None,
            }),
          )
        None => None
      }
    _ => None
  }
}

///|
fn normalized_optional_text(s : String) -> String? {
  let t = s.trim().to_string()
  if t == "" {
    None
  } else {
    Some(t)
  }
}

///|
fn normalize_optional_html_attr(s : String?) -> String? {
  match s {
    Some(raw) => normalized_optional_text(raw)
    None => None
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
