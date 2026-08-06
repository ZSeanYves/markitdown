///|
test "0.8 public interface is usable from a consumer package" {
  let input = @api.Input::from_text(
    "# Public API\n\nStable boundary\n",
    source_name="consumer.md",
  )
  let options = @api.ConvertOptions::default()
    .with_mode(Balanced)
    .with_output_mode(Markdown)
  guard @api.convert(input, options~) is Ok(output) else {
    fail("public API conversion failed")
  }
  assert_eq(output.detected_format, "markdown")
  assert_true(output.content.contains("Public API"))
  assert_true(output.provenance.selected_route != "")
}
