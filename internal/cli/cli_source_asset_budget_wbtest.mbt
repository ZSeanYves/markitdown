///|
async test "CLI SourcePath actual 33MiB plus one asset is a typed resource failure before output" {
  let root = test_tmp_root() + "/cli-source-asset-single-limit"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  write_utf8_text(
    root + "/input.html",
    "<p><img src=\"large.bin\" alt=\"large\"></p>",
  )
  @fs.write_bytes_to_file(root + "/large.bin", Bytes::new(33 * 1024 * 1024 + 1))
  let result = run_cli_impl(
    cli_options(
      root + "/input.html",
      Some(root + "/out/result.md"),
      Some(Html),
      Markdown,
    ),
    false,
  )
  match result {
    Err(failure) => {
      assert_true(failure.kind == ResourceFailure)
      assert_true(failure.message.contains("single_asset_bytes"))
    }
    Ok(_) =>
      fail(
        "33MiB+1 SourcePath asset was accepted above the existing 32MiB policy",
      )
  }
  assert_false(@fs.path_exists(root + "/out/result.md"))
}

///|
async test "CLI SourcePath actual aggregate 128MiB plus one is a typed resource failure before output" {
  let root = test_tmp_root() + "/cli-source-asset-total-limit"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let html : Array[String] = []
  let payload = Bytes::new(32 * 1024 * 1024)
  for index in 0..<4 {
    let name = "asset-" + index.to_string() + ".bin"
    @fs.write_bytes_to_file(root + "/" + name, payload)
    html.push("<p><img src=\"" + name + "\" alt=\"asset\"></p>")
  }
  @fs.write_bytes_to_file(root + "/last.bin", b"x")
  html.push("<p><img src=\"last.bin\" alt=\"last\"></p>")
  write_utf8_text(root + "/input.html", html.join("\n"))
  let result = run_cli_impl(
    cli_options(
      root + "/input.html",
      Some(root + "/out/result.md"),
      Some(Html),
      Markdown,
    ),
    false,
  )
  match result {
    Err(failure) => {
      assert_true(failure.kind == ResourceFailure)
      assert_true(failure.message.contains("total_asset_bytes"))
    }
    Ok(_) =>
      fail(
        "128MiB+1 SourcePath aggregate was accepted above the existing total policy",
      )
  }
  assert_false(@fs.path_exists(root + "/out/result.md"))
}

///|
async test "CLI SourcePath small existing payload persists exact bytes and missing source remains explicit" {
  let root = test_tmp_root() + "/cli-source-asset-controls"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  write_utf8_text(
    root + "/input.html",
    "<p><img src=\"small.png\" alt=\"small\"></p><p><img src=\"missing.png\" alt=\"missing\"></p>",
  )
  @fs.write_bytes_to_file(root + "/small.png", b"exact-small-asset")
  let result = run_cli_impl(
    cli_options(
      root + "/input.html",
      Some(root + "/out/result.md"),
      Some(Html),
      Markdown,
    ),
    false,
  ).unwrap()
  assert_true(result.contains("![small](assets/image01.png)"), msg=result)
  assert_true(result.contains("Asset unavailable: missing.png"), msg=result)
  assert_eq(
    @fs.read_file_to_bytes(root + "/out/assets/image01.png"),
    b"exact-small-asset",
  )
  assert_false(@fs.path_exists(root + "/out/assets/image02.png"))
}

///|
async test "batch SourcePath policy rejects an actual oversized asset with resource category" {
  let root = test_tmp_root() + "/cli-source-asset-batch-limit"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  write_utf8_text(
    root + "/input.html",
    "<p><img src=\"large.bin\" alt=\"large\"></p>",
  )
  @fs.write_bytes_to_file(root + "/large.bin", Bytes::new(33 * 1024 * 1024 + 1))
  let result = run_single_batch_task(
    cli_options(root + "/input.html", None, Some(Html), Markdown),
    root + "/out",
    root + "/input.html",
    "input.html",
  )
  assert_true(result.status == Failed)
  assert_true(result.failure_kind == Some(ResourceFailure))
  assert_true(result.error.unwrap().contains("single_asset_bytes"))
  assert_false(@fs.path_exists(root + "/out/input.html.md"))
}

