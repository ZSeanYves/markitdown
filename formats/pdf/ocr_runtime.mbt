///|
/// PDF raster backends currently supported by the OCR path.
pub(all) enum PdfRasterizerKind {
  PdfToPpm
} derive(Eq)

///|
/// Coarse PDF raster execution status categories.
pub(all) enum PdfRasterizerStatus {
  CommandUnavailable
  ExecutionFailed
  OutputParseFailed
  EmptyResult
} derive(Eq)

///|
/// Error categories returned by the PDF raster runtime boundary.
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
/// One rasterized page artifact produced during PDF OCR setup.
///
/// `image_path` is the temporary file handed to the OCR provider when
/// rasterization succeeds.
pub struct PdfRasterPageArtifact {
  page_index : Int
  image_path : String?
  success : Bool
  diagnostics : Array[String]
}

///|
/// Aggregated rasterization result for a PDF document.
///
/// `pages` records page-level success and diagnostics so the parser can decide
/// between fail-closed behavior, partial degradation, and OCR execution.
pub struct PdfRasterResult {
  backend_name : String
  page_count : Int
  pages : Array[PdfRasterPageArtifact]
  diagnostics : Array[String]
}

///|
/// Stable diagnostics/provenance label for one raster backend kind.
pub fn pdf_rasterizer_kind_name(kind : PdfRasterizerKind) -> String {
  match kind {
    PdfRasterizerKind::PdfToPpm => "pdftoppm"
  }
}

///|
/// Stable diagnostics/provenance label for one raster status.
pub fn pdf_rasterizer_status_name(status : PdfRasterizerStatus) -> String {
  match status {
    PdfRasterizerStatus::CommandUnavailable => "command_unavailable"
    PdfRasterizerStatus::ExecutionFailed => "execution_failed"
    PdfRasterizerStatus::OutputParseFailed => "output_parse_failed"
    PdfRasterizerStatus::EmptyResult => "empty_result"
  }
}

///|
/// Map a rasterizer error to its coarse status category.
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
/// Human-readable installation guidance for the required `pdftoppm` backend.
pub fn pdf_raster_backend_install_hint() -> String {
  @focr.dependency_diagnostic_card(
    "Missing dependency: pdftoppm / Poppler",
    "PDF OCR requires the local `pdftoppm` raster backend before any OCR provider can run.",
    ["./tools/env/optional_deps.sh install accurate"],
    [
      "MARKITDOWN_PDFTOPPM_BIN=/absolute/path/to/pdftoppm", "pdftoppm must match the managed/runtime baseline for your OS/arch",
    ],
    footer=Some(
      "This dependency belongs only to the optional Accurate PDF route. Repo-managed installs record `pdftoppm` under `./env/managed-paths/pdftoppm`; custom overrides can use `MARKITDOWN_PDFTOPPM_BIN`, but must stay aligned with the managed runtime fingerprint.",
    ),
  )
}

///|
/// Structured dependency diagnostic for the required `pdftoppm` backend.
pub fn pdf_raster_backend_dependency_diagnostic() -> @core.DependencyDiagnostic {
  @focr.dependency_diagnostic_entry(
    "Missing dependency: pdftoppm / Poppler",
    "PDF OCR requires the local `pdftoppm` raster backend before any OCR provider can run.",
    ["./tools/env/optional_deps.sh install accurate"],
    [
      "MARKITDOWN_PDFTOPPM_BIN=/absolute/path/to/pdftoppm", "pdftoppm must match the managed/runtime baseline for your OS/arch",
    ],
    footer=Some(
      "This dependency belongs only to the optional Accurate PDF route. Repo-managed installs record `pdftoppm` under `./env/managed-paths/pdftoppm`; custom overrides can use `MARKITDOWN_PDFTOPPM_BIN`, but must stay aligned with the managed runtime fingerprint.",
    ),
  )
}

///|
/// Expand a rasterizer error into a user-facing message with install guidance.
pub fn pdf_raster_provider_error_message(error : PdfRasterizerError) -> String {
  error.to_string() + " " + pdf_raster_backend_install_hint()
}

///|
/// Environment variable used to override the `pdftoppm` executable path.
pub fn pdftoppm_command_env_var() -> String {
  "MARKITDOWN_PDFTOPPM_BIN"
}

///|
/// Parser capability shared by PDF OCR routes that depend on rasterized page
/// layout.
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
  match @env.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        ".tmp/tests/pdf_ocr"
      } else {
        trimmed + "/pdf_ocr"
      }
    }
    None => ".tmp/tests/pdf_ocr"
  }
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
#warnings("-deprecated")
fn pdf_ocr_cleanup_temp_dir(path : String) -> Unit {
  if !@fs.path_exists(path) {
    return
  }
  ignore(
    try
      @async.with_event_loop(_group => @afs.rmdir(path, recursive=true)) |> Ok
    catch {
      _ => Err(())
    },
  )
}

