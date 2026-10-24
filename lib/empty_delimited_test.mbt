///|
async fn assert_empty_delimited_conversion(format : String) -> Unit {
  let input = @lib.Input::from_bytes(b"", source_name="empty." + format)
  let options = @lib.ConvertOptions::default().with_format_hint(Some(format))
  let collected = @lib.convert(input, options~).unwrap()
  assert_eq(collected.content, "")
  assert_eq(collected.detected_format, format)
  assert_eq(collected.provenance.detected_format, format)
  assert_true(collected.provenance.selected_route != "")
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
  assert_eq(fragments.join(""), collected.content)
  assert_eq(finishes.val, 1)
  assert_eq(summary.detected_format, collected.detected_format)
  assert_eq(summary.metadata_json, collected.metadata_json)
  assert_eq(summary.assets, collected.assets)
}

///|
async test "public collecting and sink conversion accept empty CSV" {
  assert_empty_delimited_conversion("csv")
}

///|
async test "public collecting and sink conversion accept empty TSV" {
  assert_empty_delimited_conversion("tsv")
}
