///|
/// Guarded complex path: raw table scanning remains responsible for runtime
/// RichTable compatibility, spans, ragged rows, captions, nested/complex cells,
/// and malformed table recovery until parser-fact table lowering fully replaces it.
priv struct HtmlTable {
  rows : Array[Array[Array[HtmlInline]]]
  header_rows : Int
  span_cells : Array[HtmlTableSpanCell]
}

///|
priv struct HtmlTableSpanCell {
  row_index : Int
  column_index : Int
  rowspan : Int
  colspan : Int
  text : String?
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
fn html_table_from_bytes_with_notes(
  inner : Bytes,
  note_plan : HtmlNotePlan,
) -> HtmlTable {
  let out : Array[Array[Array[HtmlInline]]] = []
  let span_cells : Array[HtmlTableSpanCell] = []

  let close_tr = pat("</tr>")

  let mut pos = 0
  while true {
    let tr0 = find_open_tag_with_name(inner, "tr", pos)
    match tr0 {
      None => break
      Some((_, q0)) => {
        let row_start = q0 + 1
        let end0 = find_bytes_case_insensitive(inner, close_tr, row_start)
        match end0 {
          None => break
          Some(end) => {
            let tr_inner = inner[row_start:end].to_owned()
            let row_index = out.length() + 1
            let (cells, row_spans) = html_table_row_from_bytes(
              tr_inner, row_index, note_plan,
            )
            if cells.length() > 0 {
              out.push(cells)
            }
            for span in row_spans {
              span_cells.push(span)
            }
            pos = end + close_tr.length()
          }
        }
      }
    }
  }

  {
    rows: normalize_table_rows(out),
    header_rows: html_table_header_rows(inner),
    span_cells,
  }
}

///|
fn html_table_header_rows(inner : Bytes) -> Int {
  if find_open_tag_with_name(inner, "thead", 0) is Some(_) {
    return 1
  }

  let close_tr = pat("</tr>")

  let tr0 = find_open_tag_with_name(inner, "tr", 0)
  match tr0 {
    None => 0
    Some((_, q0)) => {
      let row_start = q0 + 1
      let end0 = find_bytes_case_insensitive(inner, close_tr, row_start)
      match end0 {
        None => 0
        Some(end) => {
          let tr_inner = inner[row_start:end].to_owned()
          if find_open_tag_with_name(tr_inner, "th", 0) is Some(_) {
            1
          } else {
            0
          }
        }
      }
    }
  }
}

///|
fn html_table_row_from_bytes(
  tr_inner : Bytes,
  row_index : Int,
  note_plan : HtmlNotePlan,
) -> (Array[Array[HtmlInline]], Array[HtmlTableSpanCell]) {
  let out : Array[Array[HtmlInline]] = []
  let spans : Array[HtmlTableSpanCell] = []

  let close_td = pat("</td>")
  let close_th = pat("</th>")

  let mut pos = 0
  let n = tr_inner.length()
  let mut col_index = 1

  while pos < n {
    let td0 = find_open_tag_with_name(tr_inner, "td", pos)
    let th0 = find_open_tag_with_name(tr_inner, "th", pos)

    let next = match (td0, th0) {
      (Some((a, a_gt)), Some((b, b_gt))) =>
        if a < b {
          Some((a, a_gt, false))
        } else {
          Some((b, b_gt, true))
        }
      (Some((a, a_gt)), None) => Some((a, a_gt, false))
      (None, Some((b, b_gt))) => Some((b, b_gt, true))
      (None, None) => None
    }

    match next {
      None => break
      Some((i0, q0, is_th)) => {
        let cell_start = q0 + 1
        let end0 = if is_th {
          find_bytes_case_insensitive(tr_inner, close_th, cell_start)
        } else {
          find_bytes_case_insensitive(tr_inner, close_td, cell_start)
        }

        match end0 {
          None => break
          Some(end) => {
            let cell_inner = tr_inner[cell_start:end].to_owned()
            let xs = html_inlines_from_bytes_with_notes(cell_inner, note_plan)
            let tag_bs = tr_inner[i0:q0 + 1].to_owned()
            let tag0 = @utf8.decode(tag_bs, ignore_bom=false) catch { _ => "" }
            let rowspan = parse_html_positive_int_attr(
              @dphtml.html_attr_value(tag0, "rowspan"),
            )
            let colspan = parse_html_positive_int_attr(
              @dphtml.html_attr_value(tag0, "colspan"),
            )
            if rowspan > 1 || colspan > 1 {
              spans.push({
                row_index,
                column_index: col_index,
                rowspan,
                colspan,
                text: normalized_optional_text(render_inlines(xs)),
              })
            }
            out.push(xs)
            let mut repeat = 1
            while repeat < colspan {
              out.push([])
              repeat += 1
            }
            col_index += colspan

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

  (out, spans)
}

///|
fn parse_html_positive_int_attr(raw : String?) -> Int {
  match raw {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        return 1
      }
      let chars = trimmed.to_array()
      let mut i = 0
      let mut n = 0
      while i < chars.length() {
        let c = chars[i]
        let k = c.to_int()
        if k < 48 || k > 57 {
          return 1
        }
        n = n * 10 + (k - 48)
        i += 1
      }
      if n <= 0 {
        1
      } else {
        n
      }
    }
    None => 1
  }
}
