///|
pub struct TesseractSignalOptions {
  executable : String
  lang : String
  psm : String
  oem : String
}

///|
pub struct TesseractTsvCommandPlan {
  executable : String
  argv : Array[String]
  output_base : String
}

///|
pub enum TesseractSignalErrorKind {
  InvalidOutputBase
  CommandFailed
  MissingTsvOutput
  TsvParseFailed
} derive(Eq)

///|
pub struct TesseractSignalError {
  kind : TesseractSignalErrorKind
  message : String
  exit_code : Int?
  output_path : String?
}

///|
pub fn make_tesseract_signal_options(
  executable? : String = "tesseract",
  lang? : String = "",
  psm? : String = "",
  oem? : String = "",
) -> TesseractSignalOptions {
  {
    executable: normalize_tesseract_signal_executable(executable),
    lang: normalize_tesseract_signal_value(lang),
    psm: normalize_tesseract_signal_value(psm),
    oem: normalize_tesseract_signal_value(oem),
  }
}

///|
pub fn build_tesseract_tsv_command(
  input_path : String,
  output_base : String,
  options : TesseractSignalOptions,
) -> TesseractTsvCommandPlan {
  let executable = normalize_tesseract_signal_executable(options.executable)
  let lang = normalize_tesseract_signal_value(options.lang)
  let psm = normalize_tesseract_signal_value(options.psm)
  let oem = normalize_tesseract_signal_value(options.oem)
  let argv : Array[String] = [input_path, output_base]
  if lang != "" {
    argv.push("-l")
    argv.push(lang)
  }
  if psm != "" {
    argv.push("--psm")
    argv.push(psm)
  }
  if oem != "" {
    argv.push("--oem")
    argv.push(oem)
  }
  argv.push("tsv")
  { executable, argv, output_base }
}

///|
pub fn parse_tesseract_tsv_signal(
  tsv : String,
  provider_name : String,
) -> Result[OcrPageModel, TesseractTsvParseError] {
  parse_tesseract_tsv_page_with_provider(tsv, provider_name)
}

///|
pub async fn run_tesseract_tsv_signal(
  input_path : String,
  output_base : String,
  options : TesseractSignalOptions,
) -> Result[OcrPageModel, TesseractSignalError] {
  let tsv_output_path = match resolve_tesseract_tsv_output_path(output_base) {
    Ok(path) => path
    Err(err) => return Err(err)
  }
  let plan = build_tesseract_tsv_command(input_path, output_base, options)
  let delegated = @process.collect_output(plan.executable, plan.argv) catch {
    e =>
      return Err(
        make_tesseract_signal_error(
          TesseractSignalErrorKind::CommandFailed,
          "launch tesseract TSV signal command failed: " + e.to_string(),
          output_path=Some(tsv_output_path),
        ),
      )
  }
  match delegated {
    (0, _stdout, _stderr) => ()
    (code, stdout, stderr) => {
      let stderr_text = stderr.text().trim().to_owned()
      let stdout_text = stdout.text().trim().to_owned()
      let message = if stderr_text != "" {
        stderr_text
      } else if stdout_text != "" {
        stdout_text
      } else {
        "tesseract TSV signal command exited with code " + code.to_string()
      }
      return Err(
        make_tesseract_signal_error(
          TesseractSignalErrorKind::CommandFailed,
          message,
          exit_code=Some(code),
          output_path=Some(tsv_output_path),
        ),
      )
    }
  }

  let tsv_text = match read_tesseract_tsv_output(tsv_output_path) {
    Ok(text) => text
    Err(err) => return Err(err)
  }
  match parse_tesseract_tsv_signal(tsv_text, "tesseract-tsv") {
    Ok(page) => Ok(page)
    Err(err) =>
      Err(
        make_tesseract_signal_error(
          TesseractSignalErrorKind::TsvParseFailed,
          err.to_string(),
          output_path=Some(tsv_output_path),
        ),
      )
  }
}

///|
pub impl Show for TesseractSignalError with to_string(
  self : TesseractSignalError,
) -> String {
  self.message
}

///|
pub impl Show for TesseractSignalError with output(
  self : TesseractSignalError,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
fn normalize_tesseract_signal_executable(executable : String) -> String {
  let normalized = executable.trim().to_owned()
  if normalized == "" {
    "tesseract"
  } else {
    normalized
  }
}

///|
fn normalize_tesseract_signal_value(value : String) -> String {
  value.trim().to_owned()
}

///|
fn resolve_tesseract_tsv_output_path(
  output_base : String,
) -> Result[String, TesseractSignalError] {
  if output_base.trim() == "" {
    Err(
      make_tesseract_signal_error(
        TesseractSignalErrorKind::InvalidOutputBase,
        "tesseract TSV output base must not be blank",
      ),
    )
  } else {
    Ok(output_base + ".tsv")
  }
}

///|
fn read_tesseract_tsv_output(
  tsv_output_path : String,
) -> Result[String, TesseractSignalError] {
  if !@fs.path_exists(tsv_output_path) {
    return Err(
      make_tesseract_signal_error(
        TesseractSignalErrorKind::MissingTsvOutput,
        "expected tesseract TSV output at " + tsv_output_path,
        output_path=Some(tsv_output_path),
      ),
    )
  }
  let text = @fs.read_file_to_string(tsv_output_path, encoding="utf8") catch {
    e =>
      return Err(
        make_tesseract_signal_error(
          TesseractSignalErrorKind::MissingTsvOutput,
          "read tesseract TSV output failed: " + e.to_string(),
          output_path=Some(tsv_output_path),
        ),
      )
  }
  Ok(text)
}

///|
fn make_tesseract_signal_error(
  kind : TesseractSignalErrorKind,
  message : String,
  exit_code? : Int? = None,
  output_path? : String? = None,
) -> TesseractSignalError {
  { kind, message, exit_code, output_path }
}
