///|
priv enum HtmlInline {
  Text(String)
  Break
}

///|
priv enum HtmlNode {
  Heading(Int, Array[HtmlInline])
  Paragraph(Array[HtmlInline])
  ListItem(Bool, Int, Array[HtmlInline]) // ordered, level, text
  BlockQuote(Array[HtmlNode])
  CodeBlock(String)
  Table(Array[Array[Array[HtmlInline]]])
}

///|
fn scan_html_nodes(bs : Bytes) -> Array[HtmlNode] raise {
  let out : Array[HtmlNode] = []

  let lt = pat("<")
  let gt = pat(">")

  let close_p = pat("</p>")
  let close_blockquote = pat("</blockquote>")
  let close_pre = pat("</pre>")
  let close_table = pat("</table>")

  let close_script = pat("</script>")
  let close_style = pat("</style>")
  let close_head = pat("</head>")

  let mut pos = 0
  let n = bs.length()

  while pos < n {
    let lt0 = find_bytes(bs, lt, pos)
    match lt0 {
      None => {
        let tail = bs[pos:n].to_bytes()
        let xs = trim_inlines_to_paragraph(html_inlines_from_bytes(tail))
        if !inlines_is_blank(xs) {
          out.push(HtmlNode::Paragraph(xs))
        }
        break
      }
      Some(p) => {
        // 顶层裸文本补出，并去掉源码缩进空白
        if p > pos {
          let head = bs[pos:p].to_bytes()
          let xs = trim_inlines_to_paragraph(html_inlines_from_bytes(head))
          if !inlines_is_blank(xs) {
            out.push(HtmlNode::Paragraph(xs))
          }
        }

        let gt0 = find_bytes(bs, gt, p)
        match gt0 {
          None => {
            let tail = bs[p:n].to_bytes()
            let xs = trim_inlines_to_paragraph(html_inlines_from_bytes(tail))
            if !inlines_is_blank(xs) {
              out.push(HtmlNode::Paragraph(xs))
            }
            break
          }
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

            if tag.has_prefix("<head") {
              let j0 = find_bytes(bs, close_head, q + 1)
              match j0 {
                None => pos = q + 1
                Some(j) => pos = j + close_head.length()
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
                    let xs = html_inlines_from_bytes(inner)
                    if !inlines_is_blank(xs) {
                      out.push(HtmlNode::Heading(lvl, xs))
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
                  let children = scan_html_nodes_in_container(inner)
                  if !quote_children_is_blank(children) {
                    out.push(HtmlNode::BlockQuote(children))
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
                  let xs = html_inlines_from_bytes(inner)
                  if !inlines_is_blank(xs) {
                    out.push(HtmlNode::Paragraph(xs))
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
                    let xs = html_inlines_from_bytes(head)
                    if !inlines_is_blank(xs) {
                      out.push(HtmlNode::ListItem(ordered, level, xs))
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
                    let xs = html_inlines_from_bytes(inner)
                    if !inlines_is_blank(xs) {
                      out.push(HtmlNode::ListItem(ordered, level, xs))
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
fn scan_html_nodes_in_container(bs : Bytes) -> Array[HtmlNode] raise {
  let out : Array[HtmlNode] = []

  let lt = pat("<")
  let gt = pat(">")

  let close_p = pat("</p>")
  let close_blockquote = pat("</blockquote>")
  let close_pre = pat("</pre>")
  let close_table = pat("</table>")

  let mut pos = 0
  let n = bs.length()

  while pos < n {
    let lt0 = find_bytes(bs, lt, pos)
    match lt0 {
      None => {
        let tail = bs[pos:n].to_bytes()
        let xs = trim_inlines_to_paragraph(html_inlines_from_bytes(tail))
        if !inlines_is_blank(xs) {
          out.push(HtmlNode::Paragraph(xs))
        }
        break
      }
      Some(p) => {
        if p > pos {
          let head = bs[pos:p].to_bytes()
          let xs = trim_inlines_to_paragraph(html_inlines_from_bytes(head))
          if !inlines_is_blank(xs) {
            out.push(HtmlNode::Paragraph(xs))
          }
        }

        let gt0 = find_bytes(bs, gt, p)
        match gt0 {
          None => {
            let tail = bs[p:n].to_bytes()
            let xs = trim_inlines_to_paragraph(html_inlines_from_bytes(tail))
            if !inlines_is_blank(xs) {
              out.push(HtmlNode::Paragraph(xs))
            }
            break
          }
          Some(q) => {
            let tag_bs = bs[p:q + 1].to_bytes()
            let tag = (@cor.utf8_bytes_to_string(tag_bs) catch { _ => "" }).to_lower()

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
                    let xs = html_inlines_from_bytes(inner)
                    if !inlines_is_blank(xs) {
                      out.push(HtmlNode::Heading(lvl, xs))
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
                  let children = scan_html_nodes_in_container(inner)
                  if !quote_children_is_blank(children) {
                    out.push(HtmlNode::BlockQuote(children))
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
                  let xs = html_inlines_from_bytes(inner)
                  if !inlines_is_blank(xs) {
                    out.push(HtmlNode::Paragraph(xs))
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
fn normalize_table_rows(
  rows : Array[Array[Array[HtmlInline]]],
) -> Array[Array[Array[HtmlInline]]] {
  let mut max_cols = 0
  for row in rows {
    if row.length() > max_cols {
      max_cols = row.length()
    }
  }

  if max_cols == 0 {
    return rows
  }

  let out : Array[Array[Array[HtmlInline]]] = []
  for row in rows {
    let r : Array[Array[HtmlInline]] = []
    for cell in row {
      r.push(cell)
    }
    while r.length() < max_cols {
      r.push([])
    }
    out.push(r)
  }

  out
}

///|
/// <pre> inner bytes -> code-like text
/// keep newlines as much as possible, only strip tags and unescape
fn html_pre_text_from_bytes(inner : Bytes) -> String {
  let text_bs = strip_tags_bytes(inner)
  let s0 = @cor.utf8_bytes_to_string(text_bs) catch { _ => "" }

  html_unescape(s0.replace(old="\r\n", new="\n").replace(old="\r", new="\n"))
  .trim()
  .to_string()
}

///|
fn html_inlines_from_bytes(inner : Bytes) -> Array[HtmlInline] {
  let out : Array[HtmlInline] = []

  let lt = pat("<")
  let gt = pat(">")
  let mut pos = 0
  let n = inner.length()

  while pos < n {
    let lt0 = find_bytes(inner, lt, pos)
    match lt0 {
      None => {
        let tail = inner[pos:n].to_bytes()
        push_text_inline(out, tail)
        break
      }
      Some(i0) => {
        if i0 > pos {
          let head = inner[pos:i0].to_bytes()
          push_text_inline(out, head)
        }

        let gt0 = find_bytes(inner, gt, i0)
        match gt0 {
          None => {
            let tail = inner[i0:n].to_bytes()
            push_text_inline(out, tail)
            break
          }
          Some(j0) => {
            let tag_bs = inner[i0:j0 + 1].to_bytes()
            let tag0 = @cor.utf8_bytes_to_string(tag_bs) catch { _ => "" }
            let tag = tag0.to_lower()

            if tag.has_prefix("<br") {
              out.push(HtmlInline::Break)
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
  let s0 = @cor.utf8_bytes_to_string(bs) catch { _ => "" }
  let s1 = html_unescape(s0)
  if s1 != "" {
    out.push(HtmlInline::Text(s1))
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
    }
  }
  s
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
/// for raw text segments between tags:
/// trim leading/trailing whitespace introduced by source indentation
fn trim_inlines_to_paragraph(xs : Array[HtmlInline]) -> Array[HtmlInline] {
  let s = render_inlines(xs).trim().to_string()
  if s == "" {
    []
  } else {
    [HtmlInline::Text(s)]
  }
}
///|
fn html_table_from_bytes(inner : Bytes) -> Array[Array[Array[HtmlInline]]] {
  let out : Array[Array[Array[HtmlInline]]] = []

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
fn html_table_row_from_bytes(tr_inner : Bytes) -> Array[Array[HtmlInline]] {
  let out : Array[Array[HtmlInline]] = []

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
                let xs = html_inlines_from_bytes(cell_inner)
                out.push(xs)

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

