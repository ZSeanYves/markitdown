# Second-Round Hardening Audit

Status: historical audit record.

For the current documentation map and current support/performance contracts,
use:

* [docs/README.md](../../README.md)
* [docs/support-and-limits.md](../../support-and-limits.md)
* [docs/benchmarking.md](../../benchmarking.md)

This document is the repository's second-round hardening audit for
`markitdown-mb`.

Scope of this round:

* audit current support and limits with code/sample evidence
* document support matrices, boundaries, and missing lower-layer capabilities
* record benchmark and quality-comparison workflow outcomes for the repository
* produce an executable task queue

Non-goal of this round:

* no broad converter-semantic rewrite
* no "support inflation" that treats partial behavior as complete support
* no ungrounded speed claims beyond the repository's existing benchmark docs

Primary local evidence used:

* [README.mbt.md](./../README.mbt.md)
* [docs/support-and-limits.md](../../support-and-limits.md)
* [docs/architecture.md](../../architecture.md)
* [docs/archive/roadmap/progress.md](../roadmap/progress.md)
* [core/ir.mbt](../core/ir.mbt)
* [core/emitter_markdown.mbt](../core/emitter_markdown.mbt)
* [core/metadata.mbt](../core/metadata.mbt)
* [cli/main.mbt](../cli/main.mbt)
* [cli/cli_app.mbt](../cli/cli_app.mbt)
* [convert/convert/dispatcher.mbt](../convert/convert/dispatcher.mbt)
* `convert/*`, `doc_parse/*`, `samples/*`, and benchmark scripts

External reference scope:

* Microsoft MarkItDown repository: <https://github.com/microsoft/markitdown>
* MoonBit docs for package structure and `moon` commands: <https://docs.moonbitlang.com/>

Current checked validation totals and representative benchmark rows are tracked
separately in
[docs/archive/performance/validation-and-benchmark-summary.md](../performance/validation-and-benchmark-summary.md).

## 1. Executive Summary

`markitdown-mb` already has a real multi-format pipeline:

* `CLI -> dispatcher -> format parser/converter -> unified IR -> Markdown / assets / metadata`
* supported dispatch families are DOCX, PPTX, XLSX, PDF, HTML/HTM, CSV, TSV,
  JSON, YAML/YML, Markdown, TXT, XML, ZIP, and EPUB
* batch v1 exists and is a real product entrypoint, not just a benchmark loop

The main second-round finding is not "missing formats everywhere". It is that
the repository now needs a stricter distinction between:

* format availability
* stable support range
* conservative degradation policy
* lower-layer parser/core capability debt
* quality parity evidence
* performance evidence

The strongest current architectural assets are:

* unified IR with shared Markdown emitter and metadata sidecar
* reusable lower layers for OOXML, ZIP, PDF, and EPUB
* explicit regression sample families for main output, metadata, and assets
* native-preferred benchmark harnesses and batch profiling scripts

The largest hardening gaps are:

* support claims in top-level docs are stronger than current evidence in some
  places
* metadata validation needed a stricter sidecar contract and broader fixture
  coverage
* product-path CLI contract needed an explicit repository-level audit, because
  metadata gating, stdout side effects, and runner selection can drift even
  when format regressions stay green
* several formats still rely on coarse provenance rather than richer origin
  models needed for RAG/citation workflows
* some important limits remain converter-local when they really point to
  parser/core substrate gaps
* benchmark coverage is broad but not yet disciplined enough for a format-by-
  format "speed lead" narrative

The next round should therefore prioritize:

* P0 contract cleanup and benchmark/quality governance
* P1 hardening of textlike and structured-data foundations
* P1-P2 lower-layer work for HTML/XLSX/ZIP/EPUB and OOXML quality parity
* P2 PDF signal-model improvements before any aggressive output heuristics

### XLSX Sprint Update

The XLSX second-round sprint has now moved past cached-value-only formula
policy:

* cached values remain the default visible result when present
* missing-cache formulas now have a lightweight evaluator v1 for a bounded
  same-sheet subset
* unsupported, volatile, cross-sheet, and broader Excel-engine cases still
  degrade conservatively rather than inventing values
* metadata sidecar `formula_cells` now records formula policy, evaluated
  values, and unsupported/error reasons where available
* checked-in quality records now cover cached policy, arithmetic evaluation,
  range aggregates, unsupported boundaries, merged cells, typed cells, and
  multi-sheet output
* checked-in benchmark corpus now includes formula-eval arithmetic/range,
  formula-heavy missing-cache, and unsupported-formula stress rows

### Status Update After P0.1 / P0.2 Follow-up

This follow-up pass fixed the two highest-priority project-level guardrails
without changing converter/parser/emitter semantics:

* `samples/check.sh --metadata-only` now explicitly runs `normal --with-metadata`
  against the metadata sample corpus
* metadata validation now checks the on-disk sidecar path contract
  `<markdown_dir>/metadata/<stem>.metadata.json`, parses JSON, validates core
  top-level fields, verifies summary counts, checks asset/file correspondence,
  and requires `document` metadata for OOXML and EPUB sidecars
* CLI exact sidecar fixtures now live alongside each format package under
  `samples/main_process/<format>/expected`, while lower-layer MoonBit metadata
  snapshots remain under `samples/fixtures/metadata`
* samples with JSON sidecar fixtures now get semantic fixture comparison; other
  metadata samples get structure-level sidecar validation without freezing
  every optional field
* metadata outputs are now generated under isolated per-sample output roots, so
  asset numbering and sidecar paths are stable per sample
* top-level docs now use tighter support/status vocabulary:
  `H2 main-path quality`, `H2 partial`, `subset-H2`,
  `source-preserving H1/H2 partial`, and second-round sealed `H2++ / H3++`
  formats
* README/progress speed wording was tightened so native CLI, `moon run`,
  OCR/cloud, and overlap-only comparison cases are not blended into one claim

Remaining archival notes from the original hardening pass:

* expand semantic metadata fixture coverage for samples that currently only get
  structure-level sidecar validation
* keep older milestone documents from being read as user-facing claims of final
  completeness
* continue distinguishing parser/core substrate debt from converter-level TODOs

## 2. Task 1: Current Capability Map

### 2.1 Product Entry Capability

Current product entrypoints are defined in [cli/main.mbt](../cli/main.mbt) and orchestrated in [cli/cli_app.mbt](../cli/cli_app.mbt).

Current subcommands:

* `normal [--with-metadata] <input> [output]`
* `ocr [--with-metadata] <input> [output]`
* `batch [--with-metadata] <input_dir> <output_dir>`
* `debug [--with-metadata] <all|extract|raw|pipeline> <input> [output]`

Current supported input formats from the dispatcher:

* DOCX
* PPTX
* XLSX
* PDF
* HTML / HTM
* CSV
* TSV
* JSON
* YAML / YML
* Markdown / MD / MARKDOWN
* TXT
* XML
* ZIP
* EPUB

Current capability findings:

| Area | Current capability | Evidence | Gap / note |
| --- | --- | --- | --- |
| Single-file conversion | Stable main path through `normal` | `cmd_convert -> convert_once -> parse_to_ir -> emit_markdown` | Stability depends on format-specific lower layer quality |
| Batch conversion | Implemented as Batch v1 | `run_batch` in `cli/cli_app.mbt`, `cli/batch_wbtest.mbt` | Non-recursive, serial only |
| OCR path | Explicit separate PDF path | `ocr` subcommand and `convert/pdf/ocr` | Should not be mixed into default performance claims |
| Debug inspect | Explicit PDF-focused modes | `debug` subcommand and `pipeline_debug` behavior | Debug surface is not yet a uniform cross-format contract |
| Assets output | Generally unified under `assets/` | CLI output-root convention plus format-specific exporters | ZIP/EPUB use namespaced remap; some formats emit no assets |
| Metadata sidecar | Unified output path contract | `metadata_output_path()` and `emit_metadata_json_with_document_properties()` | Core contract is now validated; fixture coverage is still uneven across formats |
| Document properties | Unified only for OOXML + EPUB | `read_document_properties()` | No file-level docprops model for PDF/HTML/ZIP/etc. |
| Stdout behavior | Markdown only | `convert_once` stdout branch | Sidecar/assets cannot be emitted in stdout mode |
| Error handling | Mixed fail-closed and warning-block downgrade | format parsers + batch summary | Needs more explicit product-level taxonomy |
| Output path boundary | Resolved centrally | `resolve_output_path`, `looks_like_output_dir` | Non-`.md` existing path is always treated as directory-like |

Single-file conversion path assessment:

