///|
/// CLI conversion orchestration layer.
///
/// Responsibility split:
/// - parse/validate runtime IO choices (output file vs stdout, metadata switch)
/// - call converter dispatcher and emit markdown
/// - optionally emit metadata sidecar
///
/// Non-goal:
/// - does not implement format-specific parsing strategy
async fn cmd_convert(
  input : String,
  output : String?,
  out_dir : String?,
  max_heading : Int,
  pdf_mode : String?,
  pdf_extract_debug : Bool,
  pdf_dump_selected_raw : Bool,
  pdf_pipeline_debug : Bool,
  with_metadata : Bool,
) -> Unit {
  match
    convert_once(
      input, output, out_dir, max_heading, pdf_mode, pdf_extract_debug, pdf_dump_selected_raw,
      pdf_pipeline_debug, with_metadata,
    ) {
    Ok(_) => ()
    Err(msg) => exit_error(msg)
  }
}

///|
pub fn exit_error(msg : String) -> Unit {
  println("error: " + msg)
}

///|
async fn convert_once(
  input : String,
  output : String?,
  out_dir : String?,
  max_heading : Int,
  pdf_mode : String?,
  pdf_extract_debug : Bool,
  pdf_dump_selected_raw : Bool,
  pdf_pipeline_debug : Bool,
  with_metadata : Bool,
) -> Result[Unit, String] {
  let resolved_output = resolve_output_path(input, output)
  let format = detect_input_format(input)
  let xlsx_profile_enabled = format == "xlsx" && debug_profile_xlsx_enabled()
  let xlsx_profile_report : Ref[@xlsx.XlsxProfileReport?] = { val: None }

  let out_root = match out_dir {
    Some(d) => d
    None =>
      match resolved_output {
        Some(p) => dirname_of_path(p)
        None => "out"
      }
  }

  ensure_dir_tree(out_root) catch {
    e => return Err(e.to_string())
  }

  let opts : @conv.ConvertOptions = {
    out_dir: Some(out_root),
    max_heading: Some(max_heading),
    pdf_enhance_mode: pdf_mode,
    pdf_extract_debug,
    pdf_dump_selected_raw,
    pdf_pipeline_debug,
  }

  let parse_started = @env.now()
  let doc = if xlsx_profile_enabled {
    let profiled = @xlsx.parse_xlsx_with_profile(input, out_root, max_heading) catch {
      e => return Err("parse failed: " + e.to_string())
    }
    match profiled {
      (d, profile) => {
        xlsx_profile_report.val = profile
        d
      }
    }
  } else {
    match @conv.parse_to_ir(input, opts) {
      Ok(d) => d
      Err(e) => return Err("parse failed: " + e.to_string())
    }
  }
  xlsx_profile_push_cli_stage(
    xlsx_profile_report.val,
    "cli_parse_total",
    @env.now() - parse_started,
    Some("blocks=" + doc.blocks.val.length().to_string()),
  )

  let emit_started = @env.now()
  let md = @cor.emit_markdown(doc)
  xlsx_profile_push_cli_stage(
    xlsx_profile_report.val,
    "markdown_emit",
    @env.now() - emit_started,
    Some("markdown_bytes=" + md.length().to_string()),
  )

  match resolved_output {
    Some(p) => {
      let parent = dirname_of_path(p)
      ensure_dir_tree(parent) catch {
        e => return Err("create output dir failed: " + e.to_string())
      }
      let write_markdown_started = @env.now()
      @fs.write_string_to_file(p, md, encoding="utf8") catch {
        e => return Err("write output failed: " + e.to_string())
      }
      xlsx_profile_push_cli_stage(
        xlsx_profile_report.val,
        "markdown_write",
        @env.now() - write_markdown_started,
        Some("path=" + p),
      )

      if with_metadata {
        let markdown_file = @cor.basename(p)
        let docprops_started = @env.now()
        let document = read_document_properties(input, format)
        let document_available = match document {
          Some(_) => "true"
          None => "false"
        }
        xlsx_profile_push_cli_stage(
          xlsx_profile_report.val,
          "metadata_document_properties",
          @env.now() - docprops_started,
          Some("available=" + document_available),
        )
        let metadata_emit_started = @env.now()
        let metadata_json = @cor.emit_metadata_json_with_document_properties(
          doc,
          @cor.basename(input),
          format,
          markdown_file,
          document,
        )
        xlsx_profile_push_cli_stage(
          xlsx_profile_report.val,
          "metadata_json_emit",
          @env.now() - metadata_emit_started,
          Some("metadata_bytes=" + metadata_json.length().to_string()),
        )
        let metadata_path = metadata_output_path(p)
        let metadata_dir = dirname_of_path(metadata_path)

        ensure_dir_tree(metadata_dir) catch {
          e => return Err("create metadata dir failed: " + e.to_string())
        }

        let metadata_write_started = @env.now()
        @fs.write_string_to_file(metadata_path, metadata_json, encoding="utf8") catch {
          e => return Err("write metadata failed: " + e.to_string())
        }
        xlsx_profile_push_cli_stage(
          xlsx_profile_report.val,
          "metadata_write",
          @env.now() - metadata_write_started,
          Some("path=" + metadata_path),
        )
      }

      let _ = write_xlsx_profile_log_if_enabled(
        xlsx_profile_report.val,
        p,
        with_metadata,
      ) catch {
        e => return Err("write xlsx profile failed: " + e.to_string())
      }

      Ok(())
    }
    None => {
      // stdout mode is intentionally markdown-only:
      // sidecar needs a deterministic on-disk path and should not mix with text stream.
      println(md)
      Ok(())
    }
  }
}

