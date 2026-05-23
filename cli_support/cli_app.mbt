///|
pub enum OcrPolicy {
  Auto
  Force
  Disable
} derive(Eq)

///|
pub struct OcrDecision {
  use_ocr : Bool
  continue_native : Bool
  reason : String
  fail_closed_message : String?
}

///|
pub fn default_ocr_policy() -> OcrPolicy {
  OcrPolicy::Auto
}

///|
pub fn force_ocr_policy() -> OcrPolicy {
  OcrPolicy::Force
}

///|
pub fn disable_ocr_policy() -> OcrPolicy {
  OcrPolicy::Disable
}

///|
pub fn parse_ocr_policy_flags(
  force_ocr : Bool,
  disable_ocr : Bool,
) -> Result[OcrPolicy, String] {
  if force_ocr && disable_ocr {
    return Err("--ocr and --no-ocr cannot be used together")
  }
  if force_ocr {
    return Ok(OcrPolicy::Force)
  }
  if disable_ocr {
    return Ok(OcrPolicy::Disable)
  }
  Ok(OcrPolicy::Auto)
}

///|
pub fn decide_ocr_policy(input : String, policy : OcrPolicy) -> OcrDecision {
  match detect_ocr_image_format(input) {
    Some(_) => decide_image_ocr_policy(policy)
    None => {
      let format = detect_input_format(input)
      if format == "pdf" {
        decide_pdf_ocr_policy(policy)
      } else {
        decide_non_image_ocr_policy(policy)
      }
    }
  }
}

///|
fn decide_image_ocr_policy(policy : OcrPolicy) -> OcrDecision {
  match policy {
    OcrPolicy::Auto | OcrPolicy::Force =>
      {
        use_ocr: true,
        continue_native: false,
        reason: "image_ocr_execute",
        fail_closed_message: None,
      }
    OcrPolicy::Disable =>
      {
        use_ocr: false,
        continue_native: false,
        reason: "image_ocr_disabled_no_native_path",
        fail_closed_message: Some(image_ocr_disabled_message()),
      }
  }
}

///|
fn decide_pdf_ocr_policy(policy : OcrPolicy) -> OcrDecision {
  match policy {
    OcrPolicy::Force =>
      {
        use_ocr: true,
        continue_native: false,
        reason: "pdf_ocr_not_wired",
        fail_closed_message: Some(pdf_ocr_not_wired_message()),
      }
    OcrPolicy::Auto | OcrPolicy::Disable =>
      {
        use_ocr: false,
        continue_native: true,
        reason: "native_pdf_path",
        fail_closed_message: None,
      }
  }
}

///|
fn decide_non_image_ocr_policy(policy : OcrPolicy) -> OcrDecision {
  match policy {
    OcrPolicy::Force =>
      {
        use_ocr: true,
        continue_native: false,
        reason: "force_ocr_non_image_not_supported",
        fail_closed_message: Some(non_image_force_ocr_not_supported_message()),
      }
    OcrPolicy::Auto | OcrPolicy::Disable =>
      {
        use_ocr: false,
        continue_native: true,
        reason: "native_document_path",
        fail_closed_message: None,
      }
  }
}

///|
fn image_ocr_disabled_message() -> String {
  "OCR disabled for image input; no native image-to-markdown conversion is available."
}

///|
fn pdf_ocr_not_wired_message() -> String {
  "PDF OCR is not wired in this build. Image OCR will use the main CLI OCR path; PDF OCR will require an explicit PDF OCR provider."
}

///|
fn non_image_force_ocr_not_supported_message() -> String {
  "OCR is only recognized for image inputs in this build; PDF OCR is not wired."
}

