///|
/// CLI conversion orchestration layer.
///
/// Responsibility split:
/// - parse/validate runtime IO choices (output file vs stdout, metadata switch)
/// - dispatch core product conversion in-process
/// - route PDF and ZIP through bundled product components when that keeps the
///   main CLI build closure under control
/// - emit markdown and metadata sidecar
/// - keep OCR decisions explicit and routed through `cli_ocr.mbt`
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
pub fn detect_input_format(path : String) -> String {
  @clicom.detect_input_format(path)
}
