///|
test "convert public modes and structured errors cover all mappings" {
  assert_true(
    ConvertError::DetectFailed("x").to_string().contains("detect failed"),
  )
  assert_true(
    ConvertError::RenderFailed("x").to_string().contains("render failed"),
  )
  assert_eq(
    ConvertError::ResourceLimitExceeded(kind="input", observed=11L, limit=10L).to_string(),
    "resource limit exceeded: input; observed=11; limit=10",
  )
  assert_true(
    output_mode_for_convert_mode(ConvertMode::Accurate) ==
    @product.OutputMode::Markdown,
  )
  assert_true(
    output_mode_for_output_format(OutputFormat::RagJson) ==
    @product.OutputMode::Rag,
  )
  assert_true(
    derived_convert_mode(@product.FidelityMode::Accurate, false) ==
    ConvertMode::Accurate,
  )
  assert_true(
    derived_convert_mode(@product.FidelityMode::Balanced, false) ==
    ConvertMode::Balanced,
  )
  assert_true(
    derived_convert_mode(@product.FidelityMode::Balanced, true) ==
    ConvertMode::Stream,
  )
}