///|
async fn pdf_ocr_cleanup_temp_dir_async(path : String) -> Unit {
  if path.trim() == "" {
    return
  }
  @afs.rmdir(path, recursive=true) catch {
    _ => ()
  }
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
priv struct PdfToPpmCommandPlan {
  command : @rtcmd.ResolvedCommand
  argv : Array[String]
}

///|
fn resolve_pdftoppm_command() -> Result[
  @rtcmd.ResolvedCommand,
  PdfRasterizerError,
] {
  match @rtcmd.resolve_repo_managed_command("pdftoppm") {
    Some(command) => return Ok(command)
    None => ()
  }
  match @rtcmd.normalized_env_var(pdftoppm_command_env_var()) {
    Some(path) =>
      match
        @rtcmd.resolve_executable_path(
          path,
          pdftoppm_command_env_var(),
          @rtcmd.ResolvedCommandSource::EnvVar,
        ) {
        Ok(command) => return Ok(command)
        Err(msg) => return Err(PdfRasterizerError::CommandUnavailable(msg))
      }
    None => ()
  }
  match @rtcmd.resolve_path_command("pdftoppm") {
    Some(command) => Ok(command)
    None => Ok(@rtcmd.fallback_command("pdftoppm"))
  }
}

///|
fn pdftoppm_png_output_prefix(output_dir : String) -> String {
  output_dir + "/page"
}

///|
fn build_pdftoppm_png_command_plan(
  pdf_path : String,
  output_dir : String,
) -> Result[PdfToPpmCommandPlan, PdfRasterizerError] {
  let command = match resolve_pdftoppm_command() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    command,
    argv: [
      "-r",
      "150",
      "-png",
      pdf_path,
      pdftoppm_png_output_prefix(output_dir),
    ],
  })
}

///|
pub fn build_pdftoppm_png_command(
  pdf_path : String,
  output_dir : String,
) -> (String, Array[String]) {
  let command = match resolve_pdftoppm_command() {
    Ok(value) => value
    Err(_) => @rtcmd.fallback_command("pdftoppm")
  }
  (
    command.program,
    ["-r", "150", "-png", pdf_path, pdftoppm_png_output_prefix(output_dir)],
  )
}

///|
#warnings("-deprecated")
fn collect_pdftoppm_output(
  command : @rtcmd.ResolvedCommand,
  args : Array[String],
) -> Result[(Int, String, String), PdfRasterizerError] {
  let collected : Ref[Result[(Int, String, String), PdfRasterizerError]?] = {
    val: None,
  }
  @async.with_event_loop(_group => {
    let delegated = @process.collect_output(command.program, args) catch {
      e => {
        collected.val = Some(
          Err(
            PdfRasterizerError::ExecutionFailed(
              "launch pdftoppm failed on this runtime: " +
              e.to_string() +
              "\nResolved command: " +
              @rtcmd.resolved_command_context(command),
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
          "launch pdftoppm failed on this runtime: " +
          e.to_string() +
          "\nResolved command: " +
          @rtcmd.resolved_command_context(command),
        ),
      )
  }
  match collected.val {
    Some(result) => result
    None =>
      Err(
        PdfRasterizerError::ExecutionFailed(
          "launch pdftoppm failed on this runtime: event loop returned no result\nResolved command: " +
          @rtcmd.resolved_command_context(command),
        ),
      )
  }
}

///|
async fn collect_pdftoppm_output_async_resolved(
  command : @rtcmd.ResolvedCommand,
  args : Array[String],
) -> Result[(Int, String, String), PdfRasterizerError] {
  let delegated = @process.collect_output(command.program, args) catch {
    e =>
      return Err(
        PdfRasterizerError::ExecutionFailed(
          "launch pdftoppm failed on this runtime: " +
          e.to_string() +
          "\nResolved command: " +
          @rtcmd.resolved_command_context(command),
        ),
      )
  }
  match delegated {
    (code, stdout, stderr) => {
      let stdout_text = stdout.text() catch {
        e =>
          return Err(
            PdfRasterizerError::OutputParseFailed(
              "failed to decode pdftoppm stdout as UTF-8 on this runtime: " +
              e.to_string(),
            ),
          )
      }
      let stderr_text = stderr.text() catch {
        e =>
          return Err(
            PdfRasterizerError::OutputParseFailed(
              "failed to decode pdftoppm stderr as UTF-8 on this runtime: " +
              e.to_string(),
            ),
          )
      }
      Ok((code, stdout_text, stderr_text))
    }
  }
}

///|
pub async fn collect_pdftoppm_output_async(
  cmd : String,
  args : Array[String],
) -> Result[(Int, String, String), PdfRasterizerError] {
  collect_pdftoppm_output_async_resolved(
    @rtcmd.make_resolved_command(
      cmd,
      cmd,
      @rtcmd.ResolvedCommandSource::Fallback,
    ),
    args,
  )
}

///|
fn finalize_pdftoppm_result(
  paths : Array[String],
  command : @rtcmd.ResolvedCommand,
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
      diagnostics.push(
        "pdftoppm_command_source=" +
        @rtcmd.resolved_command_source_label(command.source),
      )
      diagnostics.push("pdftoppm_command=" + command.display_command)
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
            "pdftoppm command is unavailable on this runtime: " +
            raw_message +
            "\nResolved command: " +
            @rtcmd.resolved_command_context(command),
          ),
        )
      } else {
        Err(
          PdfRasterizerError::ExecutionFailed(
            "pdftoppm command failed on this runtime: " +
            raw_message +
            "\nResolved command: " +
            @rtcmd.resolved_command_context(command),
          ),
        )
      }
    }
  }
}

