///|
/// Hard parse failures for the CSV parser.
pub(all) suberror CsvError {
  ParseError(String)
}

///|
pub(all) enum CsvDelimiter {
  Comma
  Tab
} derive(Eq)

///|
/// Parsing options for delimiter, quoting, and ragged-row handling.
pub struct CsvParseOptions {
  delimiter : CsvDelimiter
  quote_char : Char
  double_quote_escape : Bool
  skip_blank_rows : Bool
  normalize_ragged_rows : Bool
}

///|
/// Parsed CSV rows with original line provenance.
pub struct CsvRow {
  fields : Array[String]
  original_field_count : Int
  line_start : Int
  line_end : Int
}

///|
/// Source-native CSV table model.
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
/// Stable classification for hard CSV parse failures.
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
/// Validation issues reported without turning the parse into a hard failure.
pub struct CsvValidationIssue {
  kind : CsvValidationIssueKind
  severity : CsvValidationSeverity
  row_index : Int
  actual_field_count : Int
  expected_field_count : Int
  message : String
}

///|
/// Aggregated CSV validation report.
pub struct CsvValidationReport {
  row_count : Int
  column_count : Int
  issue_count : Int
  warning_count : Int
  error_count : Int
  issues : Array[CsvValidationIssue]
}

///|
/// Structural summary for a parsed CSV document.
pub struct CsvInspectReport {
  delimiter : CsvDelimiter
  row_count : Int
  column_count : Int
  line_count : Int
  min_field_count : Int
  max_field_count : Int
  empty_cell_count : Int
  ragged_row_count : Int
  multiline_row_count : Int
  multiline_field_count : Int
}

///|
pub impl Show for CsvError with fn to_string(self : CsvError) -> String {
  match self {
    ParseError(msg) => "csv parse error: " + msg
  }
}

///|
pub impl Show for CsvError with fn output(self : CsvError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
