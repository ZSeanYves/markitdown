///|
pub fn tesseract_command_env_var() -> String {
  "MARKITDOWN_TESSERACT_BIN"
}

///|
priv struct TesseractCommandPlan {
  command : @rtcmd.ResolvedCommand
  argv : Array[String]
}

///|
fn resolve_tesseract_command() -> Result[
  @rtcmd.ResolvedCommand,
  OcrProviderError,
] {
  match @rtcmd.resolve_repo_managed_command("tesseract") {
    Some(command) => return Ok(command)
    None => ()
  }
  match @rtcmd.normalized_env_var(tesseract_command_env_var()) {
    Some(path) =>
      match
        @rtcmd.resolve_executable_path(
          path,
          tesseract_command_env_var(),
          @rtcmd.ResolvedCommandSource::EnvVar,
        ) {
        Ok(command) => return Ok(command)
        Err(msg) =>
          return Err(
            OcrProviderError::CommandUnavailable(
              msg + "\n\n" + tesseract_ocr_install_hint(),
            ),
          )
      }
    None => ()
  }
  match @rtcmd.resolve_path_command("tesseract") {
    Some(command) => Ok(command)
    None => Ok(@rtcmd.fallback_command("tesseract"))
  }
}

///|
fn build_tesseract_argv(request : OcrProviderRequest) -> Array[String] {
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
  argv
}

///|
fn build_tesseract_command_plan(
  request : OcrProviderRequest,
) -> Result[TesseractCommandPlan, OcrProviderError] {
  let command = match resolve_tesseract_command() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({ command, argv: build_tesseract_argv(request) })
}

///|
pub fn run_tesseract_provider(
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = match build_tesseract_command_plan(request) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let delegated = match collect_tesseract_output(plan.command, plan.argv) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_tesseract_command_result(request, plan.command, delegated)
}

///|
pub async fn run_tesseract_provider_async(
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = match build_tesseract_command_plan(request) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let delegated = match
    collect_tesseract_output_async(plan.command, plan.argv) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_tesseract_command_result(request, plan.command, delegated)
}

///|
pub fn run_tesseract_provider_with_command(
  request : OcrProviderRequest,
  collect_output : (String, Array[String]) -> Result[
    (Int, String, String),
    OcrProviderError,
  ],
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = match build_tesseract_command_plan(request) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let delegated = match collect_output(plan.command.program, plan.argv) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_tesseract_command_result(request, plan.command, delegated)
}

///|
pub async fn run_tesseract_provider_with_async_command(
  request : OcrProviderRequest,
  collect_output : async (String, Array[String]) -> Result[
    (Int, String, String),
    OcrProviderError,
  ],
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = match build_tesseract_command_plan(request) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let delegated = match collect_output(plan.command.program, plan.argv) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_tesseract_command_result(request, plan.command, delegated)
}

///|
pub fn build_tesseract_tsv_command(
  request : OcrProviderRequest,
) -> (String, Array[String]) {
  let command = match resolve_tesseract_command() {
    Ok(value) => value
    Err(_) => @rtcmd.fallback_command("tesseract")
  }
  (command.program, build_tesseract_argv(request))
}

///|
fn finalize_tesseract_command_result(
  request : OcrProviderRequest,
  command : @rtcmd.ResolvedCommand,
  delegated : (Int, String, String),
) -> Result[OcrProviderResult, OcrProviderError] {
  match delegated {
    (0, stdout, _) =>
      match parse_tesseract_tsv(stdout, language=request.language) {
        Ok(result) => {
          let diagnostics = result.diagnostics.copy()
          diagnostics.push(
            "tesseract_command_source=" +
            @rtcmd.resolved_command_source_label(command.source),
          )
          diagnostics.push("tesseract_command=" + command.display_command)
          Ok({ ..result, diagnostics, })
        }
        Err(OcrProviderError::OutputParseFailed(msg)) =>
          Err(OcrProviderError::OutputParseFailed(msg))
        Err(OcrProviderError::EmptyResult(msg)) =>
          Err(OcrProviderError::EmptyResult(msg))
        Err(other) =>
          Err(
            OcrProviderError::OutputParseFailed(
              "Tesseract TSV parsing failed on this runtime: " +
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
            "Tesseract OCR command is unavailable on this runtime: " +
            raw_message +
            "\nResolved command: " +
            @rtcmd.resolved_command_context(command) +
            "\n\n" +
            tesseract_ocr_install_hint(),
          ),
        )
      } else {
        Err(
          OcrProviderError::ExecutionFailed(
            "Tesseract OCR command failed on this runtime: " +
            raw_message +
            "\nResolved command: " +
            @rtcmd.resolved_command_context(command) +
            "\n\n" +
            tesseract_ocr_install_hint(),
          ),
        )
      }
    }
  }
}

