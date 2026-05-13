///|
priv suberror HiddenBenchError {
  Failed(String)
}

///|
priv struct HiddenBenchProductPathOptions {
  input : String
  output_root : String
  max_heading : Int
  with_metadata : Bool
  with_assets : Bool
}

///|
priv struct HiddenBenchStartupProfileOptions {
  branch : String
  input : String
  output : String
}

///|
priv struct HiddenBenchStageRow {
  stage : String
  elapsed_us : Int
  notes : String
}

///|
priv struct HiddenBenchParseResult {
  doc : @cor.Document
  parse_elapsed_us : Int
  parse_notes : String
  convert_elapsed_us : Int
  convert_notes : String
  assets_elapsed_us : Int
  assets_notes : String
  extra_rows : Array[HiddenBenchStageRow]
}

///|
async fn maybe_run_hidden_bench_command(
  args : Array[String],
  startup_profile_started : Int64,
  raw_arg_count : Int,
  args_available_us : Int,
  cli_args_ready_us : Int,
) -> Bool {
  if args.length() == 0 {
    return false
  }

  let command = args[0].trim().to_owned()
  if command == "_bench-noop" {
    return true
  }

  let forwarded : Array[String] = []
  for i in 1..<args.length() {
    forwarded.push(args[i])
  }

  if command == "_bench-startup-profile" {
    let opts = parse_hidden_bench_startup_profile_args(forwarded) catch {
      e => {
        exit_error("bench-startup-profile: " + hidden_bench_error_message(e))
        @sys.exit(2)
        return true
      }
    }

    let rows = run_hidden_bench_startup_profile(
      opts, startup_profile_started, raw_arg_count, args_available_us, cli_args_ready_us,
    ) catch {
      e => {
        exit_error("bench-startup-profile: " + hidden_bench_error_message(e))
        @sys.exit(1)
        return true
      }
    }

    print_hidden_bench_product_path_rows(rows)
    return true
  }

  if command != "_bench-product-path" {
    return false
  }

  let opts = parse_hidden_bench_product_path_args(forwarded) catch {
    e => {
      exit_error("bench-product-path: " + hidden_bench_error_message(e))
      @sys.exit(2)
      return true
    }
  }

  let rows = run_hidden_bench_product_path(opts) catch {
    e => {
      exit_error("bench-product-path: " + hidden_bench_error_message(e))
      @sys.exit(1)
      return true
    }
  }

  print_hidden_bench_product_path_rows(rows)
  true
}

///|
fn parse_hidden_bench_startup_profile_args(
  args : Array[String],
) -> HiddenBenchStartupProfileOptions raise HiddenBenchError {
  if args.length() == 0 {
    raise Failed("missing branch; expected noop, help, or normal_txt_small")
  }

  let branch = args[0].trim().to_owned()
  if branch == "noop" || branch == "help" {
    if args.length() != 1 {
      raise Failed(branch + " does not accept extra arguments")
    }
    return { branch, input: "", output: "" }
  }

  if branch != "normal_txt_small" {
    raise Failed("unknown startup-profile branch: " + branch)
  }

  let mut input = ""
  let mut output = ""
  let mut i = 1
  while i < args.length() {
    let arg = args[i].trim().to_owned()
    if arg == "--input" {
      i = hidden_bench_require_value(args, i, arg)
      input = args[i].trim().to_owned()
    } else if arg == "--output" {
      i = hidden_bench_require_value(args, i, arg)
      output = args[i].trim().to_owned()
    } else {
      raise Failed("unknown argument: " + arg)
    }
    i += 1
  }

  if input == "" {
    raise Failed("normal_txt_small requires --input")
  }
  if output == "" {
    raise Failed("normal_txt_small requires --output")
  }

  { branch, input, output }
}

///|
fn parse_hidden_bench_product_path_args(
  args : Array[String],
) -> HiddenBenchProductPathOptions raise HiddenBenchError {
  let mut input = ""
  let mut output_root = ""
  let mut max_heading = 6
  let mut with_metadata = false
  let mut with_assets = false
  let mut i = 0

  while i < args.length() {
    let arg = args[i].trim().to_owned()
    if arg == "--input" {
      i = hidden_bench_require_value(args, i, arg)
      input = args[i].trim().to_owned()
    } else if arg == "--output-root" {
      i = hidden_bench_require_value(args, i, arg)
      output_root = args[i].trim().to_owned()
    } else if arg == "--max-heading" {
      i = hidden_bench_require_value(args, i, arg)
      max_heading = hidden_bench_parse_positive_int(args[i], arg)
    } else if arg == "--with-metadata" {
      with_metadata = true
    } else if arg == "--with-assets" {
      with_assets = true
    } else {
      raise Failed("unknown argument: " + arg)
    }
    i += 1
  }

  if input == "" {
    raise Failed("missing --input")
  }
  if output_root == "" {
    raise Failed("missing --output-root")
  }

  { input, output_root, max_heading, with_metadata, with_assets }
}

///|
fn hidden_bench_require_value(
  args : Array[String],
  index : Int,
  flag : String,
) -> Int raise HiddenBenchError {
  if index + 1 >= args.length() {
    raise Failed("missing value for " + flag)
  }
  index + 1
}

///|
fn hidden_bench_parse_positive_int(
  raw : String,
  flag : String,
) -> Int raise HiddenBenchError {
  let parsed = @string.parse_int(raw) catch {
    _ => raise Failed("invalid integer for " + flag + ": " + raw)
  }
  if parsed <= 0 {
    raise Failed(flag + " must be > 0")
  }
  parsed
}

