///|
const ARCHIVE_ASSET_DEMAND_TEST_ROOT : String = ".tmp/tests/cli/archive-asset-demand"

///|
fn archive_asset_demand_options(
  limits : @convert.ResourceLimits,
) -> @convert.ConvertOptions {
  @convert.make_convert_options(Balanced, Markdown, Some(Xlsx), limits)
}

///|
fn archive_asset_demand_path() -> String {
  "samples/fixtures/contracts/xlsx/xlsx_advanced_synthetic.xlsx"
}

///|
async test "archive output demand current smaller cap is typed resource failure" {
  let source = @input.begin_input_session(
    @input.input_from_path(archive_asset_demand_path()),
  )
  defer @input.end_input_session(source)
  let result = @convert.convert_input(
    source.source,
    archive_asset_demand_options(@convert.default_resource_limits()),
  ).unwrap()
  assert_eq(result.assets.length(), 1)
  assert_true(result.assets[0].payload is None)
  let limits = @product.make_resource_limits(
    2000,
    50,
    100000,
    max_asset_bytes=1L,
  )
  let execution = @convert.convert_input_with_provenance(
    source.source,
    archive_asset_demand_options(limits),
    output_assets=ExistingOutputAssets,
  )
  guard execution is Err(error) else {
    fail("current per-asset cap must reject the 68-byte logical output asset")
  }
  let failure = cli_failure_from_convert_error(
    cli_options(archive_asset_demand_path(), None, Some(Xlsx), Markdown),
    error,
  )
  assert_eq(cli_failure_exit_code(failure), 5)
  assert_true(
    error
    is ResourceLimitExceeded(kind="single_asset_bytes", observed=68L, limit=1L),
  )
}

///|
async test "archive output demand exhausted shared read traffic stays in same account" {
  let limits = @convert.default_resource_limits()
  let baseline = @input.begin_input_session(
    @input.input_from_path(archive_asset_demand_path()),
  )
  defer @input.end_input_session(baseline)
  ignore(
    @convert.convert_input(
      baseline.source,
      archive_asset_demand_options(limits),
    ).unwrap(),
  )
  let exact = @input.input_source_budget_context(baseline.source).unwrap().account.snapshot().cumulative.read_traffic_bytes
  @input.end_input_session(baseline)
  let account = @budget.Budget::new(
    @budget.BudgetLimits::new(
      MeasurementOnly,
      inflate_bytes=None,
      parse_work=None,
      output_utf8_bytes=None,
      source_metadata_bytes=None,
      rag_metadata_bytes=None,
      read_traffic_bytes=Some(exact),
      cache_bytes=None,
      working_bytes=None,
      temporary_bytes=None,
      ir_bytes=None,
    ).unwrap(),
  )
  let source = @input.begin_input_session(
    @input.input_from_path(archive_asset_demand_path()),
    budget=account,
  )
  defer @input.end_input_session(source)
  let execution = @convert.convert_input_with_provenance(
    source.source,
    archive_asset_demand_options(limits),
    output_assets=ExistingOutputAssets,
  )
  guard execution is Err(error) else {
    fail("asset read must share the exhausted conversion account")
  }
  assert_true(error is ResourceLimitExceeded(kind="read_traffic_bytes", ..))
  assert_eq(
    cli_failure_exit_code(
      cli_failure_from_convert_error(
        cli_options(archive_asset_demand_path(), None, Some(Xlsx), Markdown),
        error,
      ),
    ),
    5,
  )
  assert_eq(account.snapshot().cumulative.read_traffic_bytes, exact)
  assert_true(
    @input.input_source_failure(source.source) is Some(BudgetFailure(_)),
  )
}

///|
async fn archive_asset_demand_corrupt_xlsx() -> Bytes {
  let original = @fs.read_file_to_bytes(archive_asset_demand_path())
  let archive = @dzip.open_zip(original)
  let entries : Array[(String, Bytes)] = []
  for entry in @dzip.list_entries(archive) {
    entries.push((entry.name, @dzip.read_entry(archive, entry.name)))
  }
  let stored = @dzip.build_store_zip_bytes(entries)
  let slice = @dzip.read_entry_data_slice(
    @dzip.open_zip(stored),
    "xl/media/red.png",
  )
  let bytes = stored.to_array()
  bytes[slice.data_start] = (bytes[slice.data_start].to_int() ^ 1).to_byte()
  Bytes::from_array(bytes)
}

