# Progress Summary

This document is a stage-level progress snapshot. It is meant to answer:

* what has already landed
* what is currently stable enough to treat as part of the working contract
* what is explicitly deferred to later rounds
* what the next candidate workstreams are

For detailed support boundaries, use [docs/support-and-limits.md](/home/zseanyves/markitdown/docs/support-and-limits.md). For benchmark execution details, use [docs/development.md](/home/zseanyves/markitdown/docs/development.md). For the current internal benchmark reference, use [docs/benchmark-baseline.md](/home/zseanyves/markitdown/docs/benchmark-baseline.md).

## 1. Format Expansion

The current format-expansion stage has landed four text / structured-input paths:

* CSV / TSV
* JSON
* Markdown passthrough
* YAML
* ZIP container conversion for text / structured / Office / PDF / HTML entries

Current positioning:

* CSV / TSV: delimited text mapped into unified IR `Table`
* JSON: structured data mapped conservatively into `Table` / `List` / `CodeBlock`
* YAML: simple subset mapping / sequence input mapped conservatively into
  `Table` / `List` / `CodeBlock`
* Markdown passthrough: low-loss path that preserves the source Markdown body
  rather than rebuilding from a Markdown AST
* ZIP: safe archive traversal that converts supported entries in normalized path
  order, remaps nested assets into archive namespaces, and supports same-archive
  HTML local images through a safe extracted tree

## 2. General Capabilities

### G1. Link Preservation

Current landed scope:

* HTML link preservation
* DOCX link preservation
* PPTX link preservation

Current contract:

* preserve supported source-native external links when the source relationship /
  href is valid
* degrade to visible plain text when the source target is missing, empty,
  internal-only, or unsupported

### G2. Origin Metadata

Current landed scope:

* additive origin schema extension
* sparse additive-field emission
* OOXML origin refinement
* structured / text origin refinement
* HTML image `source_path` refinement

Current outcome:

* block-level and asset-level origin metadata is available inside the existing
  sidecar schema
* origin remains best-effort provenance, not a full layout trace or a complete
  source anchoring system

### G3. Image Context

Current landed scope:

* unified `ImageBlock` / `ImageData` semantics
* HTML image context
* DOCX source-native image `descr/title`
* PPTX source-native picture `descr/title`
* PDF conservative single-image caption pairing

Current outcome:

* `blocks[].image` is the block-side image-context carrier
* `assets[].alt_text/title/caption` are mirrored from the corresponding
  `ImageBlock`
* `nearby_caption` remains an asset-origin mirror, not an independent
  caption-inference slot

### G4. Support Matrix / Graceful Degradation

Current landed scope:

* product-facing support matrix
* per-format support / partial support / degradation / unsupported boundaries
* shared degradation principles documented across formats

Current outcome:

* the repository now has an explicit support contract instead of relying on
  implicit test coverage alone
* graceful degradation is documented as a converter-level design principle

### G5. Table Semantics

Current landed scope:

* G5.1 explicit table header semantics
* G5.2 RichTable structured metadata

Current outcome:

* core IR now has `TableData { rows, header_rows }`
* `Block::RichTable(TableData)` carries explicit header semantics
* legacy `Block::Table(Array[Array[String]])` remains supported and keeps its
  historical Markdown behavior
* HTML tables use `RichTable(header_rows = 1)` only when `<th>` or `<thead>` is
  explicitly present
* JSON / YAML synthetic object and array-of-objects tables use
  `RichTable(header_rows = 1)`
* `blocks[].table` is an additive structured metadata field emitted only for
  `RichTable`
* legacy `Table` metadata remains flat-text only and does not synthesize
  `header_rows = 1`
* metadata version remains `1`

Current explicitly deferred table scope:

* CSV / TSV / XLSX / DOCX do not default-switch to `RichTable`
* PDF / PPTX table-like regions are not promoted to semantic Table IR
* cell-level metadata is not emitted
* alignment is not modeled
* rowspan / colspan semantics are not modeled
* merged-cell reconstruction is not performed
* table cell origin is not tracked

