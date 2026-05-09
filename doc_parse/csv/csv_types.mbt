///|
pub(all) suberror CsvError {
  ParseError(String)
}

///|
pub(all) enum CsvDelimiter {
  Comma
  Tab
} derive(Eq)

///|
pub struct CsvParseOptions {
  delimiter : CsvDelimiter
  skip_blank_rows : Bool
  normalize_ragged_rows : Bool
}

///|
pub struct CsvRow {
  fields : Array[String]
  original_field_count : Int
  line_start : Int
  line_end : Int
}

///|
pub struct CsvDocument {
  delimiter : CsvDelimiter
  rows : Array[CsvRow]
  column_count : Int
  line_count : Int
}

///|
pub(all) enum CsvErrorKind {
  UnterminatedQuotedField
  Unknown
} derive(Eq)

///|
pub struct CsvErrorInfo {
  kind : CsvErrorKind
  detail : String
}

///|
pub(all) enum CsvValidationSeverity {
  Warning
  Error
} derive(Eq)

///|
pub(all) enum CsvValidationIssueKind {
  RaggedRow
} derive(Eq)

///|
pub struct CsvValidationIssue {
  kind : CsvValidationIssueKind
  severity : CsvValidationSeverity
  row_index : Int
  actual_field_count : Int
  expected_field_count : Int
  message : String
}

///|
pub struct CsvValidationReport {
  row_count : Int
  column_count : Int
  issue_count : Int
  warning_count : Int
  error_count : Int
  issues : Array[CsvValidationIssue]
}

///|
pub struct CsvInspectReport {
  delimiter : CsvDelimiter
  row_count : Int
  column_count : Int
  line_count : Int
  empty_cell_count : Int
  ragged_row_count : Int
  multiline_row_count : Int
  multiline_field_count : Int
}

///|
pub impl Show for CsvError with to_string(self : CsvError) -> String {
  match self {
    ParseError(msg) => "csv parse error: " + msg
  }
}

///|
pub impl Show for CsvError with output(self : CsvError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
