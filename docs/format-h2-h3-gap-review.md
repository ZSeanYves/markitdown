# Format H2/H3 Gap Review

This document reviews the current post-H2 and H3 upgrade gaps for every
supported format in `markitdown-mb`.

It is now a next-stage planning document, not a record of which formats are
still waiting to reach H2. The detailed support contract remains
[docs/support-and-limits.md](./support-and-limits.md).

## H1 / H2 / H3 Reference

### H1: Hardened baseline

* regression samples
* metadata / origin / assets behavior fixed
* support-and-limits documented
* smoke benchmark corpus
* MarkItDown overlap comparison if available
* conservative fail-closed / fallback behavior

### H2: Market-parity quality pass

* compare output quality against mainstream tools
* add real-world samples
* cover complex edge cases
* preserve structures mainstream tools preserve where feasible
* if current bottom parser lacks information, improve parser/core first
* document intentional non-goals

### H3: Performance leadership pass

* prebuilt native CLI benchmark
* small / medium / large / batch cases
* compare against Microsoft MarkItDown or other mainstream tools
* classify win / close / loss
* profile losses
* optimize parser / emitter / metadata / assets as needed
* eventually add lightweight performance regression warning

## Bottom-layer Delivery Principle

`convert/*` is only one consumer layer. The reusable parsing and model layers
are part of the project deliverable:

* `doc_parse/*`
* format-specific parser packages
* shared core/IR and emitter-adjacent model surfaces

If H2 quality does not improve because the converter lacks source signal, the
first question should be whether the lower layer is too weak. The project should
prefer stronger parser/core models over piling large amounts of converter-local
regex or post-hoc patching.

This principle applies across:

* OOXML package/model work for DOCX / PPTX / XLSX
* ZIP container handling
* `doc_parse/pdf`
* HTML parsing and image-context extraction
* CSV / TSV table handling
* JSON / YAML / XML structured-text models

Those lower layers should remain independently testable, debuggable, and
reusable even outside Markdown conversion.

## Format Reviews

### DOCX

#### Current status

* H2 complete
* pending H3 performance review

#### Current strengths

* OOXML package plumbing is already in place
* headings, paragraphs, lists, tables, block quotes, code-like paragraphs
* hyperlink handling in key paragraph/list/heading contexts
* image export and metadata sidecar integration
* regression and metadata coverage already exist
* explicit `RichTable` DOCX table metadata is now in place
* style-linked numbering fallback and stronger ordered-list degradation are now
  in place

#### Documented limitations / future quality work

* style and numbering fidelity improved, but still look heuristic rather than
  parity-grade
* run-level formatting, bookmark/internal-link handling, and richer image
  caption semantics still trail mainstream DOCX tools
* richer anchored semantics for comments and near-anchor textbox placement are
  still missing
* merged/nested/cell-provenance behavior is still limited even though visible
  content preservation is now stronger
* real-world messy DOCX samples still need broader coverage

#### Bottom-layer / future parser-model work

* richer OOXML styles model
* deeper numbering / abstract numbering recovery
* richer OOXML drawing/textbox surfaces beyond current `w:txbxContent` recovery
* shared OOXML hyperlink/relationship robustness

#### H3 performance gaps

* add small / medium / large / batch DOCX benchmark tiers
* separate text-only vs image-bearing DOCX cases
* expand MarkItDown overlap comparison beyond a single simple case while
  keeping the scope overlap-only
* classify current wins/losses with prebuilt native CLI only

#### Closure decision

DOCX is now **H2 complete** after the closure audit:

* accepted-view-like revision handling now preserves inserted/moved-to visible
  text while skipping deleted/moved-from markup
* footnotes/endnotes/comments, headers/footers, and text boxes all have stable
  conservative recovery paths
* merged/nested tables remain imperfect, but current behavior preserves visible
  content without claiming Word layout reconstruction
* remaining gaps are documented limitations and future quality work, not
  outstanding H2 completion work

#### Suggested next actions

