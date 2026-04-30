///|
fn scan_document(
  doc_xml : String,
  rel_ctx : DocxRelationshipContext,
  asset_by_target : Map[String, String],
  styles : DocxStyles,
  numbering : DocxNumbering,
  max_heading : Int,
  source_name : String,
) -> @cor.Document {
  let doc = @cor.new_document()
  let chars = doc_xml.to_array()
  let mut i = 0
  let mut prev_was_list = false

  while i < chars.length() {
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

      let tbl_xml = profiled_slice_to_string(chars, t2 + 1, t3)
      let rows = scan_table_block(tbl_xml)
      if rows.length() > 0 {
        if prev_was_list {
          @cor.push_with_origin(
            doc,
            @cor.Block::BlankLine,
            Some({
              source_name: Some(source_name),
              page: None,
              slide: None,
              sheet: None,
              block_index: Some(doc.blocks.val.length()),
              heading_path: None,
            }),
          )
        }
        @cor.push_with_origin(
          doc,
          @cor.Block::Table(rows),
          Some({
            source_name: Some(source_name),
            page: None,
            slide: None,
            sheet: None,
            block_index: Some(doc.blocks.val.length()),
            heading_path: None,
          }),
        )
        prev_was_list = false
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

      profile_paragraph_seen()
      let p_xml = profiled_slice_to_string(chars, p2 + 1, p3)
      let blocks = scan_paragraph(
        p_xml, rel_ctx, asset_by_target, styles, numbering, max_heading,
      )

      for b in blocks {
        let cur_is_list = match b {
          @cor.Block::ListItem(_, _, _) => true
          _ => false
        }

        if prev_was_list && !cur_is_list {
          @cor.push_with_origin(
            doc,
            @cor.Block::BlankLine,
            Some({
              source_name: Some(source_name),
              page: None,
              slide: None,
              sheet: None,
              block_index: Some(doc.blocks.val.length()),
              heading_path: None,
            }),
          )
        }

        @cor.push_with_origin(
          doc,
          b,
          Some({
            source_name: Some(source_name),
            page: None,
            slide: None,
            sheet: None,
            block_index: Some(doc.blocks.val.length()),
            heading_path: None,
          }),
        )
        prev_was_list = cur_is_list
      }

      i = p3 + 6
      continue
    }

    break
  }

  doc
}
