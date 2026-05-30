///|
priv enum HtmlNode {
  Heading(Int, Array[HtmlInline])
  Paragraph(Array[HtmlInline])
  Figure(HtmlInline, Array[HtmlInline]) // image, figcaption inlines
  ListItem(Bool, Int, Array[HtmlNode]) // ordered, level, children
  BlockQuote(Array[HtmlNode])
  CodeBlock(String)
  Table(HtmlTable)
}

///|
fn scan_html_nodes(bs : Bytes) -> Array[HtmlNode] raise {
  let note_plan = build_html_note_plan(bs)
  scan_html_nodes_with_notes(bs, note_plan)
}

///|
fn scan_html_notes(bs : Bytes) -> Array[@cor.NoteDefinition] {
  build_html_note_plan(bs).definitions
}

///|
fn scan_html_nodes_with_notes(
  bs : Bytes,
  note_plan : HtmlNotePlan,
) -> Array[HtmlNode] raise {
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
  let close_noscript = pat("</noscript>")
  let close_details = pat("</details>")
  let close_summary = pat("</summary>")
  let close_comment = pat("-->")

  let mut pos = 0
  let n = bs.length()

  while pos < n {
    let lt0 = find_bytes(bs, lt, pos)
    match lt0 {
      None => {
        let tail = bs[pos:n].to_owned()
        let xs = trim_inlines_to_paragraph(
          html_inlines_from_bytes_with_notes(tail, note_plan),
        )
        if !inlines_is_blank(xs) {
          out.push(HtmlNode::Paragraph(xs))
        }
        break
      }
      Some(p) => {
        // 顶层裸文本补出，并去掉源码缩进空白
        if p > pos {
          let head = bs[pos:p].to_owned()
          let xs = trim_inlines_to_paragraph(
            html_inlines_from_bytes_with_notes(head, note_plan),
          )
          if !inlines_is_blank(xs) {
            out.push(HtmlNode::Paragraph(xs))
          }
        }

        let gt0 = find_bytes(bs, gt, p)
        match gt0 {
          None => {
            let tail = bs[p:n].to_owned()
            let xs = trim_inlines_to_paragraph(
              html_inlines_from_bytes_with_notes(tail, note_plan),
            )
            if !inlines_is_blank(xs) {
              out.push(HtmlNode::Paragraph(xs))
            }
            break
          }
          Some(q) => {
            let tag_bs = bs[p:q + 1].to_owned()
            let tag = (@utf8.decode(tag_bs, ignore_bom=false) catch { _ => "" }).to_lower()

            match html_note_body_range_end(note_plan, p) {
              Some(skip_end) => {
                pos = skip_end
                continue
              }
              None => ()
            }

            if tag.has_prefix("<!--") {
              let end0 = find_bytes(bs, close_comment, p + 4)
              match end0 {
                Some(end) => {
                  pos = end + close_comment.length()
                  continue
                }
                None => break
              }
            }

            match find_skippable_html_noise_subtree_end(bs, p, q, tag) {
              Some(skip_end) => {
                pos = skip_end
                continue
              }
              None => ()
            }

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

            if tag.has_prefix("<noscript") {
              let j0 = find_bytes(bs, close_noscript, q + 1)
              match j0 {
                None => pos = q + 1
                Some(j) => pos = j + close_noscript.length()
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
                    let inner = bs[inner_start:end].to_owned()
                    let xs = html_inlines_from_bytes_with_notes(
                      inner, note_plan,
                    )
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
                  let inner = bs[inner_start:end].to_owned()
                  let children = scan_html_nodes_in_container_with_notes(
                    inner, note_plan,
                  )
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
                  let inner = bs[inner_start:end].to_owned()
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
                  let inner = bs[inner_start:end].to_owned()
                  let xs = html_inlines_from_bytes_with_notes(inner, note_plan)
                  if !inlines_is_blank(xs) {
                    out.push(HtmlNode::Paragraph(xs))
                  }
                  pos = end + close_p.length()
                  continue
                }
              }
            }

            if tag.has_prefix("<details") {
              let inner_start = q + 1
              let end0 = find_bytes(bs, close_details, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_owned()
                  let children = scan_html_nodes_in_container_with_notes(
                    inner, note_plan,
                  )
                  for child in children {
                    out.push(child)
                  }
                  pos = end + close_details.length()
                  continue
                }
              }
            }

            if tag.has_prefix("<summary") {
              let inner_start = q + 1
              let end0 = find_bytes(bs, close_summary, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_owned()
                  let xs = html_inlines_from_bytes_with_notes(inner, note_plan)
                  if !inlines_is_blank(xs) {
                    out.push(HtmlNode::Paragraph(xs))
                  }
                  pos = end + close_summary.length()
                  continue
                }
              }
            }

            if tag.has_prefix("<figure") {
              let close_figure = pat("</figure>")
              let inner_start = q + 1
              let end0 = find_bytes(bs, close_figure, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_owned()
                  let fig_img = find_figure_image_inline(inner)
                  match fig_img {
                    Some(img) => {
                      let caption = find_figure_caption_inlines(inner)
                      out.push(HtmlNode::Figure(img, caption))
                    }
                    None => ()
                  }
                  pos = end + close_figure.length()
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
                    bs, inner_start, inner_end, is_ol, 0, note_plan,
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
                  let inner = bs[inner_start:end].to_owned()
                  let table = html_table_from_bytes_with_notes(inner, note_plan)
                  if table.rows.length() > 0 {
                    out.push(HtmlNode::Table(table))
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
  note_plan : HtmlNotePlan,
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

        match html_note_body_range_end(note_plan, i0) {
          Some(skip_end) =>
            if skip_end <= end_ {
              pos = skip_end
              continue
            }
          None => ()
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

                let children = scan_li_children(
                  bs,
                  inner_start,
                  li_end,
                  level + 1,
                  note_plan,
                )

                if !list_item_children_is_blank(children) {
                  out.push(HtmlNode::ListItem(ordered, level, children))
                }

                pos = li_end + close_li.length()
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
/// scan one <li> body into child blocks
/// next_level is used for nested list items
fn scan_li_children(
  bs : Bytes,
  start : Int,
  end_ : Int,
  next_level : Int,
  note_plan : HtmlNotePlan,
) -> Array[HtmlNode] raise {
  let out : Array[HtmlNode] = []
  let pending_para : Array[HtmlInline] = []

  // fast path:
  // if this <li> body has no block-like tags, treat the whole body
  // as one paragraph with inline content, so inline tags like <em>/<strong>/<code>
  // do not split into multiple paragraph nodes.
  if !has_block_like_tag_in_range(bs, start, end_) {
    let inner = bs[start:end_].to_owned()
    let xs = html_inlines_from_bytes_with_notes(inner, note_plan)
    if !inlines_is_blank(xs) {
      out.push(HtmlNode::Paragraph(xs))
    }
    return out
  }

  let lt = pat("<")
  let gt = pat(">")

  let close_p = pat("</p>")
  let close_blockquote = pat("</blockquote>")
  let close_pre = pat("</pre>")
  let close_table = pat("</table>")
  let close_comment = pat("-->")

  let mut pos = start

  while pos < end_ {
    let lt0 = find_bytes(bs, lt, pos)
    match lt0 {
      None => {
        let tail = bs[pos:end_].to_owned()
        let xs = html_inlines_from_bytes_with_notes(tail, note_plan)
        if !inlines_is_blank(xs) {
          append_inlines(pending_para, xs)
        }
        flush_pending_paragraph(out, pending_para)
        break
      }
      Some(p) => {
        if p > pos {
          let head = bs[pos:p].to_owned()
          let xs = html_inlines_from_bytes_with_notes(head, note_plan)
          if !inlines_is_blank(xs) {
            append_inlines(pending_para, xs)
          }
        }

        if p >= end_ {
          flush_pending_paragraph(out, pending_para)
          break
        }

        let gt0 = find_bytes(bs, gt, p)
        match gt0 {
          None => {
            let tail = bs[p:end_].to_owned()
            let xs = html_inlines_from_bytes_with_notes(tail, note_plan)
            if !inlines_is_blank(xs) {
              append_inlines(pending_para, xs)
            }
            flush_pending_paragraph(out, pending_para)
            break
          }
          Some(q) => {
            if q >= end_ {
              let tail = bs[p:end_].to_owned()
              let xs = html_inlines_from_bytes_with_notes(tail, note_plan)
              if !inlines_is_blank(xs) {
                append_inlines(pending_para, xs)
              }
              flush_pending_paragraph(out, pending_para)
              break
            }

            let tag_bs = bs[p:q + 1].to_owned()
            let tag = (@utf8.decode(tag_bs, ignore_bom=false) catch { _ => "" }).to_lower()

            match html_note_body_range_end(note_plan, p) {
              Some(skip_end) =>
                if skip_end <= end_ {
                  flush_pending_paragraph(out, pending_para)
                  pos = skip_end
                  continue
                }
              None => ()
            }

            if tag.has_prefix("<!--") {
              let end0 = find_bytes(bs, close_comment, p + 4)
              match end0 {
                Some(end) =>
                  if end <= end_ {
                    pos = end + close_comment.length()
                    continue
                  }
                None => break
              }
            }

            match find_skippable_html_noise_subtree_end(bs, p, q, tag) {
              Some(skip_end) =>
                if skip_end <= end_ {
                  flush_pending_paragraph(out, pending_para)
                  pos = skip_end
                  continue
                }
              None => ()
            }

            if tag.has_prefix("<p") {
              flush_pending_paragraph(out, pending_para)

              let inner_start = q + 1
              let end0 = find_bytes(bs, close_p, inner_start)
              match end0 {
                None => ()
                Some(end) =>
                  if end <= end_ {
                    let inner = bs[inner_start:end].to_owned()
                    let xs = html_inlines_from_bytes_with_notes(
                      inner, note_plan,
                    )
                    if !inlines_is_blank(xs) {
                      out.push(HtmlNode::Paragraph(xs))
                    }
                    pos = end + close_p.length()
                    continue
                  }
              }
            }

            if tag.has_prefix("<blockquote") {
              flush_pending_paragraph(out, pending_para)

              let inner_start = q + 1
              let end0 = find_bytes(bs, close_blockquote, inner_start)
              match end0 {
                None => ()
                Some(end) =>
                  if end <= end_ {
                    let inner = bs[inner_start:end].to_owned()
                    let children = scan_html_nodes_in_container_with_notes(
                      inner, note_plan,
                    )
                    if !quote_children_is_blank(children) {
                      out.push(HtmlNode::BlockQuote(children))
                    }
                    pos = end + close_blockquote.length()
                    continue
                  }
              }
            }

            if tag.has_prefix("<pre") {
              flush_pending_paragraph(out, pending_para)

              let inner_start = q + 1
              let end0 = find_bytes(bs, close_pre, inner_start)
              match end0 {
                None => ()
                Some(end) =>
                  if end <= end_ {
                    let inner = bs[inner_start:end].to_owned()
                    let text = html_pre_text_from_bytes(inner)
                    if text.trim() != "" {
                      out.push(HtmlNode::CodeBlock(text))
                    }
                    pos = end + close_pre.length()
                    continue
                  }
              }
            }

            if tag.has_prefix("<table") {
              flush_pending_paragraph(out, pending_para)

              let inner_start = q + 1
              let end0 = find_bytes(bs, close_table, inner_start)
              match end0 {
                None => ()
                Some(end) =>
                  if end <= end_ {
                    let inner = bs[inner_start:end].to_owned()
                    let table = html_table_from_bytes_with_notes(
                      inner, note_plan,
                    )
                    if table.rows.length() > 0 {
                      out.push(HtmlNode::Table(table))
                    }
                    pos = end + close_table.length()
                    continue
                  }
              }
            }

            if tag.has_prefix("<ul") || tag.has_prefix("<ol") {
              let is_ol = tag.has_prefix("<ol")
              let list_name = if is_ol { "ol" } else { "ul" }

              match find_matching_list_end(bs, p, list_name) {
                Some(end) =>
                  if end <= end_ {
                    flush_pending_paragraph(out, pending_para)

                    let close_len = ("</" + list_name + ">").length()
                    let inner_start = q + 1
                    let inner_end = end

                    let items = scan_list_nodes(
                      bs, inner_start, inner_end, is_ol, next_level, note_plan,
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

            // unrecognized tag: skip it
            pos = q + 1
          }
        }
      }
    }
  }

  flush_pending_paragraph(out, pending_para)
  out
}

///|
fn scan_html_nodes_in_container_with_notes(
  bs : Bytes,
  note_plan : HtmlNotePlan,
) -> Array[HtmlNode] raise {
  let out : Array[HtmlNode] = []
  let pending_para : Array[HtmlInline] = []

  let lt = pat("<")
  let gt = pat(">")

  let close_p = pat("</p>")
  let close_blockquote = pat("</blockquote>")
  let close_pre = pat("</pre>")
  let close_table = pat("</table>")
  let close_script = pat("</script>")
  let close_style = pat("</style>")
  let close_head = pat("</head>")
  let close_noscript = pat("</noscript>")
  let close_details = pat("</details>")
  let close_summary = pat("</summary>")
  let close_comment = pat("-->")

  let mut pos = 0
  let n = bs.length()

  while pos < n {
    let lt0 = find_bytes(bs, lt, pos)
    match lt0 {
      None => {
        let tail = bs[pos:n].to_owned()
        let xs = html_inlines_from_bytes_with_notes(tail, note_plan)
        if !inlines_is_blank(xs) {
          append_inlines(pending_para, xs)
        }
        flush_pending_paragraph(out, pending_para)
        break
      }
      Some(p) => {
        if p > pos {
          let head = bs[pos:p].to_owned()
          let xs = html_inlines_from_bytes_with_notes(head, note_plan)
          if !inlines_is_blank(xs) {
            append_inlines(pending_para, xs)
          }
        }

        let gt0 = find_bytes(bs, gt, p)
        match gt0 {
          None => {
            let tail = bs[p:n].to_owned()
            let xs = html_inlines_from_bytes_with_notes(tail, note_plan)
            if !inlines_is_blank(xs) {
              append_inlines(pending_para, xs)
            }
            flush_pending_paragraph(out, pending_para)
            break
          }
          Some(q) => {
            let tag_bs = bs[p:q + 1].to_owned()
            let tag = (@utf8.decode(tag_bs, ignore_bom=false) catch { _ => "" }).to_lower()

            match html_note_body_range_end(note_plan, p) {
              Some(skip_end) => {
                flush_pending_paragraph(out, pending_para)
                pos = skip_end
                continue
              }
              None => ()
            }

            if tag.has_prefix("<!--") {
              let end0 = find_bytes(bs, close_comment, p + 4)
              match end0 {
                Some(end) => {
                  pos = end + close_comment.length()
                  continue
                }
                None => break
              }
            }

            match find_skippable_html_noise_subtree_end(bs, p, q, tag) {
              Some(skip_end) => {
                flush_pending_paragraph(out, pending_para)
                pos = skip_end
                continue
              }
              None => ()
            }

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

            if tag.has_prefix("<noscript") {
              let j0 = find_bytes(bs, close_noscript, q + 1)
              match j0 {
                None => pos = q + 1
                Some(j) => pos = j + close_noscript.length()
              }
              continue
            }

            if tag.has_prefix("<h") && tag.length() >= 3 {
              let lvl_ch = tag[2]
              if lvl_ch >= '1' && lvl_ch <= '6' {
                flush_pending_paragraph(out, pending_para)

                let lvl = lvl_ch.to_int() - '0'.to_int()
                let close_h = pat("</h" + lvl.to_string() + ">")
                let inner_start = q + 1
                let end0 = find_bytes(bs, close_h, inner_start)
                match end0 {
                  None => ()
                  Some(end) => {
                    let inner = bs[inner_start:end].to_owned()
                    let xs = html_inlines_from_bytes_with_notes(
                      inner, note_plan,
                    )
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
              flush_pending_paragraph(out, pending_para)

              let inner_start = q + 1
              let end0 = find_bytes(bs, close_blockquote, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_owned()
                  let children = scan_html_nodes_in_container_with_notes(
                    inner, note_plan,
                  )
                  if !quote_children_is_blank(children) {
                    out.push(HtmlNode::BlockQuote(children))
                  }
                  pos = end + close_blockquote.length()
                  continue
                }
              }
            }

            if tag.has_prefix("<pre") {
              flush_pending_paragraph(out, pending_para)

              let inner_start = q + 1
              let end0 = find_bytes(bs, close_pre, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_owned()
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
              flush_pending_paragraph(out, pending_para)

              let inner_start = q + 1
              let end0 = find_bytes(bs, close_p, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_owned()
                  let xs = html_inlines_from_bytes_with_notes(inner, note_plan)
                  if !inlines_is_blank(xs) {
                    out.push(HtmlNode::Paragraph(xs))
                  }
                  pos = end + close_p.length()
                  continue
                }
              }
            }

            if tag.has_prefix("<details") {
              flush_pending_paragraph(out, pending_para)

              let inner_start = q + 1
              let end0 = find_bytes(bs, close_details, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_owned()
                  let children = scan_html_nodes_in_container_with_notes(
                    inner, note_plan,
                  )
                  for child in children {
                    out.push(child)
                  }
                  pos = end + close_details.length()
                  continue
                }
              }
            }

            if tag.has_prefix("<summary") {
              flush_pending_paragraph(out, pending_para)

              let inner_start = q + 1
              let end0 = find_bytes(bs, close_summary, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_owned()
                  let xs = html_inlines_from_bytes_with_notes(inner, note_plan)
                  if !inlines_is_blank(xs) {
                    out.push(HtmlNode::Paragraph(xs))
                  }
                  pos = end + close_summary.length()
                  continue
                }
              }
            }

            if tag.has_prefix("<ul") || tag.has_prefix("<ol") {
              let is_ol = tag.has_prefix("<ol")
              let list_name = if is_ol { "ol" } else { "ul" }

              match find_matching_list_end(bs, p, list_name) {
                Some(end) => {
                  flush_pending_paragraph(out, pending_para)

                  let close_len = ("</" + list_name + ">").length()
                  let inner_start = q + 1
                  let inner_end = end

                  let items = scan_list_nodes(
                    bs, inner_start, inner_end, is_ol, 0, note_plan,
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
              flush_pending_paragraph(out, pending_para)

              let inner_start = q + 1
              let end0 = find_bytes(bs, close_table, inner_start)
              match end0 {
                None => ()
                Some(end) => {
                  let inner = bs[inner_start:end].to_owned()
                  let table = html_table_from_bytes_with_notes(inner, note_plan)
                  if table.rows.length() > 0 {
                    out.push(HtmlNode::Table(table))
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

  flush_pending_paragraph(out, pending_para)
  out
}

///|
/// whether there is any block-like tag inside [start, end_)
/// used by <li> fast path to distinguish:
/// - pure inline content  -> one paragraph
/// - true block/mixed item -> scan into child blocks
