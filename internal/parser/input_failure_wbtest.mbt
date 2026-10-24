///|
async test "pull parser inherits the parent session and preserves child Reader failure" {
  let parent = @input.begin_input_session(@input.input_from_text("parent"))
  defer @input.end_input_session(parent)
  let calls = Ref(0)
  let child = @input.input_from_reader(
    @input.make_input_reader(fn(_offset, _length) {
      calls.val += 1
      Err("child pull read failed")
    }),
    source_name="child.txt",
  )
  let capability = parser_capability(true, false, false)
  let parser = make_parser(
    "pull-failure",
    StreamingEvent,
    capability,
    (_, _) => fail("the pull test must not use the collecting parser"),
    open_stream=Some(fn(source, _context) {
      Ok(
        Some(
          make_parse_event_stream(
            async fn() {
              match @input.read_input_bytes(source) {
                Err(message) => Err(message)
                Ok(_) => Ok(None)
              }
            },
            fn() {
              Ok(
                parse_stream_summary(
                  "pull-failure",
                  StreamingEvent,
                  capability,
                  @core.empty_diagnostics(),
                ),
              )
            },
          ),
        ),
      )
    }),
  )
  let context = parse_context_with_input_source(
    new_parse_context(Txt),
    parent.source,
  )
  let registry = empty_registry()
  registry_register(registry, Txt, parser)
  let stream = registry_open_event_stream(registry, child, context)
    .unwrap()
    .unwrap()
  match (stream.next)() {
    Err(message) => assert_eq(message, "child pull read failed")
    _ => fail("the child read must fail")
  }
  assert_eq(@input.input_session_error(parent), Some("child pull read failed"))
  match (stream.next)() {
    Err(message) => assert_eq(message, "child pull read failed")
    _ => fail("the first failure must stop further reads")
  }
  assert_eq(calls.val, 1)
}
