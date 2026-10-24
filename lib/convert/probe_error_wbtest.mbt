///|
async test "unsupported text markup probe reports unavailable without reading input" {
  let reads = Ref(0)
  let source = @input.input_from_reader(
    @input.make_input_reader(fn(_, _) {
      reads.val += 1
      Err("unsupported probe must not read")
    }),
  )
  let probe = text_markup_preflight_probe(source, Txt)
  assert_eq(probe.summary_format, "txt")
  assert_true(probe.summary_parts == ["unavailable"])
  assert_eq(probe.probe_failures.length(), 1)
  assert_eq(probe.probe_failures[0].stage, "txt")
  assert_eq(probe.probe_failures[0].detail, "probe_unavailable")
  assert_eq(probe.probe_artifacts.length(), 0)
  assert_eq(reads.val, 0)
}
