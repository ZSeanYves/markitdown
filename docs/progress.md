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

Current positioning:

* CSV / TSV: delimited text mapped into unified IR `Table`
* JSON: structured data mapped conservatively into `Table` / `List` / `CodeBlock`
* YAML: simple subset mapping / sequence input mapped conservatively into
  `Table` / `List` / `CodeBlock`
* Markdown passthrough: low-loss path that preserves the source Markdown body
  rather than rebuilding from a Markdown AST

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
* JSON / YAML nested provenance
* OCR as the default conversion path
* Python MarkItDown benchmark comparison

These are deferred items, not hidden behavior gaps.

## 5. Next-stage Candidates

Reasonable next candidates after the current stage:

* B5: Python MarkItDown comparison audit
* G5: table semantics refinement
* OCR regression closure
* EPUB / ZIP expansion
* PDF core / convert next round

## 6. Current Status

At the current point, the repository has:

* a multi-format conversion mainflow with documented support boundaries
* a stable metadata-sidecar contract for current G2 / G3 scope
* a documented degradation model instead of ad hoc fallback behavior
* an internal benchmark harness with baseline recording

This is enough to treat the current stage as a coherent, documented milestone,
while still keeping the deferred items explicit for future work.
