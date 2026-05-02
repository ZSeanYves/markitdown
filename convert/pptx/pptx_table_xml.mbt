///|
fn collect_explicit_table_frames(
  slide_xml : Bytes,
  hyperlinks : Map[String, String],
) -> Array[PptxTableFrame] raise {
  let out : Array[PptxTableFrame] = []
  let frames = collect_slide_objects(slide_xml).graphic_frames
  let mut frame_idx = 0
  for raw in frames {
    frame_idx += 1
    match
      parse_explicit_table_frame(raw.xml, frame_idx, hyperlinks, raw.object_ref) {
      Some(frame) => out.push(frame)
      None => ()
    }
  }

  out
}

///|
fn parse_explicit_table_frame(
  frame_xml : Bytes,
  frame_idx : Int,
  hyperlinks : Map[String, String],
  object_ref_override : String?,
) -> PptxTableFrame? raise {
  if !contains_bytes(frame_xml, pat("<a:tbl")) {
    return None
  }

  let rows = parse_pptx_table_rows(frame_xml, hyperlinks)
  if rows.length() == 0 {
    return None
  }

  let header_rows = explicit_table_header_rows(frame_xml, rows)
  Some({
    rows,
    header_rows,
    object_ref: match object_ref_override {
      Some(v) => Some(v)
      None =>
        Some(
          read_graphic_frame_object_ref_with_prefix(frame_xml, frame_idx, None),
        )
    },
  })
}

///|
fn explicit_table_header_rows(
  frame_xml : Bytes,
  rows : Array[Array[String]],
) -> Int raise {
  if rows.length() == 0 {
    return 0
  }

  let open_tblpr = pat("<a:tblPr")
  let gt_pat = pat(">")
  let p0 = find_bytes(frame_xml, open_tblpr, 0)
  match p0 {
    None => 1
    Some(i0) => {
      let gt = find_bytes(frame_xml, gt_pat, i0)
      match gt {
        None => 1
        Some(gt0) => {
          let tag = frame_xml[i0:gt0 + 1].to_owned()
          match read_attr_value_in_tag_bytes(tag, "firstRow") {
            Some(v) => if v == "0" || v.to_lower() == "false" { 0 } else { 1 }
            None => 1
          }
        }
      }
    }
  }
}

///|
fn read_graphic_frame_object_ref_with_prefix(
  frame_xml : Bytes,
  frame_idx : Int,
  prefix : String?,
) -> String raise {
  let open_cnvpr = pat("<p:cNvPr")
  let gt_pat = pat(">")
  let p0 = find_bytes(frame_xml, open_cnvpr, 0)
  let local_ref = match p0 {
    None => "graphicFrame-" + frame_idx.to_string()
    Some(i0) =>
      match find_bytes(frame_xml, gt_pat, i0) {
        None => "graphicFrame-" + frame_idx.to_string()
        Some(gt0) => {
          let tag = frame_xml[i0:gt0 + 1].to_owned()
          match read_attr_value_in_tag_bytes(tag, "id") {
            Some(id) =>
              if id.trim() == "" {
                "graphicFrame-" + frame_idx.to_string()
              } else {
                "graphicFrame-" + id.trim().to_owned()
              }
            None => "graphicFrame-" + frame_idx.to_string()
          }
        }
      }
  }
  match prefix {
    Some(p) =>
      if p.trim() == "" {
        local_ref
      } else if p.has_suffix("/" + local_ref) {
        p
      } else {
        p + "/" + local_ref
      }
    None => local_ref
  }
}

///|
fn parse_pptx_table_rows(
  frame_xml : Bytes,
  hyperlinks : Map[String, String],
) -> Array[Array[String]] raise {
  let open_tbl = pat("<a:tbl")
  let close_tbl = pat("</a:tbl>")
  let gt_pat = pat(">")
  let tbl0 = find_bytes(frame_xml, open_tbl, 0)
  match tbl0 {
    None => []
    Some(i0) => {
      let gt = find_bytes(frame_xml, gt_pat, i0)
      match gt {
        None => []
        Some(gt0) => {
          let end0 = find_bytes(frame_xml, close_tbl, gt0 + 1)
          match end0 {
            None => []
            Some(end) =>
              parse_table_rows_inner(
                frame_xml[gt0 + 1:end].to_owned(),
                hyperlinks,
              )
          }
        }
      }
    }
  }
}

