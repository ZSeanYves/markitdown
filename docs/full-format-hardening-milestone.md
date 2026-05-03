# Full-format hardening milestone

This milestone closes the first full-format hardening stretch across the
repository:

* H1 baseline completion for the simpler text and structured-data formats
* H1/H2 review and baseline strengthening for web, spreadsheet, container, and
  ebook formats
* H2 review passes for DOCX and PPTX
* a core-first PDF deep pass through P4.4 benchmark/comparison refresh

This is not the final completion state of the project. It is the first complete
product-stage milestone after the repository moved from “supports these
formats” to “must ship quality, speed, and reusable parsing infrastructure”.

Important framing:

* `H1 complete` does not mean final parity
* `H2 reviewed` does not mean every advanced feature is already implemented
* the PDF deep pass completed here is still text-first and core-first, not a
  full layout or OCR platform

## Current Full-format Status

| Format | Current status | Main completed work | Remaining H2/H3 focus |
| --- | --- | --- | --- |
| TXT | H2 readiness audited, H2 complete | conservative paragraph conversion, literal-safe Markdown output, metadata, smoke baseline, overlap comparison baseline | very large file behavior, batch profiling, encoding fallback policy |
| Markdown / MD / MARKDOWN | H2 readiness audited, H2 complete | passthrough baseline, normalization, metadata, smoke baseline, frontmatter passthrough policy | larger passthrough profiling, batch performance |
| CSV | H1 complete | table baseline, quoted delimiter handling, ragged rows, metadata, smoke baseline | streaming, large-table memory behavior, richer table model |
| TSV | H1 complete | table baseline, ragged rows, metadata, smoke baseline | streaming, large-table memory behavior, richer table model |
| JSON | H1 complete | conservative structured-data baseline, metadata, smoke baseline | unicode escape handling, parser completeness, large nested profiling |
| YAML / YML | H1 complete | conservative structured-data baseline, metadata, smoke baseline | subset definition, anchors, multiline scalars, document separators |
| XML | H1 complete | source-preserving fenced-code baseline, metadata, smoke baseline | safe tokenizer/event model if H2 requires it |
| HTML / HTM | H1 reviewed, baseline strengthened, H2 gaps documented | static HTML baseline, assets/metadata coverage, smoke baseline, H2 review doc | DOM/entity/source-origin improvements, rowspan/colspan, details/table cell semantics |
| XLSX | H1 reviewed, baseline strengthened, H2 gaps documented | multi-sheet baseline, formula/merged/hidden/sparse policy fixed, metadata, smoke baseline | merged ranges model, formula text + cached value, styles/custom numFmt, comments/drawings/charts |
| ZIP | H1 reviewed, container baseline strengthened, H2 gaps documented | safe-entry conversion, fail-closed unsafe paths, asset remap, metadata, smoke baseline | ZIP64, data descriptor, streaming, bomb protection, inventory/debug |
| EPUB | H1 reviewed, ebook package baseline strengthened, H2 gaps documented | container/OPF/spine pipeline, assets/metadata, fail-closed package safety, smoke baseline | nav/TOC, NCX, cover semantics, internal anchors, asset graph, large ebook profiling |
| DOCX | H2 market-parity review completed | market-parity review doc, assets/metadata coverage, smoke baseline, overlap comparison refresh | styles, numbering, footnotes/endnotes, comments, revisions, headers/footers, text boxes, nested tables |
| PPTX | H2 layout-quality review completed | layout-quality review doc, assets/metadata coverage, smoke baseline, overlap comparison refresh | explicit table XML, speaker notes, comments, hidden slides, group shape tree, charts, SmartArt, internal/action links |
| PDF | H2 core-first deep pass completed through P4.4 benchmark/comparison refresh | core-first audit, `pdf_core` model/debug pass, link signal/emission work, heading/noise/merge hardening, smoke/comparison refresh | tables, image caption expansion, richer link provenance/internal Dest, outlines/bookmarks, positive multi-column reading order, larger real-world profiling |

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
* CSV / TSV are stable as conservative table conversion
* JSON / YAML are stable as conservative structured-data conversion
* XML is stable as source-preserving fenced `xml` output

Remaining focus:

* TXT: very large file / batch behavior and encoding fallback policy
* Markdown: frontmatter policy and large passthrough speed
* CSV / TSV: streaming, large-table memory behavior, richer table model
* JSON: unicode escape handling, parser completeness, large nested cases
* YAML: subset definition, anchors, multiline scalars, document separators
* XML: safe tokenizer / event model if H2 requires a richer lower layer

## Web / Spreadsheet / Container / Ebook Group

Formats in this group:

* HTML / HTM
* XLSX
* ZIP
* EPUB

What is completed:

* HTML H1/H2 review is done, with baseline strengthening and a documented gap
  list
* XLSX H1/H2 review is done, with formula / merged / hidden / sparse policies
  fixed by regression and documented
* ZIP H1/H2 container review is done, with fail-closed unsafe-path policy,
  asset remap, metadata, and smoke coverage
* EPUB H1/H2 ebook review is done, with package/spine/assets/metadata/fail
  closed behavior fixed and documented

Remaining focus:

* HTML: stronger DOM/entity/source-origin/table-cell semantics, plus
  rowspan/colspan/details handling
* XLSX: merged-range model, formula text + cached value, richer
  styles/custom-number-format support, comments/drawings/charts
* ZIP: ZIP64, data descriptor, streaming/materialization split, bomb
  protection, inventory/debug surfaces
* EPUB: nav/TOC, NCX, cover semantics, internal anchors, asset graph, large
  ebook profiling

## Office Group

Formats in this group:

* DOCX
* PPTX

What is completed:

* DOCX H2 market-parity review is completed
* DOCX overlap comparison and smoke coverage now show strong selected-case
  speed wins over Microsoft MarkItDown, with semantic differences documented
* PPTX H2 layout-quality review is completed
* PPTX overlap comparison and smoke coverage now show strong selected-case
  speed wins over Microsoft MarkItDown, with layout/semantic gaps documented

Remaining focus:

* DOCX: styles, numbering, footnotes/endnotes, comments, revisions,
  headers/footers, text boxes, nested tables
* PPTX: explicit table XML, speaker notes, comments, hidden slides, group
  shape tree, charts, SmartArt, internal/action links

Important note:

* these review passes do not claim full market parity
* they define the gap surface and lock in current strengths, limits, and
  overlap-only benchmark/comparison baselines

## PDF Group

The PDF path completed a deeper staged pass than the other formats in this
milestone:

* H2 core gap review
* P1 `pdf_core` model/debug signal pass
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
* `pdf_core` has become a visible lower-layer deliverable with inspect/debug
  surfaces
* heading, repeated edge noise, cross-page merge, and URI link emission now
  have explicit evidence/reason surfaces
* text-PDF smoke and overlap comparison baselines are now broad enough to
  represent real H2 progress rather than a single simple sample

Remaining PDF focus:

* tables / weak table detection
* image caption expansion
* richer link provenance / internal Dest handling
* outlines / bookmarks
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
* XML conservative source-preserving baseline, with future tokenizer/event
  model path left explicit
* PDF `pdf_core` page/text/image/annotation/source-ref/debug surface

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
6. EPUB H2: nav/TOC, cover semantics, internal anchors, richer asset graph.
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
