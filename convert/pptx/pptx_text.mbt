///|
/// extract all <a:t>...</a:t> text within xml[start:end_]
fn extract_text_runs(xml : Bytes, start : Int, end_ : Int) -> String {
  let open_t = pat("<a:t>")
  let close_t = pat("</a:t>")

  let mut tpos = start
  let mut acc = ""

  while tpos < end_ {
    let t0 = find_bytes(xml, open_t, tpos)
    match t0 {
      None => break
      Some(t0i) => {
        if t0i >= end_ {
          break
        }

        let content_start = t0i + open_t.length()
        let t1 = find_bytes(xml, close_t, content_start)
        match t1 {
          None => break
          Some(t1i) => {
            if t1i > end_ {
              break
            }

            let seg = xml[content_start:t1i].to_bytes()
            let s = @cor.utf8_bytes_to_string(seg) catch { _ => "" }

            acc = acc + s
            tpos = t1i + close_t.length()
          }
        }
      }
    }
  }

  xml_unescape(acc)
}

///|
fn extract_text_inlines(
  xml : Bytes,
  start : Int,
  end_ : Int,
  hyperlinks : Map[String, String],
) -> Array[@cor.Inline] raise {
  let out : Array[@cor.Inline] = []
  let mut pos = start

  let open_r = pat("<a:r")
  let close_r = pat("</a:r>")
  let open_fld = pat("<a:fld")
  let close_fld = pat("</a:fld>")
  let open_br = pat("<a:br")
  let gt_pat = pat(">")

  while pos < end_ {
    let p_r = find_bytes(xml, open_r, pos).unwrap_or(-1)
    let p_f = find_bytes(xml, open_fld, pos).unwrap_or(-1)
    let p_b = find_bytes(xml, open_br, pos).unwrap_or(-1)

    let mut p = -1
    let mut kind = 0 // 1=a:r, 2=a:fld, 3=a:br
    if p_r >= 0 {
      p = p_r
      kind = 1
    }
    if p_f >= 0 && (p < 0 || p_f < p) {
      p = p_f
      kind = 2
    }
    if p_b >= 0 && (p < 0 || p_b < p) {
      p = p_b
      kind = 3
    }

    if p < 0 || p >= end_ {
      break
    }

    if kind == 3 {
      let gt = find_bytes(xml, gt_pat, p).unwrap_or(-1)
      if gt < 0 || gt >= end_ {
        break
      }
      out.push(@cor.Inline::Break)
      pos = gt + 1
      continue
    }

    let gt = find_bytes(xml, gt_pat, p).unwrap_or(-1)
    if gt < 0 || gt >= end_ {
      break
    }
    let close_pat = if kind == 1 { close_r } else { close_fld }
    let close = find_bytes(xml, close_pat, gt + 1).unwrap_or(-1)
    if close < 0 || close > end_ {
      pos = gt + 1
      continue
    }

    let run = xml[p:close + close_pat.length()].to_bytes()
    let text = extract_text_runs(run, 0, run.length())
    if text.trim() != "" {
      let rid = run_hyperlink_rid(run)
      let link = match rid {
        Some(id) =>
          match hyperlinks.get(id) {
            Some(u) => u.trim().to_string()
            None => ""
          }
        None => ""
      }

      if link != "" {
        out.push(@cor.Inline::Link(text, link))
      } else {
        out.push(@cor.Inline::Text(text))
      }
    }

    pos = close + close_pat.length()
  }

  if out.length() > 0 {
    return out
  }
  let fallback = extract_text_runs(xml, start, end_)
  if fallback.trim() == "" {
    []
  } else {
    [@cor.Inline::Text(fallback)]
  }
}

///|
fn run_hyperlink_rid(run : Bytes) -> String? raise {
  let open_h = pat("<a:hlinkClick")
  let gt_pat = pat(">")
  let p0 = find_bytes(run, open_h, 0).unwrap_or(-1)
  if p0 < 0 {
    return None
  }
  let gt = find_bytes(run, gt_pat, p0).unwrap_or(-1)
  if gt < 0 {
    return None
  }
  let tag = run[p0:gt + 1].to_bytes()
  read_attr_value_in_tag_bytes(tag, "r:id")
}

///|
fn render_plain_text_inlines(xs : Array[@cor.Inline]) -> String {
  let mut out = ""
  for x in xs {
    match x {
      @cor.Inline::Text(t) => out = out + t
      @cor.Inline::Break => out = out + "\n"
      @cor.Inline::Link(text, _url) => out = out + text
    }
  }
  out
}
