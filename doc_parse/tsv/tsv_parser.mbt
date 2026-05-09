///|
pub fn parse_tsv_document(text : String) -> @csv.CsvDocument raise {
  @csv.parse_csv_with_options(text, @csv.csv_parse_options_for_tsv())
}

///|
pub fn inspect_tsv_document(doc : @csv.CsvDocument) -> @csv.CsvInspectReport {
  @csv.inspect_csv_document(doc)
}

///|
pub fn collect_tsv_validation_issues(
  doc : @csv.CsvDocument,
) -> Array[@csv.CsvValidationIssue] {
  @csv.collect_csv_validation_issues(doc)
}

///|
pub fn validate_tsv_document(
  doc : @csv.CsvDocument,
) -> @csv.CsvValidationReport {
  @csv.validate_csv_document(doc)
}

///|
pub fn classify_tsv_error(err : @csv.CsvError) -> @csv.CsvErrorInfo {
  @csv.classify_csv_error(err)
}
