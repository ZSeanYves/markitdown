///|
test "xlsx parser keeps package-single-pass route diagnostics and source refs stable" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/fixtures/contracts/xlsx/xlsx_hidden_sheets_policy.xlsx",
    ),
    Xlsx,
  )
  let spec = @fmeta.xlsx_parser_contract_spec()
  assert_parse_result_matches_contract_spec(parsed, spec)
  let document = parsed.document.unwrap_or_else(fn() {
    abort("missing xlsx document")
  })
  match document.metadata.get("workbook_part") {
    Some(String(value)) => assert_eq(value, "xl/workbook.xml")
    _ => fail("xlsx document metadata should keep workbook_part")
  }
  let table_ref = document.blocks[1].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(table_ref.entry_path == Some("xl/worksheets/sheet1.xml"))
  assert_true(table_ref.inner_path == Some("/worksheet/sheetData"))
  assert_true(table_ref.extra.get("sheet_name") == Some("Visible"))
  assert_true(table_ref.extra.get("relationship_id") == Some("rId1"))
}

///|
test "xlsx accurate fidelity includes hidden sheets instead of skipping them" {
  let registry = @fmeta.builtin_registry()
  let context = @parser.parse_context_with_product_modes(
    @parser.new_parse_context(Xlsx),
    Accurate,
    Markdown,
  )
  let result = match
    @parser.registry_parse(
      registry,
      @input.input_from_path(
        "samples/fixtures/contracts/xlsx/xlsx_hidden_sheets_policy.xlsx",
      ),
      context,
    ) {
    Ok(value) => value
    Err(err) => fail("accurate xlsx parse failed: " + err)
  }
  assert_metric_eq(result.diagnostics, "fidelity_mode", "accurate")
  let document = result.document.unwrap_or_else(fn() {
    abort("missing accurate xlsx document")
  })
  assert_eq(document.blocks[0].text, "Visible")
  assert_eq(document.blocks[2].text, "HiddenData")
  assert_eq(document.blocks[4].text, "VeryHiddenAudit")
  let hidden_ref = document.blocks[2].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  let very_hidden_ref = document.blocks[4].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(hidden_ref.extra.get("sheet_visibility") == Some("hidden"))
  assert_true(
    very_hidden_ref.extra.get("sheet_visibility") == Some("very_hidden"),
  )
}
