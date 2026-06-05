///|
// BENCH_LAYER: parser; measures doc_parse parser APIs, not parser runtime.
suberror BenchError {
  Failed(String)
}

///|
struct BenchConfig {
  manifest : String
  layer : String
  output : String
  iterations : Int
  warmup : Int
  formats : Array[String]
  stages : Array[String]
  profile : String
}

///|
struct ManifestRow {
  format : String
  path : String
  label : String
  size_class : String
  stages : Array[String]
}

///|
struct BenchRunRow {
  format : String
  package_name : String
  sample : String
  size_class : String
  stage : String
  iteration : Int
  elapsed_us : Int
  bytes : Int
  notes : String
}

///|
struct BenchSummaryRow {
  format : String
  package_name : String
  sample : String
  size_class : String
  stage : String
  iterations : Int
  total_us : Int
  avg_us : Int
  min_us : Int
  p50_us : Int
  p95_us : Int
  max_us : Int
  bytes : Int
  notes : String
}

///|
fn main {
  run_bench(normalize_cli_args(@sys.get_cli_args())) catch {
    e => {
      println("doc_parse bench failed: " + e.to_string())
      @sys.exit(1)
    }
  }
}

///|
fn normalize_cli_args(args : Array[String]) -> Array[String] {
  if args.length() == 0 {
    return args
  }
  let first = args[0]
  if first.has_prefix("-") {
    return args
  }
  let out : Array[String] = []
  for i in 1..<args.length() {
    out.push(args[i])
  }
  out
}

///|
fn run_bench(args : Array[String]) -> Unit raise BenchError {
  let cfg = parse_args(args)
  let _ = cfg.layer
  let rows = read_manifest(cfg.manifest)
  let filtered = selected_rows(rows, cfg.formats, cfg.stages)
  if filtered.length() == 0 {
    raise Failed(
      "no enabled parser benchmark rows selected from external_bench; check enabled_tier, bench_layers, format, or stage filters",
    )
  }

  let summaries : Array[BenchSummaryRow] = []
  let runs : Array[BenchRunRow] = []

  for row in filtered {
    bench_manifest_row(row, cfg, summaries, runs)
  }
  if summaries.length() == 0 {
    raise Failed(
      "no enabled parser benchmark rows selected from external_bench; check enabled_tier, bench_layers, format, or stage filters",
    )
  }

  let output_dir = parent_dir(cfg.output)
  ensure_dir_tree(output_dir)
  let runs_output = raw_output_path(cfg.output)

  write_utf8_text(cfg.output, render_summary_tsv(summaries))
  write_utf8_text(runs_output, render_runs_tsv(runs))

  let slowest = slowest_summary_rows(summaries, 10)
  println("doc_parse benchmark completed")
  println("manifest: " + cfg.manifest)
  println("summary: " + cfg.output)
  println("raw runs: " + runs_output)
  println("rows: " + summaries.length().to_string())
  println("slowest stages:")
  for row in slowest {
    println(
      "- " +
      row.format +
      "/" +
      row.sample +
      " [" +
      row.stage +
      "] avg=" +
      format_ms_3(row.avg_us) +
      "ms",
    )
  }
}

