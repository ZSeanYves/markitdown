# doc_parse Examples

This directory is a lightweight documentation entrypoint for using the
`doc_parse/*` foundations directly inside `ZSeanYves/markitdown`.

These are README snippets first, not compiled example packages yet.

## What These Examples Show

The snippets below demonstrate how to:

* open or parse a document/package
* inspect structure without converting to Markdown
* collect validation issues
* classify hard parser/open errors
* build custom tooling on top of source-native models

They intentionally do not:

* call `convert/*`
* emit Markdown
* materialize assets
* imply full format-spec support

## Basic Inspect

```moonbit
let html = @html.parse_html_document("<h1>Hello</h1>")
let report = @html.inspect_html_document(html)
println("elements=" + report.element_count.to_string())
println("issues=" + report.issue_count.to_string())
```

## OOXML Inventory

```moonbit
let bytes = @fs.read_file_to_bytes("samples/main_process/docx/golden.docx")
let pkg = @ooxml.open_ooxml_package(bytes)
let inventory = @ooxml.inspect_ooxml_inventory(pkg)
println("parts=" + inventory.part_count.to_string())
println("relationships=" + inventory.relationship_count.to_string())
```

## XLSX Cells

```moonbit
let wb = @xlsx.open_xlsx_workbook("samples/benchmark/xlsx/xlsx_small.xlsx")
for sheet in wb.sheets {
  println(sheet.name)
  println("cells=" + sheet.cells.length().to_string())
}
```

## DOCX Structure

```moonbit
let doc = @docx.open_docx_document("samples/main_process/docx/golden.docx")
let report = @docx.inspect_docx_document(doc)
println("paragraphs=" + report.paragraph_count.to_string())
println("tables=" + report.table_count.to_string())
```

## PPTX Inventory

```moonbit
let pres = @pptx.open_pptx_presentation("samples/main_process/pptx/golden.pptx")
let report = @pptx.inspect_pptx_presentation(pres)
println("slides=" + report.slide_count.to_string())
println("shapes=" + report.shape_count.to_string())
```

## HTML Safety

```moonbit
let doc = @html.parse_html_document("<a href=\"javascript:alert(1)\">x</a>")
for issue in @html.collect_html_validation_issues(doc) {
  println(issue.message)
}
```

## Markdown Scan

```moonbit
let doc = @markdown.scan_markdown_document("---\ntitle: demo\n---\n# Hello\n")
let report = @markdown.inspect_markdown_document(doc)
println("frontmatter=" + report.frontmatter_count.to_string())
println("headings=" + report.heading_count.to_string())
```

## Build On Top

Typical custom consumers built on top of `doc_parse/*` include:

* document inspectors
* archive/path safety auditors
* broken-reference checkers
* OOXML media/link inventories
* custom chunkers or indexers
* converters into a private IR

Those consumers should treat `convert/*` as optional upper-layer product code,
not as the only way to reuse the parsing foundations.
