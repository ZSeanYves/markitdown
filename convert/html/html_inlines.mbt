///|
priv enum HtmlInline {
  Text(String)
  Break
  Image(String, String?, String) // alt, title, src
  Link(String, String) // text, href
  NoteRef(@cor.NoteRef)
}

///|
fn html_inlines_from_bytes(inner : Bytes) -> Array[HtmlInline] {
  html_inlines_from_bytes_with_notes(inner, empty_html_note_plan())
}

///|
fn html_inlines_from_bytes_with_notes(
  inner : Bytes,
  note_plan : HtmlNotePlan,
) -> Array[HtmlInline] {
  let out : Array[HtmlInline] = []

  let lt = pat("<")
  let gt = pat(">")
  let close_script = pat("</script>")
  let close_style = pat("</style>")
  let close_noscript = pat("</noscript>")
  let close_head = pat("</head>")
  let close_comment = pat("-->")
  let mut pos = 0
  let n = inner.length()

  while pos < n {
    let lt0 = find_bytes(inner, lt, pos)
    match lt0 {
      None => {
        let tail = inner[pos:n].to_owned()
        push_text_inline(out, tail)
        break
      }
      Some(i0) => {
        if i0 > pos {
          let head = inner[pos:i0].to_owned()
          push_text_inline(out, head)
        }

        let gt0 = find_bytes(inner, gt, i0)
        match gt0 {
          None => {
            let tail = inner[i0:n].to_owned()
            push_text_inline(out, tail)
            break
          }
          Some(j0) => {
            let tag_bs = inner[i0:j0 + 1].to_owned()
            let tag0 = @utf8.decode(tag_bs, ignore_bom=false) catch { _ => "" }
            let tag = tag0.to_lower()
            let tag_name = html_open_tag_name(tag0).unwrap_or("")
            let is_close_tag = tag.has_prefix("</")

            if !is_close_tag && tag_name == "br" {
              out.push(HtmlInline::Break)
            } else if tag.has_prefix("<!--") {
              let end0 = find_bytes(inner, close_comment, i0 + 4)
              match end0 {
                Some(end) => {
                  pos = end + close_comment.length()
                  continue
                }
                None => break
              }
            } else if !is_close_tag && tag_name == "script" {
              let end0 = find_bytes_case_insensitive(
                inner, close_script, j0 + 1,
              )
              match end0 {
                Some(end) => {
                  pos = end + close_script.length()
                  continue
                }
                None => ()
              }
            } else if !is_close_tag && tag_name == "style" {
              let end0 = find_bytes_case_insensitive(
                inner, close_style, j0 + 1,
              )
              match end0 {
                Some(end) => {
                  pos = end + close_style.length()
                  continue
                }
                None => ()
              }
            } else if !is_close_tag && tag_name == "noscript" {
              let end0 = find_bytes_case_insensitive(
                inner, close_noscript, j0 + 1,
              )
              match end0 {
                Some(end) => {
                  pos = end + close_noscript.length()
                  continue
                }
                None => ()
              }
            } else if !is_close_tag && tag_name == "head" {
              let end0 = find_bytes_case_insensitive(
                inner, close_head, j0 + 1,
              )
              match end0 {
                Some(end) => {
                  pos = end + close_head.length()
                  continue
                }
                None => ()
              }
            } else if !is_close_tag && tag_name == "a" {
              let href = sanitize_html_href(
                  read_html_attr_value(tag0, "href").unwrap_or(""),
                )
                .unwrap_or("")
                .trim()
                .to_owned()
              if href != "" {
                let close_a = pat("</a>")
                let inner_start = j0 + 1
                let a_end0 = find_bytes_case_insensitive(
                  inner, close_a, inner_start,
                )
                match a_end0 {
                  Some(a_end) => {
                    let inner_bs = inner[inner_start:a_end].to_owned()
                    let text = render_inlines(html_inlines_from_bytes(inner_bs))
                      .trim()
                      .to_owned()
                    if text != "" {
                      let signature = html_note_ref_signature(href, text)
                      match note_plan.refs_by_signature.get(signature) {
                        Some(note) => out.push(HtmlInline::NoteRef(note))
                        None => out.push(HtmlInline::Link(text, href))
                      }
                    }
                    pos = a_end + close_a.length()
                    continue
                  }
                  None => ()
                }
              }
            } else if !is_close_tag && tag_name == "img" {
              let src = html_unescape(
                  read_html_attr_value(tag0, "src").unwrap_or(""),
                )
                .trim()
                .to_owned()
              if src != "" {
                let alt = html_unescape(
                  read_html_attr_value(tag0, "alt").unwrap_or(""),
                )
                let title = read_html_attr_value(tag0, "title").map(
                  html_unescape,
                )
                out.push(HtmlInline::Image(alt, title, src))
              }
            }

            pos = j0 + 1
          }
        }
      }
    }
  }

  merge_adjacent_text_inlines(out)
}

///|
fn push_text_inline(out : Array[HtmlInline], bs : Bytes) -> Unit {
  if bs.length() == 0 {
    return
  }
  let s0 = @utf8.decode(bs, ignore_bom=false) catch { _ => "" }
  let s1 = html_unescape(s0)
  let s2 = @cor.normalize_document_text_cleanup(s1)
  if s2 != "" {
    out.push(HtmlInline::Text(s2))
  }
}

