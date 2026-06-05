///|
/// extract all <a:t>...</a:t> text within xml[start:end_]
fn extract_text_runs(xml : Bytes, start : Int, end_ : Int) -> String {
  extract_text_runs_impl(xml, start, end_, true)
}

///|
fn extract_text_runs_impl(
  xml : Bytes,
  start : Int,
  end_ : Int,
  apply_shared_cleanup : Bool,
) -> String {
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

            let seg = xml[content_start:t1i].to_owned()
            let s = @utf8.decode(seg, ignore_bom=false) catch { _ => "" }

            acc = acc + s
            tpos = t1i + close_t.length()
          }
        }
      }
    }
  }

  let decoded = xml_unescape(acc)
  if apply_shared_cleanup {
    @cor.normalize_document_text_cleanup(decoded)
  } else {
    decoded
  }
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

    let run = xml[p:close + close_pat.length()].to_owned()
    let text = extract_text_runs(run, 0, run.length())
    if text.trim() != "" {
      let rid = run_hyperlink_rid(run)
      let link = match rid {
        Some(id) =>
          match hyperlinks.get(id) {
            Some(u) => u.trim().to_owned()
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
  let fallback = extract_text_runs_impl(xml, start, end_, false)
  if fallback.trim() == "" {
    []
  } else {
    [@cor.Inline::Text(fallback)]
  }
}

///|
fn extract_single_hyperlink_relationship_id(
  inlines : Array[@cor.Inline],
  hyperlinks : Map[String, String],
) -> String? {
  let mut seen_url : String? = None
  for x in inlines {
    match x {
      @cor.Inline::Link(_text, url) => {
        let trimmed = url.trim().to_owned()
        if trimmed == "" {
          continue
        }
        match seen_url {
          Some(prev) => if prev != trimmed { return None }
          None => seen_url = Some(trimmed)
        }
      }
      @cor.Inline::NoteRef(_) => ()
      _ => ()
    }
  }

  let target = match seen_url {
    Some(url) => url
    None => return None
  }

  let mut rid : String? = None
  for entry in hyperlinks {
    let (candidate_rid, candidate_url) = entry
    if candidate_url.trim() != target {
      continue
    }
    match rid {
      Some(prev) => if prev != candidate_rid { return None }
      None => rid = Some(candidate_rid)
    }
  }
  rid
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
  let tag = run[p0:gt + 1].to_owned()
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