///|
async fn run_hidden_bench_startup_profile(
  opts : HiddenBenchStartupProfileOptions,
  startup_profile_started : Int64,
  raw_arg_count : Int,
  args_available_us : Int,
  cli_args_ready_us : Int,
) -> Array[HiddenBenchStageRow] raise HiddenBenchError {
  let rows : Array[HiddenBenchStageRow] = [
    { stage: "entered_main", elapsed_us: 0, notes: "branch=" + opts.branch },
    {
      stage: "args_available",
      elapsed_us: args_available_us,
      notes: "raw_arg_count=" + raw_arg_count.to_string(),
    },
    {
      stage: "cli_args_normalized",
      elapsed_us: cli_args_ready_us,
      notes: "normalized_arg_count=" +
      hidden_bench_startup_profile_arg_count(opts).to_string(),
    },
    {
      stage: "command_classified",
      elapsed_us: elapsed_us_since(startup_profile_started),
      notes: "hidden_command=_bench-startup-profile branch=" + opts.branch,
    },
  ]

  match opts.branch {
    "noop" => {
      let return_ready_us = elapsed_us_since(startup_profile_started)
      rows.push({
        stage: "noop_return_ready",
        elapsed_us: return_ready_us,
        notes: "parser_built=false output_emission=excluded",
      })
      rows.push({
        stage: "before_exit",
        elapsed_us: return_ready_us,
        notes: "branch=noop output_emission=excluded",
      })
      rows
    }
    "help" => {
      let parser = new_cli_parser()
      rows.push({
        stage: "help_parser_ready",
        elapsed_us: elapsed_us_since(startup_profile_started),
        notes: "subcommands=4",
      })
      let value = @clap.SimpleValue::new("markitdown-mb")
      let help_msg = parser.parse(value, ["--help"]) catch {
        e => raise Failed("help parse failed: " + e.to_string())
      }
      let rendered = match help_msg {
        Some(msg) => msg
        None => raise Failed("help parse returned no help message")
      }
      let ready_us = elapsed_us_since(startup_profile_started)
      rows.push({
        stage: "help_render_ready",
        elapsed_us: ready_us,
        notes: "help_bytes=" + rendered.length().to_string(),
      })
      rows.push({
        stage: "before_exit",
        elapsed_us: ready_us,
        notes: "branch=help output_emission=excluded",
      })
      rows
    }
    "normal_txt_small" => {
      let parser = new_cli_parser()
      rows.push({
        stage: "parser_ready",
        elapsed_us: elapsed_us_since(startup_profile_started),
        notes: "branch=normal_txt_small",
      })
      let value = @clap.SimpleValue::new("markitdown-mb")
      let parse_help = parser.parse(value, ["normal", opts.input, opts.output]) catch {
        e => raise Failed("normal_txt_small parse failed: " + e.to_string())
      }
      match parse_help {
        Some(_) =>
          raise Failed("normal_txt_small unexpectedly returned a help message")
        None => ()
      }
      let sub = match value.subcmd {
        Some(sub) => sub
        None => raise Failed("normal_txt_small expected a normal subcommand")
      }
      let positional = sub.positional_args
      let with_metadata = sub.get_flag("with-metadata").unwrap_or(false)
      if sub.name != "normal" {
        raise Failed("normal_txt_small resolved unexpected subcommand")
      }
      if positional.length() < 1 || positional.length() > 2 {
        raise Failed("normal_txt_small resolved unexpected positional count")
      }
      let input = positional[0]
      let output_opt = if positional.length() >= 2 {
        Some(positional[1])
      } else {
        None
      }
      rows.push({
        stage: "minimal_dispatch_ready",
        elapsed_us: elapsed_us_since(startup_profile_started),
        notes: "subcommand=normal positional_count=" +
        positional.length().to_string() +
        " with_metadata=" +
        hidden_bench_bool_name(with_metadata),
      })
      let convert_result = convert_once(
        input,
        output_opt,
        None,
        6,
        None,
        false,
        false,
        false,
        with_metadata,
      ) catch {
        e => raise Failed("normal_txt_small convert raised: " + e.to_string())
      }
      match convert_result {
        Ok(_) => ()
        Err(msg) => raise Failed("normal_txt_small convert failed: " + msg)
      }
      let total_us = elapsed_us_since(startup_profile_started)
      rows.push({
        stage: "convert_complete",
        elapsed_us: total_us,
        notes: "format=" +
        detect_input_format(input) +
        " output_written=true metadata=false",
      })
      rows.push({
        stage: "before_exit",
        elapsed_us: total_us,
        notes: "branch=normal_txt_small output_emission=excluded",
      })
      rows
    }
    _ => raise Failed("unknown startup-profile branch: " + opts.branch)
  }
}

///|
fn hidden_bench_startup_profile_arg_count(
  opts : HiddenBenchStartupProfileOptions,
) -> Int {
  match opts.branch {
    "noop" => 2
    "help" => 2
    "normal_txt_small" => 6
    _ => 0
  }
}

///|
async fn run_hidden_bench_product_path(
  opts : HiddenBenchProductPathOptions,
) -> Array[HiddenBenchStageRow] raise HiddenBenchError {
  ensure_dir_tree(opts.output_root) catch {
    e => raise Failed("create output root failed: " + e.to_string())
  }

  let markdown_path = join_path(
    opts.output_root,
    input_stem(opts.input) + ".md",
  )
  let rows : Array[HiddenBenchStageRow] = []

  let file_probe_started = now_us()
  let file_probe_bytes = @fs.read_file_to_bytes(opts.input) catch {
    e => raise Failed("file read probe failed: " + e.to_string())
  }
  rows.push({
    stage: "file_read",
    elapsed_us: elapsed_us_since(file_probe_started),
    notes: "standalone_probe=true bytes=" +
    file_probe_bytes.length().to_string(),
  })

  let total_started = now_us()

  let dispatch_started = now_us()
  let format = detect_input_format(opts.input)
  let dispatch_elapsed_us = elapsed_us_since(dispatch_started)
  if format == "unknown" {
    raise Failed("unsupported file type: " + opts.input)
  }
  rows.push({
    stage: "dispatch",
    elapsed_us: dispatch_elapsed_us,
    notes: "format=" + format,
  })

  let parse_out_dir = if opts.with_assets {
    Some(opts.output_root)
  } else {
    None
  }
  let convert_opts : @conv.ConvertOptions = {
    out_dir: parse_out_dir,
    max_heading: Some(opts.max_heading),
    pdf_enhance_mode: None,
    pdf_extract_debug: false,
    pdf_dump_selected_raw: false,
    pdf_pipeline_debug: false,
  }

  let parse_result = run_hidden_bench_parse_stage(format, opts, convert_opts) catch {
    e => raise Failed("parse failed: " + e.to_string())
  }
  let doc = parse_result.doc
  rows.push({
    stage: "parse",
    elapsed_us: parse_result.parse_elapsed_us,
    notes: parse_result.parse_notes,
  })

  rows.push({
    stage: "convert",
    elapsed_us: parse_result.convert_elapsed_us,
    notes: parse_result.convert_notes,
  })

  let emit_started = now_us()
  let markdown = @cor.emit_markdown(doc)
  let emit_render_elapsed_us = elapsed_us_since(emit_started)
  if format == "txt" {
    rows.push({
      stage: "txt_emit_blocks",
      elapsed_us: emit_render_elapsed_us,
      notes: "split=true includes_markdown_build=true",
    })
  }

  let emit_write_started = now_us()
  ensure_dir_tree(dirname_of_path(markdown_path)) catch {
    e => raise Failed("create markdown dir failed: " + e.to_string())
  }
  @fs.write_string_to_file(markdown_path, markdown, encoding="utf8") catch {
    e => raise Failed("write markdown failed: " + e.to_string())
  }
  let emit_write_elapsed_us = elapsed_us_since(emit_write_started)
  rows.push({
    stage: "emit",
    elapsed_us: emit_render_elapsed_us + emit_write_elapsed_us,
    notes: "includes_markdown_write=true markdown_bytes=" +
    markdown.length().to_string(),
  })
  if format == "txt" {
    rows.push({
      stage: "txt_emit_write",
      elapsed_us: emit_write_elapsed_us,
      notes: "split=true includes_markdown_write=true",
    })
  }

  if opts.with_metadata {
    let metadata_started = now_us()
    let document = read_document_properties(opts.input, format)
    let document_properties_available = match document {
      Some(_) => true
      None => false
    }
    let metadata_json = @cor.emit_metadata_json_with_document_properties(
      doc,
      @cor.basename(opts.input),
      format,
      @cor.basename(markdown_path),
      document,
    )
    let metadata_path = metadata_output_path(markdown_path)
    ensure_dir_tree(dirname_of_path(metadata_path)) catch {
      e => raise Failed("create metadata dir failed: " + e.to_string())
    }
    @fs.write_string_to_file(metadata_path, metadata_json, encoding="utf8") catch {
      e => raise Failed("write metadata failed: " + e.to_string())
    }
    rows.push({
      stage: "metadata",
      elapsed_us: elapsed_us_since(metadata_started),
      notes: "enabled=true metadata_bytes=" +
      metadata_json.length().to_string() +
      " document_properties=" +
      hidden_bench_bool_name(document_properties_available),
    })
  } else {
    rows.push({
      stage: "metadata",
      elapsed_us: 0,
      notes: "skipped=metadata_disabled",
    })
  }

  rows.push({
    stage: "assets",
    elapsed_us: parse_result.assets_elapsed_us,
    notes: parse_result.assets_notes,
  })

  for row in parse_result.extra_rows {
    rows.push(row)
  }

  rows.push({
    stage: "total",
    elapsed_us: elapsed_us_since(total_started),
    notes: "startup_excluded=true format=" + format,
  })

  rows
}

