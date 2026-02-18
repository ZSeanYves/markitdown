///|
fn find_sub(chars : Array[Char], from : Int, pat : String) -> Int {
  let p = pat.to_array()
  let plen = p.length()
  let mut i = from
  while i + plen <= chars.length() {
    let mut ok = true
    for k in 0..<plen {
      if chars[i + k] != p[k] {
        ok = false
        break
      }
    }
    if ok {
      return i
    }
    i += 1
  }
  -1
}

///|
fn find_tag_tc(chars : Array[Char], from : Int) -> Int {
  // 找 "<w:tc" 且后一个字符不是字母（排除 <w:tcW / <w:tcPr 等）
  let mut i = from
  while true {
    let p = find_sub(chars, i, "<w:tc")
    if p < 0 {
      return -1
    }

    let next = p + 5 // "<w:tc".length() == 5
    if next >= chars.length() {
      return p
    }

    let c = chars[next]
    // 真正的 tc 标签：<w:tc> 或 <w:tc ... 或 <w:tc/>
    if c == ' ' || c == '>' || c == '/' {
      return p
    }

    // 否则就是 <w:tcW / <w:tcPr...，跳过继续找
    i = next
  }
  -1
}

///|
fn read_attr_value(block : String, attr_pat : String) -> String? {
  // 在 block 字符串里找 attr_pat（比如 "<w:pStyle w:val=\"" 或 "r:embed=\"")
  // 找到则返回引号中的内容
  let chars = block.to_array()
  let pos = find_sub(chars, 0, attr_pat)
  if pos < 0 {
    return None
  }
  let start = pos + attr_pat.length()
  let mut j = start
  let buf : Ref[Array[Char]] = { val: [] }
  while j < chars.length() && chars[j] != '"' {
    buf.val.push(chars[j])
    j += 1
  }
  Some(String::from_array(buf.val))
}


fn collect_all_text(block: String) -> String {
  let chars = block.to_array()
  let mut i = 0
  let mut out = ""

  while true {
    let p1 = find_sub(chars, i, "<w:t")
    if p1 < 0 { break }

    // 找到 <w:t ...> 的 >
    let p2 = find_sub(chars, p1, ">")
    if p2 < 0 { break }

    // 严格要求闭合 </w:t>
    let p3 = find_sub(chars, p2 + 1, "</w:t>")
    if p3 < 0 {
      // 没闭合就跳过这个 <w:t ...>，继续往后找
      i = p2 + 1
      continue
    }

    out = out + @cor.slice_to_string(chars, p2 + 1, p3)
    i = p3 + 6  // "</w:t>".length() == 6
  }

  @cor.trim_string(out)
}



///|
fn scan_paragraph(
  doc : @cor.Document,
  p_xml : String,
  rels : Map[String, String],
  max_heading : Int,
) -> Unit {
  // 1) 标题级别：更精确地匹配段落样式 <w:pStyle w:val="Heading1">
  let mut level = 0
  match read_attr_value(p_xml, "<w:pStyle w:val=\"") {
    Some(v) =>
      if v == "Heading1" {
        level = 1
      } else if v == "Heading2" {
        level = 2
      } else if v == "Heading3" {
        level = 3
      } else {
        level = 0
      }
    None => ()
  }

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
  let text = collect_all_text(p_xml)
  if !@cor.is_blank(text) {
    if level > 0 && level <= max_heading {
      @cor.push(doc, @cor.Heading(level, text))
    } else {
      @cor.push(doc, @cor.Paragraph(text))
    }
  }
}



///|
fn scan_table_block(tbl_xml : String) -> Array[Array[String]] {
  let chars = tbl_xml.to_array()
  let mut i = 0
  let rows : Array[Array[String]] = []

  let tr_close_tag = "</w:tr>"
  let tc_close_tag = "</w:tc>"

  while true {
    let tr1 = find_sub(chars, i, "<w:tr")
    if tr1 < 0 {
      break
    }

    let tr2 = find_sub(chars, tr1, ">")
    if tr2 < 0 {
      break
    }

    let tr3 = find_sub(chars, tr2 + 1, tr_close_tag)
    if tr3 < 0 {
      break
    }

    // 只取 tr 内部（不含 <w:tr ...> 与 </w:tr>）
    let tr_inner = @cor.slice_to_string(chars, tr2 + 1, tr3)
    let tr_chars = tr_inner.to_array()

    let cells : Array[String] = []
    let mut j = 0

    while true {
      // 关键：只找真正的 <w:tc（排除 tcW/tcPr）
      let tc_start = find_tag_tc(tr_chars, j)
      if tc_start < 0 {
        break
      }

      // 找 <w:tc ...> 的 '>'
      let tc_open_end = find_sub(tr_chars, tc_start, ">")
      if tc_open_end < 0 {
        break
      }

      // 找 </w:tc>
      let tc_close = find_sub(tr_chars, tc_open_end + 1, tc_close_tag)
      if tc_close < 0 {
        break
      }

      // tc_inner：单元格内容区域
      let tc_inner = @cor.slice_to_string(tr_chars, tc_open_end + 1, tc_close)

      // 只抽取 w:t 文本（不会有任何 XML）
      let txt = collect_all_text(tc_inner)
      cells.push(txt)
      println("cell=" + txt)


      // 推进到 </w:tc> 后继续
      j = tc_close + tc_close_tag.length()
    }

    if cells.length() > 0 {
      rows.push(cells)
    }

    i = tr3 + tr_close_tag.length()
  }

  rows
}



///|
pub fn scan_document_xml(
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