* stable enough as a product skeleton
* consistent dispatcher-based routing
* stable Markdown emission and sidecar writing path
* per-format semantics still vary in how much structure reaches IR

Batch path assessment:

* exists and is tested
* non-recursive top-level directory scan only
* serial only in v1
* isolated document roots avoid same-stem collisions inside one batch
* summary output is `batch-summary.tsv`
* no parallelism, manifest mode, recursion, or batch-level quality metrics yet

Assets behavior assessment:

* current top-level convention is `assets/` beside Markdown output
* DOCX/PPTX/HTML/PDF emit directly under per-document output roots
* ZIP/EPUB remap nested assets under archive namespaces such as
  `assets/archive/...`
* batch v1 keeps assets isolated per document root
* no project-wide asset manifest beyond metadata sidecar `assets[]`

Metadata sidecar assessment:

* output path contract is clear: `<markdown_dir>/metadata/<stem>.metadata.json`
* emitted only when `--with-metadata` is set and output is on disk
* unavailable in stdout mode by design
* supports block and asset views
* `samples/check.sh --metadata-only` now validates sidecar existence, JSON structure,
  summary counts, asset correspondence, and semantic fixture equality where
  fixtures exist
* repository-level CLI contract checks should also verify the negative path:
  no sidecar without `--with-metadata`

Debug inspect assessment:

* current explicit debug surface is mostly PDF-specific
* PDF has `extract`, `raw`, and `pipeline` debug modes
* ZIP and EPUB have inspect surfaces, but not integrated into CLI subcommands
* XLSX has inspect APIs, but not a product CLI inspect mode

Error handling and degradation assessment:

* unsupported top-level input types fail closed at dispatcher level
* malformed CSV/JSON/YAML/XML/TXT invalid UTF-8 generally fail closed
* ZIP/EPUB downgrade unsupported internal entries to warning blocks when safe
* PDF uses conservative omission for ambiguous links/tables/captions
* OOXML often uses conservative append sections for notes/text boxes instead of
  speculative reconstruction
* product-level error taxonomy is still implicit rather than normalized

`stdout` / `output dir` / `assets dir` / `metadata dir` boundary assessment:

* `stdout` prints Markdown only
* omitted output means stdout, not `out/<stem>.md`
* if output looks directory-like, result is `<dir>/<input_stem>.md`
* metadata dir is always subordinate to Markdown dir
* assets dir is generally subordinate to output root, not metadata dir
* product-path validation should fail if stdout mode creates default `out/`
  directories or metadata sidecars
* this is workable, but still under-documented for nested-container cases

Cross-format behavior inconsistencies worth recording:

* HTML/ZIP/EPUB use passthrough-assembled Markdown in places, while many other
  formats rely purely on IR rendering
* debug inspect is rich for PDF and ZIP/EPUB internals, sparse at product level
  elsewhere
* some formats populate detailed origins (`page`, `slide`, `sheet`,
  `relationship_id`, `source_path`), while others only set `key_path` or line
  ranges

#### Current Capability

* Product shell is real and usable.
* Single-file and batch paths both exist.
* Metadata/assets/output path coordination is mostly centralized.
* OCR and debug are explicitly separated from the default path.

#### Gaps

* No unified inspect/debug UX across formats.
* No normalized product-level degrade/fail reason schema.
* Sidecar validation is now real, but fixture depth is still uneven across
  formats.
* Batch remains v1 only: serial, non-recursive, directory-driven.

#### Risks

* Top-level docs can overstate what "supported" means for some formats.
* Users may still over-read structure-level sidecar validation as exhaustive
  schema locking.
* Benchmark conclusions can be overgeneralized from mixed runner modes.

#### Second-Round Recommendation

* Keep current product shape, but harden the contract around:
  * format status terminology
  * sidecar validation
  * batch mode boundaries
  * debug/inspect discoverability
  * degrade/fail explanation

### 2.2 Unified IR / Markdown Emitter / Metadata Capability

Unified IR is defined in [core/ir.mbt](../core/ir.mbt). Markdown emission is in [core/emitter_markdown.mbt](../core/emitter_markdown.mbt). Metadata sidecar emission is in [core/metadata.mbt](../core/metadata.mbt).

Current block types:

* `Heading`
* `RichHeading`
* `Paragraph`
* `RichParagraph`
* `ListItem`
* `RichListItem`
* `BlockQuote`
* `RichBlockQuote`
* `CodeBlock`
* `Table`
* `RichTable`
* `Image` (legacy)
* `ImageBlock`
* `BlankLine`

Current inline types:

* `Text`
* `Break`
* `Link`

Current provenance structures:

* `Origin`
* `AssetOrigin`
* `ImageData`
* `Document.block_origins`
* `Document.asset_origins`
* `Document.passthrough_markdown`

IR support coverage assessment:

| Structure | Current IR support | Note |
| --- | --- | --- |
| Paragraph | Yes | plain and rich |
| Heading | Yes | plain and rich |
| List | Yes | ordered/unordered + nesting level |
| Table | Yes | legacy plain + `RichTable(header_rows)` |
| Image | Yes | canonical `ImageBlock(ImageData)` |
| Code | Yes | fenced block only |
| Link | Yes | inline only |
| Inline break | Yes | `Inline::Break` |
| Block origin | Partial but real | coarse provenance only |
| Asset origin | Partial but real | useful for images, not all resource classes |

What `Origin` can currently express:

* `source_name`
* `page`
* `slide`
* `sheet`
* `block_index`
* `heading_path`
* `line_start`
* `line_end`
* `row_index`
* `column_index`
* `object_ref`
* `relationship_id`
* `key_path`

What `AssetOrigin` can currently express:

* `source_name`
* `page`
* `slide`
* `sheet`
* `origin_id`
* `nearby_caption`
* `object_ref`
* `relationship_id`
* `source_path`
* `row_index`
* `column_index`
* `key_path`

Current emitter downgrade behavior:

* `RichTable(header_rows <= 0)` becomes Markdown table with synthetic
  `Column 1..N`
* `RichTable(header_rows > 0)` keeps only the first header row as Markdown
  header
* `Paragraph` newlines become `<br>`
* `Inline::Break` becomes `<br>`
* `ImageBlock` emits image line, optional italic title, optional caption
* Markdown/TXT/XML/ZIP/EPUB passthrough paths can bypass most structural
  rendering via `passthrough_markdown`

Current direct-Markdown bypasses:

* Markdown uses `set_passthrough_markdown`
* TXT uses `set_passthrough_markdown` for literal-safe output
* XML uses `set_passthrough_markdown` for fenced raw XML
* EPUB assembles final Markdown and stores it as passthrough
* ZIP assembles final Markdown and stores it as passthrough

This means the current repository is not "IR-only". It is "IR plus selected
passthrough-assembled formats". That is acceptable for this stage, but it is an
important architectural fact and should stay explicit.

Metadata sidecar expressiveness assessment:

Current strengths:

* block-oriented and asset-oriented views are both exposed
* image caption/alt/title/origin are reasonably aligned
* `RichTable` payload survives in sidecar
* OOXML docProps and EPUB OPF metadata can be serialized

Current limits:

* no bbox or char-span anchoring
* no table cell-level origin schema
* no DOM path or EPUB semantic spine object model in sidecar
* no format-specific debug payload section
* no confidence/explanation fields for degraded decisions

RAG / knowledge base / citation readiness assessment:

* adequate for coarse chunk provenance
* inadequate for precise citation or view-back anchoring
* good enough for file/page/slide/sheet-level indexing
* weak for table-cell, DOM-node, PDF-geometry, or EPUB-spine-fragment citation

#### Current Capability

* Shared IR is real and covers most basic Markdown structures.
* Metadata sidecar can already carry useful machine-facing origin and asset
  info.
* `RichTable` and `ImageBlock` are the most important current structured
  building blocks.

#### Gaps

* No inline style model beyond links and line breaks.
* No generic source-fragment anchor model.
* No first-class warning/degradation block type.
* No confidence/debug fields in sidecar.

#### Risks

* Passthrough-heavy formats can drift away from "fully inspectable IR" goals.
* Provenance is sufficient for auditing, but not yet for strong citation UX.
* Complex structures may appear "supported" in Markdown while losing important
  intermediate semantics.

#### Second-Round Recommendation

* Keep current IR stable for now.
* Add second-round design work around:
  * degrade/explanation model
  * richer origin anchors
  * format-specific sidecar extensions
  * stricter policy on when passthrough is acceptable versus when IR should be
    enriched

## 3. Task 2: Support Matrix

Status interpretation used here:

