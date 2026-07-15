///|
const MANIFEST_HEADER : String = "bench_id\tformat\tsize_class\trel_path\tsource_kind\tsource_ref\tbytes\tsha256\tenabled_tier\tbench_layers\ttags\treview_status\tnotes\tcomparison_class\tcomparison_reason\tcomparison_signals"

///|
const EXTERNAL_BENCH_SUFFIX : String = "external_bench"

///|
fn bench_root() -> String {
  match normalized_env_var("MARKITDOWN_BENCH_ROOT") {
    Some(path) => path
    None =>
      match discover_external_bench_root() {
        Some(path) => path
        None => abort(missing_external_bench_message())
      }
  }
}

///|
pub fn select_rows(request : SelectRequest) -> Array[BenchRow] {
  let root = bench_root()
  let manifest_path = root + "/MANIFEST.tsv"
  let content = @fs.read_file_to_string(manifest_path, encoding="utf8") catch {
    err =>
      abort(
        "bench manifest read failed: " + manifest_path + " : " + err.to_string(),
      )
  }
  select_rows_from_manifest(content, manifest_path, root, request)
}

///|
fn select_rows_from_manifest(
  content : String,
  manifest_path : String,
  root : String,
  request : SelectRequest,
) -> Array[BenchRow] {
  let lines = content.split("\n").to_array()
  if lines.length() == 0 || lines[0].trim_end() != MANIFEST_HEADER {
    abort("unexpected bench manifest header: " + manifest_path)
  }
  let rows : Array[BenchRow] = []
  let selected = Ref(0)
  for i in 1..<lines.length() {
    let line = lines[i].trim_end().to_owned()
    if line.trim() == "" {
      continue
    }
    let row = parse_manifest_line_with_root(line, i + 1, root)
    if should_skip_row(row, request) is Some(_) {
      continue
    }
    if request.limit is Some(limit) && selected.val >= limit {
      continue
    }
    rows.push(row)
    selected.val += 1
  }
  rows
}

///|
pub fn selector_stats_json(request : SelectRequest) -> Json {
  let root = bench_root()
  let manifest_path = root + "/MANIFEST.tsv"
  let content = @fs.read_file_to_string(manifest_path, encoding="utf8") catch {
    err =>
      abort(
        "bench manifest read failed: " + manifest_path + " : " + err.to_string(),
      )
  }
  selector_stats_from_manifest(content, manifest_path, root, request)
}

///|
fn selector_stats_from_manifest(
  content : String,
  manifest_path : String,
  root : String,
  request : SelectRequest,
) -> Json {
  let lines = content.split("\n").to_array()
  if lines.length() == 0 || lines[0].trim_end() != MANIFEST_HEADER {
    abort("unexpected bench manifest header: " + manifest_path)
  }
  let skipped : Map[String, Int] = Map([])
  let rows : Array[BenchRow] = []
  let selected = Ref(0)
  for i in 1..<lines.length() {
    let line = lines[i].trim_end().to_owned()
    if line.trim() == "" {
      continue
    }
    let row = parse_manifest_line_with_root(line, i + 1, root)
    match should_skip_row(row, request) {
      Some(reason) => increment_skip_reason(skipped, reason)
      None =>
        if request.limit is Some(limit) && selected.val >= limit {
          increment_skip_reason(skipped, "limit_excluded")
        } else {
          rows.push(row)
          selected.val += 1
        }
    }
  }
  let formats = rows
    .map(row => row.format.trim().to_lower().to_owned())
    .filter(format => format != "")
  formats.sort()
  formats.dedup()
  SelectorStats::{
    requested_tier: if request.exact_tiers.length() > 0 {
      None
    } else {
      Some(request.tier.trim().to_lower().to_owned())
    },
    requested_tiers: request.exact_tiers.map(tier => {
      tier.trim().to_lower().to_owned()
    }),
    tier_filter_mode: if request.exact_tiers.length() > 0 {
      "exact"
    } else {
      "cumulative"
    },
    requested_bench_ids: request.bench_ids.copy(),
    selected_rows: rows.length(),
    formats,
    skipped_by_reason: skipped,
  }.to_json()
}

///|
pub fn empty_selector_stats() -> SelectorStats {
  make_selector_stats(None, [], "cumulative", [], 0, [], Map([]))
}

///|
pub fn selector_rows_tsv(request : SelectRequest) -> Array[String] {
  format_selector_rows_tsv(select_rows(request))
}

///|
fn format_selector_rows_tsv(rows : Array[BenchRow]) -> Array[String] {
  let lines : Array[String] = []
  for row in rows {
    lines.push(
      row.bench_id +
      "\t" +
      row.format +
      "\t" +
      row.size_class +
      "\t" +
      row.enabled_tier +
      "\t" +
      row.input_bytes.to_string() +
      "\t" +
      row.rel_path +
      "\t" +
      row.input_path,
    )
  }
  lines
}

///|
pub fn repo_rel_input_path(rel_path : String) -> String {
  bench_root() + "/" + rel_path
}