///|
fn parse_args(args : Array[String]) -> BenchConfig raise BenchError {
  let mut manifest = ""
  let mut layer = "parser"
  let mut output = ".tmp/bench/parser_layer/summary.tsv"
  let mut iterations = 10
  let mut warmup = 2
  let mut formats : Array[String] = []
  let mut stages : Array[String] = []
  let mut profile = ""
  let mut i = 0

  while i < args.length() {
    let arg = args[i]
    if arg == "--manifest" {
      i = require_value(args, i, arg)
      manifest = args[i]
    } else if arg == "--layer" {
      i = require_value(args, i, arg)
      layer = args[i].trim().to_owned().to_lower()
      if layer != "parser" {
        raise Failed(
          "bench/parser_layer only supports --layer parser; use samples/bench.sh for convert/cli/compare layers",
        )
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
    } else if arg == "--stage" {
      i = require_value(args, i, arg)
      stages = split_csv_arg(args[i])
    } else if arg == "--profile" {
      i = require_value(args, i, arg)
      profile = args[i].trim().to_owned().to_lower()
    } else if arg == "-h" || arg == "--help" {
      print_usage()
      @sys.exit(0)
    } else {
      raise Failed("unknown argument: " + arg)
    }
    i += 1
  }

  if manifest == "" {
    manifest = resolve_default_external_bench_manifest()
  }

  { manifest, layer, output, iterations, warmup, formats, stages, profile }
}

///|
fn print_usage() -> Unit {
  println(
    "usage: ./samples/helpers/bench/bench_doc_parse_helper.sh [--manifest PATH] [--layer parser] [--iterations N] [--warmup N] [--format csv,json,...] [--stage parse,inspect,validate] [--profile text|json|markdown|xlsx|docx|yaml] [--output PATH]\n\nexternal benchmark corpus is required; pass --manifest <path> or set MARKITDOWN_BENCH_LAB / MARKITDOWN_QUALITY_LAB; fetch or prepare markitdown-quality-lab/external_bench first.",
  )
}

///|
fn resolve_default_external_bench_manifest() -> String raise BenchError {
  match external_bench_manifest_from_env("MARKITDOWN_BENCH_LAB") {
    Some(path) => return path
    None => ()
  }
  match external_bench_manifest_from_env("MARKITDOWN_QUALITY_LAB") {
    Some(path) => return path
    None => ()
  }
  let repo_local = "markitdown-quality-lab/external_bench/MANIFEST.tsv"
  if @fs.path_exists(repo_local) {
    return repo_local
  }
  raise Failed(
    "external benchmark corpus is required; pass --manifest <path> or set MARKITDOWN_BENCH_LAB / MARKITDOWN_QUALITY_LAB; fetch or prepare markitdown-quality-lab/external_bench first.",
  )
}

///|
fn external_bench_manifest_from_env(env_name : String) -> String? {
  match @sys.get_env_var(env_name) {
    Some(root) => {
      let trimmed = root.trim().to_owned()
      if trimmed == "" {
        return None
      }
      let path = trim_trailing_slash(trimmed) + "/external_bench/MANIFEST.tsv"
      if @fs.path_exists(path) {
        Some(path)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn trim_trailing_slash(path : String) -> String {
  let mut out = path
  while out.length() > 1 && out.has_suffix("/") {
    out = out[:out.length() - 1].to_owned()
  }
  out
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
fn split_csv_arg(raw : String) -> Array[String] {
  @benchshared.split_tokens(raw)
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
  stages : Array[String],
) -> Array[ManifestRow] {
  let out : Array[ManifestRow] = []
  for row in rows {
    if formats.length() > 0 && !contains_string(formats, row.format) {
      continue
    }
    if stages.length() > 0 && !has_any_stage(row.stages, stages) {
      continue
    }
    if row.stages.length() > 0 {
      out.push(row)
    }
  }
  out
}

///|
fn has_any_stage(row_stages : Array[String], requested : Array[String]) -> Bool {
  for stage in requested {
    if contains_string(row_stages, stage) {
      return true
    }
  }
  false
}

///|
fn read_manifest(path : String) -> Array[ManifestRow] raise BenchError {
  let external_rows = @benchshared.read_external_bench_manifest(
    path,
    "parser",
    require_parser_stages=true,
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
      stages: @benchshared.split_tokens(row.parser_stages),
    })
  }
  rows
}

///|
fn bench_manifest_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  match row.format {
    "text" => bench_text_row(row, cfg, summaries, runs)
    "txt" => bench_text_row(row, cfg, summaries, runs)
    "csv" => bench_csv_row(row, cfg, summaries, runs)
    "tsv" => bench_tsv_row(row, cfg, summaries, runs)
    "json" => bench_json_row(row, cfg, summaries, runs)
    "yaml" => bench_yaml_row(row, cfg, summaries, runs)
    "xml" => bench_xml_row(row, cfg, summaries, runs)
    "html" => bench_html_row(row, cfg, summaries, runs)
    "markdown" => bench_markdown_row(row, cfg, summaries, runs)
    "zip" => bench_zip_row(row, cfg, summaries, runs)
    "ooxml" => bench_ooxml_row(row, cfg, summaries, runs)
    "epub" => bench_epub_row(row, cfg, summaries, runs)
    "xlsx" => bench_xlsx_row(row, cfg, summaries, runs)
    "docx" => bench_docx_row(row, cfg, summaries, runs)
    "pptx" => bench_pptx_row(row, cfg, summaries, runs)
    "pdf" => bench_pdf_row(row, cfg, summaries, runs)
    other => raise Failed("unsupported manifest format: " + other)
  }
}

///|
fn enabled_stage(row : ManifestRow, cfg : BenchConfig, stage : String) -> Bool {
  contains_string(row.stages, stage) &&
  (cfg.stages.length() == 0 || contains_string(cfg.stages, stage))
}

///|
fn bench_text_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let bytes = read_bytes(row.path)
  let raw = decode_utf8(bytes, row.path)
  let package_name = "doc_parse/text"
  let notes = "parse_text_document on preloaded UTF-8 text; disk I/O excluded"
  if enabled_stage(row, cfg, "parse") && cfg.profile == "text" {
    bench_text_profile_rows(
      row,
      cfg,
      summaries,
      runs,
      package_name,
      bytes.length(),
      raw,
    )
  }
  if enabled_stage(row, cfg, "parse") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "parse",
        cfg,
        bytes.length(),
        notes,
        runs,
        fn() {
          ignore(@text.parse_text_document(raw))
          Ok(())
        },
      ),
    )
  }
  let doc = @text.parse_text_document(raw)
  if enabled_stage(row, cfg, "inspect") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "inspect",
        cfg,
        bytes.length(),
        "inspect_text_document on pre-parsed text model; parse and I/O excluded",
        runs,
        fn() {
          ignore(@text.inspect_text_document(doc))
          Ok(())
        },
      ),
    )
  }
}

///|
fn bench_text_profile_rows(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
  package_name : String,
  bytes : Int,
  raw : String,
) -> Unit {
  let profile_runs : Array[BenchRunRow] = []
  let stage_order : Array[String] = []
  let stage_notes : Map[String, String] = Map([])

  for _ in 0..<cfg.warmup {
    ignore(@text.profile_text_document(raw))
  }

  for i in 0..<cfg.iterations {
    let profiled = @text.profile_text_document(raw)
    for stage in profiled.report.stages {
      let stage_name = "profile:" + stage.name
      if stage_notes.get(stage_name) == None {
        stage_order.push(stage_name)
        stage_notes.set(stage_name, text_profile_stage_notes(stage.detail))
      }
      let run = {
        format: row.format,
        package_name,
        sample: row.label,
        size_class: row.size_class,
        stage: stage_name,
        iteration: i + 1,
        elapsed_us: stage.elapsed_ms.to_int() * 1000,
        bytes,
        notes: stage_notes.get(stage_name).unwrap_or(""),
      }
      runs.push(run)
      profile_runs.push(run)
    }
  }

  for stage_name in stage_order {
    let timings : Array[Int] = []
    let notes = stage_notes.get(stage_name).unwrap_or("")
    for run in profile_runs {
      if run.stage == stage_name {
        timings.push(run.elapsed_us)
      }
    }
    if timings.length() > 0 {
      summaries.push(
        summary_row_from_timings(
          row, package_name, stage_name, bytes, notes, timings,
        ),
      )
    }
  }
}

///|
fn text_profile_stage_notes(detail : String?) -> String {
  let base = "text internal parse sub-stage from profile_text_document; durations are rounded to package-local milliseconds"
  match detail {
    Some(text) =>
      if text.trim() == "" {
        base
      } else {
        base + " detail=" + text.trim().to_owned()
      }
    None => base
  }
}