* `H1`: baseline support only
* `H2`: mainstream lightweight contract reasonably covered
* `H3`: performance-governed or benchmark-mature path
* `partial`: useful but clearly incomplete
* `unknown`: not enough local evidence

Current maturity judgement in this audit is intentionally stricter than "README
status" when sample/benchmark/support evidence is thin.

| Format | Maturity | Parser/core entry | Converter entry | Regression coverage | Benchmark coverage | Supported structures | Weak / unsupported structures | Stable degrade strategy | Metadata / origin | Assets | MS MarkItDown overlap | Quality shortboard | Performance risk | Priority | Next step |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DOCX | H2++ complete, H3++ evidence-backed on checked-in native overlap corpus | `doc_parse/ooxml`, `convert/docx/*` | `parse_docx` | strong second-round main + metadata + assets + tests | smoke + batch profile + metadata-on rows + compare | headings, style-linked headings, lists, tables, links, notes, headers/footers, text boxes, images, docProps | run styles beyond the checked-in subset, tracked changes UI, internal anchors, full visual table/layout fidelity | append sections, conservative merged-cell policy, text fallback | good coarse OOXML origin plus relationship/source-path evidence | yes | high | layout-engine non-goals remain explicit, but checked-in evidence now covers the mainstream document contract | medium | sealed | keep future work optional: richer inline style model, anchor promotion, stronger table provenance |
| PPTX | H2++ complete, H3++ evidence-backed on checked-in native overlap corpus | `doc_parse/ooxml`, `convert/pptx/*` | `parse_pptx` | strong main + metadata + assets + quality/benchmark evidence | smoke + metadata + compare + batch profile + extended | slide order, text, bullets, notes, hidden slides, explicit tables, grouped shapes, images, hyperlinks | charts, SmartArt, OLE, action links, merged tables, full z-order | readable downgrade + heuristic grouping | good slide/shape/image origin | yes | medium-high | still heuristic rather than layout-engine exact | low | closed | future work is bounded layout/table/comment refinement, not H2 closure |
| XLSX | H2++ complete, H3++ evidence-backed on checked-in native overlap corpus | `doc_parse/ooxml`, `convert/xlsx/*` | `parse_xlsx` / `inspect_xlsx` | strong main + metadata + tests | smoke + batch profile + extended + overlap compare | multi-sheet, shared strings, datetime, sparse trim, cached formulas, lightweight missing-cache formula eval v1, rich table, typed-cell/table hints | full Excel formula compatibility, merged reconstruction, comments/charts/images | top-left merged policy, cached-first formula policy, unsupported formula fail-closed policy | good sheet/row/col origin plus table hints | no | medium-high | formula/merged/state policy now evidenced, but no full formula engine or visual merge model | medium-high on large sheets | sealed | keep future work strictly optional: cross-sheet/lookup/array/dynamic formulas, charts/pivots/comments/images, full RSS benchmarking |
| PDF | H2++ complete (native text-PDF scope) | `doc_parse/pdf/*`, `vendor/mbtpdf` | `parse_pdf` | strong main + metadata/assets + tests | smoke + compare + batch profile + extended | text PDF, page blocks, headings, noise cleanup, merge, simple tables, URI links, images, captions | complex tables, outlines, internal links, OCR-default, complex layout | omit ambiguous structure, optional OCR path | moderate page/image/object origin | yes | medium | lower-layer signal still limits quality more than converter logic | medium | P2 | pdf_core signal enrichment before more heuristics |
| HTML | H2++ complete, H3++ evidence-backed on checked-in native overlap corpus | `convert/html/html_dom.mbt` + parser | `parse_html` | very strong main + metadata + assets + tests | smoke + compare + batch profile + metadata-on rows | headings, paragraphs, nested lists, blockquote, pre/code, table, links, local images, figure/figcaption, semantic containers, details/summary, provenance hints | browser tree-building, CSS layout, JS execution, remote fetch, full rowspan/colspan reconstruction | skip script/style/head/noscript; unsafe-link fail-closed; conservative literal fallback | block `object_ref`/`key_path`, table `span_cells`, asset `source_path` | yes local only | high | checked-in quality records show strong local overlap behavior, but not browser-grade parity | low-medium | sealed | keep future work optional: richer DOM/tree provenance, broader entity coverage, browser-like parsing intentionally out of scope |
| TXT | H2 | `convert/txt/txt_parser.mbt` | `parse_txt` | strong main + metadata + tests | smoke + compare + batch profile | paragraphs, UTF-8 normalize, literal-safe Markdown passthrough | semantic heading/list/table inference by design | fail closed on invalid UTF-8; literal-safe output | line-range origin only | no | medium | deliberate non-goal, but contract should stay explicit | low | P1 | benchmark guardrails and explicit text policy docs |
| Markdown | H2 | `convert/markdown/*` | `parse_markdown` | strong main + metadata + tests | smoke + compare | passthrough, conservative block summary | no AST rewrite, no semantic normalization | passthrough source | line-range origin only | no | medium | current path is intentionally minimal, not normalized Markdown understanding | very low | P1 | benchmark guardrails and metadata contract clarity |
| CSV | H2 | `convert/csv/csv_parser.mbt` | `parse_csv` | strong main + metadata + tests | smoke + compare + batch profile | quoted fields, BOM/CRLF, ragged rows, RichTable | no sniffing, no streaming, no typing | fail closed on malformed quotes | coarse table/line origin | no | high | always-header Markdown policy is simplistic | low-medium | P1 | parser hardening and streaming path design |
| TSV | H2 | `convert/csv/csv_parser.mbt` | `parse_tsv` | moderate main + metadata + tests | smoke | tab-delimited table path | same as CSV | same as CSV | coarse table/line origin | no | low-medium | less compare/benchmark evidence than CSV | low-medium | P1 | fold into CSV/TSV shared hardening plan |
| JSON | H2 | `convert/json/json_parser.mbt` | `parse_json` | strong main + metadata + tests | smoke + batch profile | object table, scalar arrays, uniform object-array tables, fallback code block | no streaming, no JSONL, shallow provenance | fail closed on invalid JSON | root `key_path` only | no | low-medium | provenance and large-file strategy are shallow | medium on large materialization | P1 | parser hardening and streaming/large-file plan |
| YAML / YML | partial H2 | `convert/yaml/yaml_parser.mbt` | `parse_yaml` | strong main + metadata + tests | smoke + batch profile | mapping table, scalar seq list, sequence-of-mappings table, fallback code block | subset only: no anchors/aliases/tags/block scalars/flow/multi-doc | fail closed on unsupported subset | root `key_path` only | no | low | support contract must say subset more loudly | medium | P1 | explicit YAML 1.2 subset contract and hardening |
| XML | H1/H2 partial | `convert/xml/xml_parser.mbt` tokenizer | `parse_xml` | strong main + metadata + tests | smoke | safe source-preserving fenced XML, tokenizer events | no semantic XML-family rendering, no namespaces/DTD semantics | fail closed on malformed syntax; literal preserve | whole-doc code-block origin only | no | low | useful substrate, but not really "semantic XML support" | low-medium | P1 | tokenizer/event model promotion and family-specific future split |
| ZIP | H2++ complete, H3++ evidence-backed on checked-in native corpus | `doc_parse/zip/*` | `parse_zip` / `inspect_zip` | strong main + metadata + tests | smoke + batch profile + metadata-on rows | safe entry traversal, nested supported-format dispatch, asset remap, inspect report, warning/degrade policy, container provenance | no nested archive recursion, no ZIP64/encrypted/data descriptor support, no fair external overlap corpus yet | warning blocks for unsupported/nested entries; fail closed on unsafe paths and normalized collisions | good container + nested asset `source_path` + nested provenance passthrough | yes | low | quality is now well-grounded for the checked-in corpus, but still intentionally conservative on unsupported low-level ZIP features | medium on large entry counts | sealed | keep future work optional: ZIP64/data-descriptor/encrypted support, richer inspect surfacing, broader corpus evidence |
| EPUB | H2++ complete, H3++ evidence-backed on checked-in native EPUB corpus | `doc_parse/epub/*` + ZIP/XML | `parse_epub` / `inspect_epub` | strong main + metadata + tests | smoke + batch profile + metadata-on rows + compare | OPF/container/spine/nav/NCX/cover/local images, warning/degrade policy, package metadata, XHTML provenance | no DRM, no CSS rendering, no JS, NCX minimal subset only, limited anchor model | warning blocks for missing/unsupported spine items; fail closed on container/path/encryption errors | good spine/source-path plus nested XHTML provenance | yes | medium | current checked-in corpus now evidences package/spine/nav/assets behavior, but not reader-grade rendering | medium | sealed | keep future work optional: broader EPUB variant coverage, richer anchor model, fuller NCX fidelity, memory/RSS baselines |

