# Performance Roadmap

This page turns the current benchmark baseline into a concrete optimization
plan for `doc_parse/*` and the surrounding converter stack.

## Budget By Format Group

### Lightweight text and structured formats

Formats:

* TXT
* Markdown scanner
* CSV
* TSV
* JSON
* YAML
* XML
* HTML

Budget:

* small library path target: `<10ms` where realistic on a same-machine native
  build
* CLI timing tracked separately because startup and file I/O can dominate

### Package / container formats

Formats:

* ZIP
* EPUB

Budget:

* small package inspect/open target: roughly `<10-20ms` when native runner and
  local I/O are favorable
* archive size, compression mix, and part inventory can move the result

### OOXML semantic formats

Formats:

* XLSX
* DOCX
* PPTX

Budget:

* establish baseline first
* optimize small native cases toward roughly `<10-30ms` only where realistic
* treat relationship/media scans, XML parsing, and converter policy as
  separate possible hotspots

### Native text-PDF

Formats:

* PDF native text path

Budget:

* separate budget from lightweight formats
* never mix OCR/scanned-PDF expectations into the native text-PDF target

## Current Hotspot Tracking

This round is baseline-first, so hotspot ownership is still provisional.

Track each hotspot by:

* format
* sample
* current measured timing
* suspected bottleneck
* owner layer: `doc_parse` / `convert` / emitter / metadata-assets / CLI
* next action

## Current Initial Hotspot List

Initial priorities after this round's baseline:

* Office semantic rows:
  verify whether cost is dominated by OOXML open/part read, semantic parsing,
  or converter lowering
* PDF rows:
  keep native text extraction separate from CLI and emitter overhead
* asset-heavy HTML / EPUB / ZIP rows:
  distinguish parsing cost from asset/output materialization cost
* lightweight small rows above the small-case target:
  confirm whether startup cost, converter policy, or lower-layer parsing is
  dominant before optimizing

## Optimization Stages

### P1: Measurement and obvious allocation fixes

Focus:

* better baseline reporting
* same-part repeated-read audit
* obvious string-concatenation or repeated-scan cleanup
* no behavior changes and no safety-boundary weakening

### P2: Parser / emitter hot path optimization

Focus:

* format-local parser hotspots
* repeated relationship lookup or XML walk reductions
* lower allocation churn in clearly bounded loops
* keep validation and safety behavior intact

### P3: Regression guard and comparison refinement

Focus:

* lightweight perf regression guard for checked-in rows
* clearer format-group summaries
* better library-vs-CLI interpretation
* comparison and loss analysis where mainstream tools are relevant

## Release Rule

Do not accept a performance win that:

* changes checked conversion output
* removes validation or classifier signal
* weakens unsafe-path / XXE / script / external-fetch boundaries
* introduces opaque global caches without a clearly documented safety story
