# Format H2/H3 Gap Review

This document reviews the current H2 and H3 upgrade gaps for every supported
format in `markitdown-mb`.

It builds on [docs/format-hardening-roadmap.md](./format-hardening-roadmap.md)
and assumes the same H1 / H2 / H3 ladder.

This is a planning and audit document. It is not the detailed support contract,
and it should not be read as a claim that every listed task is already in
progress.

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
* `pdf_core`
* HTML parsing and image-context extraction
* CSV / TSV table handling
* JSON / YAML / XML structured-text models

Those lower layers should remain independently testable, debuggable, and
reusable even outside Markdown conversion.

## Format Reviews

### DOCX

#### Current status

* supported
* H2 market-parity review documented
* pending H3 performance review

#### Current strengths

* OOXML package plumbing is already in place
* headings, paragraphs, lists, tables, block quotes, code-like paragraphs
* hyperlink handling in key paragraph/list/heading contexts
* image export and metadata sidecar integration
* regression and metadata coverage already exist

#### H2 quality gaps

* style and numbering fidelity still look heuristic rather than parity-grade
* footnotes / endnotes are not yet recovered as reading output
* comment / revision / textbox-heavy documents remain outside current quality
  target
* richer table semantics and cell provenance are still limited
* real-world messy DOCX samples need broader coverage
* run-level formatting, bookmark/internal-link handling, and richer image
  caption semantics still trail mainstream DOCX tools

#### Bottom-layer gaps

* OOXML styles model
* numbering / abstract numbering recovery
* footnote/endnote relationships and content traversal
* richer OOXML drawing/textbox surfaces
* shared OOXML hyperlink/relationship robustness

#### H3 performance gaps

* add small / medium / large / batch DOCX benchmark tiers
* separate text-only vs image-bearing DOCX cases
* expand MarkItDown overlap comparison beyond a single simple case while
  keeping the scope overlap-only
* classify current wins/losses with prebuilt native CLI only

#### Suggested next actions

* add real-world DOCX corpus with styles, numbering, links, and notes
* improve OOXML numbering/style signal before converter-local polishing
* add DOCX footnote/endnote recovery plan
* benchmark text-heavy and image-heavy DOCX separately
* document intentional non-goals for tracked changes / comments if deferred

#### Non-goals for now

* pixel-faithful Word layout reproduction
* full tracked-changes editor semantics
* full comment workflow export

### PPTX

#### Current status

* supported
* H2 layout-quality review documented
* pending H3 performance review

#### Current strengths

* slide-order traversal and reading-order-aware text recovery
* title/body/list separation
* conservative table-like / callout-like / caption-like region handling
* basic run-level and shape-level external hyperlinks
* image export and caption-like metadata surfaces

#### H2 quality gaps

* layout grouping quality still depends heavily on heuristics
* notes-page output is absent
* real PowerPoint table objects are not modeled separately from heuristic
  table-like regions
* complex grouped shapes and dense slide layouts need stronger recovery
* image-caption association still needs more real-world validation
* hyperlink/media coverage is not yet parity-grade

#### Bottom-layer gaps

* slide layout/master/placeholder model
* shape geometry and grouping model
* richer slide object graph
* notes/comments/hidden-slide relationship traversal
* table/drawing/media/action/hyperlink signal

#### H3 performance gaps

* benchmark text-only vs dense-layout PPTX separately
* add batch slide-deck cases
* compare overlap-only PPTX cases against MarkItDown on more than one sample
* profile layout-heavy slides where grouping heuristics dominate runtime

#### Suggested next actions

* add real-world dense and mixed-layout PPTX samples
* model notes-page and richer shape grouping in lower layers
* improve hyperlink/media extraction before more heuristic converter work
* benchmark simple, dense, and image-heavy decks separately
* define explicit non-goals for animation/media semantics

#### Non-goals for now

* animation/timing reproduction
* speaker-view or full slideshow semantics
* pixel-perfect slide layout recreation

### XLSX

#### Current status

* supported
* pending H1 / H2 review
* pending H3 performance review

#### Current strengths

* multi-sheet traversal
* sparse-region trimming
* datetime/time formatting
* sheet-level table output with provenance
* OOXML workbook/package base already exists

#### H2 quality gaps

* merged cells are not reconstructed
* formula policy is still "cached values only"
* comments, drawings, charts, pivots are missing
* richer workbook semantics and sheet layout need review
* real-world spreadsheet samples are still too light

#### Bottom-layer gaps

* workbook / worksheet structural model
* merged-cell region modeling
* formula/cached-value policy abstraction
* comments / drawings / relationships surfaces
* richer cell typing/format signal

#### H3 performance gaps