## 4. Task 3: Per-format Detailed Support and Boundaries

### DOCX

#### A. Current Support Range

Evidence comes from `convert/docx/*`, `doc_parse/ooxml/*`, and
`samples/main_process/docx/*`.

Stable support today includes:

* heading levels
* paragraphs
* ordered / unordered lists
* nested lists
* block quotes
* code-like paragraph downgrade
* tables
* multiline table cells in readable Markdown form
* hyperlinks in paragraph / heading / list contexts
* paragraph linebreaks and tabs
* footnotes / endnotes / comments as conservative append sections
* headers / footers with deduplication and page-number noise skipping
* text boxes including table-contained text boxes
* OOXML document properties in sidecar
* image asset export with relationship/source-path metadata
* table-cell hyperlink and image-alt retention on the default local path

#### B. Current Boundaries and Non-goals

Current non-support or conservative-only areas:

* no run-level bold/italic/code-span fidelity
* no rich inline style model
* no internal bookmark / anchor link promotion
* no tracked-change UX
* no merged/nested visual table reconstruction
* notes/comments remain append sections, not inline annotations

Explicit non-goal for this round:

* do not patch complex DOCX output by converter-only regex logic
* instead, identify missing OOXML numbering/style/relationship/document-part
  substrate when behavior is limited by source signal

#### C. Lower-layer Capability Gaps

Main substrate gaps:

* OOXML numbering and style semantics remain conservative rather than
  Word-complete
* relationship/object identity is useful but not yet a full inline-object model
* no stronger document-part origin model for every header/footer/comment/note
  scenario
* no cell-level table provenance or visual merged-cell model

#### D. H2 Quality Parity Tasks

This second-round sprint is now sealed for the checked-in DOCX contract.

Checked-in evidence now covers:

* nested/style-linked list behavior
* multi-run hyperlinks and hyperlink spacing
* multiline and merged-boundary tables
* notes/comments ordering
* headers/footers/text boxes
* local image asset behavior
* OOXML docProps-rich sidecars

Checked-in DOCX quality records now include:

* `docx-golden-structure`: `close`
* `docx-table-multiline-cell`: `win`
* `docx-list-link-style`: `close`
* `docx-notes-comments`: `win`
* `docx-image-assets`: `win`
* `docx-header-footer-textbox`: `close`

#### E. H3 Performance Tasks

Checked-in DOCX benchmark coverage now includes:

* small / medium / large
* table-heavy
* link-heavy
* image-heavy
* notes/comments-heavy
* metadata on/off
* batch profile with DOCX
* overlap compare against Microsoft MarkItDown on selected local samples

Current H3 conclusion is intentionally narrow:

* `H3++ evidence-backed on checked-in native overlap corpus`
* overlap conclusions are limited to the checked-in DOCX compare rows
* no blanket claim about all Word documents or full layout-engine workloads

### PPTX

#### A. Current Support Range

Evidence from `convert/pptx/*`, tests, rich main-process samples, metadata
fixtures, quality records, and checked-in benchmark rows.

Stable support today includes:

* slide order
* synthetic slide boundary headings
* title / subtitle / body paragraph separation
* bullets and ordered-list-like output
* reading-order-aware grouping
* grouped shape traversal
* explicit `a:tbl` table extraction
* heuristic table-like and callout-like regions
* speaker notes
* hidden slide preservation
* run-level and shape-level external hyperlink recovery
* image asset export with alt/title/caption-like metadata
* provenance-aware slide/shape/link/image metadata sidecars

#### B. Current Boundaries and Non-goals

Weak or unsupported:

* charts
* SmartArt
* OLE / embedded media
* animations and transitions
* internal/action/media links
* full merged-table visual fidelity
* exact z-order and visual grouping reconstruction

Current non-goal:

* do not fake full slide layout understanding by local Markdown heuristics only
* do not become a PowerPoint layout engine

#### C. Lower-layer Capability Gaps

Current closure stance:

* `H2++ complete`
* `H3++ evidence-backed on checked-in native overlap corpus`

Checked-in quality records:

* `pptx-title-bullets`: `win`
* `pptx-reading-order`: `win`
* `pptx-links-images`: `win`
* `pptx-notes-hidden-slides`: `win`
* `pptx-table-grid-callouts`: `win`
* `pptx-caption-like-image`: `win`

Checked-in benchmark coverage now includes:

* small / medium / large
* image-heavy
* link-heavy
* notes-heavy
* layout-heavy / many-shapes
* metadata on/off
* batch profile with PPTX
* selected local overlap compare rows against Microsoft MarkItDown

Current H3 conclusion remains narrow:

* runner path is `prebuilt-native`
* overlap conclusions are limited to the checked-in local PPTX compare rows
* no blanket claim about all presentation layouts or full slide-rendering
  workloads

### XLSX

#### A. Current Support Range

Stable support today includes:

* multi-sheet output
* sheet headings
* `RichTable` lowering
* shared strings and inline strings
* number/date/time/datetime formatting
* boolean / blank / error cell handling
* sparse used-range trimming
* cached formula value policy
* lower-layer merged range detection
* hidden/veryHidden sheet state in inspect layer
* row/column origin
* table-level metadata hints for `format`, `sheet_state`, `merged_ranges`,
  `formula_cells`, and `semantic_types`

#### B. Current Boundaries and Non-goals

Weak or unsupported:

* no full Excel formula engine
* no merged-cell visual reconstruction
* no comments, charts, pivots, images
* hidden sheets are not richly annotated in final Markdown beyond workbook
  order and headings

Current non-goal:

* no spreadsheet recalculation engine in converter layer

#### C. Lower-layer Capability Gaps

Main substrate gaps:

* lower layer lacks stronger workbook/table semantic model beyond used range
* style/format handling is enough for date/time and coarse semantic typing, but
  not richer workbook semantics
* no first-class table object model, comments model, drawing/image model
* no cell-span or merged-layout reconstruction model

#### D. H2 Quality Parity Tasks

Needed next samples:

* richer merged-header/body samples
* formula + cached-value matrix with compare records
* hidden/veryHidden sheet policy docs and compare notes
* sparse wide sheets with empty leading/trailing areas
* table-like business sheets with mixed types

#### E. H3 Performance Tasks

Benchmark design:

* small/medium/large workbook files
* multi-sheet large
* sparse large
* formula-heavy
* merged-heavy
* typed-cells
* batch directories of many small workbooks
* metadata on/off
* memory peak during sharedStrings/styles/worksheet materialization
* compare overlap-only where Python tool meaningfully supports the case

### PDF

#### A. Current Support Range

Evidence from `doc_parse/pdf/*`, `convert/pdf/*`, tests, and smoke corpus.

Stable support today includes:

* text-oriented PDF extraction
* page model, line staging, block staging
* headings
* paragraphs
* list-like text
* repeated header/footer cleanup
* cross-page paragraph merge
* high-confidence external URI links
* image extraction
* high-confidence same-page image captions
* simple aligned tables
* headerless numeric tables
* object/page provenance
* debug pipeline
* explicit OCR path and auto-fallback mode

#### B. Current Boundaries and Non-goals

Weak or unsupported:

* no full table engine
* no outline/bookmark emission
* no internal destination link emission
* no robust multi-column reconstruction
* no tagged-PDF semantic contract
* no OCR-first default path
* no full scanned PDF quality claim

Current non-goal:

* do not patch layout quality primarily in `convert/pdf` if the missing signal
  belongs in `doc_parse/pdf`

#### C. Lower-layer Capability Gaps

Main substrate gaps:

* no explicit outline/bookmark model in emitted path
* annotation model is present, but link emission strategy is still narrow
* limited table/grid signal model
* limited confidence model for layout decisions
* limited caption pairing signals for multiple nearby images
* no richer font/semantic signal exposure for heading detection

#### D. H2 Quality Parity Tasks

Needed next samples:

* more two-column negatives and partial positives
* table-like families: bordered, borderless, headerless, multiline
* link families: visible URI, hidden URI, internal dest, overlapping annotations
* figure/caption ambiguity sets
* repetitive legal/report PDFs with headers/footers and page numbers

#### E. H3 Performance Tasks

Benchmark design must separate:

* text PDF
* scanned/OCR PDF
* optional OCR fallback
* any future cloud/LLM path

Metrics and groups:

