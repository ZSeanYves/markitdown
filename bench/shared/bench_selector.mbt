///|
pub fn smoke_rows() -> Array[BenchManifestRow] {
  select_rows(BenchTier::Smoke)
}

///|
pub fn regular_rows() -> Array[BenchManifestRow] {
  select_rows(BenchTier::Regular)
}

///|
pub fn release_rows() -> Array[BenchManifestRow] {
  select_rows(BenchTier::Release)
}

///|
pub fn stress_rows() -> Array[BenchManifestRow] {
  select_rows(BenchTier::Stress)
}

///|
pub fn select_rows_exact_tiers(
  tiers : Array[BenchTier],
) -> Array[BenchManifestRow] {
  let allowed = tiers.map(tier => bench_tier_name(tier))
  load_bench_manifest()
  .filter(row => bench_row_is_default_candidate(row))
  .filter(row => allowed.contains(row.enabled_tier.trim().to_lower().to_owned()))
}

///|
pub fn select_rows(max_tier : BenchTier) -> Array[BenchManifestRow] {
  load_bench_manifest()
  .filter(row => bench_row_is_default_candidate(row))
  .filter(row => {
    bench_row_tier_rank(row.enabled_tier) <= bench_tier_rank(max_tier)
  })
}

///|
pub fn select_rows_for_layer(
  max_tier : BenchTier,
  layer : String,
) -> Array[BenchManifestRow] {
  let wanted = layer.trim().to_lower()
  select_rows(max_tier).filter(row => {
    row.bench_layers.any(name => name.trim().to_lower() == wanted)
  })
}

///|
pub fn select_rows_for_formats(
  max_tier : BenchTier,
  formats : Array[String],
) -> Array[BenchManifestRow] {
  let wanted = formats.map(name => name.trim().to_lower())
  select_rows(max_tier).filter(row => {
    wanted.contains(row.format.trim().to_lower())
  })
}

///|
pub fn select_rows_for_layer_and_formats(
  max_tier : BenchTier,
  layer : String,
  formats : Array[String],
) -> Array[BenchManifestRow] {
  let rows = select_rows_for_layer(max_tier, layer)
  let wanted = formats.map(name => name.trim().to_lower())
  rows.filter(row => wanted.contains(row.format.trim().to_lower()))
}

///|
pub fn bench_tier_name(tier : BenchTier) -> String {
  match tier {
    BenchTier::Smoke => "smoke"
    BenchTier::Regular => "regular"
    BenchTier::Release => "release"
    BenchTier::Stress => "stress"
  }
}

///|
pub fn bench_row_is_default_candidate(row : BenchManifestRow) -> Bool {
  row.source_kind != "missing_candidate" &&
  row.review_status != "missing_candidate" &&
  row.enabled_tier != "disabled" &&
  row.bytes > 0 &&
  row.rel_path.trim() != "" &&
  bench_row_payload_exists(row)
}

///|
pub fn bench_row_tier_rank(enabled_tier : String) -> Int {
  match enabled_tier.trim().to_lower() {
    "smoke" => 0
    "regular" => 1
    "release" => 2
    "stress" => 3
    _ => 100
  }
}

///|
fn bench_tier_rank(tier : BenchTier) -> Int {
  match tier {
    BenchTier::Smoke => 0
    BenchTier::Regular => 1
    BenchTier::Release => 2
    BenchTier::Stress => 3
  }
}