* add small / medium / large / batch spreadsheet cases
* separate sparse vs dense sheet profiles
* compare overlap-only XLSX cases against MarkItDown on more than one sample
* profile memory and string-formatting costs for larger workbooks

#### Suggested next actions

* add merged-cell and formula-policy audit samples
* strengthen lower-layer worksheet model before converter-specific table polish
* add real-world workbooks with multiple sheets and sparse/dense mixes
* benchmark sparse and dense XLSX separately
* define current non-goals for charts/pivots/comments if deferred

#### Non-goals for now

* Excel formula evaluation engine
* chart or pivot semantic export
* full spreadsheet UI semantics

### PDF

#### Current status

* supported
* PDF H2 core-gap review documented
* pending `pdf_core` P1 signal upgrade pass
* pending converter-side PDF H2 quality pass
* pending H3 performance review

#### Current strengths

* native `pdf_core` substrate already exposes chars / spans / lines / blocks
* page geometry, image extraction, annotation extraction, and source refs exist
* repeated header/footer cleanup and cross-page paragraph merge already exist
* provenance and inspect surfaces are already part of the project
* a dedicated PDF audit now exists in
  [docs/pdf-h2-core-gap-review.md](./pdf-h2-core-gap-review.md)

#### H2 quality gaps

* semantic table recovery is still absent
* annotation/link output is still debug-only rather than emitted Markdown
* complex layouts and multi-column handling remain limited
* image-caption recovery is intentionally narrow
* some document capability surfaces are still placeholders rather than trusted
  lower-layer signals

#### Bottom-layer gaps

* more trustworthy `pdf_core` capability reporting and populated model fields
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

* complete `pdf_core` model/debug cleanup before more heading/noise/merge work
* add PDF samples for annotations/links, outlines, and table-like negatives
* audit link emission policy with lower-layer support first
* expand benchmark coverage to multiple PDF profiles before claiming H3 trend
* keep explicit PDF non-goals in place while the core-first pass is underway

#### Non-goals for now

* OCR-first default behavior
* browser/PDF-viewer visual fidelity
* full vector/graphics semantic reconstruction

### HTML / HTM

#### Current status

* supported
* pending H1 / H2 review
* pending H3 performance review

#### Current strengths

* structural HTML conversion is in place
* headings, paragraphs, lists, block quotes, code blocks, tables
* inline links and local image export
* figure/figcaption/alt/title handling already exists

#### H2 quality gaps

* more real-world HTML with messy DOMs is needed
* semantic block/inline boundaries need broader review
* table edge cases such as rowspan/colspan remain unsupported
* image-context quality needs broader site-style coverage
* browser-grade semantics are intentionally out of scope and should stay explicit

#### Bottom-layer gaps

* stronger DOM / node model
* block/inline boundary signal
* image-context extraction surfaces
* safer local-reference and extracted-asset handling

#### H3 performance gaps

* add small / medium / large / batch HTML cases
* separate simple static pages vs DOM-heavy pages
* compare overlap-only HTML cases against MarkItDown on more than one shape
* profile HTML parsing vs asset handling separately

#### Suggested next actions

* run dedicated HTML H1/H2 review across real pages
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

* H1 complete
* pending H2 review
* pending H3 review

#### Current strengths

* conservative paragraph conversion
* literal-safe Markdown output
* BOM/CRLF handling is stable
* smoke benchmark small / medium / large exists
* overlap-only MarkItDown comparison baseline exists

#### H2 quality gaps

* real-world plain-text corpora still need review
* international text joining behavior may need closer quality audit
* paragraph joining heuristics should be evaluated against mainstream behavior
* empty/odd whitespace edge cases may still need broader coverage

#### Bottom-layer gaps

* text normalization policy
* optional future line-classification helpers, if H2 shows a real need

#### H3 performance gaps

* add batch plain-text benchmark
* compare multiple TXT shapes, not only one overlap case
* profile very large plain-text files

#### Suggested next actions

* run TXT H2 review on real-world text corpora
* audit CJK and mixed-language paragraph joining
* add batch/large-file TXT benchmarks
* compare multiple simple TXT overlap samples against MarkItDown

#### Non-goals for now

* Markdown inference
* heading/list/table semantics for plain TXT
* OCR or language understanding

### Markdown / MD / MARKDOWN

#### Current status

* H1 complete
* pending H2 review
* pending H3 review

#### Current strengths

* source-preserving passthrough path
* BOM/CRLF handling is stable
* metadata summary and benchmark enrollment exist
* overlap-only comparison baseline exists

#### H2 quality gaps

* broader real-world Markdown corpus is needed
* frontmatter and mixed Markdown/HTML handling need review against mainstream
  tools
* extension/variant behavior should be documented more explicitly where it
  intentionally stays conservative

#### Bottom-layer gaps

