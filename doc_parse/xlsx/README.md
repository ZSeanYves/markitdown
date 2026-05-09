# doc_parse/xlsx

Purpose:

* SpreadsheetML workbook/sheet/cell semantic foundation inside
  `ZSeanYves/markitdown`
* reusable lower-layer package for workbook structure, sheet ordering,
  shared strings, styles/number formats, cells, merged ranges, and
  conservative formula trace signal
* not a `RichTable`, Markdown table, or final product-output policy layer

Current status:

* active semantic foundation Pass 1
* in-tree semantic/model/inspect/validation package, not a standalone MoonBit
  module split yet
* `convert/xlsx` now consumes this semantic workbook model while keeping
  RichTable / IR / Markdown / metadata policy in the converter layer

Current public API:

* `open_xlsx_workbook`
* `parse_xlsx_workbook_from_package`
* `inspect_xlsx_workbook`
* `collect_xlsx_validation_issues`
* `validate_xlsx_workbook`
* `classify_xlsx_error`

Inspect / validation API:

* `inspect_xlsx_workbook`
* `collect_xlsx_validation_issues`
* `validate_xlsx_workbook`

Compatibility surface:

* `XlsxWorkbook`
* `XlsxSheet`
* `XlsxCell`
* `XlsxStyles`
* `XlsxMergedRange`
* `XlsxFormulaTrace`
* `XlsxInspectReport`
* `XlsxValidationIssue`
* `XlsxValidationReport`

Internal exposed surface:

* Workbook/worksheet XML scanning helpers remain package-internal
* formula tokenization / parsing / conservative evaluation helpers remain
  internal
* OOXML relationship lookup and part-target normalization are consumed through
  `doc_parse/ooxml`, not re-exposed here as a second public helper layer

Current semantic boundary:

* workbook structure
* sheet order / names / visibility
* worksheet relationship targets
* shared strings
* cell style index -> number-format mapping
* conservative datetime-like display formatting
* raw cell types and display text
* raw formula text plus conservative formula trace
* merged ranges
* inspect counts and validation issue collection

Non-goals:

* `RichTable`
* Markdown table rendering
* header-row product policy
* sheet heading output
* empty-sheet / unsupported-sheet wording
* metadata sidecar policy
* assets / origin / CLI product formatting
* charts / pivots / VBA / external links
* full Excel engine or full formula evaluator

Relationship to `convert/xlsx`:

* `doc_parse/xlsx` owns SpreadsheetML semantic parsing/model/inspect/validation
* `convert/xlsx` owns `XlsxWorkbook -> RichTable -> IR -> Markdown` lowering
  and product-facing wording / hints / origin policy

Known limits:

* this package does not claim full Excel formula compatibility
* formula handling is current-policy raw formula capture plus conservative
  cached-value / missing-cache trace signal
* styles and number formats are used only for conservative semantic display,
  not as a full Excel style engine
* charts, pivots, comments, macros, and external links remain out of scope
* current workbook/sheet/cell field layout should be treated as a Pass 1
  compatibility surface rather than a finished standalone release contract

Testing:

* lower-layer tests live in `doc_parse/xlsx/tests`
* converter regression remains separately guarded in `convert/xlsx/test`

Versioning note:

* this package is intentionally being stabilized in-tree first
* future work may still narrow field-level compatibility surfaces, add
  additional open helpers, or split module boundaries after broader internal
  validation