* add real-world DOCX corpus with styles, numbering, links, and notes
* continue OOXML numbering/style signal beyond current style-linked fallback
* benchmark text-heavy and image-heavy DOCX separately
* document intentional non-goals for richer inline styling / review UI in
  user-facing docs as needed

#### Non-goals for now

* pixel-faithful Word layout reproduction
* full tracked-changes editor semantics
* full threaded comment workflow export

### PPTX

#### Current status

* H2 complete
* pending H3 performance review

#### Current strengths

* slide-order traversal and reading-order-aware text recovery
* title/body/list separation
* explicit table-object lowering plus conservative table-like / callout-like /
  caption-like region handling
* basic run-level and shape-level external hyperlinks
* image export and caption-like metadata surfaces
* speaker notes extraction with conservative placeholder filtering
* content-preserving hidden-slide annotation
* explicit `p:grpSp` traversal with grouped text/image/table recovery

#### Documented limitations / future quality work

* image-caption association still needs more real-world validation
* hyperlink/media coverage is not yet parity-grade
* comments remain absent
* merged visual table reconstruction remains conservative

#### Bottom-layer / future parser-model work

* slide layout/master/placeholder model
* richer shape geometry / grouped-layout model
* richer slide object graph
* comments/action-link traversal
* charts / SmartArt / OLE object signal

#### H3 performance gaps

* benchmark text-only vs dense-layout PPTX separately
* add batch slide-deck cases
* compare overlap-only PPTX cases against MarkItDown on more than one sample
* profile layout-heavy slides where grouping heuristics dominate runtime

#### Suggested next actions

* add more real-world dense and mixed-layout PPTX samples
* improve hyperlink/media extraction before broader converter work
* benchmark simple, dense, and image-heavy decks separately
* define explicit non-goals for animation/media semantics

#### Non-goals for now

* animation/timing reproduction
* speaker-view or full slideshow semantics
* pixel-perfect slide layout recreation

### XLSX

#### Current status

* H2 lower-layer upgrade completed, H2 complete
* pending H3 performance review

#### Current strengths

* multi-sheet traversal
* sparse-region trimming
* datetime/time formatting
* sheet-level `RichTable` output with provenance
* workbook/sheet inspect surface with hidden-state and merged-range capture
* formula cached-value policy with preserved lower-layer formula text
* OOXML workbook/package base already exists
#### Documented limitations / future quality work

* comments, drawings, charts, pivots are missing
* real-world spreadsheet samples are still too light

#### Bottom-layer / future parser-model work

* comments / drawings / relationships surfaces
* richer cell typing/format signal

#### H3 performance gaps

* add small / medium / large / batch spreadsheet cases
* separate sparse vs dense sheet profiles
* compare overlap-only XLSX cases against MarkItDown on more than one sample
* profile memory and string-formatting costs for larger workbooks

#### Suggested next actions

* add real-world workbooks with multiple sheets and sparse/dense mixes
* benchmark sparse and dense XLSX separately
* define current non-goals for charts/pivots/comments if deferred

#### Non-goals for now

* Excel formula evaluation engine
* chart or pivot semantic export
* full spreadsheet UI semantics

### PDF

#### Current status

* H2 core-first deep pass completed through P4.4 benchmark/comparison refresh
* H2 closure re-audit completed, H2 complete
* pending H3 performance review

#### Current strengths

* native `doc_parse/pdf` substrate already exposes chars / spans / lines / blocks
* page geometry, image extraction, annotation extraction, and source refs exist
* repeated header/footer cleanup and cross-page paragraph merge already exist
* provenance and inspect surfaces are already part of the project
* a dedicated PDF audit now exists in
  [docs/pdf-h2-core-gap-review.md](./pdf-h2-core-gap-review.md)

#### H2 completed work

* native `doc_parse/pdf` page/text/image/annotation/source-ref surface is wired into
  the main converter path
* heading, repeated edge-noise, page-number, and cross-page merge hardening are
  covered by checked-in regression corpus
* annotation/link output is conservative but stable for high-confidence safe
  URI cases
* simple high-confidence table recovery now exists, including headerless
  numeric tables with `header_rows = 0`
