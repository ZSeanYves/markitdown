///|
test "output archive asset lookup preserves safe dot segment handling" {
  assert_eq(
    normalize_output_asset_entry("./ObjectReplacements/Object 1"),
    Some("ObjectReplacements/Object 1"),
  )
  assert_eq(
    normalize_output_asset_entry("Pictures/./image.png"),
    Some("Pictures/image.png"),
  )
  assert_eq(normalize_output_asset_entry("Pictures/../image.png"), None)
  assert_eq(normalize_output_asset_entry("/Pictures/image.png"), None)
}

///|
async test "existing output assets count each logical duplicate and recheck a smaller cached cap" {
  for total_cap in [135L, 136L] {
    let limits = @product.make_resource_limits(
      2000,
      50,
      100000,
      max_asset_bytes=68L,
      max_total_asset_bytes=total_cap,
    )
    let options = make_convert_options(Balanced, Markdown, Some(Xlsx), limits)
    let owner = @input.begin_input_session(
      @input.input_from_path(
        "samples/fixtures/contracts/xlsx/xlsx_advanced_synthetic.xlsx",
      ),
    )
    defer @input.end_input_session(owner)
    let plan = detect_and_resolve_execution_plan(owner.source, options).unwrap().2
    let context = @parser.parse_context_with_input_source(
      parse_context_from_execution_plan(Xlsx, plan),
      owner.source,
    )
    let parsed = parse_with_route_probe_artifact(
        plan.prepared_source,
        Xlsx,
        context,
        @formats.builtin_registry(),
        plan.probe_artifacts,
      )
      .unwrap()
      .unwrap()
    assert_eq(parsed.assets.length(), 1)
    assert_true(parsed.assets[0].payload is None)
    let account = @input.input_source_budget_context(owner.source).unwrap().account
    let before = account.snapshot()
    let result = materialize_existing_output_assets(
      owner.source,
      Xlsx,
      [parsed.assets[0], parsed.assets[0]],
      plan.probe_artifacts,
      limits,
    )
    let after = account.snapshot()
    // The same checked archive cache serves two logical output records.
    assert_eq(
      after.cumulative.inflate_bytes,
      before.cumulative.inflate_bytes + 68L,
    )
    if total_cap == 135L {
      assert_true(
        result
        is Err(
          ResourceLimitExceeded(
            kind="total_asset_bytes",
            observed=136L,
            limit=135L
          )
        ),
      )
    } else {
      let assets = result.unwrap()
      assert_eq(assets.length(), 2)
      guard assets[0].payload is Some(Bytes(first)) else {
        fail("first duplicate must own bytes")
      }
      guard assets[1].payload is Some(Bytes(second)) else {
        fail("second duplicate must own bytes")
      }
      assert_eq(first, second)
      assert_eq(assets[0].asset_id, parsed.assets[0].asset_id)
      let smaller = @product.make_resource_limits(
        2000,
        50,
        100000,
        max_asset_bytes=67L,
      )
      assert_true(
        materialize_existing_output_assets(
          owner.source,
          Xlsx,
          [parsed.assets[0]],
          plan.probe_artifacts,
          smaller,
        )
        is Err(
          ResourceLimitExceeded(
            kind="single_asset_bytes",
            observed=68L,
            limit=67L
          )
        ),
      )
      let after_reject = account.snapshot()
      assert_eq(
        after_reject.cumulative.read_traffic_bytes,
        after.cumulative.read_traffic_bytes,
      )
      assert_eq(
        after_reject.cumulative.inflate_bytes,
        after.cumulative.inflate_bytes,
      )
      assert_eq(after_reject.resident.cache_bytes, after.resident.cache_bytes)
    }
  }
}