* small/medium/large text PDFs
* batch same-shape and mixed-shape PDFs
* metadata on/off
* debug on/off cost
* assets-heavy PDFs
* compare only on text-PDF overlap corpus
* memory peak for page model and image extraction

### HTML

#### A. Current Support Range

Stable support today includes:

* headings
* paragraphs
* ordered and unordered lists
* nested lists
* blockquotes
* `pre` / code blocks
* tables
* `br`
* inline links
* images
* `alt` / `title`
* `figure` / `figcaption`
* `details` / `summary`
* semantic containers such as `main` / `section` / `article` / `aside` / `nav`
* common entities and numeric entities
* script/style/head/noscript ignore policy
* local image asset export when path is accepted
* block-level provenance through `object_ref` / `key_path` where the unified
  metadata schema permits it
* HTML table span-boundary hints through metadata `span_cells`

#### B. Current Boundaries and Non-goals

Weak or unsupported:

* no CSS execution/layout
* no JS
* no remote fetch
* `data:` images are not materialized by default
* no full rowspan/colspan visual reconstruction
* no browser-spec tree builder
* unknown named entities remain literal

Current non-goal:

* no browser-grade rendering in converter
* no browser-style DOM/CSS/JS execution contract

#### C. Lower-layer Capability Gaps

Main substrate gaps:

* DOM/event model is lightweight and custom, not a stronger safe event/DOM API
* provenance is useful at block/key-path level, but still not a full DOM path
  or browser-grade tree contract
* no CSS display hint model
* local resource policy is useful but not generalized into a shared resource
  fetch/sanitizer substrate

#### D. H2 Quality Parity Tasks

Checked-in HTML H2++ evidence now includes:

* lightweight safe parser positioning rather than browser-grade rendering
* explicit no-JS, no-CSS-layout, no-remote-fetch boundary
* `script` / `style` / `head` / `noscript` ignore policy
* unsafe-link fail-closed policy for `javascript:` / `vbscript:` / `data:`
* local image asset export plus `alt` / `title` / `figcaption` preservation
* table coverage for header rows, ragged rows, inline links in cells, and
  span-boundary explanation through `span_cells`
* semantic-container, nested-list, blockquote, pre/code, and
  details/summary samples
* metadata/origin coverage for `object_ref`, `key_path`, table `span_cells`,
  and asset `source_path`
* checked-in quality records:
  * `html-document-structure`: `close`
  * `html-table-links`: `win`
  * `html-figure-image-assets`: `win`
  * `html-semantic-containers`: `close`
  * `html-unsafe-link-boundary`: `close`

These records are checked-in seed evidence, not blanket claims about all HTML
pages. They also do not compare JS/CSS execution, browser layout, or remote
fetch behavior.

#### E. H3 Performance Tasks

Checked-in HTML H3++ benchmark evidence now covers:

* `small`
* `medium`
* `large`
* `table-heavy`
* `link-heavy`
* `asset-heavy local`
* `malformed/common`
* metadata-on rows
* overlap compare with Microsoft MarkItDown
* batch profile with HTML

Current checked-in native overlap corpus observations are:

* prebuilt-native `markitdown-mb` is clearly faster than Microsoft
  MarkItDown 0.1.5 on the checked-in HTML overlap corpus
* batch profile shows clear startup/throughput benefit over repeated per-file
  `normal` invocations on the checked-in HTML batch corpus
* no new RSS/memory conclusion should be claimed here because the memory probe
  remains unavailable or unstable in the default checked-in harness
* these timing observations must not be generalized to all webpages or
  browser-like HTML workloads

HTML provenance enhancements also now surface naturally through ZIP/EPUB nested
HTML metadata snapshots. This sprint accepts those metadata refreshes as a
lower-layer HTML effect; ZIP/EPUB Markdown output semantics did not change, and
that downstream reflection was not, by itself, the reason ZIP/EPUB later moved
to `H2++ complete`; each format required its own checked-in evidence chain.

### TXT

#### A. Current Support Range

Stable support today includes:

* UTF-8 BOM removal
* CRLF/CR normalization
* paragraph splitting on blank lines
* literal-safe Markdown passthrough output
* paragraph line-range provenance

#### B. Current Boundaries and Non-goals

By design unsupported:

* heading inference
* list inference
* table inference
* code inference
* encoding auto-detection

#### C. Lower-layer Capability Gaps

Main gap is deliberate policy, not parser incompleteness:

* no broader text ingestion/encoding substrate
* no optional encoding sniffing mode
* no text chunk/origin model beyond paragraph lines

#### D. H2 Quality Parity Tasks

Needed next samples:

* long-line and whitespace edge cases
* non-BMP handling expectations
* mixed blank-line paragraph families

#### E. H3 Performance Tasks

Benchmark design:

* small/medium/large plain text
* batch many small files
* metadata on/off
* compare overlap-only on plain text, not Markdown-like text

### Markdown

#### A. Current Support Range

Stable support today includes:

* source-preserving passthrough
* conservative block slicing for metadata
* BOM/newline normalization
* frontmatter passthrough

#### B. Current Boundaries and Non-goals

Unsupported by design:

* Markdown AST normalization
* semantic re-render
* structure-preserving transformations

#### C. Lower-layer Capability Gaps

Main gap:

* no Markdown AST/parser substrate
* metadata summary blocks are intentionally shallow

#### D. H2 Quality Parity Tasks

Needed next samples:

* frontmatter variants
* raw HTML, nested links, fenced code, no trailing newline

#### E. H3 Performance Tasks

Benchmark design:

* small/medium/large Markdown files
* batch many small docs
* compare runner-level only, not semantic parity

### CSV

#### A. Current Support Range

Stable support today includes:

* comma-routed parsing
* quoted delimiter support
* escaped quotes
* quoted newline cells
* BOM/CRLF normalization
* ragged-row normalization
* blank-line skipping
* `RichTable`
* line-range/row/column origin

#### B. Current Boundaries and Non-goals

Unsupported or weak:

* no delimiter sniffing
* no schema inference
* no streaming
* no type/date inference

#### C. Lower-layer Capability Gaps

Main substrate gaps:

* parser is eager/materializing
* no dialect sniffing model
* no streaming table writer path

#### D. H2 Quality Parity Tasks

Needed next samples:

* quote/newline edge families
* wide ragged rows
* markdown-sensitive cells

#### E. H3 Performance Tasks

Benchmark design:

* small/medium/large CSV
* batch many small CSV
* metadata on/off
* compare overlap-only on plain CSV table cases

### TSV

#### A. Current Support Range

Stable support is the shared CSV engine with tab delimiter:

* tab-separated parsing
* trailing empty cells
* quoted tabs/newlines
* BOM/CRLF normalization
* ragged-row handling

#### B. Current Boundaries and Non-goals

Same as CSV, plus:

* less explicit compare coverage today

#### C. Lower-layer Capability Gaps

Same shared parser gaps as CSV.

#### D. H2 Quality Parity Tasks

Needed next samples:

* quoted tab and newline families
* large/wide TSV corpus

#### E. H3 Performance Tasks

Same shape as CSV, but keep TSV rows separate in smoke and warning policy.

### JSON

#### A. Current Support Range

Stable support today includes:

* object to key/value table
* scalar array to list
* uniform object array to table
* mixed/nested fallback to code block
* escapes and surrogate pairs
* strict number grammar
* BOM/CRLF normalization

#### B. Current Boundaries and Non-goals

Unsupported or weak:

* no JSON Lines
* no comments/trailing commas
* no JSON Schema
* no deep per-node provenance
* no streaming

#### C. Lower-layer Capability Gaps

Main gaps:

* eager materialization only
* provenance limited to root `key_path`
* no path-level node origin model

#### D. H2 Quality Parity Tasks

Needed next samples:

* large uniform object arrays
* nested mixed arrays/objects
* escaped/unicode heavy samples

#### E. H3 Performance Tasks

Benchmark design:

* small/medium/large JSON
* uniform object-array large
* batch many small JSON
* metadata on/off
* memory peak on large parse materialization

### YAML / YML

#### A. Current Support Range

Current stable subset includes:

* mapping to table
* scalar sequence to list
* sequence-of-mappings to table with stable key set
* nested fallback to code block
* comments/blank lines ignored
* BOM/CRLF normalization

#### B. Current Boundaries and Non-goals

Unsupported or subset-only:

* anchors / aliases
* tags
* block scalars
* flow style
* multi-document input
* merge keys

This should be documented as a conservative YAML subset, not generic YAML
support.

#### C. Lower-layer Capability Gaps

Main gaps:

* parser is subset-oriented, not YAML 1.2 broad coverage
* provenance limited to root `key_path`

