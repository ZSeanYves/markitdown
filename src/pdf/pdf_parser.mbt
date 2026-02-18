///|
pub struct PdfParseOptions {
  out_dir : String? // TODO：MVP 不导出图片也不需要
}

///|
pub async fn parse_pdf(
  path : String,
  opts : PdfParseOptions,
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
  let (status, output) = @proc.collect_output_merged(cmd, args)
  let output : String =
    try {
      output.text()
    } catch {
      _ => return Err(@cor.AppError("process output is not valid utf-8"))
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
fn text_to_ir_document(text0 : String) -> @cor.Document raise Error{
  let text = normalize_text(text0)
  let doc = @cor.new_document()

  let mut first_page = true

  for page_sv in text.split("\f") { // Iter[StringView]
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
      if t == "" { continue }
      @cor.push(doc, @cor.Block::Paragraph(t))
      @cor.push(doc, @cor.Block::BlankLine)
    }

      }

  doc
}

///|
/// 更适合 PDF 的分段：
/// - 连续空行 => 段落边界
/// - 段内单换行 => 合并为空格
/// - 可选：处理连字符断词 "hyphen-\nated" => "hyphenated"
fn split_paragraphs_smart(page : String) -> Array[String] raise Error { 
  // 先做基础替换：NBSP、Tab、CR
  let s =
    page
      .replace(old="\r\n", new="\n")
      .replace(old="\r", new="\n")
      .replace(old="\u00A0", new=" ")
      .replace(old="\t", new=" ")

  let paras : Array[String] = []
  let mut buf : String = ""
  let mut prev_blank = false

  for line_sv in s.split("\n") {
    let line_trim_sv = line_sv.trim()

    // 空行：触发段落结束（连续空行只触发一次）
    if line_trim_sv == "" {
      if !prev_blank {
        let p = @cor.finalize_paragraph(buf)
        if p != "" { paras.push(p) }
        buf = ""
        prev_blank = true
      }
      continue
    }

    prev_blank = false
    let line = line_trim_sv.to_string()

    if buf == "" {
      buf = line
    } else {
      // 断词处理：如果 buf 以 '-' 结尾，则直接拼接（去掉 '-'）
      if @cor.ends_with_hyphen(buf) {
        buf = @cor.drop_last_char(buf) + line
      } else {
        // 否则用空格连接（把行内硬换行变成空格）
        buf = buf + " " + line
      }
    }
  }

  // 收尾
  let p = @cor.finalize_paragraph(buf)
  if p != "" { paras.push(p) }

  paras
}



///|
fn normalize_text(s : String) -> String {
  s.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
}


