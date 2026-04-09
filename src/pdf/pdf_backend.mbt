///|
priv struct PdfBackendSpec {
  name : String
  cmd : String
  args : Array[String]
}

///|
priv struct PdfBackendResult {
  backend_name : String
  cmd : String
  args : Array[String]
  text : String
  exit_status : Int
  stderr : String
  quality : PdfTextQuality?
  spawn_error : String?
}

///|
fn default_pdf_backend_specs(path : String) -> Array[PdfBackendSpec] {
  [
    { name: "pdftotext-default", cmd: "pdftotext", args: [path, "-"] },
    { name: "pdftotext-layout", cmd: "pdftotext", args: ["-layout", path, "-"] },
    { name: "pdftotext-raw", cmd: "pdftotext", args: ["-raw", path, "-"] },
    { name: "mutool-draw-txt", cmd: "mutool", args: ["draw", "-F", "txt", path] },
  ]
}

///|
async fn run_pdf_backend(spec : PdfBackendSpec) -> PdfBackendResult {
  let res = @proc.collect_output(spec.cmd, spec.args[:]) catch {
    e => {
      let msg = e.to_string()
      return {
        backend_name: spec.name,
        cmd: spec.cmd,
        args: spec.args,
        text: "",
        exit_status: -1,
        stderr: "",
        quality: None,
        spawn_error: Some(normalize_spawn_error(spec.cmd, msg)),
      }
    }
  }

  let (status, out_data, err_data) = res

  let stdout : String = out_data.text() catch { _ => "" }
  let stderr : String = err_data.text() catch { _ => "" }
  let quality =
    if status == 0 {
      Some(analyze_pdf_text_quality(stdout))
    } else {
      None
    }

  {
    backend_name: spec.name,
    cmd: spec.cmd,
    args: spec.args,
    text: stdout,
    exit_status: status,
    stderr: stderr,
    quality: quality,
    spawn_error: None,
  }
}

///|
async fn collect_pdf_backend_results(path : String) -> Array[PdfBackendResult] {
  let all : Array[PdfBackendResult] = []
  for spec in default_pdf_backend_specs(path) {
    all.push(run_pdf_backend(spec))
  }
  all
}

///|
fn normalize_spawn_error(cmd : String, msg : String) -> String {
  if msg.contains("No such file or directory") || msg.contains("not found") {
    missing_tools_hint(cmd)
  } else {
    "spawn failed: " + msg
  }
}

///|
fn missing_tools_hint(cmd : String) -> String {
  if cmd == "ocrmypdf" {
    let a = "未找到 ocrmypdf，请安装后重试。\n" +
      "macOS: brew install ocrmypdf tesseract\n" +
      "Ubuntu/Debian: sudo apt-get install ocrmypdf tesseract-ocr\n"
    return a
  }

  "未找到 pdftotext（Poppler）或 mutool（MuPDF），请安装后重试。\n" +
  "macOS: brew install poppler mupdf-tools\n" +
  "Ubuntu/Debian: sudo apt-get install poppler-utils mupdf-tools\n" +
  "Arch: sudo pacman -S poppler mupdf-tools\n"
}

///|
async fn run_command_capture(
  cmd : String,
  args : Array[String],
) -> Result[(Int, String, String), @cor.AppError] {
  let res = @proc.collect_output(cmd, args[:]) catch {
    e => {
      let msg = e.to_string()
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

  Ok((status, stdout, stderr))
}
