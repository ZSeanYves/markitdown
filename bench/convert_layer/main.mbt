///|
// BENCH_TOOL_NOT_CONVERT_RUNTIME: convert-layer benchmark tool, not product runtime.
suberror BenchError {
  Failed(String)
}

///|
fn bench_error_message(e : BenchError) -> String {
  match e {
    Failed(msg) => msg
  }
}

///|
struct BenchConfig {
  manifest : String
  output : String
  iterations : Int
  warmup : Int
  formats : Array[String]
  profile : String
  debug_select : Bool
}

///|
struct ManifestRow {
  format : String
  path : String
  label : String
  size_class : String
  source_group : String
  bench_profile : String
  workload_tags : String
}

///|
struct DebugManifestRow {
  bench_id : String
  format : String
  enabled_tier : String
  bench_layers : String
}

///|
struct BenchRunRow {
  layer : String
  format : String
  sample : String
  size_class : String
  stage : String
  iteration : Int
  elapsed_ms : Int64
  input_bytes : Int
  blocks : Int
  asset_count : Int
  exit_status : Int
  notes : String
}

///|
struct BenchSummaryRow {
  layer : String
  format : String
  sample : String
  size_class : String
  stage : String
  iterations : Int
  failed : Int
  min_ms : Int64
  p50_ms : Int64
  p95_ms : Int64
  max_ms : Int64
  avg_ms : Int64
  input_bytes : Int
  blocks_last : Int
  asset_count_last : Int
  runner_kind : String
  notes : String
}

///|
async fn main {
  run_bench(normalize_cli_args(@sys.get_cli_args())) catch {
    e => {
      println("convert layer bench failed: " + bench_error_message(e))
      @sys.exit(1)
    }
  }
}

///|
fn normalize_cli_args(args : Array[String]) -> Array[String] {
  if args.length() == 0 {
    return args
  }
  if args[0].has_prefix("-") {
    return args
  }
  let out : Array[String] = []
  for i in 1..<args.length() {
    out.push(args[i])
  }
  out
}

///|
async fn run_bench(args : Array[String]) -> Unit raise BenchError {
  let cfg = parse_args(args)
  if cfg.debug_select {
    debug_select_rows(cfg)
    return
  }
  let rows = read_manifest(cfg.manifest)
  let filtered = selected_rows(rows, cfg.formats)
  if filtered.length() == 0 {
    raise Failed(
      "no enabled convert benchmark rows selected from external_bench; check enabled_tier, bench_layers, format, or filters",
    )
  }

  let runs : Array[BenchRunRow] = []
  for row in filtered {
    bench_convert_row(row, cfg, runs)
  }
  if runs.length() == 0 {
    raise Failed(
      "no enabled convert benchmark rows selected from external_bench; check enabled_tier, bench_layers, format, or filters",
    )
  }

  let summaries = summarize_runs(runs)
  let output_dir = parent_dir(cfg.output)
  ensure_dir_tree(output_dir)
  let runs_output = raw_output_path(cfg.output)
  write_utf8_text(cfg.output, render_summary_tsv(summaries))
  write_utf8_text(runs_output, render_runs_tsv(runs))

  println("convert layer benchmark completed")
  println("manifest: " + cfg.manifest)
  println("summary: " + cfg.output)
  println("raw runs: " + runs_output)
  println("rows: " + summaries.length().to_string())
}

