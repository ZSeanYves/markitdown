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
  rows
* benchmark:
  unified entrypoint through `./samples/bench.sh`

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
* startup / batch amortization
* heavier rich-format corpora
* optional regression guard

## Later Work

* optional split into standalone `ZSeanYves/doc_parse`
* remote dependency integration back into `markitdown`
* richer PDF fallback/OCR line
* deeper DOCX/PPTX normal-path integration if justified
* broader real-world corpus
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
