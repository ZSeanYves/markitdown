///|
async fn ocr_backend_available() -> Bool raise Error {
  match run_command_capture("ocrmypdf", ["--version"]) {
    Ok((status, _, _)) => status == 0
    Err(_) => false
  }
}

///|
async fn try_ocr_pdf_to_text(path : String) -> String? {
  if !ocr_backend_available() {
    return None
  }

  let sidecar = make_ocr_sidecar_path(path)

  let _ = run_command_capture("rm", ["-f", sidecar])

  let primary = run_command_capture("ocrmypdf", [
    "--skip-text", "--sidecar", sidecar, "--output-type", "none", path, "-",
  ])

  match primary {
    Ok((status, _, _)) =>
      if status != 0 {
        let _ = run_command_capture("ocrmypdf", [
          "--skip-text", "--sidecar", sidecar, "--output-type", "none", path, "/dev/null",
        ])
      }
    Err(_) => {
      let _ = run_command_capture("ocrmypdf", [
        "--skip-text", "--sidecar", sidecar, "--output-type", "none", path, "/dev/null",
      ])
    }
  }

  if !@fs.path_exists(sidecar) {
    return None
  }

  let text = (@fs.read_file_to_bytes(sidecar)
  |> fn(bs) { @cor.utf8_bytes_to_string(bs) catch { _ => "" } }) catch {
    _ => ""
  }

  let _ = run_command_capture("rm", ["-f", sidecar])

  let cleaned = cleanup_pdf_text(text)
  let quality = analyze_pdf_text_quality(cleaned)

  if is_quality_failure_for_normal_text(quality) {
    None
  } else {
    Some(cleaned)
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