///|
fn parse_args(args : Array[String]) -> BenchConfig raise BenchError {
  let mut manifest = ""
  let mut output = ".tmp/bench/convert/summary.tsv"
  let mut iterations = 10
  let mut warmup = 2
  let mut formats : Array[String] = []
  let mut profile = ""
  let mut debug_select = false
  let mut i = 0

  while i < args.length() {
    let arg = args[i]
    if arg == "--manifest" {
      i = require_value(args, i, arg)
      manifest = args[i]
    } else if arg == "--layer" {
      i = require_value(args, i, arg)
      let layer = args[i].trim().to_owned().to_lower()
      if layer != "convert" {
        raise Failed("convert layer runner only supports --layer convert")
      }
    } else if arg == "--output" {
      i = require_value(args, i, arg)
      output = args[i]
    } else if arg == "--iterations" {
      i = require_value(args, i, arg)
      iterations = parse_positive_int(args[i], arg)
    } else if arg == "--warmup" {
      i = require_value(args, i, arg)
      warmup = parse_non_negative_int(args[i], arg)
    } else if arg == "--format" {
      i = require_value(args, i, arg)
      formats = split_required_format_arg(args[i])
    } else if arg == "--profile" {
      i = require_value(args, i, arg)
      profile = args[i].trim().to_owned().to_lower()
    } else if arg == "--debug-select" {
      debug_select = true
    } else if arg == "-h" || arg == "--help" {
      print_usage()
      @sys.exit(0)
    } else {
      raise Failed("unknown argument: " + arg)
    }
    i += 1
  }

  if manifest == "" {
    raise Failed(
      "external benchmark corpus is required; pass --manifest <path> or set MARKITDOWN_BENCH_LAB / MARKITDOWN_QUALITY_LAB; fetch or prepare markitdown-quality-lab/external_bench first.",
    )
  }
  { manifest, output, iterations, warmup, formats, profile, debug_select }
}

///|
fn print_usage() -> Unit {
  println(
    "usage: ./samples/helpers/bench/bench_convert_layer.sh [--layer convert] [--manifest PATH] [--format csv,json,...] [--iterations N] [--warmup N] [--profile PROFILE] [--output PATH] [--debug-select]\n\nexternal benchmark corpus is required; pass --manifest <path> or set MARKITDOWN_BENCH_LAB / MARKITDOWN_QUALITY_LAB; fetch or prepare markitdown-quality-lab/external_bench first.",
  )
}

///|
fn require_value(
  args : Array[String],
  index : Int,
  flag : String,
) -> Int raise BenchError {
  if index + 1 >= args.length() {
    raise Failed("missing value for " + flag)
  }
  index + 1
}

///|
fn parse_positive_int(raw : String, flag : String) -> Int raise BenchError {
  let value = parse_non_negative_int(raw, flag)
  if value <= 0 {
    raise Failed(flag + " must be > 0")
  }
  value
}

///|
fn parse_non_negative_int(raw : String, flag : String) -> Int raise BenchError {
  @string.parse_int(raw) catch {
    _ => raise Failed("invalid integer for " + flag + ": " + raw)
  }
}

///|
fn split_required_format_arg(raw : String) -> Array[String] raise BenchError {
  let tokens = @benchshared.split_tokens(raw)
  if tokens.length() == 0 {
    raise Failed("--format has no non-empty tokens")
  }
  tokens
}

///|
fn selected_rows(
  rows : Array[ManifestRow],
  formats : Array[String],
) -> Array[ManifestRow] {
  let out : Array[ManifestRow] = []
  for row in rows {
    if formats.length() > 0 && !contains_string(formats, row.format) {
      continue
    }
    out.push(row)
  }
  out
}

///|
fn debug_select_rows(cfg : BenchConfig) -> Unit raise BenchError {
  let text = read_utf8_text(cfg.manifest)
  let shared_rows = read_manifest_from_text(text, parent_dir(cfg.manifest))
  let selected_ids : Array[String] = []
  for row in shared_rows {
    if format_allowed(row.format, cfg.formats) {
      selected_ids.push(row.label)
    }
  }

  println("manifest\t" + cfg.manifest)
  println("requested_layer\tconvert")
  println("format_filter\t" + render_format_filter(cfg.formats))
  println("bench_id\tformat\tenabled_tier\tbench_layers\tselection")
  for row in parse_debug_manifest_rows(text) {
    println(
      row.bench_id +
      "\t" +
      row.format +
      "\t" +
      row.enabled_tier +
      "\t" +
      row.bench_layers +
      "\t" +
      debug_selection_reason(row, cfg.formats, selected_ids),
    )
  }
  println("selected_count\t" + selected_ids.length().to_string())
}

