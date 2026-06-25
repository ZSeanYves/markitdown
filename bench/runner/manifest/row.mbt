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
  format_filter : String?
  limit : Int?
  output : SelectOutput
  stats_only : Bool
} derive(Eq)
