///|
async test "presentation budget failure stops before projecting prior missing relationships" {
  let account = @budget.Budget::new(@budget.BudgetLimits::measurement_only())
  let leases : Array[@budget.BudgetLease] = []
  defer {
    for lease in leases {
      lease.release()
    }
    ignore(account.close())
  }
  let context = @budget.BudgetContext::new(account, (kind, amount) => {
    match account.reserve(kind, amount) {
      Err(error) => Err(error)
      Ok(lease) => {
        leases.push(lease)
        Ok(())
      }
    }
  })
  let ctx = presentation_cursor_fixture(
    b"<p:presentation><p:sldId id='257' r:id='missing'/><p:sldId id='258' r:id='rId1'/></p:presentation>",
    budget_context=context,
  )
  let graph = build_pptx_part_graph(ctx)
  let baseline = account.snapshot().resident.cache_bytes
  let warnings_before = ctx.warnings.length()
  // Admit the first selected row's three retained strings, then exhaust the
  // same ledger on the second row, before any relationship projection runs.
  let first_row_payload = 42L
  account
  .tighten_resident_limit(CacheBytes, baseline + first_row_payload)
  .unwrap()
  let rejected = try {
    ignore(parse_source_presentation(ctx, graph))
    false
  } catch {
    PptxError::OoxmlFailure(_) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(ctx.warnings.length(), warnings_before)
  assert_true(@dzip.archive_hard_failure(ctx.pkg.archive) is Some(_))
  assert_eq(
    account.snapshot().resident.cache_bytes,
    baseline + first_row_payload,
  )
  match account.failure() {
    Some(LimitExceeded(Resident(CacheBytes), used~, requested~, limit~)) => {
      assert_eq(used, baseline + first_row_payload)
      assert_eq(requested, 36L)
      assert_eq(limit, baseline + first_row_payload)
    }
    _ => fail("expected the original shared Cache budget failure")
  }
}