///|
fn debug_selection_reason(
  row : DebugManifestRow,
  formats : Array[String],
  selected_ids : Array[String],
) -> String {
  let tier = row.enabled_tier.trim().to_owned().to_lower()
  if tier == "" ||
    tier == "disabled" ||
    tier == "pending_review" ||
    tier == "unknown" {
    let rendered = if tier == "" { "<empty>" } else { tier }
    return "skip:enabled_tier=" + rendered
  }
  if tier != "smoke" && tier != "full" && tier != "manual" {
    return "skip:unsupported_enabled_tier=" + tier
  }
  if !@benchshared.list_contains_token(row.bench_layers, "convert") {
    return "skip:bench_layers"
  }
  if !format_allowed(row.format, formats) {
    return "skip:format"
  }
  if contains_string(selected_ids, row.bench_id) {
    "selected"
  } else {
    "skip:shared_parser_excluded"
  }
}

///|
fn render_format_filter(formats : Array[String]) -> String {
  if formats.length() == 0 {
    "(all)"
  } else {
    formats.join(",")
  }
}

///|
fn format_allowed(format : String, formats : Array[String]) -> Bool {
  formats.length() == 0 || contains_string(formats, format)
}

///|
fn parse_debug_manifest_rows(
  text : String,
) -> Array[DebugManifestRow] raise BenchError {
  let rows : Array[DebugManifestRow] = []
  let header : Map[String, Int] = Map([])
  let mut saw_header = false
  for line in text.split("\n") {
    let normalized_line = line.replace(old="\r", new="")
    let trimmed = normalized_line.trim().to_owned()
    if trimmed == "" || trimmed.has_prefix("#") {
      continue
    }
    let cols = string_view_array_to_string_array(
      normalized_line.split("\t").to_array(),
    )
    if !saw_header {
      saw_header = true
      for i in 0..<cols.length() {
        let key = cols[i].trim().to_owned().to_lower()
        if key != "" {
          header.set(key, i)
        }
      }
      require_debug_manifest_field(header, "bench_id")
      require_debug_manifest_field(header, "format")
      require_debug_manifest_field(header, "bench_layers")
      require_debug_manifest_field(header, "enabled_tier")
      continue
    }
    rows.push({
      bench_id: debug_manifest_col(cols, header, "bench_id"),
      format: debug_manifest_col(cols, header, "format").to_lower(),
      enabled_tier: debug_manifest_col(cols, header, "enabled_tier"),
      bench_layers: debug_manifest_col(cols, header, "bench_layers"),
    })
  }
  if !saw_header {
    raise Failed("external_bench manifest is empty")
  }
  rows
}

///|
fn require_debug_manifest_field(
  header : Map[String, Int],
  name : String,
) -> Unit raise BenchError {
  if header.get(name) == None {
    raise Failed("external_bench manifest missing required field: " + name)
  }
}

///|
fn debug_manifest_col(
  cols : Array[String],
  header : Map[String, Int],
  name : String,
) -> String {
  match header.get(name) {
    Some(index) =>
      if index >= 0 && index < cols.length() {
        cols[index].trim().to_owned()
      } else {
        ""
      }
    None => ""
  }
}

///|
fn read_manifest(path : String) -> Array[ManifestRow] raise BenchError {
  let external_rows = read_manifest_from_text(
    read_utf8_text(path),
    parent_dir(path),
  )
  if external_rows.length() == 0 {
    raise Failed(
      "no enabled convert benchmark rows selected from external_bench; check enabled_tier, bench_layers, format, or filters",
    )
  }
  external_rows
}

///|
fn read_manifest_from_text(
  text : String,
  manifest_dir : String,
) -> Array[ManifestRow] raise BenchError {
  let external_rows = @benchshared.parse_external_bench_manifest(
    text,
    manifest_dir,
    "convert",
    require_parser_stages=false,
  ) catch {
    e => raise Failed(e.to_string())
  }
  let rows : Array[ManifestRow] = []
  for row in external_rows {
    rows.push({
      format: row.format,
      path: row.path,
      label: row.bench_id,
      size_class: row.size_class,
      source_group: row.source_group,
      bench_profile: row.bench_profile,
      workload_tags: row.workload_tags,
    })
  }
  rows
}

