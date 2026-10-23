///|
/// A borrowed conversion account. Escaping payload reservations belong to
/// the conversion scope through this callback, not to a cache map key.
pub struct BudgetContext {
  account : Budget
  retain_resident : (ResidentKind, Int64) -> Result[Unit, BudgetError]
}

///|
pub fn BudgetContext::new(
  account : Budget,
  retain_resident : (ResidentKind, Int64) -> Result[Unit, BudgetError],
) -> BudgetContext {
  { account, retain_resident, }
}

///|
pub fn budget_dimension_name(dimension : BudgetDimension) -> String {
  match dimension {
    Cumulative(InflateBytes) => "inflate_bytes"
    Cumulative(ParseWork) => "parse_work"
    Cumulative(OutputUtf8Bytes) => "output_utf8_bytes"
    Cumulative(SourceMetadataBytes) => "source_metadata_bytes"
    Cumulative(RagMetadataBytes) => "rag_metadata_bytes"
    Cumulative(ReadTrafficBytes) => "read_traffic_bytes"
    Resident(CacheBytes) => "cache_bytes"
    Resident(WorkingBytes) => "working_bytes"
    Resident(TemporaryBytes) => "temporary_bytes"
    Resident(IrBytes) => "ir_bytes"
  }
}

///|
/// A shared diagnostic formatter; callers propagate the typed error itself.
pub fn budget_error_message(error : BudgetError) -> String {
  match error {
    InvalidLimit(dimension, limit) =>
      "negative budget limit: " +
      budget_dimension_name(dimension) +
      "; limit=" +
      limit.to_string()
    MissingEnforcedLimit(dimension) =>
      "missing enforced budget limit: " + budget_dimension_name(dimension)
    NegativeAmount(dimension, requested) =>
      "negative budget amount: " +
      budget_dimension_name(dimension) +
      "; requested=" +
      requested.to_string()
    ArithmeticOverflow(dimension, used~, requested~) =>
      "budget arithmetic overflow: " +
      budget_dimension_name(dimension) +
      "; used=" +
      used.to_string() +
      "; requested=" +
      requested.to_string()
    LimitExceeded(dimension, used~, requested~, limit~) =>
      "resource budget exceeded: " +
      budget_dimension_name(dimension) +
      "; used=" +
      used.to_string() +
      "; requested=" +
      requested.to_string() +
      "; limit=" +
      limit.to_string()
    LeaseCountOverflow => "budget lease count overflow"
    OutstandingLeases(count) =>
      "budget has outstanding leases: " + count.to_string()
    Closed => "conversion budget is closed"
  }
}
