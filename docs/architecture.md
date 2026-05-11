# Architecture Overview

This document describes the current repository architecture. It intentionally
focuses on the active design, not the full historical path used to reach it.

## Pipeline

The current project follows this layered flow:

**CLI -> dispatcher -> format converters / parsers -> unified IR -> Markdown / assets / metadata**

The key idea is to keep parsing, recovery, representation, and output concerns
separate enough that behavior stays explainable and regression-verifiable.

## Main Layers

### CLI

`cli/` is responsible for:

* subcommand parsing
* output path coordination
* explicit `--with-metadata` sidecar gating
* debug/ocr mode selection
* batch-v1 per-document output-root coordination

It does not implement format-specific parsing or recovery.

Current CLI contract:

* `normal` default emits Markdown plus necessary assets only
* `normal --with-metadata` additionally emits
  `<markdown_dir>/metadata/<stem>.metadata.json`
* stdout mode is Markdown-only and should not create sidecar or `out/`
  directories
* `batch` is non-recursive, serial v1, and writes one isolated document root
  per top-level input file plus `batch-summary.tsv`
* `debug <input>` is the unified multi-format inspect path and emits a
  developer-facing report instead of Markdown output
* `debug --json` is the stable scriptable form; human-readable report text is
  the default interactive form
* legacy `debug <all|extract|raw|pipeline> <input> [output]` is a deprecated
  PDF alias over the unified inspect surface; Markdown materialization only
  happens when `[output]` is explicitly provided

### Dispatcher

`convert/convert/dispatcher.mbt` is responsible for extension-based routing.

It currently routes:

* `docx`
* `pptx`
* `xlsx`
* `pdf`
* `html` / `htm`
* `csv` / `tsv`
* `json`
* `yaml` / `yml`
* `md` / `markdown`
* `txt`
* `xml`
* `zip`
* `epub`

It only chooses the converter; it does not own recovery strategy.

### Low-level parsing infrastructure

`doc_parse/*` provides reusable foundations:

* `doc_parse/zip`: ZIP reader and container primitives
* `doc_parse/ooxml`: OOXML package / relationships / media / docProps helpers
* `doc_parse/epub`: EPUB package parsing for `container.xml`, OPF, manifest,
  and spine
* `doc_parse/pdf`: native PDF substrate and inspect/debug-facing raw data
* `doc_parse/csv` / `doc_parse/tsv`: delimited table parser/model/inspect
* `doc_parse/json`: JSON parser / AST / inspect
* `doc_parse/yaml`: current YAML-subset parser / AST / inspect
* `doc_parse/text`: plain-text structural document model / inspect
* `doc_parse/xml`: XML tokenizer / parser / inspect / validation foundation
* `doc_parse/html`: tolerant HTML tokenizer / parser / inspect / validation
  foundation candidate
* `doc_parse/markdown`: Markdown lightweight scanner candidate for inspect /
  validation
* `doc_parse/xlsx`: SpreadsheetML semantic workbook / sheet / cell foundation
* `doc_parse/docx`: WordprocessingML semantic body / inline / table /
  relationship foundation
* `doc_parse/pptx`: PresentationML semantic presentation / slide / shape /
  text / table / notes / media foundation

These packages are infrastructure, not final Markdown semantics.

Current candidate line:

* `doc_parse/ooxml`: OOXML package foundation candidate
* `doc_parse/epub`: EPUB package/spine/nav foundation candidate
* `doc_parse/pdf`: native text-PDF foundation candidate
* `doc_parse/zip`: external-decoder-backed ZIP foundation candidate as
  the shared container primitive
* `doc_parse/csv`: simple-format parser foundation candidate
* `doc_parse/tsv`: simple-format parser foundation candidate
* `doc_parse/json`: simple-format parser foundation candidate
* `doc_parse/yaml`: YAML-subset parser foundation candidate
* `doc_parse/text`: plain-text parser foundation candidate
* `doc_parse/xml`: XML parser foundation candidate
* `doc_parse/html`: HTML DOM-ish parser foundation candidate
* `doc_parse/markdown`: lightweight Markdown scanner foundation candidate
* `doc_parse/xlsx`: XLSX semantic foundation candidate
* `doc_parse/docx`: DOCX semantic foundation candidate
* `doc_parse/pptx`: PPTX semantic foundation candidate

Current module strategy keeps these as importable subpackages under
`ZSeanYves/markitdown` rather than as independently split MoonBit modules.

Current foundation contract for reusable lower layers is documented in
[docs/doc-parse-foundation.md](./doc-parse-foundation.md).

### Format converters

`convert/*` maps source formats into unified IR and handles conservative
degradation.

The convert layer is now intentionally narrow at its public boundary:

* stable package-facing entrypoints are the format `parse_*` functions and the
  small set of inspect/profile APIs consumed by dispatcher, CLI, and unified
  debug inspect
