///|
pub fn run_tesseract_provider(
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  let language_note = match request.language {
    Some(language) => {
      let trimmed = language.trim().to_owned()
      if trimmed == "" {
        ""
      } else {
        " language=" + trimmed
      }
    }
    None => ""
  }
  Err(
    OcrProviderError::NotConfigured(
      "Tesseract OCR provider is not configured on the current root runtime." +
      language_note,
    ),
  )
}

///|
pub async fn run_tesseract_provider_async(
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  run_tesseract_provider_with_async_command(request, (cmd, args) => {
    let delegated = @process.collect_output(cmd, args) catch {
      e =>
        return Err(
          OcrProviderError::ExecutionFailed(
            "launch tesseract failed on the current root runtime: " +
            e.to_string(),
          ),
        )
    }
    match delegated {
      (code, stdout, stderr) => {
        let stdout_text = stdout.text() catch {
          e =>
            return Err(
              OcrProviderError::OutputParseFailed(
                "failed to decode Tesseract stdout as UTF-8 on the current root runtime: " +
                e.to_string(),
              ),
            )
        }
        let stderr_text = stderr.text() catch {
          e =>
            return Err(
              OcrProviderError::OutputParseFailed(
                "failed to decode Tesseract stderr as UTF-8 on the current root runtime: " +
                e.to_string(),
              ),
            )
        }
        Ok((code, stdout_text, stderr_text))
      }
    }
  })
}

///|
pub fn run_tesseract_provider_with_command(
  request : OcrProviderRequest,
  collect_output : (String, Array[String]) -> Result[
    (Int, String, String),
    OcrProviderError,
  ],
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = build_tesseract_tsv_command(request)
  let delegated = match collect_output(plan.0, plan.1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_tesseract_command_result(request, delegated)
}

///|
pub async fn run_tesseract_provider_with_async_command(
  request : OcrProviderRequest,
  collect_output : async (String, Array[String]) -> Result[
    (Int, String, String),
    OcrProviderError,
  ],
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = build_tesseract_tsv_command(request)
  let delegated = match collect_output(plan.0, plan.1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_tesseract_command_result(request, delegated)
}

///|
pub fn build_tesseract_tsv_command(
  request : OcrProviderRequest,
) -> (String, Array[String]) {
  let argv = [request.image_path, "stdout", "--oem", "1", "--psm", "6"]
  match request.language {
    Some(language) => {
      let trimmed = language.trim().to_owned()
      if trimmed != "" {
        argv.push("-l")
        argv.push(trimmed)
      }
    }
    None => ()
  }
  argv.push("tsv")
  ("tesseract", argv)
}

///|
fn finalize_tesseract_command_result(
  request : OcrProviderRequest,
  delegated : (Int, String, String),
) -> Result[OcrProviderResult, OcrProviderError] {
  match delegated {
    (0, stdout, _) =>
      match parse_tesseract_tsv(stdout, language=request.language) {
        Ok(result) => Ok(result)
        Err(OcrProviderError::OutputParseFailed(msg)) =>
          Err(OcrProviderError::OutputParseFailed(msg))
        Err(OcrProviderError::EmptyResult(msg)) =>
          Err(OcrProviderError::EmptyResult(msg))
        Err(other) =>
          Err(
            OcrProviderError::OutputParseFailed(
              "Tesseract TSV parsing failed on the current root runtime: " +
              other.to_string(),
            ),
          )
      }
    (code, stdout, stderr) => {
      let stderr_text = stderr.trim().to_owned()
      let stdout_text = stdout.trim().to_owned()
      let raw_message = if stderr_text != "" {
        stderr_text
      } else if stdout_text != "" {
        stdout_text
      } else {
        "tesseract exited with code " + code.to_string()
      }
      let lowered = raw_message.to_lower()
      if lowered.contains("command not found") ||
        lowered.contains("not found") ||
        lowered.contains("no such file") {
        Err(
          OcrProviderError::CommandUnavailable(
            "Tesseract OCR command is unavailable on the current root runtime: " +
            raw_message,
          ),
        )
      } else {
        Err(
          OcrProviderError::ExecutionFailed(
            "Tesseract OCR command failed on the current root runtime: " +
            raw_message,
          ),
        )
      }
    }
  }
}
