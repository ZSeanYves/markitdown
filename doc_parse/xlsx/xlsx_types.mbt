///|
/// Hard open and parse failures for the SpreadsheetML semantic layer.
pub(all) suberror XlsxError {
  OpenFailed(String)
  OoxmlFailure(String)
  ParseError(String)
}

///|
/// Raw workbook visibility state preserved from `workbook.xml`.
pub(all) enum XlsxSheetState {
  Visible
  Hidden
  VeryHidden
} derive(Eq)

///|
/// Source-native cell storage kinds preserved from worksheet XML.
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
/// Conservative semantic interpretation for parsed cell values.
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
/// Formula handling policy used for cached and best-effort evaluation signals.
pub(all) enum XlsxFormulaPolicy {
  Cached
  EvaluatedMissingCache
  UnsupportedFormula
  FormulaError
} derive(Eq)

///|
/// Parsed merged-cell range metadata without visual reconstruction.
pub struct XlsxMergedRange {
  range_ref : String
  start_row : Int
  start_col : Int
  end_row : Int
  end_col : Int
}

///|
/// Source-native worksheet comment metadata preserved from `comments*.xml`.
pub struct XlsxComment {
  reference : String
  row : Int
  column : Int
  author_name : String?
  text : String
}

///|
/// Conservative trace information for formula handling.
///
/// This is not a full Excel formula engine.
pub struct XlsxFormulaTrace {
  policy : XlsxFormulaPolicy
  evaluated_value : String?
  unsupported_reason : String?
  error_reason : String?
  referenced_cells : Array[String]?
  referenced_ranges : Array[String]?
}

///|
/// Source-native SpreadsheetML cell model.
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
/// Source-native worksheet model with preserved workbook ordering.
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
  comments : Array[XlsxComment]
  hidden_rows : Array[Int]
  used_min_row : Int
  used_min_col : Int
  used_max_row : Int
  used_max_col : Int
  issues : Array[XlsxValidationIssue]
}

///|
/// Minimal styles and number-format information used for conservative cell
/// interpretation.
pub struct XlsxStyles {
  xf_numfmts : Array[Int]
  custom_numfmts : Map[Int, String]
}

///|
/// Source-native SpreadsheetML workbook model.
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
/// Stable classification for hard XLSX open and parse failures.
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
/// Validation issues surfaced without changing workbook parsing into a hard
/// failure.
pub struct XlsxValidationIssue {
  kind : XlsxValidationIssueKind
  severity : XlsxValidationSeverity
  sheet_name : String?
  cell_reference : String?
  part_target : String?
  message : String
}

///|
/// Aggregated validation report for an XLSX workbook.
pub struct XlsxValidationReport {
  sheet_count : Int
  cell_count : Int
  issue_count : Int
  warning_count : Int
  error_count : Int
  issues : Array[XlsxValidationIssue]
}

///|
/// Structural summary for a parsed XLSX workbook.
pub struct XlsxInspectReport {
  sheet_count : Int
  hidden_sheet_count : Int
  hidden_row_count : Int
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
pub impl Show for XlsxError with fn to_string(self : XlsxError) -> String {
  match self {
    OpenFailed(msg) => "xlsx open failed: " + msg
    OoxmlFailure(msg) => "xlsx ooxml failure: " + msg
    ParseError(msg) => "xlsx parse error: " + msg
  }
}

///|
pub impl Show for XlsxError with fn output(self : XlsxError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
