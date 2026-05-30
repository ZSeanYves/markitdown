///|
pub(all) enum EnabledTierAction {
  Run
  Skip
  Error
} derive(Eq)

///|
pub(all) struct ExternalBenchRow {
  bench_id : String
  format : String
  rel_path : String
  path : String
  size_class : String
  bench_layers : String
  enabled_tier : String
  source_group : String
  bench_profile : String
  workload_tags : String
  parser_stages : String
}

///|
pub fn read_external_bench_manifest(
  path : String,
  layer : String,
  require_parser_stages~ : Bool,
) -> Array[ExternalBenchRow] raise BenchSharedError {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => raise Failed("read manifest failed: " + path + " : " + e.to_string())
  }
  let text = @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise Failed("utf8 decode failed for " + path)
  }
  let manifest_dir = parent_dir(path)
  let rows = parse_external_bench_manifest(
    text,
    manifest_dir,
    layer,
    require_parser_stages~,
  )
  if rows.length() == 0 {
    raise Failed(
      "no enabled " +
      layer +
      " benchmark rows selected from external_bench; check enabled_tier, bench_layers, format, or filters",
    )
  }
  rows
}

///|
pub fn parse_external_bench_manifest(
  text : String,
  manifest_dir : String,
  layer : String,
  require_parser_stages~ : Bool,
) -> Array[ExternalBenchRow] raise BenchSharedError {
  let rows : Array[ExternalBenchRow] = []
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
      require_external_bench_header(cols, header, require_parser_stages~)
      continue
    }
    let enabled_tier = manifest_col(cols, header, "enabled_tier")
      .trim()
      .to_owned()
      .to_lower()
    match enabled_tier_action(enabled_tier) {
      Skip => continue
      Error =>
        raise Failed(
          "external_bench manifest has unsupported enabled_tier: " +
          enabled_tier,
        )
      Run => ()
    }
    let bench_layers = manifest_col(cols, header, "bench_layers")
    if !list_contains_token(bench_layers, layer) {
      continue
    }
    let bench_id = manifest_col(cols, header, "bench_id").trim().to_owned()
    if bench_id == "" {
      raise Failed("external_bench manifest bench_id must not be empty")
    }
    let rel_path = manifest_col(cols, header, "rel_path").trim().to_owned()
    if rel_path == "" {
      raise Failed("external_bench manifest rel_path must not be empty")
    }
    if require_parser_stages &&
      optional_manifest_col(cols, header, "parser_stages").trim() == "" {
      raise Failed(
        "external_bench parser row missing parser_stages: " + bench_id,
      )
    }
    let resolved = resolve_manifest_rel_path(manifest_dir, rel_path)
    reject_forbidden_benchmark_path(resolved)
    rows.push({
      bench_id,
      format: manifest_col(cols, header, "format").trim().to_owned().to_lower(),
      rel_path,
      path: resolved,
      size_class: manifest_col(cols, header, "size_class")
      .trim()
      .to_owned()
      .to_lower(),
      bench_layers: bench_layers.trim().to_owned(),
      enabled_tier,
      source_group: optional_manifest_col(cols, header, "source_group"),
      bench_profile: optional_manifest_col(cols, header, "bench_profile"),
      workload_tags: optional_manifest_col(cols, header, "workload_tags"),
      parser_stages: optional_manifest_col(cols, header, "parser_stages"),
    })
  }
  if !saw_header {
    raise Failed("external_bench manifest is empty")
  }
  rows
}

///|
pub fn require_external_bench_header(
  cols : Array[String],
  header : Map[String, Int],
  require_parser_stages~ : Bool,
) -> Unit raise BenchSharedError {
  if cols.length() == 0 || cols[0].trim().to_owned().to_lower() != "bench_id" {
    raise Failed("manifest must use external_bench header schema")
  }
  for i in 0..<cols.length() {
    let key = cols[i].trim().to_owned().to_lower()
    if key != "" {
      header.set(key, i)
    }
  }
  require_external_manifest_field(header, "bench_id")
  require_external_manifest_field(header, "format")
  require_external_manifest_field(header, "rel_path")
  require_external_manifest_field(header, "size_class")
  require_external_manifest_field(header, "bench_layers")
  require_external_manifest_field(header, "enabled_tier")
  if require_parser_stages {
    require_external_manifest_field(header, "parser_stages")
  }
}

///|
pub fn enabled_tier_action(enabled_tier : String) -> EnabledTierAction {
  let value = enabled_tier.trim().to_owned().to_lower()
  if value == "smoke" || value == "full" || value == "manual" {
    Run
  } else if value == "" ||
    value == "disabled" ||
    value == "pending_review" ||
    value == "unknown" {
    Skip
  } else {
    Error
  }
}

///|
pub fn list_contains_token(list : String, wanted : String) -> Bool {
  let wanted = wanted.trim().to_owned().to_lower()
  if wanted == "" {
    return false
  }
  for part in normalize_token_separators(list).split(",") {
    let token = part.trim().to_owned().to_lower()
    if token != "" && token == wanted {
      return true
    }
  }
  false
}

///|
pub fn split_tokens(raw : String) -> Array[String] {
  let out : Array[String] = []
  for part in normalize_token_separators(raw).split(",") {
    let item = canonical_token(part.trim().to_owned().to_lower())
    if item != "" && item != "all" {
      out.push(item)
    }
  }
  out
}

///|
fn canonical_token(token : String) -> String {
  if token == "text" {
    "txt"
  } else {
    token
  }
}

///|
fn normalize_token_separators(raw : String) -> String {
  let mut out = raw
  while out.contains(";") {
    out = out.replace(old=";", new=",")
  }
  out
}

///|
fn require_external_manifest_field(
  header : Map[String, Int],
  name : String,
) -> Unit raise BenchSharedError {
  if header.get(name) == None {
    raise Failed("external_bench manifest missing required field: " + name)
  }
}

///|
fn manifest_col(
  cols : Array[String],
  header : Map[String, Int],
  name : String,
) -> String raise BenchSharedError {
  match header.get(name) {
    Some(index) =>
      if index >= 0 && index < cols.length() {
        cols[index]
      } else {
        ""
      }
    None =>
      raise Failed("external_bench manifest missing required field: " + name)
  }
}

///|
fn optional_manifest_col(
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
fn string_view_array_to_string_array(
  values : Array[StringView],
) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    out.push(value.to_owned())
  }
  out
}