#### D. H2 Quality Parity Tasks

Needed next samples:

* block scalar and flow-style negatives
* subset boundary fixtures
* large sequence-of-mappings files

#### E. H3 Performance Tasks

Benchmark design:

* small/medium/large subset YAML
* large sequence-of-mappings
* batch repeated YAML files
* metadata on/off

### XML

#### A. Current Support Range

Current stable support is source-preserving XML handling:

* fenced `xml` Markdown output
* BOM/CRLF normalization
* declarations, PI, comments, CDATA, doctype, entity refs preserved literally
* safe tokenizer event surface for syntax analysis

#### B. Current Boundaries and Non-goals

Unsupported:

* semantic XML-family conversion
* namespace-aware interpretation
* DTD/entity expansion
* external resource loading
* XHTML/OPF/SVG/RSS-specific rendering in the standalone XML path

#### C. Lower-layer Capability Gaps

Main opportunities:

* promote tokenizer/event model into a clearer shared lower-layer package
* add safe DOM/event subset if future formats need it

#### D. H2 Quality Parity Tasks

Needed next samples:

* malformed syntax families
* declarations/comments/CDATA/entity families
* markdown-sensitive literal text

#### E. H3 Performance Tasks

Benchmark design:

* small/medium/large XML source-preservation
* batch many XML docs
* metadata on/off

### ZIP

#### A. Current Support Range

Stable support today includes:

* ZIP inspect report
* safe normalized entry traversal
* skip hidden metadata/directories
* supported nested entries dispatched by extension
* local HTML image handling inside archive
* remapped nested assets
* deterministic warning blocks for unsupported or nested archive entries
* duplicate asset-name isolation through archive namespacing
* nested DOCX / PPTX asset remap with preserved nested provenance
* metadata sidecars that retain archive entry `key_path` plus nested
  `object_ref` / `relationship_id` / page-or-slide provenance when present

#### B. Current Boundaries and Non-goals

Unsupported or weak:

* nested archive recursion
* ZIP64
* encrypted ZIP
* data descriptor deep support
* generic binary preview

Fail-closed policy should remain explicit for:

* unsafe paths
* normalized collisions
* unsupported low-level ZIP features

#### C. Lower-layer Capability Gaps

Main substrate gaps:

* ZIP security model exists, but feature coverage is incomplete
* no reusable archive-entry IR beyond Markdown aggregation and inspect report
* no batch/container summary sidecar model

#### D. H2 Quality Parity Tasks

Checked-in ZIP H2++ evidence now includes:

* deterministic normalized entry ordering
* mixed supported-entry dispatch across Markdown / TXT / CSV / JSON / HTML
* explicit warning blocks for unsupported binary entries
* explicit warning blocks for nested archive boundaries
* hidden metadata skip policy with visible non-hidden dotfile behavior
* archive asset namespace/remap for nested HTML and OOXML image outputs
* duplicate asset-name isolation through archive entry ids
* metadata/origin coverage for archive entry `key_path`, nested block
  provenance, and nested asset `source_path`
* checked-in quality records:
  * `zip-mixed-supported`: `win`
  * `zip-assets-remap`: `win`
  * `zip-unsafe-path-boundary`: `not_comparable`
  * `zip-unsupported-entry-boundary`: `win`

These records are checked-in engineering evidence, not blanket claims about all
ZIP archives or recursive container traversal.

#### E. H3 Performance Tasks

Checked-in ZIP H3++ benchmark evidence now covers:

* `small`
* `medium`
* `large / many-entry`
* `mixed supported`
* `asset-heavy`
* `unsupported/degrade`
* metadata-on rows
* batch profile with ZIP

Current checked-in native corpus observations are:

* prebuilt-native smoke rows exist for the repository ZIP corpus, including
  mixed-supported and assets-heavy cases
* native batch profile shows clear startup/throughput benefit over repeated
  per-file ZIP conversion on the checked-in ZIP corpus
* no new RSS/memory conclusion should be claimed here because the default
  memory probe remains unavailable or unstable
* ZIP does not currently have a fair external overlap-performance corpus, so
  H3 conclusions stay scoped to the checked-in native ZIP corpus rather than a
  Microsoft MarkItDown speed comparison

### EPUB

#### A. Current Support Range

Stable support today includes:

* container.xml / OPF parsing
* manifest / spine parsing
* spine-order aggregation
* local XHTML/HTML spine conversion
* EPUB3 nav TOC emission
* EPUB2 NCX minimal fallback TOC on the checked-in subset
* cover-image emission with guide-cover image fallback
* same-archive local image remap and duplicate-name isolation
* OPF title / creator / language / identifier / publisher / date / modified
  metadata
* warning-block downgrade for missing manifest spine items
* warning-block downgrade for unsupported spine media items

#### B. Current Boundaries and Non-goals

Unsupported or weak:

* DRM/encryption
* CSS rendering
* richer NCX semantics beyond the current minimal subset
* advanced internal anchor/link model
* pageList / navList / landmarks / SMIL NCX features
* media overlays, fonts, SVG-heavy semantics

#### C. Lower-layer Capability Gaps

Main substrate gaps are now narrower and mostly future-facing:

* no stronger spine-fragment / anchor provenance model
* NCX support is intentionally minimal rather than reader-grade
* local image/resource policy is archive-safe and explainable, but not
  semantically rich beyond current asset/source provenance

#### D. H2 Quality Parity Tasks

Checked-in quality evidence now exists for:

* spine-order aggregation and explicit chapter boundaries
* EPUB3 nav TOC extraction
* local cover-image asset materialization
* unsupported spine-media warning/degrade behavior
* NCX fallback TOC on the current minimal-support subset

#### E. H3 Performance Tasks

Checked-in H3++ benchmark evidence now covers:

* small / medium / large-many-chapter native corpus rows
* asset-heavy and duplicate-asset EPUB rows
* metadata-on EPUB rows
* warning/degrade EPUB rows
* batch-profile EPUB runs
* meaningful local compare rows with Microsoft MarkItDown on selected overlap
  samples only

Current conclusion is intentionally scoped:

* EPUB is `H2++ complete`
* EPUB is `H3++ evidence-backed on checked-in native EPUB corpus`
* compare rows with Microsoft MarkItDown are meaningful on selected local
  samples, but no claim is made about all ebook workloads or reading-system
  rendering

## 5. Task 4: Second-Round Benchmark Design

### 4.1 Benchmark Goals

The second-round benchmark program should prove or disprove three things:

* whether MoonBit native CLI has startup/throughput/memory advantages on the
  default non-OCR, non-LLM local path
* which bottlenecks belong to parser/core, emitter, metadata, assets, or IO
* whether future changes regress either single-file latency or batch throughput

Benchmark conclusions must not:

* mix OCR/default paths
* mix cloud/plugin-assisted paths with local native paths
* treat `moon run` fallback numbers as native-only proof

### 4.2 Benchmark Dimensions

Every format family should aim to cover:

* small file
* medium file
* large file
* batch directory/group
* assets-heavy case when relevant
* metadata sidecar on/off
* debug on/off where a debug mode exists
* error/degrade cases for success/fail/degraded accounting

Additional format-specific dimensions:

* PDF: text PDF vs scanned/OCR PDF
* ZIP: entry-count-heavy vs assets-heavy vs mixed-supported
* XLSX: sparse vs dense vs multi-sheet
* EPUB: chapter-heavy vs asset-heavy

### 4.3 Comparison Targets

Primary targets:

* `markitdown-mb` native CLI
* Microsoft MarkItDown CLI on overlap corpus only

Comparison rules:

* if Microsoft MarkItDown does not support a format or requires optional
  components, mark it `not comparable` and state why
* PDF comparisons must separate:
  * text-only PDF overlap
  * scanned/OCR PDF
  * any Document Intelligence / LLM path

### 4.4 Metrics

Required metrics:

* wall time
* cold-start time
* warm-run time
* throughput files/sec
* throughput MB/sec
* peak RSS / memory when measurable
* output size
* asset count
* metadata size
* success / fail / degraded count
* quality score or manual quality notes

Recommended additional metrics:

* runner kind (`native`, `moon-run`, `python`)
* parse time vs emit time vs metadata time where profile hooks exist
* asset extraction time

### 4.5 Output Format

Recommended standardization target:

* `benchmark/results/*.json`
* `benchmark/results/*.md`
* `benchmark/corpus/README.md`
* `benchmark/run_native.sh`
* `benchmark/compare_markitdown.sh`

Current repo reality:

