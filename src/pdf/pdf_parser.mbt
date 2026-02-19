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
async fn extract_pdf_text(path : String) -> Result[String, @cor.AppError] {
  let cands : Array[String] = []

  // 1) pdftotext: default / layout / raw
  match run_and_capture("pdftotext", [path, "-"]) {
    Ok(out) => if out.trim() != "" { cands.push(out) }
    Err(_) => ()
  }
  match run_and_capture("pdftotext", ["-layout", path, "-"]) {
    Ok(out) => if out.trim() != "" { cands.push(out) }
    Err(_) => ()
  }
  match run_and_capture("pdftotext", ["-raw", path, "-"]) {
    Ok(out) => if out.trim() != "" { cands.push(out) }
    Err(_) => ()
  }

  // 2) fallback: mutool
  match run_and_capture("mutool", ["draw", "-F", "txt", path]) {
    Ok(out) => if out.trim() != "" { cands.push(out) }
    Err(_) => ()
  }

  if cands.length() == 0 {
    return Err(
      @cor.AppError(
        "No PDF text extractor available. Please install `pdftotext` (poppler) or `mutool` (mupdf).",
      ),
    )
  }

  // pick best by heuristic score
  Ok(@cor.pick_best_extracted_text(cands))
}


///|
fn missing_tools_hint() -> String {
  "未找到 pdftotext（Poppler）或 mutool（MuPDF），请安装后重试。\n" +
  "macOS: brew install poppler mupdf-tools\n" +
  "Ubuntu/Debian: sudo apt-get install poppler-utils mupdf-tools\n" +
  "Arch: sudo pacman -S poppler mupdf-tools\n"
}

///|
async fn run_and_capture(
  cmd : String,
  args : Array[String],
) -> Result[String, @cor.AppError] {
  // stdout / stderr 分开收集，避免 mutool 的进度信息污染输出
  let res = @proc.collect_output(cmd, args[:]) catch {
    e => {
      let msg = e.to_string()
      // 统一缺命令错误信息
      if msg.contains("No such file or directory") || msg.contains("not found") {
        return Err(@cor.AppError(missing_tools_hint()))
      }
      return Err(@cor.AppError("spawn failed: " + msg))
    }
  }

  let (status, out_data, err_data) = res

  let stdout : String = out_data.text() catch {
    _ => return Err(@cor.AppError("invalid utf-8 stdout"))
  }
  let stderr : String = err_data.text() catch { _ => "" }

  if status != 0 {
    // 有些情况下（权限/参数）也可能输出 not found，
    if stderr.contains("No such file or directory") ||
      stderr.contains("not found") {
      return Err(@cor.AppError(missing_tools_hint()))
    }
    return Err(
      @cor.AppError(
        "Command failed: " + cmd + " " + args.join(" ") + "\n" + stderr,
      ),
    )
  }

  Ok(stdout)
}





///|
/// Convert plain text into IR.
/// Strategy (MVP):
/// - Normalize line endings
/// - Split by blank lines into paragraphs
/// - Insert a horizontal rule between pages if extractor outputs formfeed \f
fn text_to_ir_document(text0 : String) -> @cor.Document {
  let text = @cor.normalize_text(text0)
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