* internal helpers such as classifiers, per-format normalization helpers,
  relationship walkers, table heuristics, and parser internals are not treated
  as stable external APIs
* repository integration should prefer the dispatcher and CLI surfaces unless a
  format-specific parse/inspect contract is explicitly required

Current format families:

* OOXML:
  * `convert/docx`
  * `convert/pptx`
  * `convert/xlsx`
* PDF:
  * `convert/pdf`
* HTML:
  * `convert/html`
* Structured data:
  * `convert/csv` for CSV / TSV
  * `convert/json`
  * `convert/yaml`
  * `convert/xml`
* Text-like:
  * `convert/markdown`
  * `convert/txt`
* Container:
  * `convert/zip`
* Ebook:
  * `convert/epub`

Current lower-layer integration split:

Integrated normal paths:

* `convert/csv` consumes `doc_parse/csv` / `doc_parse/tsv` and still owns
  `RichTable` / IR / Markdown policy
* `convert/json` and `convert/yaml` consume parser/model layers from
  `doc_parse/json` and `doc_parse/yaml` and still own table/list/code-block
  lowering policy
* `convert/txt` consumes `doc_parse/text` and still owns literal-Markdown /
  `Document` product policy
* `convert/xlsx` now consumes `doc_parse/xlsx` for SpreadsheetML semantic
  parsing while still owning sheet heading output, RichTable hints, IR
  lowering, Markdown table policy, and product wording

Not switched intentionally:

* `convert/xml` still owns the current source-preserving fenced-output normal
  path; the XML parser foundation is not the normal converter path yet
* `convert/html` still owns heading/list/table/link/image/assets/caption/
  nearby-text product policy; the HTML DOM-ish parser foundation is not the
  normal converter path yet
* `convert/markdown` still owns passthrough/product policy; the Markdown
  scanner foundation is not the normal converter path yet
* `convert/docx` still owns the current normal conversion path, final
  heading/list/table/caption/code/image policy, and the normal DOCX
  converter path is not switched even though `doc_parse/docx` now provides a
  WordprocessingML source-native semantic package
* `convert/pptx` still owns the current normal conversion path,
  reading-order/layout/grouping/caption/image policy, Speaker Notes final
  product policy, and the normal PPTX converter path is not switched even
  though `doc_parse/pptx` now provides a PresentationML source-native
  semantic package

### Unified IR

`core/ir.mbt` provides the shared representation:

* `Document`
* `Block`
* `Inline`
* `ImageData`
* `block_origins`
* `asset_origins`
* optional `passthrough_markdown`

This layer is what makes cross-format Markdown, metadata, and asset behavior
consistent enough to test as one tool rather than a pile of unrelated parsers.

### Output layers

`core/emitter_markdown.mbt` handles Markdown emission.

`core/metadata.mbt` handles sidecar emission.

Asset export is driven by converters plus CLI output-directory coordination.

## Format-family View

### OOXML

DOCX / PPTX / XLSX share:

* ZIP package handling
* relationships
* media indexing
* document properties

This is why OOXML support is not implemented as three fully isolated parsers.

`doc_parse/ooxml` is intended to keep evolving as a reusable package parser for
parts/relationships/media/docProps, not as a DOCX/PPTX/XLSX semantic
converter.

### PDF

PDF has its own native substrate:

* page geometry
* document / page / text / image / annotation models
* text structures
* raw image extraction
* annotation/link data
* inspect/debug surfaces

The default mainflow uses conservative structural recovery rather than OCR-first
or visual-page reconstruction.

Converter responsibility is intentionally separated:

* `doc_parse/pdf` owns extraction, page/text/image/annotation signal, and
  debug-facing raw/model surfaces
* `doc_parse/pdf` also exposes a structured inspect/report view plus
  classifier-friendly errors for package-level audit use
* the recommended package-facing candidate facade is `doc_parse/pdf/api`
* `convert/pdf` consumes those lower-layer signals for conservative heading,
  noise, merge, table, caption, and link decisions
* `core/text_normalization.mbt` provides the shared text-normalization facade
  and rule pipeline used by the PDF path for deterministic pure-string cleanup
  before higher-level heuristics run

Current text-normalization layering is also intentional:

* shared substrate is profile-driven rather than globally aggressive:
  `Literal`, `GeneralText`, `PdfText`, `PdfCompareText`, `HtmlText`,
  `OoxmlText`, and `StructuredDataText`
* shared substrate is stage-organized but rule-driven internally:
  line-ending, canonical-unicode policy, compatibility glyph, whitespace,
  invisible-char, soft-hyphen, PDF glyph fallback, and PDF compare cleanup
  are each decomposed into explicit cleanup rules with ids, scopes, ordering,
  and rule-level summary reporting
* `PdfText` is the output-facing extracted-text profile
* `PdfCompareText` is a stronger comparison-only profile used by PDF heading,
  noise, table, caption, and merge heuristics
