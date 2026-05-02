///|
pub enum XlsxSheetState {
  Visible
  Hidden
  VeryHidden
} derive(Eq)

///|
pub enum XlsxCellKind {
  SharedString
  InlineString
  Boolean
  StringResult
  Error
  Number
  Blank
} derive(Eq)

///|
pub enum XlsxCellSemanticType {
  String
  Number
  Boolean
  Date
  DateTime
  Time
  Blank
  Error
  FormulaCachedValue
  FormulaMissingCache
} derive(Eq)

///|
pub enum XlsxFormulaPolicy {
  Cached
  EvaluatedMissingCache
  UnsupportedFormula
  FormulaError
} derive(Eq)

///|
pub struct XlsxMergedRange {
  range_ref : String
  start_row : Int
  start_col : Int
  end_row : Int
  end_col : Int
}

///|
pub struct XlsxFormulaTrace {
  policy : XlsxFormulaPolicy
  evaluated_value : String?
  unsupported_reason : String?
  error_reason : String?
  referenced_cells : Array[String]?
  referenced_ranges : Array[String]?
}

///|
pub struct XlsxCellModel {
  reference : String
  row : Int
  column : Int
  kind : XlsxCellKind
  display_text : String
  source_value : String?
  formula_text : String?
  semantic_type : XlsxCellSemanticType
  style_index : Int
  num_format_id : Int
  formula_trace : XlsxFormulaTrace?
}

///|
pub struct XlsxSheetModel {
  name : String
  relationship_id : String?
  relationship_type : String?
  part_target : String?
  state : XlsxSheetState
  is_supported_worksheet : Bool
  has_sheet_xml : Bool
  cells : Array[XlsxCellModel]
  merged_ranges : Array[XlsxMergedRange]
  table_rows : Array[Array[String]]
  header_rows : Int
  used_min_row : Int
  used_min_col : Int
  used_max_row : Int
  used_max_col : Int
}

///|
pub struct XlsxWorkbookModel {
  source_name : String
  uses_date_1904 : Bool
  sheets : Array[XlsxSheetModel]
}
