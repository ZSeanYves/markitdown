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

This page now tracks two benchmark families:

* repository-level CLI/product-path rows
* direct `doc_parse/*` library rows from `./samples/bench_doc_parse.sh`

Track each hotspot by:

* format
* sample
* current measured timing
* suspected bottleneck
* owner layer: `doc_parse` / `convert` / emitter / metadata-assets / CLI
* next action

## doc_parse Library Hotspot Attribution

Current highest-priority library rows:

* `doc_parse/xlsx`
  `xlsx_formula_heavy_missing_cache / parse / 14.367 ms`
  suspected owner: SpreadsheetML semantic parse plus conservative
  formula-evaluation trace on missing cached values
  next action: isolate workbook open vs sheet parse vs formula trace cost

* `doc_parse/docx`
  `docx_link_heavy / parse / 8.631 ms`
  suspected owner: WordprocessingML body/inline scan plus hyperlink
  relationship resolution
  next action: profile repeated XML walk and hyperlink/media lookup density

* `doc_parse/yaml`
  `yaml_large / parse / 7.181 ms`
  suspected owner: YAML-subset parser scan and tree allocation on large mapping
  input
  next action: allocation-focused parser profile before any semantic change

* `doc_parse/text`
  `txt_large / parse / 3.769 ms`
  suspected owner: newline normalization and line inventory construction
  next action: check repeated passes over large text buffers

* `doc_parse/json`
  `json_large / parse / 3.857 ms`
  suspected owner: JSON tokenizer plus value-tree allocation
  next action: inspect allocation churn in object/array recursion

* `doc_parse/markdown`
  `markdown_large / scan / 3.306 ms`
  suspected owner: line scanner and raw block inventory traversal
  next action: confirm whether fence/frontmatter/block classification performs
  duplicate scans

Lower-priority library observations:

* `inspect` and `validate` rows are mostly sub-`1 ms`
* `zip`, `ooxml`, and `epub` `open` rows are currently sub-`1 ms` on the
  checked small/large manifest files
* the current library baseline suggests the main optimization headroom is in
  parse/scan stages, not in inspect/validate traversal

## CLI/Product-Path Interpretation

Current CLI smoke and batch-profile numbers still matter because they include:

* startup
* file I/O
* converter lowering
* Markdown / metadata / assets work

That means:

* rows above `10 ms` in CLI smoke are not automatically `doc_parse` problems
* the library harness is the better owner-attribution tool for parser work
* PDF and output-heavy HTML/EPUB/ZIP rows still need repo-level measurement in
  addition to package-local timing

## Optimization Stages

### P1: Measurement and obvious allocation fixes

Focus:

* better baseline reporting
* keep library and CLI harnesses side by side
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
