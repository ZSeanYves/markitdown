///|
async test "PPTX preparation failure preserves its reason without a second parse" {
  let bytes = @asset_zip.build_store_zip_bytes([
    ("[Content_Types].xml", b"<Types/>"),
    (
      "ppt/presentation.xml", b"<p:presentation><broken></wrong></p:presentation>",
    ),
  ])
  let reads = Ref(0)
  let source = @input.input_from_reader(
    @input.make_input_reader((offset, length) => {
      reads.val += 1
      if offset >= bytes.length().to_int64() {
        return Ok(b"")
      }
      let start = offset.to_int()
      Ok(bytes[start:(start + length).min(bytes.length())].to_owned())
    }),
  )
  let probe = pptx_preflight_probe(source, default_convert_options())
  assert_eq(probe.probe_failures.length(), 1)
  let reason = probe.probe_failures[0].detail
  assert_true(reason.contains("pptx parse error:"))
  let after_probe = reads.val
  let parsed = parse_with_route_probe_artifact(
    probe.prepared_source,
    Pptx,
    @parser.new_parse_context(Pptx),
    @formats.builtin_registry(),
    probe.probe_artifacts,
  )
  match parsed {
    Some(Err(message)) => assert_eq(message, reason)
    _ => fail("original preparation failure must survive the route boundary")
  }
  assert_eq(reads.val, after_probe)
  let unrelated = parse_with_route_probe_artifact(
    probe.prepared_source,
    Txt,
    @parser.new_parse_context(Txt),
    @formats.builtin_registry(),
    probe.probe_artifacts,
  )
  assert_true(unrelated is None)
  assert_eq(reads.val, after_probe)
}
