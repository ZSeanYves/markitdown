///|
test "xlsx contract spec matches the active runtime parser" {
  let spec = @formats_root.xlsx_parser_contract_spec()
  let parser = @fxlsx.xlsx_parser()
  assert_contract_spec_matches_parser(spec, parser)
  assert_true(
    @shared.xlsx_contract_mode() == @parser.ParserMode::PackageSinglePass,
  )
  assert_true(
    @shared.xlsx_contract_granularity() ==
    @parser.StreamingGranularity::XlsxSheet,
  )
  assert_true(
    @shared.xlsx_contract_large_granularity() ==
    @parser.StreamingGranularity::XlsxRow,
  )
  assert_eq(@shared.xlsx_contract_ir_input_kind(), "document")
  assert_eq(@shared.xlsx_contract_large_ir_input_kind(), "block_stream")
  assert_true(
    @shared.xlsx_contract_foundations() ==
    ["format_readers/ooxml/package", "format_readers/ooxml/shared"],
  )
  assert_true(
    @shared.xlsx_contract_excluded_runtime_foundations() ==
    ["convert/xlsx", "old_core"],
  )
  assert_contains_all(@shared.xlsx_contract_guardrails().join("\n"), [
    "XLSX is supported on the main CLI", "PackageSinglePass / IRInput::Document / xlsx_sheet",
    "large path = BlockStreaming / BlockStream / xlsx_row", "format_readers/ooxml/shared owns the shared XLSX semantic layer",
    "document rendering stays in the shared renderer layer", "formulas are preserved and never executed",
    "external links are no-fetch",
  ])
}

///|
test "xlsx shared contracts keep formula sheet relationship and asset policies explicit" {
  let xlsx_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(
            @core.source_ref_with_office_fields(
              @core.source_ref_with_container_entry(
                @core.empty_source_ref(),
                Some("sample.xlsx"),
                Some("xlsx"),
                Some("sample.xlsx"),
                Some("xl/worksheets/sheet1.xml"),
                Some(0),
                Some("xlsx"),
                Some("/worksheet/sheetData/row[7]/c[2]"),
              ),
              Some("sample.xlsx"),
              Some("xlsx"),
              Some("/worksheet/sheetData/row[7]/c[2]"),
              Some("Sheet A"),
              Some("B7"),
              None,
              None,
              Some("rIdSheet1"),
            ),
            "sheet_name",
            "Sheet A",
          ),
          "sheet_id",
          "1",
        ),
        "sheet_visibility",
        "visible",
      ),
      "row_index",
      "7",
    ),
    "column_index",
    "2",
  )
  let style : @core.StyleRef = {
    style_id: Some("3"),
    style_name: Some("Currency"),
    attrs: Map([]),
  }
  let formula = @shared.make_xlsx_formula(
    "SUM(B2:B6)",
    cached_value=Some("42"),
    formula_ref=Some("B7"),
    source_ref=Some(xlsx_ref),
  )
  let cell = @shared.make_xlsx_cell_model(
    "B7",
    7,
    2,
    @shared.XlsxCellType::Formula,
    raw_value=Some("42"),
    display_value=Some("42"),
    style_ref=Some(style),
    formula=Some(formula),
  )
  let row = @shared.make_xlsx_row_model(7, [cell], source_ref=Some(xlsx_ref))
  let sheet = @shared.make_xlsx_sheet_model(
    "Sheet A",
    [row],
    sheet_id=Some("1"),
    relationship_id=Some("rIdSheet1"),
    part_name=Some("xl/worksheets/sheet1.xml"),
    visibility=@shared.XlsxSheetVisibility::Visible,
  )
  let workbook = @shared.make_xlsx_workbook_model([sheet])
  let plan = @shared.make_xlsx_workbook_plan(workbook, ["Sheet A"], skipped_sheet_names=[
    "Hidden 1",
  ])
  assert_true(plan.workbook.sheets.length() == 1)
  assert_true(plan.included_sheet_names == ["Sheet A"])
  assert_true(plan.skipped_sheet_names == ["Hidden 1"])
  assert_true(cell.formula is Some(_))
  assert_true(cell.style_ref is Some(_))
  assert_contains_all(@shared.xlsx_contract_formula_policy().join("\n"), [
    "formula text is preserved", "formula evaluation is forbidden", "cached value may be used when present",
  ])
  assert_contains_all(@shared.xlsx_contract_sheet_policy().join("\n"), [
    "visible sheets are future first-scope input", "hidden sheets require explicit diagnostics policy",
    "very hidden sheets require explicit diagnostics policy", "large sheets are bounded and defer to xlsx_row block streaming",
  ])
  assert_contains_all(@shared.xlsx_contract_relationship_policy().join("\n"), [
    "relationship target resolution is package-local by default", "TargetMode=External is no-fetch",
    "external links are diagnostics/metadata only",
  ])
  assert_contains_all(@shared.xlsx_contract_asset_policy().join("\n"), [
    "drawing/image relationships stay package-local only", "materialization only happens at the CLI/output boundary",
  ])
}