///|
struct BatchItemResult {
  index : Int
  input_path : String
  output_md : String?
  format : String
  status : String
  elapsed_ms : Int
  error : String
}

///|
struct BatchRunResult {
  total_count : Int
  success_count : Int
  failure_count : Int
  unsupported_count : Int
  skipped_directory_count : Int
  had_error : Bool
  summary_path : String
}

///|
fn batch_summary_line(result : BatchRunResult) -> String {
  "batch summary: " +
  result.success_count.to_string() +
  " ok, " +
  result.failure_count.to_string() +
  " failed, " +
  result.unsupported_count.to_string() +
  " unsupported, " +
  result.skipped_directory_count.to_string() +
  " skipped_directory, " +
  result.total_count.to_string() +
  " total -> " +
  result.summary_path
}

///|
async fn run_batch(
  input_dir : String,
  output_dir : String,
  with_metadata : Bool,
) -> Result[BatchRunResult, String] {
  let items = collect_batch_inputs(input_dir) catch {
    e => return Err("read batch input dir failed: " + e.to_string())
  }
  ensure_dir_tree(output_dir) catch {
    e => return Err("create batch output dir failed: " + e.to_string())
  }

  let results : Array[BatchItemResult] = []
  let mut success_count = 0
  let mut failure_count = 0
  let mut unsupported_count = 0
  let mut skipped_directory_count = 0

  for i in 0..<items.length() {
    let item = items[i]
    let index = i + 1

    match item.kind {
      BatchInputKind::Directory => {
        skipped_directory_count += 1
        results.push({
          index,
          input_path: item.path,
          output_md: None,
          format: "",
          status: "skipped_directory",
          elapsed_ms: 0,
          error: "",
        })
      }
      BatchInputKind::File => {
        let format = detect_input_format(item.path)
        if format == "unknown" {
          failure_count += 1
          unsupported_count += 1
          results.push({
            index,
            input_path: item.path,
            output_md: None,
            format: file_ext_lower(item.path),
            status: "unsupported",
            elapsed_ms: 0,
            error: "Unsupported file type: " + file_ext_lower(item.path),
          })
          continue
        }

        let doc_root = batch_doc_root(output_dir, index, item.path)
        let markdown_path = join_path(doc_root, input_stem(item.path) + ".md")
        let started = now_ms()
        let result = convert_once(
          item.path,
          Some(markdown_path),
          Some(doc_root),
          6,
          None,
          false,
          false,
          false,
          with_metadata,
        )
        let elapsed_ms = elapsed_ms_since(started)

        match result {
          Ok(_) => {
            success_count += 1
            results.push({
              index,
              input_path: item.path,
              output_md: Some(markdown_path),
              format,
              status: "ok",
              elapsed_ms,
              error: "",
            })
          }
          Err(msg) => {
            failure_count += 1
            let status = if msg.contains("Unsupported file type:") {
              unsupported_count += 1
              "unsupported"
            } else {
              "failed"
            }
            results.push({
              index,
              input_path: item.path,
              output_md: Some(markdown_path),
              format,
              status,
              elapsed_ms,
              error: msg,
            })
          }
        }
      }
    }
  }

  let summary_path = join_path(output_dir, "batch-summary.tsv")
  write_batch_summary(summary_path, results) catch {
    e => return Err("write batch summary failed: " + e.to_string())
  }

  Ok({
    total_count: items.length(),
    success_count,
    failure_count,
    unsupported_count,
    skipped_directory_count,
    had_error: failure_count > 0,
    summary_path,
  })
}

///|
enum BatchInputKind {
  File
  Directory
}

///|
struct BatchInputEntry {
  path : String
  kind : BatchInputKind
}

