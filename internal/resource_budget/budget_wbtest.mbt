///|
fn test_limits(profile : BudgetProfile, cap : Int64?) -> BudgetLimits {
  BudgetLimits::new(
    profile,
    inflate_bytes=cap,
    parse_work=cap,
    output_utf8_bytes=cap,
    source_metadata_bytes=cap,
    rag_metadata_bytes=cap,
    read_traffic_bytes=cap,
    cache_bytes=cap,
    working_bytes=cap,
    temporary_bytes=cap,
    ir_bytes=cap,
  ).unwrap()
}

///|
test "enforced limits reject missing and negative caps while measurement is explicit" {
  let missing = BudgetLimits::new(
    Enforced,
    inflate_bytes=None,
    parse_work=Some(0L),
    output_utf8_bytes=Some(0L),
    source_metadata_bytes=Some(0L),
    rag_metadata_bytes=Some(0L),
    read_traffic_bytes=Some(0L),
    cache_bytes=Some(0L),
    working_bytes=Some(0L),
    temporary_bytes=Some(0L),
    ir_bytes=Some(0L),
  )
  assert_true(missing is Err(MissingEnforcedLimit(Cumulative(InflateBytes))))
  let invalid = BudgetLimits::new(
    MeasurementOnly,
    inflate_bytes=None,
    parse_work=None,
    output_utf8_bytes=None,
    source_metadata_bytes=None,
    rag_metadata_bytes=None,
    read_traffic_bytes=None,
    cache_bytes=None,
    working_bytes=None,
    temporary_bytes=None,
    ir_bytes=Some(-1L),
  )
  assert_true(invalid is Err(InvalidLimit(Resident(IrBytes), -1L)))
  let sample = Budget::new(test_limits(MeasurementOnly, None)).snapshot()
  assert_true(sample.limits.profile == MeasurementOnly)
  assert_true(sample.first_error is None)
}

///|
test "cumulative dimensions are separate exact-limit counters with frozen snapshots" {
  let budget = Budget::new(test_limits(Enforced, Some(10L)))
  for kind in cumulative_kinds() {
    budget.charge(kind, 10L).unwrap()
  }
  let sample = budget.snapshot()
  assert_eq(sample.cumulative.inflate_bytes, 10L)
  assert_eq(sample.cumulative.parse_work, 10L)
  assert_eq(sample.cumulative.output_utf8_bytes, 10L)
  assert_eq(sample.cumulative.source_metadata_bytes, 10L)
  assert_eq(sample.cumulative.rag_metadata_bytes, 10L)
  assert_eq(sample.cumulative.read_traffic_bytes, 10L)
  assert_true(
    budget.charge(OutputUtf8Bytes, 1L)
    is Err(
      LimitExceeded(
        Cumulative(OutputUtf8Bytes),
        used=10L,
        requested=1L,
        limit=10L
      )
    ),
  )
  assert_true(sample.first_error is None)
  assert_eq(budget.snapshot().cumulative.output_utf8_bytes, 10L)
}

///|
test "unbounded measurement still rejects arithmetic overflow before mutation" {
  let budget = Budget::new(test_limits(MeasurementOnly, None))
  budget.charge(InflateBytes, MAX_COUNTER).unwrap()
  assert_true(
    budget.charge(InflateBytes, 1L)
    is Err(
      ArithmeticOverflow(
        Cumulative(InflateBytes),
        used=MAX_COUNTER,
        requested=1L
      )
    ),
  )
  assert_eq(budget.snapshot().cumulative.inflate_bytes, MAX_COUNTER)
}

///|
test "negative amounts latch the first failure across charge and reserve" {
  for resident in [false, true] {
    let budget = Budget::new(test_limits(Enforced, Some(10L)))
    if resident {
      assert_true(
        budget.reserve(CacheBytes, -1L)
        is Err(NegativeAmount(Resident(CacheBytes), -1L)),
      )
    } else {
      assert_true(
        budget.charge(ParseWork, -1L)
        is Err(NegativeAmount(Cumulative(ParseWork), -1L)),
      )
    }
    let first = budget.failure().unwrap()
    assert_true(
      budget.charge(OutputUtf8Bytes, 0L) is Err(error) && error == first,
    )
    assert_true(
      budget.reserve(WorkingBytes, 1L) is Err(error) && error == first,
    )
    assert_eq(budget.snapshot().resident.working_bytes, 0L)
    assert_eq(budget.snapshot().active_leases, 0L)
  }
}

///|
test "resident leases release after failure and preserve their high-water marks" {
  let budget = Budget::new(test_limits(Enforced, Some(10L)))
  let first = budget.reserve(CacheBytes, 6L).unwrap()
  let second = budget.reserve(CacheBytes, 4L).unwrap()
  assert_eq(budget.snapshot().resident.cache_bytes, 10L)
  first.release()
  first.release()
  assert_eq(budget.snapshot().resident.cache_bytes, 4L)
  assert_eq(budget.snapshot().resident_peak.cache_bytes, 10L)
  assert_eq(budget.snapshot().active_leases, 1L)
  assert_true(
    budget.reserve(CacheBytes, 7L)
    is Err(
      LimitExceeded(Resident(CacheBytes), used=4L, requested=7L, limit=10L)
    ),
  )
  second.release()
  assert_eq(budget.snapshot().resident.cache_bytes, 0L)
  assert_eq(budget.snapshot().active_leases, 0L)
  assert_eq(budget.snapshot().resident_peak.cache_bytes, 10L)
  assert_true(budget.close() is Ok(_))
  assert_true(budget.failure() is Some(LimitExceeded(_, ..)))
}

