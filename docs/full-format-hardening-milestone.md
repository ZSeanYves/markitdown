# Full-format hardening milestone

This milestone closes the first full-format hardening stretch across the
repository:

* H1 baseline completion for the simpler text and structured-data formats
* H1/H2 review and baseline strengthening for web, spreadsheet, container, and
  ebook formats
* H2 completion across DOCX, PPTX, and PDF after deeper closure work

This is not the final completion state of the project. It is the first complete
product-stage milestone after the repository moved from “supports these
formats” to “must ship quality, speed, and reusable parsing infrastructure”.

Important framing:

* `H1 complete` does not mean final parity
* `H2 complete` does not mean every advanced feature is already implemented
* the PDF completion recorded here is still text-first and core-first, not a
  full layout or OCR platform

## Current Full-format Status

| Format | Current status | Main completed work | Remaining H2/H3 focus |
| --- | --- | --- | --- |
| TXT | H2 complete | conservative paragraph conversion, literal-safe Markdown output, metadata, smoke baseline, overlap comparison baseline | very large file behavior, batch profiling, encoding fallback policy |
| Markdown / MD / MARKDOWN | H2 complete | passthrough baseline, normalization, metadata, smoke baseline, frontmatter passthrough policy | larger passthrough profiling, batch performance |
| CSV | H2 complete | table baseline, quoted delimiter/newline handling, ragged rows, RichTable metadata semantics, smoke baseline | streaming, large-table memory behavior, wider overlap corpus |
| TSV | H2 complete | table baseline, quoted tab handling, ragged rows, RichTable metadata semantics, smoke baseline | streaming, large-table memory behavior, overlap-comparison practicality |
| JSON | H2 complete | conservative structured-data baseline, unicode escape decoding, strict number grammar, RichTable metadata semantics, smoke baseline | large nested profiling, streaming/materialization behavior, overlap-comparison practicality |
| YAML / YML | H2 complete | conservative subset parser, fail-closed unsupported-feature policy, RichTable metadata semantics, smoke baseline | larger real-world subset review, H3 config-style profiling, any future subset expansion |
| XML | H2 complete | source-preserving fenced-code baseline, safe tokenizer/event surface, metadata, smoke baseline | future XML-family converters can build on tokenizer without changing generic XML output |
| HTML / HTM | H2 complete | lightweight DOM-like lowering, entity handling, RichTable metadata semantics, assets/metadata coverage, smoke baseline | DOM-path provenance, rowspan/colspan reconstruction, larger real-world HTML corpus |
| XLSX | H2 complete | workbook/sheet/cell lower layer, hidden-sheet state capture, formula cached-value + lower-layer formula text policy, merged-range detection, RichTable metadata semantics, smoke baseline | comments/drawings/charts, richer real-world workbook corpus, H3 sparse/dense profiling |
| ZIP | H2 complete | safe-entry conversion, fail-closed unsafe paths, inspect/inventory surface, asset remap, metadata, smoke baseline | ZIP64, data descriptor, streaming, bomb protection, broader mixed-archive corpus |
| EPUB | H2 complete | container/OPF/spine/nav/cover pipeline, assets/metadata, fail-closed package safety, smoke baseline | NCX, richer internal-anchor semantics, broader asset graph, large ebook profiling |
| DOCX | H2 complete | numbering/list semantics hardening, RichTable table metadata, footnotes/endnotes/comments append sections, header/footer append sections, textbox append sections, conservative accepted-view revision policy, assets/metadata coverage, smoke baseline, overlap comparison refresh | richer inline styling, bookmark/internal-link promotion, merged/nested visual reconstruction |
| PPTX | H2 complete | explicit table XML lowering, speaker notes output, hidden slide annotation, explicit `p:grpSp` traversal with grouped text/image/table recovery, assets/metadata coverage, smoke baseline, overlap comparison refresh | comments, charts, SmartArt, internal/action links, richer table merge reconstruction |
| PDF | H2 complete | `doc_parse/pdf` model/debug pass, link signal/emission work, heading/noise/merge hardening, conservative table lowering including headerless numeric tables, conservative image-caption association, numeric page-number scoping hardening, smoke/comparison refresh | outlines/bookmarks, internal Dest, positive multi-column reading order, larger real-world profiling, future H2.1 table/caption breadth only if product demand appears |

