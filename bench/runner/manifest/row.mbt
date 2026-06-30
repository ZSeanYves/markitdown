///|
pub struct BenchRow {
  bench_id : String
  format : String
  size_class : String
  rel_path : String
  source_kind : String
  source_ref : String
  input_bytes : Int
  sha256 : String
  enabled_tier : String
  bench_layers : Array[String]
  tags : Array[String]
  review_status : String
  notes : String
  input_path : String
} derive(ToJson, FromJson, Eq)

///|
pub struct SelectorStats {
  requested_tier : String?
  requested_tiers : Array[String]
  tier_filter_mode : String
  requested_bench_ids : Array[String]
  selected_rows : Int
  formats : Array[String]
  skipped_by_reason : Map[String, Int]
} derive(ToJson, FromJson, Eq)

///|
pub(all) enum SelectOutput {
  Jsonl
  Tsv
} derive(Eq)

///|
pub struct SelectRequest {
  tier : String
  exact_tiers : Array[String]
  bench_ids : Array[String]
  format_filters : Array[String]
  limit : Int?
  output : SelectOutput
  stats_only : Bool
} derive(Eq)

///|
pub fn make_bench_row(
  bench_id : String,
  format : String,
  size_class : String,
  rel_path : String,
  source_kind : String,
  source_ref : String,
  input_bytes : Int,
  sha256 : String,
  enabled_tier : String,
  bench_layers : Array[String],
  tags : Array[String],
  review_status : String,
  notes : String,
  input_path : String,
) -> BenchRow {
  {
    bench_id,
    format,
    size_class,
    rel_path,
    source_kind,
    source_ref,
    input_bytes,
    sha256,
    enabled_tier,
    bench_layers,
    tags,
    review_status,
    notes,
    input_path,
  }
}

///|
pub fn make_selector_stats(
  requested_tier : String?,
  requested_tiers : Array[String],
  tier_filter_mode : String,
  requested_bench_ids : Array[String],
  selected_rows : Int,
  formats : Array[String],
  skipped_by_reason : Map[String, Int],
) -> SelectorStats {
  {
    requested_tier,
    requested_tiers,
    tier_filter_mode,
    requested_bench_ids,
    selected_rows,
    formats,
    skipped_by_reason,
  }
}
