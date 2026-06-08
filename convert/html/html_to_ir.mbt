///|
/// HTML parser-fact -> unified IR product helpers.
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
  note_definitions : Array[@cor.NoteDefinition]
  semantic_lowering_state : HtmlSemanticLoweringState?
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
      HtmlInline::NoteRef(note) => buf.push(@cor.Inline::NoteRef(note))
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
fn render_ir_inlines(xs : Array[@cor.Inline]) -> String {
  let mut out = ""
  for x in xs {
    match x {
      @cor.Inline::Text(t) => out = out + t
      @cor.Inline::Break => out = out + "<br>"
      @cor.Inline::Link(text, href) => out = out + text + href
      @cor.Inline::NoteRef(note) => {
        let marker = note.marker.trim().to_owned()
        if note.body_status == @cor.NoteBodyStatus::Resolved &&
          note.note_id.trim() != "" {
          out = out + "[^" + note.note_id.trim().to_owned() + "]"
        } else if marker != "" {
          out = out +
            (if marker.has_prefix("^") { marker } else { "^" + marker })
        }
      }
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
    by_src: Map([]),
    src_by_asset_path: Map([]),
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
  let started = html_active_profile_start_tick()
  if ctx.out_dir == "" {
    return None
  }

  let src0 = strip_query_and_hash(src_raw.trim().to_owned())
  if src0 == "" {
    return None
  }
  if is_remote_or_unsupported_html_image_src(src0) {
    profile_html_remote_asset_candidate()
    return None
  }
  if src0.contains("..") {
    profile_html_unresolved_local_asset()
    return None
  }

  if ctx.by_src.contains(src0) {
    let rel_out = ctx.by_src.get(src0)
    match rel_out {
      Some(path) => {
        profile_html_cached_asset_hit()
        if !ctx.src_by_asset_path.contains(path) {
          ctx.src_by_asset_path.set(path, src0)
        }
        return Some(path)
      }
      None => return None
    }
  }

  let abs_path_opt = resolve_html_local_image_path(ctx.input_dir, src0)
  profile_html_asset_discovery_elapsed_ms(html_profile_elapsed_since(started))
  match abs_path_opt {
    None => {
      profile_html_unresolved_local_asset()
      return None
    }
    Some(abs_path) => {
      let export_started = html_active_profile_start_tick()
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
      profile_html_local_asset_exported()
      profile_html_asset_export_elapsed_ms(
        html_profile_elapsed_since(export_started),
      )
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
