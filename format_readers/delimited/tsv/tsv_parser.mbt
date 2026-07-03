///|
/// Parse TSV text by reusing the shared CSV parser with TSV options.
pub fn parse_tsv_document(text : String) -> @csv.CsvDocument raise {
  @csv.parse_csv_with_options(text, @csv.csv_parse_options_for_tsv())
}

///|
/// Summarize structure for a parsed TSV document.
pub fn inspect_tsv_document(doc : @csv.CsvDocument) -> @csv.CsvInspectReport {
  @csv.inspect_csv_document(doc)
}

///|
/// Return TSV validation issues without treating them as hard parse failures.
pub fn collect_tsv_validation_issues(
  doc : @csv.CsvDocument,
) -> Array[@csv.CsvValidationIssue] {
  @csv.collect_csv_validation_issues(doc)
}

///|
/// Aggregate TSV validation counts and issues into a deterministic report.
pub fn validate_tsv_document(
  doc : @csv.CsvDocument,
) -> @csv.CsvValidationReport {
  @csv.validate_csv_document(doc)
}

///|
/// Classify a hard TSV parse failure into the shared CSV error taxonomy.
pub fn classify_tsv_error(err : @csv.CsvError) -> @csv.CsvErrorInfo {
  @csv.classify_csv_error(err)
}