///|
fn bench_csv_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let bytes = read_bytes(row.path)
  let raw = decode_utf8(bytes, row.path)
  let package_name = "doc_parse/csv"
  if enabled_stage(row, cfg, "parse") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "parse",
        cfg,
        bytes.length(),
        "parse_csv_document on preloaded UTF-8 text; disk I/O excluded",
        runs,
        fn() {
          ignore(
            @csv.parse_csv_document(raw) catch {
              e =>
                return Err(
                  Failed(
                    "csv parse failed for " + row.path + " : " + e.to_string(),
                  ),
                )
            },
          )
          Ok(())
        },
      ),
    )
  }
  let doc = @csv.parse_csv_document(raw) catch {
    e =>
      raise Failed("csv parse failed for " + row.path + " : " + e.to_string())
  }
  if enabled_stage(row, cfg, "inspect") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "inspect",
        cfg,
        bytes.length(),
        "inspect_csv_document on pre-parsed CSV model; parse and I/O excluded",
        runs,
        fn() {
          ignore(@csv.inspect_csv_document(doc))
          Ok(())
        },
      ),
    )
  }
  if enabled_stage(row, cfg, "validate") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "validate",
        cfg,
        bytes.length(),
        "validate_csv_document on pre-parsed CSV model; parse and I/O excluded",
        runs,
        fn() {
          ignore(@csv.validate_csv_document(doc))
          Ok(())
        },
      ),
    )
  }
}

///|
fn bench_tsv_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let bytes = read_bytes(row.path)
  let raw = decode_utf8(bytes, row.path)
  let package_name = "doc_parse/tsv"
  if enabled_stage(row, cfg, "parse") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "parse",
        cfg,
        bytes.length(),
        "parse_tsv_document on preloaded UTF-8 text; disk I/O excluded",
        runs,
        fn() {
          ignore(
            @tsv.parse_tsv_document(raw) catch {
              e =>
                return Err(
                  Failed(
                    "tsv parse failed for " + row.path + " : " + e.to_string(),
                  ),
                )
            },
          )
          Ok(())
        },
      ),
    )
  }
  let doc = @tsv.parse_tsv_document(raw) catch {
    e =>
      raise Failed("tsv parse failed for " + row.path + " : " + e.to_string())
  }
  if enabled_stage(row, cfg, "inspect") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "inspect",
        cfg,
        bytes.length(),
        "inspect_tsv_document on pre-parsed TSV model; parse and I/O excluded",
        runs,
        fn() {
          ignore(@tsv.inspect_tsv_document(doc))
          Ok(())
        },
      ),
    )
  }
  if enabled_stage(row, cfg, "validate") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "validate",
        cfg,
        bytes.length(),
        "validate_tsv_document on pre-parsed TSV model; parse and I/O excluded",
        runs,
        fn() {
          ignore(@tsv.validate_tsv_document(doc))
          Ok(())
        },
      ),
    )
  }
}

///|
fn bench_json_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let bytes = read_bytes(row.path)
  let raw = decode_utf8(bytes, row.path)
  let package_name = "doc_parse/json"
  if enabled_stage(row, cfg, "parse") && cfg.profile == "json" {
    bench_json_profile_rows(
      row,
      cfg,
      summaries,
      runs,
      package_name,
      bytes.length(),
      raw,
    )
  }
  if enabled_stage(row, cfg, "parse") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "parse",
        cfg,
        bytes.length(),
        "parse_json_document on preloaded UTF-8 text; disk I/O excluded",
        runs,
        fn() {
          ignore(
            @json.parse_json_document(raw) catch {
              e =>
                return Err(
                  Failed(
                    "json parse failed for " + row.path + " : " + e.to_string(),
                  ),
                )
            },
          )
          Ok(())
        },
      ),
    )
  }
  let doc = @json.parse_json_document(raw) catch {
    e =>
      raise Failed("json parse failed for " + row.path + " : " + e.to_string())
  }
  if enabled_stage(row, cfg, "inspect") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "inspect",
        cfg,
        bytes.length(),
        "inspect_json_document on pre-parsed JSON model; parse and I/O excluded",
        runs,
        fn() {
          ignore(@json.inspect_json_document(doc))
          Ok(())
        },
      ),
    )
  }
}

///|
fn bench_json_profile_rows(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
  package_name : String,
  bytes : Int,
  raw : String,
) -> Unit raise BenchError {
  let profile_runs : Array[BenchRunRow] = []
  let stage_order : Array[String] = []
  let stage_notes : Map[String, String] = Map([])

  for _ in 0..<cfg.warmup {
    ignore(
      @json.profile_json_document(raw) catch {
        e =>
          raise Failed(
            "json profile parse failed for " + row.path + " : " + e.to_string(),
          )
      },
    )
  }

  for i in 0..<cfg.iterations {
    let profiled = @json.profile_json_document(raw) catch {
      e =>
        raise Failed(
          "json profile parse failed for " + row.path + " : " + e.to_string(),
        )
    }
    for stage in profiled.report.stages {
      let stage_name = "profile:" + stage.name
      if stage_notes.get(stage_name) == None {
        stage_order.push(stage_name)
        stage_notes.set(stage_name, json_profile_stage_notes(stage.detail))
      }
      let run = {
        format: row.format,
        package_name,
        sample: row.label,
        size_class: row.size_class,
        stage: stage_name,
        iteration: i + 1,
        elapsed_us: stage.elapsed_ms.to_int() * 1000,
        bytes,
        notes: stage_notes.get(stage_name).unwrap_or(""),
      }
      runs.push(run)
      profile_runs.push(run)
    }
  }

  for stage_name in stage_order {
    let timings : Array[Int] = []
    let notes = stage_notes.get(stage_name).unwrap_or("")
    for run in profile_runs {
      if run.stage == stage_name {
        timings.push(run.elapsed_us)
      }
    }
    if timings.length() > 0 {
      summaries.push(
        summary_row_from_timings(
          row, package_name, stage_name, bytes, notes, timings,
        ),
      )
    }
  }
}

///|
fn json_profile_stage_notes(detail : String?) -> String {
  let base = "json internal parse sub-stage from profile_json_document; durations are rounded to package-local milliseconds"
  match detail {
    Some(text) =>
      if text.trim() == "" {
        base
      } else {
        base + " detail=" + text.trim().to_owned()
      }
    None => base
  }
}