///|
fn cli_test_source_asset(id : String, path : String) -> @core.AssetRef {
  {
    ..@core.make_asset_ref(Image, id),
    path: Some("assets/" + id + ".bin"),
    payload: Some(SourcePath(path)),
  }
}

///|
fn cli_test_asset_account(working : Int64?, cache : Int64?) -> @budget.Budget {
  @budget.Budget::new(
    @budget.BudgetLimits::new(
      MeasurementOnly,
      inflate_bytes=None,
      parse_work=None,
      output_utf8_bytes=None,
      source_metadata_bytes=None,
      rag_metadata_bytes=None,
      read_traffic_bytes=None,
      cache_bytes=cache,
      working_bytes=working,
      temporary_bytes=None,
      ir_bytes=None,
    ).unwrap(),
  )
}

///|
async test "asset Path inherits parent first failure and closed state without opening the missing child" {
  for closed in [false, true] {
    let session = @input.begin_input_session(
      @input.input_from_text("x"),
      max_bytes=1L,
    )
    defer @input.end_input_session(session)
    let account = @input.input_source_budget_context(session.source).unwrap().account
    if closed {
      @input.end_input_session(session)
    } else {
      @input.record_input_resource_failure(
        session.source,
        @input.make_resource_limit_failure(SingleAssetBytes, 3L, 2L),
      )
    }
    let result = cli_prepare_source_assets(
      "/no-asset-parent/input.txt",
      session.source,
      [cli_test_source_asset("one", "missing.bin")],
      @convert.default_resource_limits(),
      @core.empty_diagnostics(),
    )
    guard result is Err(failure) else {
      fail("failed or closed parent must reject before missing fallback")
    }
    assert_true(
      failure.kind == (if closed { OutputFailure } else { ResourceFailure }),
    )
    if closed {
      assert_eq(
        @input.input_source_error(session.source),
        Some("input session is closed"),
      )
    } else {
      assert_true(
        @input.input_source_failure(session.source) is Some(ResourceLimit(_)),
      )
    }
    assert_eq(account.snapshot().cumulative.read_traffic_bytes, 0L)
    assert_eq(account.snapshot().resident.cache_bytes, 0L)
  }
}