///|
fn parse_table_rows_inner(
  inner : Bytes,
  hyperlinks : Map[String, String],
) -> Array[Array[String]] raise {
  let out : Array[Array[String]] = []
  let open_tr = pat("<a:tr")
  let close_tr = pat("</a:tr>")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let p0 = find_bytes(inner, open_tr, pos)
    match p0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(inner, gt_pat, i0)
        match gt {
          None => break
          Some(gt0) => {
            let end0 = find_bytes(inner, close_tr, gt0 + 1)
            match end0 {
              None => break
              Some(end) => {
                let row = parse_table_row_cells(
                  inner[gt0 + 1:end].to_owned(),
                  hyperlinks,
                )
                if row.length() > 0 {
                  out.push(row)
                }
                pos = end + close_tr.length()
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
fn parse_table_row_cells(
  row_xml : Bytes,
  hyperlinks : Map[String, String],
) -> Array[String] raise {
  let out : Array[String] = []
  let open_tc = pat("<a:tc")
  let close_tc = pat("</a:tc>")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let p0 = find_bytes(row_xml, open_tc, pos)
    match p0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(row_xml, gt_pat, i0)
        match gt {
          None => break
          Some(gt0) => {
            let tag = row_xml[i0:gt0 + 1].to_owned()
            let end0 = find_bytes(row_xml, close_tc, gt0 + 1)
            match end0 {
              None => break
              Some(end) => {
                let is_hmerge = pptx_bool_like_attr(tag, "hMerge")
                let is_vmerge = pptx_bool_like_attr(tag, "vMerge")
                let grid_span = pptx_positive_int_attr(tag, "gridSpan").unwrap_or(
                  1,
                )
                let text = if is_hmerge || is_vmerge {
                  ""
                } else {
                  parse_table_cell_text(
                    row_xml[gt0 + 1:end].to_owned(),
                    hyperlinks,
                  )
                }
                out.push(text)
                if grid_span > 1 {
                  for _ in 1..<grid_span {
                    out.push("")
                  }
                }
                pos = end + close_tc.length()
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
fn parse_table_cell_text(
  cell_xml : Bytes,
  hyperlinks : Map[String, String],
) -> String raise {
  let open_body = pat("<a:txBody")
  let close_body = pat("</a:txBody>")
  let gt_pat = pat(">")
  let body0 = find_bytes(cell_xml, open_body, 0)
  match body0 {
    None => ""
    Some(i0) => {
      let gt = find_bytes(cell_xml, gt_pat, i0)
      match gt {
        None => ""
        Some(gt0) => {
          let end0 = find_bytes(cell_xml, close_body, gt0 + 1)
          match end0 {
            None => ""
            Some(end) =>
              parse_table_cell_text_body(
                cell_xml[gt0 + 1:end].to_owned(),
                hyperlinks,
              )
          }
        }
      }
    }
  }
}

///|
fn parse_table_cell_text_body(
  body_xml : Bytes,
  hyperlinks : Map[String, String],
) -> String raise {
  let open_p = pat("<a:p")
  let close_p = pat("</a:p>")
  let gt_pat = pat(">")
  let paras : Array[String] = []

  let mut pos = 0
  while true {
    let p0 = find_bytes(body_xml, open_p, pos)
    match p0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(body_xml, gt_pat, i0)
        match gt {
          None => break
          Some(gt0) => {
            let end0 = find_bytes(body_xml, close_p, gt0 + 1)
            match end0 {
              None => break
              Some(end) => {
                let inlines = extract_text_inlines(
                  body_xml,
                  gt0 + 1,
                  end,
                  hyperlinks,
                )
                let rendered = render_pptx_table_inlines(inlines)
                  .trim()
                  .to_owned()
                if rendered != "" {
                  paras.push(rendered)
                }
                pos = end + close_p.length()
              }
            }
          }
        }
      }
    }
  }

  paras.join("<br>")
}

///|
fn render_pptx_table_inlines(xs : Array[@cor.Inline]) -> String {
  let mut out = ""
  for x in xs {
    match x {
      @cor.Inline::Text(t) => if t != "" { out = out + t }
      @cor.Inline::Break => out = out + "<br>"
      @cor.Inline::Link(text, href) => {
        let t = text.trim().to_owned()
        let h = href.trim().to_owned()
        if t == "" || h == "" {
          out = out + t
        } else {
          out = out + "[" + t + "](" + h + ")"
        }
      }
    }
  }
  out
}

///|
fn pptx_bool_like_attr(tag : Bytes, attr : String) -> Bool raise {
  match read_attr_value_in_tag_bytes(tag, attr) {
    Some(v) => {
      let lower = v.trim().to_lower()
      lower == "1" || lower == "true"
    }
    None => false
  }
}

///|
fn pptx_positive_int_attr(tag : Bytes, attr : String) -> Int? raise {
  match read_attr_value_in_tag_bytes(tag, attr) {
    Some(v) => {
      let n = parse_nonneg_int(v)
      if n > 0 {
        Some(n)
      } else {
        None
      }
    }
    None => None
  }
}