///|
fn bench_yaml_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let bytes = read_bytes(row.path)
  let raw = decode_utf8(bytes, row.path)
  let package_name = "doc_parse/yaml"
  if enabled_stage(row, cfg, "parse") && cfg.profile == "yaml" {
    bench_yaml_profile_rows(
      row,
      cfg,
      summaries,
      runs,
      package_name,
      bytes.length(),
      raw,
    )
  }
  if enabled_stage(row, cfg, "parse") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "parse",
        cfg,
        bytes.length(),
        "parse_yaml_document on preloaded UTF-8 text; disk I/O excluded",
        runs,
        fn() {
          ignore(
            @yaml.parse_yaml_document(raw) catch {
              e =>
                return Err(
                  Failed(
                    "yaml parse failed for " + row.path + " : " + e.to_string(),
                  ),
                )
            },
          )
          Ok(())
        },
      ),
    )
  }
  let doc = @yaml.parse_yaml_document(raw) catch {
    e =>
      raise Failed("yaml parse failed for " + row.path + " : " + e.to_string())
  }
  if enabled_stage(row, cfg, "inspect") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "inspect",
        cfg,
        bytes.length(),
        "inspect_yaml_document on pre-parsed YAML model; parse and I/O excluded",
        runs,
        fn() {
          ignore(@yaml.inspect_yaml_document(doc))
          Ok(())
        },
      ),
    )
  }
}

///|
fn bench_yaml_profile_rows(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
  package_name : String,
  bytes : Int,
  raw : String,
) -> Unit raise BenchError {
  let profile_runs : Array[BenchRunRow] = []
  let stage_order : Array[String] = []
  let stage_notes : Map[String, String] = Map([])

  for _ in 0..<cfg.warmup {
    ignore(
      @yaml.profile_yaml_document(raw) catch {
        e =>
          raise Failed(
            "yaml profile parse failed for " + row.path + " : " + e.to_string(),
          )
      },
    )
  }

  for i in 0..<cfg.iterations {
    let profiled = @yaml.profile_yaml_document(raw) catch {
      e =>
        raise Failed(
          "yaml profile parse failed for " + row.path + " : " + e.to_string(),
        )
    }
    for stage in profiled.report.stages {
      let stage_name = "profile:" + stage.name
      if stage_notes.get(stage_name) == None {
        stage_order.push(stage_name)
        stage_notes.set(stage_name, yaml_profile_stage_notes(stage.detail))
      }
      let run = {
        format: row.format,
        package_name,
        sample: row.label,
        size_class: row.size_class,
        stage: stage_name,
        iteration: i + 1,
        elapsed_us: stage.elapsed_ms.to_int() * 1000,
        bytes,
        notes: stage_notes.get(stage_name).unwrap_or(""),
      }
      runs.push(run)
      profile_runs.push(run)
    }
  }

  for stage_name in stage_order {
    let timings : Array[Int] = []
    let notes = stage_notes.get(stage_name).unwrap_or("")
    for run in profile_runs {
      if run.stage == stage_name {
        timings.push(run.elapsed_us)
      }
    }
    if timings.length() > 0 {
      summaries.push(
        summary_row_from_timings(
          row, package_name, stage_name, bytes, notes, timings,
        ),
      )
    }
  }
}

///|
fn yaml_profile_stage_notes(detail : String?) -> String {
  let base = "yaml internal parse sub-stage from profile_yaml_document; durations are rounded to package-local milliseconds"
  match detail {
    Some(text) =>
      if text.trim() == "" {
        base
      } else {
        base + " detail=" + text.trim().to_owned()
      }
    None => base
  }
}

///|
fn bench_xml_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let bytes = read_bytes(row.path)
  let raw = decode_utf8(bytes, row.path)
  let package_name = "doc_parse/xml"
  if enabled_stage(row, cfg, "parse") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "parse",
        cfg,
        bytes.length(),
        "parse_xml_document on preloaded UTF-8 text; disk I/O excluded",
        runs,
        fn() {
          ignore(
            @xml.parse_xml_document(raw) catch {
              e =>
                return Err(
                  Failed(
                    "xml parse failed for " + row.path + " : " + e.to_string(),
                  ),
                )
            },
          )
          Ok(())
        },
      ),
    )
  }
  let doc = @xml.parse_xml_document(raw) catch {
    e =>
      raise Failed("xml parse failed for " + row.path + " : " + e.to_string())
  }
  if enabled_stage(row, cfg, "inspect") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "inspect",
        cfg,
        bytes.length(),
        "inspect_xml_document on pre-parsed XML model; parse and I/O excluded",
        runs,
        fn() {
          ignore(@xml.inspect_xml_document(doc))
          Ok(())
        },
      ),
    )
  }
  if enabled_stage(row, cfg, "validate") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "validate",
        cfg,
        bytes.length(),
        "validate_xml_document on pre-parsed XML model; parse and I/O excluded",
        runs,
        fn() {
          ignore(@xml.validate_xml_document(doc))
          Ok(())
        },
      ),
    )
  }
}

///|
fn bench_html_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let bytes = read_bytes(row.path)
  let raw = decode_utf8(bytes, row.path)
  let package_name = "doc_parse/html"
  if enabled_stage(row, cfg, "parse") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "parse",
        cfg,
        bytes.length(),
        "parse_html_document on preloaded UTF-8 text; disk I/O excluded",
        runs,
        fn() {
          ignore(
            @html.parse_html_document(raw) catch {
              e =>
                return Err(
                  Failed(
                    "html parse failed for " + row.path + " : " + e.to_string(),
                  ),
                )
            },
          )
          Ok(())
        },
      ),
    )
  }
  let doc = @html.parse_html_document(raw) catch {
    e =>
      raise Failed("html parse failed for " + row.path + " : " + e.to_string())
  }
  if enabled_stage(row, cfg, "inspect") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "inspect",
        cfg,
        bytes.length(),
        "inspect_html_document on pre-parsed HTML model; parse and I/O excluded",
        runs,
        fn() {
          ignore(@html.inspect_html_document(doc))
          Ok(())
        },
      ),
    )
  }
  if enabled_stage(row, cfg, "validate") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "validate",
        cfg,
        bytes.length(),
        "validate_html_document on pre-parsed HTML model; parse and I/O excluded",
        runs,
        fn() {
          ignore(@html.validate_html_document(doc))
          Ok(())
        },
      ),
    )
  }
}

