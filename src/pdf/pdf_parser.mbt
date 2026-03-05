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
  Ok(pick_best_extracted_text(cands))
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

        if is_short(buf) || is_short(next) {

        } else {
          // 真分段
          let p = finalize_paragraph(buf)
          if p != "" {
            paras.push(p)
          }
          buf = ""
        }
      } else if buf != "" && k >= n {
        // 文件结束，收尾
        let p = finalize_paragraph(buf)
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
      buf = buf + glue_between(buf, cur) + cur
    }

    i = i + 1
  }

  if buf != "" {
    let p = finalize_paragraph(buf)
    if p != "" {
      paras.push(p)
    }
  }

  paras
}

// ============================
// Utilities
// ============================

///|
/// 段落最后做一次清理：多空格折叠 + trim（字符级，不走 bytes）
fn finalize_paragraph(s : String) -> String {
  let t = s.trim()
  if t == "" {
    return ""
  }

  let mut out = ""
  let mut prev_space = false
  for c in t.to_array() {
    if c == ' ' {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + c.to_string()
      prev_space = false
    }
  }

  remove_cjk_inner_spaces(out.trim().to_string())
}

///|
/// 去掉中文/全角符号之间的“字间空格”
fn remove_cjk_inner_spaces(s : String) -> String {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return s
  }

  let mut out = ""
  let mut i = 0
  while i < n {
    let c = cs[i]

    if c == ' ' {
      if i > 0 && i + 1 < n {
        let prev = cs[i - 1]
        let next = cs[i + 1]
        if is_cjkish(prev) && is_cjkish(next) {
          i = i + 1
          continue
        }
      }
      out = out + " "
      i = i + 1
      continue
    }

    out = out + c.to_string()
    i = i + 1
  }

  out
}

///|
/// 粗略判断“中文相关字符”：CJK 汉字,全角区（含中文标点）,常见中文标点
fn is_cjkish(c : Char) -> Bool {
  let x = c.to_int()
  (x >= 0x4E00 && x <= 0x9FFF) || // CJK Unified
  (x >= 0x3400 && x <= 0x4DBF) || // Extension A
  (x >= 0xF900 && x <= 0xFAFF) || // Compatibility
  (x >= 0xFF00 && x <= 0xFFEF) || // Half/Full width
  c == '，' ||
  c == '。' ||
  c == '；' ||
  c == '：' ||
  c == '！' ||
  c == '？'
}

///|
/// “短行”判断：<=2 个字符（对付中文被切成单字/两字的情况）
pub fn is_short(s : String) -> Bool {
  let t = s.trim()
  if t == "" {
    return true
  }
  t.to_array().length() <= 2
}

///|
/// 决定拼接时加不加空格：
/// - CJK + CJK：不加空格（中文不应该被强行加空格）
/// - 其他情况：加一个空格
pub fn glue_between(left : String, right : String) -> String {
  let lc = last_char(left)
  let rc = first_char(right)
  match (lc, rc) {
    (Some(a), Some(b)) => if is_cjk(a) && is_cjk(b) { "" } else { " " }
    _ => " "
  }
}

///|
fn first_char(s : String) -> Char? {
  let arr = s.trim().to_array()
  if arr.length() == 0 {
    None
  } else {
    Some(arr[0])
  }
}

///|
fn last_char(s : String) -> Char? {
  let arr = s.trim().to_array()
  let n = arr.length()
  if n == 0 {
    None
  } else {
    Some(arr[n - 1])
  }
}

///|
/// 粗略 CJK 判定（足够 MVP）
/// 覆盖：CJK Unified / Extensions / 常用全角符号区
fn is_cjk(c : Char) -> Bool {
  let x = c.to_int()
  (x >= 0x4E00 && x <= 0x9FFF) ||
  (x >= 0x3400 && x <= 0x4DBF) ||
  (x >= 0xF900 && x <= 0xFAFF) ||
  (x >= 0xFF00 && x <= 0xFFEF)
}

///|
fn pick_best_extracted_text(cands : Array[String]) -> String {
  let mut best = cands[0]
  let mut best_score = score_extracted_text(best)

  for i in 1..<cands.length() {
    let t = cands[i]
    let sc = score_extracted_text(t)
    if sc > best_score {
      best = t
      best_score = sc
    }
  }
  best
}

// 分数越高越好

///|
fn score_extracted_text(text : String) -> Int {
  let s = text.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
  let mut total = 0
  let mut blank = 0
  let mut short = 0
  let mut sum_len = 0

  for sv in s.split("\n") {
    let line = sv.to_string().trim().to_string()
    total = total + 1
    if line == "" {
      blank = blank + 1
      continue
    }
    let len = line.to_array().length()
    sum_len = sum_len + len
    if len <= 2 {
      short = short + 1
    }
  }

  let nonblank = total - blank
  let avg_len = if nonblank <= 0 { 0 } else { sum_len / nonblank }

  // 惩罚碎片化：短行、空行；奖励平均行长
  avg_len * 10 - blank * 3 - short * 5
}
