# doc_parse/csv

Purpose:

* parser/model/inspect/validation foundation for comma-delimited table-shaped
  text
* reusable lower-layer package inside `ZSeanYves/markitdown`
* not a Markdown table renderer and not a `RichTable` policy layer

Current status:

* internal foundation hardening
* not yet labeled as a standalone publishable package candidate

Public API:

* `parse_csv_document`
* `parse_csv_with_options`
* `new_csv_parse_options`
* `inspect_csv_document`
* `collect_csv_validation_issues`
* `validate_csv_document`
* `classify_csv_error`
* `default_csv_parse_options`
* `csv_parse_options_for_tsv`

Current model:

* `CsvDocument`
* `CsvRow`
* `CsvParseOptions`

Current error / validation surface:

* `CsvError`
* `CsvErrorInfo`
* `CsvValidationIssue`
* `CsvValidationReport`

Current inspect surface:

* row/column/line counts
* min/max field counts
* ragged row counts
* empty-cell counts
* multiline row / field counts

Current parser boundary:

* delimiter parsing
* quoted field parsing
* escaped quote parsing
* multiline field parsing
* ragged row preservation plus optional normalization

Non-goals:

* `RichTable`
* Markdown table rendering
* header-row product policy
* metadata/assets sidecar policy
* CLI/debug product formatting

Relationship to `convert/csv`:

* `doc_parse/csv` owns delimited parsing and table-shaped lower-layer model
* `convert/csv` owns `CsvDocument -> IR -> Markdown` lowering and origin
  policy

Known limits:

* current quoting behavior is intentionally narrow and RFC4180-ish, not a full
  spreadsheet import stack
* UTF-8 file I/O and non-BMP output compatibility policy still live in
  `convert/csv`

Testing:

* lower-layer tests live in `doc_parse/csv/tests`
* converter behavior is regression-guarded separately under `convert/csv/test`

Versioning note:

* this package is currently stabilized in-tree first
* future standalone extraction should happen only after API boundaries and
  consumer seams are tighter