///|
fn collect_batch_inputs(
  input_dir : String,
) -> Array[BatchInputEntry] raise @fs.IOError {
  let names = @fs.read_dir(input_dir)
  names.sort()

  let out : Array[BatchInputEntry] = []
  for name in names {
    let child = join_path(input_dir, name)
    if @fs.is_dir(child) {
      out.push({ path: child, kind: BatchInputKind::Directory })
    } else if @fs.is_file(child) {
      out.push({ path: child, kind: BatchInputKind::File })
    }
  }
  out
}

///|
fn file_ext_lower(path : String) -> String {
  let n = path.length()
  if n == 0 {
    return ""
  }

  let mut i = n - 1
  while i >= 0 {
    if path[i] == '.' {
      if i == n - 1 {
        return ""
      }
      return path[i + 1:].to_owned().to_lower()
    }
    i = i - 1
  }
  ""
}

///|
fn batch_doc_root(
  output_dir : String,
  index : Int,
  input_path : String,
) -> String {
  join_path(
    output_dir,
    pad_batch_index(index) + "-" + sanitize_batch_stem(input_stem(input_path)),
  )
}

///|
fn pad_batch_index(n : Int) -> String {
  if n < 10 {
    "00" + n.to_string()
  } else if n < 100 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn sanitize_batch_stem(raw : String) -> String {
  let chars = raw.to_array()
  let out : Array[Char] = []
  for ch in chars {
    let keep = (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9')
    if keep {
      out.push(ch)
    } else if ch == '-' || ch == '_' {
      out.push(ch)
    } else {
      out.push('-')
    }
  }

  let text = String::from_array(out).trim().to_owned()
  if text == "" {
    "document"
  } else {
    text
  }
}

///|
fn write_batch_summary(
  path : String,
  results : Array[BatchItemResult],
) -> Unit raise @fs.IOError {
  let lines : Array[String] = [
    "index\tinput_path\toutput_md\tformat\tstatus\telapsed_ms\terror",
  ]
  for item in results {
    let output_md = match item.output_md {
      Some(p) => p
      None => ""
    }
    lines.push(
      item.index.to_string() +
      "\t" +
      summary_escape(item.input_path) +
      "\t" +
      summary_escape(output_md) +
      "\t" +
      summary_escape(item.format) +
      "\t" +
      summary_escape(item.status) +
      "\t" +
      item.elapsed_ms.to_string() +
      "\t" +
      summary_escape(item.error),
    )
  }
  @fs.write_string_to_file(path, lines.join("\n") + "\n", encoding="utf8")
}

///|
fn summary_escape(text : String) -> String {
  text
  .replace(old="\t", new=" ")
  .replace(old="\n", new=" ")
  .replace(old="\r", new=" ")
}

///|
fn elapsed_ms_since(started : Int64) -> Int {
  let now = now_ms()
  if now <= started {
    0
  } else {
    (now - started).to_int()
  }
}

///|
fn resolve_output_path(input : String, output : String?) -> String? {
  match output {
    None => None
    Some(raw) => {
      let out = raw.trim().to_owned()
      if out == "" {
        None
      } else if looks_like_output_dir(out) {
        Some(join_path(out, input_stem(input) + ".md"))
      } else {
        Some(out)
      }
    }
  }
}

///|
fn looks_like_output_dir(path : String) -> Bool {
  if path.has_suffix("/") || path.has_suffix("\\") {
    return true
  }

  let base = @cor.basename(path)
  let base_lower = base.to_lower()
  if base_lower.has_suffix(".md") || base_lower.has_suffix(".markdown") {
    return false
  }

  if !@fs.path_exists(path) {
    // 对于不存在的路径，默认按目录处理，便于 `normal A/B.pdf C` 产出 `C/B.md`
    return true
  }

  true
}

///|
fn dirname_of_path(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' {
      last = i
    }
  }
  if last <= 0 {
    "."
  } else {
    path[:last].to_owned()
  }
}

///|
fn join_path(dir : String, file : String) -> String {
  if dir.has_suffix("/") {
    dir + file
  } else {
    dir + "/" + file
  }
}

///|
fn input_stem(path : String) -> String {
  let base = @cor.basename(path)
  let mut dot = -1
  for i in 0..<base.length() {
    if base[i] == '.' {
      dot = i
    }
  }
  if dot <= 0 {
    base
  } else {
    base[:dot].to_owned()
  }
}

