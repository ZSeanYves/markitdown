///|
const MAX_COUNTER : Int64 = 9223372036854775807L

///|
pub fn Budget::new(limits : BudgetLimits) -> Budget {
  {
    state: {
      limits,
      cumulative: FixedArray::make(6, 0L),
      resident: FixedArray::make(4, 0L),
      resident_peak: FixedArray::make(4, 0L),
      active_leases: 0L,
      first_error: None,
      closed: false,
    },
  }
}

///|
fn latch(state : BudgetState, error : BudgetError) -> BudgetError {
  match state.first_error {
    Some(first) => first
    None => {
      state.first_error = Some(error)
      error
    }
  }
}

///|
fn checked_next(
  state : BudgetState,
  dimension : BudgetDimension,
  used : Int64,
  requested : Int64,
  limit : Int64?,
) -> Result[Int64, BudgetError] {
  if state.first_error is Some(error) {
    return Err(error)
  }
  if state.closed {
    return Err(latch(state, Closed))
  }
  if requested < 0L {
    return Err(latch(state, NegativeAmount(dimension, requested)))
  }
  if requested > MAX_COUNTER - used {
    return Err(latch(state, ArithmeticOverflow(dimension, used~, requested~)))
  }
  match limit {
    Some(limit) if used > limit || requested > limit - used =>
      Err(latch(state, LimitExceeded(dimension, used~, requested~, limit~)))
    _ => Ok(used + requested)
  }
}

///|
/// Tighten one resident dimension on this same account. A larger request never
/// relaxes an existing limit, and no counter, lease, peak or first failure is
/// reset. Failure leaves the previous limits unchanged. Successful updates
/// replace the immutable limits record, so earlier snapshots remain frozen.
/// A finite cap in MeasurementOnly still enforces admission; measurements of
/// that dimension are consequently censored by the supplied configuration.
pub fn Budget::tighten_resident_limit(
  self : Budget,
  kind : ResidentKind,
  limit : Int64,
) -> Result[Unit, BudgetError] {
  let state = self.state
  if state.first_error is Some(error) {
    return Err(error)
  }
  if state.closed {
    return Err(latch(state, Closed))
  }
  if limit < 0L {
    return Err(latch(state, InvalidLimit(Resident(kind), limit)))
  }
  let effective = match resident_limit(state.limits, kind) {
    Some(previous) => previous.min(limit)
    None => limit
  }
  let used = state.resident[resident_index(kind)]
  if used > effective {
    return Err(
      latch(
        state,
        LimitExceeded(Resident(kind), used~, requested=0L, limit=effective),
      ),
    )
  }
  state.limits = match kind {
    CacheBytes => { ..state.limits, cache_bytes: Some(effective), }
    WorkingBytes => { ..state.limits, working_bytes: Some(effective), }
    TemporaryBytes => { ..state.limits, temporary_bytes: Some(effective), }
    IrBytes => { ..state.limits, ir_bytes: Some(effective), }
  }
  Ok(())
}

///|
/// Validate before performing the work. Failed charges do not change usage.
pub fn Budget::charge(
  self : Budget,
  kind : CumulativeKind,
  amount : Int64,
) -> Result[Unit, BudgetError] {
  let state = self.state
  let index = cumulative_index(kind)
  match
    checked_next(
      state,
      Cumulative(kind),
      state.cumulative[index],
      amount,
      cumulative_limit(state.limits, kind),
    ) {
    Ok(next) => {
      state.cumulative[index] = next
      Ok(())
    }
    Err(error) => Err(error)
  }
}

///|
/// Reserve before allocation or file growth. Zero-byte reservations own no
/// capacity and create no outstanding lease; they still reject failed/closed
/// accounts and negative requests.
pub fn Budget::reserve(
  self : Budget,
  kind : ResidentKind,
  amount : Int64,
) -> Result[BudgetLease, BudgetError] {
  let state = self.state
  let index = resident_index(kind)
  let next = match
    checked_next(
      state,
      Resident(kind),
      state.resident[index],
      amount,
      resident_limit(state.limits, kind),
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if amount > 0L && state.active_leases == MAX_COUNTER {
    return Err(latch(state, LeaseCountOverflow))
  }
  state.resident[index] = next
  state.resident_peak[index] = state.resident_peak[index].max(next)
  if amount > 0L {
    state.active_leases += 1L
  }
  Ok({ state, kind, amount: Ref(amount), released: Ref(amount == 0L), })
}

///|
/// Grow one live reservation before file growth/allocation. Copies share its
/// amount as well as its release token: any alias refunds the full grown amount
/// exactly once. This creates no new active lease or per-write lease array.
/// Zero-byte reserve handles remain already released; callers can reserve their
/// first nonzero growth lazily. Prior account error/close wins over lease state.
pub fn BudgetLease::grow(
  self : BudgetLease,
  amount : Int64,
) -> Result[Unit, BudgetError] {
  let state = self.state
  if state.first_error is Some(error) {
    return Err(error)
  }
  if state.closed {
    return Err(latch(state, Closed))
  }
  if self.released.val {
    return Err(latch(state, ReleasedLease))
  }
  let index = resident_index(self.kind)
  let next = match
    checked_next(
      state,
      Resident(self.kind),
      state.resident[index],
      amount,
      resident_limit(state.limits, self.kind),
    ) {
    Ok(next) => next
    Err(error) => return Err(error)
  }
  // self.amount is part of the aggregate resident counter checked above, so
  // this smaller nonnegative sum cannot overflow after aggregate admission.
  self.amount.val += amount
  state.resident[index] = next
  state.resident_peak[index] = state.resident_peak[index].max(next)
  Ok(())
}

///|
/// Cleanup remains valid after a failure or close. A repeated release is a
/// no-op, so it cannot refund somebody else's reservation or lower a peak.
pub fn BudgetLease::release(self : BudgetLease) -> Unit {
  if self.released.val {
    return
  }
  self.released.val = true
  let index = resident_index(self.kind)
  self.state.resident[index] -= self.amount.val
  self.state.active_leases -= 1L
}

///|
pub fn Budget::failure(self : Budget) -> BudgetError? {
  self.state.first_error
}

///|
/// Mark the account closed before inspecting cleanup. Close never silently
/// releases memory/storage represented by a live lease. It reports remaining
/// leases while preserving the original failure, if any, in the snapshot.
/// Release remains usable after close; closing again after cleanup is Ok.
pub fn Budget::close(self : Budget) -> Result[Unit, BudgetError] {
  self.state.closed = true
  if self.state.active_leases > 0L {
    let error = OutstandingLeases(self.state.active_leases)
    ignore(latch(self.state, error))
    Err(error)
  } else {
    Ok(())
  }
}

///|
fn cumulative_usage(values : FixedArray[Int64]) -> CumulativeUsage {
  {
    inflate_bytes: values[0],
    parse_work: values[1],
    output_utf8_bytes: values[2],
    source_metadata_bytes: values[3],
    rag_metadata_bytes: values[4],
    read_traffic_bytes: values[5],
  }
}

///|
fn resident_usage(values : FixedArray[Int64]) -> ResidentUsage {
  {
    cache_bytes: values[0],
    working_bytes: values[1],
    temporary_bytes: values[2],
    ir_bytes: values[3],
  }
}

///|
pub fn Budget::snapshot(self : Budget) -> BudgetSnapshot {
  let state = self.state
  {
    limits: state.limits,
    cumulative: cumulative_usage(state.cumulative),
    resident: resident_usage(state.resident),
    resident_peak: resident_usage(state.resident_peak),
    active_leases: state.active_leases,
    first_error: state.first_error,
    closed: state.closed,
  }
}