* benchmark artifacts are currently under `.tmp/bench/...`
* checked-in controls live in `samples/benchmark/*`
* scripts live in `samples/scripts/*`

Second-round recommendation:

* do not immediately rename everything
* first normalize fields and corpus policy
* then decide whether to keep `samples/benchmark` or promote a top-level
  `benchmark/` namespace

Current script audit summary:

* `samples/bench.sh --suite smoke`: good public smoke harness over broad
  checked-in corpus
* `samples/bench.sh --suite compare`: good public overlap-only comparison
  harness
* `samples/bench.sh --suite batch-profile`: good public profiling harness, not
  a public stable result schema
* `samples/check.sh --manifest-only`: useful governance helper surface

Follow-up status:

* benchmark governance now has a dedicated summary document:
  [docs/archive/benchmark/benchmark-governance.md](../benchmark/benchmark-governance.md)
* the repository kept the current `samples/benchmark/*` and `.tmp/bench/*`
  layout, but raw JSON outputs now expose clearer suite/runner/status fields
* TSV summaries remain suite-specific by design; they are still not a universal
  stable benchmark API

Main benchmark hardening gaps:

* no quality-aware benchmark summary schema yet
* no unified degraded/fail reason taxonomy in benchmark outputs
* no per-format explicit "not comparable" registry
* no cross-format cold-start baseline table

## 6. Task 5: Quality Comparison Template

Quality comparison in this project should optimize for Markdown usefulness for:

* LLM ingestion
* RAG chunking
* knowledge-base import
* human-readable structure

It should not optimize for:

* visual fidelity
* pixel-perfect layout recreation

Recommended template:

```md
## Sample: <sample name>

- format: <format>
- feature focus: <feature focus>
- expected important structures: <headings/lists/tables/links/images/code/etc.>
- markitdown-mb result: <summary>
- Microsoft MarkItDown result: <summary>
- verdict: win | close | loss | not comparable
- lost structures: <what was lost>
- extra noise: <what extra noise appeared>
- asset behavior: <export/remap/caption behavior>
- metadata/origin behavior: <what provenance survived>
- degradation explanation: <why current result degraded>
- next action: <sample / parser / converter / benchmark follow-up>
```

Current rollout status:

* a dedicated checked-in directory now exists at
  [docs/quality-comparisons/README.md](./quality-comparisons/README.md)
* a reusable template now exists at
  [docs/quality-comparisons/template.md](./quality-comparisons/template.md)
* the current seed set is intentionally small and sample-scoped; it is not a
  blanket parity conclusion

## 7. Task 6: Second-Round Task Queue

### P0: Project-level Guardrails

#### P0.1 Support matrix and status vocabulary cleanup

Goal:

* stop treating "format present in dispatcher" as "final done"

Impact:

* README/docs terminology
* future progress tracking

Modules:

* `README.mbt.md`
* `docs/support-and-limits.md`
* `docs/progress.md`
* this audit

Samples / benchmark:

* none required

Risk:

* low, but user-visible messaging changes

Done when:

* H1/H2/H3/partial wording is consistent and conservative

Current status:

* fixed in this follow-up for `README.mbt.md`,
  `docs/support-and-limits.md`, `docs/progress.md`, and this audit
* remaining work is to keep older milestone documents from being read as
  product-level "final done" claims

#### P0.2 Metadata validation contract fix

Goal:

* make `samples/check.sh --metadata-only` either actually validate sidecar JSON or
  rename the script/scope

Impact:

* validation trustworthiness

Modules:

* `samples/check.sh --metadata-only`
* `samples/scripts/validation_helpers.sh`
* expected metadata fixtures under `samples/main_process/<format>/expected`
* lower-layer metadata fixtures under `samples/fixtures/metadata`

Samples:

* existing metadata corpus

Benchmark:

* none

Risk:

* low-medium because expected fixtures/workflow may need adjustment

Done when:

* metadata validation name and behavior match

Current status:

* fixed in this follow-up: `samples/check.sh --metadata-only` now runs
  `--with-metadata`, validates sidecar path/JSON/core fields/assets, and uses
  semantic JSON fixture comparison where fixtures exist
* remaining work is broader per-format fixture coverage, not a rename or
  contract mismatch fix

#### P0.3 Benchmark corpus/governance stabilization

Goal:

* fix the second-round benchmark contract before more speed claims

Impact:

* smoke/compare/batch-profile outputs and docs

Modules:

* `samples/benchmark/*`
* `samples/scripts/bench_*`
* benchmark docs

Samples:

* corpus manifest and sample naming discipline

Benchmark:

* rerun smoke and selected compare after field normalization

Risk:

* low

Done when:

* per-format benchmark scope and comparability are explicit

Current status:

* partially fixed in this follow-up:
  * current checked-in benchmark corpus coverage is now summarized
  * runner classes, execution paths, raw result fields, and comparability rules
    are documented in [docs/archive/benchmark/benchmark-governance.md](../benchmark/benchmark-governance.md)
  * raw JSON outputs from smoke/compare/batch-profile now carry clearer
    suite/runner/status/execution-path fields
* remaining work is compare-corpus expansion, not-comparable registry growth,
  and stronger summary-level degraded/fail taxonomy

#### P0.4 Quality comparison record rollout

Goal:

* establish a durable review format for `mb` vs Microsoft MarkItDown quality

Impact:

* future parity work prioritization

Modules:

* docs only initially

Samples:

* select overlap cases for DOCX/PPTX/PDF/HTML/CSV/Markdown/TXT/XLSX

Benchmark:

* none

Risk:

* low

Done when:

* at least a few seed comparison records exist in the agreed template

Current status:

* fixed in this follow-up:
  * checked-in quality comparison docs now exist under
    [docs/quality-comparisons/README.md](./quality-comparisons/README.md)
  * the repository now has a reusable comparison template plus seed records for
    DOCX / PPTX / XLSX / HTML / CSV / Markdown / TXT / PDF
  * each seed record names the concrete sample, commands, comparable scope, and
    verdict
* remaining work is broader record coverage, explicit not-comparable cases, and
  future metadata-aware quality records where fair

### P1: Textlike / Structured Data Hardening

#### P1.1 TXT H2/H3 hardening

Goal:

* freeze literal text policy and benchmark it clearly

Impact:

* TXT parsing/output expectations

Modules:

* `convert/txt/*`
* docs

Samples:

* more whitespace/encoding edge cases

Benchmark:

* small/medium/large + batch

Risk:

* low

Done when:

* TXT contract is explicit and benchmarked

#### P1.2 Markdown H2/H3 hardening

Goal:

* freeze passthrough semantics and metadata expectations

Modules:

* `convert/markdown/*`

Samples:

* frontmatter/raw HTML/no-trailing-newline/pathological literal cases

Benchmark:

* small/medium/large + batch

Risk:

* low

Done when:

* Markdown passthrough contract is explicit and stable

#### P1.3 CSV/TSV parser hardening and streaming design

Goal:

* strengthen parser correctness and define H3 large-file strategy

Modules:

* `convert/csv/*`

Samples:

* wider quoted newline/ragged/huge row corpora

Benchmark:

* large single file and batch many-small

Risk:

* medium because parser changes may affect current output

Done when:

* parser edge coverage grows and streaming plan is documented or implemented

#### P1.4 JSON hardening and large-file strategy

Goal:

* make large-file and provenance limitations explicit, then improve them

Modules:

* `convert/json/*`

Samples:

* large object-array and nested-array corpora

Benchmark:

* large JSON + memory peak

Risk:

* medium

Done when:

* large-file plan and path-level provenance direction are documented

#### P1.5 YAML subset clarification and hardening

Goal:

* explicitly document and test the supported YAML subset

Modules:

* `convert/yaml/*`

Samples:

* subset boundary positives/negatives

Benchmark:

* subset large files and batch

Risk:

* low-medium

Done when:

* "subset" is explicit in docs and tests

#### P1.6 XML safe tokenizer/event model promotion

Goal:

* treat XML tokenizer/event model as a lower-layer deliverable, not only a
  source-preserving converter helper

Modules:

* `convert/xml/*`
* possibly `doc_parse/xml/*` in future

Samples:

* malformed and entity/declaration families

Benchmark:

* source-preserving XML only

Risk:

* medium if package reshaping happens

Done when:

* XML substrate boundary is explicit and reusable

### P1: HTML / XLSX / ZIP / EPUB

#### P1.7 HTML DOM semantics and resource hardening

Goal:

* improve semantic DOM handling and local resource policy

Modules:

* `convert/html/*`

Samples:

* richer wrappers/tables/figure/resource path cases

Benchmark:

* mixed and assets-heavy HTML