///|
async test "archive output demand publishes owned Bytes and accounts actual read inflate and cache" {
  let limits = @convert.default_resource_limits()
  let baseline = @input.begin_input_session(
    @input.input_from_path(archive_asset_demand_path()),
  )
  defer @input.end_input_session(baseline)
  let metadata_only = @convert.convert_input_with_provenance(
    baseline.source,
    archive_asset_demand_options(limits),
  ).unwrap()
  assert_true(metadata_only.result.assets[0].payload is None)
  let before = @input.input_source_budget_context(baseline.source).unwrap().account.snapshot()
  let owner = @input.begin_input_session(
    @input.input_from_path(archive_asset_demand_path()),
  )
  defer @input.end_input_session(owner)
  let execution = @convert.convert_input_with_provenance(
    owner.source,
    archive_asset_demand_options(limits),
    output_assets=ExistingOutputAssets,
  ).unwrap()
  assert_eq(execution.result.content, metadata_only.result.content)
  assert_eq(
    execution.result.assets[0].asset_id,
    metadata_only.result.assets[0].asset_id,
  )
  assert_eq(
    execution.result.assets[0].path,
    metadata_only.result.assets[0].path,
  )
  guard execution.result.assets[0].payload is Some(Bytes(payload)) else {
    fail("owned archive payload required")
  }
  assert_eq(payload.length(), 68)
  let after = @input.input_source_budget_context(owner.source).unwrap().account.snapshot()
  assert_true(
    after.cumulative.read_traffic_bytes > before.cumulative.read_traffic_bytes,
  )
  assert_eq(
    after.cumulative.inflate_bytes,
    before.cumulative.inflate_bytes + 68L,
  )
  assert_true(after.resident.cache_bytes >= before.resident.cache_bytes + 68L)
  let root = ARCHIVE_ASSET_DEMAND_TEST_ROOT + "/candidate-owned"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let output = root + "/result.md"
  let before_persist = after.cumulative.read_traffic_bytes
  ignore(
    cli_render_convert_result(
      cli_options(
        archive_asset_demand_path(),
        Some(output),
        Some(Xlsx),
        Markdown,
      ),
      execution.result,
      owner.source,
      limits,
    ).unwrap(),
  )
  assert_eq(
    @fs.read_file_to_bytes(
      root + "/" + execution.result.assets[0].path.unwrap(),
    ),
    payload,
  )
  assert_eq(
    @input.input_source_budget_context(owner.source).unwrap().account.snapshot().cumulative.read_traffic_bytes,
    before_persist,
  )
}

///|
async test "archive output demand stable CRC failure is IO6 while library and stdout remain metadata only" {
  let root = ARCHIVE_ASSET_DEMAND_TEST_ROOT + "/stable-crc"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let input = root + "/corrupt.xlsx"
  @fs.write_bytes_to_file(input, archive_asset_demand_corrupt_xlsx())
  let limits = @convert.default_resource_limits()
  let library = @convert.convert_input(
    @input.input_from_path(input),
    archive_asset_demand_options(limits),
  ).unwrap()
  assert_true(library.assets[0].payload is None)
  let stdout = run_cli(cli_options(input, None, Some(Xlsx), Markdown)).unwrap()
  assert_true(stdout.contains("Asset not materialized on stdout"))
  let output = root + "/candidate/result.md"
  let result = run_cli_impl(
    cli_options(input, Some(output), Some(Xlsx), Markdown),
    false,
  )
  guard result is Err(failure) else {
    fail("corrupt asset must fail before output is written")
  }
  assert_eq(cli_failure_exit_code(failure), 6)
  assert_true(failure.message.contains("crc32 mismatch"))
  assert_false(@fs.path_exists(output))
}

///|
async test "archive output demand owned nested container payloads need no extra archive reads" {
  let limits = @convert.default_resource_limits()
  let bytes = cli_output_nested_office_zip_bytes()
  let owner = @input.begin_input_session(
    @input.input_from_bytes(bytes, source_name="nested.zip"),
  )
  defer @input.end_input_session(owner)
  let opts = @convert.make_convert_options(
    Balanced,
    Markdown,
    Some(Zip),
    limits,
  )
  let execution = @convert.convert_input_with_provenance(
    owner.source,
    opts,
    output_assets=ExistingOutputAssets,
  ).unwrap()
  assert_true(execution.result.assets.length() > 0)
  for asset in execution.result.assets {
    assert_true(asset.payload is Some(Bytes(_)))
  }
  let before = @input.input_source_budget_context(owner.source).unwrap().account.snapshot()
  let root = ARCHIVE_ASSET_DEMAND_TEST_ROOT + "/nested"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let output = root + "/result.md"
  ignore(
    cli_render_convert_result(
      cli_options("nested.zip", Some(output), Some(Zip), Markdown),
      execution.result,
      owner.source,
      limits,
    ).unwrap(),
  )
  let after = @input.input_source_budget_context(owner.source).unwrap().account.snapshot()
  assert_eq(
    after.cumulative.read_traffic_bytes,
    before.cumulative.read_traffic_bytes,
  )
  assert_eq(after.cumulative.inflate_bytes, before.cumulative.inflate_bytes)
}

///|
async test "archive output demand parent failure and closed owner block additional reads" {
  for closed in [false, true] {
    let owner = @input.begin_input_session(
      @input.input_from_path(archive_asset_demand_path()),
    )
    defer @input.end_input_session(owner)
    let account = @input.input_source_budget_context(owner.source).unwrap().account
    if closed {
      @input.end_input_session(owner)
    } else {
      @input.record_input_failure(owner.source, "controlled original failure")
    }
    let before = account.snapshot().cumulative.read_traffic_bytes
    let result = @convert.convert_input_with_provenance(
      owner.source,
      archive_asset_demand_options(@convert.default_resource_limits()),
      output_assets=ExistingOutputAssets,
    )
    assert_true(result is Err(_))
    assert_eq(account.snapshot().cumulative.read_traffic_bytes, before)
  }
}
