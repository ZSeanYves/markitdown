# XLSX H1/H2 Review

This document records the current XLSX H1/H2 review status for
`markitdown-mb`.

It is an audit and planning document. The detailed support contract remains
[docs/support-and-limits.md](./support-and-limits.md).

## Current implementation map

### Converter and lower layer

* converter entry: `convert/xlsx/xlsx_parser.mbt`
* package open + workbook rel resolution: `convert/xlsx/xlsx_package.mbt`
* worksheet table extraction: `convert/xlsx/xlsx_sheet.mbt`
* shared strings: `convert/xlsx/xlsx_shared_strings.mbt`
* styles / numFmt handling: `convert/xlsx/xlsx_styles.mbt`
* datetime formatting: `convert/xlsx/xlsx_datetime.mbt`
* XML helpers: `convert/xlsx/xlsx_xml.mbt`
* shared OOXML substrate: `doc_parse/ooxml/*`

### Dispatch and container wiring

* `.xlsx` is routed through the shared dispatcher
* ZIP entry conversion also routes self-contained `.xlsx` entries through the
  same parser path

### Metadata / provenance

* metadata format is `xlsx`
* `source_name` and `sheet` are populated
* table origins carry `sheet`, `line_start`, `line_end`, `row_index`,
  `column_index`, and `relationship_id`
* `asset_count` is always `0` in the current XLSX path

## Current H1 status

### Supported and stable in H1

* workbook-order multi-sheet output
* sheet headings followed by one legacy table per sheet
* sparse bounding-box trimming
* empty-cell preservation inside the retained bounding box
* shared strings
* inline strings
* numeric cells
* boolean cells
* error cells
* built-in date / time / datetime formatting
* custom numFmt datetime detection where the current style scan is sufficient
* workbook document-properties metadata through shared OOXML support

### Current policy fixed by regression

* formulas are not evaluated
* cached values are emitted when present
* formula cells without cached values degrade to empty cells
* merged cells currently keep only the top-left visible value
* hidden sheets are currently still emitted in workbook order
* tables remain legacy `Table` output rather than richer sheet-aware table IR

### Known H1 limits

* no merged-cell reconstruction beyond the current top-left-only behavior
* no formula policy beyond cached-value passthrough
* no chart / drawing / image / comment / pivot export
* no explicit hidden-sheet filtering
* sparse extraction is single bounding-box based, so widely separated populated
  regions can preserve large blank interiors
* no physical cell-by-cell metadata beyond sheet/range anchoring on the table

## H2 gap table

| Area | Current behavior | Market expectation | Gap | Bottom-layer needed? | Suggested action |
| --- | --- | --- | --- | --- | --- |
| Merged cells | Top-left value only; rest of range is effectively empty | Better merged-range reconstruction or explicit policy controls | Large | Yes | Parse and model merged ranges before converter changes |
| Formula policy | Cached result only; no cached value means blank | Clearer formula/cached-result policy and better no-cache fallback | Large | Yes | Preserve formula text and cached result distinctly in lower layer |
| Custom number formats | Partial custom datetime-like detection | Broader custom format fidelity | Moderate | Yes | Strengthen style/numFmt parsing and classification |
| Date/time precision | Common builtin/custom datetime cases are stable | Wider precision/locale fidelity across real workbooks | Moderate | Yes | Expand format coverage with lower-layer tests before converter polish |
| Hidden sheets | Hidden sheets are still emitted | Clear policy: include/exclude/annotate hidden sheets | Moderate | Partly | Preserve sheet state in the workbook model and define policy explicitly |
| Comments/notes | Not surfaced | Comments/notes often preserved by mainstream tools | Large | Yes | Expose comment parts and relationships in OOXML lower layer |
| Charts/images/drawings | Not surfaced | Better non-cell artifact awareness | Large | Yes | Add drawing/chart/image access surfaces before any converter-level semantics |
| Workbook metadata | Basic docProps only | Richer workbook-level metadata and sheet state | Moderate | Yes | Extend workbook model, not converter string hacks |
| Large workbook performance | Only light smoke coverage existed before this review | Stable small/medium/large/sparse/multi-sheet benchmarks | Moderate | Partly | Keep expanding corpus and profile parser vs table materialization |
| Sparse trimming correctness | Single bounding box can over-preserve blank interiors | More region-aware trimming | Large | Yes | Model sparse regions explicitly before changing converter output |
| Sheet/table provenance | Table origin anchors to one rectangular range | Finer provenance for cell/range level reasoning | Moderate | Yes | Improve worksheet model and metadata extraction surfaces |
| Multi-sheet organization | Workbook order is stable | Better grouping/annotation for real workbooks | Small | Partly | Add real-world coverage and decide if hidden/aux sheets need policy changes |
| Markdown escaping in cells | Pipe escaping is stable under current emitter | Broader Markdown-safety confidence | Small | No | Add more cell-content regression cases |

## XLSX lower-layer gaps

The XLSX path already reuses the shared OOXML package base, which is a strong
starting point. The main H2 blockers now come from worksheet/model depth rather
than from basic package access.

### Stable enough today

* OOXML package open/read path is shared and reusable
* workbook relationship resolution is in place
* shared strings and inline strings are accessible
* basic styles and builtin/custom datetime-like numFmt mapping exist
* table-range provenance can point back to sheet and top-left row/column

### Lower-layer gaps that likely gate H2 quality

* sheet state is not preserved in the parsed `SheetInfo` model
* merged ranges are not parsed/modelled
* formula text and cached result are not preserved as separate structured data
* worksheet extraction is cell-scan plus one bounding box, not a richer sparse
  region model
* comments / notes / drawings / charts / images are not surfaced
* number-format support is still intentionally narrow
* debug/dump surfaces for worksheet structure are lighter than what deeper H2
  workbook triage will likely need

### Recommendation

If XLSX H2 work stalls, strengthen the OOXML/XLSX lower layer first:

* preserve sheet state in workbook parsing
* model merged ranges explicitly
* preserve formula text plus cached values together
* add richer sparse-region/worksheet modeling
* expose comments/drawings relationships before converter-level semantics
* improve styles/numFmt coverage with dedicated lower-layer tests

Do not try to close these gaps only by piling converter-local table text
patches onto the current worksheet scan.