### Z1. Container Conversion

Current landed scope:

* Z1.1c ZIP container conversion with asset namespace/remap and HTML local
  image materialization

Current outcome:

* `.zip` inputs route through a container converter
* entry paths are normalized and checked before temporary extraction
* directory entries and common macOS metadata entries are skipped
* supported entries are `.md` / `.markdown`, `.csv` / `.tsv`, `.json`,
  `.yaml` / `.yml`, `.docx`, `.pdf`, `.xlsx`, `.pptx`, and `.html` / `.htm`
* Markdown / CSV / TSV / JSON / YAML / static HTML entries convert directly,
  while self-contained DOCX / PPTX / XLSX / PDF entries also support asset
  export inside the archive flow
* entries are processed in normalized path order and emitted under
  `# archive/path.ext` headings
* nested entry assets are remapped under `assets/archive/<entry-id>/...`
* repeated converter-local asset names such as `image01.*` stay isolated across
  archive entries through that namespace/remap
* HTML local images work when referenced sibling files are safe entries in the
  same archive and the `src` stays within the existing conservative HTML local
  path rules
* unsupported entries, nested archives, and failed entry conversions emit
  blockquote warnings
* normalized path collisions fail the archive closed
* low-level unsupported ZIP features such as encrypted inputs, ZIP64, data
  descriptors, multi-disk archives, or duplicate raw entry names fail closed
* current entry-count, per-entry-byte, and total-byte limits are enforced
* metadata schema remains unchanged; entry block origins and remapped asset
  origins use the normalized entry path as ZIP-level provenance, while inner
  `relationship_id` / `object_ref` are preserved when present

Current explicitly deferred ZIP scope:

* nested archive recursion
* remote fetch for HTML image refs inside ZIP
* `data:`/absolute/root-relative/parent/scheme-like/backslash HTML image refs
  inside ZIP
* binary preview
* full archive extraction without the existing safety checks
* streaming archive conversion
* `.txt` conversion without a dedicated text converter
* preserving inner HTML image `src` as a separate metadata field

## 3. Benchmark

Current benchmark infrastructure has landed in four pieces:

* smoke benchmark corpus and runner
* iterations / warmup controls
* optional benchmark tiers
* baseline documentation

Current benchmark surface:

* `samples/bench_smoke.sh`
* `samples/benchmark/corpus.tsv`
* `results.jsonl`
* `summary.tsv`

Current benchmark capabilities:

* default `smoke` tier for low-cost daily runs
* optional `image`, `metadata`, `extended`, and `all` tiers
* configurable `BENCH_ITERATIONS` / `BENCH_WARMUP`
* isolated benchmark output under `MARKITDOWN_TMP_DIR`
* checked-in internal baseline documentation for the current environment

## 4. Explicitly Deferred / Not Yet Done

The following items are intentionally not claimed as done at the current stage:

* PDF annotation link Markdown emission
* PDF / PPTX multi-image caption pairing
* PDF full `source_refs` / bbox default sidecar emission
* table cell-level provenance
* table alignment / span / merged-cell reconstruction
* JSON / YAML nested provenance
* OCR as the default conversion path
* Python MarkItDown benchmark comparison

These are deferred items, not hidden behavior gaps.

## 5. Next-stage Candidates

Reasonable next candidates after the current stage:

* B5: Python MarkItDown comparison audit
* OCR regression closure
* EPUB / ZIP expansion
* ZIP HTML dependency refinement beyond safe sibling materialization
* PDF core / convert next round

## 6. Current Status

At the current point, the repository has:

* a multi-format conversion mainflow with documented support boundaries
* a stable metadata-sidecar contract for current G2 / G3 scope
* completed G5 table semantics for explicit headers and RichTable metadata
* a documented degradation model instead of ad hoc fallback behavior
* an internal benchmark harness with baseline recording

This is enough to treat the current stage as a coherent, documented milestone,
while still keeping the deferred items explicit for future work.