///|
async fn bench_convert_row(
  row : ManifestRow,
  cfg : BenchConfig,
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let input_bytes = file_size_bytes(row.path)
  let total = cfg.iterations + cfg.warmup
  for iter in 1..<=total {
    let run = run_convert_once(row, cfg, iter - cfg.warmup, input_bytes)
    if iter > cfg.warmup {
      runs.push(run)
    }
  }
}

///|
async fn run_convert_once(
  row : ManifestRow,
  cfg : BenchConfig,
  measured_iteration : Int,
  input_bytes : Int,
) -> BenchRunRow raise BenchError {
  let started = now_ms()
  let opts : @conv.ConvertOptions = {
    out_dir: None,
    max_heading: Some(6),
    pdf_enhance_mode: None,
    pdf_extract_debug: false,
    pdf_dump_selected_raw: false,
    pdf_pipeline_debug: false,
  }
  let result = @conv.parse_to_ir(row.path, opts) catch {
    e => raise Failed(e.to_string())
  }
  let elapsed = elapsed_ms_since(started)
  match result {
    Ok(doc) =>
      {
        layer: "convert",
        format: row.format,
        sample: row.label,
        size_class: row.size_class,
        stage: "parse_to_ir",
        iteration: measured_iteration,
        elapsed_ms: elapsed,
        input_bytes,
        blocks: doc.blocks.val.length(),
        asset_count: doc.asset_origins.val.length(),
        exit_status: 0,
        notes: convert_notes(row, cfg),
      }
    Err(err) =>
      {
        layer: "convert",
        format: row.format,
        sample: row.label,
        size_class: row.size_class,
        stage: "parse_to_ir",
        iteration: measured_iteration,
        elapsed_ms: elapsed,
        input_bytes,
        blocks: 0,
        asset_count: 0,
        exit_status: 1,
        notes: "parse_to_ir_failed=" +
        summary_escape(err.to_string()) +
        " " +
        convert_notes(row, cfg),
      }
  }
}

///|
fn convert_notes(row : ManifestRow, cfg : BenchConfig) -> String {
  let parts : Array[String] = [
    "runner=bench/convert_layer", "entrypoint=convert/convert.parse_to_ir", "cli=false",
    "markdown_emit=false", "parser_included=true",
  ]
  if row.bench_profile != "" {
    parts.push("bench_profile=" + row.bench_profile)
  }
  if row.source_group != "" {
    parts.push("source_group=" + row.source_group)
  }
  if row.workload_tags != "" {
    parts.push("workload_tags=" + row.workload_tags)
  }
  if cfg.profile != "" {
    parts.push("profile=" + cfg.profile)
  }
  parts.join(" ")
}

///|
fn summarize_runs(runs : Array[BenchRunRow]) -> Array[BenchSummaryRow] {
  let out : Array[BenchSummaryRow] = []
  let keys : Array[String] = []
  for run in runs {
    let key = run.format + "\t" + run.sample + "\t" + run.stage
    if !contains_string(keys, key) {
      keys.push(key)
    }
  }
  for key in keys {
    let values : Array[Int64] = []
    let mut failed = 0
    let mut input_bytes = 0
    let mut blocks_last = 0
    let mut asset_count_last = 0
    let mut first : BenchRunRow? = None
    for run in runs {
      let row_key = run.format + "\t" + run.sample + "\t" + run.stage
      if row_key != key {
        continue
      }
      if first is None {
        first = Some(run)
      }
      values.push(run.elapsed_ms)
      if run.exit_status != 0 {
        failed += 1
      }
      input_bytes = run.input_bytes
      blocks_last = run.blocks
      asset_count_last = run.asset_count
    }
    match first {
      Some(run) => {
        let stats = @benchshared.summarize_int64(values)
        out.push({
          layer: run.layer,
          format: run.format,
          sample: run.sample,
          size_class: run.size_class,
          stage: run.stage,
          iterations: stats.count,
          failed,
          min_ms: stats.min,
          p50_ms: stats.p50,
          p95_ms: stats.p95,
          max_ms: stats.max,
          avg_ms: stats.avg,
          input_bytes,
          blocks_last,
          asset_count_last,
          runner_kind: "prebuilt-native",
          notes: run.notes,
        })
      }
      None => ()
    }
  }
  out
}

