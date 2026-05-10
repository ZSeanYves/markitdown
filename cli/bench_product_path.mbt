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
  elapsed_us : Int64
  notes : String
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

  let parse_started = now_us()
  let parsed_result = @conv.parse_to_ir(opts.input, convert_opts) catch {
    e => raise Failed("parse failed: " + e.to_string())
  }
  let doc = match parsed_result {
    Ok(parsed) => parsed
    Err(err) => raise Failed("parse failed: " + err.to_string())
  }
  let parse_elapsed_us = elapsed_us_since(parse_started)
  rows.push({
    stage: "parse",
    elapsed_us: parse_elapsed_us,
    notes: hidden_bench_parse_stage_notes(
      format,
      doc.blocks.val.length(),
      opts.with_assets,
    ),
  })

  rows.push({
    stage: "convert",
    elapsed_us: 0,
    notes: "combined_in_parse_current_path=true",
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

  let asset_count = if opts.with_assets {
    count_hidden_bench_assets(join_path(opts.output_root, "assets"))
  } else {
    0
  }
  let asset_notes = if opts.with_assets {
    "embedded_in_parse_current_path=true asset_count=" + asset_count.to_string()
  } else {
    "skipped=assets_disabled"
  }
  rows.push({ stage: "assets", elapsed_us: 0, notes: asset_notes })

  rows.push({
    stage: "total",
    elapsed_us: elapsed_us_since(total_started),
    notes: "startup_excluded=true format=" + format,
  })

  rows
}

///|
fn hidden_bench_parse_stage_notes(
  format : String,
  block_count : Int,
  with_assets : Bool,
) -> String {
  let integrated = format == "txt" ||
    format == "json" ||
    format == "yaml" ||
    format == "csv" ||
    format == "tsv" ||
    format == "xlsx"
  let parse_kind = if integrated {
    "doc_parse_plus_convert"
  } else {
    "converter_local_combined_path"
  }
  let asset_mode = if with_assets { "materialized" } else { "disabled" }
  "format=" +
  format +
  " blocks=" +
  block_count.to_string() +
  " parse_kind=" +
  parse_kind +
  " includes_file_read=true combined_convert=true asset_mode=" +
  asset_mode
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
fn elapsed_us_since(started : Int64) -> Int64 {
  let now = now_us()
  if now <= started {
    0
  } else {
    now - started
  }
}