///|
async fn run_hidden_bench_parse_stage(
  format : String,
  opts : HiddenBenchProductPathOptions,
  convert_opts : @conv.ConvertOptions,
) -> HiddenBenchParseResult {
  match format {
    "txt" => hidden_bench_split_txt_parse(opts)
    "json" => hidden_bench_split_json_parse(opts)
    "yaml" => hidden_bench_split_yaml_parse(opts)
    "csv" => hidden_bench_split_csv_like_parse(opts, false)
    "tsv" => hidden_bench_split_csv_like_parse(opts, true)
    "xlsx" => hidden_bench_split_xlsx_parse(opts)
    "html" => hidden_bench_profiled_html_parse(opts)
    "pdf" => hidden_bench_profiled_pdf_parse(opts)
    "docx" => hidden_bench_profiled_docx_parse(opts)
    "pptx" => hidden_bench_profiled_pptx_parse(opts)
    _ => hidden_bench_combined_parse_stage(format, opts, convert_opts)
  }
}

///|
fn hidden_bench_combined_parse_stage_notes(
  format : String,
  block_count : Int,
  with_assets : Bool,
) -> String {
  let asset_mode = if with_assets { "materialized" } else { "disabled" }
  "format=" +
  format +
  " blocks=" +
  block_count.to_string() +
  " parse_kind=converter_local_combined_path includes_file_read=true combined_convert=true asset_mode=" +
  asset_mode
}

///|
async fn hidden_bench_combined_parse_stage(
  format : String,
  opts : HiddenBenchProductPathOptions,
  convert_opts : @conv.ConvertOptions,
) -> HiddenBenchParseResult {
  let parse_started = now_us()
  let parsed_result = @conv.parse_to_ir(opts.input, convert_opts) catch {
    e => raise Failed(e.to_string())
  }
  let doc = match parsed_result {
    Ok(parsed) => parsed
    Err(err) => raise Failed(err.to_string())
  }
  let parse_elapsed_us = elapsed_us_since(parse_started)
  let asset_count = if opts.with_assets {
    count_hidden_bench_assets(join_path(opts.output_root, "assets"))
  } else {
    0
  }
  {
    doc,
    parse_elapsed_us,
    parse_notes: hidden_bench_combined_parse_stage_notes(
      format,
      doc.blocks.val.length(),
      opts.with_assets,
    ) +
    hidden_bench_combined_split_reason(format),
    convert_elapsed_us: 0,
    convert_notes: hidden_bench_combined_convert_stage_notes(format),
    assets_elapsed_us: 0,
    assets_notes: hidden_bench_assets_stage_notes(
      format,
      opts.with_assets,
      asset_count,
    ),
    extra_rows: [],
  }
}

///|
fn hidden_bench_combined_split_reason(format : String) -> String {
  match format {
    "html" =>
      " split_blocked_by=dom_scan_block_lowering_and_asset_export_share_entrypoint"
    "docx" =>
      " split_blocked_by=package_rels_notes_assets_and_ir_scan_share_entrypoint"
    "pptx" =>
      " split_blocked_by=slide_parse_classification_and_image_export_share_entrypoint"
    _ =>
      " split_blocked_by=current_converter_entrypoint_combines_parse_and_convert"
  }
}

///|
fn hidden_bench_combined_convert_stage_notes(format : String) -> String {
  "combined_in_parse_current_path=true format=" +
  format +
  hidden_bench_combined_split_reason(format)
}

///|
fn hidden_bench_assets_stage_notes(
  format : String,
  with_assets : Bool,
  asset_count : Int,
) -> String {
  if !with_assets {
    return "skipped=assets_disabled"
  }

  match format {
    "html" =>
      "embedded_in_parse_current_path=true asset_count=" +
      asset_count.to_string() +
      " asset_discovery_boundary=nodes_to_blocks asset_export_boundary=export_local_html_image"
    "docx" =>
      "embedded_in_parse_current_path=true asset_count=" +
      asset_count.to_string() +
      " asset_discovery_boundary=build_docx_asset_path_map asset_export_boundary=extract_media_by_relationships"
    "pptx" =>
      "embedded_in_parse_current_path=true asset_count=" +
      asset_count.to_string() +
      " asset_discovery_boundary=collect_slide_picture_shape_metas+rels_image_target_map asset_export_boundary=export_slide_images"
    "pdf" =>
      "embedded_in_parse_current_path=false asset_count=" +
      asset_count.to_string() +
      " asset_discovery_boundary=export_convert_page_images asset_export_boundary=export_single_pdf_image text_pdf_only=true ocr_excluded=true"
    _ =>
      "embedded_in_parse_current_path=true asset_count=" +
      asset_count.to_string()
  }
}

