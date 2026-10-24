///|
/// Explicit measurement profile, with no invented finite production caps.
pub fn BudgetLimits::measurement_only() -> BudgetLimits {
  {
    profile: MeasurementOnly,
    inflate_bytes: None,
    parse_work: None,
    output_utf8_bytes: None,
    source_metadata_bytes: None,
    rag_metadata_bytes: None,
    read_traffic_bytes: None,
    cache_bytes: None,
    working_bytes: None,
    temporary_bytes: None,
    ir_bytes: None,
  }
}

///|
/// Every dimension must be supplied explicitly. MeasurementOnly may use None
/// to measure an unbounded dimension; provided caps are still enforced.
pub fn BudgetLimits::new(
  profile : BudgetProfile,
  inflate_bytes~ : Int64?,
  parse_work~ : Int64?,
  output_utf8_bytes~ : Int64?,
  source_metadata_bytes~ : Int64?,
  rag_metadata_bytes~ : Int64?,
  read_traffic_bytes~ : Int64?,
  cache_bytes~ : Int64?,
  working_bytes~ : Int64?,
  temporary_bytes~ : Int64?,
  ir_bytes~ : Int64?,
) -> Result[BudgetLimits, BudgetError] {
  let limits : BudgetLimits = {
    profile,
    inflate_bytes,
    parse_work,
    output_utf8_bytes,
    source_metadata_bytes,
    rag_metadata_bytes,
    read_traffic_bytes,
    cache_bytes,
    working_bytes,
    temporary_bytes,
    ir_bytes,
  }
  for kind in cumulative_kinds() {
    match
      validate_limit(profile, Cumulative(kind), cumulative_limit(limits, kind)) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  for kind in resident_kinds() {
    match
      validate_limit(profile, Resident(kind), resident_limit(limits, kind)) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  Ok(limits)
}

///|
fn validate_limit(
  profile : BudgetProfile,
  dimension : BudgetDimension,
  limit : Int64?,
) -> Result[Unit, BudgetError] {
  match limit {
    Some(value) if value < 0L => Err(InvalidLimit(dimension, value))
    None if profile == Enforced => Err(MissingEnforcedLimit(dimension))
    _ => Ok(())
  }
}

///|
fn cumulative_kinds() -> Array[CumulativeKind] {
  [
    InflateBytes,
    ParseWork,
    OutputUtf8Bytes,
    SourceMetadataBytes,
    RagMetadataBytes,
    ReadTrafficBytes,
  ]
}

///|
fn resident_kinds() -> Array[ResidentKind] {
  [CacheBytes, WorkingBytes, TemporaryBytes, IrBytes]
}

///|
fn cumulative_index(kind : CumulativeKind) -> Int32 {
  match kind {
    InflateBytes => 0
    ParseWork => 1
    OutputUtf8Bytes => 2
    SourceMetadataBytes => 3
    RagMetadataBytes => 4
    ReadTrafficBytes => 5
  }
}

///|
fn resident_index(kind : ResidentKind) -> Int32 {
  match kind {
    CacheBytes => 0
    WorkingBytes => 1
    TemporaryBytes => 2
    IrBytes => 3
  }
}

///|
fn cumulative_limit(limits : BudgetLimits, kind : CumulativeKind) -> Int64? {
  match kind {
    InflateBytes => limits.inflate_bytes
    ParseWork => limits.parse_work
    OutputUtf8Bytes => limits.output_utf8_bytes
    SourceMetadataBytes => limits.source_metadata_bytes
    RagMetadataBytes => limits.rag_metadata_bytes
    ReadTrafficBytes => limits.read_traffic_bytes
  }
}

///|
fn resident_limit(limits : BudgetLimits, kind : ResidentKind) -> Int64? {
  match kind {
    CacheBytes => limits.cache_bytes
    WorkingBytes => limits.working_bytes
    TemporaryBytes => limits.temporary_bytes
    IrBytes => limits.ir_bytes
  }
}
