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

///|
test "0.8 consumers can configure resource and RAG policies" {
  let limits = @api.ResourceLimits::default()
    .with_max_rows(100)
    .with_max_cols(20)
    .with_max_cells(1000)
    .with_max_line_chars(2000)
    .with_max_input_bytes(1024L)
    .with_max_asset_bytes(512L)
    .with_max_total_asset_bytes(768L)
    .with_external_command_timeout_ms(250)
    .with_max_external_output_bytes(4096L)
  let rag = @api.RagOptions::default()
    .with_chunk_size(128)
    .with_chunk_overlap(16)
    .with_preserve_heading_path(true)
    .with_preserve_source_ref(true)
    .with_split_tables(false)
    .with_split_code_blocks(false)
  let options = @api.ConvertOptions::default()
    .with_limits(limits)
    .with_rag(rag)
    .with_output_mode(Rag)
  guard @api.convert(
      @api.Input::from_text("# Configurable\n\nBody\n", source_name="policy.md"),
      options~,
    )
    is Ok(output) else {
    fail("configured public API conversion failed")
  }
  assert_true(output.chunks.length() > 0)
}
