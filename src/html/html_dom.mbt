///|
pub enum HtmlNode {
  Heading(Int, String)
  Paragraph(String)
  ListItem(String)
}

///|
fn scan_html_nodes(bs : Bytes) -> Array[HtmlNode] raise {
  let out : Array[HtmlNode] = []

  let lt = pat("<")
  let gt = pat(">")

  let close_p = pat("</p>")
  let close_li = pat("</li>")

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

            pos = q + 1
          }
        }
      }
    }
  }

  out
}