///|
fn bench_markdown_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let bytes = read_bytes(row.path)
  let raw = decode_utf8(bytes, row.path)
  let package_name = "doc_parse/markdown"
  if enabled_stage(row, cfg, "scan") && cfg.profile == "markdown" {
    bench_markdown_profile_rows(
      row,
      cfg,
      summaries,
      runs,
      package_name,
      bytes.length(),
      raw,
    )
  }
  if enabled_stage(row, cfg, "scan") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "scan",
        cfg,
        bytes.length(),
        "scan_markdown_document on preloaded UTF-8 text; disk I/O excluded",
        runs,
        fn() {
          ignore(@markdown.scan_markdown_document(raw))
          Ok(())
        },
      ),
    )
  }
  let doc = @markdown.scan_markdown_document(raw)
  if enabled_stage(row, cfg, "inspect") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "inspect",
        cfg,
        bytes.length(),
        "inspect_markdown_document on pre-scanned Markdown model; scan and I/O excluded",
        runs,
        fn() {
          ignore(@markdown.inspect_markdown_document(doc))
          Ok(())
        },
      ),
    )
  }
  if enabled_stage(row, cfg, "validate") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "validate",
        cfg,
        bytes.length(),
        "validate_markdown_document on pre-scanned Markdown model; scan and I/O excluded",
        runs,
        fn() {
          ignore(@markdown.validate_markdown_document(doc))
          Ok(())
        },
      ),
    )
  }
}

///|
fn bench_markdown_profile_rows(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
  package_name : String,
  bytes : Int,
  raw : String,
) -> Unit {
  let profile_runs : Array[BenchRunRow] = []
  let stage_order : Array[String] = []
  let stage_notes : Map[String, String] = Map([])

  for _ in 0..<cfg.warmup {
    ignore(@markdown.profile_markdown_document(raw))
  }

  for i in 0..<cfg.iterations {
    let profiled = @markdown.profile_markdown_document(raw)
    for stage in profiled.report.stages {
      let stage_name = "profile:" + stage.name
      if stage_notes.get(stage_name) == None {
        stage_order.push(stage_name)
        stage_notes.set(stage_name, markdown_profile_stage_notes(stage.detail))
      }
      let run = {
        format: row.format,
        package_name,
        sample: row.label,
        size_class: row.size_class,
        stage: stage_name,
        iteration: i + 1,
        elapsed_us: stage.elapsed_ms.to_int() * 1000,
        bytes,
        notes: stage_notes.get(stage_name).unwrap_or(""),
      }
      runs.push(run)
      profile_runs.push(run)
    }
  }

  for stage_name in stage_order {
    let timings : Array[Int] = []
    let notes = stage_notes.get(stage_name).unwrap_or("")
    for run in profile_runs {
      if run.stage == stage_name {
        timings.push(run.elapsed_us)
      }
    }
    if timings.length() > 0 {
      summaries.push(
        summary_row_from_timings(
          row, package_name, stage_name, bytes, notes, timings,
        ),
      )
    }
  }
}

///|
fn markdown_profile_stage_notes(detail : String?) -> String {
  let base = "markdown internal scan sub-stage from profile_markdown_document; durations are rounded to package-local milliseconds"
  match detail {
    Some(text) =>
      if text.trim() == "" {
        base
      } else {
        base + " detail=" + text.trim().to_owned()
      }
    None => base
  }
}

///|
fn bench_zip_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let bytes = read_bytes(row.path)
  let package_name = "doc_parse/zip"
  if enabled_stage(row, cfg, "open") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "open",
        cfg,
        bytes.length(),
        "open_zip on preloaded bytes; disk I/O excluded",
        runs,
        fn() {
          ignore(
            @zip.open_zip(bytes) catch {
              e =>
                return Err(
                  Failed(
                    "zip open failed for " + row.path + " : " + e.to_string(),
                  ),
                )
            },
          )
          Ok(())
        },
      ),
    )
  }
  let archive = @zip.open_zip(bytes) catch {
    e => raise Failed("zip open failed for " + row.path + " : " + e.to_string())
  }
  if enabled_stage(row, cfg, "inspect") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "inspect",
        cfg,
        bytes.length(),
        "inspect_zip_archive on pre-opened archive; open and I/O excluded",
        runs,
        fn() {
          ignore(@zip.inspect_zip_archive(archive))
          Ok(())
        },
      ),
    )
  }
  if enabled_stage(row, cfg, "validate") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "validate",
        cfg,
        bytes.length(),
        "validate_zip_archive on pre-opened archive; open and I/O excluded",
        runs,
        fn() {
          ignore(@zip.validate_zip_archive(archive))
          Ok(())
        },
      ),
    )
  }
}

///|
fn bench_ooxml_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let bytes = read_bytes(row.path)
  let package_name = "doc_parse/ooxml"
  if enabled_stage(row, cfg, "open") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "open",
        cfg,
        bytes.length(),
        "open_ooxml_package on preloaded bytes; disk I/O excluded",
        runs,
        fn() {
          ignore(
            @ooxml.open_ooxml_package(bytes) catch {
              e =>
                return Err(
                  Failed(
                    "ooxml open failed for " + row.path + " : " + e.to_string(),
                  ),
                )
            },
          )
          Ok(())
        },
      ),
    )
  }
  let pkg = @ooxml.open_ooxml_package(bytes) catch {
    e =>
      raise Failed("ooxml open failed for " + row.path + " : " + e.to_string())
  }
  if enabled_stage(row, cfg, "inspect") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "inspect",
        cfg,
        bytes.length(),
        "inspect_ooxml_package on pre-opened package; open and I/O excluded",
        runs,
        fn() {
          ignore(@ooxml.inspect_ooxml_package(pkg))
          Ok(())
        },
      ),
    )
  }
  if enabled_stage(row, cfg, "validate") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "validate",
        cfg,
        bytes.length(),
        "validate_ooxml_package on pre-opened package; open and I/O excluded",
        runs,
        fn() {
          ignore(@ooxml.validate_ooxml_package(pkg))
          Ok(())
        },
      ),
    )
  }
}

