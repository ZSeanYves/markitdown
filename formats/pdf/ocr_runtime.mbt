///|
pub(all) enum PdfRasterizerKind {
  PdfToPpm
} derive(Eq)

///|
pub(all) enum PdfRasterizerStatus {
  CommandUnavailable
  ExecutionFailed
  OutputParseFailed
  EmptyResult
} derive(Eq)

///|
pub(all) enum PdfRasterizerError {
  CommandUnavailable(String)
  ExecutionFailed(String)
  OutputParseFailed(String)
  EmptyResult(String)
} derive(Eq)

///|
pub impl Show for PdfRasterizerError with fn to_string(
  self : PdfRasterizerError,
) -> String {
  match self {
    CommandUnavailable(msg) => msg
    ExecutionFailed(msg) => msg
    OutputParseFailed(msg) => msg
    EmptyResult(msg) => msg
  }
}

///|
pub struct PdfRasterPageArtifact {
  page_index : Int
  image_path : String?
  success : Bool
  diagnostics : Array[String]
}

///|
pub struct PdfRasterResult {
  backend_name : String
  page_count : Int
  pages : Array[PdfRasterPageArtifact]
  diagnostics : Array[String]
}

///|
pub fn pdf_rasterizer_kind_name(kind : PdfRasterizerKind) -> String {
  match kind {
    PdfRasterizerKind::PdfToPpm => "pdftoppm"
  }
}

///|
pub fn pdf_rasterizer_status_name(status : PdfRasterizerStatus) -> String {
  match status {
    PdfRasterizerStatus::CommandUnavailable => "command_unavailable"
    PdfRasterizerStatus::ExecutionFailed => "execution_failed"
    PdfRasterizerStatus::OutputParseFailed => "output_parse_failed"
    PdfRasterizerStatus::EmptyResult => "empty_result"
  }
}

///|
pub fn pdf_rasterizer_error_status(
  error : PdfRasterizerError,
) -> PdfRasterizerStatus {
  match error {
    PdfRasterizerError::CommandUnavailable(_) =>
      PdfRasterizerStatus::CommandUnavailable
    PdfRasterizerError::ExecutionFailed(_) =>
      PdfRasterizerStatus::ExecutionFailed
    PdfRasterizerError::OutputParseFailed(_) =>
      PdfRasterizerStatus::OutputParseFailed
    PdfRasterizerError::EmptyResult(_) => PdfRasterizerStatus::EmptyResult
  }
}

///|
pub fn pdf_raster_backend_install_hint() -> String {
  @focr.dependency_diagnostic_card(
    "Missing dependency: pdftoppm / Poppler",
    "PDF OCR requires the local `pdftoppm` raster backend before any OCR provider can run.",
    ["brew install poppler"],
    ["sudo apt install poppler-utils"],
    footer=Some(
      "This dependency is required for both Balanced PDF OCR and Accurate PDF OCR.",
    ),
  )
}

///|
pub fn pdf_raster_backend_dependency_diagnostic() -> @core.DependencyDiagnostic {
  @focr.dependency_diagnostic_entry(
    "Missing dependency: pdftoppm / Poppler",
    "PDF OCR requires the local `pdftoppm` raster backend before any OCR provider can run.",
    ["brew install poppler"],
    ["sudo apt install poppler-utils"],
    footer=Some(
      "This dependency is required for both Balanced PDF OCR and Accurate PDF OCR.",
    ),
  )
}

///|
pub fn pdf_raster_provider_error_message(error : PdfRasterizerError) -> String {
  error.to_string() + " " + pdf_raster_backend_install_hint()
}

///|
pub fn pdf_ocr_layout_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::LayoutTwoStage,
    false,
    @parser.StreamingGranularity::Page,
    true,
    false,
    false,
    false,
    false,
    true,
    false,
    true,
    true,
    false,
    true,
    true,
    true,
    false,
    true,
    false,
  )
}

///|
fn pdf_ocr_tmp_root() -> String {
  ".tmp/pdf_ocr"
}

///|
fn pdf_ocr_ensure_dir_tree(path : String) -> Unit raise @fs.IOError {
  let normalized = path.trim().to_owned()
  if normalized == "" || normalized == "." {
    return
  }
  if @fs.path_exists(normalized) {
    return
  }
  let parts = normalized.split("/")
  let mut current = if normalized.has_prefix("/") { "/" } else { "" }
  for raw in parts {
    let part = raw.trim().to_owned()
    if part == "" || part == "." {
      continue
    }
    if current == "" || current == "/" {
      current = if current == "/" { "/" + part } else { part }
    } else {
      current = current + "/" + part
    }
    if !@fs.path_exists(current) {
      @fs.create_dir(current)
    }
  }
}

