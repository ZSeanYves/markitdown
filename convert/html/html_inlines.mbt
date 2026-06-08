///|
/// HtmlInline is the convert-owned Markdown/product inline view. Normal runtime
/// builds it from parser inline/link/image/note facts.
priv enum HtmlInline {
  Text(String)
  Break
  Image(String, String?, String) // alt, title, src
  Link(String, String) // text, href
  NoteRef(@cor.NoteRef)
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
fn render_html_note_ref_inline(note : @cor.NoteRef) -> String {
  if note.body_status == @cor.NoteBodyStatus::Resolved &&
    note.note_id.trim() != "" {
    return "[^" + note.note_id.trim().to_owned() + "]"
  }
  let marker = note.marker.trim().to_owned()
  if marker == "" {
    ""
  } else if marker.has_prefix("^") {
    marker
  } else {
    "^" + marker
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
