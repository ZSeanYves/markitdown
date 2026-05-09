///|
pub(all) suberror XlsxError {
  OpenFailed(String)
  OoxmlFailure(String)
  ParseError(String)
}

///|
pub(all) enum XlsxSheetState {
  Visible
  Hidden
  VeryHidden
} derive(Eq)

///|
pub(all) enum XlsxCellKind {
  SharedString
  InlineString
  Boolean
  StringResult
  Error
  Number
  Blank
} derive(Eq)

///|
pub(all) enum XlsxCellSemanticType {
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
pub(all) enum XlsxFormulaPolicy {
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
pub struct XlsxCell {
  reference : String
  row : Int
  column : Int
  raw_type : String
  kind : XlsxCellKind
  display_text : String
  source_value : String?
  formula_text : String?
  semantic_type : XlsxCellSemanticType
  style_index : Int
  num_format_id : Int
  formula_trace : XlsxFormulaTrace?
  issues : Array[XlsxValidationIssue]
}

///|
pub struct XlsxSheet {
  name : String
  sheet_id : String?
  relationship_id : String?
  relationship_type : String?
  part_target : String?
  state : XlsxSheetState
  is_supported_worksheet : Bool
  has_sheet_xml : Bool
  cells : Array[XlsxCell]
  merged_ranges : Array[XlsxMergedRange]
  used_min_row : Int
  used_min_col : Int
  used_max_row : Int
  used_max_col : Int
  issues : Array[XlsxValidationIssue]
}

///|
pub struct XlsxStyles {
  xf_numfmts : Array[Int]
  custom_numfmts : Map[Int, String]
}

///|
pub struct XlsxWorkbook {
  shared_strings : Array[String]
  styles : XlsxStyles
  uses_date_1904 : Bool
  sheets : Array[XlsxSheet]
  issues : Array[XlsxValidationIssue]
}

///|
pub(all) enum XlsxErrorKind {
  OpenFailed
  OoxmlFailure
  MissingWorkbook
  MalformedWorkbookXml
  MalformedSheetXml
  InvalidCellReference
  Unknown
} derive(Eq)

///|
pub struct XlsxErrorInfo {
  kind : XlsxErrorKind
  detail : String
}

///|
pub(all) enum XlsxValidationSeverity {
  Warning
  Error
} derive(Eq)

///|
pub(all) enum XlsxValidationIssueKind {
  MissingWorksheetPart
  MissingSharedString
  InvalidCellReference
  InvalidMergedRange
  UnsupportedCellType
  DuplicateSheetName
  MalformedSheetXml
  UnsupportedFormulaEvaluation
} derive(Eq)

///|
pub struct XlsxValidationIssue {
  kind : XlsxValidationIssueKind
  severity : XlsxValidationSeverity
  sheet_name : String?
  cell_reference : String?
  part_target : String?
  message : String
}

///|
pub struct XlsxValidationReport {
  sheet_count : Int
  cell_count : Int
  issue_count : Int
  warning_count : Int
  error_count : Int
  issues : Array[XlsxValidationIssue]
}

///|
pub struct XlsxInspectReport {
  sheet_count : Int
  hidden_sheet_count : Int
  cell_count : Int
  non_empty_cell_count : Int
  formula_cell_count : Int
  merged_range_count : Int
  shared_string_count : Int
  style_count : Int
  uses_date_1904 : Bool
  issue_count : Int
  warning_count : Int
  error_count : Int
}

///|
type XlsxSheetModel = XlsxSheet

///|
type XlsxCellModel = XlsxCell

///|
pub impl Show for XlsxError with to_string(self : XlsxError) -> String {
  match self {
    OpenFailed(msg) => "xlsx open failed: " + msg
    OoxmlFailure(msg) => "xlsx ooxml failure: " + msg
    ParseError(msg) => "xlsx parse error: " + msg
  }
}

///|
pub impl Show for XlsxError with output(self : XlsxError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
