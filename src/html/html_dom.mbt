///|
priv enum HtmlNode {
  Heading(Int, String)
  Paragraph(String)
  ListItem(String)
  BlockQuote(String)
  CodeBlock(String)
  Table(Array[Array[String]])
}

///|
fn scan_html_nodes(bs : Bytes) -> Array[HtmlNode] raise {
  let out : Array[HtmlNode] = []

  let lt = pat("<")
  let gt = pat(">")

  let close_p = pat("</p>")
  let close_li = pat("</li>")
  let close_blockquote = pat("</blockquote>")
  let close_pre = pat("</pre>")
  let close_table = pat("</table>")
  let close_tr = pat("</tr>")
  let close_td = pat("</td>")
  let close_th = pat("</th>")

  let close_script = pat("</script>")
  let close_style = pat("</style>")

  let mut pos = 0
  let n = bs.length()

  while pos < n {
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

            if tag.has_prefix("<h") && tag.length() >= 3 {
              let lvl_ch = tag[2]
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
                      out.push(HtmlNode::Heading(lvl, text))
                    }
                    pos = end + close_h.length()
                    continue
                  }
                }
              }
            }

            if tag.has_prefix("<blockquote") {
              let inner_start = q + 1
              let end0 = find_bytes(bs, close_blockquote, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_bytes()
                  let text = html_text_from_bytes(inner)
                  if text.trim() != "" {
                    out.push(HtmlNode::BlockQuote(text))
                  }
                  pos = end + close_blockquote.length()
                  continue
                }
              }
            }

            if tag.has_prefix("<pre") {
              let inner_start = q + 1
              let end0 = find_bytes(bs, close_pre, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_bytes()
                  let text = html_pre_text_from_bytes(inner)
                  if text.trim() != "" {
                    out.push(HtmlNode::CodeBlock(text))
                  }
                  pos = end + close_pre.length()
                  continue
                }
              }
            }

            if tag.has_prefix("<p") {
              let inner_start = q + 1
              let end0 = find_bytes(bs, close_p, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_bytes()
                  let text = html_text_from_bytes(inner)
                  if text.trim() != "" {
                    out.push(HtmlNode::Paragraph(text))
                  }
                  pos = end + close_p.length()
                  continue
                }
              }
            }

            if tag.has_prefix("<li") {
              let inner_start = q + 1
              let end0 = find_bytes(bs, close_li, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_bytes()
                  let text = html_text_from_bytes(inner)
                  if text.trim() != "" {
                    out.push(HtmlNode::ListItem(text))
                  }
                  pos = end + close_li.length()
                  continue
                }
              }
            }
            if tag.has_prefix("<table") {
              let inner_start = q + 1
              let end0 = find_bytes(bs, close_table, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_bytes()
                  let rows = html_table_from_bytes(inner)
                  if rows.length() > 0 {
                    out.push(HtmlNode::Table(rows))
                  }
                  pos = end + close_table.length()
                  continue
                }
              }
            }

            pos = q + 1
          }
        }
      }
    }
  }

  out
}

///|
fn normalize_table_rows(rows : Array[Array[String]]) -> Array[Array[String]] {
  let mut max_cols = 0
  for row in rows {
    if row.length() > max_cols {
      max_cols = row.length()
    }
  }

  if max_cols == 0 {
    return rows
  }

  let out : Array[Array[String]] = []
  for row in rows {
    let r : Array[String] = []
    for cell in row {
      r.push(cell)
    }
    while r.length() < max_cols {
      r.push("")
    }
    out.push(r)
  }

  out
}

///|
/// <pre> inner bytes -> code-like text
/// keep newlines as much as possible, only strip tags and unescape
fn html_pre_text_from_bytes(inner : Bytes) -> String raise {
  let text_bs = strip_tags_bytes(inner)
  let s0 = @cor.utf8_bytes_to_string(text_bs) catch { _ => "" }

  html_unescape(s0.replace(old="\r\n", new="\n").replace(old="\r", new="\n"))
  .trim()
  .to_string()
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

///|
fn html_table_from_bytes(inner : Bytes) -> Array[Array[String]] raise {
  let out : Array[Array[String]] = []

  let open_tr = pat("<tr")
  let close_tr = pat("</tr>")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let tr0 = find_bytes(inner, open_tr, pos)
    match tr0 {
      None => break
      Some(i0) => {
        let gt0 = find_bytes(inner, gt_pat, i0)
        match gt0 {
          None => break
          Some(q0) => {
            let row_start = q0 + 1
            let end0 = find_bytes(inner, close_tr, row_start)
            match end0 {
              None => break
              Some(end) => {
                let tr_inner = inner[row_start:end].to_bytes()
                let cells = html_table_row_from_bytes(tr_inner)
                if cells.length() > 0 {
                  out.push(cells)
                }
                pos = end + close_tr.length()
              }
            }
          }
        }
      }
    }
  }

  normalize_table_rows(out)
}

///|
fn html_table_row_from_bytes(tr_inner : Bytes) -> Array[String] raise {
  let out : Array[String] = []

  let open_td = pat("<td")
  let close_td = pat("</td>")
  let open_th = pat("<th")
  let close_th = pat("</th>")
  let gt_pat = pat(">")

  let mut pos = 0
  let n = tr_inner.length()

  while pos < n {
    let td0 = find_bytes(tr_inner, open_td, pos)
    let th0 = find_bytes(tr_inner, open_th, pos)

    let next = match (td0, th0) {
      (Some(a), Some(b)) =>
        if a < b {
          Some((a, false))
        } else {
          Some((b, true))
        }
      (Some(a), None) => Some((a, false))
      (None, Some(b)) => Some((b, true))
      (None, None) => None
    }

    match next {
      None => break
      Some((i0, is_th)) => {
        let gt0 = find_bytes(tr_inner, gt_pat, i0)
        match gt0 {
          None => break
          Some(q0) => {
            let cell_start = q0 + 1
            let end0 = if is_th {
              find_bytes(tr_inner, close_th, cell_start)
            } else {
              find_bytes(tr_inner, close_td, cell_start)
            }

            match end0 {
              None => break
              Some(end) => {
                let cell_inner = tr_inner[cell_start:end].to_bytes()
                let text = html_text_from_bytes(cell_inner).trim().to_string()
                out.push(text)

                pos = if is_th {
                  end + close_th.length()
                } else {
                  end + close_td.length()
                }
              }
            }
          }
        }
      }
    }
  }

  out
}