## Text / Structured-data Group

Formats in this group:

* TXT
* Markdown
* CSV
* TSV
* JSON
* YAML / YML
* XML

What is completed:

* H1 baseline is complete across the group
* sample regression, metadata, benchmark corpus, and support/limits wording are
  already consolidated
* TXT is stable as literal-safe paragraph conversion
* Markdown is stable as conservative passthrough/normalization
* CSV / TSV are stable as conservative table conversion with explicit table
  metadata semantics
* JSON is stable as conservative structured-data conversion with standard escape
  decoding and explicit table metadata semantics
* YAML is stable as conservative subset-based structured-data conversion with
  explicit fail-closed unsupported-feature policy
* XML is stable as source-preserving fenced `xml` output with a reusable safe
  tokenizer/event surface

Remaining focus:

* TXT: very large file / batch behavior and encoding fallback policy
* Markdown: frontmatter policy and large passthrough speed
* CSV / TSV: streaming and large-table memory behavior
* JSON: large nested cases, streaming/materialization behavior
* YAML: larger real-world subset review and any future explicitly scoped subset
  expansion
* XML: future XML-family specialization on top of the tokenizer, plus H3 large
  / batch profiling

## Web / Spreadsheet / Container / Ebook Group

Formats in this group:

* HTML / HTM
* XLSX
* ZIP
* EPUB

What is completed:

* HTML H1/H2 review is done, with baseline strengthening and a documented gap
  list
* XLSX H2 lower-layer upgrade is done, with workbook / sheet / cell semantics,
  formula cached-value policy, merged-range detection, hidden-sheet state, and
  RichTable metadata documented
* ZIP H2 lower-layer upgrade is done, with fail-closed unsafe-path policy,
  inspect/inventory surface, asset remap, metadata, and smoke coverage
* EPUB H2 ebook upgrade is done, with package/spine/nav/cover/assets/metadata
  and fail-closed behavior documented

Remaining focus:

* HTML: stronger DOM/entity/source-origin/table-cell semantics, plus
  rowspan/colspan/details handling
* XLSX: comments/drawings/charts, broader workbook corpus, and H3 sparse/dense
  profiling
* ZIP: ZIP64, data descriptor, streaming/materialization split, bomb
  protection, and broader mixed-archive corpus
* EPUB: NCX, richer internal anchors, broader asset graph, large ebook
  profiling

## Office Group

Formats in this group:

* DOCX
* PPTX

What is completed:

* DOCX H2 market-parity review and closure work are completed
* DOCX overlap comparison and smoke coverage now show strong selected-case
  speed wins over Microsoft MarkItDown, with semantic differences documented
* PPTX H2 layout-quality review and closure work are completed
* PPTX overlap comparison and smoke coverage now show strong selected-case
  speed wins over Microsoft MarkItDown, with documented limitations

Remaining focus:

* DOCX: richer inline styling, bookmark/internal-link promotion,
  merged/nested-table visual reconstruction
* PPTX: comments, charts, SmartArt, internal/action links, richer table merge
  reconstruction

Important note:

* these completed H2 passes do not claim full market parity
* they lock in current strengths, limits, and overlap-only
  benchmark/comparison baselines

## PDF Group

The PDF path completed a deeper staged pass than the other formats in this
milestone:

* H2 core gap review
* P1 `doc_parse/pdf` model/debug signal pass
* P1.1 annotation/link signal pass
* P2 link emission policy
* P2.1 debug-only URI link matching
* P2.2 high-confidence URI link emission
* P3 heading/noise/cross-page audit
* P3.1 heading attribution signals
* P3.2 edge noise attribution signals
* P3.3 cross-page merge attribution signals
* P4.1 heading policy guards hardened
* P4.2 edge noise policy guards hardened
* P4.3 cross-page merge policy hardened
* P4.4 benchmark/comparison refresh

What this means:

