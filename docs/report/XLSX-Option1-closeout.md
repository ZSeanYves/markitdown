# XLSX Option 1 Closeout Report

Date: 2026-06-07
HEAD: `0964ea3`

## Summary

XLSX remains on the Option 1 architecture: no full v2 replacement was created.
The active runtime continues to use the existing `doc_parse/xlsx` and
`convert/xlsx` boundary:

```text
OOXML package
 -> doc_parse/xlsx SpreadsheetML parser
 -> typed workbook/sheet/cell model
 -> convert/xlsx RichTable / Markdown lowering
 -> core Document / metadata / origins
```

`doc_parse/xlsx` owns XLSX package and XML parsing. `convert/xlsx` consumes typed
facts only and owns output policy. There is no `doc_parse/xlsx_v2`,
`convert/xlsx_v2`, dispatcher switch, dual runtime, legacy oracle, or normal
runtime fallback path.

The closeout runtime commit is:

```text
0964ea3 xlsx: complete Option 1 cleanup with typed facts, warning taxonomy, table/defined name support, cell-level link metadata, and performance guards
```

## Current Runtime Status

Current XLSX normal conversion is still routed through `convert/xlsx`, backed by
the semantic parser/model in `doc_parse/xlsx`.

The runtime now has a clearer parser/converter split:

- `doc_parse/xlsx` parses workbook XML, worksheets, relationships, shared
  strings, styles, tables, defined names, hyperlinks, unsupported source facts,
  and bounded validation warnings.
- `convert/xlsx` mirrors the semantic model into converter-facing structs,
  applies sheet visibility and RichTable policy, renders conservative Markdown
  links, emits sparse-sheet previews, and attaches bounded origin `key_path`
  metadata.
- `convert/xlsx` does not read raw XLSX package parts and does not parse
  workbook XML, sheet XML, shared strings, styles, or `.rels` files.

## Completed Runtime Slices

### Typed Workbook, Sheet, and Cell Facts

The current XLSX model preserves:

- workbook state, `date1904`, shared strings, styles, and validation issues
- sheet order, names, IDs, relationship IDs, relationship targets, visibility,
  hidden rows, used range, and missing/unsupported sheet facts
- cell references, rows, columns, raw cell kinds, display text, source values,
  formulas, semantic types, style index, number format ID, and cell issues
- formula traces for cached values, conservative missing-cache evaluation,
  unsupported formula evaluation, and formula errors
- merged ranges and worksheet comments

### Hyperlink Facts and Cell-Level Metadata

Worksheet hyperlinks are typed as `XlsxHyperlink` facts and are available both
at sheet level and on safely associated concrete cells.

Implemented behavior:

- external, internal, and unknown hyperlink kinds
- relationship ID, target, location, tooltip, display, range coordinates, and
  warning preservation
- conservative Markdown link rendering in table cells when a concrete target is
  available
- bounded cell hyperlink lookup so large ranges are not expanded
- structured RichTable origin `key_path` summaries:
  - `cell_links=cell=A2,kind=external,target=...,rid=...,display=...,tooltip=...`
  - `range_links=ref=A1:ALL2000,kind=external,target=...,rid=...`

Large hyperlink ranges remain range-level facts when expansion would exceed the
safe cap.

### Structured Table and Defined Name Facts

Structured table facts are preserved without changing main Markdown rendering.

The model now carries:

- table ID, name, display name, range, coordinates, owning sheet, source part,
  and relationship ID
- header and totals row counts
- header/totals visibility
- table style name
- auto-filter range
- column IDs, names, totals row labels, and totals row functions

Workbook defined names and named ranges are preserved as `XlsxDefinedName`
facts, including:

- name and source text
- sheet scope and sheet scope index
- kind classification: named range, print area, auto filter, formula-like, or
  unknown
- target sheet/range when simple and safely parsed
- hidden flag and source

