# doc_parse

`doc_parse/*` is the reusable lower-layer parsing foundation inside
`ZSeanYves/markitdown`.

These packages expose parser/model/error/inspect/validation/safety surfaces that
the product-path `convert/*` packages build on for final IR, Markdown, assets,
and metadata output.

Release-facing contract and packaging notes live in:

* [doc_parse Foundation](../docs/doc-parse-foundation.md)
* [doc_parse Package Strategy](../docs/package-publishing-strategy.md)

## What It Is

`doc_parse/*` gives you lower-layer parser/model/inspect/validation surfaces
without forcing you through the full product conversion path.

Typical direct uses include:

* document inspection and validation tooling
* ZIP / OOXML / EPUB inventory tools
* XLSX workbook and cell analyzers
* DOCX paragraph / table / link / image extractors
* PPTX slide / shape / media inventories
* HTML / XML safety scanners
* Markdown frontmatter or fence scanners
* custom converters into a private IR
* chunking or indexing preprocessors for RAG pipelines

## Ownership Split

Current boundary:

* `doc_parse/*` owns parsing, source-native model, inspect, validation,
  provenance where available, and safety boundary
* `convert/*` owns IR, Markdown, assets, metadata, and final product output
  policy

## API Stability Levels

Use package READMEs with four release-surface buckets in mind:

* Stable candidate API:
  intended public facade for normal use, usually `open_*`, `parse_*`,
  `scan_*`, `read_*`, `list_*`, `inspect_*`, `validate_*`, and
  `classify_*` entrypoints
* Compatibility surface:
  public today because `markitdown`, `convert/*`, and lower-layer tests still
  depend on public model fields, raw structs, or legacy helper-shaped entry
  points; these may narrow in a future standalone-module release
* Diagnostic / profile helpers:
  benchmark, profiling, dump, and troubleshooting helpers such as
  `profile_*`, textual debug dumps, and `doc_parse/bench`; these are useful,
  but they are not the primary stable semantic API
* Internal exposed surface:
  visible today because of package structure or current in-repo layering, but
  not recommended as an external dependency line for new consumers

Package READMEs call out format-specific exceptions and helper surfaces where
needed.

## What It Is Not

`doc_parse/*` is not:

* a Markdown renderer
* an Office, PDF, or browser engine
* an OCR system
* the owner of final output policy
* a blanket full-spec claim for every format family

## Package Map

### Container And Package Foundations

* [doc_parse/zip](./zip/README.md)
  external-decoder-backed ZIP foundation candidate for archive structure,
  inventory, validation, and inspect
* [doc_parse/ooxml](./ooxml/README.md)
  OOXML package foundation candidate for parts, relationships, content types,
  media, docProps, inspect, and strict validation
* [doc_parse/epub](./epub/README.md)
  EPUB package/spine/nav foundation candidate for container, OPF, manifest,
  spine, nav/NCX, cover, metadata, inspect, and validation
* [doc_parse/pdf](./pdf/README.md)
  native text-PDF foundation candidate for page/text/image/annotation lower
  layers, structured inspect, typed issues, and classifier-friendly errors

### Simple-Format, Markup, And Scanner Foundations

* [doc_parse/csv](./csv/README.md)
  CSV parser foundation candidate for delimited table model, inspect, and
  ragged-row validation
* [doc_parse/tsv](./tsv/README.md)
  TSV parser foundation candidate as the tab-delimited facade over the CSV core
* [doc_parse/json](./json/README.md)
  JSON parser foundation candidate for AST, inspect, and malformed-input
  classification
* [doc_parse/yaml](./yaml/README.md)
  YAML-subset parser foundation candidate for subset AST, inspect, and
  fail-closed unsupported-feature boundaries
* [doc_parse/text](./text/README.md)
  plain-text parser foundation candidate for bytes/string open, BOM/newline
  handling, structural model, and inspect
* [doc_parse/xml](./xml/README.md)
  XML parser foundation candidate for safe tokenizer/parser/model/inspect/
  validation with explicit no-XXE and no-DTD-expansion boundary
* [doc_parse/html](./html/README.md)
  HTML DOM-ish parser foundation candidate for tolerant tokenizer/parser/raw
  node inventory/inspect/validation with explicit no-fetch and
  no-script-execution boundaries
* [doc_parse/markdown](./markdown/README.md)
  Markdown lightweight scanner foundation candidate for raw block inventory,
  frontmatter detection, fenced code detection, and inspect/validation

### OOXML Semantic Sublayers

* [doc_parse/xlsx](./xlsx/README.md)
  XLSX semantic foundation candidate for workbook/sheet/cell/shared
  strings/styles/merged ranges/formula trace inspect and validation
* [doc_parse/docx](./docx/README.md)
  DOCX semantic foundation candidate for source-native body/inline/table
  relationships, styles, numbering, notes, and media refs
* [doc_parse/pptx](./pptx/README.md)
  PPTX semantic foundation candidate for source-native slide order, raw shape
  tree, text paragraphs/runs, explicit tables, notes, media refs, and
  hyperlink refs

## Integration Status

Current delivery model:

* these packages are delivered today as importable in-tree subpackages under
  `ZSeanYves/markitdown`
* standalone `ZSeanYves/doc_parse` extraction remains later release work
* integrated normal paths today:
  `csv` / `tsv` / `json` / `yaml` / `text` / `xlsx`
* intentionally not switched as the normal converter path:
  `xml` / `html` / `markdown` / `docx` / `pptx`
* `convert/*` still owns final Markdown, assets, metadata, heading/list/table/
  caption/layout heuristics, and compatibility behavior

## Local Docs And Tooling

Package-specific READMEs live next to each package directory.

Related repository entrypoints:

* [doc_parse examples](./examples/README.md)
* `doc_parse/bench`
  implementation package for the direct library benchmark harness
* `../samples/bench.sh --suite doc-parse --kind library`
  recommended public benchmark entrypoint
* `../samples/helpers/bench_doc_parse_helper.sh`
  internal focused rerun helper behind the public benchmark entrypoint
* `../samples/benchmark/manifests/doc_parse.tsv`
  checked manifest for the library benchmark corpus
* [docs/performance.md](../docs/performance.md)
  current performance interpretation and baseline
* [docs/benchmarking.md](../docs/benchmarking.md)
  benchmark commands, helper status, and output layout