* same-page high-confidence image caption association now exists with
  ambiguity/body/noise/table guards
* conservative numeric page-number scoping now preserves middle-body numeric
  table cells without weakening edge/trailing page-number cleanup

#### H2 documented limitations

* complex layouts and positive multi-column recovery remain limited
* outlines / bookmarks are not yet emitted
* internal Dest / GoTo emission remains out of the current converter policy
* image-caption recovery stays intentionally narrow and same-page only
* complex / multi-page / rotated / merged PDF table reconstruction is out of
  scope for the current H2 bar

#### Bottom-layer gaps

* more trustworthy `doc_parse/pdf` capability reporting and populated model fields
* stronger page-edge / artifact / reading-order candidate signal
* annotation/link/outlines surfaces usable by converter
* richer provenance/debug surfaces for text/image/annotation decisions
* clearer separation between core signal loss and converter-policy loss

#### H3 performance gaps

* benchmark simple / medium / large / batch PDFs
* separate text-only, image-heavy, multi-page, noisy, and table-like PDFs
* add core-only extraction timing in addition to full native conversion timing
* compare overlap-only PDF cases against MarkItDown on multiple profiles

#### Suggested next actions

* add PDF samples for outlines/bookmarks and richer internal-link behaviors if
  product demand appears
* expand broader image-caption and table corpora only if future H2.1 quality
  work is desired, without widening current conservative guards
* expand benchmark coverage to larger and more diverse text-PDF profiles before claiming H3 trend
* keep explicit PDF non-goals in place while deeper layout semantics remain out of scope

#### Non-goals for now

* OCR-first default behavior
* browser/PDF-viewer visual fidelity
* full vector/graphics semantic reconstruction

### HTML / HTM

#### Current status

* H2 lower-layer upgrade completed
* H2 complete
* pending H3 performance review

#### Current strengths

* structural HTML conversion is in place
* headings, paragraphs, lists, block quotes, code blocks, tables
* inline links and local image export
* figure/figcaption/alt/title handling already exists
* common/numeric entity handling is now explicit and stable
* table semantics now carry explicit `RichTable` / `header_rows` metadata
* details/summary and script/style/head/noscript policy are explicit

#### H2 quality outcome

* more real-world HTML with messy DOMs is needed
* table edge cases such as rowspan/colspan remain unsupported
* image-context quality needs broader site-style coverage
* browser-grade semantics are intentionally out of scope and should stay explicit

#### Bottom-layer gaps

* optional richer DOM-path/source-span signal
* optional stronger malformed-HTML recovery if future samples justify it
* broader image-context extraction surfaces on messier real-world pages

#### H3 performance gaps

* add small / medium / large / batch HTML cases
* separate simple static pages vs DOM-heavy pages
* compare overlap-only HTML cases against MarkItDown on more than one shape
* profile HTML parsing vs asset handling separately

#### Suggested next actions

* expand samples for nested block/inline and difficult tables
* review local-image and figure semantics on messy HTML
* benchmark static/simple vs DOM-heavy HTML separately
* keep browser/CSS non-goals explicit

#### Non-goals for now

* CSS layout execution
* JavaScript execution
* remote browsing or rendering engine behavior

### TXT

#### Current status

* H2 complete
* next-stage work is H3 performance and selective H2.1 quality

#### Current strengths

* conservative paragraph conversion
* literal-safe Markdown output
* BOM/CRLF handling is stable
* smoke benchmark small / medium / large exists
* overlap-only MarkItDown comparison baseline exists

#### H2 quality notes

* conservative paragraph conversion and literal-safe markdown output are stable
* UTF-8-only fail-closed policy is explicit and acceptable for current H2 scope
* empty/CR-only/thematic-break-like edge cases are covered conservatively
* broader corpus expansion may still be useful, but no longer blocks H2

#### Bottom-layer gaps

* text normalization policy
* optional future line-classification helpers, if H2 shows a real need

#### H3 performance gaps

* add batch plain-text benchmark
* compare multiple TXT shapes, not only one overlap case
* profile very large plain-text files

#### Suggested next actions