///|
fn merge_adjacent_text_inlines(xs : Array[HtmlInline]) -> Array[HtmlInline] {
  let out : Array[HtmlInline] = []
  for x in xs {
    match x {
      HtmlInline::Text(s) =>
        if s == "" {
          ()
        } else {
          match out.pop() {
            Some(HtmlInline::Text(prev)) => out.push(HtmlInline::Text(prev + s))
            Some(last) => {
              out.push(last)
              out.push(HtmlInline::Text(s))
            }
            None => out.push(HtmlInline::Text(s))
          }
        }
      HtmlInline::Break => out.push(HtmlInline::Break)
      HtmlInline::Image(alt, title, src) =>
        out.push(HtmlInline::Image(alt, title, src))
      HtmlInline::Link(text, href) => out.push(HtmlInline::Link(text, href))
      HtmlInline::NoteRef(note) => out.push(HtmlInline::NoteRef(note))
    }
  }
  out
}

///|
fn render_inlines(xs : Array[HtmlInline]) -> String {
  let mut s = ""
  for x in xs {
    match x {
      HtmlInline::Text(t) => if t != "" { s = s + t }
      HtmlInline::Break => s = s + "<br>"
      HtmlInline::Image(alt, _title, _src) =>
        if alt.trim() != "" {
          s = s + alt
        } else {
          s = s + "image"
        }
      HtmlInline::Link(text, href) => {
        let t = text.trim().to_owned()
        let h = href.trim().to_owned()
        if t == "" || h == "" {
          s = s + t
        } else {
          s = s + "[" + t + "](" + h + ")"
        }
      }
      HtmlInline::NoteRef(note) => s = s + render_html_note_ref_inline(note)
    }
  }
  s
}

///|
fn find_figure_image_inline(inner : Bytes) -> HtmlInline? {
  let open_img = pat("<img")
  let gt_pat = pat(">")
  let p0 = find_bytes(inner, open_img, 0)
  match p0 {
    None => None
    Some(i0) => {
      let gt = find_bytes(inner, gt_pat, i0)
      match gt {
        None => None
        Some(gt0) => {
          let tag_bs = inner[i0:gt0 + 1].to_owned()
          let tag0 = @utf8.decode(tag_bs, ignore_bom=false) catch { _ => "" }
          let src = html_unescape(
              read_html_attr_value(tag0, "src").unwrap_or(""),
            )
            .trim()
            .to_owned()
          if src == "" {
            return None
          }
          let alt = html_unescape(
            read_html_attr_value(tag0, "alt").unwrap_or(""),
          )
          let title = read_html_attr_value(tag0, "title").map(html_unescape)
          Some(HtmlInline::Image(alt, title, src))
        }
      }
    }
  }
}

///|
fn find_figure_caption_inlines(inner : Bytes) -> Array[HtmlInline] {
  let open_cap = pat("<figcaption")
  let close_cap = pat("</figcaption>")
  let gt_pat = pat(">")
  let c0 = find_bytes(inner, open_cap, 0)
  match c0 {
    None => []
    Some(i0) => {
      let gt = find_bytes(inner, gt_pat, i0)
      match gt {
        None => []
        Some(gt0) => {
          let start = gt0 + 1
          let c1 = find_bytes(inner, close_cap, start)
          match c1 {
            None => []
            Some(end) => html_inlines_from_bytes(inner[start:end].to_owned())
          }
        }
      }
    }
  }
}

///|
fn sanitize_html_href(raw_href : String) -> String? {
  let href0 = html_unescape(raw_href).trim().to_owned()
  let href = match unwrap_known_html_redirect_href(href0) {
    Some(target) => target
    None => if is_known_html_redirect_href(href0) { return None } else { href0 }
  }
  if href == "" {
    return None
  }

  let lower = href.to_lower()
  if lower.has_prefix("javascript:") ||
    lower.has_prefix("vbscript:") ||
    lower.has_prefix("data:") {
    return None
  }

  Some(href)
}

///|
fn is_known_html_redirect_href(href : String) -> Bool {
  let lower = href.to_lower()
  lower.has_prefix("https://www.bing.com/ck/a") ||
  lower.has_prefix("http://www.bing.com/ck/a") ||
  lower.has_prefix("https://bing.com/ck/a") ||
  lower.has_prefix("http://bing.com/ck/a")
}

///|
fn unwrap_known_html_redirect_href(href : String) -> String? {
  if !is_known_html_redirect_href(href) {
    return None
  }
  let parts = href.split("?").to_array()
  if parts.length() < 2 {
    None
  } else {
    extract_bing_click_redirect_target(parts[1].to_owned())
  }
}

///|
fn extract_bing_click_redirect_target(query : String) -> String? {
  for part in query.split("&") {
    let item = part.to_owned()
    if item.has_prefix("u=") {
      let raw = item[2:item.length()].trim().to_owned()
      if raw == "" {
        return None
      }
      if raw.has_prefix("http://") ||
        raw.has_prefix("https://") ||
        raw.has_prefix("/") {
        return Some(raw)
      }
      if raw.has_prefix("a1") {
        let payload = raw[2:raw.length()]
        try @base64.decode(payload, url_safe=false) catch {
          _ => ()
        } noraise {
          bytes =>
            try @utf8.decode(bytes, ignore_bom=false) catch {
              _ => ()
            } noraise {
              decoded => {
                let target = decoded.trim().to_owned()
                if target.has_prefix("http://") ||
                  target.has_prefix("https://") ||
                  target.has_prefix("/") {
                  return Some(target)
                }
              }
            }
        }
      }
    }
  }
  None
}

///|
fn append_inlines(dst : Array[HtmlInline], src : Array[HtmlInline]) -> Unit {
  for x in src {
    dst.push(x)
  }
}
