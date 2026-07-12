///|
test "text markup diagnostic templates remain stable" {
  let templates = text_markup_diagnostic_templates("rst")
  assert_eq(
    templates.quote_warning,
    "rst degraded complex quote/admonition preserved as block quote",
  )
  assert_eq(templates.raw_fallback, "rst complex boundary -> raw fenced block")
  assert_eq(
    templates.semantic_raw_fallback,
    "rst complex boundary -> semantic text block",
  )
}
