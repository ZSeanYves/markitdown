///|
pub fn scan_document(
  doc_xml : String,
  rels : Map[String, String],
  max_heading : Int,
) -> @cor.Document {
  let doc = @cor.new_document()
  let chars = doc_xml.to_array()
  let mut i = 0

  while i < chars.length() {
    // 优先表格（避免表格内部段落被当成普通段落重复解析）
    let p_tbl = find_sub(chars, i, "<w:tbl")
    let p_p = find_sub(chars, i, "<w:p")

    if p_tbl >= 0 && (p_p < 0 || p_tbl < p_p) {
      let t2 = find_sub(chars, p_tbl, ">")
      if t2 < 0 {
        break
      }
      let t3 = find_sub(chars, t2 + 1, "</w:tbl>")
      if t3 < 0 {
        break
      }

      let tbl_xml = @cor.slice_to_string(chars, t2 + 1, t3)
      let rows = scan_table_block(tbl_xml)
      if rows.length() > 0 {
        @cor.push(doc, @cor.Table(rows))
      }
      i = t3 + 8
      continue
    }

    if p_p >= 0 {
      let p2 = find_sub(chars, p_p, ">")
      if p2 < 0 {
        break
      }
      let p3 = find_sub(chars, p2 + 1, "</w:p>")
      if p3 < 0 {
        break
      }

      let p_xml = @cor.slice_to_string(chars, p2 + 1, p3)
      scan_paragraph(doc, p_xml, rels, max_heading)
      i = p3 + 6
      continue
    }

    break
  }

  doc
}
