///|
fn scan_paragraph(
  doc : @cor.Document,
  p_xml : String,
  rels : Map[String, String],
  max_heading : Int,
) -> Unit {
  // 1) 标题级别
  let level = read_heading_level(p_xml, max_heading)

  // 2) 图片 embed（常见：<a:blip r:embed="rId5">，直接找 r:embed="）
  match read_attr_value(p_xml, "r:embed=\"") {
    Some(rid) =>
      match rels.get(rid) {
        Some(target) => {
          let asset = rid_to_asset_path(target)
          @cor.push(doc, @cor.Image("image", asset))
        }
        None => ()
      }
    None => ()
  }

  // 3) 段落文本
  let text = collect_wt_text(p_xml)
  if @cor.is_blank(text) {
    return
  }

  if level > 0 {
    @cor.push(doc, @cor.Block::Heading(level, text))
    return
  }

  if paragraph_is_list_item(p_xml) {
    @cor.push(doc, @cor.Block::ListItem(text))
    return
  }

  @cor.push(doc, @cor.Block::Paragraph(text))
}

///|
fn read_heading_level(p_xml : String, max_heading : Int) -> Int {
  match read_attr_value(p_xml, "<w:pStyle w:val=\"") {
    Some(v) => {
      let level = if v == "Heading1" {
        1
      } else if v == "Heading2" {
        2
      } else if v == "Heading3" {
        3
      } else if v == "Heading4" {
        4
      } else if v == "Heading5" {
        5
      } else if v == "Heading6" {
        6
      } else {
        0
      }

      if level < 1 {
        0
      } else if level > max_heading {
        max_heading
      } else {
        level
      }
    }
    None => 0
  }
}

///|
fn scan_table_block(tbl_xml : String) -> Array[Array[String]] {
  let chars = tbl_xml.to_array()
  let mut i = 0
  let rows : Array[Array[String]] = []

  while true {
    let tr1 = find_sub(chars, i, "<w:tr")
    if tr1 < 0 {
      break
    }
    let tr2 = find_sub(chars, tr1, ">")
    if tr2 < 0 {
      break
    }
    let tr3 = find_sub(chars, tr2 + 1, "</w:tr>")
    if tr3 < 0 {
      break
    }

    let tr_inner = @cor.slice_to_string(chars, tr2 + 1, tr3)
    let tr_chars = tr_inner.to_array()

    let mut j = 0
    let cells : Array[String] = []

    while true {
      let tc1 = find_tc_open(tr_chars, j)
      if tc1 < 0 {
        break
      }

      let tc2 = find_sub(tr_chars, tc1, ">")
      if tc2 < 0 {
        break
      }

      let tc3 = find_sub(tr_chars, tc2 + 1, "</w:tc>")
      if tc3 < 0 {
        break
      }

      let tc_inner = @cor.slice_to_string(tr_chars, tc2 + 1, tc3)

      // 只从 tc_inner 里抽 w:t
      let cell_text = collect_wt_text(tc_inner)
      //println("[DBG] cell_text=" + cell_text)
      //println("[DBG] cell_len=" + cell_text.length().to_string())

      cells.push(cell_text)

      // 游标推进："</w:tc>" 长度 7
      j = tc3 + 7
    }

    if cells.length() > 0 {
      rows.push(cells)
    }

    // "</w:tr>" 长度 7
    i = tr3 + 7
  }

  rows
}

///|
/// MVP: 只要段落里出现 numPr / ilvl / numId，就先视为列表项
fn paragraph_is_list_item(p_xml : String) -> Bool {
  p_xml.contains("<w:numPr") ||
  p_xml.contains("<w:ilvl") ||
  p_xml.contains("<w:numId")
}