///|
test "xlsx parser keeps package-single-pass route diagnostics and source refs stable" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/xlsx/markdown/xlsx_hidden_sheets_policy.xlsx",
    ),
    @input.DetectedFormat::Xlsx,
  )
  let spec = @formats_root.xlsx_parser_contract_spec()
  assert_parse_result_matches_contract_spec(parsed, spec)
  let document = parsed.document.unwrap_or_else(fn() {
    abort("missing xlsx document")
  })
  match document.metadata.get("workbook_part") {
    Some(@core.JsonValue::String(value)) => assert_eq(value, "xl/workbook.xml")
    _ => fail("xlsx document metadata should keep workbook_part")
  }
  assert_true(document.blocks.length() == 2)
  let table_ref = document.blocks[1].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(table_ref.entry_path == Some("xl/worksheets/sheet1.xml"))
  assert_true(table_ref.inner_path == Some("/worksheet/sheetData"))
  assert_true(table_ref.extra.get("sheet_name") == Some("Visible"))
  assert_true(table_ref.extra.get("sheet_visibility") == Some("visible"))
  assert_true(
    table_ref.extra.get("part_name") == Some("xl/worksheets/sheet1.xml"),
  )
  assert_true(table_ref.extra.get("relationship_id") == Some("rId1"))
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "xlsx_legacy_fallback", "doc_parse_xlsx_used", "xlsx_raw_fallback", "formula_evaluation_enabled",
  ])
}

