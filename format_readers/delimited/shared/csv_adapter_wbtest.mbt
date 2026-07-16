///|
test "TSV adapter exposes parse inspect validation and error classification" {
  let doc = parse_tsv_document("name\tvalue\na\t1\n")
  assert_eq(inspect_tsv_document(doc).row_count, 2)
  assert_eq(collect_tsv_validation_issues(doc).length(), 0)
  assert_eq(validate_tsv_document(doc).error_count, 0)
  let classified = classify_tsv_error(ParseError("bad row"))
  assert_true(classified.detail.contains("bad row"))
}