///|
fn hidden_bench_split_txt_parse(
  opts : HiddenBenchProductPathOptions,
) -> HiddenBenchParseResult raise {
  let started = now_us()
  let (doc, report_opt) = @txt.parse_txt_with_profile(
    opts.input,
    "",
    opts.max_heading,
  )
  let total_elapsed_us = elapsed_us_since(started)
  let report = match report_opt {
    Some(rep) => rep
    None =>
      return hidden_bench_profile_missing_result(
        "txt", opts, doc, total_elapsed_us,
      )
  }

  let file_read_us = hidden_bench_txt_stage_us(report, "txt_file_read")
  let parse_us = hidden_bench_txt_stage_us(report, "txt_bytes_to_string") +
    hidden_bench_txt_stage_us(report, "txt_normalize_newlines") +
    hidden_bench_txt_stage_us(report, "txt_split_paragraphs")
  let literal_wrap_us = hidden_bench_txt_stage_us(report, "txt_literal_wrap")
  let origin_blocks_us = hidden_bench_txt_stage_us(report, "txt_origin_blocks")
  let convert_us = hidden_bench_txt_stage_us(report, "txt_build_ir")
  let gap_us = hidden_bench_residual_us(
    total_elapsed_us,
    file_read_us + parse_us + convert_us,
  )

  {
    doc,
    parse_elapsed_us: parse_us,
    parse_notes: "format=txt blocks=" +
    doc.blocks.val.length().to_string() +
    " parse_kind=doc_parse_text_model_split decode_included=true normalize_included=true file_read_probe_separate=true embedded_file_read_us=" +
    file_read_us.to_string() +
    " profile_gap_us=" +
    gap_us.to_string(),
    convert_elapsed_us: convert_us,
    convert_notes: "split_from_profile=true lowering=txt_build_ir includes_passthrough_markdown=true includes_origin_blocks=true literal_wrap_us=" +
    literal_wrap_us.to_string() +
    " origin_blocks_us=" +
    origin_blocks_us.to_string(),
    assets_elapsed_us: 0,
    assets_notes: "skipped=assets_disabled",
    extra_rows: [
      {
        stage: "txt_literal_wrap",
        elapsed_us: literal_wrap_us,
        notes: "split=true source=txt_build_ir",
      },
      {
        stage: "txt_lowering",
        elapsed_us: origin_blocks_us,
        notes: "split=true source=txt_build_ir origins_and_blocks_only=true",
      },
    ],
  }
}

///|
fn hidden_bench_split_json_parse(
  opts : HiddenBenchProductPathOptions,
) -> HiddenBenchParseResult raise {
  let started = now_us()
  let (doc, report_opt) = @json.parse_json_with_profile(
    opts.input,
    "",
    opts.max_heading,
  )
  let total_elapsed_us = elapsed_us_since(started)
  let report = match report_opt {
    Some(rep) => rep
    None =>
      return hidden_bench_profile_missing_result(
        "json", opts, doc, total_elapsed_us,
      )
  }

  let file_read_us = hidden_bench_json_stage_us(report, "json_file_read")
  let parse_us = hidden_bench_json_stage_us(report, "json_bytes_to_string") +
    hidden_bench_json_stage_us(report, "json_parse_total")
  let convert_us = hidden_bench_json_stage_us(report, "json_lower_to_ir")
  let gap_us = hidden_bench_residual_us(
    total_elapsed_us,
    file_read_us + parse_us + convert_us,
  )

  {
    doc,
    parse_elapsed_us: parse_us,
    parse_notes: "format=json blocks=" +
    doc.blocks.val.length().to_string() +
    " parse_kind=doc_parse_json_model_split decode_included=true file_read_probe_separate=true embedded_file_read_us=" +
    file_read_us.to_string() +
    " profile_gap_us=" +
    gap_us.to_string(),
    convert_elapsed_us: convert_us,
    convert_notes: "split_from_profile=true lowering=json_lower_to_ir table_detection_and_nested_stringify_are_internal_substages=true",
    assets_elapsed_us: 0,
    assets_notes: "skipped=assets_disabled",
    extra_rows: [],
  }
}

///|
fn hidden_bench_split_yaml_parse(
  opts : HiddenBenchProductPathOptions,
) -> HiddenBenchParseResult raise {
  let started = now_us()
  let (doc, report_opt) = @yaml.parse_yaml_with_profile(
    opts.input,
    "",
    opts.max_heading,
  )
  let total_elapsed_us = elapsed_us_since(started)
  let report = match report_opt {
    Some(rep) => rep
    None =>
      return hidden_bench_profile_missing_result(
        "yaml", opts, doc, total_elapsed_us,
      )
  }

  let file_read_us = hidden_bench_yaml_stage_us(report, "yaml_file_read")
  let bytes_to_string_us = hidden_bench_yaml_stage_us(
    report, "yaml_bytes_to_string",
  )
  let parse_model_total_us = hidden_bench_yaml_stage_us(
    report, "yaml_parse_model",
  )
  let convert_us = hidden_bench_yaml_stage_us(report, "yaml_to_ir")
  let parse_model_only_us = if parse_model_total_us > convert_us {
    parse_model_total_us - convert_us
  } else {
    0
  }
  let parse_us = bytes_to_string_us + parse_model_only_us
  let gap_us = hidden_bench_residual_us(
    total_elapsed_us,
    file_read_us + parse_us + convert_us,
  )

  {
    doc,
    parse_elapsed_us: parse_us,
    parse_notes: "format=yaml blocks=" +
    doc.blocks.val.length().to_string() +
    " parse_kind=doc_parse_yaml_model_split decode_included=true file_read_probe_separate=true embedded_file_read_us=" +
    file_read_us.to_string() +
    " parse_model_only_us=" +
    parse_model_only_us.to_string() +
    " profile_gap_us=" +
    gap_us.to_string() +
    " split_source=overlapping_profile_stage_derivation",
    convert_elapsed_us: convert_us,
    convert_notes: "split_from_profile=true lowering=yaml_to_ir note=yaml_parse_model_profile_stage_overlaps_lowering",
    assets_elapsed_us: 0,
    assets_notes: "skipped=assets_disabled",
    extra_rows: [],
  }
}