///|
fn now_ms() -> Int64 {
  @async.now()
}

///|
fn elapsed_ms_since(started : Int64) -> Int64 {
  let now = now_ms()
  if now <= started {
    0
  } else {
    now - started
  }
}

///|
fn file_size_bytes(path : String) -> Int {
  let bytes = @fs.read_file_to_bytes(path) catch { _ => return 0 }
  bytes.length()
}

///|
fn read_utf8_text(path : String) -> String raise BenchError {
  @fs.read_file_to_string(path, encoding="utf8") catch {
    e => raise Failed("read file failed: " + path + " : " + e.to_string())
  }
}

///|
fn render_summary_tsv(rows : Array[BenchSummaryRow]) -> String {
  let lines : Array[String] = [
    @benchshared.header([
      "layer", "format", "sample", "size_class", "stage", "iterations", "failed",
      "min_ms", "p50_ms", "p95_ms", "max_ms", "avg_ms", "input_bytes", "blocks_last",
      "asset_count_last", "runner_kind", "notes",
    ]),
  ]
  for row in rows {
    lines.push(
      @benchshared.row([
        row.layer,
        row.format,
        row.sample,
        row.size_class,
        row.stage,
        row.iterations.to_string(),
        row.failed.to_string(),
        row.min_ms.to_string(),
        row.p50_ms.to_string(),
        row.p95_ms.to_string(),
        row.max_ms.to_string(),
        row.avg_ms.to_string(),
        row.input_bytes.to_string(),
        row.blocks_last.to_string(),
        row.asset_count_last.to_string(),
        row.runner_kind,
        row.notes,
      ]),
    )
  }
  lines.join("\n") + "\n"
}

///|
fn render_runs_tsv(rows : Array[BenchRunRow]) -> String {
  let lines : Array[String] = [
    @benchshared.header([
      "layer", "format", "sample", "stage", "iteration", "elapsed_ms", "input_bytes",
      "blocks", "asset_count", "exit_status", "notes",
    ]),
  ]
  for row in rows {
    lines.push(
      @benchshared.row([
        row.layer,
        row.format,
        row.sample,
        row.stage,
        row.iteration.to_string(),
        row.elapsed_ms.to_string(),
        row.input_bytes.to_string(),
        row.blocks.to_string(),
        row.asset_count.to_string(),
        row.exit_status.to_string(),
        row.notes,
      ]),
    )
  }
  lines.join("\n") + "\n"
}

///|
fn contains_string(values : Array[String], wanted : String) -> Bool {
  for value in values {
    if value == wanted {
      return true
    }
  }
  false
}

///|
fn string_view_array_to_string_array(
  values : Array[StringView],
) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    out.push(value.to_owned())
  }
  out
}

///|
fn write_utf8_text(path : String, text : String) -> Unit raise BenchError {
  @fs.write_string_to_file(path, text, encoding="utf8") catch {
    e => raise Failed("write file failed: " + path + " : " + e.to_string())
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise BenchError {
  @benchshared.ensure_dir_tree(path) catch {
    e => raise Failed(e.to_string())
  }
}

///|
fn parent_dir(path : String) -> String {
  @benchshared.parent_dir(path)
}

///|
fn raw_output_path(summary_path : String) -> String {
  @benchshared.raw_output_path(summary_path)
}

///|
fn summary_escape(text : String) -> String {
  @benchshared.escape(text)
}

///|