* add batch/large-file TXT benchmarks
* revisit line-joining policy only if a concrete real-world quality issue appears
* keep semantic inference out of TXT unless product goals change

#### Non-goals for now

* Markdown inference
* heading/list/table semantics for plain TXT
* OCR or language understanding

### Markdown / MD / MARKDOWN

#### Current status

* H2 complete
* next-stage work is H3 performance and selective H2.1 quality

#### Current strengths

* source-preserving passthrough path
* BOM/CRLF handling is stable
* metadata summary and benchmark enrollment exist
* overlap-only comparison baseline exists

#### H2 quality notes

* passthrough fidelity, normalization, and frontmatter policy are now explicit
* conservative block slicing remains metadata-oriented, not semantic Markdown
  rewriting
* broader real-world corpus expansion is still useful, but no longer blocks H2

#### Bottom-layer gaps

* lightweight Markdown block slicer / metadata summarizer surfaces
* optional future source model if H2 requires richer provenance without AST
  rewrite

#### H3 performance gaps

* add batch Markdown benchmark
* compare more than one overlap Markdown case
* profile large passthrough files and metadata slicing cost

#### Suggested next actions

* benchmark batch and large-file passthrough
* expand real-world corpus only if a concrete fidelity gap appears
* keep non-goals explicit around AST rewrite / beautification

#### Non-goals for now

* full Markdown AST rewrite
* Markdown beautification/reformatting
* semantic normalization across Markdown dialects

### CSV

#### Current status

* H2 complete
* next-stage work is H3 performance and corpus expansion

#### Current strengths

* structured table conversion is stable
* quoted delimiter/newline and empty-cell handling are in place
* metadata/origin coverage exists
* smoke benchmark small / medium / large exists
* overlap-only CSV comparison exists
* explicit `RichTable` header semantics and sparse table metadata are now in
  place

#### H2 quality outcome

* conservative RFC-4180-ish parsing is in place for supported cases
* ragged rows, trailing empty cells, quoted delimiters, and quoted newlines are
  stable
* metadata now carries explicit table rows/header metadata without changing
  Markdown output
* malformed unterminated quoted fields fail closed
* additional real-world corpora are still useful, but no longer block H2

#### Bottom-layer gaps

* optional streaming/materialization split for very large delimited files
* optional streaming path for large files

#### H3 performance gaps

* add batch table benchmarks
* benchmark larger real-world CSVs
* profile parser vs emitter cost on wide/tall tables

#### Suggested next actions

* add wide-table and very tall-table benchmarks
* evaluate need for streaming parser path
* compare additional CSV overlap cases against MarkItDown

#### Non-goals for now

* schema inference
* type inference beyond current conservative text handling
* spreadsheet-like semantic reconstruction

### TSV

#### Current status

* H2 complete
* next-stage work is H3 performance and corpus expansion

#### Current strengths

* stable tab-delimited table conversion
* metadata/origin coverage exists
* smoke benchmark small / medium / large exists
* explicit `RichTable` header semantics and sparse table metadata are now in
  place

#### H2 quality outcome

* stable tab-delimited parsing is in place through the shared delimited parser
* trailing empty cells, ragged rows, quoted tabs, and pipe-safe Markdown cells
  are stable
* metadata now carries explicit table rows/header metadata without changing
  Markdown output
* TSV overlap-comparison practicality remains separate from H2 completeness

#### Bottom-layer gaps

* possible large-table streaming path
* large-table memory behavior

#### H3 performance gaps

* add batch TSV benchmarks
* benchmark wide and tall TSV datasets
* currently not a checked-in MarkItDown overlap format; clarify whether that is
  practical or not

#### Suggested next actions

* benchmark large/wide TSV separately from CSV
* evaluate overlap-comparison practicality with mainstream tools
* review shared delimited parser scalability

#### Non-goals for now

* delimiter sniffing
* schema inference
* spreadsheet semantics

### JSON

#### Current status

* H2 complete
* next-stage work is H3 performance and corpus expansion

#### Current strengths

