///|
/// temporary local debug switch for PDF extractor selection
const PDF_EXTRACT_DEBUG = false

///|
fn debug_print_candidate(label : String, text : String) -> Unit {
  if !PDF_EXTRACT_DEBUG {
    return
  }

  let score = score_extracted_text(text)
  println("[pdf-debug] candidate=" + label + " score=" + score.to_string())

  let s = text.replace(old="\r\n", new="\n").replace(old="\r", new="\n")

  let mut shown = 0
  for sv in s.split("\n") {
    let line = sv.to_string().trim().to_string()
    if line != "" {
      println("[pdf-debug]   " + line)
      shown += 1
      if shown >= 8 {
        break
      }
    }
  }
  let all_lines : Array[String] = []
  for sv in s.split("\n") {
    let line = sv.to_string().trim().to_string()
    if line != "" {
      all_lines.push(line)
    }
  }

  println("[pdf-debug]   -- tail --")
  let start = if all_lines.length() > 5 { all_lines.length() - 5 } else { 0 }
  for i in start..<all_lines.length() {
    println("[pdf-debug]   " + all_lines[i])
  }

  if shown == 0 {
    println("[pdf-debug]   <empty>")
  }
}

///|
fn debug_print_selected(label : String, score : Int) -> Unit {
  if !PDF_EXTRACT_DEBUG {
    return
  }
  println("[pdf-debug] selected=" + label + " score=" + score.to_string())
}

///|
priv struct PdfExtractCandidate {
  label : String
  text : String
}

///|
/// Try multiple external backends to avoid vendor lock-in.
async fn extract_pdf_text(path : String) -> Result[String, @cor.AppError] {
  let cands : Array[PdfExtractCandidate] = []

  // 1) pdftotext: default / layout / raw
  match run_and_capture("pdftotext", [path, "-"]) {
    Ok(out) =>
      if out.trim() != "" {
        cands.push({ label: "pdftotext-default", text: out })
      }
    Err(_) => ()
  }

  match run_and_capture("pdftotext", ["-layout", path, "-"]) {
    Ok(out) =>
      if out.trim() != "" {
        cands.push({ label: "pdftotext-layout", text: out })
      }
    Err(_) => ()
  }

  match run_and_capture("pdftotext", ["-raw", path, "-"]) {
    Ok(out) =>
      if out.trim() != "" {
        cands.push({ label: "pdftotext-raw", text: out })
      }
    Err(_) => ()
  }

  // 2) fallback: mutool
  match run_and_capture("mutool", ["draw", "-F", "txt", path]) {
    Ok(out) =>
      if out.trim() != "" {
        cands.push({ label: "mutool-draw-txt", text: out })
      }
    Err(_) => ()
  }

  if cands.length() == 0 {
    return Err(
      @cor.AppError(
        "No PDF text extractor available. Please install `pdftotext` (poppler) or `mutool` (mupdf).",
      ),
    )
  }

  if PDF_EXTRACT_DEBUG {
    for cand in cands {
      debug_print_candidate(cand.label, cand.text)
    }
  }

  let (best_label, best_text, best_score) = pick_best_extracted_text(cands)
  debug_print_selected(best_label, best_score)

  Ok(best_text)
}

///|
fn missing_tools_hint(cmd : String) -> String {
  if cmd == "ocrmypdf" {
    return
      "未找到 ocrmypdf，请安装后重试。\n" +
      "macOS: brew install ocrmypdf tesseract\n" +
      "Ubuntu/Debian: sudo apt-get install ocrmypdf tesseract-ocr\n"
  }

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
        return Err(@cor.AppError(missing_tools_hint(cmd)))
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
      return Err(@cor.AppError(missing_tools_hint(cmd)))
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
fn pick_best_extracted_text(
  cands : Array[PdfExtractCandidate],
) -> (String, String, Int) {
  let first = cands[0]
  let mut best_label = first.label
  let mut best_text = first.text
  let mut best_score = score_extracted_text(first.text)

  for i in 1..<cands.length() {
    let cand = cands[i]
    let sc = score_extracted_text(cand.text)

    // prefer pdftotext-default unless another candidate is clearly better
    if cand.label == "pdftotext-default" {
      if sc >= best_score - 10 {
        best_label = cand.label
        best_text = cand.text
        best_score = sc
      }
      continue
    }

    // if current best is default, require a clearer margin to replace it
    if best_label == "pdftotext-default" {
      if sc >= best_score + 20 {
        best_label = cand.label
        best_text = cand.text
        best_score = sc
      }
    } else if sc > best_score {
      best_label = cand.label
      best_text = cand.text
      best_score = sc
    }
  }

  (best_label, best_text, best_score)
}

///|
fn score_extracted_text(text : String) -> Int {
  let s = text.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
  let mut total = 0
  let mut blank = 0
  let mut short = 0
  let mut sum_len = 0
  let mut suspicious_short_alpha = 0

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

    // suspicious: very short alphabetic fragment lines like "fi"
    if len >= 1 && len <= 3 && is_all_ascii_letters(line) {
      suspicious_short_alpha += 1
    }
  }

  let nonblank = total - blank
  let avg_len = if nonblank <= 0 { 0 } else { sum_len / nonblank }

  // reward average line length, but penalize fragmentation harder
  avg_len * 10 - blank * 3 - short * 5 - suspicious_short_alpha * 25
}

///|
fn is_all_ascii_letters(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  for c in t.to_array() {
    if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) {
      return false
    }
  }

  true
}
