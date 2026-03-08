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