///|
pub fn ensure_bench_row_payload(row : BenchRow) -> Bool {
  @fs.path_exists(row.input_path)
}

///|
pub fn parse_manifest_line(line : String, line_no : Int) -> BenchRow {
  parse_manifest_line_with_root(line, line_no, bench_root())
}

///|
fn parse_manifest_line_with_root(
  line : String,
  line_no : Int,
  root : String,
) -> BenchRow {
  let columns = line.split("\t").to_array().map(part => part.to_owned())
  if columns.length() != 16 {
    abort("bench manifest column mismatch at line " + line_no.to_string())
  }
  let rel_path = columns[3]
  {
    bench_id: columns[0],
    format: columns[1],
    size_class: columns[2],
    rel_path,
    source_kind: columns[4],
    source_ref: columns[5],
    input_bytes: parse_manifest_int(columns[6], line_no),
    sha256: columns[7],
    enabled_tier: columns[8],
    bench_layers: split_csv_field(columns[9]),
    tags: split_csv_field(columns[10]),
    review_status: columns[11],
    notes: columns[12],
    comparison_class: columns[13],
    comparison_reason: columns[14],
    comparison_signals: split_csv_field(columns[15]),
    input_path: root + "/" + rel_path,
  }
}

///|
pub fn should_skip_row(row : BenchRow, request : SelectRequest) -> String? {
  let enabled_tier = row.enabled_tier.trim().to_lower().to_owned()
  if row.source_kind.trim() == "missing_candidate" {
    return Some("missing_candidate")
  }
  if row.review_status.trim() == "missing_candidate" {
    return Some("review_status_missing_candidate")
  }
  if enabled_tier == "disabled" {
    return Some("disabled")
  }
  if !tier_order().contains(enabled_tier) {
    return Some("unknown_tier")
  }
  if request.exact_tiers.length() > 0 {
    if !request.exact_tiers.any(tier => tier.trim().to_lower() == enabled_tier) {
      return Some("tier_exact_excluded")
    }
  } else if tier_rank(enabled_tier) >
    tier_rank(request.tier.trim().to_lower().to_owned()) {
    return Some("tier_excluded")
  }
  if request.bench_ids.length() > 0 &&
    !request.bench_ids.any(id => id.trim() == row.bench_id) {
    return Some("bench_id_filtered")
  }
  if row.input_bytes <= 0 {
    return Some("zero_bytes")
  }
  if request.format_filters.length() > 0 {
    let row_format = row.format.trim().to_lower().to_owned()
    if !request.format_filters.any(format_filter => {
        format_filter.trim().to_lower() == row_format
      }) {
      return Some("format_filtered")
    }
  }
  if request.comparison_classes.length() > 0 &&
    !request.comparison_classes.any(class => {
      class.trim().to_lower() == row.comparison_class.trim().to_lower()
    }) {
    return Some("comparison_class_filtered")
  }
  if row.rel_path.trim() == "" {
    return Some("missing_rel_path")
  }
  if !ensure_bench_row_payload(row) {
    return Some("missing_payload")
  }
  None
}

///|
fn tier_order() -> Array[String] {
  ["smoke", "regular", "release", "stress"]
}

///|
fn tier_rank(tier : String) -> Int {
  match tier {
    "smoke" => 0
    "regular" => 1
    "release" => 2
    "stress" => 3
    _ => 100
  }
}

///|
fn parse_manifest_int(text : String, line_no : Int) -> Int {
  @string.parse_int(text.trim()) catch {
    _ =>
      abort(
        "bench manifest integer parse failed at line " + line_no.to_string(),
      )
  }
}

///|
fn split_csv_field(text : String) -> Array[String] {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return []
  }
  trimmed
  .split(",")
  .to_array()
  .map(part => part.trim().to_owned())
  .filter(part => part != "")
}

///|
fn increment_skip_reason(skipped : Map[String, Int], reason : String) -> Unit {
  let next = match skipped.get(reason) {
    Some(count) => count + 1
    None => 1
  }
  skipped[reason] = next
}

///|
fn normalized_env_var(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
fn discover_external_bench_root() -> String? {
  let candidates = ["markitdown-quality-lab/" + EXTERNAL_BENCH_SUFFIX]
  for candidate in candidates {
    if @fs.path_exists(candidate + "/MANIFEST.tsv") {
      return Some(candidate)
    }
  }
  None
}

///|
fn missing_external_bench_message() -> String {
  [
    "benchmark corpus not found", "expected one of:", "  - $MARKITDOWN_BENCH_ROOT/MANIFEST.tsv",
    "  - ./markitdown-quality-lab/external_bench/MANIFEST.tsv", "download the external corpus into the main repo root first:",
    "  git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab",
    "  # official location: ./markitdown-quality-lab", "or set MARKITDOWN_BENCH_ROOT=/absolute/path/to/markitdown-quality-lab/external_bench",
  ].join("\n")
}
