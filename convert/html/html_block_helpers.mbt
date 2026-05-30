///|
fn has_block_like_tag_in_range(bs : Bytes, start : Int, end_ : Int) -> Bool {
  let open_p = pat("<p")
  let open_blockquote = pat("<blockquote")
  let open_pre = pat("<pre")
  let open_table = pat("<table")
  let open_ul = pat("<ul")
  let open_ol = pat("<ol")

  let p0 = find_bytes(bs, open_p, start)
  match p0 {
    Some(i) => if i < end_ { return true }
    None => ()
  }

  let q0 = find_bytes(bs, open_blockquote, start)
  match q0 {
    Some(i) => if i < end_ { return true }
    None => ()
  }

  let r0 = find_bytes(bs, open_pre, start)
  match r0 {
    Some(i) => if i < end_ { return true }
    None => ()
  }

  let s0 = find_bytes(bs, open_table, start)
  match s0 {
    Some(i) => if i < end_ { return true }
    None => ()
  }

  let t0 = find_bytes(bs, open_ul, start)
  match t0 {
    Some(i) => if i < end_ { return true }
    None => ()
  }

  let u0 = find_bytes(bs, open_ol, start)
  match u0 {
    Some(i) => if i < end_ { return true }
    None => ()
  }

  false
}

///|
/// <pre> inner bytes -> code-like text
/// keep newlines as much as possible, only strip tags and unescape
fn html_pre_text_from_bytes(inner : Bytes) -> String {
  let text_bs = strip_tags_bytes(inner)
  let s0 = @utf8.decode(text_bs, ignore_bom=false) catch { _ => "" }

  html_unescape(s0.replace(old="\r\n", new="\n").replace(old="\r", new="\n"))
  .trim()
  .to_owned()
}

///|
/// trim one pending paragraph as a whole:
/// - preserve internal spaces between raw text fragments
/// - strip only leading/trailing whitespace introduced by source indentation
fn normalize_pending_paragraph(xs : Array[HtmlInline]) -> Array[HtmlInline] {
  let s = render_inlines(merge_adjacent_text_inlines(xs)).trim().to_owned()
  if s == "" {
    []
  } else {
    [HtmlInline::Text(s)]
  }
}

///|
fn flush_pending_paragraph(
  out : Array[HtmlNode],
  pending : Array[HtmlInline],
) -> Unit {
  let xs = normalize_pending_paragraph(pending)
  if !inlines_is_blank(xs) {
    out.push(HtmlNode::Paragraph(xs))
  }
  pending.clear()
}

///|
fn inlines_is_blank(xs : Array[HtmlInline]) -> Bool {
  render_inlines(xs).trim() == ""
}

///|
fn quote_children_is_blank(xs : Array[HtmlNode]) -> Bool {
  xs.length() == 0
}

///|
fn list_item_children_is_blank(xs : Array[HtmlNode]) -> Bool {
  xs.length() == 0
}

///|
/// for raw text segments between tags:
/// trim leading/trailing whitespace introduced by source indentation
fn trim_inlines_to_paragraph(xs : Array[HtmlInline]) -> Array[HtmlInline] {
  let s = render_inlines(xs).trim().to_owned()
  if s == "" {
    []
  } else {
    [HtmlInline::Text(s)]
  }
}
