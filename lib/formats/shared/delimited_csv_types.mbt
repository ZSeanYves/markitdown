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
pub extend CsvDelimiter with Eq::{equal, not_equal}

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
  original_field_count : Int32
  line_start : Int32
  line_end : Int32
}

///|
/// Source-native CSV table model.
pub struct CsvDocument {
  delimiter : CsvDelimiter
  rows : Array[CsvRow]
  column_count : Int32
  line_count : Int32
}

///|
pub(all) enum CsvErrorKind {
  UnterminatedQuotedField
  Unknown
} derive(Eq)

///|
pub extend CsvErrorKind with Eq::{equal, not_equal}

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
pub extend CsvValidationSeverity with Eq::{equal, not_equal}

///|
pub(all) enum CsvValidationIssueKind {
  RaggedRow
} derive(Eq)

///|
pub extend CsvValidationIssueKind with Eq::{equal, not_equal}

///|
/// Validation issues reported without turning the parse into a hard failure.
pub struct CsvValidationIssue {
  kind : CsvValidationIssueKind
  severity : CsvValidationSeverity
  row_index : Int32
  actual_field_count : Int32
  expected_field_count : Int32
  message : String
}

///|
/// Aggregated CSV validation report.
pub struct CsvValidationReport {
  row_count : Int32
  column_count : Int32
  issue_count : Int32
  warning_count : Int32
  error_count : Int32
  issues : Array[CsvValidationIssue]
}

///|
/// Structural summary for a parsed CSV document.
pub struct CsvInspectReport {
  delimiter : CsvDelimiter
  row_count : Int32
  column_count : Int32
  line_count : Int32
  min_field_count : Int32
  max_field_count : Int32
  empty_cell_count : Int32
  blank_row_count : Int32
  ragged_row_count : Int32
  multiline_row_count : Int32
  multiline_field_count : Int32
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
