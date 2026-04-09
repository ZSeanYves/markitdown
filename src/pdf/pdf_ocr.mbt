///|
/// OCR fallback should remain optional-first:
/// - only used by experimental mode
/// - only used when extracted text is effectively empty
fn ocr_backend_available() -> Bool {
  match run_and_capture("ocrmypdf", ["--version"]) {
    Ok(_) => true
    Err(_) => false
  }
}

///|
fn is_effectively_empty_pdf_text(text : String) -> Bool {
  let trimmed = text.trim().to_string()
  if trimmed == "" {
    return true
  }

  let mut signal_chars = 0
  for c in trimmed.to_array() {
    if c != ' ' && c != '\t' && c != '\n' && c != '\r' {
      signal_chars += 1
      if signal_chars >= 20 {
        return false
      }
    }
  }

  true
}

///|
async fn try_ocr_pdf_to_text(path : String) -> String? {
  if !ocr_backend_available() {
    return None
  }

  let sidecar = make_ocr_sidecar_path(path)

  // best-effort cleanup before run
  let _ = run_and_capture("rm", ["-f", sidecar])

  // Primary command form recommended by OCRmyPDF docs for sidecar capture.
  let primary = run_and_capture("ocrmypdf", [
    "--skip-text",
    "--sidecar",
    sidecar,
    "--output-type",
    "none",
    path,
    "-",
  ])

  // Some environments still prefer a file path output even with output-type none.
  match primary {
    Ok(_) => ()
    Err(_) => {
      let _ = run_and_capture("ocrmypdf", [
        "--skip-text",
        "--sidecar",
        sidecar,
        "--output-type",
        "none",
        path,
        "/dev/null",
      ])
      ()
    }
  }

  if !@fs.path_exists(sidecar) {
    return None
  }

  let text = @fs.read_file_to_bytes(sidecar) |> fn(bs) {
    bs.text() catch { _ => "" }
  } catch {
    _ => ""
  }

  let _ = run_and_capture("rm", ["-f", sidecar])

  let normalized = text.trim().to_string()
  if normalized == "" {
    None
  } else {
    Some(text)
  }
}

///|
fn make_ocr_sidecar_path(path : String) -> String {
  let name = @cor.basename(path)
  "/tmp/markitdown_ocr_sidecar_" + name + "_" + path.length().to_string() + ".txt"
}