///|
fn pdf_ocr_remove_dir_recursive(path : String) -> Unit raise @fs.IOError {
  if !@fs.path_exists(path) {
    return
  }
  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      pdf_ocr_remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }
  @fs.remove_dir(path)
}

///|
fn pdf_ocr_cleanup_temp_dir(path : String) -> Unit {
  ignore(
    try pdf_ocr_remove_dir_recursive(path) |> Ok catch {
      _ => Err(())
    },
  )
}

///|
fn pdf_ocr_temp_dir_name(source : @input.InputSource) -> String {
  let raw = match source.path {
    Some(path) => path
    None => source.source_name
  }
  let chars = raw.to_array()
  let safe : Array[Char] = []
  for ch in chars {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') {
      safe.push(ch)
    } else {
      safe.push('_')
    }
  }
  let normalized = String::from_array(safe)
  let base = if normalized.trim() == "" { "input" } else { normalized }
  let now = @env.now()
  pdf_ocr_tmp_root() + "/" + base + "_" + now.to_string()
}

///|
fn pdf_ocr_materialize_source_path(
  source : @input.InputSource,
  temp_dir : String,
) -> Result[String, PdfRasterizerError] {
  match source.path {
    Some(path) => Ok(path)
    None => {
      let bytes = match @input.read_input_bytes(source) {
        Ok(payload) => payload
        Err(err) =>
          return Err(
            PdfRasterizerError::ExecutionFailed(
              "failed to read PDF bytes for OCR rasterization: " + err,
            ),
          )
      }
      let pdf_path = temp_dir + "/source.pdf"
      @fs.write_bytes_to_file(pdf_path, bytes) catch {
        e =>
          return Err(
            PdfRasterizerError::ExecutionFailed(
              "failed to materialize PDF bytes for OCR rasterization: " +
              e.to_string(),
            ),
          )
      }
      Ok(pdf_path)
    }
  }
}

///|
pub fn build_pdftoppm_png_command(
  pdf_path : String,
  output_dir : String,
) -> (String, Array[String]) {
  ("pdftoppm", ["-png", pdf_path, output_dir + "/page"])
}