* lightweight Markdown block slicer / metadata summarizer surfaces
* optional future source model if H2 requires richer provenance without AST
  rewrite

#### H3 performance gaps

* add batch Markdown benchmark
* compare more than one overlap Markdown case
* profile large passthrough files and metadata slicing cost

#### Suggested next actions

* run Markdown H2 review on real-world repositories/docs
* add broader frontmatter/raw-HTML/nontrivial Markdown samples
* benchmark batch and large-file passthrough
* define explicit non-goals for full Markdown semantic normalization

#### Non-goals for now

* full Markdown AST rewrite
* Markdown beautification/reformatting
* semantic normalization across Markdown dialects

### CSV

#### Current status

* H1 complete
* pending H2 review
* pending H3 review

#### Current strengths

* structured table conversion is stable
* quoted delimiter/newline and empty-cell handling are in place
* metadata/origin coverage exists
* smoke benchmark small / medium / large exists
* overlap-only CSV comparison exists

#### H2 quality gaps

* larger real-world CSVs and ragged datasets need review
* header semantics should be compared against mainstream tools more carefully
* multiline-cell readability and escaping behavior need real-world validation

#### Bottom-layer gaps

* delimited parser robustness
* table model for larger/streamed data
* optional streaming path for large files

#### H3 performance gaps

* add batch table benchmarks
* benchmark larger real-world CSVs
* profile parser vs emitter cost on wide/tall tables

#### Suggested next actions

* run CSV H2 review on real-world exported datasets
* add wide-table and very tall-table benchmarks
* evaluate need for streaming parser path
* compare additional CSV overlap cases against MarkItDown

#### Non-goals for now

* schema inference
* type inference beyond current conservative text handling
* spreadsheet-like semantic reconstruction

### TSV

#### Current status

* H1 complete
* pending H2 review
* pending H3 review

#### Current strengths

* stable tab-delimited table conversion
* metadata/origin coverage exists
* smoke benchmark small / medium / large exists

#### H2 quality gaps

* broader real-world TSV coverage is still needed
* multiline/escaping conventions need validation against actual TSV producers
* parity expectations should be separated from CSV where behavior differs

#### Bottom-layer gaps

* shared delimited parser quality
* possible large-table streaming path
* table model scalability

#### H3 performance gaps

* add batch TSV benchmarks
* benchmark wide and tall TSV datasets
* currently not a checked-in MarkItDown overlap format; clarify whether that is
  practical or not

#### Suggested next actions

* run TSV H2 review on real exported corpora
* benchmark large/wide TSV separately from CSV
* evaluate overlap-comparison practicality with mainstream tools
* review shared delimited parser scalability

#### Non-goals for now

* delimiter sniffing
* schema inference
* spreadsheet semantics

### JSON

#### Current status

* H1 complete
* pending H2 review
* pending H3 review

#### Current strengths

* stable conservative object/list/table/code-block mapping
* metadata coverage and smoke benchmarks already exist
* mixed/nested fallback behavior is explicit

#### H2 quality gaps

* unicode-escape behavior remains conservative and may need parity review
* real-world nested JSON needs broader coverage
* array-of-objects table decisions should be compared against mainstream tools
* malformed and irregular payload behavior should be reviewed against product
  expectations

#### Bottom-layer gaps

* parser completeness
* unicode decoding policy
* richer nested JSON model if H2 proves current fallback too weak

#### H3 performance gaps

* add batch JSON benchmarks
* benchmark larger nested and array-of-objects cases
* currently no checked-in overlap comparison; assess whether mainstream tools
  provide meaningful comparison cases

#### Suggested next actions

* run JSON H2 review on real API/config samples
* decide whether unicode escape decoding belongs in parser/core
* benchmark nested vs table-friendly JSON separately
* evaluate overlap-comparison practicality and corpus shape

#### Non-goals for now

* schema inference
* JSON Schema validation
* business-semantic guessing

### YAML / YML

#### Current status

* H1 complete
* pending H2 review
* pending H3 review

#### Current strengths

* conservative simple-subset parser with fail-closed boundaries
* stable mapping/list/table/code-block downgrade behavior
* metadata and smoke benchmark coverage exists

#### H2 quality gaps

* current subset needs clearer real-world validation
* comments are intentionally ignored; that tradeoff needs parity review
* anchors, multiline scalars, flow style, and multi-document handling are still
  outside current quality surface

#### Bottom-layer gaps

* YAML subset parser definition
* safer tokenizer/line model
* optional future anchor/multiline/document-separator support

#### H3 performance gaps

* add batch YAML benchmarks
* benchmark larger subset-valid configuration files
* currently no checked-in overlap comparison; assess practicality

#### Suggested next actions

