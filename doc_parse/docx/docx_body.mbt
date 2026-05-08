///|
fn extract_docx_body_inner(doc_xml : String) -> String raise {
  let chars = doc_xml.to_array()
  let body_start = find_exact_open_tag(chars, 0, wbody_open_tag_chars)
  if body_start < 0 {
    raise DocxError::ParseError("malformed document xml: missing <w:body>")
  }
  let body_open_end = find_sub(chars, body_start, ">")
  if body_open_end < 0 {
    raise DocxError::ParseError("malformed document xml: invalid <w:body> tag")
  }
  let body_close = find_pattern_in_range(
    chars,
    body_open_end + 1,
    chars.length(),
    wbody_close_tag_chars,
  )
  if body_close < 0 {
    raise DocxError::ParseError("malformed document xml: missing </w:body>")
  }
  @cor.slice_to_string(chars, body_open_end + 1, body_close)
}

///|
fn parse_docx_body_blocks(
  xml : String,
  ctx : DocxPartParseContext,
  styles : DocxStyles,
  numbering : DocxNumbering,
) -> Array[DocxBodyBlock] {
  let chars = xml.to_array()
  let out : Array[DocxBodyBlock] = []
  let mut i = 0

  while i < chars.length() {
    let p_tbl = find_exact_open_tag(chars, i, wtbl_open_tag_chars)
    let p_p = find_exact_open_tag(chars, i, wp_open_tag_chars)

    if p_tbl >= 0 && (p_p < 0 || p_tbl < p_p) {
      let t2 = find_sub(chars, p_tbl, ">")
      if t2 < 0 {
        break
      }
      let t3 = find_matching_docx_element_close(
        chars, p_tbl, wtbl_open_tag_chars, wtbl_close_tag_chars,
      )
      if t3 < 0 {
        break
      }
      let tbl_xml = @cor.slice_to_string(chars, t2 + 1, t3)
      out.push(
        DocxBodyBlock::Table(parse_docx_table(tbl_xml, ctx, styles, numbering)),
      )
      i = t3 + wtbl_close_tag_chars.length()
      continue
    }

    if p_p >= 0 {
      let p2 = find_sub(chars, p_p, ">")
      if p2 < 0 {
        break
      }
      if open_tag_is_self_closing(chars, p_p, p2) {
        i = p2 + 1
        continue
      }
      let p3 = find_matching_docx_element_close(
        chars, p_p, wp_open_tag_chars, wp_close_tag_chars,
      )
      if p3 < 0 {
        break
      }
      let p_xml = @cor.slice_to_string(chars, p2 + 1, p3)
      out.push(
        DocxBodyBlock::Paragraph(
          parse_docx_paragraph(p_xml, ctx, styles, numbering),
        ),
      )
      i = p3 + wp_close_tag_chars.length()
      continue
    }

    break
  }

  out
}

///|
fn collect_docx_hyperlinks_from_blocks(
  blocks : Array[DocxBodyBlock],
) -> Array[DocxHyperlink] {
  let out : Array[DocxHyperlink] = []
  for block in blocks {
    match block {
      DocxBodyBlock::Paragraph(p) =>
        for link in p.hyperlink_refs {
          out.push(link)
        }
      DocxBodyBlock::Table(table) =>
        for row in table.rows {
          for cell in row.cells {
            for link in collect_docx_hyperlinks_from_blocks(cell.body_blocks) {
              out.push(link)
            }
          }
        }
    }
  }
  out
}

///|
fn collect_docx_media_from_blocks(
  blocks : Array[DocxBodyBlock],
) -> Array[DocxMediaRef] {
  let out : Array[DocxMediaRef] = []
  for block in blocks {
    match block {
      DocxBodyBlock::Paragraph(p) =>
        for media in p.media_refs {
          out.push(media)
        }
      DocxBodyBlock::Table(table) =>
        for row in table.rows {
          for cell in row.cells {
            for media in collect_docx_media_from_blocks(cell.body_blocks) {
              out.push(media)
            }
          }
        }
    }
  }
  out
}

///|
fn docx_blocks_visible_text(blocks : Array[DocxBodyBlock]) -> String {
  let parts : Array[String] = []
  for block in blocks {
    match block {
      DocxBodyBlock::Paragraph(p) => {
        let text = docx_paragraph_visible_text(p)
        if text != "" {
          parts.push(text)
        }
      }
      DocxBodyBlock::Table(table) => {
        let rows : Array[String] = []
        for row in table.rows {
          let cells : Array[String] = []
          for cell in row.cells {
            let text = docx_blocks_visible_text(cell.body_blocks)
            if text != "" {
              cells.push(text)
            }
          }
          if cells.length() > 0 {
            rows.push(cells.join(" | "))
          }
        }
        if rows.length() > 0 {
          parts.push(rows.join("\n"))
        }
      }
    }
  }
  parts.join("\n")
}

///|
fn docx_paragraph_visible_text(p : DocxParagraph) -> String {
  let out = StringBuilder::new()
  for run in p.runs {
    for inline in run.inlines {
      match inline {
        DocxInline::Text(text) => out.write_string(text)
        DocxInline::Tab => out.write_string("\t")
        DocxInline::LineBreak => out.write_string("\n")
        DocxInline::Hyperlink(link) => out.write_string(link.text)
        DocxInline::FootnoteRef(id) =>
          out.write_string("[^" + id.to_string() + "]")
        DocxInline::EndnoteRef(id) =>
          out.write_string("[^e" + id.to_string() + "]")
        DocxInline::CommentRef(id) =>
          out.write_string("[comment " + id.to_string() + "]")
        DocxInline::DrawingRef(media) =>
          match media.alt_text {
            Some(text) => out.write_string(text)
            None => ()
          }
        DocxInline::Unsupported(_) => ()
      }
    }
  }
  @cor.trim_string(out.to_string())
}