///|
fn hidden_bench_split_csv_like_parse(
  opts : HiddenBenchProductPathOptions,
  is_tsv : Bool,
) -> HiddenBenchParseResult raise {
  let format = if is_tsv { "tsv" } else { "csv" }
  let started = now_us()
  let (doc, report_opt) = if is_tsv {
    @csv.parse_tsv_with_profile(opts.input, "", opts.max_heading)
  } else {
    @csv.parse_csv_with_profile(opts.input, "", opts.max_heading)
  }
  let total_elapsed_us = elapsed_us_since(started)
  let report = match report_opt {
    Some(rep) => rep
    None =>
      return hidden_bench_profile_missing_result(
        format, opts, doc, total_elapsed_us,
      )
  }

  let file_read_us = hidden_bench_csv_stage_us(report, "csv_file_read")
  let parse_us = hidden_bench_csv_stage_us(report, "csv_bytes_to_string") +
    hidden_bench_csv_stage_us(report, "csv_parse_records")
  let convert_us = hidden_bench_csv_stage_us(report, "csv_to_rich_table")
  let gap_us = hidden_bench_residual_us(
    total_elapsed_us,
    file_read_us + parse_us + convert_us,
  )

  {
    doc,
    parse_elapsed_us: parse_us,
    parse_notes: "format=" +
    format +
    " blocks=" +
    doc.blocks.val.length().to_string() +
    " parse_kind=doc_parse_delimited_model_split decode_included=true file_read_probe_separate=true embedded_file_read_us=" +
    file_read_us.to_string() +
    " profile_gap_us=" +
    gap_us.to_string(),
    convert_elapsed_us: convert_us,
    convert_notes: "split_from_profile=true lowering=csv_to_rich_table format=" +
    format,
    assets_elapsed_us: 0,
    assets_notes: "skipped=assets_disabled",
    extra_rows: [],
  }
}

///|
fn hidden_bench_split_xlsx_parse(
  opts : HiddenBenchProductPathOptions,
) -> HiddenBenchParseResult raise {
  let started = now_us()
  let (doc, report_opt) = @xlsx.parse_xlsx_with_profile(
    opts.input,
    "",
    opts.max_heading,
  )
  let total_elapsed_us = elapsed_us_since(started)
  let report = match report_opt {
    Some(rep) => rep
    None =>
      return hidden_bench_profile_missing_result(
        "xlsx", opts, doc, total_elapsed_us,
      )
  }

  let parse_us = hidden_bench_xlsx_stage_us(report, "semantic_workbook_parse")
  let convert_us = hidden_bench_xlsx_stage_us(report, "ir_lowering")
  let gap_us = hidden_bench_residual_us(total_elapsed_us, parse_us + convert_us)

  {
    doc,
    parse_elapsed_us: parse_us,
    parse_notes: "format=xlsx blocks=" +
    doc.blocks.val.length().to_string() +
    " parse_kind=doc_parse_xlsx_semantic_split includes_package_open=true file_read_probe_separate=true profile_gap_us=" +
    gap_us.to_string(),
    convert_elapsed_us: convert_us,
    convert_notes: "split_from_profile=true lowering=ir_lowering source=semantic_workbook_model",
    assets_elapsed_us: 0,
    assets_notes: "skipped=assets_disabled",
    extra_rows: [],
  }
}

///|
fn hidden_bench_residual_us(total_us : Int, attributed_us : Int) -> Int {
  if total_us <= attributed_us {
    0
  } else {
    total_us - attributed_us
  }
}

///|
fn hidden_bench_profile_missing_result(
  format : String,
  opts : HiddenBenchProductPathOptions,
  doc : @cor.Document,
  total_elapsed_us : Int,
) -> HiddenBenchParseResult {
  let asset_count = if opts.with_assets {
    count_hidden_bench_assets(join_path(opts.output_root, "assets"))
  } else {
    0
  }
  {
    doc,
    parse_elapsed_us: total_elapsed_us,
    parse_notes: hidden_bench_combined_parse_stage_notes(
      format,
      doc.blocks.val.length(),
      opts.with_assets,
    ) +
    " split_blocked_by=profile_not_enabled",
    convert_elapsed_us: 0,
    convert_notes: "combined_in_parse_current_path=true format=" +
    format +
    " split_blocked_by=profile_not_enabled",
    assets_elapsed_us: 0,
    assets_notes: hidden_bench_assets_stage_notes(
      format,
      opts.with_assets,
      asset_count,
    ),
    extra_rows: [],
  }
}

///|
fn hidden_bench_stage_ms_to_us(elapsed_ms : UInt64) -> Int {
  elapsed_ms.to_int() * 1000
}

///|
fn hidden_bench_txt_stage_us(
  report : @txt.TxtProfileReport,
  name : String,
) -> Int {
  for stage in report.stages {
    if stage.name == name {
      return hidden_bench_stage_ms_to_us(stage.elapsed_ms)
    }
  }
  0
}

///|
fn hidden_bench_json_stage_us(
  report : @json.JsonProfileReport,
  name : String,
) -> Int {
  for stage in report.stages {
    if stage.name == name {
      return hidden_bench_stage_ms_to_us(stage.elapsed_ms)
    }
  }
  0
}

///|
fn hidden_bench_yaml_stage_us(
  report : @yaml.YamlProfileReport,
  name : String,
) -> Int {
  for stage in report.stages {
    if stage.name == name {
      return hidden_bench_stage_ms_to_us(stage.elapsed_ms)
    }
  }
  0
}

///|
fn hidden_bench_csv_stage_us(
  report : @csv.CsvProfileReport,
  name : String,
) -> Int {
  for stage in report.stages {
    if stage.name == name {
      return hidden_bench_stage_ms_to_us(stage.elapsed_ms)
    }
  }
  0
}

///|
fn hidden_bench_xlsx_stage_us(
  report : @xlsx.XlsxProfileReport,
  name : String,
) -> Int {
  for stage in report.stages {
    if stage.name == name {
      return hidden_bench_stage_ms_to_us(stage.elapsed_ms)
    }
  }
  0
}

///|
fn hidden_bench_profile_file_stage_map(
  path : String,
  prefix : String,
) -> (Map[String, Int], String) {
  if !@fs.path_exists(path) {
    return (Map([]), "")
  }
  let text = @fs.read_file_to_string(path, encoding="utf8") catch {
    _ => return (Map([]), "")
  }
  let stage_us : Map[String, Int] = Map([])
  let mut summary_notes = ""
  for raw_line in text.split("\n") {
    let line = raw_line.trim().to_owned()
    if line == "" {
      continue
    }
    if line.has_prefix(prefix + " summary ") {
      summary_notes = hidden_bench_profile_summary_notes(line)
      continue
    }
    if !line.has_prefix(prefix + " stage=") {
      continue
    }
    let name = hidden_bench_profile_field_value(line, "stage").unwrap_or("")
    let elapsed_ms_raw = hidden_bench_profile_field_value(line, "elapsed_ms").unwrap_or(
      "",
    )
    let elapsed_ms = @string.parse_int(elapsed_ms_raw) catch { _ => 0 }
    if name != "" {
      stage_us.set(name, stage_us.get(name).unwrap_or(0) + elapsed_ms * 1000)
    }
  }
  (stage_us, summary_notes)
}

