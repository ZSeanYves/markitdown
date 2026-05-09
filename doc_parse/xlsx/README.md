# doc_parse/xlsx

Purpose:

* SpreadsheetML workbook/sheet/cell semantic foundation inside
  `ZSeanYves/markitdown`
* reusable lower-layer package for workbook structure, sheet ordering,
  shared strings, styles/number formats, cells, merged ranges, and
  conservative formula trace signal
* not a `RichTable`, Markdown table, or final product-output policy layer

Current status:

* XLSX semantic foundation candidate
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

Stable candidate API:

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

Minimal examples:

```moonbit
let wb = @xlsx.open_xlsx_workbook("samples/benchmark/xlsx/xlsx_small.xlsx")
let report = @xlsx.inspect_xlsx_workbook(wb)

println("sheets=" + report.sheet_count.to_string())
println("cells=" + report.cell_count.to_string())
```

```moonbit
for sheet in wb.sheets {
  println(sheet.name)
  for cell in sheet.cells {
    println(cell.reference + " = " + cell.display_text)
  }
}
```

```moonbit
let _ = @xlsx.open_xlsx_workbook("missing.xlsx") catch {
  err => {
    let info = @xlsx.classify_xlsx_error(err)
    println(info.kind.to_string())
    println(info.detail)
    @xlsx.open_xlsx_workbook("samples/benchmark/xlsx/xlsx_small.xlsx")
  }
}
```

Build on top:

* workbook analyzers, formula auditors, sheet inventory tools, and custom cell
  loaders can consume `XlsxWorkbook` directly without pulling in `RichTable`

Compatibility surface:

* `XlsxWorkbook`
* `XlsxSheet`
* `XlsxCell`
* `XlsxFormulaPolicy`
* `XlsxStyles`
* `XlsxMergedRange`
* `XlsxFormulaTrace`
* `XlsxSheetState`
* `XlsxCellKind`
* `XlsxCellSemanticType`
* `XlsxError`
* `XlsxErrorInfo`
* `XlsxInspectReport`
* `XlsxValidationIssue`
* `XlsxValidationReport`

Internal exposed surface:

* Workbook/worksheet XML scanning helpers remain package-internal
* cell-reference parsing, merged-range parsing, and shared-string decoding
  helpers remain internal
* formula tokenization / parsing / conservative evaluation helpers remain
  internal
* style/number-format scanning and datetime-like formatting helpers remain
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

Formula / style / date / merge boundary:

* raw formula text is preserved on cells
* cached formula values are preserved when present
* conservative missing-cache evaluation is exposed only through
  `XlsxFormulaTrace`, not as a full Excel engine contract
* unsupported formula evaluation is surfaced as validation issue / trace
  signal, not as blanket hard failure
* style index and `numFmtId` are preserved where available
* builtin/custom datetime-like detection is conservative semantic formatting,
  not final output policy
* the workbook `date1904` flag is preserved as semantic workbook signal
* merged-range refs are preserved and invalid merged refs are reported, but no
  visual reconstruction is attempted

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
* current workbook/sheet/cell field layout is an in-tree candidate
  compatibility surface, not a promise of full standalone Excel semantics

Performance note:

* package and XML parsing costs are heavier than lightweight text formats, so
  benchmark this layer separately from final table/Markdown lowering
* current public benchmarks are still product-path timings first, not isolated
  `doc_parse/xlsx` library timings

Testing:

* lower-layer tests live in `doc_parse/xlsx/tests`
* converter regression remains separately guarded in `convert/xlsx/test`

Versioning note:

* this package is intentionally being stabilized in-tree first
* future work may still narrow field-level compatibility surfaces, add
  additional open helpers, or split module boundaries after broader internal
  validation
* candidate status here means the in-tree semantic workbook API and lower-layer
  tests are stable enough for internal reuse; it does not claim a full Excel
  engine or a separately published MoonBit module