///|
test "xlsx accurate fidelity includes hidden sheets instead of skipping them" {
  let registry = @formats_root.builtin_registry()
  let context = @parser.parse_context_with_product_modes(
    @parser.new_parse_context(@input.DetectedFormat::Xlsx),
    @product.FidelityMode::Accurate,
    @product.OutputMode::Markdown,
  )
  let result = match
    @parser.registry_parse(
      registry,
      @input.input_from_path(
        "samples/main_process/xlsx/markdown/xlsx_hidden_sheets_policy.xlsx",
      ),
      context,
    ) {
    Ok(value) => value
    Err(err) => fail("accurate xlsx parse failed: " + err)
  }
  assert_metric_eq(result.diagnostics, "fidelity_mode", "accurate")
  assert_diagnostics_lists_contain_none(result.diagnostics, [
    "xlsx_hidden_sheet_skipped", "xlsx_very_hidden_sheet_skipped",
  ])
  let document = result.document.unwrap_or_else(fn() {
    abort("missing accurate xlsx document")
  })
  assert_true(document.blocks.length() == 6)
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

///|
test "xlsx accurate fidelity restores hidden grouped rows in external quality sample" {
  let registry = @formats_root.builtin_registry()
  let balanced = match
    @parser.registry_parse(
      registry,
      @input.input_from_path(
        "markitdown-quality-lab/external_quality/xlsx/apache-poi/GroupTest.xlsx",
      ),
      @parser.parse_context_with_product_modes(
        @parser.new_parse_context(@input.DetectedFormat::Xlsx),
        @product.FidelityMode::Balanced,
        @product.OutputMode::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(err) => fail("balanced xlsx parse failed: " + err)
  }
  let accurate = match
    @parser.registry_parse(
      registry,
      @input.input_from_path(
        "markitdown-quality-lab/external_quality/xlsx/apache-poi/GroupTest.xlsx",
      ),
      @parser.parse_context_with_product_modes(
        @parser.new_parse_context(@input.DetectedFormat::Xlsx),
        @product.FidelityMode::Accurate,
        @product.OutputMode::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(err) => fail("accurate xlsx parse failed: " + err)
  }
  let balanced_document = balanced.document.unwrap_or_else(fn() {
    abort("missing balanced xlsx document")
  })
  let accurate_document = accurate.document.unwrap_or_else(fn() {
    abort("missing accurate xlsx document")
  })
  let balanced_markdown = (@render.markdown_renderer().render)(
      balanced_document,
      @render.make_render_context(false),
    ).content
  let accurate_markdown = (@render.markdown_renderer().render)(
      accurate_document,
      @render.make_render_context(false),
    ).content
  let balanced_inner_rows = balanced_markdown
    .split("| inner |")
    .to_array()
    .length() -
    1
  let accurate_inner_rows = accurate_markdown
    .split("| inner |")
    .to_array()
    .length() -
    1
  let balanced_collapsed_rows = balanced_markdown
    .split("| collapsed |")
    .to_array()
    .length() -
    1
  let accurate_collapsed_rows = accurate_markdown
    .split("| collapsed |")
    .to_array()
    .length() -
    1
  assert_true(balanced_markdown != accurate_markdown)
  assert_eq(balanced_inner_rows, 2)
  assert_eq(accurate_inner_rows, 10)
  assert_eq(balanced_collapsed_rows, 4)
  assert_eq(accurate_collapsed_rows, 8)
  assert_metric_eq(balanced.diagnostics, "xlsx_row_count", "19")
  assert_metric_eq(accurate.diagnostics, "xlsx_row_count", "32")
}

///|
test "xlsx accurate fidelity upgrades merged-range workbook to html table spans" {
  let registry = @formats_root.builtin_registry()
  let balanced = match
    @parser.registry_parse(
      registry,
      @input.input_from_path(
        "markitdown-quality-lab/external_quality/xlsx/xlsxwriter/generated/merge1.xlsx",
      ),
      @parser.parse_context_with_product_modes(
        @parser.new_parse_context(@input.DetectedFormat::Xlsx),
        @product.FidelityMode::Balanced,
        @product.OutputMode::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(err) => fail("balanced merge1 parse failed: " + err)
  }
  let accurate = match
    @parser.registry_parse(
      registry,
      @input.input_from_path(
        "markitdown-quality-lab/external_quality/xlsx/xlsxwriter/generated/merge1.xlsx",
      ),
      @parser.parse_context_with_product_modes(
        @parser.new_parse_context(@input.DetectedFormat::Xlsx),
        @product.FidelityMode::Accurate,
        @product.OutputMode::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(err) => fail("accurate merge1 parse failed: " + err)
  }
  let balanced_markdown = (@render.markdown_renderer().render)(
      balanced.document.unwrap_or_else(fn() {
        abort("missing balanced merge1 document")
      }),
      @render.make_render_context(false),
    ).content
  let accurate_markdown = (@render.markdown_renderer().render)(
      accurate.document.unwrap_or_else(fn() {
        abort("missing accurate merge1 document")
      }),
      @render.make_render_context(false),
    ).content
  assert_true(!balanced_markdown.contains("<table>"))
  assert_true(accurate_markdown.contains("<table>"))
  assert_true(accurate_markdown.contains("colspan=\"3\""))
  assert_true(accurate_markdown.contains("rowspan=\"2\""))
  assert_true(accurate_markdown.contains("Merged Range"))
}

///|
test "xlsx sheet hyperlinks render as markdown links without fetching targets" {
  let registry = @formats_root.builtin_registry()
  let parsed = match
    @parser.registry_parse(
      registry,
      @input.input_from_path(
        "markitdown-quality-lab/external_quality/xlsx/apache-poi/sharedhyperlink.xlsx",
      ),
      @parser.parse_context_with_product_modes(
        @parser.new_parse_context(@input.DetectedFormat::Xlsx),
        @product.FidelityMode::Accurate,
        @product.OutputMode::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(err) => fail("sharedhyperlink parse failed: " + err)
  }
  let markdown = (@render.markdown_renderer().render)(
      parsed.document.unwrap_or_else(fn() {
        abort("missing sharedhyperlink document")
      }),
      @render.make_render_context(false),
    ).content
  assert_true(
    markdown.contains("[http://www.apache.org](http://www.apache.org/)"),
  )
  assert_true(
    parsed.diagnostics.degraded_features.contains("xlsx_external_link_deferred"),
  )
}

///|
test "xlsx formal table parts split disjoint sheet tables into separate markdown tables" {
  let registry = @formats_root.builtin_registry()
  let parsed = match
    @parser.registry_parse(
      registry,
      @input.input_from_path(
        "markitdown-quality-lab/external_quality/xlsx/apache-poi/ExcelTables.xlsx",
      ),
      @parser.parse_context_with_product_modes(
        @parser.new_parse_context(@input.DetectedFormat::Xlsx),
        @product.FidelityMode::Accurate,
        @product.OutputMode::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(err) => fail("ExcelTables parse failed: " + err)
  }
  let markdown = (@render.markdown_renderer().render)(
      parsed.document.unwrap_or_else(fn() {
        abort("missing ExcelTables document")
      }),
      @render.make_render_context(false),
    ).content
  let table_count = markdown
    .split("| Name | Age | AgeGroup |")
    .to_array()
    .length() -
    1
  assert_true(markdown.contains("### TableName"))
  assert_eq(table_count, 2)
  assert_true(
    !markdown.contains(
      "| Name | Age | AgeGroup |  |  |  | Name | Age | AgeGroup |",
    ),
  )
}

///|
test "xlsx convert and parser large routes stay on block streaming" {
  let converted = convert_path(
    "samples/main_process/xlsx/markdown/sheet_simple.xlsx",
    format=Some(@input.DetectedFormat::Xlsx),
    limits=limits(1, 1, 1),
  )
  assert_true(converted.parser_mode == @parser.ParserMode::BlockStreaming)
  assert_metric_eq(converted.diagnostics, "selected_route", "block_streaming")
  assert_metric_eq(
    converted.diagnostics,
    "route_reason",
    "xlsx_over_limit_block_streaming",
  )
  assert_metric_eq(converted.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(converted.diagnostics, "event_granularity", "xlsx_row")

  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/xlsx/markdown/sheet_simple.xlsx",
    ),
    @input.DetectedFormat::Xlsx,
    requested_mode=Some(@parser.ParserMode::BlockStreaming),
  )
  assert_true(parsed.mode == @parser.ParserMode::BlockStreaming)
  assert_true(parsed.document is None)
  assert_true(parsed.block_stream is Some(_))
  assert_metric_eq(parsed.diagnostics, "ir_input_kind", "block_stream")
  assert_metric_eq(parsed.diagnostics, "event_granularity", "xlsx_row")
  assert_true(
    parsed.diagnostics.pass_trace.contains("lower:xlsx_sheet_row_table_regions"),
  )
}

///|
test "xlsx parser preserves formulas renderer boundary and source-ref debug fields" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/xlsx/markdown/xlsx_formula_missing_cache.xlsx",
    ),
    @input.DetectedFormat::Xlsx,
  )
  let document = parsed.document.unwrap_or_else(fn() {
    abort("missing xlsx formula document")
  })
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  let expected = read_utf8_text(
    "samples/main_process/xlsx/expected/markdown/xlsx_formula_missing_cache.md",
  )
  assert_eq(rendered.content.trim().to_owned(), expected.trim().to_owned())
  assert_true(rendered.content.contains("| Missing numeric cache | =1+2 |"))

  let source_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(
            @core.source_ref_with_extra(
              @core.source_ref_with_extra(
                @core.source_ref_with_extra(
                  @core.source_ref_with_office_fields(
                    @core.source_ref_with_container_entry(
                      @core.empty_source_ref(),
                      Some("book.xlsx"),
                      Some("xlsx"),
                      Some("book.xlsx"),
                      Some("xl/worksheets/sheet1.xml"),
                      Some(0),
                      Some("xlsx"),
                      Some("/worksheet/sheetData/row[7]/c[2]"),
                    ),
                    Some("book.xlsx"),
                    Some("xlsx"),
                    Some("/worksheet/sheetData/row[7]/c[2]"),
                    Some("Summary"),
                    Some("B7:C9"),
                    None,
                    None,
                    Some("rIdSheet1"),
                  ),
                  "sheet_name",
                  "Summary",
                ),
                "sheet_id",
                "1",
              ),
              "sheet_visibility",
              "very_hidden",
            ),
            "cell_ref",
            "B7",
          ),
          "row_index",
          "7",
        ),
        "column_index",
        "2",
      ),
      "formula_ref",
      "B7",
    ),
    "shared_string_index",
    "14",
  )
  let with_more = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(source_ref, "style_id", "3"),
        "merge_range",
        "B7:C9",
      ),
      "part_name",
      "xl/worksheets/sheet1.xml",
    ),
    "relationship_id",
    "rIdSheet1",
  )
  let block = @core.make_block(
    @core.BlockKind::TableCell,
    "42",
    source_ref=with_more,
  )
  let debug = (@render.debug_json_renderer().render)(
    @core.document_from_blocks([block]),
    @render.make_render_context(true),
  )
  assert_true(debug.content.contains("\"format\": \"xlsx\""))
  assert_true(debug.content.contains("\"sheet_name\": \"Summary\""))
  assert_true(debug.content.contains("\"relationship_id\": \"rIdSheet1\""))
}
