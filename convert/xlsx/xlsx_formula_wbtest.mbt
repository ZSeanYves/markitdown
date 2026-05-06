///|
fn formula_cell(
  reference : String,
  display_text : String,
  semantic_type : XlsxCellSemanticType,
  formula_text : String?,
  source_value : String?,
) -> XlsxCellModel {
  let (row, column) = formula_cell_ref_to_rc(reference)
  {
    reference,
    row,
    column,
    kind: XlsxCellKind::Number,
    display_text,
    source_value,
    formula_text,
    semantic_type,
    style_index: 0,
    num_format_id: 0,
    formula_trace: None,
  }
}

///|
test "xlsx formula parser supports arithmetic precedence and ranges" {
  let arithmetic = parse_xlsx_formula_text("(A1+B2)*2")
  match arithmetic {
    Ok(
      XlsxFormulaAst::Binary(
        "*",
        XlsxFormulaAst::Binary(
          "+",
          XlsxFormulaAst::CellRef("A1", 1, 1),
          XlsxFormulaAst::CellRef("B2", 2, 2),
        ),
        XlsxFormulaAst::Number(v),
      ),
    ) => assert_eq(format_formula_number(v), "2")
    _ => fail("expected arithmetic AST shape")
  }

  let range_expr = parse_xlsx_formula_text("SUM($A$1:$C$3)")
  match range_expr {
    Ok(
      XlsxFormulaAst::FunctionCall(
        "SUM",
        [
          XlsxFormulaAst::RangeRef("$A$1", "$C$3", 1, 1, 3, 3),
        ],
      ),
    ) => ()
    _ => fail("expected range AST shape")
  }
}

///|
test "xlsx formula parser rejects cross-sheet references conservatively" {
  match parse_xlsx_formula_text("Sheet2!A1") {
    Err(reason) => assert_true(reason.contains("unsupported"))
    _ => fail("cross-sheet reference should fail closed")
  }
}

///|
test "xlsx formula evaluator computes missing-cache arithmetic" {
  let cells = [
    formula_cell("A1", "1", XlsxCellSemanticType::Number, None, Some("1")),
    formula_cell("B1", "2", XlsxCellSemanticType::Number, None, Some("2")),
    formula_cell("C1", "", XlsxCellSemanticType::FormulaMissingCache, Some("A1+B1"), None),
  ]
  let trace = evaluate_missing_cache_formula("Sheet1", cells[2], cells)
  match trace {
    Some(info) => {
      if info.policy != XlsxFormulaPolicy::EvaluatedMissingCache {
        fail("expected EvaluatedMissingCache policy")
      }
      assert_eq(info.evaluated_value, Some("3"))
      match info.referenced_cells {
        Some(refs) => assert_eq(refs, ["A1", "B1"])
        None => fail("expected referenced cells")
      }
    }
    None => fail("expected arithmetic evaluation trace")
  }
}

///|
test "xlsx formula evaluator supports ranges and IF/ROUND text cases" {
  let range_cells = [
    formula_cell("A1", "1", XlsxCellSemanticType::Number, None, Some("1")),
    formula_cell("A2", "2", XlsxCellSemanticType::Number, None, Some("2")),
    formula_cell("A3", "3", XlsxCellSemanticType::Number, None, Some("3")),
    formula_cell(
      "B1",
      "",
      XlsxCellSemanticType::FormulaMissingCache,
      Some("SUM(A1:A3)"),
      None,
    ),
  ]
  match evaluate_missing_cache_formula("Sheet1", range_cells[3], range_cells) {
    Some(info) => {
      if info.policy != XlsxFormulaPolicy::EvaluatedMissingCache {
        fail("expected EvaluatedMissingCache policy for SUM")
      }
      assert_eq(info.evaluated_value, Some("6"))
      match info.referenced_ranges {
        Some(ranges) => assert_eq(ranges, ["A1:A3"])
        None => fail("expected referenced range")
      }
    }
    None => fail("expected SUM evaluation")
  }

  let cond_cells = [
    formula_cell("A1", "12", XlsxCellSemanticType::Number, None, Some("12")),
    formula_cell(
      "B1",
      "",
      XlsxCellSemanticType::FormulaMissingCache,
      Some("IF(A1>10,\"high\",\"low\")"),
      None,
    ),
    formula_cell("A2", "10", XlsxCellSemanticType::Number, None, Some("10")),
    formula_cell(
      "B2",
      "",
      XlsxCellSemanticType::FormulaMissingCache,
      Some("ROUND(A2/3,2)"),
      None,
    ),
  ]
  match evaluate_missing_cache_formula("Sheet1", cond_cells[1], cond_cells) {
    Some(info) => assert_eq(info.evaluated_value, Some("high"))
    None => fail("expected IF evaluation")
  }
  match evaluate_missing_cache_formula("Sheet1", cond_cells[3], cond_cells) {
    Some(info) => assert_eq(info.evaluated_value, Some("3.33"))
    None => fail("expected ROUND evaluation")
  }
}

