///|
/// Consumer-side adapter contract: operation failure remains reported and
/// queryable, while completed resource cleanup can retire its callback.
async fn cleanup_callback_result(
  owner : @session_temp.TempOwner,
) -> Result[Unit, @session_temp.TempFailure] noraise + nocancel {
  let outcome = owner.close()
  if owner.cleanup_complete() {
    Ok(())
  } else {
    match outcome {
      Err(error) => Err(error)
      Ok(_) => Err(State("temporary cleanup returned without completion"))
    }
  }
}

///|
async test "cross-package cleanup retires after an operation error without erasing that error" {
  let account = @budget.Budget::new(@budget.BudgetLimits::measurement_only())
  account.tighten_resident_limit(TemporaryBytes, 10L).unwrap()
  let reports : Array[@session_temp.TempFailure] = []
  let owner = @session_temp.TempOwner::create(account, capacity=3L, report_failure=error => {
    reports.push(error)
  }).unwrap()
  defer ignore(owner.close())
  owner.append(b"abc").unwrap()
  assert_true(
    owner.append(b"d")
    is Err(
      Budget(
        LimitExceeded(Resident(TemporaryBytes), used=3L, requested=1L, limit=3L)
      )
    ),
  )
  let original = owner.failure().unwrap()
  assert_false(owner.cleanup_complete())
  assert_true(cleanup_callback_result(owner) is Ok(_))
  assert_true(owner.cleanup_complete())
  assert_true(owner.failure() == Some(original))
  assert_true(owner.close() is Err(error) && error == original)
  assert_eq(reports.length(), 1)
  assert_true(reports[0] == original)
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_eq(account.snapshot().resident_peak.temporary_bytes, 3L)
  account.close().unwrap()
}

///|
async test "cross-package shared cap rejects a second owner before payload write and both clean" {
  let account = @budget.Budget::new(@budget.BudgetLimits::measurement_only())
  let initial = account.snapshot()
  let borrowed = account
  borrowed.tighten_resident_limit(TemporaryBytes, 5L).unwrap()
  let first = @session_temp.TempOwner::create(account, capacity=5L).unwrap()
  defer ignore(first.close())
  let second = @session_temp.TempOwner::create(borrowed, capacity=5L).unwrap()
  defer ignore(second.close())
  first.append(b"abc").unwrap()
  assert_true(
    second.append(b"def")
    is Err(
      Budget(
        LimitExceeded(Resident(TemporaryBytes), used=3L, requested=3L, limit=5L)
      )
    ),
  )
  assert_eq(second.length(), 0L)
  assert_eq(account.snapshot().resident.temporary_bytes, 3L)
  assert_eq(account.snapshot().resident_peak.temporary_bytes, 3L)
  let resource_error = account.failure().unwrap()
  assert_true(second.failure() == Some(Budget(resource_error)))
  assert_true(cleanup_callback_result(first) is Ok(_))
  assert_true(cleanup_callback_result(second) is Ok(_))
  assert_true(first.cleanup_complete())
  assert_true(second.cleanup_complete())
  assert_true(account.failure() == Some(resource_error))
  assert_true(initial.limits.temporary_bytes is None)
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_eq(account.snapshot().active_leases, 0L)
  account.close().unwrap()
}

///|
async test "cross-package zero cap allows an empty store while forbidding payload growth" {
  let account = @budget.Budget::new(@budget.BudgetLimits::measurement_only())
  account.tighten_resident_limit(TemporaryBytes, 0L).unwrap()
  let owner = @session_temp.TempOwner::create(account, capacity=0L).unwrap()
  defer ignore(owner.close())
  assert_false(owner.cleanup_complete())
  owner.append(b"").unwrap()
  owner.seal().unwrap()
  let range = owner.range(0L, 0L).unwrap()
  assert_eq(range.length, 0L)
  let buffer = FixedArray::make(1, b'!')
  assert_true(owner.read_at(range, 0L, buffer) is Ok(0))
  assert_eq(buffer[0], b'!')
  assert_eq(account.snapshot().active_leases, 0L)
  assert_true(cleanup_callback_result(owner) is Ok(_))
  assert_true(owner.cleanup_complete())
  account.close().unwrap()
}
