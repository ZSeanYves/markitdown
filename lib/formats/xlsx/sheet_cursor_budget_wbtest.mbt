///|
fn sheet_cursor_test_context(
  account : @budget.Budget,
  leases : Array[@budget.BudgetLease],
) -> @budget.BudgetContext {
  @budget.BudgetContext::new(account, fn(kind, amount) {
    match account.reserve(kind, amount) {
      Err(error) => Err(error)
      Ok(lease) => {
        leases.push(lease)
        Ok(())
      }
    }
  })
}

///|
async test "XLSX worksheet cursor budget failure remains typed without whole-part fallback" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml", "<Types><Default Extension=\"xml\" ContentType=\"application/xml\"/></Types>",
    ),
    (
      "xl/worksheets/sheet1.xml", "<worksheet><sheetData><row r=\"1\"><c r=\"A1\"><v>1</v></c></row></sheetData></worksheet>",
    ),
  ])
  let control = @budget.Budget::new(@budget.BudgetLimits::measurement_only())
  let control_leases : Array[@budget.BudgetLease] = []
  let control_archive = @dzip.open_zip(
    bytes,
    budget_context=sheet_cursor_test_context(control, control_leases),
  )
  ignore(@ox.open_ooxml_archive(control_archive))
  let prior_work = control.snapshot().cumulative.parse_work
  assert_true(prior_work > 0L)
  for lease in control_leases {
    lease.release()
  }
  control.close().unwrap()
  let account = @budget.Budget::new(
    @budget.BudgetLimits::new(
      MeasurementOnly,
      inflate_bytes=None,
      parse_work=Some(prior_work),
      output_utf8_bytes=None,
      source_metadata_bytes=None,
      rag_metadata_bytes=None,
      read_traffic_bytes=None,
      cache_bytes=None,
      working_bytes=None,
      temporary_bytes=None,
      ir_bytes=None,
    ).unwrap(),
  )
  let leases : Array[@budget.BudgetLease] = []
  defer (for lease in leases {
    lease.release()
  })
  let archive = @dzip.open_zip(
    bytes,
    budget_context=sheet_cursor_test_context(account, leases),
  )
  let pkg = @ox.open_ooxml_archive(archive)
  assert_eq(account.snapshot().cumulative.parse_work, prior_work)
  let diagnostics = @core.empty_diagnostics()
  let outcome = try
    xlsx_parse_sheet_view(
      pkg,
      xlsx_wbtest_sheet_info(),
      [],
      xlsx_parse_styles(""),
      false,
      true,
      true,
      1,
      10,
      10,
      diagnostics,
      prefer_streaming_scan=true,
    )
    |> Ok
  catch {
    error => Err(error)
  }
  match outcome {
    Err(
      BudgetExceeded(
        LimitExceeded(Cumulative(ParseWork), used~, requested~, limit~)
      )
    ) => {
      assert_eq(used, prior_work)
      assert_eq(limit, prior_work)
      assert_true(requested > 0L)
    }
    _ =>
      fail("worksheet cursor admission must preserve typed ParseWork failure")
  }
  assert_true(diagnostics.fallback_trace.is_empty())
  assert_true(@dzip.archive_hard_failure(archive) is Some(_))
}