///|
fn bench_epub_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let bytes = read_bytes(row.path)
  let package_name = "doc_parse/epub"
  let source_name = @cor.basename(row.path)
  if enabled_stage(row, cfg, "open") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "open",
        cfg,
        bytes.length(),
        "open_epub_package on preloaded bytes; disk I/O excluded",
        runs,
        fn() {
          ignore(
            @epub.open_epub_package(bytes, source_name) catch {
              e =>
                return Err(
                  Failed(
                    "epub open failed for " + row.path + " : " + e.to_string(),
                  ),
                )
            },
          )
          Ok(())
        },
      ),
    )
  }
  let pkg = @epub.open_epub_package(bytes, source_name) catch {
    e =>
      raise Failed("epub open failed for " + row.path + " : " + e.to_string())
  }
  if enabled_stage(row, cfg, "inspect") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "inspect",
        cfg,
        bytes.length(),
        "inspect_epub_package on pre-opened package; open and I/O excluded",
        runs,
        fn() {
          ignore(@epub.inspect_epub_package(pkg))
          Ok(())
        },
      ),
    )
  }
  if enabled_stage(row, cfg, "validate") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "validate",
        cfg,
        bytes.length(),
        "validate_epub_package on pre-opened package; open and I/O excluded",
        runs,
        fn() {
          ignore(@epub.validate_epub_package(pkg))
          Ok(())
        },
      ),
    )
  }
}

///|
fn bench_xlsx_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let bytes = read_bytes(row.path)
  let package_name = "doc_parse/xlsx"
  let pkg = @ooxml.open_ooxml_package(bytes) catch {
    e =>
      raise Failed(
        "ooxml open failed for xlsx sample " + row.path + " : " + e.to_string(),
      )
  }
  if enabled_stage(row, cfg, "parse") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "parse",
        cfg,
        bytes.length(),
        "parse_xlsx_workbook_from_package on pre-opened OOXML package; disk I/O and package open excluded",
        runs,
        fn() {
          ignore(
            @xlsx.parse_xlsx_workbook_from_package(pkg) catch {
              e =>
                return Err(
                  Failed(
                    "xlsx parse failed for " + row.path + " : " + e.to_string(),
                  ),
                )
            },
          )
          Ok(())
        },
      ),
    )
  }
  if enabled_stage(row, cfg, "parse") && cfg.profile == "xlsx" {
    bench_xlsx_profile_rows(
      row,
      cfg,
      summaries,
      runs,
      package_name,
      bytes.length(),
      pkg,
    )
  }
  let wb = @xlsx.parse_xlsx_workbook_from_package(pkg) catch {
    e =>
      raise Failed("xlsx parse failed for " + row.path + " : " + e.to_string())
  }
  if enabled_stage(row, cfg, "inspect") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "inspect",
        cfg,
        bytes.length(),
        "inspect_xlsx_workbook on pre-parsed semantic workbook; parse and I/O excluded",
        runs,
        fn() {
          ignore(@xlsx.inspect_xlsx_workbook(wb))
          Ok(())
        },
      ),
    )
  }
  if enabled_stage(row, cfg, "validate") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "validate",
        cfg,
        bytes.length(),
        "validate_xlsx_workbook on pre-parsed semantic workbook; parse and I/O excluded",
        runs,
        fn() {
          ignore(@xlsx.validate_xlsx_workbook(wb))
          Ok(())
        },
      ),
    )
  }
}

///|
fn bench_xlsx_profile_rows(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
  package_name : String,
  bytes : Int,
  pkg : @ooxml.OoxmlPackage,
) -> Unit raise BenchError {
  let profile_runs : Array[BenchRunRow] = []
  let stage_order : Array[String] = []
  let stage_notes : Map[String, String] = Map([])

  for _ in 0..<cfg.warmup {
    ignore(
      @xlsx.profile_xlsx_workbook_from_package(pkg) catch {
        e =>
          raise Failed(
            "xlsx profile parse failed for " + row.path + " : " + e.to_string(),
          )
      },
    )
  }

  for i in 0..<cfg.iterations {
    let profiled = @xlsx.profile_xlsx_workbook_from_package(pkg) catch {
      e =>
        raise Failed(
          "xlsx profile parse failed for " + row.path + " : " + e.to_string(),
        )
    }
    for stage in profiled.report.stages {
      let stage_name = "profile:" + stage.name
      if stage_notes.get(stage_name) == None {
        stage_order.push(stage_name)
        stage_notes.set(stage_name, xlsx_profile_stage_notes(stage.detail))
      }
      let run = {
        format: row.format,
        package_name,
        sample: row.label,
        size_class: row.size_class,
        stage: stage_name,
        iteration: i + 1,
        elapsed_us: stage.elapsed_ms.to_int() * 1000,
        bytes,
        notes: stage_notes.get(stage_name).unwrap_or(""),
      }
      runs.push(run)
      profile_runs.push(run)
    }
  }

  for stage_name in stage_order {
    let timings : Array[Int] = []
    let notes = stage_notes.get(stage_name).unwrap_or("")
    for run in profile_runs {
      if run.stage == stage_name {
        timings.push(run.elapsed_us)
      }
    }
    if timings.length() > 0 {
      summaries.push(
        summary_row_from_timings(
          row, package_name, stage_name, bytes, notes, timings,
        ),
      )
    }
  }
}

///|
fn xlsx_profile_stage_notes(detail : String?) -> String {
  let base = "xlsx internal parse sub-stage from profile_xlsx_workbook_from_package; durations are rounded to package-local milliseconds"
  match detail {
    Some(text) =>
      if text.trim() == "" {
        base
      } else {
        base + " detail=" + text.trim().to_owned()
      }
    None => base
  }
}