///|
fn metadata_output_path(markdown_path : String) -> String {
  let base = @cor.basename(markdown_path)
  let dir = dirname_of_path(markdown_path)

  let mut dot = -1
  for i in 0..<base.length() {
    if base[i] == '.' {
      dot = i
    }
  }

  let stem = if dot <= 0 { base } else { base[:dot].to_owned() }

  // Keep sidecar under `metadata/` subdir to avoid cluttering markdown dirs and
  // to make metadata/main_process/assets chain collection easier in CI scripts.
  join_path(join_path(dir, "metadata"), stem + ".metadata.json")
}

///|
fn ensure_dir_tree(path : String) -> Unit raise @fs.IOError {
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

    current = if current == "" || current == "/" {
      if current == "/" {
        "/" + part
      } else {
        part
      }
    } else {
      current + "/" + part
    }

    if !@fs.path_exists(current) {
      @fs.create_dir(current)
    }
  }
}

///|
fn read_document_properties(
  input : String,
  format : String,
) -> @cor.MetadataDocumentProperties? {
  if format == "docx" || format == "pptx" || format == "xlsx" {
    return read_ooxml_document_properties(input)
  }
  if format == "epub" {
    return read_epub_document_properties(input)
  }
  None
}

///|
fn debug_profile_xlsx_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_XLSX") {
    Some(raw) => {
      let value = raw.trim().to_lower()
      value == "1" || value == "true" || value == "yes" || value == "on"
    }
    None => false
  }
}

///|
fn xlsx_profile_push_cli_stage(
  profile : @xlsx.XlsxProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  @xlsx.xlsx_profile_add_stage(profile, name, elapsed_ms, detail)
}

///|
fn write_xlsx_profile_log_if_enabled(
  profile : @xlsx.XlsxProfileReport?,
  markdown_path : String,
  with_metadata : Bool,
) -> Unit raise @fs.IOError {
  match profile {
    None => ()
    Some(rep) => {
      let debug_dir = join_path(dirname_of_path(markdown_path), "debug")
      ensure_dir_tree(debug_dir)
      let profile_path = join_path(
        debug_dir,
        input_stem(markdown_path) + ".xlsx.profile.log",
      )
      let lines : Array[String] = [
        @xlsx.xlsx_profile_render_report(rep),
        "xlsx_profile cli markdown_output=" + markdown_path,
        "xlsx_profile cli metadata_enabled=" + with_metadata.to_string(),
      ]
      @fs.write_string_to_file(
        profile_path,
        lines.join("\n") + "\n",
        encoding="utf8",
      )
    }
  }
}

///|
fn read_ooxml_document_properties(
  input : String,
) -> @cor.MetadataDocumentProperties? {
  let bytes = @fs.read_file_to_bytes(input) catch { _ => return None }
  let pkg = @ox.open_ooxml_package(bytes) catch { _ => return None }
  let core = @ox.read_core_properties(pkg)
  let app = @ox.read_app_properties(pkg)

  Some(
    @cor.metadata_document_properties(
      core.title,
      core.subject,
      core.creator,
      core.description,
      core.keywords,
      core.created,
      core.modified,
      app.application,
      app.pages,
      app.words,
      app.slides,
      app.sheets,
    ),
  )
}

///|
fn read_epub_document_properties(
  input : String,
) -> @cor.MetadataDocumentProperties? {
  let bytes = @fs.read_file_to_bytes(input) catch { _ => return None }
  let pkg = @epubpkg.open_epub_package(bytes, @cor.basename(input)) catch {
    _ => return None
  }
  let meta = pkg.metadata

  Some(
    @cor.metadata_document_properties(
      meta.title,
      None,
      meta.creator,
      None,
      None,
      meta.date,
      meta.modified,
      Some("EPUB"),
      None,
      None,
      None,
      None,
    ),
  )
}

///|
fn detect_input_format(path : String) -> String {
  let base = @cor.basename(path).to_lower()
  if base.has_suffix(".docx") {
    "docx"
  } else if base.has_suffix(".pdf") {
    "pdf"
  } else if base.has_suffix(".xlsx") {
    "xlsx"
  } else if base.has_suffix(".pptx") {
    "pptx"
  } else if base.has_suffix(".html") || base.has_suffix(".htm") {
    "html"
  } else if base.has_suffix(".csv") {
    "csv"
  } else if base.has_suffix(".tsv") {
    "tsv"
  } else if base.has_suffix(".txt") {
    "txt"
  } else if base.has_suffix(".xml") {
    "xml"
  } else if base.has_suffix(".json") {
    "json"
  } else if base.has_suffix(".yaml") || base.has_suffix(".yml") {
    "yaml"
  } else if base.has_suffix(".markdown") || base.has_suffix(".md") {
    "markdown"
  } else if base.has_suffix(".zip") {
    "zip"
  } else if base.has_suffix(".epub") {
    "epub"
  } else {
    "unknown"
  }
}
