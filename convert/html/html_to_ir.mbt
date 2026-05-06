///|
/// HTML node -> unified IR projection.
///
/// Design boundaries:
/// - figure/figcaption/img alt/title are mapped as structured image context
/// - remote images are not force-downloaded/exported; local export is best-effort
/// - container reconstruction is conservative to avoid speculative DOM semantics
priv struct HtmlImageExportCtx {
  input_dir : String
  out_dir : String
  next_idx : Ref[Int]
  by_src : Map[String, String]
  src_by_asset_path : Map[String, String]
}

///|
priv struct HtmlBlocksResult {
  blocks : Array[@cor.Block]
  asset_source_paths : Map[String, String]
  block_origins : Array[@cor.Origin?]
}

///|
fn nodes_to_blocks(
  nodes : Array[HtmlNode],
  max_h : Int,
  input_path : String,
  out_dir : String,
) -> HtmlBlocksResult raise {
  let out : Array[@cor.Block] = []
  let origins : Array[@cor.Origin?] = []
  let ctx = new_html_image_export_ctx(input_path, out_dir)
  let source_name = @cor.basename(input_path)
  let mut object_counter = 0

  for node in nodes {
    object_counter += 1
    let origin : @cor.Origin? = Some({
      source_name: Some(source_name),
      page: None,
      slide: None,
      sheet: None,
      block_index: None,
      heading_path: None,
      line_start: None,
      line_end: None,
      row_index: None,
      column_index: None,
      object_ref: Some(
        "html:" + html_node_origin_kind(node) + ":" + object_counter.to_string(),
      ),
      relationship_id: None,
      key_path: Some(html_node_origin_key_path(node, object_counter)),
    })
    match node {
      HtmlNode::Heading(level, xs) => {
        out.push(
          @cor.Block::RichHeading(
            clamp_heading(level, max_h),
            html_inlines_to_ir(xs),
          ),
        )
        origins.push(origin)
      }
      HtmlNode::Paragraph(xs) => {
        let blocks = paragraph_inlines_to_blocks(xs, ctx)
        for b in blocks {
          out.push(b)
          origins.push(origin)
        }
      }
      HtmlNode::Figure(img, caption) =>
        match figure_to_image_block(img, caption, ctx) {
          Some(b) => {
            out.push(b)
            origins.push(origin)
          }
          None => ()
        }
      HtmlNode::ListItem(ordered, level, children) =>
        match list_item_children_to_inlines(children, max_h) {
          Some(inlines) => {
            out.push(@cor.Block::RichListItem(ordered, level, inlines))
            origins.push(origin)
          }
          None => {
            out.push(
              @cor.Block::ListItem(
                ordered,
                level,
                list_item_children_to_text(children, max_h),
              ),
            )
            origins.push(origin)
          }
        }
      HtmlNode::BlockQuote(children) =>
        match quote_children_to_inlines(children, max_h) {
          Some(inlines) => {
            out.push(@cor.Block::RichBlockQuote(inlines))
            origins.push(origin)
          }
          None => {
            out.push(
              @cor.Block::BlockQuote(quote_children_to_text(children, max_h)),
            )
            origins.push(origin)
          }
        }
      HtmlNode::CodeBlock(text) => {
        out.push(@cor.Block::CodeBlock(text))
        origins.push(origin)
      }
      HtmlNode::Table(table) => {
        let out_rows : Array[Array[String]] = []
        for row in table.rows {
          let out_row : Array[String] = []
          for cell in row {
            out_row.push(render_inlines(cell))
          }
          out_rows.push(out_row)
        }
        let hints = html_table_hints(table)
        out.push(
          @cor.Block::RichTable({
            rows: out_rows,
            header_rows: table.header_rows,
            hints,
          }),
        )
        origins.push(origin)
      }
    }
  }

  {
    blocks: out,
    asset_source_paths: ctx.src_by_asset_path,
    block_origins: origins,
  }
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
      HtmlInline::Link(text, href) => {
        let t = text.trim().to_owned()
        let h = href.trim().to_owned()
        if t != "" && h != "" {
          buf.push(@cor.Inline::Link(t, h))
        } else if t != "" {
          buf.push(@cor.Inline::Text(t))
        }
      }
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
                origin: Some(
                  new_html_image_origin(ctx.input_dir, src, "inline-img"),
                ),
              }),
            )
          None => {
            let fallback = if alt.trim() == "" {
              "image"
            } else {
              alt.trim().to_owned()
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
              alt.trim().to_owned()
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
    src_by_asset_path: Map::new(),
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

  let src0 = strip_query_and_hash(src_raw.trim().to_owned())
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
    let rel_out = ctx.by_src.get(src0)
    match rel_out {
      Some(path) => {
        if !ctx.src_by_asset_path.contains(path) {
          ctx.src_by_asset_path.set(path, src0)
        }
        return Some(path)
      }
      None => return None
    }
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
      ctx.src_by_asset_path.set(rel_out, src0)
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
  src[:end].to_owned()
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
    path[:last].to_owned()
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
    HtmlNode::Table(table) => render_table_markdown(table.rows)
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
    HtmlNode::Table(table) => render_table_markdown(table.rows)
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
              origin: Some(
                new_html_image_origin(ctx.input_dir, src, "figure-img"),
              ),
            }),
          )
        None => None
      }
    _ => None
  }
}

///|
fn normalized_optional_text(s : String) -> String? {
  let t = s.trim().to_owned()
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

///|
fn html_table_hints(table : HtmlTable) -> @cor.TableHints? {
  let span_cells = if table.span_cells.length() == 0 {
    None
  } else {
    let out : Array[@cor.TableSpanHint] = []
    for span in table.span_cells {
      out.push({
        row_index: span.row_index,
        column_index: span.column_index,
        rowspan: span.rowspan,
        colspan: span.colspan,
        text: span.text,
      })
    }
    Some(out)
  }

  Some({
    format: Some("html"),
    sheet_state: None,
    merged_ranges: None,
    formula_cells: None,
    semantic_types: None,
    span_cells,
  })
}

///|
fn html_node_origin_kind(node : HtmlNode) -> String {
  match node {
    HtmlNode::Heading(_, _) => "heading"
    HtmlNode::Paragraph(_) => "paragraph"
    HtmlNode::Figure(_, _) => "figure"
    HtmlNode::ListItem(_, _, _) => "list-item"
    HtmlNode::BlockQuote(_) => "blockquote"
    HtmlNode::CodeBlock(_) => "pre"
    HtmlNode::Table(_) => "table"
  }
}

///|
fn html_node_origin_key_path(node : HtmlNode, index : Int) -> String {
  "$.html[" + index.to_string() + "]." + html_node_origin_kind(node)
}

///|
fn new_html_image_origin(
  _input_dir : String,
  src : String,
  kind : String,
) -> @cor.Origin {
  {
    source_name: None,
    page: None,
    slide: None,
    sheet: None,
    block_index: None,
    heading_path: None,
    line_start: None,
    line_end: None,
    row_index: None,
    column_index: None,
    object_ref: Some("html:" + kind),
    relationship_id: None,
    key_path: Some("$.html.asset[" + src + "]"),
  }
}