///|
/// CLI conversion orchestration layer.
///
/// Responsibility split:
/// - parse/validate runtime IO choices (output file vs stdout, metadata switch)
/// - dispatch core product conversion in-process
/// - route PDF and ZIP through bundled product components when that keeps the
///   main CLI build closure under control
/// - emit markdown and metadata sidecar
/// - keep OCR out of the normal path until explicit main-CLI controls land
///
/// Non-goal:
/// - does not implement format-specific parsing strategy
pub async fn cmd_convert(
  input : String,
  output : String?,
  out_dir : String?,
  max_heading : Int,
  pdf_mode : String?,
  pdf_extract_debug : Bool,
  pdf_dump_selected_raw : Bool,
  pdf_pipeline_debug : Bool,
  with_metadata : Bool,
  ocr_policy : OcrPolicy,
  ocr_lang : String?,
) -> Unit {
  match
    convert_once(
      input, output, out_dir, max_heading, pdf_mode, pdf_extract_debug, pdf_dump_selected_raw,
      pdf_pipeline_debug, with_metadata, ocr_policy, ocr_lang,
    ) {
    Ok(_) => ()
    Err(msg) => exit_error(msg)
  }
}

///|
pub fn exit_error(msg : String) -> Unit {
  @clicom.exit_error(msg)
}

