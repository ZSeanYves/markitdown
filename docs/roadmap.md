# Roadmap

This page is the current roadmap source of truth for the repository.

## Current Status

* `doc_parse` foundation in-tree complete
* container/package foundations:
  `zip / ooxml / epub / pdf`
* simple/markup/scanner foundations:
  `csv / tsv / json / yaml / text / xml / html / markdown`
* OOXML semantic sublayers:
  `xlsx / docx / pptx`
* performance:
  library and same-process product first-pass corpus have no obvious `>10ms`
  rows, and cold-start attribution now shows main-internal CLI work is
  sub-millisecond while process/runtime cost dominates the remaining
  process-per-file path
* benchmark:
  unified entrypoint through `./samples/bench.sh`, including the focused
  cold-start CLI suite with external vs main-internal startup attribution

## Near-term Release Work

### 1. API stability review

* stable candidate APIs
* benchmark/profile helpers are not stable product APIs
* compatibility surfaces
* package README final check

### 2. `doc_parse` independent module extraction readiness audit

* import graph
* `moon.mod.json` strategy
* package boundaries
* version / changelog / release policy
* `markitdown` integration plan

### 3. Documentation release polish

* `README`
* package README
* examples
* support/limits
* performance caveats

### 4. Performance follow-ups

* PDF direct library attribution
* batch / embedded / warm-runner startup amortization guidance
* release packaging or runtime-level cold-start follow-up if process-per-file
  usage remains a priority
* heavier rich-format corpora
* optional regression guard
* no longer prioritize source-level cold CLI micro-optimization for the
  current checked `noop`/`--help`/minimal-TXT path

### 5. PDF layout classifier follow-up

* keep the current `samples/pdf_layout_classifier` work scoped as a training
  spike
* expand local labels only if the text-layer classifier shows useful signal
* keep plugin/backend/OCR/visual-model integration optional and outside the
  default fast main path

### 6. External/private quality intake

* keep `samples/quality_corpus/` as an external/public-dataset/private-local
  intake framework rather than repopulating it with repository regression
  samples
* keep the checked public manifest intentionally empty until rows are manually
  curated
* treat private local real documents as the first-class intake path
* require license review before vendoring any external dataset or tool fixture
* legacy synthetic `samples/real_world` has been removed and is no longer
  current release quality evidence

## Later Work

* optional split into standalone `ZSeanYves/doc_parse`
* remote dependency integration back into `markitdown`
* richer PDF fallback/OCR line
* deeper DOCX/PPTX normal-path integration if justified
* manually curated external/private quality corpus growth
* fuzz / malformed corpus
* more ecosystem adapters

## Non-goals For Current Release

* full Office engine
* full PDF engine
* scanned/OCR PDF default support
* full browser HTML engine
* full CommonMark renderer
* full ICU/UAX #15 canonical normalization
* replacing Pandoc/Tika
* claiming cross-machine absolute benchmark guarantees

## Historical Records

Historical planning, audit, and milestone notes remain available at their
existing paths as archived stubs, with full historical bodies preserved under
`docs/archive/`:

* [Archived roadmap docs](./archive/roadmap/)
* [Archived benchmark docs](./archive/benchmark/)
* [Archived normalization docs](./archive/normalization/)
