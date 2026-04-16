///|
async fn collect_process_output(
  cmd : String,
  args : Array[String],
) -> Result[(Int, String, String), String] {
  let res = @proc.collect_output(cmd, args[:]) catch {
    e => return Err(e.to_string())
  }

  let (status, out_data, err_data) = res
  let stdout : String = out_data.text() catch { _e => "" }
  let stderr : String = err_data.text() catch { _e => "" }

  Ok((status, stdout, stderr))
}

///|
async fn ocrmypdf_available() -> Bool {
  match collect_process_output("ocrmypdf", ["--version"]) {
    Ok((status, _, _)) => status == 0
    Err(_) => false
  }
}

///|
fn make_ocr_sidecar_path(path : String) -> String {
  let name = @cor.basename(path)
  "/tmp/markitdown_ocr_sidecar_" +
  name +
  "_" +
  path.length().to_string() +
  ".txt"
}

///|
fn remove_file_if_exists(path : String) -> Unit {
  if !@fs.path_exists(path) {
    return
  }

  ignore(@fs.remove_file(path) catch { _ => () })
}

///|
fn cleanup_ocr_sidecar_text(text : String) -> String {
  let mut out = ""
  let mut blank_run = 0

  for line_sv in text.split("\n") {
    let line = line_sv.to_string().trim().to_string()

    if line == "" {
      blank_run = blank_run + 1
      if blank_run <= 1 {
        out = out + "\n\n"
      }
    } else {
      blank_run = 0
      if out != "" && !out.has_suffix("\n") {
        out = out + "\n"
      }
      out = out + line
    }
  }

  out.trim().to_string()
}

///|
fn is_effectively_empty_ocr_text(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return true
  }

  let mut signal = 0
  for ch in t.to_array() {
    if ch != ' ' && ch != '\t' && ch != '\n' && ch != '\r' {
      signal = signal + 1
      if signal >= 24 {
        return false
      }
    }
  }

  true
}

///|
async fn try_ocr_pdf_to_text(path : String, pipeline_debug : Bool) -> String? {
  let available = ocrmypdf_available()
  if !available {
    return None
  }

  let sidecar = make_ocr_sidecar_path(path)
  remove_file_if_exists(sidecar)

  let primary = collect_process_output("ocrmypdf", [
    "--skip-text", "--sidecar", sidecar, "--output-type", "none", path, "-",
  ])

  match primary {
    Ok((status, _, stderr)) => {
      if pipeline_debug {
        println("[pdf-ocr] primary status=" + status.to_string())
        if stderr.trim() != "" {
          println("[pdf-ocr] primary stderr=" + stderr)
        }
      }

      if status != 0 {
        let fallback = collect_process_output("ocrmypdf", [
          "--skip-text", "--sidecar", sidecar, "--output-type", "none", path, "/dev/null",
        ])

        match fallback {
          Ok((status2, _, stderr2)) =>
            if pipeline_debug {
              println("[pdf-ocr] fallback status=" + status2.to_string())
              if stderr2.trim() != "" {
                println("[pdf-ocr] fallback stderr=" + stderr2)
              }
            }
          Err(err2) =>
            if pipeline_debug {
              println("[pdf-ocr] fallback spawn failed: " + err2)
            }
        }
      }
    }
    Err(err) => {
      if pipeline_debug {
        println("[pdf-ocr] primary spawn failed: " + err)
      }

      let fallback = collect_process_output("ocrmypdf", [
        "--skip-text", "--sidecar", sidecar, "--output-type", "none", path, "/dev/null",
      ])

      match fallback {
        Ok((status2, _, stderr2)) =>
          if pipeline_debug {
            println("[pdf-ocr] fallback status=" + status2.to_string())
            if stderr2.trim() != "" {
              println("[pdf-ocr] fallback stderr=" + stderr2)
            }
          }
        Err(err2) =>
          if pipeline_debug {
            println("[pdf-ocr] fallback spawn failed: " + err2)
          }
      }
    }
  }

  if !@fs.path_exists(sidecar) {
    return None
  }

  let text = (@fs.read_file_to_bytes(sidecar)
  |> fn(bs) { @cor.utf8_bytes_to_string(bs) catch { _ => "" } }) catch {
    _ => ""
  }

  remove_file_if_exists(sidecar)

  let cleaned = cleanup_ocr_sidecar_text(text)
  if is_effectively_empty_ocr_text(cleaned) {
    None
  } else {
    Some(cleaned)
  }
}

///|
/// OCR 子包总入口：
/// - 调 ocrmypdf 产出 sidecar 文本
/// - 再走旧的纯文本规则恢复链
pub async fn parse_pdf_via_ocr(
  input_path : String,
  out_dir : String,
  max_heading : Int,
  pipeline_debug : Bool,
) -> @cor.Document {
  ignore(max_heading)

  let text = match try_ocr_pdf_to_text(input_path, pipeline_debug) {
    Some(t) => t
    None => return @cor.new_document()
  }

  ocr_text_to_ir_document_with_debug(input_path, out_dir, text, pipeline_debug)
}