* stable conservative object/list/table/code-block mapping
* metadata coverage and smoke benchmarks already exist
* mixed/nested fallback behavior is explicit
* explicit `RichTable` metadata semantics are already in place
* unicode escape decoding and strict number grammar are now in place

#### H2 quality outcome

* valid `\uXXXX` escapes now decode to Unicode text, including surrogate pairs
* malformed unicode, bad numbers, trailing commas, and raw control characters
  fail closed
* scalar roots, scalar arrays, object roots, and uniform object arrays lower
  deterministically
* stable-key object arrays keep RichTable semantics even when later object key
  order differs
* nested values are preserved as compact JSON strings instead of being
  misleadingly flattened

#### Bottom-layer gaps

* streaming/materialization split for very large JSON payloads
* richer nested JSON model only if a concrete product need appears

#### H3 performance gaps

* add batch JSON benchmarks
* benchmark larger nested and array-of-objects cases
* currently no checked-in overlap comparison; assess whether mainstream tools
  provide meaningful comparison cases

#### Suggested next actions

* benchmark nested vs table-friendly JSON separately
* evaluate overlap-comparison practicality and corpus shape

#### Non-goals for now

* schema inference
* JSON Lines
* JSON Schema validation
* business-semantic guessing
* arbitrary nested flattening

### YAML / YML

#### Current status

* H2 complete
* next-stage work is H3 performance and corpus expansion

#### Current strengths

* conservative simple-subset parser with fail-closed boundaries
* stable mapping/list/table/code-block downgrade behavior
* metadata and smoke benchmark coverage exists
* explicit `RichTable` metadata semantics are already in place
* unsupported feature boundaries are already narrow and testable

#### H2 quality outcome

* supported subset is now explicit rather than implicit
* comment/blank-line/simple-mapping/scalar-sequence/sequence-of-mappings
  behavior is stable
* anchors, aliases, tags, document separators, block scalars, flow style, and
  inconsistent indentation fail closed
* stable-key sequence-of-mappings now keep table semantics even when later
  mapping key order differs
* nested values are preserved conservatively instead of being flattened

#### Bottom-layer gaps

* optional future richer tokenizer/model if a larger safe subset becomes
  necessary
* optional future anchor/multiline/document-separator support if explicitly
  scoped

#### H3 performance gaps

* add batch YAML benchmarks
* benchmark larger subset-valid configuration files
* currently no checked-in overlap comparison; assess practicality

#### Suggested next actions

* run broader real-world config review within the supported subset
* evaluate whether anchors/multiline support belongs in bottom-layer upgrades
* benchmark larger config-style YAMLs

#### Non-goals for now

* full YAML spec coverage
* schema or business-semantic inference
* silent partial parsing of unsupported constructs

### XML

#### Current status

* H2 complete
* next-stage work is H3 performance and future XML-family specialization

#### Current strengths

* source-preserving baseline is stable
* BOM/CRLF/empty-file/backtick fence behavior is covered
* metadata/origin coverage and smoke benchmarks exist
* safe tokenizer / event surface now exists for declarations, processing
  instructions, tags, comments, CDATA, doctype, text, and literal entity refs
* explicit safe boundaries are already documented

#### H2 quality gaps

* generic XML remains intentionally source-preserving rather than semantic
* real-world XML families still need clearer distinction from generic XML
  handling

#### Bottom-layer gaps

* optional richer namespace-neutral source model on top of the tokenizer
* optional future DOM/event surfaces that still avoid unsafe entity behavior

#### H3 performance gaps

* add batch XML benchmarks
* benchmark larger source-preservation cases on real corpora
* current MarkItDown overlap is only runner-level and not shape-equivalent, so
  comparison should be documented as not fully comparable for now

#### Suggested next actions

* keep XML H2 focused on safe generic XML, not XHTML/RSS/OPF/SVG semantics
* reuse the tokenizer/event surface for future XHTML/RSS/OPF/SVG-local work
* benchmark batch and large-file XML preservation
* document comparability limits against MarkItDown more explicitly if needed

#### Non-goals for now

* XHTML/OPF/RSS/SVG semantic conversion
* external entity expansion
* schema or DTD validation