`convert/xlsx` mirrors these typed facts into inspect and origin metadata. It
does not parse table XML or workbook XML directly.

### Unsupported Feature Facts and Warning Taxonomy

Discoverable unsupported workbook/sheet structures are now surfaced as typed
`XlsxUnsupportedFeature` facts plus validation issues. They are not silently
dropped.

Current typed unsupported feature coverage includes:

- drawings
- charts
- images
- pivot tables
- VBA/macros
- OLE objects
- external links
- threaded comments
- sheet protection
- workbook protection
- unknown or missing relationship targets

Each fact carries kind, severity, sheet name when applicable, relationship ID,
part target, source, and message.

This is warning/fact surfacing only. It is not full chart, drawing, image,
pivot, macro, OLE, external-link, or threaded-comment content conversion.

### Large-Workbook Guards

Guard thresholds are centralized in `doc_parse/xlsx/xlsx_guards.mbt`.

Current bounded warnings cover:

- large shared string count
- large shared string text bytes
- unusually long shared strings
- many sheets
- many defined names
- many parsed cells in one sheet
- many non-empty cells in one sheet
- many merged ranges
- many hyperlinks
- many structured tables
- large sheet dimensions with sparse data
- under-cap but expensive RichTable areas

The guard work does not implement a streaming parser rewrite. It adds bounded
warnings and keeps existing dense range and sparse preview policy intact.

## Validation

Validation was run after the runtime closeout commit.

```text
moon check doc_parse/xlsx convert/xlsx
```

Result:

```text
pass
```

```text
moon test doc_parse/xlsx/tests
```

Result:

```text
pass, 19/19 tests
```

```text
moon test convert/xlsx/test
```

Result:

```text
pass, 17/17 tests
```

```text
bash samples/check.sh --format xlsx
```

Result:

```text
pass, formats=xlsx rows=35 checked=35 skipped=1 failed=0
```

```text
bash samples/check_quality.sh --format xlsx
```

Result:

```text
pass, rows=53 checked=47 skipped=6 failed=0
```

```text
bash samples/bench.sh --layer convert --format xlsx --iterations 1 --warmup 0
```

Result:

```text
pass, layer=convert rows=1 iterations=1 warmup=0 median=352.000ms runner=prebuilt
```

```text
moon check
```

Result:

```text
pass
```

Existing unrelated warnings during full `moon check`:

- `convert/epub/epub_part_cache.mbt:53` unused function
  `read_epub_part_text_cached`
- `convert/markdown/test/markdown_passthrough_test.mbt:185` deprecated debug
  warning

## Boundary Greps

### Convert Runtime Raw XLSX Part Scanning

Runtime-only grep:

```text
rg -n "xl/workbook\.xml|xl/worksheets|xl/sharedStrings\.xml|xl/styles\.xml|\.rels|read_part|parse XML" convert/xlsx/*.mbt
```

Result:

```text
no hits
```

Full `convert/xlsx` grep has hits only in `convert/xlsx/test/xlsx_test.mbt`,
where generated XLSX package fixtures construct workbook, worksheet,
shared-string, style, and relationship parts for tests.

Conclusion:

- normal `convert/xlsx` runtime does not scan raw XLSX ZIP/XML parts
- normal `convert/xlsx` runtime does not read `workbook.xml`, worksheet XML,
  `sharedStrings.xml`, `styles.xml`, or `.rels`
- test fixture strings are expected and are not runtime parsing logic

### Fallback, Legacy, Oracle, Counter

Grep:

```text
rg -n "fallback|legacy|oracle|counter" convert/xlsx doc_parse/xlsx
```

Classified hits:

- `convert/xlsx/test/xlsx_test.mbt`: sample path helper variable named
  `fallback`
- `convert/xlsx/test/xlsx_test.mbt`: test wording for sparse-sheet fallback
  behavior
- `doc_parse/xlsx/tests/xlsx_parser_test.mbt`: sample path helper variable named
  `fallback`
