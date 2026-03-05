///|
/// PPTX MVP parser
/// Strategy:
/// - list entries under ppt/slides/slide*.xml
/// - read each slide xml
/// - extract text runs <a:t>...</a:t>
/// - output as Heading + Paragraphs
pub async fn parse_pptx(
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
    let xml = read_zip_utf8(z, path)
    let paras = extract_slide_paragraphs(xml)
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
async fn read_zip_utf8(z : @cor.ZipReader, name : String) -> String {
  let bs = @cor.ZipReader::read_entry_bytes(z, name) catch {
    e =>
      raise @cor.AppError(
        "pptx: read zip entry failed: " + name + ": " + e.to_string(),
      )
  }
  @cor.utf8_bytes_to_string(bs) catch {
    e =>
      raise @cor.AppError(
        "pptx: invalid utf8 in " + name + ": " + e.to_string(),
      )
  }
}

///|
/// Extract paragraphs by scanning <a:p> ... </a:p> and collecting <a:t>...</a:t>
fn extract_slide_paragraphs(xml : String) -> Array[String] raise {
  let out : Array[String] = []
  let mut pos = 0

  while true {
    let p0 = find_sub(xml, "<a:p", pos)
    match p0 {
      None => break
      Some(i0) => {
        let p_tag_end = find_sub(xml, ">", i0)
        match p_tag_end {
          None => break
          Some(i1) => {
            let p_end0 = find_sub(xml, "</a:p>", i1 + 1)
            match p_end0 {
              None => break
              Some(p_end) => {
                let inner = xml[i1 + 1:p_end].to_string()
                let text = collect_all_a_t(inner)
                let t = xml_unescape(text).trim().to_string()
                if t != "" {
                  out.push(t)
                }
                pos = p_end + 6
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
fn collect_all_a_t(s : String) -> String raise {
  let mut pos = 0
  let mut acc = ""
  while true {
    let t0 = find_sub(s, "<a:t>", pos)
    match t0 {
      None => break
      Some(i0) => {
        let start = i0 + 5
        let t1 = find_sub(s, "</a:t>", start)
        match t1 {
          None => break
          Some(j) => {
            acc = acc + s[start:j].to_string()
            pos = j + 6
          }
        }
      }
    }
  }
  acc
}

// ============================
// Utilities
// ============================

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
fn find_sub(s : String, pat : String, start : Int) -> Int? raise {
  let n = s.length()
  let m = pat.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start >= n {
    return None
  }
  if n < m {
    return None
  }

  let last = n - m
  let mut i = start
  while i <= last {
    if s[i:i + m] == pat {
      return Some(i)
    }
    i += 1
  }
  None
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
