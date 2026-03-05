///|
/// HTML MVP parser (bytes-based, avoid InvalidIndex on UTF-8)
pub fn parse_html(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("html: file not found: " + input_path)
  }

  let bs = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("html: read failed: " + e.to_string())
  }

  let doc = @cor.new_document()
  @cor.push(doc, @cor.Block::Heading(clamp_heading(1, max_heading), "HTML"))

  let blocks = parse_blocks_bytes(bs, max_heading)
  for b in blocks {
    @cor.push(doc, b)
  }

  doc
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

// ---------- bytes helpers ----------

///|
fn pat(s : String) -> Bytes {
  @utf8.encode(s)
}

///|
fn find_bytes(hay : Bytes, needle : Bytes, start : Int) -> Int? {
  let n = hay.length()
  let m = needle.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start > n - m {
    return None
  }
  let last = n - m
  let mut i = start
  while i <= last {
    let mut ok = true
    let mut j = 0
    while j < m {
      if hay[i + j] != needle[j] {
        ok = false
        break
      }
      j = j + 1
    }
    if ok {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn starts_with_bytes(hay : Bytes, pos : Int, needle : Bytes) -> Bool {
  let n = hay.length()
  let m = needle.length()
  if pos < 0 || pos + m > n {
    return false
  }
  let mut j = 0
  while j < m {
    if hay[pos + j] != needle[j] {
      return false
    }
    j = j + 1
  }
  true
}

///|
/// remove <...> tags from a byte slice (keep text bytes)
fn strip_tags_bytes(inner : Bytes) -> Bytes {
  let out : Array[Byte] = []
  let mut i = 0
  let n = inner.length()
  let lt = pat("<")
  let gt = pat(">")

  while i < n {
    let p0 = find_bytes(inner, lt, i)
    match p0 {
      None => {
        let tail = inner[i:n].to_bytes().to_array()
        for b in tail {
          out.push(b)
        }
        break
      }
      Some(p) => {
        let head = inner[i:p].to_bytes().to_array()
        for b in head {
          out.push(b)
        }
        let q0 = find_bytes(inner, gt, p)
        match q0 {
          None => break
          Some(q) => i = q + 1
        }
      }
    }
  }

  Bytes::from_array(out)
}

///|
fn replace_bytes(hay : Bytes, from : Bytes, to : Bytes) -> Bytes {
  let out : Array[Byte] = []
  let mut i = 0
  let n = hay.length()
  let m = from.length()

  while i < n {
    let hit = m > 0 && i <= n - m && starts_with_bytes(hay, i, from)
    if hit {
      let arr = to.to_array()
      for b in arr {
        out.push(b)
      }
      i = i + m
    } else {
      out.push(hay[i])
      i = i + 1
    }
  }

  Bytes::from_array(out)
}

///|
fn html_unescape(s : String) -> String raise {
  let t = s
    .replace(old="&lt;", new="<")
    .replace(old="&gt;", new=">")
    .replace(old="&amp;", new="&")
    .replace(old="&quot;", new="\"")
    .replace(old="&apos;", new="'")
  @cor.decode_numeric_entities(t)
}

///|
/// inner bytes -> visible text (strip tags + unescape)
fn html_text_from_bytes(inner : Bytes) -> String raise {
  // handle <br> variants (MVP: turn into space)
  let bs0 = replace_bytes(inner, pat("<br>"), pat(" "))
  let bs1 = replace_bytes(bs0, pat("<br/>"), pat(" "))
  let bs2 = replace_bytes(bs1, pat("<br />"), pat(" "))

  let text_bs = strip_tags_bytes(bs2)
  let s0 = @cor.utf8_bytes_to_string(text_bs) catch { _ => "" }
  html_unescape(s0).trim().to_string()
}

// ---------- parser ----------

///|
fn parse_blocks_bytes(bs : Bytes, max_h : Int) -> Array[@cor.Block] raise {
  let out : Array[@cor.Block] = []

  let lt = pat("<")
  let gt = pat(">")

  let close_p = pat("</p>")
  let close_li = pat("</li>")

  let close_script = pat("</script>")
  let close_style = pat("</style>")

  let mut pos = 0
  let n = bs.length()

  while pos < n {
    // find next '<'
    let lt0 = find_bytes(bs, lt, pos)
    match lt0 {
      None => break
      Some(p) => {
        let gt0 = find_bytes(bs, gt, p)
        match gt0 {
          None => break
          Some(q) => {
            let tag_bs = bs[p:q + 1].to_bytes()
            let tag = (@cor.utf8_bytes_to_string(tag_bs) catch { _ => "" }).to_lower()

            // skip script/style blocks
            if tag.has_prefix("<script") {
              let j0 = find_bytes(bs, close_script, q + 1)
              match j0 {
                None => pos = q + 1
                Some(j) => pos = j + close_script.length()
              }
              continue
            }
            if tag.has_prefix("<style") {
              let j0 = find_bytes(bs, close_style, q + 1)
              match j0 {
                None => pos = q + 1
                Some(j) => pos = j + close_style.length()
              }
              continue
            }

            // headings <h1..h6>
            if tag.has_prefix("<h") && tag.length() >= 3 {
              let lvl_ch = tag[2] // ASCII safe
              if lvl_ch >= '1' && lvl_ch <= '6' {
                let lvl = lvl_ch.to_int() - '0'.to_int()
                let close_h = pat("</h" + lvl.to_string() + ">")
                let inner_start = q + 1
                let end0 = find_bytes(bs, close_h, inner_start)
                match end0 {
                  None => ()
                  Some(end) => {
                    let inner = bs[inner_start:end].to_bytes()
                    let text = html_text_from_bytes(inner)
                    if text.trim() != "" {
                      out.push(
                        @cor.Block::Heading(clamp_heading(lvl, max_h), text),
                      )
                      out.push(@cor.Block::BlankLine)
                    }
                    pos = end + close_h.length()
                    continue
                  }
                }
              }
            }

            // paragraph <p>
            if tag.has_prefix("<p") {
              let inner_start = q + 1
              let end0 = find_bytes(bs, close_p, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_bytes()
                  let text = html_text_from_bytes(inner)
                  if text.trim() != "" {
                    out.push(@cor.Block::Paragraph(text))
                    out.push(@cor.Block::BlankLine)
                  }
                  pos = end + close_p.length()
                  continue
                }
              }
            }

            // list item <li>
            if tag.has_prefix("<li") {
              let inner_start = q + 1
              let end0 = find_bytes(bs, close_li, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_bytes()
                  let text = html_text_from_bytes(inner)
                  if text.trim() != "" {
                    out.push(@cor.Block::Paragraph("- " + text))
                  }
                  pos = end + close_li.length()
                  continue
                }
              }
            }

            // default: advance
            pos = q + 1
          }
        }
      }
    }
  }

  out
}