* the current project does not claim ICU-level or full UAX #15 Unicode
  normalization; canonical `NFD/NFC/NFKD/NFKC` are explicit facade APIs backed
  by `tonyfettes/unicode`, but they are still opt-in and are not default
  converter behavior
* shared low-risk rules include line-ending normalization, NBSP/unicode-space
  cleanup, selected zero-width removal, soft-hyphen stripping, common
  ligature expansion, PDF compatibility-glyph fallback, and profile-gated
  PDF output-safe spacing repair such as CJK spacing, punctuation spacing,
  and marker spacing
* shared document-text cleanup is already reused by PDF, TXT, HTML, DOCX, and
  PPTX, while full conformance validation remains a future opt-in step
* future Unicode conformance validation should stay manual/user-provided first:
  no bundled `NormalizationTest.txt`, no automatic Unicode-data download, and
  no default-gate canonical-normalization runner
* PDF keeps layout-aware repair such as word-fragment recovery, line-wrap
  hyphen repair, noise filtering, heading/table/caption decisions, and other
  geometry/source-ref heuristics in `doc_parse/pdf`
* PDF-local span/line/model glue now prefers context signals such as source-ref
  adjacency, font/font-size consistency, gap/baseline proximity, punctuation
  boundaries, and casing signals over pure short-word fallback guesses
* literal/source-preserving paths such as Markdown passthrough, XML fenced
  output, JSON/YAML fallback code fences, and TXT literal-safe lowering do not
  opt into aggressive text normalization policies

This split is the stable architecture outcome from the earlier PDF H2 process;
historical PDF phase docs remain useful for audit traceability, but they are
no longer the source of truth for the active design.

### HTML

HTML is still a lightweight semantic converter in the normal product path:

* structural tags map into IR
* inline links and local images are preserved within current limits
* browser/CSS/JS semantics are intentionally out of scope
* `doc_parse/html` now provides a lower-layer tokenizer/parser/model/inspect/
  validation candidate surface, but `convert/html` still owns the normal HTML
  -> IR / Markdown / asset/product policy path

### Markdown

Markdown is intentionally a source-scanner lower layer, not a renderer:

* `doc_parse/markdown` now provides a lightweight source scanner / raw block
  inventory / frontmatter / fenced-code candidate surface
* `convert/markdown` still owns passthrough output and final product policy
* HTML-in-Markdown remains a raw source candidate only and is not parsed as
  HTML by the scanner

### Text-like

TXT and Markdown are intentionally different:

* TXT is conservative paragraph conversion
* Markdown is source-preserving passthrough

### Structured data

CSV / TSV / JSON / YAML / XML are not treated as one semantic family, but they
share a “conservative and stable” philosophy:

* `doc_parse/csv` / `doc_parse/tsv` now own delimited parsing while
  `convert/csv` still owns `RichTable` / IR semantics
* `doc_parse/json` now owns JSON parsing / AST while `convert/json` still owns
  table/list/code-block lowering; source normalization now also lives in the
  parser layer
* `doc_parse/yaml` now owns current YAML-subset parsing / AST while
  `convert/yaml` still owns conservative table/list/code-block lowering
* `doc_parse/text` now owns UTF-8/open-newline/paragraph structure while
  `convert/txt` still owns cleanup-profile choice and literal-Markdown policy
* `doc_parse/xml` now owns a safe XML tokenizer/parser/model/inspect/
  validation foundation
  while `convert/xml` still keeps the normal source-preserving fenced code-block
  output path

### Container

ZIP is not just “unzip and concatenate”.

It adds:

* safe path normalization
* supported-entry dispatch
* archive warning fallback
* archive asset namespace/remap
* safe extracted-tree handling for ZIP HTML local images

### Ebook

EPUB is not treated as generic ZIP traversal.

It adds:

* `container.xml` lookup
* OPF rootfile handling
* manifest/spine parsing
* spine-order aggregation
* safe same-archive local-image handling for XHTML/HTML spine documents

`doc_parse/epub` is intended to stay at the package/container/OPF/spine/nav
layer rather than turning into a reading-system renderer or final Markdown
aggregator.

## Metadata And Assets

The repository treats Markdown main output and engineering sidecar output as
different layers:

* Markdown is for reading
* metadata is for provenance / indexing / auditing
* assets are for materialized exported resources

Current provenance is intentionally lightweight:

* block-level origin
* asset-level origin
* additive sparse fields

It is not a full layout trace or DOM/object anchoring model.

## Debug / Regression / Benchmark

The repository includes explicit non-production support layers:

* debug pipeline for PDF
* regression inputs under `samples/main_process` with checked expectations
  under `samples/expected`
* lower-layer parser/core fixtures under `samples/fixtures`
* internal smoke benchmark
* overlap-only comparison benchmark

These are part of the architecture in practice because they enforce contract
stability and provide explainability beyond “the converter happened to run”.