///|
fn hidden_bench_profile_summary_notes(line : String) -> String {
  let out : Array[String] = []
  for token in line.split(" ") {
    let trimmed = token.trim().to_owned()
    if trimmed == "" ||
      trimmed == "summary" ||
      trimmed.has_prefix("stages=") ||
      trimmed.has_prefix("total_elapsed_ms=") {
      continue
    }
    out.push(trimmed)
  }
  out.join(" ")
}

///|
fn hidden_bench_profile_field_value(line : String, key : String) -> String? {
  let prefix = key + "="
  for token in line.split(" ") {
    let trimmed = token.trim().to_owned()
    if trimmed.has_prefix(prefix) {
      return Some(trimmed[prefix.length():].to_owned())
    }
  }
  None
}

///|
fn hidden_bench_stage_map_us(stage_us : Map[String, Int], name : String) -> Int {
  stage_us.get(name).unwrap_or(0)
}

///|
fn hidden_bench_profiled_html_parse(
  opts : HiddenBenchProductPathOptions,
) -> HiddenBenchParseResult raise {
  let profile_path = join_path(opts.output_root, ".html.profile.log")
  if @fs.path_exists(profile_path) {
    @fs.remove_file(profile_path) catch {
      _ => ()
    }
  }
  let started = now_us()
  let doc = @html.parse_html(opts.input, opts.output_root, opts.max_heading)
  let total_elapsed_us = elapsed_us_since(started)
  let (stage_us, summary_notes) = hidden_bench_profile_file_stage_map(
    profile_path, "html_profile",
  )
  if stage_us.length() == 0 {
    return hidden_bench_profile_missing_result(
      "html", opts, doc, total_elapsed_us,
    )
  }

  let parse_us = hidden_bench_stage_map_us(stage_us, "html_file_read") +
    hidden_bench_stage_map_us(stage_us, "html_normalize_bytes") +
    hidden_bench_stage_map_us(stage_us, "html_dom_scan")
  let convert_us = hidden_bench_stage_map_us(stage_us, "html_block_lowering") +
    hidden_bench_stage_map_us(stage_us, "html_document_build")
  let assets_us = hidden_bench_stage_map_us(stage_us, "html_asset_discovery") +
    hidden_bench_stage_map_us(stage_us, "html_asset_export")
  let extra_rows : Array[HiddenBenchStageRow] = [
    {
      stage: "html_dom_scan",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "html_dom_scan"),
      notes: "split=true",
    },
    {
      stage: "html_block_lowering",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "html_block_lowering"),
      notes: "split=true",
    },
    {
      stage: "html_asset_discovery",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "html_asset_discovery"),
      notes: "split=true " + summary_notes,
    },
    {
      stage: "html_asset_export",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "html_asset_export"),
      notes: "split=true " + summary_notes,
    },
  ]

  {
    doc,
    parse_elapsed_us: parse_us,
    parse_notes: "format=html blocks=" +
    doc.blocks.val.length().to_string() +
    " parse_kind=converter_profiled_dom_split split=true " +
    summary_notes,
    convert_elapsed_us: convert_us,
    convert_notes: "split_from_profile=true lowering=html_block_lowering_and_document_build",
    assets_elapsed_us: assets_us,
    assets_notes: "asset_discovery_only=false embedded_in_parse_current_path=false " +
    summary_notes +
    " asset_discovery_boundary=nodes_to_blocks asset_export_boundary=export_local_html_image",
    extra_rows,
  }
}

///|
async fn hidden_bench_profiled_pdf_parse(
  opts : HiddenBenchProductPathOptions,
) -> HiddenBenchParseResult {
  let profile_path = join_path(opts.output_root, ".pdf.profile.log")
  if @fs.path_exists(profile_path) {
    @fs.remove_file(profile_path) catch {
      _ => ()
    }
  }
  let parse_started = now_us()
  let doc = @pdfconv.parse_pdf(
    opts.input,
    if opts.with_assets {
      opts.output_root
    } else {
      ""
    },
    opts.max_heading,
    None,
    false,
    false,
    false,
  )
  let total_elapsed_us = elapsed_us_since(parse_started)
  let (stage_us, summary_notes) = hidden_bench_profile_file_stage_map(
    profile_path, "pdf_convert_profile",
  )
  if stage_us.length() == 0 {
    return hidden_bench_profile_missing_result(
      "pdf", opts, doc, total_elapsed_us,
    )
  }

  let parse_us = hidden_bench_stage_map_us(stage_us, "pdf_backend_select") +
    hidden_bench_stage_map_us(stage_us, "pdf_extract_model") +
    hidden_bench_stage_map_us(stage_us, "pdf_line_build") +
    hidden_bench_stage_map_us(stage_us, "pdf_block_build")
  let convert_us = hidden_bench_stage_map_us(stage_us, "pdf_block_classify") +
    hidden_bench_stage_map_us(stage_us, "pdf_noise_filter") +
    hidden_bench_stage_map_us(stage_us, "pdf_merge") +
    hidden_bench_stage_map_us(stage_us, "pdf_annotation_handling") +
    hidden_bench_stage_map_us(stage_us, "pdf_final_block_build")
  let assets_us = 0
  let extra_rows : Array[HiddenBenchStageRow] = [
    {
      stage: "pdf_backend_select",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pdf_backend_select"),
      notes: "split=true text_pdf_only=true ocr_excluded=true",
    },
    {
      stage: "pdf_extract_model",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pdf_extract_model"),
      notes: "split=true native_text_pdf_only=true raw_extract_and_model_build_combined=true " +
      summary_notes,
    },
    {
      stage: "pdf_line_build",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pdf_line_build"),
      notes: "split=true source=build_convert_lines",
    },
    {
      stage: "pdf_block_build",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pdf_block_build"),
      notes: "split=true source=build_convert_blocks",
    },
    {
      stage: "pdf_block_classify",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pdf_block_classify"),
      notes: "split=true source=classify_convert_blocks",
    },
    {
      stage: "pdf_noise_filter",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pdf_noise_filter"),
      notes: "split=true source=filter_noise_blocks",
    },
    {
      stage: "pdf_merge",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pdf_merge"),
      notes: "split=true source=merge_convert_blocks",
    },
    {
      stage: "pdf_annotation_handling",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pdf_annotation_handling"),
      notes: "split=true source=attach_high_confidence_uri_links",
    },
    {
      stage: "pdf_final_block_build",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pdf_final_block_build"),
      notes: "split=true source=convert_pdf_blocks_to_ir",
    },
  ]

  {
    doc,
    parse_elapsed_us: parse_us,
    parse_notes: "format=pdf blocks=" +
    doc.blocks.val.length().to_string() +
    " parse_kind=native_text_pdf_split text_pdf_only=true ocr_excluded=true fallback_not_exercised=true " +
    summary_notes,
    convert_elapsed_us: convert_us,
    convert_notes: "split_from_profile=true lowering=pdf_block_classify+noise_filter+merge+annotation_handling+final_block_build text_pdf_only=true",
    assets_elapsed_us: assets_us,
    assets_notes: "skipped=no_pdf_asset_export_in_checked_sample text_pdf_only=true ocr_excluded=true",
    extra_rows,
  }
}

