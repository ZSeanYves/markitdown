# doc_parse/tsv

Purpose:

* thin tab-delimited facade over `doc_parse/csv`
* reusable parser/model/inspect/validation entrypoint for TSV input

Current status:

* internal foundation hardening
* not yet labeled as a standalone publishable package candidate

Public API:

* `parse_tsv_document`
* `inspect_tsv_document`
* `collect_tsv_validation_issues`
* `validate_tsv_document`
* `classify_tsv_error`

Current model:

* reuses `doc_parse/csv` model types such as `CsvDocument` and `CsvRow`

Boundary:

* owns delimiter=`tab` parser entry
* does not duplicate CSV parser logic
* does not own Markdown table rendering or `RichTable` policy

Relationship to `convert/csv`:

* `convert/csv` still owns TSV-to-IR / Markdown conversion semantics

Known limits:

* follows the same quoted-field and ragged-row behavior as `doc_parse/csv`
* remains a thin facade rather than an independently deep parser stack

Testing:

* lower-layer tests live in `doc_parse/tsv/tests`