- `doc_parse/xlsx/xlsx_datetime.mbt`: existing comment,
  `fallback: datetime-like but ambiguous`

Focused grep:

```text
rg -n "legacy|oracle|counter" convert/xlsx doc_parse/xlsx
```

Result:

```text
no hits
```

Conclusion:

- no normal runtime legacy/oracle/counter glue
- no normal runtime v1 fallback
- `fallback` hits are test helpers, test wording, or an existing explanatory
  comment

## Parity and Non-Goals

Covered parity / stability gates:

- existing XLSX repo-local samples remain green
- external quality XLSX rows remain green
- convert-layer benchmark row remains green
- inspect surface preserves typed facts for links, tables, defined names,
  unsupported structures, validation issues, and guards
- normal Markdown output remains stable; samples expected files were not
  changed
- quality-lab manifests were not changed

Deliberate non-goals for this closeout:

- no full XLSX v2 replacement
- no dispatcher or CLI route switch
- no dual runtime
- no Excel formula engine
- no full Excel structured table renderer
- no chart rendering
- no image/drawing rendering beyond unsupported fact surfacing
- no pivot table conversion
- no macro/VBA execution or conversion
- no OLE rendering
- no threaded comment content conversion
- no streaming-scale parser rewrite

Unsupported structures are surfaced as typed facts and validation warnings where
discoverable. They are not claimed as fully supported output features.

## Commit Readiness

The XLSX Option 1 runtime cleanup has already been committed:

```text
0964ea3 xlsx: complete Option 1 cleanup with typed facts, warning taxonomy, table/defined name support, cell-level link metadata, and performance guards
```

Committed runtime/docs scope:

```text
convert/xlsx/**
convert/xlsx/test/**
doc_parse/xlsx/**
doc_parse/xlsx/tests/**
doc_parse/xlsx/README.md
docs/archive/README.md
docs/archive/xlsx-architecture.md
```

Commit stat:

```text
14 files changed, 3675 insertions(+), 14 deletions(-)
```

This closeout report is a follow-up archive/report artifact and does not modify
runtime code.

## Git Snapshot

Snapshot immediately after runtime commit and validation:

```text
git status --short --untracked-files=all
```

Result:

```text
clean
```

```text
git diff --stat
```

Result:

```text
empty
```

```text
git diff --cached --stat
```

Result:

```text
empty
```

After adding this report file, the expected working tree delta is this report
only:

```text
?? docs/report/XLSX-Option1-closeout.md
```

## Future Optional Slices

Recommended future work, all optional and compatible with Option 1:

1. Formal core metadata schema

   Promote the current bounded `key_path` summaries for cell links, range links,
   tables, defined names, and unsupported facts into a formal core metadata
   schema if downstream consumers need typed metadata instead of compact strings.

2. Chart, image, drawing, and pivot enhancements

   Add richer typed inventories or optional product rendering for charts,
   images/drawings, and pivot tables. Keep unsupported facts explicit until a
   real conversion policy is implemented.

3. Threaded comments

   Parse threaded comment parts as source facts and decide whether normal
   Markdown should render them, expose them only through inspect/metadata, or
   keep them warning-only.

4. External link and protection detail

   Preserve richer workbook/sheet protection details and external-link metadata
   beyond the current warning-level classification.

5. Streaming-scale parser work

   Introduce streaming or chunked parsing for truly huge workbooks if future
   quality or benchmark rows require it. Current guards are bounded warnings,
   not a streaming rewrite.

## Closeout Decision

Option 1 remains the correct XLSX path.

No `xlsx_v2` package is needed for the current runtime. The scoped cleanup is
complete: typed facts, warning taxonomy, cell-level link metadata, table/defined
name support, unsupported feature surfacing, guard polish, tests, samples,
quality, bench, and architecture docs are all green within the existing
`doc_parse/xlsx` and `convert/xlsx` boundary.
