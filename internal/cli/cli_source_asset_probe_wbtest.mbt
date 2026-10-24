///|
async test "SourcePath only missing ENOENT may become a placeholder; notdir loop and denied traversal are hard IO" {
  let root = test_tmp_root() + "/cli-source-asset-typed-probe-v3"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  @fs.write_bytes_to_file(root + "/not-a-directory", b"file")
  @asset_fs.symlink(target="loop.png", root + "/loop.png")
  defer @asset_fs.remove(root + "/loop.png")
  @asset_fs.mkdir(root + "/denied")
  @asset_fs.write_file(root + "/denied/asset.png", b"secret")
  @asset_fs.chmod(root + "/denied", 0o000)
  defer @asset_fs.chmod(root + "/denied", 0o700)
  for relative in ["not-a-directory/asset.png", "loop.png", "denied/asset.png"] {
    let session = @input.begin_input_session(@input.input_from_text("root"))
    defer @input.end_input_session(session)
    let result = cli_prepare_source_assets(
      root + "/input.html",
      session.source,
      [cli_test_source_asset("one", relative)],
      @convert.default_resource_limits(),
      @core.empty_diagnostics(),
    )
    guard result is Err(failure) else {
      fail("real IO was silently classified as missing: " + relative)
    }
    assert_true(failure.kind == OutputFailure)
    assert_eq(cli_failure_exit_code(failure), 6)
    assert_true(
      @input.input_source_failure(session.source) is Some(InputError(_)),
    )
    let snapshot = @input.input_source_budget_context(session.source).unwrap().account.snapshot()
    assert_eq(snapshot.cumulative.read_traffic_bytes, 0L)
    assert_eq(snapshot.resident.cache_bytes, 0L)
    assert_eq(snapshot.resident.working_bytes, 0L)
  }
}

///|
async test "empty opened SourcePath needs no collection buffer with explicit zero Working and Cache caps" {
  let root = test_tmp_root() + "/cli-source-asset-empty-zero"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  @fs.write_bytes_to_file(root + "/empty.png", b"")
  let account = cli_test_asset_account(Some(0L), Some(0L))
  let session = @input.begin_input_session(
    @input.input_from_text("root"),
    budget=account,
  )
  defer @input.end_input_session(session)
  let assets = cli_prepare_source_assets(
    root + "/input.html",
    session.source,
    [cli_test_source_asset("one", "empty.png")],
    @convert.default_resource_limits(),
    @core.empty_diagnostics(),
  ).unwrap()
  guard assets[0].payload is Some(Bytes(payload)) else {
    fail("owned empty bytes required")
  }
  assert_eq(payload, b"")
  assert_true(account.failure() is None)
  let snapshot = account.snapshot()
  assert_eq(snapshot.cumulative.read_traffic_bytes, 0L)
  assert_eq(snapshot.resident.working_bytes, 0L)
  assert_eq(snapshot.resident_peak.working_bytes, 0L)
  assert_eq(snapshot.resident.cache_bytes, 0L)
  assert_eq(snapshot.resident_peak.cache_bytes, 0L)
  assert_eq(snapshot.active_leases, 0L)
  persist_cli_assets(root + "/input.html", root + "/out/result.md", assets)
  assert_eq(@fs.read_file_to_bytes(root + "/out/assets/one.bin"), b"")
}
