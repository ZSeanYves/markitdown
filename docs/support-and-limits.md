# Support Scope And Known Limits

This is the repository’s detailed support contract. When README, progress, and
support text differ, this document should be treated as the detailed source of
truth for format behavior and limits.

## Project Scope

Current product positioning:

* Markdown is the primary reading output
* `assets/` and metadata sidecars are engineering companion outputs
* the default goal is conservative, explainable recovery rather than visual
  reproduction
* unsupported or ambiguous features should degrade predictably or fail closed

Current non-goals for the default mainflow:

* remote fetch
* browser-grade rendering
* DRM handling
* nested archive recursion
* OCR-first default conversion
* LLM-style or visual-semantic reconstruction

## Supported Input Extensions

Current supported extension families:

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
* ZIP
* EPUB
* TXT
* XML

Inputs outside this set are rejected by the dispatcher.

## Shared Behavioral Rules

Across the current implementation:

* document-style converters prefer conservative partial recovery over
  speculative reconstruction
* structured-text converters either preserve source form or fail closed on
  invalid syntax instead of guessing
* origin metadata is best-effort provenance, not a full anchoring system
* metadata schema stays additive and sparse
* asset export only happens for formats that materially emit image files

## Per-format Support

### DOCX

Supported:

* headings
* ordered / unordered / nested lists
* tables
* block quotes
* code-like paragraphs
* hyperlinks in paragraph / heading / list contexts
* exported images through unified `ImageBlock`

Conservative behavior:

* style-driven recovery remains heuristic rather than style-taxonomy complete
* image title/alt comes from source-native OOXML drawing fields
* OOXML document properties are surfaced in the explicit `--with-metadata`
  sidecar path

Known limits:

* no run-level bold / italic / code-span preservation yet
* no internal bookmark / anchor hyperlink promotion
* no footnote/endnote hyperlink recovery
* no comments / revisions / textbox-special semantics
* no table cell provenance or rich cell model

### PPTX

Supported:

* slide-order traversal
* reading-order-aware text recovery
* title/body/list separation
* placeholder- and geometry-aware reading-order heuristics
* table-like / callout-like / caption-like region handling
* run-level and basic shape-level external hyperlink recovery
* exported images through unified `ImageBlock`
* OOXML document properties in the explicit `--with-metadata` sidecar path

Conservative behavior:

* each slide gets a synthetic slide-boundary heading in workbook order
* current "table" recovery is heuristic layout grouping, not explicit PowerPoint
  table-object lowering
* image caption attachment stays conservative
* layout heuristics favor readable downgrade over aggressive reconstruction

Known limits:

* no notes-page output
* no comments or hidden-slide annotation policy
* no advanced multi-image caption pairing
* no semantic table IR for heuristic table-like regions
* no internal/action/media hyperlink promotion
* no chart / SmartArt / OLE / embedded-media semantics

### XLSX

Supported:

* multi-sheet output
* sheet headings plus tables
* sparse-region trimming
* datetime/time formatting
* source row/column provenance

Conservative behavior:

* tables remain legacy `Table` output
* cached values are used; formulas are not evaluated
* hidden sheets are currently emitted in workbook order
* merged ranges currently preserve only the top-left visible value

Known limits:

* no merged-cell reconstruction
* no formula policy beyond current cached-value path
* no hidden-sheet filtering or annotation policy yet
* no charts / pivots / comments / image export

### PDF

Supported:

* native text-oriented structural recovery
* headings / paragraphs / list-like text recovery
* repeated-header/footer cleanup
* cross-page paragraph merge
* exported images
* lightweight page/image provenance
* PDF debug pipeline and inspect surfaces

Conservative behavior:

* structure is text-first, not visual-layout faithful
* image caption attachment is limited to conservative single-image cases
* PDF annotation links only emit for a narrow, high-confidence URI subset; all
  other annotation/link cases remain conservative and debug-visible

Known limits:

* no internal-destination / GoTo link emission
* no multiline or ambiguous PDF link emission
* no semantic table recovery
* no OCR-first default path
* no full complex-layout or advanced multi-column reconstruction

### HTML / HTM

Supported:

* headings, paragraphs, lists, block quotes, code blocks, tables
* inline hyperlinks
* local image export
* figure / figcaption / alt / title handling
* UTF-8 BOM removal
* CRLF / CR normalization

Conservative behavior:

* recovery is lightweight semantic HTML parsing, not browser rendering
* local images are only exported for accepted local paths
* unsupported remote/data-URI images degrade conservatively instead of fetching
* comments / doctype are ignored
* semantic wrappers such as `main` / `section` / `header` / `footer` preserve
  child content conservatively

Known limits:

* no CSS / JS execution
* no remote fetch
* no DOM-path metadata
* no rowspan / colspan reconstruction
* HTML named-entity decoding is intentionally partial in the current H1 path
* no specialized `details` / `summary` semantic reconstruction

### CSV / TSV

Supported:

* delimiter-based table conversion
* `.csv` comma / `.tsv` tab routing
* quoted fields and escaped quotes
* empty-cell preservation
* quoted-newline cell preservation via current Markdown-table `<br>` emission
* Markdown-pipe-safe table cell emission
* UTF-8 BOM removal
* CRLF / CR normalization
* ragged-row normalization
* blank-line skipping inside delimited inputs
* explicit table metadata with `rows` and `header_rows`
* physical line-range provenance

Conservative behavior:

* output is a single table, not schema-aware typing
* current Markdown table emission treats the first row as the header row
* malformed unterminated quoted fields fail closed instead of guessing

Known limits:

