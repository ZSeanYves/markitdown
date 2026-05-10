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
}

///|
async fn maybe_run_hidden_bench_command(args : Array[String]) -> Bool {
  if args.length() == 0 {
    return false
  }

  let command = args[0].trim().to_owned()
  if command == "_bench-noop" {
    return true
  }

  if command != "_bench-product-path" {
    return false
  }

  let forwarded : Array[String] = []
  for i in 1..<args.length() {
    forwarded.push(args[i])
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
  ensure_dir_tree(dirname_of_path(markdown_path)) catch {
    e => raise Failed("create markdown dir failed: " + e.to_string())
  }
  @fs.write_string_to_file(markdown_path, markdown, encoding="utf8") catch {
    e => raise Failed("write markdown failed: " + e.to_string())
  }
  rows.push({
    stage: "emit",
    elapsed_us: elapsed_us_since(emit_started),
    notes: "includes_markdown_write=true markdown_bytes=" +
    markdown.length().to_string(),
  })

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
    convert_notes: "split_from_profile=true lowering=txt_build_ir includes_passthrough_markdown=true includes_origin_blocks=true",
    assets_elapsed_us: 0,
    assets_notes: "skipped=assets_disabled",
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
