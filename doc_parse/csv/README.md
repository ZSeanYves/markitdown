# doc_parse/csv

Purpose:

* parser/model/inspect/validation foundation for comma-delimited table-shaped
  text
* reusable lower-layer package inside `ZSeanYves/markitdown`
* not a Markdown table renderer and not a `RichTable` policy layer

Current status:

* simple-format parser foundation candidate
* stable as an in-tree parser/model/error/inspect/validation surface
* not a standalone MoonBit module split yet

Stable candidate API:

* `parse_csv_document`
* `parse_csv_with_options`
* `new_csv_parse_options`
* `inspect_csv_document`
* `collect_csv_validation_issues`
* `validate_csv_document`
* `classify_csv_error`
* `default_csv_parse_options`
* `csv_parse_options_for_tsv`

Minimal examples:

```moonbit
let doc = @csv.parse_csv_document("name,score\nalice,42\n")
let report = @csv.inspect_csv_document(doc)
let issues = @csv.collect_csv_validation_issues(doc)

println("rows=" + report.row_count.to_string())
println("issues=" + issues.length().to_string())
```

```moonbit
let custom = @csv.new_csv_parse_options()
custom.delimiter = @csv.CsvDelimiter::Comma
custom.trim_fields = true
let doc = @csv.parse_csv_with_options("a, b\n1, 2\n", custom)

for row in doc.rows {
  println(row.fields.join(" | "))
}
```

Build on top:

* ragged-row auditors, schema-ish CSV validators, and custom `CsvDocument`
  loaders can sit directly on this model without using `convert/csv`

Debug / inspect API:

* `inspect_csv_document`

Compatibility surface:

* `CsvDocument`
* `CsvRow`
* `CsvParseOptions`
* `CsvValidationIssue`
* `CsvValidationReport`

Internal exposed surface:

* there is no separate public parser-helper layer; delimiter scanning and quote
  handling stay internal to the package implementation

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
* exact row/field struct layout is still a compatibility surface first, even
  though it is now intentionally reusable by `convert/csv`

Performance note:

* small in-memory CSV parse/inspect paths are intended to stay lightweight
* benchmark CLI numbers should still be read separately from direct package
  usage because startup / I/O / lowering can dominate the total

Testing:

* lower-layer tests live in `doc_parse/csv/tests`
* converter behavior is regression-guarded separately under `convert/csv/test`

Versioning note:

* this package is stabilized in-tree first
* future release-policy work may still narrow field-level compatibility
  surfaces, add bytes-open helpers, or split module boundaries after broader
  internal validation
