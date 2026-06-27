///|
pub fn micro_textlike_smoke_rows() -> Array[BenchManifestRow] {
  let formats = ["txt", "csv", "tsv", "json", "yaml", "xml", "markdown", "html"]
  select_rows_for_layer_and_formats(BenchTier::Smoke, "micro", formats).filter(row => {
    row.size_class == "tiny" || row.size_class == "small"
  })
}

///|
pub fn micro_detector_smoke_rows() -> Array[BenchManifestRow] {
  select_rows_for_layer(BenchTier::Smoke, "micro")
}

///|
pub fn pipeline_smoke_textlike_rows() -> Array[BenchManifestRow] {
  let formats = ["txt", "csv", "tsv", "json", "yaml", "xml", "markdown", "html"]
  select_rows_for_layer_and_formats(BenchTier::Smoke, "pipeline", formats)
}

///|
pub fn pipeline_smoke_binary_rows() -> Array[BenchManifestRow] {
  let formats = ["zip", "epub", "pdf", "docx", "pptx", "xlsx"]
  select_rows_for_layer_and_formats(BenchTier::Smoke, "pipeline", formats)
}

///|
pub fn product_smoke_rows() -> Array[BenchManifestRow] {
  select_rows_for_layer(BenchTier::Smoke, "product")
}

///|
pub fn official_gate_tiers() -> Array[BenchTier] {
  [BenchTier::Regular, BenchTier::Release, BenchTier::Stress]
}

///|
pub fn official_gate_main_formats() -> Array[String] {
  [
    "txt", "csv", "tsv", "json", "yaml", "xml", "markdown", "html", "zip", "epub",
    "pdf", "docx", "pptx", "xlsx",
  ]
}

///|
pub fn official_gate_rows() -> Array[BenchManifestRow] {
  let wanted_formats = official_gate_main_formats()
  filter_profile_rows(
    select_rows_exact_tiers(official_gate_tiers()).filter(row => {
      wanted_formats.contains(row.format.trim().to_lower().to_owned())
    }),
  )
}

///|
pub fn official_gate_rows_for_format(
  format : String,
) -> Array[BenchManifestRow] {
  let wanted = format.trim().to_lower().to_owned()
  official_gate_rows().filter(row => {
    row.format.trim().to_lower().to_owned() == wanted
  })
}

///|
pub fn pipeline_official_gate_textlike_rows() -> Array[BenchManifestRow] {
  let formats = ["txt", "csv", "tsv", "json", "yaml", "xml", "markdown", "html"]
  official_gate_rows().filter(row => {
    row.bench_layers.any(name => name.trim().to_lower() == "pipeline") &&
    formats.contains(row.format.trim().to_lower().to_owned())
  })
}

///|
pub fn pipeline_official_gate_binary_rows() -> Array[BenchManifestRow] {
  let formats = ["zip", "epub", "pdf", "docx", "pptx", "xlsx"]
  official_gate_rows().filter(row => {
    row.bench_layers.any(name => name.trim().to_lower() == "pipeline") &&
    formats.contains(row.format.trim().to_lower().to_owned())
  })
}

///|
fn filter_profile_rows(
  rows : Array[BenchManifestRow],
) -> Array[BenchManifestRow] {
  let filtered_by_format = match normalized_profile_formats() {
    [] => rows
    wanted =>
      rows.filter(row => {
        wanted.contains(row.format.trim().to_lower().to_owned())
      })
  }
  match normalized_profile_bench_ids() {
    [] => filtered_by_format
    wanted =>
      filtered_by_format.filter(row => {
        wanted.contains(row.bench_id.trim().to_lower().to_owned())
      })
  }
}

///|
fn normalized_profile_bench_ids() -> Array[String] {
  match @env.get_env_var("MARKITDOWN_BENCH_PROFILE_BENCH_IDS") {
    Some(value) =>
      value
      .split(",")
      .to_array()
      .map(part => part.trim().to_lower().to_owned())
      .filter(part => part != "")
    None => []
  }
}

///|
fn normalized_profile_formats() -> Array[String] {
  match @env.get_env_var("MARKITDOWN_BENCH_PROFILE_FORMATS") {
    Some(value) =>
      value
      .split(",")
      .to_array()
      .map(part => part.trim().to_lower().to_owned())
      .filter(part => part != "")
    None => []
  }
}
