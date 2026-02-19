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


///|
fn is_delim_for_tag(c : Char) -> Bool {
  c == ' ' || c == '>' || c == '/' || c == '\n' || c == '\r' || c == '\t'
}

// 只匹配真正的 "<w:t" 标签：后面必须是分隔符（空格 / > / /）
///|
fn find_wt_open(chars : Array[Char], from : Int) -> Int {
  let mut i = from
  while true {
    let p = find_sub(chars, i, "<w:t")
    if p < 0 {
      return -1
    }

    // "<w:t" 长度是 4
    if p + 4 < chars.length() && is_delim_for_tag(chars[p + 4]) {
      return p
    }

    i = p + 4
  }
  -1
}

///|
fn collect_wt_text(block : String) -> String {
  let chars = block.to_array()
  let mut i = 0
  let mut out = ""

  while true {
    let p1 = find_wt_open(chars, i)
    if p1 < 0 { break }

    let p2 = find_sub(chars, p1, ">")
    if p2 < 0 { break }

    let p3 = find_sub(chars, p2 + 1, "</w:t>")
    if p3 < 0 {
      i = p2 + 1
      continue
    }

    out = out + @cor.slice_to_string(chars, p2 + 1, p3)
    i = p3 + 6
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
  let text = collect_wt_text(p_xml)
  if !@cor.is_blank(text) {
    if level > 0 && level <= max_heading {
      @cor.push(doc, @cor.Heading(level, text))
    } else {
      @cor.push(doc, @cor.Paragraph(text))
    }
  }
}



fn is_delim(c: Char) -> Bool {
  c == ' ' || c == '>' || c == '/' || c == '\n' || c == '\r' || c == '\t'
}

fn find_tc_open(chars: Array[Char], from: Int) -> Int {
  // 只匹配真正的 "<w:tc ...>"，排除 "<w:tcW", "<w:tcPr", "<w:tcMar" ...
  let mut i = from
  while true {
    let p = find_sub(chars, i, "<w:tc")
    if p < 0 { return -1 }

    // "<w:tc" 长度是 5，后面必须是分隔符才算 cell 开始
    if p + 5 < chars.length() && is_delim(chars[p + 5]) {
      return p
    }

    i = p + 5
  }
  -1
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