///|
pub async fn convert_once(
  input : String,
  output : String?,
  out_dir : String?,
  max_heading : Int,
  pdf_mode : String?,
  pdf_extract_debug : Bool,
  pdf_dump_selected_raw : Bool,
  pdf_pipeline_debug : Bool,
  with_metadata : Bool,
  ocr_policy : OcrPolicy,
  ocr_lang : String?,
) -> Result[Unit, String] {
  let resolved_output = resolve_output_path(input, output)
  let normalized_ocr_lang = match
    validate_ocr_lang_usage(input, ocr_policy, ocr_lang) {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  let ocr_decision = decide_ocr_policy(input, ocr_policy)
  if ocr_decision.reason == "image_ocr_execute" {
    return run_image_ocr_conversion(
      input, resolved_output, with_metadata, normalized_ocr_lang,
    )
  }
  if !ocr_decision.continue_native {
    match ocr_decision.fail_closed_message {
      Some(msg) => return Err(msg)
      None => return Err("OCR policy decision failed closed")
    }
  }
  let format = detect_input_format(input)
  if format == "pdf" {
    if pdf_mode is Some(mode) && mode.trim() != "" {
      return Err(pdf_ocr_not_wired_message())
    }
    if pdf_extract_debug || pdf_dump_selected_raw || pdf_pipeline_debug {
      return Err(
        "pdf debug extraction moved to debug; the normal cli only supports plain product PDF conversion",
      )
    }
    return delegate_pdf_conversion(input, output, with_metadata)
  }
  if format == "zip" {
    return delegate_zip_conversion(input, output, with_metadata)
  }
  let xlsx_profile_enabled = format == "xlsx" && debug_profile_xlsx_enabled()
  let csv_profile_enabled = (format == "csv" || format == "tsv") &&
    debug_profile_csv_enabled()
  let json_profile_enabled = format == "json" && debug_profile_json_enabled()
  let txt_profile_enabled = format == "txt" && debug_profile_txt_enabled()
  let yaml_profile_enabled = (format == "yaml" || format == "yml") &&
    debug_profile_yaml_enabled()
  let xlsx_profile_report : Ref[@xlsx.XlsxProfileReport?] = { val: None }
  let csv_profile_report : Ref[@csv.CsvProfileReport?] = { val: None }
  let json_profile_report : Ref[@json.JsonProfileReport?] = { val: None }
  let txt_profile_report : Ref[@txt.TxtProfileReport?] = { val: None }
  let yaml_profile_report : Ref[@yaml.YamlProfileReport?] = { val: None }

  let output_root_opt = match out_dir {
    Some(d) => Some(d)
    None =>
      match resolved_output {
        Some(p) => Some(dirname_of_path(p))
        None => None
      }
  }
  let parse_out_dir = output_root_opt.unwrap_or("")

  if output_root_opt is Some(out_root) {
    ensure_dir_tree(out_root) catch {
      e => return Err(e.to_string())
    }
  }

  let parse_started = @env.now()
  let doc = if xlsx_profile_enabled {
    let profiled = @xlsx.parse_xlsx_with_profile(
      input, parse_out_dir, max_heading,
    ) catch {
      e => return Err("parse failed: " + e.to_string())
    }
    match profiled {
      (d, profile) => {
        xlsx_profile_report.val = profile
        d
      }
    }
  } else if csv_profile_enabled {
    let profiled = try {
      if format == "tsv" {
        @csv.parse_tsv_with_profile(input, parse_out_dir, max_heading)
      } else {
        @csv.parse_csv_with_profile(input, parse_out_dir, max_heading)
      }
    } catch {
      e => return Err("parse failed: " + e.to_string())
    }
    match profiled {
      (d, profile) => {
        csv_profile_report.val = profile
        d
      }
    }
  } else if json_profile_enabled {
    let profiled = @json.parse_json_with_profile(
      input, parse_out_dir, max_heading,
    ) catch {
      e => return Err("parse failed: " + e.to_string())
    }
    match profiled {
      (d, profile) => {
        json_profile_report.val = profile
        d
      }
    }
  } else if txt_profile_enabled {
    let profiled = @txt.parse_txt_with_profile(
      input, parse_out_dir, max_heading,
    ) catch {
      e => return Err("parse failed: " + e.to_string())
    }
    match profiled {
      (d, profile) => {
        txt_profile_report.val = profile
        d
      }
    }
  } else if yaml_profile_enabled {
    let profiled = @yaml.parse_yaml_with_profile(
      input, parse_out_dir, max_heading,
    ) catch {
      e => return Err("parse failed: " + e.to_string())
    }
    match profiled {
      (d, profile) => {
        yaml_profile_report.val = profile
        d
      }
    }
  } else {
    match
      parse_core_product_input_to_ir(input, format, parse_out_dir, max_heading) {
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
  csv_profile_push_cli_stage(
    csv_profile_report.val,
    "cli_parse_total",
    @env.now() - parse_started,
    Some("blocks=" + doc.blocks.val.length().to_string()),
  )
  json_profile_push_cli_stage(
    json_profile_report.val,
    "cli_parse_total",
    @env.now() - parse_started,
    Some("blocks=" + doc.blocks.val.length().to_string()),
  )
  txt_profile_push_cli_stage(
    txt_profile_report.val,
    "cli_parse_total",
    @env.now() - parse_started,
    Some("blocks=" + doc.blocks.val.length().to_string()),
  )
  yaml_profile_push_cli_stage(
    yaml_profile_report.val,
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
  csv_profile_push_cli_stage(
    csv_profile_report.val,
    "markdown_emit",
    @env.now() - emit_started,
    Some("markdown_bytes=" + md.length().to_string()),
  )
  json_profile_push_cli_stage(
    json_profile_report.val,
    "markdown_emit",
    @env.now() - emit_started,
    Some("markdown_bytes=" + md.length().to_string()),
  )
  txt_profile_push_cli_stage(
    txt_profile_report.val,
    "markdown_emit",
    @env.now() - emit_started,
    Some("markdown_bytes=" + md.length().to_string()),
  )
  yaml_profile_push_cli_stage(
    yaml_profile_report.val,
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
      csv_profile_push_cli_stage(
        csv_profile_report.val,
        "markdown_write",
        @env.now() - write_markdown_started,
        Some("path=" + p),
      )
      json_profile_push_cli_stage(
        json_profile_report.val,
        "markdown_write",
        @env.now() - write_markdown_started,
        Some("path=" + p),
      )
      txt_profile_push_cli_stage(
        txt_profile_report.val,
        "markdown_write",
        @env.now() - write_markdown_started,
        Some("path=" + p),
      )
      yaml_profile_push_cli_stage(
        yaml_profile_report.val,
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
        csv_profile_push_cli_stage(
          csv_profile_report.val,
          "metadata_document_properties",
          @env.now() - docprops_started,
          Some("available=" + document_available),
        )
        json_profile_push_cli_stage(
          json_profile_report.val,
          "metadata_document_properties",
          @env.now() - docprops_started,
          Some("available=" + document_available),
        )
        txt_profile_push_cli_stage(
          txt_profile_report.val,
          "metadata_document_properties",
          @env.now() - docprops_started,
          Some("available=" + document_available),
        )
        yaml_profile_push_cli_stage(
          yaml_profile_report.val,
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
        csv_profile_push_cli_stage(
          csv_profile_report.val,
          "metadata_json_emit",
          @env.now() - metadata_emit_started,
          Some("metadata_bytes=" + metadata_json.length().to_string()),
        )
        json_profile_push_cli_stage(
          json_profile_report.val,
          "metadata_json_emit",
          @env.now() - metadata_emit_started,
          Some("metadata_bytes=" + metadata_json.length().to_string()),
        )
        txt_profile_push_cli_stage(
          txt_profile_report.val,
          "metadata_json_emit",
          @env.now() - metadata_emit_started,
          Some("metadata_bytes=" + metadata_json.length().to_string()),
        )
        yaml_profile_push_cli_stage(
          yaml_profile_report.val,
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
        csv_profile_push_cli_stage(
          csv_profile_report.val,
          "metadata_write",
          @env.now() - metadata_write_started,
          Some("path=" + metadata_path),
        )
        json_profile_push_cli_stage(
          json_profile_report.val,
          "metadata_write",
          @env.now() - metadata_write_started,
          Some("path=" + metadata_path),
        )
        txt_profile_push_cli_stage(
          txt_profile_report.val,
          "metadata_write",
          @env.now() - metadata_write_started,
          Some("path=" + metadata_path),
        )
        yaml_profile_push_cli_stage(
          yaml_profile_report.val,
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
      let _ = write_csv_profile_log_if_enabled(
        csv_profile_report.val,
        p,
        with_metadata,
      ) catch {
        e => return Err("write csv profile failed: " + e.to_string())
      }
      let _ = write_json_profile_log_if_enabled(
        json_profile_report.val,
        p,
        with_metadata,
      ) catch {
        e => return Err("write json profile failed: " + e.to_string())
      }
      let _ = write_txt_profile_log_if_enabled(
        txt_profile_report.val,
        p,
        with_metadata,
      ) catch {
        e => return Err("write txt profile failed: " + e.to_string())
      }
      let _ = write_yaml_profile_log_if_enabled(
        yaml_profile_report.val,
        p,
        with_metadata,
      ) catch {
        e => return Err("write yaml profile failed: " + e.to_string())
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
async fn run_image_ocr_conversion(
  input : String,
  output : String?,
  with_metadata : Bool,
  ocr_lang : String?,
) -> Result[Unit, String] {
  let temp_root = image_ocr_temp_root_for_input(input)
  image_ocr_recreate_clean_dir(temp_root) catch {
    e =>
      return Err("Image OCR failed: prepare temp dir failed: " + e.to_string())
  }
  defer cleanup_image_ocr_temp_root(Some(temp_root))

  let signal_output_base = join_path(temp_root, "tesseract/output")
  let signal_output_dir = dirname_of_path(signal_output_base)
  ensure_dir_tree(signal_output_dir) catch {
    e =>
      return Err("Image OCR failed: prepare temp dir failed: " + e.to_string())
  }

  let page = match
    @vision.run_tesseract_tsv_signal(
      input,
      signal_output_base,
      @vision.make_tesseract_signal_options(
        lang=match ocr_lang {
          Some(lang) => lang
          None => ""
        },
      ),
    ) {
    Ok(page) => page
    Err(err) => return Err(map_image_ocr_signal_error(err))
  }
  let resegmented = @vision.resegment_ocr_page_lines_from_words(page)
  let layout = @vision.recover_ocr_layout_page(resegmented)
  let doc = @vision.convert_ocr_layout_page_to_ir(layout)
  write_document_output(input, "image-ocr", doc, output, with_metadata)
}

///|
fn map_image_ocr_signal_error(err : @vision.TesseractSignalError) -> String {
  match err.kind {
    @vision.TesseractSignalErrorKind::CommandFailed =>
      "Image OCR failed: tesseract executable was not available or failed. Install tesseract and language data, or use --no-ocr to disable image OCR."
    @vision.TesseractSignalErrorKind::MissingTsvOutput =>
      "Image OCR failed: tesseract executable was not available or failed. Install tesseract and language data, or use --no-ocr to disable image OCR."
    @vision.TesseractSignalErrorKind::InvalidOutputBase =>
      "Image OCR failed: invalid temporary OCR output path."
    @vision.TesseractSignalErrorKind::TsvParseFailed =>
      "Image OCR failed: tesseract produced invalid TSV output for this image."
  }
}

///|
fn validate_ocr_lang_usage(
  input : String,
  policy : OcrPolicy,
  raw : String?,
) -> Result[String?, String] {
  let normalized = match normalize_ocr_lang_cli_value(raw) {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  match normalized {
    None => Ok(None)
    Some(lang) => {
      if policy == OcrPolicy::Disable {
        return Err("--ocr-lang cannot be used when --no-ocr is set")
      }
      if detect_ocr_image_format(input) is Some(_) {
        return Ok(Some(lang))
      }
      if detect_input_format(input) == "pdf" && policy == OcrPolicy::Force {
        return Ok(Some(lang))
      }
      Err("--ocr-lang can only be used with image OCR in this build")
    }
  }
}

///|
fn normalize_ocr_lang_cli_value(raw : String?) -> Result[String?, String] {
  match raw {
    None => Ok(None)
    Some(value) => {
      let langs = parse_ocr_lang_arg(Some(value))
      if langs.length() == 0 {
        return Err("--ocr-lang must not be blank")
      }
      Ok(Some(langs.join("+")))
    }
  }
}

///|
fn image_ocr_temp_root_for_input(input : String) -> String {
  let base_root = match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(path) => if path.trim() == "" { ".tmp" } else { path }
    None => ".tmp"
  }
  base_root +
  "/helpers/ocr_cli/" +
  sanitize_image_ocr_path_component(input_stem(input)) +
  "-" +
  now_us().to_string()
}

///|
fn sanitize_image_ocr_path_component(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text {
    if is_image_ocr_path_safe_char(ch) {
      out.write_char(ch)
    } else {
      out.write_char('_')
    }
  }
  let sanitized = out.to_string()
  if sanitized.trim() == "" {
    "input"
  } else {
    sanitized
  }
}

///|
fn is_image_ocr_path_safe_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == '_' ||
  ch == '.'
}

///|
fn image_ocr_recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    image_ocr_remove_dir_recursive(path)
  }
  ensure_dir_tree(path)
}

///|
fn cleanup_image_ocr_temp_root(path : String?) -> Unit {
  match path {
    Some(root) => ignore(try? image_ocr_remove_dir_recursive(root))
    None => ()
  }
}

///|
fn image_ocr_remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }

  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      image_ocr_remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }

  @fs.remove_dir(path)
}

///|
fn parse_core_product_input_to_ir(
  input_path : String,
  format : String,
  out_dir : String,
  max_heading : Int,
) -> Result[@cor.Document, Error] {
  match format {
    "docx" => try? @doc.parse_docx(input_path, out_dir, max_heading)
    "xlsx" => try? @xlsx.parse_xlsx(input_path, out_dir, max_heading)
    "pptx" => try? @pptx.parse_pptx(input_path, out_dir, max_heading)
    "html" => try? @html.parse_html(input_path, out_dir, max_heading)
    "htm" => try? @html.parse_html(input_path, out_dir, max_heading)
    "csv" => try? @csv.parse_csv(input_path, out_dir, max_heading)
    "tsv" => try? @csv.parse_tsv(input_path, out_dir, max_heading)
    "txt" => try? @txt.parse_txt(input_path, out_dir, max_heading)
    "xml" => try? @xml.parse_xml(input_path, out_dir, max_heading)
    "json" => try? @json.parse_json(input_path, out_dir, max_heading)
    "yaml" => try? @yaml.parse_yaml(input_path, out_dir, max_heading)
    "yml" => try? @yaml.parse_yaml(input_path, out_dir, max_heading)
    "md" => try? @md.parse_markdown(input_path, out_dir, max_heading)
    "markdown" => try? @md.parse_markdown(input_path, out_dir, max_heading)
    "epub" => try? @epub.parse_epub(input_path, out_dir, max_heading)
    _ => Err(@cor.AppError("Unsupported file type: " + format))
  }
}

///|
async fn delegate_pdf_conversion(
  input : String,
  output : String?,
  with_metadata : Bool,
) -> Result[Unit, String] {
  match
    @clicom.delegate_external_command(
      "bundled PDF support component",
      "pdf",
      "MARKITDOWN_PDF_CLI",
      external_component_args(input, output, with_metadata),
    ) {
    Ok(_) => Ok(())
    Err(msg) =>
      Err(
        "pdf support is unavailable in this product bundle: " +
        msg +
        ". Rebuild pdf alongside cli, or set MARKITDOWN_PDF_CLI for an explicit component path.",
      )
  }
}

///|
async fn delegate_zip_conversion(
  input : String,
  output : String?,
  with_metadata : Bool,
) -> Result[Unit, String] {
  match
    @clicom.delegate_external_command(
      "bundled ZIP support component",
      "zip",
      "MARKITDOWN_ZIP_CLI",
      external_component_args(input, output, with_metadata),
    ) {
    Ok(_) => Ok(())
    Err(msg) =>
      Err(
        "zip support is unavailable in this product bundle: " +
        msg +
        ". Rebuild zip alongside cli, or set MARKITDOWN_ZIP_CLI for an explicit component path.",
      )
  }
}

///|
fn external_component_args(
  input : String,
  output : String?,
  with_metadata : Bool,
) -> Array[String] {
  let args : Array[String] = ["normal"]
  if with_metadata {
    args.push("--with-metadata")
  }
  args.push(input)
  match output {
    Some(out) => args.push(out)
    None => ()
  }
  args
}

///|
pub fn write_document_output(
  input : String,
  format : String,
  doc : @cor.Document,
  output : String?,
  with_metadata : Bool,
) -> Result[Unit, String] {
  @clicom.write_document_output_with_document_properties(
    input,
    format,
    doc,
    output,
    with_metadata,
    read_document_properties(input, format),
  )
}

///|
priv struct BatchItemResult {
  index : Int
  input_path : String
  output_md : String?
  format : String
  status : String
  elapsed_ms : Int
  error : String
}

///|
pub struct BatchRunResult {
  total_count : Int
  success_count : Int
  failure_count : Int
  unsupported_count : Int
  skipped_directory_count : Int
  had_error : Bool
  summary_path : String
}

///|
pub fn batch_summary_line(result : BatchRunResult) -> String {
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
pub async fn run_batch(
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
            format: @cor.file_ext_lower(item.path),
            status: "unsupported",
            elapsed_ms: 0,
            error: "Unsupported file type: " + @cor.file_ext_lower(item.path),
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
          OcrPolicy::Auto,
          None,
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
priv enum BatchInputKind {
  File
  Directory
}

///|
priv struct BatchInputEntry {
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
pub fn resolve_output_path(input : String, output : String?) -> String? {
  @clicom.resolve_output_path(input, output)
}

///|
pub fn dirname_of_path(path : String) -> String {
  @clicom.dirname_of_path(path)
}

///|
pub fn join_path(dir : String, file : String) -> String {
  @clicom.join_path(dir, file)
}

///|
pub fn input_stem(path : String) -> String {
  @clicom.input_stem(path)
}

///|
pub fn metadata_output_path(markdown_path : String) -> String {
  @clicom.metadata_output_path(markdown_path)
}

///|
pub fn ensure_dir_tree(path : String) -> Unit raise @fs.IOError {
  @clicom.ensure_dir_tree(path)
}

///|
pub fn read_document_properties(
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
fn debug_profile_json_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_JSON") {
    Some(raw) => {
      let value = raw.trim().to_lower()
      value == "1" || value == "true" || value == "yes" || value == "on"
    }
    None => false
  }
}

///|
fn debug_profile_csv_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_CSV") {
    Some(raw) => {
      let value = raw.trim().to_lower()
      value == "1" || value == "true" || value == "yes" || value == "on"
    }
    None => false
  }
}

///|
fn debug_profile_txt_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_TXT") {
    Some(raw) => {
      let value = raw.trim().to_lower()
      value == "1" || value == "true" || value == "yes" || value == "on"
    }
    None => false
  }
}

///|
fn debug_profile_yaml_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_YAML") {
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
fn csv_profile_push_cli_stage(
  profile : @csv.CsvProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  @csv.csv_profile_add_stage(profile, name, elapsed_ms, detail)
}

///|
fn json_profile_push_cli_stage(
  profile : @json.JsonProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  @json.json_profile_add_stage(profile, name, elapsed_ms, detail)
}

///|
fn txt_profile_push_cli_stage(
  profile : @txt.TxtProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  @txt.txt_profile_add_stage(profile, name, elapsed_ms, detail)
}

///|
fn yaml_profile_push_cli_stage(
  profile : @yaml.YamlProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  @yaml.yaml_profile_add_stage(profile, name, elapsed_ms, detail)
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
fn write_csv_profile_log_if_enabled(
  profile : @csv.CsvProfileReport?,
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
        input_stem(markdown_path) + ".csv.profile.log",
      )
      let lines : Array[String] = [
        @csv.csv_profile_render_report(rep),
        "csv_profile cli markdown_output=" + markdown_path,
        "csv_profile cli metadata_enabled=" + with_metadata.to_string(),
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
fn write_json_profile_log_if_enabled(
  profile : @json.JsonProfileReport?,
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
        input_stem(markdown_path) + ".json.profile.log",
      )
      let lines : Array[String] = [
        @json.json_profile_render_report(rep),
        "json_profile cli markdown_output=" + markdown_path,
        "json_profile cli metadata_enabled=" + with_metadata.to_string(),
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
fn write_txt_profile_log_if_enabled(
  profile : @txt.TxtProfileReport?,
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
        input_stem(markdown_path) + ".txt.profile.log",
      )
      let lines : Array[String] = [
        @txt.txt_profile_render_report(rep),
        "txt_profile cli markdown_output=" + markdown_path,
        "txt_profile cli metadata_enabled=" + with_metadata.to_string(),
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
fn write_yaml_profile_log_if_enabled(
  profile : @yaml.YamlProfileReport?,
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
        input_stem(markdown_path) + ".yaml.profile.log",
      )
      let lines : Array[String] = [
        @yaml.yaml_profile_render_report(rep),
        "yaml_profile cli markdown_output=" + markdown_path,
        "yaml_profile cli metadata_enabled=" + with_metadata.to_string(),
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

  let props = @cor.metadata_document_properties(
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
  )
  Some(
    @cor.metadata_document_properties_with_extras(
      props,
      meta.language,
      meta.identifier,
      meta.publisher,
    ),
  )
}

///|
pub fn detect_input_format(path : String) -> String {
  @clicom.detect_input_format(path)
}

///|
pub fn detect_ocr_image_format(path : String) -> String? {
  @clicom.detect_ocr_image_format(path)
}

///|
pub fn parse_ocr_lang_arg(raw : String?) -> Array[String] {
  @clicom.parse_ocr_lang_arg(raw)
}