///|
fn bench_docx_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let bytes = read_bytes(row.path)
  let package_name = "doc_parse/docx"
  let pkg = @ooxml.open_ooxml_package(bytes) catch {
    e =>
      raise Failed(
        "ooxml open failed for docx sample " + row.path + " : " + e.to_string(),
      )
  }
  if enabled_stage(row, cfg, "parse") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "parse",
        cfg,
        bytes.length(),
        "parse_docx_document_from_package on pre-opened OOXML package; disk I/O and package open excluded",
        runs,
        fn() {
          ignore(
            @docx.parse_docx_document_from_package(pkg) catch {
              e =>
                return Err(
                  Failed(
                    "docx parse failed for " + row.path + " : " + e.to_string(),
                  ),
                )
            },
          )
          Ok(())
        },
      ),
    )
  }
  if enabled_stage(row, cfg, "parse") && cfg.profile == "docx" {
    bench_docx_profile_rows(
      row,
      cfg,
      summaries,
      runs,
      package_name,
      bytes.length(),
      pkg,
    )
  }
  let doc = @docx.parse_docx_document_from_package(pkg) catch {
    e =>
      raise Failed("docx parse failed for " + row.path + " : " + e.to_string())
  }
  if enabled_stage(row, cfg, "inspect") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "inspect",
        cfg,
        bytes.length(),
        "docx typed model traversal on pre-parsed semantic document; parse and I/O excluded",
        runs,
        fn() {
          ignore(inspect_docx_document_for_bench(doc))
          Ok(())
        },
      ),
    )
  }
  if enabled_stage(row, cfg, "validate") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "validate",
        cfg,
        bytes.length(),
        "docx warning scan on pre-parsed semantic document; parse and I/O excluded",
        runs,
        fn() {
          ignore(validate_docx_document_for_bench(doc))
          Ok(())
        },
      ),
    )
  }
}

///|
fn bench_docx_profile_rows(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
  package_name : String,
  bytes : Int,
  pkg : @ooxml.OoxmlPackage,
) -> Unit raise BenchError {
  let profile_runs : Array[BenchRunRow] = []
  let stage_name = "profile:docx_parse"
  let notes = docx_profile_stage_notes(None)

  for _ in 0..<cfg.warmup {
    ignore(
      @docx.parse_docx_document_from_package(pkg) catch {
        e =>
          raise Failed(
            "docx profile parse failed for " + row.path + " : " + e.to_string(),
          )
      },
    )
  }

  for i in 0..<cfg.iterations {
    let started = now_us()
    ignore(
      @docx.parse_docx_document_from_package(pkg) catch {
        e =>
          raise Failed(
            "docx profile parse failed for " + row.path + " : " + e.to_string(),
          )
      },
    )
    let run = {
      format: row.format,
      package_name,
      sample: row.label,
      size_class: row.size_class,
      stage: stage_name,
      iteration: i + 1,
      elapsed_us: elapsed_us_since(started),
      bytes,
      notes,
    }
    runs.push(run)
    profile_runs.push(run)
  }

  let timings : Array[Int] = []
  for run in profile_runs {
    timings.push(run.elapsed_us)
  }
  if timings.length() > 0 {
    summaries.push(
      summary_row_from_timings(
        row, package_name, stage_name, bytes, notes, timings,
      ),
    )
  }
}

///|
fn inspect_docx_document_for_bench(doc : @docx.DocxDocument) -> Int {
  let mut count = 0
  count += doc.body.length()
  count += doc.footnotes.length()
  count += doc.endnotes.length()
  count += doc.comments.length()
  count += doc.headers.length()
  count += doc.footers.length()
  count += doc.textboxes.length()
  for block in doc.body {
    count += count_docx_block_for_bench(block)
  }
  count
}

///|
fn validate_docx_document_for_bench(doc : @docx.DocxDocument) -> Int {
  let mut count = 0
  for warning in doc.warnings {
    match warning.severity {
      @docx.DocxWarningSeverity::Warning => count += 1
      @docx.DocxWarningSeverity::Error => count += 10
    }
  }
  count
}

///|
fn count_docx_block_for_bench(block : @docx.DocxBlock) -> Int {
  match block {
    @docx.DocxBlock::Paragraph(p) => p.inlines.length() + p.runs.length()
    @docx.DocxBlock::Table(table) => {
      let mut count = table.rows.length()
      for row in table.rows {
        count += row.cells.length()
        for cell in row.cells {
          for child in cell.blocks {
            count += count_docx_block_for_bench(child)
          }
        }
      }
      count
    }
    @docx.DocxBlock::ContentControl(control) => {
      let mut count = control.inlines.length()
      for child in control.blocks {
        count += count_docx_block_for_bench(child)
      }
      count
    }
    @docx.DocxBlock::TablePlaceholder(_)
    | @docx.DocxBlock::StructuralMarker(_)
    | @docx.DocxBlock::Unsupported(_) => 1
  }
}

///|
fn docx_profile_stage_notes(_detail : String?) -> String {
  "docx package parse on pre-opened OOXML package; disk I/O and package open excluded"
}

///|
fn bench_pptx_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let bytes = read_bytes(row.path)
  let package_name = "doc_parse/pptx"
  let pkg = @ooxml.open_ooxml_package(bytes) catch {
    e =>
      raise Failed(
        "ooxml open failed for pptx sample " + row.path + " : " + e.to_string(),
      )
  }
  if enabled_stage(row, cfg, "parse") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "parse",
        cfg,
        bytes.length(),
        "parse_pptx_presentation_from_package on pre-opened OOXML package; disk I/O and package open excluded",
        runs,
        fn() {
          ignore(
            @pptx.parse_pptx_presentation_from_package(pkg) catch {
              e =>
                return Err(
                  Failed(
                    "pptx parse failed for " + row.path + " : " + e.to_string(),
                  ),
                )
            },
          )
          Ok(())
        },
      ),
    )
  }
  let pres = @pptx.parse_pptx_presentation_from_package(pkg) catch {
    e =>
      raise Failed("pptx parse failed for " + row.path + " : " + e.to_string())
  }
  if enabled_stage(row, cfg, "inspect") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "inspect",
        cfg,
        bytes.length(),
        "inspect_pptx_presentation on pre-parsed semantic presentation; parse and I/O excluded",
        runs,
        fn() {
          ignore(@pptx.inspect_pptx_presentation(pres))
          Ok(())
        },
      ),
    )
  }
  if enabled_stage(row, cfg, "validate") {
    summaries.push(
      measure_stage(
        row,
        package_name,
        "validate",
        cfg,
        bytes.length(),
        "validate_pptx_presentation on pre-parsed semantic presentation; parse and I/O excluded",
        runs,
        fn() {
          ignore(@pptx.validate_pptx_presentation(pres))
          Ok(())
        },
      ),
    )
  }
}

