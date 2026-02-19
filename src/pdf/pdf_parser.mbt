///|
pub struct PdfParseOptions {
  out_dir : String? // TODO：MVP 不导出图片也不需要
}

///|
pub async fn parse_pdf(
  path : String,
  _opts : PdfParseOptions,
) -> Result[@cor.Document, @cor.AppError] {
  // 1) basic check
  if !@fs.path_exists(path) {
    let e : @cor.AppError = @cor.AppError("PDF file not found: " + path)
    return Err(e)
  }

  // 2) extract plain text from PDF via external tool
  let text_res : Result[String, @cor.AppError] = extract_pdf_text(path)
  match text_res {
    Err(e) => Err(e)
    Ok(text) => Ok(text_to_ir_document(text))
  }
}

///|
/// Try multiple external backends to avoid vendor lock-in.
///
/// Preferred:
///   - pdftotext (Poppler): pdftotext <in.pdf> -
/// Fallback:
///   - mutool (MuPDF): mutool draw -F txt <in.pdf>
async fn extract_pdf_text(path : String) -> Result[String, @cor.AppError] {
  // Candidate 1: pdftotext
  // `-` means write to stdout
  match run_and_capture("pdftotext", [path, "-"]) {
    Ok(out) => if out.trim() != "" { return Ok(out) }
    Err(_) => ()
  }

  // Candidate 2: mutool (MuPDF)
  match run_and_capture("mutool", ["draw", "-F", "txt", path]) {
    Ok(out) => if out.trim() != "" { return Ok(out) }
    Err(_) => ()
  }

  Err(
    @cor.AppError(
      "No PDF text extractor available. Please install `pdftotext` (poppler) or `mutool` (mupdf).",
    ),
  )
}


///|
async fn run_and_capture(
  cmd : String,
  args : Array[String],
) -> Result[String, @cor.AppError] {
  let (status, data) = @proc.collect_output_merged(cmd, args) catch {
    e => return Err(@cor.AppError("spawn failed: " + e.to_string()))
  }

  let output : String = data.text() catch {
    _ => return Err(@cor.AppError("invalid utf-8 output"))
  }

  if status != 0 {
    return Err(
      @cor.AppError(
        "Command failed: " + cmd + " " + args.join(" ") + "\n" + output,
      ),
    )
  }

  Ok(output)
}



///|
/// Convert plain text into IR.
/// Strategy (MVP):
/// - Normalize line endings
/// - Split by blank lines into paragraphs
/// - Insert a horizontal rule between pages if extractor outputs formfeed \f
fn text_to_ir_document(text0 : String) -> @cor.Document {
  let text = normalize_text(text0)
  let doc = @cor.new_document()

  let mut first_page = true

  for page_sv in text.split("\f") { // Iter[StringView]
    let page0 = page_sv.to_string()
    if page0.trim() == "" {
      continue
    }
    if !first_page {
      // page separator: blank line + "---" + blank line（更像 markdown）
      @cor.push(doc, @cor.Block::BlankLine)
      @cor.push(doc, @cor.Block::Paragraph("---"))
      @cor.push(doc, @cor.Block::BlankLine)
    } else {
      first_page = false
    }

    let page = page_sv.to_string()

    for t in split_paragraphs_smart(page) {
      if t == "" {
        continue
      }
      @cor.push(doc, @cor.Block::Paragraph(t))
      @cor.push(doc, @cor.Block::BlankLine)
    }
  }

  doc
}

///|
/// PDF 分段：
pub fn split_paragraphs_smart(page : String) -> Array[String] {
  let s = page
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
    .replace(old="\u00A0", new=" ")
    .replace(old="\t", new=" ")

  // 先把行收集起来，方便做“空行前后 lookahead”
  let lines : Array[String] = []
  for sv in s.split("\n") {
    lines.push(sv.to_string())
  }

  let paras : Array[String] = []
  let mut buf = ""

  let n = lines.length()
  let mut i = 0
  while i < n {
    let cur = lines[i].trim().to_string()

    if cur == "" {
      // 数空行
      let mut k = i
      while k < n && lines[k].trim() == "" {
        k = k + 1
      }

      // 找下一个非空行（用于判断是否真分段）
      if buf != "" && k < n {
        let next = lines[k].trim().to_string()

        if @cor.is_short(buf) || @cor.is_short(next) {

        } else {
          // 真分段
          let p = @cor.finalize_paragraph(buf)
          if p != "" {
            paras.push(p)
          }
          buf = ""
        }
      } else if buf != "" && k >= n {
        // 文件结束，收尾
        let p = @cor.finalize_paragraph(buf)
        if p != "" {
          paras.push(p)
        }
        buf = ""
      }

      i = k
      continue
    }

    // 非空行：追加进 buf
    if buf == "" {
      buf = cur
    } else {
      buf = buf + @cor.glue_between(buf, cur) + cur
    }

    i = i + 1
  }

  if buf != "" {
    let p = @cor.finalize_paragraph(buf)
    if p != "" {
      paras.push(p)
    }
  }

  paras
}

///|
fn normalize_text(s : String) -> String {
  s.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
}


