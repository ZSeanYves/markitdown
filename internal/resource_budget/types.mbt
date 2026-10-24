///|
/// Enforced budgets require a finite limit for every dimension. Only an
/// explicitly marked measurement profile may leave dimensions unbounded.
pub(all) enum BudgetProfile {
  Enforced
  MeasurementOnly
} derive(Eq)

///|
pub extend BudgetProfile with Eq::{equal, not_equal}

///|
/// These counters describe cumulative work and are never refunded.
/// ParseWork counts the caller's documented work units; this package does
/// not choose parser-specific units or production defaults.
pub(all) enum CumulativeKind {
  InflateBytes
  ParseWork
  OutputUtf8Bytes
  SourceMetadataBytes
  RagMetadataBytes
  ReadTrafficBytes
} derive(Eq)

///|
pub extend CumulativeKind with Eq::{equal, not_equal}

///|
/// Resident payload/storage counters are released by explicit leases.
/// IrBytes is separate from output, cache and transient working storage.
pub(all) enum ResidentKind {
  CacheBytes
  WorkingBytes
  TemporaryBytes
  IrBytes
} derive(Eq)

///|
pub extend ResidentKind with Eq::{equal, not_equal}

///|
pub(all) enum BudgetDimension {
  Cumulative(CumulativeKind)
  Resident(ResidentKind)
} derive(Eq)

///|
pub extend BudgetDimension with Eq::{equal, not_equal}

///|
/// Resource failures are typed data, separate from asynchronous cancellation.
/// `used` and `requested` remain separate even when their sum would overflow.
pub(all) enum BudgetError {
  InvalidLimit(BudgetDimension, Int64)
  MissingEnforcedLimit(BudgetDimension)
  NegativeAmount(BudgetDimension, Int64)
  ArithmeticOverflow(BudgetDimension, used~ : Int64, requested~ : Int64)
  LimitExceeded(
    BudgetDimension,
    used~ : Int64,
    requested~ : Int64,
    limit~ : Int64
  )
  LeaseCountOverflow
  OutstandingLeases(Int64)
  ReleasedLease
  Closed
} derive(Eq)

///|
pub extend BudgetError with Eq::{equal, not_equal}

///|
/// Construct with BudgetLimits::new; there is deliberately no default profile.
/// Optional limits are permitted only in MeasurementOnly profiles.
pub struct BudgetLimits {
  profile : BudgetProfile
  inflate_bytes : Int64?
  parse_work : Int64?
  output_utf8_bytes : Int64?
  source_metadata_bytes : Int64?
  rag_metadata_bytes : Int64?
  read_traffic_bytes : Int64?
  cache_bytes : Int64?
  working_bytes : Int64?
  temporary_bytes : Int64?
  ir_bytes : Int64?
} derive(Eq)

///|
pub extend BudgetLimits with Eq::{equal, not_equal}

///|
pub struct CumulativeUsage {
  inflate_bytes : Int64
  parse_work : Int64
  output_utf8_bytes : Int64
  source_metadata_bytes : Int64
  rag_metadata_bytes : Int64
  read_traffic_bytes : Int64
} derive(Eq)

///|
pub extend CumulativeUsage with Eq::{equal, not_equal}

///|
pub struct ResidentUsage {
  cache_bytes : Int64
  working_bytes : Int64
  temporary_bytes : Int64
  ir_bytes : Int64
} derive(Eq)

///|
pub extend ResidentUsage with Eq::{equal, not_equal}

///|
/// An immutable sample. Cumulative usage is also its peak because those
/// counters never decrease. Resident peaks survive release and close.
pub struct BudgetSnapshot {
  limits : BudgetLimits
  cumulative : CumulativeUsage
  resident : ResidentUsage
  resident_peak : ResidentUsage
  active_leases : Int64
  first_error : BudgetError?
  closed : Bool
} derive(Eq)

///|
pub extend BudgetSnapshot with Eq::{equal, not_equal}

///|
priv struct BudgetState {
  mut limits : BudgetLimits
  cumulative : FixedArray[Int64]
  resident : FixedArray[Int64]
  resident_peak : FixedArray[Int64]
  mut active_leases : Int64
  mut first_error : BudgetError?
  mut closed : Bool
}

///|
/// Copies borrow the same account; copying this handle never resets usage.
/// A conversion owner must close it after releasing owned resources.
pub struct Budget {
  priv state : BudgetState
}

///|
/// Release is explicit, idempotent, and allowed after failure or close.
/// A lease keeps its account alive until cleanup; it performs no I/O.
pub struct BudgetLease {
  priv state : BudgetState
  priv kind : ResidentKind
  priv amount : Ref[Int64]
  priv released : Ref[Bool]
}
