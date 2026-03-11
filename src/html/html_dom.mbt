///|
priv enum HtmlNode {
  Heading(Int, String)
  Paragraph(String)
  ListItem(Bool, Int, String) // ordered, level, text
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
  let _close_li = pat("</li>")
  let close_blockquote = pat("</blockquote>")
  let close_pre = pat("</pre>")
  let close_table = pat("</table>")
  let _close_tr = pat("</tr>")
  let _close_td = pat("</td>")
  let _close_th = pat("</th>")

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
            if tag.has_prefix("<ul") || tag.has_prefix("<ol") {
              let is_ol = tag.has_prefix("<ol")
              let list_name = if is_ol { "ol" } else { "ul" }

              match find_matching_list_end(bs, p, list_name) {
                Some(end) => {
                  let close_len = ("</" + list_name + ">").length()
                  let inner_start = q + 1
                  let inner_end = end

                  let items = scan_list_nodes(
                    bs, inner_start, inner_end, is_ol, 0,
                  )
                  for item in items {
                    out.push(item)
                  }

                  pos = end + close_len
                  continue
                }
                None => ()
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
/// scan one <ul>/<ol> block body and emit list items with ordered/level
fn scan_list_nodes(
  bs : Bytes,
  start : Int,
  end_ : Int,
  ordered : Bool,
  level : Int,
) -> Array[HtmlNode] raise {
  let out : Array[HtmlNode] = []

  let open_li = pat("<li")
  let close_li = pat("</li>")
  let gt_pat = pat(">")

  let mut pos = start
  while pos < end_ {
    let li0 = find_bytes(bs, open_li, pos)
    match li0 {
      None => break
      Some(i0) => {
        if i0 >= end_ {
          break
        }

        let gt0 = find_bytes(bs, gt_pat, i0)
        match gt0 {
          None => break
          Some(q0) => {
            if q0 >= end_ {
              break
            }

            let inner_start = q0 + 1

            // 关键修复：找“当前 li”的匹配闭合位置，而不是第一个 </li>
            let end_li0 = find_matching_li_end(bs, i0)
            match end_li0 {
              None => break
              Some(li_end) => {
                if li_end > end_ {
                  break
                }

                let nested0 = find_nested_list_start_in_range(
                  bs, inner_start, li_end,
                )

                match nested0 {
                  Some(nested_start) => {
                    let head = bs[inner_start:nested_start].to_bytes()
                    let text = html_text_from_bytes(head)
                    if text.trim() != "" {
                      out.push(HtmlNode::ListItem(ordered, level, text))
                    }

                    let nested_tag_end0 = find_bytes(bs, gt_pat, nested_start)
                    match nested_tag_end0 {
                      None => ()
                      Some(nested_gt) => {
                        let tag_bs = bs[nested_start:nested_gt + 1].to_bytes()
                        let tag = (@cor.utf8_bytes_to_string(tag_bs) catch {
                          _ => ""
                        }).to_lower()

                        let nested_is_ol = tag.has_prefix("<ol")
                        let nested_is_ul = tag.has_prefix("<ul")

                        if nested_is_ol || nested_is_ul {
                          let nested_name = if nested_is_ol {
                            "ol"
                          } else {
                            "ul"
                          }
                          match
                            find_matching_list_end(
                              bs, nested_start, nested_name,
                            ) {
                            Some(nested_end) => {
                              let _nested_close_len = ("</" + nested_name + ">").length()
                              let nested_inner_start = nested_gt + 1

                              let nested_nodes = scan_list_nodes(
                                bs,
                                nested_inner_start,
                                nested_end,
                                nested_is_ol,
                                level + 1,
                              )
                              for node in nested_nodes {
                                out.push(node)
                              }

                              pos = li_end + close_li.length()
                              continue
                            }
                            None => ()
                          }
                        }
                      }
                    }

                    pos = li_end + close_li.length()
                  }
                  None => {
                    let inner = bs[inner_start:li_end].to_bytes()
                    let text = html_text_from_bytes(inner)
                    if text.trim() != "" {
                      out.push(HtmlNode::ListItem(ordered, level, text))
                    }
                    pos = li_end + close_li.length()
                  }
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
fn html_pre_text_from_bytes(inner : Bytes) -> String{
  let text_bs = strip_tags_bytes(inner)
  let s0 = @cor.utf8_bytes_to_string(text_bs) catch { _ => "" }

  html_unescape(s0.replace(old="\r\n", new="\n").replace(old="\r", new="\n"))
  .trim()
  .to_string()
}

///|
fn html_text_from_bytes(inner : Bytes) -> String {
  let bs0 = normalize_html_breaks(inner)
  let text_bs = strip_tags_bytes(bs0)
  let s0 = @cor.utf8_bytes_to_string(text_bs) catch { _ => "" }
  let s1 = replace_all(html_unescape(s0), "@@HTML_BR@@", "<br>")
  s1.trim().to_string()
}

///|
fn html_table_from_bytes(inner : Bytes) -> Array[Array[String]]{
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
fn html_table_row_from_bytes(tr_inner : Bytes) -> Array[String]{
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

///|
/// replace any <br...> tag (case-insensitive) with sentinel text
fn normalize_html_breaks(inner : Bytes) -> Bytes {
  let out : Array[Byte] = []

  let lt = pat("<")
  let gt = pat(">")

  let br_bytes = @utf8.encode("@@HTML_BR@@")

  let mut pos = 0
  let n = inner.length()

  while pos < n {
    let lt0 = find_bytes(inner, lt, pos)
    match lt0 {
      None => {
        for b in inner[pos:].to_array() {
          out.push(b)
        }
        break
      }
      Some(i0) => {
        for b in inner[pos:i0].to_array() {
          out.push(b)
        }

        let gt0 = find_bytes(inner, gt, i0)
        match gt0 {
          None => {
            for b in inner[i0:].to_array() {
              out.push(b)
            }
            break
          }
          Some(j0) => {
            let tag_bs = inner[i0:j0 + 1].to_bytes()
            let tag0 = @cor.utf8_bytes_to_string(tag_bs) catch { _ => "" }
            let tag = tag0.to_lower()

            if tag.has_prefix("<br") {
              for b in br_bytes {
                out.push(b)
              }
            } else {
              for b in tag_bs.to_array() {
                out.push(b)
              }
            }

            pos = j0 + 1
          }
        }
      }
    }
  }

  Bytes::from_iter(out.iter())
}

///|
fn replace_all(s : String, old : String, new_ : String) -> String {
  let mut cur = s
  while cur.contains(old) {
    cur = cur.replace(old~, new=new_)
  }
  cur
}