* define the supported YAML subset more crisply
* run H2 review on real config files within that subset
* evaluate whether anchors/multiline support belongs in bottom-layer upgrades
* benchmark larger config-style YAMLs

#### Non-goals for now

* full YAML spec coverage
* schema or business-semantic inference
* silent partial parsing of unsupported constructs

### XML

#### Current status

* H1 complete
* pending H2 review
* pending H3 review

#### Current strengths

* source-preserving baseline is stable
* BOM/CRLF/empty-file/backtick fence behavior is covered
* metadata/origin coverage and smoke benchmarks exist
* explicit safe boundaries are already documented

#### H2 quality gaps

* current path is literal preservation only
* if future user value needs more than fenced source, the project will need a
  safe token/event model first
* real-world XML families need clearer distinction from generic XML handling

#### Bottom-layer gaps

* safe tokenizer / event model
* namespace-neutral source model
* optional future DOM/event surfaces that still avoid unsafe entity behavior

#### H3 performance gaps

* add batch XML benchmarks
* benchmark larger source-preservation cases on real corpora
* current MarkItDown overlap is only runner-level and not shape-equivalent, so
  comparison should be documented as not fully comparable for now

#### Suggested next actions

* keep XML H2 focused on safe generic XML, not XHTML/RSS/OPF/SVG semantics
* design a safe tokenizer/event model if H2 requires richer behavior
* benchmark batch and large-file XML preservation
* document comparability limits against MarkItDown more explicitly if needed

#### Non-goals for now

* XHTML/OPF/RSS/SVG semantic conversion
* external entity expansion
* schema or DTD validation

### ZIP

#### Current status

* supported
* H1 / H2 container review in progress
* pending H3 performance review

#### Current strengths

* safe entry traversal and normalization
* supported-entry dispatch already works
* archive asset namespace/remap is implemented
* HTML local-image handling within ZIP is already in place

#### H2 quality gaps

* container behavior needs broader robustness review
* nested-archive policy and mixed-entry behavior need clearer boundaries
* warning/unsupported-entry downgrade quality should be checked on real-world
  archives

#### Bottom-layer gaps

* ZIP container safety model
* entry policy abstraction
* extracted-tree and namespace/remap robustness
* optional future archive inventory/debug model

#### H3 performance gaps

* add ZIP container benchmarks
* benchmark archives with many supported entries
* benchmark asset-heavy archives separately
* no direct MarkItDown overlap claim unless the archive behavior is truly
  comparable

#### Suggested next actions

* run dedicated ZIP H1/H2 container audit
* add mixed-entry and large-archive corpora
* review nested-archive and unsupported-entry policy
* benchmark container overhead separately from nested entry conversion

#### Non-goals for now

* recursive nested archive extraction by default
* generic archive browsing product semantics
* unsafe path or external-reference handling

### EPUB

#### Current status

* supported
* H1 complete, pending H2 / H3 ebook review
* pending H3 performance review

#### Current strengths

* `container.xml` -> OPF -> manifest/spine pipeline already exists
* spine-order aggregation is in place
* same-archive local-image handling already works
* EPUB metadata/document-properties support exists

#### H2 quality gaps

* nav/TOC semantic reconstruction is still pending
* richer XHTML spine semantics need review
* CSS-informed readability remains intentionally limited
* real-world ebooks with more packaging variation need broader coverage

#### Bottom-layer gaps

* OPF/nav model
* EPUB package and spine abstraction
* stronger XHTML/asset remap surfaces
* optional ebook-specific metadata/navigation model

#### H3 performance gaps

* add EPUB small / medium / large / batch cases
* benchmark many-spine-item books separately
* likely not directly comparable to MarkItDown at a clean runner level today,
  so document non-comparability if retained

#### Suggested next actions

* run dedicated EPUB H1/H2 ebook audit
* add nav/TOC and multi-spine real-world samples
* review XHTML/asset semantics within EPUB separately from generic XML
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

14. PDF with `pdf_core` upgrades first

Notes:

* this order does not mean PDF is unimportant; it means PDF H2 depends heavily
  on deeper `pdf_core` page/object/text modeling and benefits from a later,
  concentrated deep pass
* ZIP and EPUB should be treated as container/ebook formats, not ordinary text
  formats
* DOCX / PPTX / XLSX share OOXML package/model work that is itself a deliverable
* `pdf_core` is one of the core project deliverables, not a converter-only
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
7. Deepen `pdf_core` page object, text geometry, annotation, and image surfaces.
8. Add batch and real-world benchmark tiers across all H1-complete simple
   formats.
9. Evaluate CSV/TSV large-table scalability and possible streaming path.
10. Define safer richer structured-text lower layers for JSON/YAML/XML where H2
    shows current fallback behavior is too limiting.
