///|
priv enum XlsxFormulaAst {
  Number(Double)
  String(String)
  Bool(Bool)
  CellRef(String, Int, Int)
  RangeRef(String, String, Int, Int, Int, Int)
  Unary(String, XlsxFormulaAst)
  Binary(String, XlsxFormulaAst, XlsxFormulaAst)
  FunctionCall(String, Array[XlsxFormulaAst])
}

///|
priv struct XlsxFormulaCellRecord {
  display_text : String
  semantic_type : XlsxCellSemanticType
  formula_text : String?
  source_value : String?
}

///|
priv struct XlsxFormulaSheetContext {
  cells : Map[String, XlsxFormulaCellRecord]
  max_recursion_depth : Int
  max_range_cell_count : Int
  max_formula_text_length : Int
}

///|
priv enum XlsxFormulaScalar {
  Number(Double)
  String(String)
  Bool(Bool)
  Blank
  Error(String)
}

///|
priv enum XlsxFormulaValue {
  Scalar(XlsxFormulaScalar, Array[String], Array[String])
  Range(Array[XlsxFormulaScalar], Array[String], Array[String])
}

///|
priv enum XlsxFormulaScalarMode {
  ScalarOnly
}

///|
priv enum XlsxFormulaEvalResult {
  Evaluated(String, XlsxCellSemanticType, Array[String], Array[String])
  Unsupported(String, Array[String], Array[String])
  Error(String, Array[String], Array[String])
}

///|
priv struct XlsxFormulaEvalState {
  visited : Map[String, Bool]
}
