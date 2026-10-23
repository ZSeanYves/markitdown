///|
async fn office_asset_limit_case(path : String, format : String) -> Unit {
  let input = @lib.Input::from_path(path)
  let baseline = @lib.convert(input).unwrap()
  assert_true(baseline.assets.length() > 0)
  let options = @lib.ConvertOptions::default()
    .with_format_hint(Some(format))
    .with_limits(@lib.ResourceLimits::default().with_max_asset_bytes(1L))
  let collect_rejected = match @lib.convert(input, options~) {
    Err(@lib.ConvertError::ResourceLimitExceeded(kind~, observed~, limit~)) => {
      assert_eq(kind, "single_asset_bytes")
      assert_true(observed > 1L)
      assert_eq(limit, 1L)
      true
    }
    _ => false
  }
  let writes = Ref(0)
  let finishes = Ref(0)
  let sink_rejected = match
    @lib.convert_to_sink(
      input,
      @lib.OutputSink::new(
        fn(_fragment) {
          writes.val += 1
          Ok(())
        },
        fn() {
          finishes.val += 1
          Ok(())
        },
      ),
      options~,
    ) {
    Err(@lib.ConvertError::ResourceLimitExceeded(kind~, observed~, limit~)) => {
      assert_eq(kind, "single_asset_bytes")
      assert_true(observed > 1L)
      assert_eq(limit, 1L)
      true
    }
    _ => false
  }
  // A parser must not turn an enforced byte ceiling into successful output
  // after silently removing the asset. Both public entrypoints must reject.
  assert_eq(
    (collect_rejected, sink_rejected, writes.val, finishes.val),
    (true, true, 0, 0),
  )
}

///|
async test "DOCX parser asset limit is a public hard resource failure" {
  office_asset_limit_case(
    "samples/fixtures/contracts/docx/docx_image_alt_title.docx", "docx",
  )
}

///|
async test "PPTX parser asset limit is a public hard resource failure" {
  office_asset_limit_case(
    "samples/fixtures/contracts/pptx/pptx_image_single.pptx", "pptx",
  )
}

///|
async test "XLSX parser asset limit is a public hard resource failure" {
  office_asset_limit_case(
    "samples/fixtures/contracts/xlsx/xlsx_advanced_synthetic.xlsx", "xlsx",
  )
}

///|
async test "ODT parser asset limit is a public hard resource failure" {
  office_asset_limit_case(
    "samples/fixtures/contracts/odt/odt_basic_assets.odt", "odt",
  )
}

///|
async test "ODS parser asset limit is a public hard resource failure" {
  office_asset_limit_case(
    "samples/fixtures/contracts/ods/ods_advanced_synthetic.ods", "ods",
  )
}

///|
async test "ODP parser asset limit is a public hard resource failure" {
  office_asset_limit_case(
    "samples/fixtures/contracts/odp/odp_advanced_synthetic.odp", "odp",
  )
}
