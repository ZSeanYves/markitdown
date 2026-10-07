///|
/// Parse TSV text by reusing the shared CSV parser with TSV options.
pub fn parse_tsv_document(text : String) -> CsvDocument raise {
  parse_csv_with_options(text, csv_parse_options_for_tsv())
}

///|
/// Summarize structure for a parsed TSV document.
pub fn inspect_tsv_document(doc : CsvDocument) -> CsvInspectReport {
  inspect_csv_document(doc)
}

///|
/// Return TSV validation issues without treating them as hard parse failures.
pub fn collect_tsv_validation_issues(
  doc : CsvDocument,
) -> Array[CsvValidationIssue] {
  collect_csv_validation_issues(doc)
}

///|
/// Aggregate TSV validation counts and issues into a deterministic report.
pub fn validate_tsv_document(doc : CsvDocument) -> CsvValidationReport {
  validate_csv_document(doc)
}

///|
/// Classify a hard TSV parse failure into the shared CSV error taxonomy.
pub fn classify_tsv_error(err : CsvError) -> CsvErrorInfo {
  classify_csv_error(err)
}