### ZIP

#### Current status

* H2 complete
* next-stage work is H3 performance and deeper container features

#### Current strengths

* safe entry traversal and normalization
* supported-entry dispatch already works
* archive asset namespace/remap is implemented
* HTML local-image handling within ZIP is already in place
* reusable inspect/inventory surface is now in place

#### H2 completed work

* container safety model is explicitly documented and testable
* entry policy abstraction now exists through inspect/inventory
* extracted-tree and namespace/remap behavior remain covered and documented
* normalized collision, unsafe path, and warning-level action boundaries are
  explicitly surfaced

#### H3 performance gaps

* add ZIP container benchmarks
* benchmark archives with many supported entries
* benchmark asset-heavy archives separately
* no direct MarkItDown overlap claim unless the archive behavior is truly
  comparable

#### Suggested next actions

* add mixed-entry and large-archive corpora
* benchmark container overhead separately from nested entry conversion
* scope any future ZIP64 / data-descriptor / streaming work explicitly

#### Non-goals for now

* recursive nested archive extraction by default
* generic archive browsing product semantics
* unsafe path or external-reference handling

### EPUB

#### Current status

* H2 complete
* next-stage work is H3 performance and broader ebook semantics

#### Current strengths

* `container.xml` -> OPF -> manifest/spine pipeline already exists
* spine-order aggregation is in place
* same-archive local-image handling already works
* EPUB metadata/document-properties support exists

#### H2 completed work

* EPUB3 nav detection and conservative TOC emission are in place
* cover-image detection and conservative top-of-document cover emission are in
  place
* richer OPF metadata and inspect/debug surface are in place
* EPUB package and spine abstraction are stronger and explicitly testable

#### H3 performance gaps

* add EPUB small / medium / large / batch cases
* benchmark many-spine-item books separately
* likely not directly comparable to MarkItDown at a clean runner level today,
  so document non-comparability if retained

#### Suggested next actions

* review XHTML/asset semantics within EPUB separately from generic XML
* decide whether NCX should stay future or get a minimal extractor
* benchmark short vs long-spine EPUBs

#### Non-goals for now

* browser-grade CSS rendering
* DRM handling
* ebook-reader UI semantics

## Recommended Upgrade Order

### Phase A: H2 review for simple/text/structured data

1. TXT
2. Markdown / MD / MARKDOWN
3. CSV
4. TSV
5. JSON
6. YAML / YML
7. XML

### Phase B: Web/table/container formats

8. HTML / HTM
9. XLSX
10. ZIP
11. EPUB

### Phase C: Complex Office formats

12. DOCX
13. PPTX

### Phase D: PDF deep pass

14. PDF with `doc_parse/pdf` upgrades first

Notes:

* this order does not mean PDF is unimportant; it means PDF H2 depends heavily
  on deeper `doc_parse/pdf` page/object/text modeling and benefits from a later,
  concentrated deep pass
* ZIP and EPUB should be treated as container/ebook formats, not ordinary text
  formats
* DOCX / PPTX / XLSX share OOXML package/model work that is itself a deliverable
* `doc_parse/pdf` is one of the core project deliverables, not a converter-only
  implementation detail

## Top Priority List

1. Run HTML H1/H2 review on real-world pages and tables.
2. Strengthen XLSX workbook/worksheet modeling for merged cells and formula
   policy.
3. Run ZIP H1/H2 container robustness audit with mixed-entry archives.
4. Run EPUB H1/H2 ebook audit with nav/TOC and multi-spine real-world books.
5. Improve OOXML lower-layer support for DOCX footnotes, numbering, and styles.
6. Improve PPTX lower-layer shape/grouping/notes/link signal before more
   converter heuristics.
7. Deepen `doc_parse/pdf` page object, text geometry, annotation, and image surfaces.
8. Add batch and real-world benchmark tiers across all H1-complete simple
   formats.
9. Evaluate CSV/TSV large-table scalability and possible streaming path.
10. Define safer richer structured-text lower layers for JSON/YAML/XML where H2
    shows current fallback behavior is too limiting.