///|
#warnings("-deprecated")
fn collect_pdftoppm_output(
  cmd : String,
  args : Array[String],
) -> Result[(Int, String, String), PdfRasterizerError] {
  let collected : Ref[Result[(Int, String, String), PdfRasterizerError]?] = {
    val: None,
  }
  @async.with_event_loop(_group => {
    let delegated = @process.collect_output(cmd, args) catch {
      e => {
        collected.val = Some(
          Err(
            PdfRasterizerError::ExecutionFailed(
              "launch pdftoppm failed on this runtime: " + e.to_string(),
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
                PdfRasterizerError::OutputParseFailed(
                  "failed to decode pdftoppm stdout as UTF-8 on this runtime: " +
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
                PdfRasterizerError::OutputParseFailed(
                  "failed to decode pdftoppm stderr as UTF-8 on this runtime: " +
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
        PdfRasterizerError::ExecutionFailed(
          "launch pdftoppm failed on this runtime: " + e.to_string(),
        ),
      )
  }
  match collected.val {
    Some(result) => result
    None =>
      Err(
        PdfRasterizerError::ExecutionFailed(
          "launch pdftoppm failed on this runtime: event loop returned no result",
        ),
      )
  }
}

///|
fn finalize_pdftoppm_result(
  paths : Array[String],
  delegated : (Int, String, String),
) -> Result[PdfRasterResult, PdfRasterizerError] {
  match delegated {
    (0, stdout, stderr) => {
      if paths.length() == 0 {
        return Err(
          PdfRasterizerError::EmptyResult(
            "pdftoppm produced no page images on this runtime.",
          ),
        )
      }
      let pages : Array[PdfRasterPageArtifact] = []
      for i in 0..<paths.length() {
        pages.push({
          page_index: i,
          image_path: Some(paths[i]),
          success: true,
          diagnostics: [],
        })
      }
      let diagnostics : Array[String] = []
      let stderr_text = stderr.trim().to_owned()
      let stdout_text = stdout.trim().to_owned()
      if stderr_text != "" {
        diagnostics.push("pdftoppm_stderr=" + stderr_text)
      }
      if stdout_text != "" {
        diagnostics.push("pdftoppm_stdout=" + stdout_text)
      }
      Ok({
        backend_name: "pdftoppm",
        page_count: pages.length(),
        pages,
        diagnostics,
      })
    }
    (code, stdout, stderr) => {
      let stderr_text = stderr.trim().to_owned()
      let stdout_text = stdout.trim().to_owned()
      let raw_message = if stderr_text != "" {
        stderr_text
      } else if stdout_text != "" {
        stdout_text
      } else {
        "pdftoppm exited with code " + code.to_string()
      }
      let lowered = raw_message.to_lower()
      if lowered.contains("command not found") ||
        lowered.contains("not found") ||
        lowered.contains("no such file") {
        Err(
          PdfRasterizerError::CommandUnavailable(
            "pdftoppm command is unavailable on this runtime: " + raw_message,
          ),
        )
      } else {
        Err(
          PdfRasterizerError::ExecutionFailed(
            "pdftoppm command failed on this runtime: " + raw_message,
          ),
        )
      }
    }
  }
}

///|
fn pdftoppm_png_paths(output_dir : String) -> Array[String] raise @fs.IOError {
  if !@fs.path_exists(output_dir) || !@fs.is_dir(output_dir) {
    return []
  }
  let paths : Array[String] = []
  for name in @fs.read_dir(output_dir) {
    let child = output_dir + "/" + name
    if @fs.is_file(child) && child.to_lower().has_suffix(".png") {
      paths.push(child)
    }
  }
  paths.sort()
  paths
}

///|
pub fn rasterize_pdf_with_pdftoppm(
  source : @input.InputSource,
  collect_output : (String, Array[String]) -> Result[
    (Int, String, String),
    PdfRasterizerError,
  ],
) -> Result[(PdfRasterResult, String), PdfRasterizerError] {
  let temp_dir = pdf_ocr_temp_dir_name(source)
  pdf_ocr_ensure_dir_tree(temp_dir) catch {
    e =>
      return Err(
        PdfRasterizerError::ExecutionFailed(
          "failed to create PDF OCR temp dir: " + e.to_string(),
        ),
      )
  }
  let pdf_path = match pdf_ocr_materialize_source_path(source, temp_dir) {
    Ok(path) => path
    Err(err) => {
      pdf_ocr_cleanup_temp_dir(temp_dir)
      return Err(err)
    }
  }
  let output_dir = temp_dir + "/pages"
  pdf_ocr_ensure_dir_tree(output_dir) catch {
    e => {
      pdf_ocr_cleanup_temp_dir(temp_dir)
      return Err(
        PdfRasterizerError::ExecutionFailed(
          "failed to create PDF OCR raster dir: " + e.to_string(),
        ),
      )
    }
  }
  let plan = build_pdftoppm_png_command(pdf_path, output_dir)
  let delegated = match collect_output(plan.0, plan.1) {
    Ok(value) => value
    Err(error) => {
      pdf_ocr_cleanup_temp_dir(temp_dir)
      return Err(error)
    }
  }
  let finalized = match delegated {
    (0, _, _) => {
      let paths = pdftoppm_png_paths(output_dir) catch {
        e => {
          pdf_ocr_cleanup_temp_dir(temp_dir)
          return Err(
            PdfRasterizerError::OutputParseFailed(
              "failed to enumerate pdftoppm output pages on this runtime: " +
              e.to_string(),
            ),
          )
        }
      }
      let pages : Array[PdfRasterPageArtifact] = []
      for i in 0..<paths.length() {
        pages.push({
          page_index: i,
          image_path: Some(paths[i]),
          success: true,
          diagnostics: [],
        })
      }
      if pages.length() == 0 {
        Err(
          PdfRasterizerError::EmptyResult(
            "pdftoppm produced no page images on this runtime.",
          ),
        )
      } else {
        finalize_pdftoppm_result(paths, delegated)
      }
    }
    _ => finalize_pdftoppm_result([], delegated)
  }
  match finalized {
    Ok(result) => Ok((result, temp_dir))
    Err(error) => {
      pdf_ocr_cleanup_temp_dir(temp_dir)
      Err(error)
    }
  }
}

///|
pub fn rasterize_pdf_with_pdftoppm_default(
  source : @input.InputSource,
) -> Result[(PdfRasterResult, String), PdfRasterizerError] {
  rasterize_pdf_with_pdftoppm(source, collect_pdftoppm_output)
}

///|
pub fn cleanup_pdf_ocr_temp_dir(path : String) -> Unit {
  pdf_ocr_cleanup_temp_dir(path)
}