///|
fn pdftoppm_png_paths(
  output_prefix : String,
) -> Array[String] raise @fs.IOError {
  let paths : Array[String] = []
  let mut page_index = 1
  while true {
    let candidate = output_prefix + "-" + page_index.to_string() + ".png"
    if !@fs.path_exists(candidate) {
      break
    }
    if @fs.is_file(candidate) {
      paths.push(candidate)
      page_index = page_index + 1
      continue
    }
    break
  }
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
  let plan = match build_pdftoppm_png_command_plan(pdf_path, output_dir) {
    Ok(value) => value
    Err(error) => {
      pdf_ocr_cleanup_temp_dir(temp_dir)
      return Err(error)
    }
  }
  let output_prefix = pdftoppm_png_output_prefix(output_dir)
  let delegated = match collect_output(plan.command.program, plan.argv) {
    Ok(value) => value
    Err(error) => {
      pdf_ocr_cleanup_temp_dir(temp_dir)
      return Err(error)
    }
  }
  let finalized = match delegated {
    (0, _, _) => {
      let paths = pdftoppm_png_paths(output_prefix) catch {
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
        finalize_pdftoppm_result(paths, plan.command, delegated)
      }
    }
    _ => finalize_pdftoppm_result([], plan.command, delegated)
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
  let plan = match build_pdftoppm_png_command_plan(pdf_path, output_dir) {
    Ok(value) => value
    Err(error) => {
      pdf_ocr_cleanup_temp_dir(temp_dir)
      return Err(error)
    }
  }
  let output_prefix = pdftoppm_png_output_prefix(output_dir)
  let delegated = match collect_pdftoppm_output(plan.command, plan.argv) {
    Ok(value) => value
    Err(error) => {
      pdf_ocr_cleanup_temp_dir(temp_dir)
      return Err(error)
    }
  }
  let finalized = match delegated {
    (0, _, _) => {
      let paths = pdftoppm_png_paths(output_prefix) catch {
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
        finalize_pdftoppm_result(paths, plan.command, delegated)
      }
    }
    _ => finalize_pdftoppm_result([], plan.command, delegated)
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
pub async fn rasterize_pdf_with_pdftoppm_async(
  source : @input.InputSource,
  collect_output : async (String, Array[String]) -> Result[
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
  let plan = match build_pdftoppm_png_command_plan(pdf_path, output_dir) {
    Ok(value) => value
    Err(error) => {
      pdf_ocr_cleanup_temp_dir(temp_dir)
      return Err(error)
    }
  }
  let output_prefix = pdftoppm_png_output_prefix(output_dir)
  let delegated = match collect_output(plan.command.program, plan.argv) {
    Ok(value) => value
    Err(error) => {
      pdf_ocr_cleanup_temp_dir(temp_dir)
      return Err(error)
    }
  }
  let finalized = match delegated {
    (0, _, _) => {
      let paths = pdftoppm_png_paths(output_prefix) catch {
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
        finalize_pdftoppm_result(paths, plan.command, delegated)
      }
    }
    _ => finalize_pdftoppm_result([], plan.command, delegated)
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
pub async fn rasterize_pdf_with_pdftoppm_default_async(
  source : @input.InputSource,
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
  let plan = match build_pdftoppm_png_command_plan(pdf_path, output_dir) {
    Ok(value) => value
    Err(error) => {
      pdf_ocr_cleanup_temp_dir(temp_dir)
      return Err(error)
    }
  }
  let output_prefix = pdftoppm_png_output_prefix(output_dir)
  let delegated = match
    collect_pdftoppm_output_async_resolved(plan.command, plan.argv) {
    Ok(value) => value
    Err(error) => {
      pdf_ocr_cleanup_temp_dir(temp_dir)
      return Err(error)
    }
  }
  let finalized = match delegated {
    (0, _, _) => {
      let paths = pdftoppm_png_paths(output_prefix) catch {
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
        finalize_pdftoppm_result(paths, plan.command, delegated)
      }
    }
    _ => finalize_pdftoppm_result([], plan.command, delegated)
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
pub fn cleanup_pdf_ocr_temp_dir(path : String) -> Unit {
  pdf_ocr_cleanup_temp_dir(path)
}
