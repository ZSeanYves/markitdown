///|
pub async fn parse_pptx(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document {
  parse_pptx_impl(input_path, out_dir, max_heading) catch {
    e => raise @cor.AppError("pptx: crashed: " + e.to_string())
  }
}

///|
/// PPTX MVP parser
/// Strategy:
/// - list entries under ppt/slides/slide*.xml
/// - read each slide xml
/// - extract text runs <a:t>...</a:t>
/// - output as Heading + Paragraphs
pub async fn parse_pptx_impl(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
) -> @cor.Document {
  let z = @cor.open_zip(input_path) catch {
    e => raise @cor.AppError("pptx: open zip failed: " + e.to_string())
  }

  // find slides
  let slides = list_slide_entries(z)

  let doc = @cor.new_document()
  @cor.push(doc, @cor.Block::Heading(clamp_heading(1, max_heading), "PPTX"))

  if slides.length() == 0 {
    @cor.push(doc, @cor.Block::Paragraph("(no slides found)"))
    return doc
  }

  let mut idx = 1
  for path in slides {
    @cor.push(
      doc,
      @cor.Block::Heading(
        clamp_heading(2, max_heading),
        "Slide " + idx.to_string(),
      ),
    )
    //println(".. pptx: reading " + path)
    let xml = read_zip_bytes(z, path)
    //println(".. pptx: read ok, len=" + xml.length().to_string())
    let paras = extract_slide_paragraphs_bytes(xml)
    if paras.length() == 0 {
      @cor.push(doc, @cor.Block::Paragraph("(empty)"))
    } else {
      for p in paras {
        if p.trim() != "" {
          @cor.push(doc, @cor.Block::Paragraph(p))
        }
      }
    }
    @cor.push(doc, @cor.Block::BlankLine)
    idx = idx + 1
  }

  doc
}

///|
/// list ppt/slides/slide*.xml
fn list_slide_entries(z : @cor.ZipReader) -> Array[String] {
  let all = @cor.ZipReader::list_entries(z)
  let out : Array[String] = []
  for name in all {
    if name.has_prefix("ppt/slides/slide") && name.has_suffix(".xml") {
      out.push(name)
    }
  }
  // 简单字典序排序会让 slide10 排在 slide2 前；MVP 先这样也行
  out.sort()
  out
}

///|
async fn read_zip_bytes(z : @cor.ZipReader, name : String) -> Bytes {
  @cor.ZipReader::read_entry_bytes(z, name) catch {
    e =>
      raise @cor.AppError(
        "pptx: read zip entry failed: " + name + ": " + e.to_string(),
      )
  }
}

///|
fn extract_slide_paragraphs_bytes(xml : Bytes) -> Array[String] raise {
  let out : Array[String] = []

  let open_p = pat("<a:p")
  let close_p = pat("</a:p>")
  let open_t = pat("<a:t>")
  let close_t = pat("</a:t>")

  let mut pos = 0
  while true {
    let p0 = find_bytes(xml, open_p, pos)
    match p0 {
      None => break
      Some(i0) => {
        // find '>' end of <a:p ...>
        let gt = find_bytes(xml, pat(">"), i0)
        match gt {
          None => break
          Some(gt0) => {
            let inner_start = gt0 + 1
            let p_end = find_bytes(xml, close_p, inner_start)
            match p_end {
              None => break
              Some(p_end0) => {
                // scan inner for <a:t>...</a:t>
                let mut tpos = inner_start
                let mut acc = ""
                while tpos < p_end0 {
                  let t0 = find_bytes(xml, open_t, tpos)
                  match t0 {
                    None => break
                    Some(t0i) => {
                      if t0i >= p_end0 {
                        break
                      }
                      let content_start = t0i + open_t.length()
                      let t1 = find_bytes(xml, close_t, content_start)
                      match t1 {
                        None => break
                        Some(t1i) => {
                          if t1i > p_end0 {
                            break
                          }
                          let seg = xml[content_start:t1i].to_bytes()
                          // decode UTF-8 content bytes -> String
                          let s = @cor.utf8_bytes_to_string(seg) catch {
                            _ => ""
                          }
                          acc = acc + s
                          tpos = t1i + close_t.length()
                        }
                      }
                    }
                  }
                }

                let line = xml_unescape(acc).trim().to_string()
                if line != "" {
                  out.push(line)
                }

                pos = p_end0 + close_p.length()
              }
            }
          }
        }
      }
    }
  }

  out
}

// ============================
// Utilities
// ============================
// ASCII patterns as bytes

///|
fn pat(s : String) -> Bytes {
  @utf8.encode(s)
}

///|
fn find_bytes(hay : Bytes, needle : Bytes, start : Int) -> Int? {
  let n = hay.length()
  let m = needle.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start > n - m {
    return None
  }
  let last = n - m
  let mut i = start
  while i <= last {
    // compare bytes
    let mut ok = true
    let mut j = 0
    while j < m {
      if hay[i + j] != needle[j] {
        ok = false
        break
      }
      j = j + 1
    }
    if ok {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn clamp_heading(level : Int, max_h : Int) -> Int {
  if level < 1 {
    1
  } else if level > max_h {
    max_h
  } else {
    level
  }
}

///|
fn xml_unescape(s : String) -> String raise {
  // 先基础实体，再数字实体（复用你 xlsx 的实现）
  let t = s
    .replace(old="&lt;", new="<")
    .replace(old="&gt;", new=">")
    .replace(old="&amp;", new="&")
    .replace(old="&quot;", new="\"")
    .replace(old="&apos;", new="'")
  @cor.decode_numeric_entities(t)
}