///|
fn hidden_bench_profiled_docx_parse(
  opts : HiddenBenchProductPathOptions,
) -> HiddenBenchParseResult raise {
  let profile_path = join_path(opts.output_root, ".docx.profile.log")
  if @fs.path_exists(profile_path) {
    @fs.remove_file(profile_path) catch {
      _ => ()
    }
  }
  let started = now_us()
  let doc = @docx.parse_docx(opts.input, opts.output_root, opts.max_heading)
  let total_elapsed_us = elapsed_us_since(started)
  let (stage_us, summary_notes) = hidden_bench_profile_file_stage_map(
    profile_path, "docx_convert_profile",
  )
  if stage_us.length() == 0 {
    return hidden_bench_profile_missing_result(
      "docx", opts, doc, total_elapsed_us,
    )
  }

  let parse_us = hidden_bench_stage_map_us(stage_us, "docx_package_open") +
    hidden_bench_stage_map_us(stage_us, "docx_document_xml") +
    hidden_bench_stage_map_us(stage_us, "docx_relationships") +
    hidden_bench_stage_map_us(stage_us, "docx_styles") +
    hidden_bench_stage_map_us(stage_us, "docx_numbering") +
    hidden_bench_stage_map_us(stage_us, "docx_notes") +
    hidden_bench_stage_map_us(stage_us, "docx_headers_footers") +
    hidden_bench_stage_map_us(stage_us, "docx_text_boxes") +
    hidden_bench_stage_map_us(stage_us, "docx_body_scan")
  let convert_us = hidden_bench_stage_map_us(stage_us, "docx_final_block_build") +
    hidden_bench_stage_map_us(stage_us, "docx_appended_sections")
  let assets_us = hidden_bench_stage_map_us(stage_us, "docx_asset_map_build") +
    hidden_bench_stage_map_us(stage_us, "docx_media_export") +
    hidden_bench_stage_map_us(stage_us, "docx_asset_origin_attach")
  let parse_only_us = if parse_us > convert_us {
    parse_us - convert_us
  } else {
    0
  }

  let extra_rows : Array[HiddenBenchStageRow] = [
    {
      stage: "docx_package_open",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_package_open"),
      notes: "split=true",
    },
    {
      stage: "docx_relationships",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_relationships"),
      notes: "split=true",
    },
    {
      stage: "docx_styles",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_styles"),
      notes: "split=true style_load_gated_by_document_features=true",
    },
    {
      stage: "docx_numbering",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_numbering"),
      notes: "split=true",
    },
    {
      stage: "docx_rels_styles_numbering",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_relationships") +
      hidden_bench_stage_map_us(stage_us, "docx_styles") +
      hidden_bench_stage_map_us(stage_us, "docx_numbering"),
      notes: "split=true combined_rels_styles_numbering=true",
    },
    {
      stage: "docx_notes",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_notes"),
      notes: "split=true raw_note_bundle_load=true",
    },
    {
      stage: "docx_headers_footers",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_headers_footers"),
      notes: "split=true includes_embedded_media_export_when_assets_enabled=true",
    },
    {
      stage: "docx_text_boxes",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_text_boxes"),
      notes: "split=true includes_embedded_asset_map_seed_build=true",
    },
    {
      stage: "docx_notes_headers_footers_textboxes",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_notes") +
      hidden_bench_stage_map_us(stage_us, "docx_headers_footers") +
      hidden_bench_stage_map_us(stage_us, "docx_text_boxes"),
      notes: "split=true combined_notes_header_footer_textbox=true",
    },
    {
      stage: "docx_asset_map_build",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_asset_map_build"),
      notes: "split=true scope=main_document_only",
    },
    {
      stage: "docx_media_export",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_media_export"),
      notes: "split=true scope=main_document_only",
    },
    {
      stage: "docx_asset_origin_attach",
      elapsed_us: hidden_bench_stage_map_us(
        stage_us, "docx_asset_origin_attach",
      ),
      notes: "split=true asset_origin_metadata_and_path_binding=true",
    },
    {
      stage: "docx_body_xml_scan",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_body_xml_scan"),
      notes: "split=true residual_top_level_body_traversal=true",
    },
    {
      stage: "docx_paragraph_scan",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_paragraph_scan"),
      notes: "split=true includes_heading_list_codeblock_blockquote_and_image_policy=true",
    },
    {
      stage: "docx_table_scan",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_table_scan"),
      notes: "split=true includes_cell_paragraph_and_inline_scan=true",
    },
    {
      stage: "docx_inline_scan",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_inline_scan"),
      notes: "split=true nested_in=docx_paragraph_scan,docx_table_scan",
    },
    {
      stage: "docx_body_scan",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_body_scan"),
      notes: "split=true",
    },
    {
      stage: "docx_final_block_build",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_final_block_build"),
      notes: "split=true partial_lowering_visible=true paragraph_policy_still_embedded_upstream=true",
    },
    {
      stage: "docx_appended_sections",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "docx_appended_sections"),
      notes: "split=true includes_footnotes_endnotes_comments_headers_footers_textboxes=true",
    },
  ]

  {
    doc,
    parse_elapsed_us: parse_only_us,
    parse_notes: "format=docx blocks=" +
    doc.blocks.val.length().to_string() +
    " parse_kind=converter_profiled_partial_split body_scan_substaged=true partial_convert_extracted_from_body_scan=true " +
    summary_notes,
    convert_elapsed_us: convert_us,
    convert_notes: "partial_split=true format=docx extracted_from_body_scan=true split_blocked_by=paragraph_policy_and_ir_block_shape_still_mixed_in_scan_paragraph final_block_build_us=" +
    hidden_bench_stage_map_us(stage_us, "docx_final_block_build").to_string() +
    " appended_sections_us=" +
    hidden_bench_stage_map_us(stage_us, "docx_appended_sections").to_string(),
    assets_elapsed_us: assets_us,
    assets_notes: "asset_discovery_only=false embedded_in_parse_current_path=false " +
    summary_notes +
    " asset_discovery_boundary=build_docx_asset_path_map asset_export_boundary=extract_media_by_relationships",
    extra_rows,
  }
}

