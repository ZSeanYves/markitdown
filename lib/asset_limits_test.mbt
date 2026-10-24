///|
fn asset_limits_notebook_input() -> @lib.Input {
  // Two independent embedded payloads, each exactly three decoded bytes.
  let text =
    #|{"nbformat":4,"nbformat_minor":5,"metadata":{},"cells":[{"cell_type":"code","source":"","outputs":[{"output_type":"display_data","data":{"image/png":"YWJj"}},{"output_type":"display_data","data":{"image/png":"ZGVm"}}]}]}
  @lib.Input::from_text(text, source_name="assets.ipynb")
}

///|
async test "public conversion preserves embedded assets at exact payload ceilings" {
  let input = asset_limits_notebook_input()
  let baseline = @lib.convert(input).unwrap()
  let options = @lib.ConvertOptions::default().with_limits(
    @lib.ResourceLimits::default()
    .with_max_asset_bytes(3L)
    .with_max_total_asset_bytes(6L),
  )
  let output = @lib.convert(input, options~).unwrap()
  assert_eq(output.content, baseline.content)
  assert_eq(output.assets, baseline.assets)
  assert_eq(output.assets.length(), 2)
  assert_true(output.assets[0].payload == Some(Bytes(b"abc")))
  assert_true(output.assets[1].payload == Some(Bytes(b"def")))
  let fragments : Array[String] = []
  let finishes = Ref(0)
  let summary = @lib.convert_to_sink(
    input,
    @lib.OutputSink::new(
      fn(fragment) {
        fragments.push(fragment)
        Ok(())
      },
      fn() {
        finishes.val += 1
        Ok(())
      },
    ),
    options~,
  ).unwrap()
  assert_eq(fragments.join(""), output.content)
  assert_eq(summary.assets, output.assets)
  assert_eq(finishes.val, 1)
}

///|
async test "public collect and Sink reject asset excess before output or finish" {
  let input = asset_limits_notebook_input()
  for
    (single_limit, total_limit, kind, observed, limit) in [
      (2L, 6L, "single_asset_bytes", 3L, 2L),
      (3L, 5L, "total_asset_bytes", 6L, 5L),
    ] {
    for mode in [@lib.OutputMode::Markdown, Debug, Rag] {
      let options = @lib.ConvertOptions::default()
        .with_output_mode(mode)
        .with_limits(
          @lib.ResourceLimits::default()
          .with_max_asset_bytes(single_limit)
          .with_max_total_asset_bytes(total_limit),
        )
      let expected = @lib.ConvertError::ResourceLimitExceeded(
        kind~,
        observed~,
        limit~,
      )
      assert_true(
        @lib.convert(input, options~) is Err(error) && error == expected,
      )
      let writes = Ref(0)
      let finishes = Ref(0)
      let result = @lib.convert_to_sink(
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
      )
      assert_true(result is Err(error) && error == expected)
      assert_eq(writes.val, 0)
      assert_eq(finishes.val, 0)
    }
  }
}

///|
async test "negative asset ceilings remain invalid options before reading input" {
  let reads = Ref(0)
  let input = @lib.Input::from_reader(
    fn(_offset, _length) {
      reads.val += 1
      Err("invalid options must be checked before input")
    },
    source_name="assets.ipynb",
  )
  for (single_limit, total_limit) in [(-1L, 6L), (3L, -1L)] {
    let options = @lib.ConvertOptions::default().with_limits(
      @lib.ResourceLimits::default()
      .with_max_asset_bytes(single_limit)
      .with_max_total_asset_bytes(total_limit),
    )
    assert_true(@lib.convert(input, options~) is Err(InvalidOption(_)))
    let finishes = Ref(0)
    let result = @lib.convert_to_sink(
      input,
      @lib.OutputSink::new(
        _fragment => fail("invalid options must not write output"),
        fn() {
          finishes.val += 1
          Ok(())
        },
      ),
      options~,
    )
    assert_true(result is Err(InvalidOption(_)))
    assert_eq(finishes.val, 0)
  }
  assert_eq(reads.val, 0)
}