* no streaming
* no dialect sniffing
* no delimiter auto-detection beyond file extension
* no schema inference
* no formula/date/type inference

### JSON

Supported:

* object -> table
* scalar array -> list
* regular object array -> table
* empty array -> fenced code block
* empty object -> empty key/value table
* mixed / nested fallback -> code block
* UTF-8 BOM removal
* CRLF / CR normalization

Conservative behavior:

* object tables use explicit header semantics only where structure is obvious
* regular object arrays only become tables when all rows share the same key set

Known limits:

* no JSON Schema
* no JSON Lines
* no streaming parser path
* unicode escapes are preserved in decoded string values as conservative text
* no nested provenance beyond root `key_path`

### YAML / YML

Supported:

* conservative simple-subset mapping / sequence parsing
* mapping -> table
* scalar sequence -> list
* sequence-of-mappings -> table when the mapping key set is stable
* nested / ambiguous fallback -> code block
* UTF-8 BOM removal
* CRLF / CR normalization

Conservative behavior:

* only the current simple subset is interpreted structurally
* comments are ignored by the current parser
* regular table cells preserve markdown-sensitive characters conservatively

Known limits:

* no anchors / aliases / tags
* no block scalar / flow style / multi-document input
* no full YAML spec support
* no nested provenance beyond root `key_path`

### Markdown / MD / MARKDOWN

Supported:

* UTF-8 BOM removal
* CRLF / CR normalization
* source-preserving passthrough
* conservative block slicing for metadata summary
* frontmatter passthrough as literal source text when a leading `---` or `+++`
  block is present

Conservative behavior:

* original Markdown body is preserved instead of re-rendered from an AST
* metadata summary uses lightweight conservative blocks instead of full Markdown
  semantics

Known limits:

* no Markdown AST rewrite
* no link/image/table/frontmatter semantic transformation

### TXT

Supported:

* UTF-8 BOM removal
* CRLF / CR normalization
* empty-line paragraph boundaries
* paragraph-only output

Conservative behavior:

* non-empty lines inside one paragraph are joined with single spaces
* no Markdown semantics are inferred
* markdown-like literal text is emitted conservatively so plain TXT does not
  silently become headings/lists/links by accident
* input must decode as UTF-8; unsupported encodings fail closed rather than
  using heuristic auto-detection

Known limits:

* no heading/list/table/code recognition
* no complex encoding auto-detection
* no asset export

### XML

Supported:

* `.xml` routing
* UTF-8 BOM removal
* CRLF / CR normalization
* source-preserving fenced `xml` code-block output
* XML declaration / comments / attributes / doctype text preserved literally
* fence-width growth when source contains backticks

Conservative behavior:

* XML is preserved as normalized source text rather than semantically rebuilt
* metadata treats the whole source as one conservative `CodeBlock` summary block

Known limits:

* no XML semantic recovery
* no namespace interpretation
* no external entity loading
* no DTD expansion
* no `SYSTEM` / `PUBLIC` external-resource resolution
* no schema validation
* no specialized `.xhtml` / `.rss` / `.atom` / `.opf` / `.svg` handling
* no asset export

### ZIP

Supported:

* safe normalized entry traversal
* directory and common macOS metadata skip
* normalized path ordering
* supported nested entries:
  * Markdown / CSV / TSV / TXT / XML / JSON / YAML / static HTML
  * self-contained DOCX / PPTX / XLSX / PDF
* archive asset namespace/remap
* same-archive HTML local-image support through a safe extracted tree

Conservative behavior:

* unsafe archive paths fail closed at container level
* unsupported entries emit warning blocks rather than crashing the whole archive
* supported entries convert through the same dispatcher-driven path as their
  standalone format families
* nested archives are downgraded to warning blocks rather than traversed

Known limits:

* no nested archive recursion
* no binary preview
* no remote HTML asset fetch
* no absolute / root-relative / parent / scheme-like / backslash HTML local-image export
* normalized collisions and unsupported low-level ZIP features fail closed
* no ZIP64 / data-descriptor / encrypted-ZIP support in the current H1 path

### EPUB

Supported:

* `META-INF/container.xml`
* OPF rootfile / manifest / spine parsing
* spine-order Markdown aggregation
* XHTML / HTML spine item conversion
* same-archive local images through a safe extracted tree
* archive-style asset namespace/remap
* OPF title / creator / date / modified document metadata
* `linear="no"` spine items are skipped in the current H1 path

Conservative behavior:

* EPUB reading order comes from OPF spine, not ZIP entry order
* unsupported spine items degrade per item

Known limits:

* no DRM / encryption support
* no CSS rendering
* no nav / NCX semantic reconstruction
* no fallback chains
* no advanced media / font / SVG spine handling
* no remote fetch
* no nested archive recursion

Important boundary:

* EPUB uses XML internally for container/OPF files, but EPUB support is its own
  package/spine pipeline and is not the same thing as standalone XML conversion

## Shared Metadata / Asset Notes

Current shared rules:

* metadata schema remains unchanged
* origin fields are additive and sparse
* block provenance and asset provenance are lightweight, not fine-grained
* `ImageBlock` / `ImageData` is the current shared image contract

Current strong examples:

* DOCX / PPTX assets preserve OOXML relationship identity where available
* PDF assets preserve `object_ref`
* ZIP / EPUB remapped assets preserve container-level provenance
* TXT and XML produce no assets

## OCR Boundary

OCR is present only as an explicit `ocr` subcommand path.

It should currently be understood as:

* available for explicit use
* dependent on external tooling
* not the default `normal` mainflow
* not a claim that the repository is OCR-first by default