///|
fn hidden_bench_profiled_pptx_parse(
  opts : HiddenBenchProductPathOptions,
) -> HiddenBenchParseResult raise {
  let profile_path = join_path(opts.output_root, ".pptx.profile.log")
  if @fs.path_exists(profile_path) {
    @fs.remove_file(profile_path) catch {
      _ => ()
    }
  }
  let started = now_us()
  let doc = @pptx.parse_pptx(opts.input, opts.output_root, opts.max_heading)
  let total_elapsed_us = elapsed_us_since(started)
  let (stage_us, summary_notes) = hidden_bench_profile_file_stage_map(
    profile_path, "pptx_convert_profile",
  )
  if stage_us.length() == 0 {
    return hidden_bench_profile_missing_result(
      "pptx", opts, doc, total_elapsed_us,
    )
  }

  let parse_us = hidden_bench_stage_map_us(stage_us, "pptx_package_open") +
    hidden_bench_stage_map_us(stage_us, "pptx_presentation_rels") +
    hidden_bench_stage_map_us(stage_us, "pptx_slide_parse") +
    hidden_bench_stage_map_us(stage_us, "pptx_slide_relationships") +
    hidden_bench_stage_map_us(stage_us, "pptx_shape_collect") +
    hidden_bench_stage_map_us(stage_us, "pptx_text_extract") +
    hidden_bench_stage_map_us(stage_us, "pptx_table_extract") +
    hidden_bench_stage_map_us(stage_us, "pptx_notes_parse")
  let convert_us = hidden_bench_stage_map_us(stage_us, "pptx_reading_order") +
    hidden_bench_stage_map_us(stage_us, "pptx_classification") +
    hidden_bench_stage_map_us(stage_us, "pptx_caption_pairing") +
    hidden_bench_stage_map_us(stage_us, "pptx_final_block_build")
  let assets_us = hidden_bench_stage_map_us(stage_us, "pptx_image_inventory") +
    hidden_bench_stage_map_us(stage_us, "pptx_image_export") +
    hidden_bench_stage_map_us(stage_us, "pptx_asset_origin_attach")

  let extra_rows : Array[HiddenBenchStageRow] = [
    {
      stage: "pptx_package_open",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pptx_package_open"),
      notes: "split=true",
    },
    {
      stage: "pptx_presentation_rels",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pptx_presentation_rels"),
      notes: "split=true includes_slide_order_and_hidden_flags=true",
    },
    {
      stage: "pptx_slide_parse",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pptx_slide_parse"),
      notes: "split=true",
    },
    {
      stage: "pptx_slide_relationships",
      elapsed_us: hidden_bench_stage_map_us(
        stage_us, "pptx_slide_relationships",
      ),
      notes: "split=true",
    },
    {
      stage: "pptx_shape_collect",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pptx_shape_collect"),
      notes: "split=true",
    },
    {
      stage: "pptx_text_extract",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pptx_text_extract"),
      notes: "split=true",
    },
    {
      stage: "pptx_table_extract",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pptx_table_extract"),
      notes: "split=true",
    },
    {
      stage: "pptx_reading_order",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pptx_reading_order"),
      notes: "split=true includes_layout_recovery=true",
    },
    {
      stage: "pptx_grouping",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pptx_grouping"),
      notes: "split=true subset_of=pptx_reading_order",
    },
    {
      stage: "pptx_classification",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pptx_classification"),
      notes: "split=true includes_notes_block_classification=true",
    },
    {
      stage: "pptx_caption_pairing",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pptx_caption_pairing"),
      notes: "split=true",
    },
    {
      stage: "pptx_image_inventory",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pptx_image_inventory"),
      notes: "split=true asset_discovery_only=true",
    },
    {
      stage: "pptx_image_export",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pptx_image_export"),
      notes: "split=true",
    },
    {
      stage: "pptx_asset_origin_attach",
      elapsed_us: hidden_bench_stage_map_us(
        stage_us, "pptx_asset_origin_attach",
      ),
      notes: "split=true",
    },
    {
      stage: "pptx_notes_parse",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pptx_notes_parse"),
      notes: "split=true",
    },
    {
      stage: "pptx_final_block_build",
      elapsed_us: hidden_bench_stage_map_us(stage_us, "pptx_final_block_build"),
      notes: "split=true includes_speaker_notes_section=true",
    },
  ]

  {
    doc,
    parse_elapsed_us: parse_us,
    parse_notes: "format=pptx blocks=" +
    doc.blocks.val.length().to_string() +
    " parse_kind=converter_profiled_partial_split text_and_table_extract_split=true " +
    summary_notes,
    convert_elapsed_us: convert_us,
    convert_notes: "split_from_profile=true lowering=reading_order_grouping_classification_caption_and_document_build grouping_subset_of_reading_order=true split_blocked_by=document_build_and_policy_still_share_current_slide_loop",
    assets_elapsed_us: assets_us,
    assets_notes: "asset_discovery_only=false embedded_in_parse_current_path=false " +
    summary_notes +
    " asset_discovery_boundary=collect_slide_picture_shape_metas+rels_image_target_map asset_export_boundary=export_slide_images asset_metadata_attach_boundary=set_asset_origin",
    extra_rows,
  }
}

///|
fn count_hidden_bench_assets(path : String) -> Int {
  if !@fs.path_exists(path) {
    return 0
  }
  let names = @fs.read_dir(path) catch { _ => return 0 }
  let mut count = 0
  for name in names {
    let child = join_path(path, name)
    if (@fs.is_dir(child) catch { _ => false }) {
      count += count_hidden_bench_assets(child)
    } else if (@fs.is_file(child) catch { _ => false }) {
      count += 1
    }
  }
  count
}

///|
fn hidden_bench_error_message(err : HiddenBenchError) -> String {
  match err {
    Failed(msg) => msg
  }
}

///|
fn hidden_bench_bool_name(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn print_hidden_bench_product_path_rows(
  rows : Array[HiddenBenchStageRow],
) -> Unit {
  println("stage\telapsed_us\tnotes")
  for row in rows {
    println(
      row.stage +
      "\t" +
      row.elapsed_us.to_string() +
      "\t" +
      sanitize_hidden_bench_note(row.notes),
    )
  }
}

///|
fn sanitize_hidden_bench_note(note : String) -> String {
  note
  .replace(old="\t", new=" ")
  .replace(old="\r", new=" ")
  .replace(old="\n", new=" ")
  .trim()
  .to_owned()
}

///|
fn elapsed_us_since(started : Int64) -> Int {
  let now = now_us()
  if now <= started {
    0
  } else {
    (now - started).to_int()
  }
}
