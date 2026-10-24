///|
test "growing copied lease handles refunds the shared aggregate exactly once" {
  let account = @resource_budget.Budget::new(
    @resource_budget.BudgetLimits::measurement_only(),
  )
  account.tighten_resident_limit(TemporaryBytes, 1001L).unwrap()
  let lease = account.reserve(TemporaryBytes, 1L).unwrap()
  let copy = lease
  let before = account.snapshot()
  lease.grow(0L).unwrap()
  for _ in 0..<1000 {
    copy.grow(1L).unwrap()
  }
  assert_eq(before.resident.temporary_bytes, 1L)
  assert_eq(before.resident_peak.temporary_bytes, 1L)
  assert_eq(before.active_leases, 1L)
  assert_eq(account.snapshot().resident.temporary_bytes, 1001L)
  assert_eq(account.snapshot().active_leases, 1L)
  lease.release()
  copy.release()
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_eq(account.snapshot().resident_peak.temporary_bytes, 1001L)
  assert_eq(account.snapshot().active_leases, 0L)
  account.close().unwrap()
}

///|
test "grow rejects aggregate cap excess before changing either lease or existing peers" {
  let account = @resource_budget.Budget::new(
    @resource_budget.BudgetLimits::measurement_only(),
  )
  account.tighten_resident_limit(TemporaryBytes, 5L).unwrap()
  let a = account.reserve(TemporaryBytes, 2L).unwrap()
  let b = account.reserve(TemporaryBytes, 2L).unwrap()
  a.grow(1L).unwrap()
  let sample = account.snapshot()
  assert_true(
    b.grow(1L)
    is Err(
      LimitExceeded(Resident(TemporaryBytes), used=5L, requested=1L, limit=5L)
    ),
  )
  assert_true(account.snapshot().resident == sample.resident)
  assert_true(account.snapshot().resident_peak == sample.resident_peak)
  assert_eq(account.snapshot().active_leases, sample.active_leases)
  a.release()
  b.release()
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
test "grow preserves overflow and first failure while original leases remain cleanable" {
  let account = @resource_budget.Budget::new(
    @resource_budget.BudgetLimits::measurement_only(),
  )
  let lease = account.reserve(TemporaryBytes, 9223372036854775807L).unwrap()
  assert_true(
    lease.grow(1L)
    is Err(
      ArithmeticOverflow(
        Resident(TemporaryBytes),
        used=9223372036854775807L,
        requested=1L
      )
    ),
  )
  assert_eq(account.snapshot().resident.temporary_bytes, 9223372036854775807L)
  assert_eq(account.snapshot().active_leases, 1L)
  lease.release()
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_true(lease.grow(0L) is Err(ArithmeticOverflow(_, ..)))
}

///|
test "zero and released leases cannot be revived and negative growth is typed" {
  for zero in [true, false] {
    let account = @resource_budget.Budget::new(
      @resource_budget.BudgetLimits::measurement_only(),
    )
    let lease = account
      .reserve(TemporaryBytes, if zero { 0L } else { 1L })
      .unwrap()
    if !zero {
      lease.release()
    }
    assert_true(lease.grow(1L) is Err(ReleasedLease))
    assert_eq(account.snapshot().resident.temporary_bytes, 0L)
    assert_eq(account.snapshot().active_leases, 0L)
  }
  let account = @resource_budget.Budget::new(
    @resource_budget.BudgetLimits::measurement_only(),
  )
  let lease = account.reserve(WorkingBytes, 1L).unwrap()
  assert_true(
    lease.grow(-1L) is Err(NegativeAmount(Resident(WorkingBytes), -1L)),
  )
  assert_eq(account.snapshot().resident.working_bytes, 1L)
  lease.release()
  let closed = @resource_budget.Budget::new(
    @resource_budget.BudgetLimits::measurement_only(),
  )
  let zero = closed.reserve(TemporaryBytes, 0L).unwrap()
  closed.close().unwrap()
  assert_true(zero.grow(1L) is Err(Closed))
  assert_eq(closed.snapshot().resident.temporary_bytes, 0L)
  assert_eq(closed.snapshot().active_leases, 0L)
}