///|
async test "SourcePath preparation shares one account reads each path once and persists owned bytes after unlink" {
  let root = test_tmp_root() + "/cli-source-asset-once"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let payload = b"shared-actual-payload"
  @fs.write_bytes_to_file(root + "/source.bin", payload)
  let session = @input.begin_input_session(@input.input_from_text("root"))
  defer @input.end_input_session(session)
  let account = @input.input_source_budget_context(session.source).unwrap().account
  let diagnostics = @core.empty_diagnostics()
  let assets = cli_prepare_source_assets(
    root + "/input.txt",
    session.source,
    [
      cli_test_source_asset("one", "source.bin"),
      cli_test_source_asset("two", "source.bin"),
    ],
    @convert.default_resource_limits(),
    diagnostics,
  ).unwrap()
  let sampled = account.snapshot()
  assert_eq(sampled.cumulative.read_traffic_bytes, payload.length().to_int64())
  assert_eq(sampled.resident.working_bytes, 0L)
  assert_eq(sampled.resident.cache_bytes, payload.length().to_int64())
  assert_eq(diagnostics.metrics.get("cli_source_asset_read_count"), Some("1"))
  @fs.remove_file(root + "/source.bin")
  assert_true(validate_cli_assets(root + "/missing-root.txt", assets) is Ok(_))
  persist_cli_assets(
    root + "/missing-root.txt",
    root + "/out/result.md",
    assets,
  )
  assert_eq(@fs.read_file_to_bytes(root + "/out/assets/one.bin"), payload)
  assert_eq(@fs.read_file_to_bytes(root + "/out/assets/two.bin"), payload)
  assert_eq(
    account.snapshot().cumulative.read_traffic_bytes,
    sampled.cumulative.read_traffic_bytes,
  )
  @input.end_input_session(session)
  assert_true(account.snapshot().closed)
  assert_eq(account.snapshot().resident.cache_bytes, 0L)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "SourcePath shared working and cache limits fail with typed resource category and release scratch" {
  let root = test_tmp_root() + "/cli-source-asset-shared-budget"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  @fs.write_bytes_to_file(root + "/source.bin", b"xyz")
  for before_read in [true, false] {
    let account = cli_test_asset_account(
      if before_read {
        Some(0L)
      } else {
        None
      },
      if before_read {
        None
      } else {
        Some(0L)
      },
    )
    let session = @input.begin_input_session(
      @input.input_from_text("root"),
      budget=account,
    )
    defer @input.end_input_session(session)
    let result = cli_prepare_source_assets(
      root + "/input.txt",
      session.source,
      [cli_test_source_asset("one", "source.bin")],
      @convert.default_resource_limits(),
      @core.empty_diagnostics(),
    )
    guard result is Err(failure) else {
      fail("explicit shared budget must reject")
    }
    assert_true(failure.kind == ResourceFailure)
    assert_true(
      @input.input_source_failure(session.source) is Some(BudgetFailure(_)),
    )
    assert_eq(
      account.snapshot().cumulative.read_traffic_bytes,
      if before_read {
        0L
      } else {
        3L
      },
    )
    assert_eq(account.snapshot().resident.working_bytes, 0L)
    assert_eq(account.snapshot().resident.cache_bytes, 0L)
    @input.end_input_session(session)
    assert_eq(account.snapshot().active_leases, 0L)
    assert_true(account.snapshot().closed)
  }
}

///|
async test "existing nonregular SourcePath is a hard IO output failure distinct from missing and resource limits" {
  let root = test_tmp_root() + "/cli-source-asset-io-failure"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  @fs.create_dir(root + "/directory.png")
  write_utf8_text(
    root + "/input.html",
    "<p><img src=\"directory.png\" alt=\"directory\"></p>",
  )
  let result = run_cli_impl(
    cli_options(
      root + "/input.html",
      Some(root + "/out/result.md"),
      Some(Html),
      Markdown,
    ),
    false,
  )
  guard result is Err(failure) else {
    fail("present nonregular source must fail")
  }
  assert_true(failure.kind == OutputFailure)
  assert_eq(cli_failure_exit_code(failure), 6)
  assert_false(@fs.path_exists(root + "/out/result.md"))
}

///|
async test "CLI provenance samples asset materialization after render without changing confirmed output" {
  let root = test_tmp_root() + "/cli-source-asset-provenance"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  @fs.write_bytes_to_file(root + "/small.png", b"actual-payload")
  write_utf8_text(
    root + "/input.html",
    "<p><img src=\"small.png\" alt=\"small\"></p>",
  )
  let opts = cli_options(
    root + "/input.html",
    Some(root + "/out/result.md"),
    Some(Html),
    Markdown,
    provenance_output=Some(root + "/provenance.json"),
  )
  let result = run_cli_impl(opts, false).unwrap()
  let value = @asset_json.parse(
    read_utf8_text(root + "/provenance.json"),
    reject_duplicate_keys=true,
  )
  guard value is Object(fields) else { fail("provenance object required") }
  guard fields.get("budget_usage") is Some(Object(usage)) else {
    fail("budget object required")
  }
  assert_eq(usage.get("budget_schema"), Some(Json("partial_v11")))
  assert_true(
    usage.get("budget_cache_payload_peak_bytes") is Some(String(count)) &&
    count != "0",
  )
  assert_eq(
    usage.get("budget_output_confirmed_utf8_bytes"),
    Some(Json((@utf8.encode(result).length() - 1).to_string())),
  )
  assert_eq(
    @fs.read_file_to_bytes(root + "/out/assets/image01.png"),
    b"actual-payload",
  )
}

///|
async test "asset local extent is independent of a smaller raw root ceiling and obeys a smaller explicit asset cap" {
  let root = test_tmp_root() + "/cli-source-asset-local-extent"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  @fs.write_bytes_to_file(root + "/source.bin", b"xyz")
  for limit in [2L, 3L] {
    let session = @input.begin_input_session(
      @input.input_from_text("x"),
      max_bytes=1L,
    )
    defer @input.end_input_session(session)
    let limits = @product.make_resource_limits(
      2000,
      50,
      100000,
      max_asset_bytes=limit,
    )
    let result = cli_prepare_source_assets(
      root + "/input.txt",
      session.source,
      [cli_test_source_asset("one", "source.bin")],
      limits,
      @core.empty_diagnostics(),
    )
    if limit == 3L {
      assert_true(result is Ok(_))
      assert_true(@input.input_source_failure(session.source) is None)
      assert_eq(
        @input.input_source_budget_context(session.source).unwrap().account.snapshot().cumulative.read_traffic_bytes,
        3L,
      )
    } else {
      assert_true(result is Err({ kind: ResourceFailure, .. }))
      assert_true(
        @input.input_source_failure(session.source) is Some(ResourceLimit(_)),
      )
    }
  }
}

///|
async test "SourcePath reads the descriptor admitted by metadata after pathname replacement" {
  let root = test_tmp_root() + "/cli-source-asset-opened-fd"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  @fs.write_bytes_to_file(root + "/source.bin", b"old")
  let session = @input.begin_input_session(
    @input.input_from_text("x"),
    max_bytes=1L,
  )
  defer @input.end_input_session(session)
  let child = @input.input_from_asset_path(
    session.source,
    root + "/source.bin",
    asset_limit=3L,
  )
  assert_eq(@input.input_source_size(child).unwrap(), Some(3L))
  @fs.remove_file(root + "/source.bin")
  @fs.write_bytes_to_file(
    root + "/source.bin",
    b"new-replacement-larger-than-cap",
  )
  assert_eq(
    cli_read_source_asset(child, 3L, @convert.default_resource_limits()).unwrap(),
    b"old",
  )
  assert_eq(
    @fs.read_file_to_bytes(root + "/source.bin"),
    b"new-replacement-larger-than-cap",
  )
  assert_eq(
    @input.input_source_budget_context(session.source).unwrap().account.snapshot().cumulative.read_traffic_bytes,
    3L,
  )
}

///|
async test "cancelling actual Path asset IO releases working payload and closes its outer account" {
  let root = test_tmp_root() + "/cli-source-asset-cancel"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let size = 32 * 1024 * 1024
  @fs.write_bytes_to_file(root + "/source.bin", Bytes::new(size))
  let account = cli_test_asset_account(None, None)
  let finished = Ref(false)
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      @async.handle_cancellation(async fn() {
        let session = @input.begin_input_session(
          @input.input_from_text("x"),
          budget=account,
        )
        defer @input.end_input_session(session)
        let result = cli_prepare_source_assets(
          root + "/input.txt",
          session.source,
          [cli_test_source_asset("one", "source.bin")],
          @convert.default_resource_limits(),
          @core.empty_diagnostics(),
        )
        result |> ignore
        finished.val = true
      })
    })
    while account.snapshot().resident.working_bytes == 0L && !finished.val {
      @async.pause()
    }
    assert_false(finished.val)
    assert_true(account.snapshot().resident.working_bytes > 0L)
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_true(account.snapshot().closed)
  assert_eq(account.snapshot().active_leases, 0L)
  assert_eq(account.snapshot().resident.cache_bytes, 0L)
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  assert_true(
    account.snapshot().cumulative.read_traffic_bytes < size.to_int64(),
  )
  assert_true(account.failure() is None)
  assert_false(finished.val)
}