///|
fn bench_pdf_row(
  row : ManifestRow,
  cfg : BenchConfig,
  summaries : Array[BenchSummaryRow],
  runs : Array[BenchRunRow],
) -> Unit raise BenchError {
  let _ = row
  let _ = cfg
  let _ = summaries
  let _ = runs
  raise Failed(
    "pdf direct library attribution is currently deferred in bench/parser_layer: async PDF API shape does not fit the current typed benchmark runner without wider harness refactor",
  )
}

///|
fn measure_stage(
  row : ManifestRow,
  package_name : String,
  stage : String,
  cfg : BenchConfig,
  bytes : Int,
  notes : String,
  runs : Array[BenchRunRow],
  action : () -> Result[Unit, BenchError],
) -> BenchSummaryRow raise BenchError {
  let timings : Array[Int] = []

  for _ in 0..<cfg.warmup {
    match action() {
      Ok(_) => ()
      Err(e) => raise e
    }
  }

  for i in 0..<cfg.iterations {
    let started = now_us()
    match action() {
      Ok(_) => ()
      Err(e) => raise e
    }
    let elapsed_us = elapsed_us_since(started)
    timings.push(elapsed_us)
    runs.push({
      format: row.format,
      package_name,
      sample: row.label,
      size_class: row.size_class,
      stage,
      iteration: i + 1,
      elapsed_us,
      bytes,
      notes,
    })
  }

  summary_row_from_timings(row, package_name, stage, bytes, notes, timings)
}

///|
fn _pdf_library_attribution_deferred_note() -> String {
  "pdf direct library attribution remains deferred: async lower-layer API shape currently mismatches the typed synchronous benchmark runner"
}

///|
fn summary_row_from_timings(
  row : ManifestRow,
  package_name : String,
  stage : String,
  bytes : Int,
  notes : String,
  timings : Array[Int],
) -> BenchSummaryRow {
  let stats = @benchshared.summarize_int(timings)
  {
    format: row.format,
    package_name,
    sample: row.label,
    size_class: row.size_class,
    stage,
    iterations: stats.count,
    total_us: stats.total,
    avg_us: stats.avg,
    min_us: stats.min,
    p50_us: stats.p50,
    p95_us: stats.p95,
    max_us: stats.max,
    bytes,
    notes,
  }
}

///|
fn now_us() -> Int64 {
  @async.now() * 1000
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

///|
fn format_ms_3(elapsed_us : Int) -> String {
  let whole = elapsed_us / 1000
  let frac = elapsed_us % 1000
  let frac_text = if frac < 10 {
    "00" + frac.to_string()
  } else if frac < 100 {
    "0" + frac.to_string()
  } else {
    frac.to_string()
  }
  whole.to_string() + "." + frac_text
}

///|
fn render_summary_tsv(rows : Array[BenchSummaryRow]) -> String {
  let lines : Array[String] = [
    @benchshared.header([
      "format", "package", "sample", "size_class", "stage", "iterations", "total_ms",
      "avg_ms", "min_ms", "p50_ms", "p95_ms", "max_ms", "bytes", "notes",
    ]),
  ]
  for row in rows {
    lines.push(
      @benchshared.row([
        row.format,
        row.package_name,
        row.sample,
        row.size_class,
        row.stage,
        row.iterations.to_string(),
        format_ms_3(row.total_us),
        format_ms_3(row.avg_us),
        format_ms_3(row.min_us),
        format_ms_3(row.p50_us),
        format_ms_3(row.p95_us),
        format_ms_3(row.max_us),
        row.bytes.to_string(),
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
      "format", "package", "sample", "size_class", "stage", "iteration", "elapsed_ms",
      "bytes", "notes",
    ]),
  ]
  for row in rows {
    lines.push(
      @benchshared.row([
        row.format,
        row.package_name,
        row.sample,
        row.size_class,
        row.stage,
        row.iteration.to_string(),
        format_ms_3(row.elapsed_us),
        row.bytes.to_string(),
        row.notes,
      ]),
    )
  }
  lines.join("\n") + "\n"
}

///|
fn slowest_summary_rows(
  rows : Array[BenchSummaryRow],
  limit : Int,
) -> Array[BenchSummaryRow] {
  let out : Array[BenchSummaryRow] = []
  for row in rows {
    out.push(row)
  }
  out.sort_by(fn(a, b) {
    if a.avg_us == b.avg_us {
      0
    } else if a.avg_us > b.avg_us {
      -1
    } else {
      1
    }
  })
  if out.length() <= limit {
    out
  } else {
    let limited : Array[BenchSummaryRow] = []
    for i in 0..<limit {
      limited.push(out[i])
    }
    limited
  }
}

///|
fn read_bytes(path : String) -> Bytes raise BenchError {
  @fs.read_file_to_bytes(path) catch {
    e => raise Failed("read file failed: " + path + " : " + e.to_string())
  }
}

///|
fn decode_utf8(bytes : Bytes, path : String) -> String raise BenchError {
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise Failed("utf8 decode failed for " + path)
  }
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
fn contains_string(items : Array[String], needle : String) -> Bool {
  for item in items {
    if item == needle {
      return true
    }
  }
  false
}

///|
impl Show for BenchError with fn to_string(self : BenchError) -> String {
  match self {
    Failed(msg) => msg
  }
}
