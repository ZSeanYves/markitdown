# XLSX Architecture Contract

Status: current architecture contract. XLSX does not require a full v2
replacement at this time.

The XLSX runtime differs from the old DOCX and PPTX cases that needed complete
replacement. Its parser and converter boundary is already close to the target
shape: `doc_parse/xlsx` owns SpreadsheetML package parsing and typed workbook
facts, while `convert/xlsx` consumes that model for product lowering. Future XLSX
work should proceed as local model, warning, metadata, and guard slices. Do not
create `doc_parse/xlsx_v2` or `convert/xlsx_v2` for the current cleanup path.

## Pipeline

```text
OOXML package
 -> XLSX package/workbook parser
 -> typed workbook/sheet/cell model
 -> convert lowering / RichTable policy
 -> core Document / Markdown / metadata / origins
```

## Layer Responsibilities

### OOXML/shared package layer

Responsibilities:

* Open OOXML packages and provide package/cache behavior.
* Read part text and bytes.
* Resolve relationships.
* Parse content types.
* Provide shared `docProps` readers where product metadata needs them.

Non-responsibilities:

* Spreadsheet semantic conversion.
* Markdown, RichTable, or workbook output policy.

### `doc_parse/xlsx`

Responsibilities:

* Discover the workbook and sheets.
* Preserve sheet order, names, relationship targets, and visibility state.
* Parse worksheet cells, references, source types, and values.
* Parse shared strings and inline strings.
* Preserve formulas, cached values, and missing-cache formula traces.
* Parse styles, `numFmtId` values, and conservative date/time display hints.
* Preserve merged-cell ranges.
* Preserve worksheet comments.
* Preserve hidden rows.
* Emit parser validation issues.
* Preserve discoverable unsupported workbook/sheet structures as typed facts and
  validation warnings.
* Emit bounded large-workbook guard warnings.

Non-responsibilities:

* Markdown table rendering.
* Sheet separator or heading policy.
* Dense/sparse preview policy.
* RichTable policy.
* Metadata sidecar rendering.
* Origin or block placement policy.

### `convert/xlsx`

Responsibilities:

* Consume the typed workbook model only.
* Apply sheet visibility and output policy.
* Lower sheets to RichTable/core IR.
* Choose empty sheet, missing sheet, and unsupported sheet wording.
* Enforce the dense-range guard.
* Produce sparse previews.
* Apply formula display policy using parser facts.
* Place the comments output section.
* Attach origin metadata and block metadata.
* Integrate with metadata sidecar output.

Non-responsibilities:

* Raw XLSX ZIP or XML part parsing.
* Relationship parsing.
* Shared strings or styles parsing.
* Fallback, oracle, or counter runtime logic.

## Current Supported Facts

The current typed XLSX model represents:

* Workbook-level state.
* Sheets, order, names, relationship targets, and visibility states.
* Cells and cell references.
* Sparse sheet data.
* Shared strings.
* Inline strings.
* Numbers, booleans, errors, blanks, and strings.
* Formulas, cached formula values, and missing-cache formula traces.
* Date/time display hints.
* Style indices and `numFmtId` values.
* Merged ranges.
* Worksheet comments.
* Worksheet hyperlinks.
* Structured table metadata.
* Workbook defined names and named ranges.
* Hidden rows.
* Validation issues.
* Typed unsupported workbook/sheet structure facts and warnings for protection,
  external links, drawings/images, charts, pivots, macros, OLE, threaded
  comments, and missing relationship targets where discoverable from
  relationships or low-risk XML markers.
* Bounded large-workbook warnings for shared string count/bytes/long strings,
  many sheets, many defined names, many parsed and non-empty cells, many tables,
  many merged ranges, many hyperlinks, large sparse dimensions, and expensive
  under-cap RichTable areas.

Document properties are currently read through shared OOXML/core metadata paths
for product sidecars. They are not unified into `XlsxWorkbook`.

## Current Product Policies

`convert/xlsx` owns these current policies:

* Hidden and very-hidden sheets are available to inspect-style paths but skipped
  in normal Markdown output.
* Visible sheets are emitted with sheet headings.
* Sheet data is lowered as RichTable when it is bounded and non-empty.
* Dense table materialization is capped at 1,000,000 cells.
* Large sparse sheets emit a bounded preview of up to 100 visible non-empty
  cells.
* Worksheet comments are emitted in a sheet-local comments section.
* Worksheet hyperlinks are rendered conservatively as Markdown links inside
  table cell text when a concrete target is available.
* Structured table and defined-name facts are preserved for inspect/metadata
  paths without changing normal sheet table rendering.
* RichTable origins carry bounded, structured `key_path` summaries for concrete
  cell hyperlinks, range hyperlinks, structured tables, defined names, and
  sheet-level unsupported facts.
* Cached formula values are preferred when present; missing-cache formulas use
  conservative trace/evaluation signals rather than a full Excel engine.
* Empty, missing, and unsupported sheets use product-facing placeholder wording.
* Origins and metadata are attached during conversion and sidecar emission.

## Known Gaps / Roadmap

Model facts:

* Richer workbook and sheet protection facts beyond warning classification.
* Richer external link facts beyond warning classification.
* Threaded comments as parsed facts.
* Full Excel table rendering semantics beyond preserving table metadata.
* Drawings, images, charts, pivots, macros, and OLE as future supported
  structures rather than current typed unsupported facts.

Warning taxonomy:

* More detailed sub-classification inside unsupported charts, drawings/images,
  pivot tables, VBA/macros, OLE objects, and external links.
* Corrupted or missing relationships.
* Protected or hidden structures beyond current warning-level classification.
* Unsupported cell and style features.

Metadata:

* Unify the `docProps` contract with the workbook model or document the product
  sidecar boundary more explicitly.
* Keep metadata sidecar rendering in convert/core policy.
* XLSX table blocks carry compact structured origin metadata for typed concrete
  cell hyperlinks, range hyperlinks, table, defined-name, and unsupported facts;
  a formal core metadata schema remains future work.

Performance guards:

* Shared strings memory use and copying.
* Full in-memory sheet parsing.
* Merged range lookup complexity if rendering policy becomes richer.
* Style lookup caching.
* Streaming or chunked parsing for truly huge workbooks.

Quality and bench:

* Keep current repository samples, external quality rows, and benchmark rows
  green.
* Add targeted rows only after each unsupported policy is explicit.
* Do not change expected files as part of architecture-contract work.

## Rewrite Decision

Option 1 is selected: no complete XLSX v2 replacement.

Do not create `doc_parse/xlsx_v2` or `convert/xlsx_v2`. Future XLSX work should
be local refactor, typed model extension, warning taxonomy, metadata contract,
or performance guard slices inside the current package structure.

## Acceptance Criteria For Future Cleanup

* `convert/xlsx` still does not scan raw XLSX XML or ZIP parts.
* Parser/model changes emit typed facts and warnings.
* Unsupported structures are visible through warnings or typed unsupported facts,
  not silently dropped.
* Large workbooks remain bounded.
* Repository samples, external quality checks, and benchmark rows stay green.
