# doc_parse/tsv

Purpose:

* thin tab-delimited facade over `doc_parse/csv`
* reusable parser/model/inspect/validation entrypoint for TSV input

Current status:

* simple-format parser foundation candidate
* thin in-tree candidate facade over `doc_parse/csv`
* not a standalone MoonBit module split yet

Stable candidate API:

* `parse_tsv_document`
* `inspect_tsv_document`
* `collect_tsv_validation_issues`
* `validate_tsv_document`
* `classify_tsv_error`

Minimal examples:

```moonbit
let doc = @tsv.parse_tsv_document("name\tscore\nalice\t42\n")
let report = @tsv.inspect_tsv_document(doc)

println("rows=" + report.row_count.to_string())
println("max_fields=" + report.max_field_count.to_string())
```

```moonbit
let doc = @tsv.parse_tsv_document("name\tscore\nalice\t42\tunexpected\n")
for issue in @tsv.collect_tsv_validation_issues(doc) {
  println(issue.message)
}
```

Build on top:

* TSV row auditors and custom table importers can reuse the shared CSV model
  directly without taking a Markdown dependency

Debug / inspect API:

* `inspect_tsv_document`

Current model:

* reuses `doc_parse/csv` model types such as `CsvDocument` and `CsvRow`

Compatibility surface:

* the TSV facade intentionally reuses `doc_parse/csv` model, inspect, error,
  and validation types

Internal exposed surface:

* there is no duplicated TSV-specific parser core; delimiter routing is the
  only package-local implementation layer

Boundary:

* owns delimiter=`tab` parser entry
* does not duplicate CSV parser logic
* does not own Markdown table rendering or `RichTable` policy

Relationship to `convert/csv`:

* `convert/csv` still owns TSV-to-IR / Markdown conversion semantics

Known limits:

* follows the same quoted-field and ragged-row behavior as `doc_parse/csv`
* remains a thin facade rather than an independently deep parser stack

Performance note:

* this facade adds minimal logic on top of the CSV core
* benchmark rows should still distinguish TSV parsing from converter-side
  `RichTable` / Markdown work

Versioning note:

* future release-policy work may decide whether TSV should remain a thin facade
  forever or later gain a narrower independent surface

Testing:

* lower-layer tests live in `doc_parse/tsv/tests`