Risk:

* medium

Done when:

* recorded in the hardening pass as `HTML H2++ complete`
* HTML remains explicitly positioned as a lightweight safe semantic parser, not
  a browser-grade engine
* H3 claims stay limited to the checked-in native overlap corpus

#### P1.8 XLSX table/type hardening

Goal:

* strengthen workbook/sheet semantic model before pushing quality claims

Modules:

* `convert/xlsx/*`
* `doc_parse/ooxml/*`

Samples:

* merged/formula/hidden/type-heavy sheets

Benchmark:

* large and sparse workbooks

Risk:

* medium-high

Done when:

* merged/formula/hidden behavior is explicit in output and metadata

#### P1.9 ZIP container safety and inspect hardening

Goal:

* improve container-level feature support and product-facing inspect clarity

Modules:

* `doc_parse/zip/*`
* `convert/zip/*`

Samples:

* ZIP64, encrypted, data descriptor, unsafe-path negatives as available

Benchmark:

* many-entry and assets-heavy ZIPs

Risk:

* medium

Done when:

* recorded in the hardening pass as `ZIP H2++ complete`
* supported/unsupported ZIP feature boundary is explicit and tested
* H3 claims stay limited to the checked-in native ZIP corpus

#### P1.10 EPUB spine/nav/assets/link model hardening

Goal:

* improve EPUB package semantics and provenance

Modules:

* `doc_parse/epub/*`
* `convert/epub/*`

Samples:

* nav/cover/internal link/unsupported media families

Benchmark:

* chapter-heavy and assets-heavy EPUBs

Risk:

* medium

Done when:

* spine/nav/link/assets model is richer and better surfaced in metadata

### P2: OOXML High-value Quality Work

#### P2.1 DOCX quality parity push

Goal:

* close high-value mainstream DOCX gaps without pretending to solve all Word
  semantics

Modules:

* `convert/docx/*`
* `doc_parse/ooxml/*`

Samples:

* style/numbering/link/textbox/note edge cases

Benchmark:

* docx medium/large and batch

Risk:

* medium-high

Done when:

* higher-confidence mainstream docs compare favorably on chosen quality records

#### P2.2 PPTX layout quality push

Goal:

* improve reading-order and grouped layout quality on mainstream decks

Modules:

* `convert/pptx/*`
* `doc_parse/ooxml/*`

Samples:

* multi-column, grouped, note-heavy, table-heavy decks

Benchmark:

* layout-dense and many-slide decks

Risk:

* high because heuristics can regress readability

Done when:

* quality records show better structure retention without obvious noise growth

#### P2.3 XLSX formula/date/merged/table model push

Goal:

* improve spreadsheet semantics where they materially affect Markdown utility

Modules:

* `convert/xlsx/*`

Samples:

* formula cache, merged ranges, typed cells, table-like business sheets

Benchmark:

* large typed/multi-sheet files

Risk:

* medium-high

Done when:

* output and sidecar better expose type and table policy

### P2: PDF Deep-water Work

#### P2.4 PDF signal model enrichment

Goal:

* improve lower-layer signals before converter heuristics

Modules:

* `doc_parse/pdf/*`
* `convert/pdf/*`

Samples:

* outline/link/table/caption/layout edge sets

Benchmark:

* text-PDF corpora only for default path

Risk:

* high

Done when:

* heading/noise/table/link decisions have stronger explicit substrate support

#### P2.5 PDF outline/bookmark and link strategy

Goal:

* define emitted strategy for outlines/bookmarks/internal destinations

Modules:

* `doc_parse/pdf/raw|model|api`
* `convert/pdf/*`

Samples:

* bookmarked reports/manuals

Benchmark:

* not primarily perf-driven; use quality records

Risk:

* medium-high

Done when:

* policy is explicit and tested

#### P2.6 PDF table/caption/layout confidence expansion

Goal:

* extend useful table/caption/layout recovery without destabilizing text PDFs

Modules:

* `convert/pdf/*`
* `doc_parse/pdf/*`

Samples:

* multi-image caption pairs, borderless grids, headerless tables

Benchmark:

* text-PDF quality suite + debug cost

Risk:

* high

Done when:

* confidence-aware behavior is better and regressions remain explainable

### P3: Optional Expansion

Candidate formats and paths:

* EML
* IPYNB
* RTF
* ODT / ODS / ODP
* image OCR as broader product path
* audio / YouTube
* LLM / vision / plugin paths

Rule for P3:

* do not start these until P0-P2 contract hardening is in better shape

## 8. Task 7: Documentation and Terminology Consistency Audit

Current issues to record at audit start, with current follow-up status:

### 8.1 H1/H2/H3 language is too "done" in top-level docs

Evidence:

* [README.mbt.md](./../README.mbt.md) and
  [docs/archive/roadmap/progress.md](../roadmap/progress.md)
  present the repo as post-H2 and post-H3-phase-1 complete across the main
  format set.

Why this is a problem:

* some formats are truly useful, but still partial in ways that matter for
  quality parity or lower-layer completeness
* "H2 complete" is fine as an internal milestone label, but needs stronger
  boundary language in user-facing summaries

Current follow-up status:

* partially resolved: README/progress/support wording is now tighter, but older
  milestone docs still need to be read as historical milestone records, not
  universal product claims

### 8.2 "Supports format X" sometimes lacks explicit boundary language

Examples:

* YAML is really a supported subset
* XML is source-preserving XML handling, not semantic XML-family rendering
* PDF is text-oriented conservative PDF support, not generic PDF semantic
  completeness
* ZIP/EPUB support depends heavily on nested-format maturity and security
  boundaries

### 8.3 "Speed lead" language must stay qualified

Current benchmark docs are more careful than README, but the repository still
needs a stronger discipline that:

* native lead claims require native runner evidence
* overlap-only compare claims remain overlap-only
* OCR/cloud/plugin paths are excluded from local-native lead claims

Current follow-up status:

* partially resolved: top-level wording was tightened, while broader
  benchmark-governance work remains an H3/P0.3 task

### 8.4 OCR / LLM / default local path must stay separated

Current code does this reasonably well:

* explicit `ocr` subcommand
* PDF auto-fallback only when explicitly requested via enhance mode

Documentation should keep this separation prominent.

### 8.5 Parser/core vs converter boundary is still easy to blur

Needed correction:

* second-round tasks should prefer lower-layer fixes when missing signal is the
  real bottleneck
* avoid framing every quality gap as a converter heuristic TODO

### 8.6 Metadata / origin / assets wording is not fully consistent

Most important concrete issue:

* `samples/check.sh --metadata-only` previously ran normal conversion without
  `--with-metadata`, so the name overstated sidecar verification strength

Current follow-up status:

* fixed: the script now validates real sidecars and compares to JSON fixtures
  where present; remaining work is fixture expansion, not contract mismatch

### 8.7 Project structure terminology is slightly stale

Observed mismatch:

* repository instructions still emphasize `moon.pkg.json`, while the current
  repo uses `moon.pkg` files

This is mostly documentation hygiene, but worth recording.

## 9. Task 8: Validation Plan for This Round

Requested validation:

* `moon check`
* `moon test`
* `moon bench`
* existing sample scripts that actually exist:
  * `bash samples/check.sh`
  * `bash samples/check.sh --metadata-only`
  * `bash samples/check.sh --assets-only`
  * `bash samples/check.sh --manifest-only`

Local pre-audit existence check:

* `samples/check.sh`: exists
* `samples/check.sh --markdown-only`: exists
* `samples/check.sh --metadata-only`: exists
* `samples/check.sh --assets-only`: exists
* `samples/check.sh --manifest-only`: exists

Expected validation note for `moon bench`:

* repository search did not find current benchmark test blocks in MoonBit code
* if `moon bench` fails or reports no benchmark target, that result is expected
  and should be recorded honestly

## 10. Recommended Immediate Next Step

The most valuable next round is:

1. land P0 contract cleanup first
2. fix metadata validation naming/behavior
3. create a small set of real quality-comparison records
4. choose one P1 lower-layer track from:
   * CSV/TSV streaming hardening
   * XLSX table/type/merged semantics
   * EPUB spine/nav/link model
   * HTML DOM/resource hardening
5. keep PDF deep work for a dedicated substrate-first pass, not opportunistic
   converter patching

If only one follow-up should be chosen next, the strongest recommendation is:

* **P0.2 metadata validation contract fix plus P0.1 status-vocabulary cleanup**

Reason:

* they improve the trustworthiness of every future claim without forcing
  converter-semantic churn
* they make later quality and benchmark work easier to interpret