* PDF work is no longer just ad hoc converter heuristics
* `doc_parse/pdf` has become a visible lower-layer deliverable with inspect/debug
  surfaces
* heading, repeated edge noise, cross-page merge, and URI link emission now
  have explicit evidence/reason surfaces
* text-PDF smoke and overlap comparison baselines are now broad enough to
  represent real H2 progress rather than a single simple sample

Remaining PDF focus:

* outlines / bookmarks
* richer link provenance / internal Dest handling
* positive multi-column reading order
* tagged PDF semantics
* deeper encrypted/object-stream/xref-stream support if product needs it
* larger real-world text-PDF benchmarking and profiling

## Benchmark / Comparison Summary

Current benchmark/comparison posture:

* smoke benchmark now covers all major supported format families with
  representative small/medium/large or capability-focused samples
* comparison harness now defaults to prebuilt native CLI when available
* fallback `moon run` is still supported, but it includes wrapper overhead and
  should not be confused with native-cli timing
* Microsoft MarkItDown comparison remains overlap-only
* overlap-only comparison does not mean full semantic parity
* output differences are recorded at the semantic level, not forced to be
  byte-identical

Selected overlap cases now show clear speed wins for `markitdown-mb` in:

* TXT
* DOCX
* PPTX
* PDF

Important scope note:

> Speed wins are measured for selected overlap cases, not a blanket claim for
> every possible document.

## Bottom-layer Deliverables

The current milestone matters because the repository now clearly contains
reusable parsing/model infrastructure, not just Markdown-output glue.

Key lower-layer deliverables include:

* OOXML package / relationships / docProps / media helpers
* XLSX workbook / worksheet / sharedStrings / styles / datetime handling
* ZIP reader / safe path / archive entry handling / asset remap support
* EPUB package / OPF / manifest / spine handling
* HTML parser / DOM-like lowering
* CSV / TSV delimited parser
* JSON / YAML structured parsers
* XML conservative source-preserving baseline plus a reusable tokenizer/event
  model
* PDF `doc_parse/pdf` page/text/image/annotation/source-ref/debug surface

Repository principle:

* `convert/*` is the Markdown consumer layer
* parser/core/model packages are reusable infrastructure
* when quality stalls because converter logic lacks source signal, the preferred
  fix is to improve the lower layer
* debug/inspect/regression/benchmark surfaces are part of productization, not
  optional developer extras

## Known Non-goals For This Milestone

This milestone does **not** claim support for:

* OCR as the default product path
* LLM / vision as the default path
* browser-grade HTML rendering or JavaScript execution
* Excel formula evaluation
* PowerPoint visual layout engine behavior
* Word full layout-engine behavior
* PDF full visual reconstruction
* DRM bypass
* remote resource fetching
* full YAML spec coverage
* full XML semantic parsing
* full EPUB reader semantics

## Next-stage Top 10

1. Sample script temp-dir isolation, so `diff/check_metadata/check_assets` can
   run without `.tmp/samples` collisions.
2. H3 benchmark discipline: batch / large / memory profiling as a regular
   workflow.
3. HTML H2 lower-layer upgrade: entity/DOM/source-origin/table-cell semantics.
4. XLSX H2 lower-layer upgrade: merged ranges, formula text + cached value,
   styles/custom numFmt.
5. ZIP H2 lower-layer upgrade: ZIP64, data descriptor, streaming, inventory.
6. EPUB next pass: NCX, broader anchor semantics, richer asset graph.
7. DOCX H2: styles, numbering, footnotes/comments/textboxes.
8. PPTX H2: explicit table XML, notes, group-shape tree.
9. PDF H2 next pass: tables, image captions, outlines, internal links, larger
   real-world profiling.
10. Release polish: README product positioning, CLI help polish, support
    matrix wording, benchmark docs discipline.

## Milestone Takeaway

This milestone is the point where the project stops looking like “many formats
are wired up” and starts looking like a product with:

* a stable supported surface
* explicit gap documentation
* reusable lower layers
* measurable native-speed advantages on overlap cases
* a credible next-phase backlog organized around quality, performance, and
  parser/core upgrades
