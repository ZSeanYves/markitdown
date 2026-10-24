///|
async test "Markdown line sink accepts leading blank events and preserves inline form feed" {
  for count in [0, 1, 6] {
    let events : Array[@core.CoreEvent] = Array::makei(count, _ => {
      rag_test_event(BlankLine, "")
    })
    events.append([
      rag_test_event(TextLine, " alpha "),
      rag_test_event(TextLine, "form\u{000c}feed"),
      rag_test_event(BlankLine, ""),
      rag_test_event(TextLine, "omega"),
    ])
    let actual = render_events_through_sink(events)
    assert_eq(actual, "alpha form\u{000c}feed\n\nomega")
    assert_eq(actual, render_markdown_events(events))
  }
  assert_eq(render_events_through_sink([rag_test_event(BlankLine, "")]), "")
}