///|
test "xlsx formula evaluator marks unsupported and error cases" {
  let unsupported_cells = [
    formula_cell(
      "A1",
      "",
      XlsxCellSemanticType::FormulaMissingCache,
      Some("VLOOKUP(1,B1:C3,2,FALSE)"),
      None,
    ),
  ]
  match evaluate_missing_cache_formula("Sheet1", unsupported_cells[0], unsupported_cells) {
    Some(info) => {
      if info.policy != XlsxFormulaPolicy::UnsupportedFormula {
        fail("expected UnsupportedFormula policy")
      }
      match info.unsupported_reason {
        Some(reason) => assert_true(reason.contains("unsupported function"))
        None => fail("expected unsupported reason")
      }
    }
    None => fail("expected unsupported trace")
  }

  let range_scalar_cells = [
    formula_cell("A1", "1", XlsxCellSemanticType::Number, None, Some("1")),
    formula_cell("A2", "2", XlsxCellSemanticType::Number, None, Some("2")),
    formula_cell("B1", "3", XlsxCellSemanticType::Number, None, Some("3")),
    formula_cell("B2", "4", XlsxCellSemanticType::Number, None, Some("4")),
    formula_cell(
      "C1",
      "",
      XlsxCellSemanticType::FormulaMissingCache,
      Some("A1:A2+B1:B2"),
      None,
    ),
  ]
  match evaluate_missing_cache_formula("Sheet1", range_scalar_cells[4], range_scalar_cells) {
    Some(info) => {
      if info.policy != XlsxFormulaPolicy::UnsupportedFormula {
        fail("expected UnsupportedFormula policy for range scalar coercion")
      }
      match info.unsupported_reason {
        Some(reason) => assert_true(reason.contains("range scalar coercion unsupported"))
        None => fail("expected range scalar coercion reason")
      }
    }
    None => fail("expected range scalar unsupported trace")
  }

  let error_cells = [
    formula_cell(
      "A1",
      "",
      XlsxCellSemanticType::FormulaMissingCache,
      Some("1/0"),
      None,
    ),
  ]
  match evaluate_missing_cache_formula("Sheet1", error_cells[0], error_cells) {
    Some(info) => {
      if info.policy != XlsxFormulaPolicy::FormulaError {
        fail("expected FormulaError policy")
      }
      assert_eq(info.error_reason, Some("division by zero"))
    }
    None => fail("expected error trace")
  }
}

///|
test "xlsx formula evaluator detects missing references and circular references" {
  let missing_ref_cells = [
    formula_cell(
      "A1",
      "",
      XlsxCellSemanticType::FormulaMissingCache,
      Some("Z99+1"),
      None,
    ),
  ]
  match evaluate_missing_cache_formula("Sheet1", missing_ref_cells[0], missing_ref_cells) {
    Some(info) => {
      if info.policy != XlsxFormulaPolicy::FormulaError {
        fail("expected FormulaError policy for missing ref")
      }
      match info.error_reason {
        Some(reason) => assert_true(reason.contains("missing cell reference"))
        None => fail("expected missing reference reason")
      }
    }
    None => fail("expected missing-reference trace")
  }

  let circular_cells = [
    formula_cell(
      "A1",
      "",
      XlsxCellSemanticType::FormulaMissingCache,
      Some("B1+1"),
      None,
    ),
    formula_cell(
      "B1",
      "",
      XlsxCellSemanticType::FormulaMissingCache,
      Some("A1+1"),
      None,
    ),
  ]
  match evaluate_missing_cache_formula("Sheet1", circular_cells[0], circular_cells) {
    Some(info) => {
      if info.policy != XlsxFormulaPolicy::FormulaError {
        fail("expected FormulaError policy for circular reference")
      }
      match info.error_reason {
        Some(reason) => assert_true(reason.contains("circular reference"))
        None => fail("expected circular reference reason")
      }
    }
    None => fail("expected circular-reference trace")
  }
}