///|
test "all resident dimensions keep independent current and peak usage" {
  let budget = Budget::new(test_limits(Enforced, Some(8L)))
  let leases : Array[BudgetLease] = []
  for kind in resident_kinds() {
    leases.push(budget.reserve(kind, 8L).unwrap())
  }
  let full = budget.snapshot()
  assert_eq(full.resident.cache_bytes, 8L)
  assert_eq(full.resident.working_bytes, 8L)
  assert_eq(full.resident.temporary_bytes, 8L)
  assert_eq(full.resident.ir_bytes, 8L)
  for lease in leases {
    lease.release()
  }
  let empty = budget.snapshot()
  assert_eq(empty.resident.cache_bytes, 0L)
  assert_eq(empty.resident.working_bytes, 0L)
  assert_eq(empty.resident.temporary_bytes, 0L)
  assert_eq(empty.resident.ir_bytes, 0L)
  assert_true(empty.resident_peak == full.resident)
  assert_true(budget.close() is Ok(_))
}

///|
test "close does not forgive outstanding leases and cleanup remains valid afterwards" {
  let budget = Budget::new(test_limits(Enforced, Some(5L)))
  let lease = budget.reserve(WorkingBytes, 5L).unwrap()
  assert_true(budget.close() is Err(OutstandingLeases(1L)))
  assert_true(budget.snapshot().closed)
  assert_eq(budget.snapshot().resident.working_bytes, 5L)
  assert_true(budget.charge(ParseWork, 1L) is Err(OutstandingLeases(1L)))
  lease.release()
  lease.release()
  assert_eq(budget.snapshot().resident.working_bytes, 0L)
  assert_true(budget.close() is Ok(_))
  assert_true(budget.failure() is Some(OutstandingLeases(1L)))
}

///|
test "a clean close is idempotent and rejects even zero new work" {
  let budget = Budget::new(test_limits(Enforced, Some(0L)))
  let empty = budget.reserve(TemporaryBytes, 0L).unwrap()
  assert_eq(budget.snapshot().active_leases, 0L)
  assert_true(budget.close() is Ok(_))
  assert_true(budget.close() is Ok(_))
  empty.release()
  assert_true(budget.reserve(TemporaryBytes, 0L) is Err(Closed))
  assert_true(budget.charge(ReadTrafficBytes, 0L) is Err(Closed))
}

///|
test "borrowed nested handles share cumulative limits and resident cleanup" {
  let parent = Budget::new(test_limits(Enforced, Some(10L)))
  let child = parent
  parent.charge(InflateBytes, 7L).unwrap()
  let lease = child.reserve(TemporaryBytes, 6L).unwrap()
  assert_eq(parent.snapshot().resident.temporary_bytes, 6L)
  assert_true(
    child.charge(InflateBytes, 4L)
    is Err(
      LimitExceeded(Cumulative(InflateBytes), used=7L, requested=4L, limit=10L)
    ),
  )
  assert_true(parent.failure() == child.failure())
  assert_eq(parent.snapshot().cumulative.inflate_bytes, 7L)
  lease.release()
  assert_eq(parent.snapshot().resident.temporary_bytes, 0L)
}

///|
test "copied lease handles release the same reservation only once" {
  let budget = Budget::new(test_limits(Enforced, Some(7L)))
  let lease = budget.reserve(IrBytes, 7L).unwrap()
  let copy = lease
  copy.release()
  lease.release()
  let sample = budget.snapshot()
  assert_eq(sample.resident.ir_bytes, 0L)
  assert_eq(sample.resident_peak.ir_bytes, 7L)
  assert_eq(sample.active_leases, 0L)
  assert_true(sample.first_error is None)
  assert_true(budget.close() is Ok(_))
}

///|
test "overflowing reservation preserves capacity and can still be cleaned up" {
  let budget = Budget::new(test_limits(MeasurementOnly, None))
  let lease = budget.reserve(WorkingBytes, MAX_COUNTER).unwrap()
  assert_true(
    budget.reserve(WorkingBytes, 1L)
    is Err(
      ArithmeticOverflow(Resident(WorkingBytes), used=MAX_COUNTER, requested=1L)
    ),
  )
  let sample = budget.snapshot()
  assert_eq(sample.resident.working_bytes, MAX_COUNTER)
  assert_eq(sample.resident_peak.working_bytes, MAX_COUNTER)
  assert_eq(sample.active_leases, 1L)
  lease.release()
  assert_eq(budget.snapshot().resident.working_bytes, 0L)
  assert_eq(budget.snapshot().active_leases, 0L)
  assert_true(budget.close() is Ok(_))
}