///|
async fn collect_tesseract_output_async(
  command : @rtcmd.ResolvedCommand,
  args : Array[String],
) -> Result[(Int, String, String), OcrProviderError] {
  let delegated = @process.collect_output(command.program, args) catch {
    e =>
      return Err(
        OcrProviderError::ExecutionFailed(
          "launch tesseract failed on this runtime: " +
          e.to_string() +
          "\nResolved command: " +
          @rtcmd.resolved_command_context(command) +
          "\n\n" +
          tesseract_ocr_install_hint(),
        ),
      )
  }
  match delegated {
    (code, stdout, stderr) => {
      let stdout_text = stdout.text() catch {
        e =>
          return Err(
            OcrProviderError::OutputParseFailed(
              "failed to decode Tesseract stdout as UTF-8 on this runtime: " +
              e.to_string(),
            ),
          )
      }
      let stderr_text = stderr.text() catch {
        e =>
          return Err(
            OcrProviderError::OutputParseFailed(
              "failed to decode Tesseract stderr as UTF-8 on this runtime: " +
              e.to_string(),
            ),
          )
      }
      Ok((code, stdout_text, stderr_text))
    }
  }
}

///|
#warnings("-deprecated")
fn collect_tesseract_output(
  command : @rtcmd.ResolvedCommand,
  args : Array[String],
) -> Result[(Int, String, String), OcrProviderError] {
  let collected : Ref[Result[(Int, String, String), OcrProviderError]?] = {
    val: None,
  }
  @async.with_event_loop(_group => {
    let delegated = @process.collect_output(command.program, args) catch {
      e => {
        collected.val = Some(
          Err(
            OcrProviderError::ExecutionFailed(
              "launch tesseract failed on this runtime: " +
              e.to_string() +
              "\nResolved command: " +
              @rtcmd.resolved_command_context(command) +
              "\n\n" +
              tesseract_ocr_install_hint(),
            ),
          ),
        )
        return
      }
    }
    match delegated {
      (code, stdout, stderr) => {
        let stdout_text = stdout.text() catch {
          e => {
            collected.val = Some(
              Err(
                OcrProviderError::OutputParseFailed(
                  "failed to decode Tesseract stdout as UTF-8 on this runtime: " +
                  e.to_string(),
                ),
              ),
            )
            return
          }
        }
        let stderr_text = stderr.text() catch {
          e => {
            collected.val = Some(
              Err(
                OcrProviderError::OutputParseFailed(
                  "failed to decode Tesseract stderr as UTF-8 on this runtime: " +
                  e.to_string(),
                ),
              ),
            )
            return
          }
        }
        collected.val = Some(Ok((code, stdout_text, stderr_text)))
      }
    }
  }) catch {
    e =>
      return Err(
        OcrProviderError::ExecutionFailed(
          "launch tesseract failed on this runtime: " +
          e.to_string() +
          "\nResolved command: " +
          @rtcmd.resolved_command_context(command) +
          "\n\n" +
          tesseract_ocr_install_hint(),
        ),
      )
  }
  match collected.val {
    Some(result) => result
    None =>
      Err(
        OcrProviderError::ExecutionFailed(
          "launch tesseract failed on this runtime: event loop returned no result\nResolved command: " +
          @rtcmd.resolved_command_context(command) +
          "\n\n" +
          tesseract_ocr_install_hint(),
        ),
      )
  }
}
