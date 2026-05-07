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

## CLI Output Contract

Current product-path CLI contract:

* `normal <input> [output]` writes Markdown and any required materialized
  assets, but does not write metadata sidecars by default
* `normal --with-metadata <input> [output]` additionally writes
  `<markdown_dir>/metadata/<stem>.metadata.json`
* stdout mode prints Markdown only; it does not create sidecar or default
  output directories
* `batch <input_dir> <output_dir>` is a serial, non-recursive v1 runner over
  top-level files only
* `batch --with-metadata` writes one sidecar per generated Markdown file inside
  each isolated batch document root
* `ocr` and `debug` follow the same explicit metadata-gating rule when writing
  on-disk outputs
* `debug <input>` is now the unified multi-format inspect/report path
* unified debug inspect does not write Markdown, metadata sidecars, or assets
  by default
* PDF keeps deeper debug detail, including normalization summary aggregation,
  while other formats currently provide baseline report data plus selected
  format-specific stats
* legacy `debug <all|extract|raw|pipeline> <input> [output]` is deprecated and
  now maps to the unified PDF inspect surface; only an explicit `[output]`
  path materializes Markdown

Batch v1 behavior:

* one isolated document root per top-level input file:
  `NNN-<input_stem>/<input_stem>.md`
* `assets/` and `metadata/` stay inside each document root
* unsupported files do not abort the whole batch; they are recorded in
  `batch-summary.tsv`
* nested directories are skipped in v1 and recorded as `skipped_directory`

## Status Vocabulary

Repository status labels are intentionally conservative:

* `H1 baseline`: dispatcher reachability plus a conservative main path exists
* `H2 main-path quality`: common local non-OCR cases are stable, with explicit
  limits documented
* `H2 partial`: useful main-path support exists, but important structures still
  depend on future lower-layer work
* `subset-H2`: only a conservative supported subset reaches H2-style
  expectations
* `source-preserving`: the primary contract is safe source preservation, not
  semantic reconstruction
* `H2++ complete`: checked-in regression, metadata/assets behavior, and quality
  scope are sealed for the documented format boundary
* `H3++ evidence-backed`: performance language is backed by a named checked-in
  corpus on the documented runner path
* `H3 evidence requires benchmark`: performance language must be backed by
  runner- and corpus-specific benchmark evidence, and must separate native CLI,
  `moon run`, OCR, and cloud/plugin paths

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
* shared text normalization is profile-based rather than globally aggressive:
  output text, comparison/heuristic text, and literal/raw text preservation are
  explicitly separated
* origin metadata is best-effort provenance, not a full anchoring system
* metadata schema stays additive and sparse
* asset export only happens for formats that materially emit image files

Shared text-normalization substrate:

* `core/text_normalization.mbt` is the common entry point for Text
  Normalization v2
* current shared profiles are:
  `Literal`, `GeneralText`, `PdfText`, `PdfCompareText`, `HtmlText`,
  `OoxmlText`, and `StructuredDataText`
* `PdfText` is used for output-facing extracted PDF text cleanup
* `PdfCompareText` is used for PDF heading/noise/table/caption/merge
  comparison text and is intentionally stronger than output normalization
* current shared stages are:
  validate-scalar, line-ending, canonical-unicode policy,
  compatibility-glyph, whitespace, invisible-char, soft-hyphen, PDF glyph
  fallback, and PDF compare cleanup
* current high-value subset covers line endings, NBSP/unicode spaces,
  `U+200B` / `U+FEFF`, `U+00AD`, common ligatures, and PDF compatibility glyph
  fallback
* smart-quote normalization, dash normalization, fullwidth folding, and CJK
  punctuation rewriting are explicit opt-in behaviors and are not default
  output policy
* canonical `NFC` / `NFKC` policy hooks exist, but the repository does not
  claim full ICU/UAX #15 support; the current MoonBit stdlib path does not
  expose a full Unicode normalization API here, so canonical stages remain
  documented no-op/warning behavior until a future table-backed implementation
  exists
* this substrate is deterministic preprocessing, not OCR, not a layout engine,
  and not a semantic classifier
* literal contexts such as Markdown passthrough, fenced code output, HTML
  `pre/code`, XML source-preserving fallback, JSON/YAML/XML literal code
  paths, CSV/TSV value text, and TXT literal-safe lowering do not opt into
  aggressive normalization by default

## Per-format Support

### DOCX

Status:

* `H2++ complete`
* `H3++ evidence-backed on checked-in native overlap corpus`

Supported:

* headings
* ordered / unordered / nested lists
* tables
* block quotes
* code-like paragraphs
* hyperlinks in paragraph / heading / list contexts
* multi-run hyperlinks
* footnotes / endnotes / comments
* headers / footers
* text boxes, including table-contained text boxes
* exported images through unified `ImageBlock`

Conservative behavior:

* numbering.xml and style-linked numbering now drive conservative ordered /
  unordered list recovery where signal is available
* style-driven recovery remains heuristic rather than style-taxonomy complete
* image title/alt comes from source-native OOXML drawing fields
* OOXML document properties are surfaced in the explicit `--with-metadata`
  sidecar path
* DOCX tables now carry explicit `RichTable` / `header_rows` metadata while
  keeping current Markdown table output stable
* DOCX table cells now preserve conservative Markdown-link text and image
  alt-text labels where the lower layer has the necessary OOXML signal
* headers/footers now use conservative append sections with de-duplication and
  page-number-only noise skipping
* `w:txbxContent` text boxes now use a conservative final `Text Boxes` append
  section instead of visual anchor reconstruction
* merged table cells currently follow a visible-content policy rather than full
  visual merge reconstruction
* footnotes/endnotes/comments use explicit append-section ordering rather than
  inline Word review semantics
* deleted / moved-from revision markup is skipped while inserted / moved-to
  visible text is preserved conservatively

Known limits:

* not a Word layout engine
* no macro / VBA handling
* no run-level bold / italic / code-span preservation yet
* no internal bookmark / anchor hyperlink promotion
* footnotes/endnotes/comments currently use conservative append-section output
  rather than richer inline semantics
* no tracked-changes UI / richer review semantics
* no floating-object or complex DrawingML visual reconstruction
* no full style rendering
* no table cell provenance or merged/nested visual table reconstruction

### PPTX

Status:

* `H2++ complete`
* `H3++ evidence-backed on checked-in native overlap corpus`

Supported:

* slide-order traversal
* reading-order-aware text recovery
* title/body/list separation
* placeholder- and geometry-aware reading-order heuristics
* explicit `p:grpSp` group-shape traversal with nested grouped text/image/table
  recovery
* explicit PowerPoint `a:tbl` table-object lowering
* table-like / callout-like / caption-like region handling
* run-level and basic shape-level external hyperlink recovery
* slide-local speaker notes extraction
* hidden slide annotation with content-preserving output
* exported images through unified `ImageBlock`
* OOXML document properties in the explicit `--with-metadata` sidecar path
* relationship/source provenance for hyperlinks, tables, images, and notes

Conservative behavior:

* each slide gets a synthetic slide-boundary heading in workbook order
* hidden slides are preserved with a `(hidden)` heading marker
* explicit table objects emit `RichTable` with first-row header semantics unless
  `a:tblPr firstRow="0|false"` disables it
* speaker notes are emitted under the owning slide as a conservative append
  subsection
* heuristic "table-like" recovery still exists for non-table shape layouts
* grouped shapes preserve conservative `object_ref` provenance through
  reading-order text lowering when lower-layer shape identity is available
* image caption attachment stays conservative
* layout heuristics favor readable downgrade over aggressive reconstruction

Known limits:

* no advanced multi-image caption pairing
* no comments output yet
* no semantic table IR for heuristic table-like regions
* no visual merged-table reconstruction
* no internal/action/media hyperlink promotion
* no chart / SmartArt / OLE / embedded-media semantics
* no pixel-perfect grouped-layout or z-order reconstruction
* not a PowerPoint layout engine
* no animations / transitions

### XLSX

Status:

* `H2++ complete`
* `H3++ evidence-backed on checked-in native overlap corpus`

Supported:

* multi-sheet output
* sheet headings plus tables
* explicit `RichTable` table semantics
* sparse-region trimming
* datetime/time formatting
* shared strings and inline strings
* boolean / error / blank cell handling
* typed-cell semantic tagging in metadata sidecar
* formula text and cached-value policy hints in metadata sidecar
* lightweight missing-cache formula evaluation for a safe local subset
* merged-range detection in the lower layer
* hidden / veryHidden sheet-state capture in the lower layer
* sheet-state emission in metadata sidecar
* source row/column provenance

Conservative behavior:

* tables emit spreadsheet-style `RichTable` with `header_rows = 1`
* cached values are still preferred over local evaluation when present
* missing cached formulas now use a lightweight evaluator only for a bounded,
  deterministic subset
* supported evaluator-v1 subset includes same-sheet references/ranges,
  arithmetic, comparisons, and common local functions such as `SUM`,
  `AVERAGE`, `MIN`, `MAX`, `COUNT`, `COUNTA`, `IF`, `ROUND`, `ABS`,
  `CONCAT`/`CONCATENATE`, `LEFT`, `RIGHT`, `LEN`, `LOWER`, `UPPER`, and
  `TRIM`
* missing-cache formulas outside that subset degrade conservatively to blank
  display rather than invented values
* formula policy, evaluated values, and unsupported/error reasons are exposed
  in metadata sidecar hints when available
* hidden sheets are currently emitted in workbook order
* merged ranges currently preserve only the top-left visible value
* formula text is preserved in the lower layer and metadata sidecar when present
* sparse sheets are lowered through a used bounding box, not a full grid

Known limits:

* no merged-cell reconstruction
* no full Excel formula engine
* no cross-sheet, external workbook, named-range, lookup, array, dynamic
  array, volatile, or structured-reference evaluation
* no workbook recalc or compatibility guarantee beyond the checked-in
  evaluator-v1 subset
* no hidden-sheet annotation in emitted Markdown beyond sheet headings
* no charts / pivots / comments / image export
* no full memory / RSS benchmark evidence yet

### PDF

Status label:

* `H2++ complete` for text-oriented PDF on the default local path
* scanned/OCR PDF is a separate explicit path, not part of the default
  performance story

Supported:

* native text-oriented structural recovery
* headings / paragraphs / list-like text recovery
* repeated-header/footer cleanup
* cross-page paragraph merge
* exported images
* simple high-confidence grid-like PDF tables
* headerless numeric PDF tables
* high-confidence same-page image captions
* lightweight page/image provenance
* PDF debug pipeline and inspect surfaces

Conservative behavior:

* structure is text-first, not visual-layout faithful
* shared `PdfText` normalization runs before heading/noise/merge/table/caption
  heuristics so low-risk character cleanup is consistent across the PDF path
* table recovery only triggers for compact, aligned, high-confidence text grids
* table lowering supports both explicit header-like first rows and conservative
  `header_rows = 0` headerless numeric tables
* page-number-like numeric candidates survive core/early-block construction and
  are resolved later by edge-aware noise policy so middle-body numeric table
  cells are still available to the conservative table detector
* image caption attachment only triggers for short, figure-like nearby text
* PDF annotation links only emit for a narrow, high-confidence URI subset; all
  other annotation/link cases remain conservative and debug-visible

Known limits:

* no internal-destination / GoTo link emission
* no multiline or ambiguous PDF link emission
* no general PDF table engine or complex table reconstruction
* no outlines / bookmarks emission
* no tagged-PDF semantic interpretation contract
* no default smart-quote/dash/fullwidth/CJK-punctuation rewriting policy
* no OCR-first default path
* no full complex-layout or advanced multi-column reconstruction
* H3++ performance claims apply only to the checked-in native text-PDF corpus

### HTML / HTM

Supported:

* headings, paragraphs, lists, block quotes, code blocks, tables
* inline hyperlinks
* local image export
* figure / figcaption / alt / title handling
* details / summary visible-text preservation
* UTF-8 BOM removal
* CRLF / CR normalization
* common named entities: `amp`, `lt`, `gt`, `quot`, `apos`, `nbsp`
* numeric decimal / hex entity decoding
* explicit `RichTable` metadata semantics for HTML tables
* conservative HTML provenance through block-level `object_ref` / `key_path`
  where the current unified metadata schema permits it
* table span-boundary hints in metadata sidecars through `span_cells`

Conservative behavior:

* recovery is lightweight safe semantic HTML parsing, not browser rendering
* local images are only exported for accepted local paths
* unsupported remote/data-URI images degrade conservatively instead of fetching
* `javascript:`, `vbscript:`, and `data:` hyperlinks fail closed to visible
  text instead of emitting dangerous Markdown links
* comments / doctype are ignored
* semantic wrappers such as `main` / `section` / `header` / `footer` preserve
  child content conservatively
* `script` / `style` / `head` / `noscript` are skipped rather than executed,
  rendered, or browser-expanded
* `thead` / `tbody` / `tr` / `th` / `td` lower to stable Markdown table rows
  with conservative header-row inference
* `rowspan` / `colspan` boundaries are recorded/explained through metadata
  hints, but not visually reconstructed

Known limits:

* not browser-grade HTML5 parsing
* no CSS layout
* no JS execution
* no remote fetch
* `data:` images are not materialized by default
* local-path export remains fail-closed for rooted paths and parent-traversal
  paths
* unknown named entities remain literal rather than using a full HTML entity
  table
* no full DOM/tree-builder contract
* no browser-style visual layout reconstruction

Current second-round note:

* HTML provenance improvements naturally surface through ZIP/EPUB nested HTML
  metadata snapshots because those formats consume HTML as a lower layer
* that downstream metadata reflection was not, by itself, enough to seal ZIP or
  EPUB; both formats only moved to `H2++ complete` after their own checked-in
  regression, metadata, quality, and benchmark evidence chains were completed

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
* standard JSON escape decoding including valid `\uXXXX`
* valid unicode surrogate-pair decoding
* strict JSON number grammar for integer / fraction / exponent forms

Conservative behavior:

* object tables use explicit header semantics only where structure is obvious
* regular object arrays only become tables when all rows share the same key set
* nested object/array cell values inside otherwise tabular object arrays are
  preserved as compact JSON strings instead of being flattened

Known limits:

* no JSON Schema
* no JSON Lines
* no streaming parser path
* no nested provenance beyond root `key_path`
* duplicate keys keep parser source order; no deduplication semantics are added
* no relaxed JSON comments or trailing-comma support

### YAML / YML

Status label:

* `subset-H2`: only the current conservative YAML subset is in scope

Supported:

* conservative simple-subset mapping / sequence parsing
* mapping -> table
* scalar sequence -> list
* sequence-of-mappings -> table when the mapping key set is stable
* nested / ambiguous fallback -> code block
* UTF-8 BOM removal
* CRLF / CR normalization
* `'...'` / `"..."` quoted scalar support
* comment-only / blank-line-only input handling

Conservative behavior:

* only the current simple subset is interpreted structurally
* comments are ignored by the current parser
* regular table cells preserve markdown-sensitive characters conservatively
* later mapping key order may differ inside a sequence-of-mappings as long as
  the key set stays stable
* nested mapping/sequence cell values are preserved as compact inline text
  instead of being flattened

Known limits:

* no anchors / aliases / tags
* no block scalar / flow style / multi-document input
* no full YAML spec support
* no nested provenance beyond root `key_path`
* duplicate keys keep parser source order; no merge-key semantics are added

### Markdown / MD / MARKDOWN

Status label:

* `H2 main-path quality` for passthrough Markdown
* not a semantic Markdown AST converter

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

Status label:

* `H2 main-path quality` for literal-safe plain text
* no heading/list/table inference contract

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

Status label:

* `source-preserving`
* safe XML handling, not semantic XML-family conversion

Supported:

* `.xml` routing
* UTF-8 BOM removal
* CRLF / CR normalization
* source-preserving fenced `xml` code-block output
* XML declaration / processing instruction / comments / CDATA / attributes /
  doctype text preserved literally
* fence-width growth when source contains backticks
* safe tokenizer/event surface for declarations, processing instructions, tags,
  comments, CDATA, doctype, text, and literal entity references

Conservative behavior:

* XML is preserved as normalized source text rather than semantically rebuilt
* metadata treats the whole source as one conservative `CodeBlock` summary block
* tokenizer is syntax-level only and does not change main Markdown output

Known limits:

* no XML semantic recovery
* no namespace interpretation
* no external entity loading
* no DTD expansion
* no entity expansion
* no `SYSTEM` / `PUBLIC` external-resource resolution
* no schema validation
* no specialized `.xhtml` / `.rss` / `.atom` / `.opf` / `.svg` handling
* no asset export

### ZIP

Status label:

* `H2++ complete`
* `H3++ evidence-backed on checked-in native corpus`
* package dispatch with explicit ZIP feature and safety boundaries

Supported:

* safe normalized entry traversal
* directory and common macOS metadata skip
* normalized path ordering
* supported nested entries:
  * Markdown / CSV / TSV / TXT / XML / JSON / YAML / static HTML
  * self-contained DOCX / PPTX / XLSX / PDF
* archive asset namespace/remap
* same-archive HTML local-image support through a safe extracted tree
* nested DOCX / PPTX asset remap with archive namespacing
* metadata sidecars that preserve archive entry `key_path`, nested provenance,
  and nested asset `source_path`

Conservative behavior:

* unsafe archive paths fail closed at container level
* unsupported entries emit warning blocks rather than crashing the whole archive
* supported entries convert through the same dispatcher-driven path as their
  standalone format families
* nested archives are downgraded to warning blocks rather than traversed
* deterministic ZIP inspect/inventory can classify entry action without
  changing conversion semantics

Known limits:

* no nested archive recursion
* no binary preview
* no remote HTML asset fetch
* no absolute / root-relative / parent / scheme-like / backslash HTML local-image export
* normalized collisions and unsupported low-level ZIP features fail closed
* no ZIP64 / data-descriptor / encrypted-ZIP support in the current H2 path

Current second-round note:

* checked-in ZIP quality conclusions come from the repository quality records,
  not from a blanket archive claim
* checked-in ZIP H3 conclusions come from the native checked-in ZIP smoke and
  batch corpus; they are not broad claims about every archive and do not
  currently depend on an external overlap-performance story

### EPUB

Status label:

* `H2++ complete`
* `H3++ evidence-backed on checked-in native EPUB corpus`
* safe OPF/spine/nav/NCX/local-asset main path, not full ebook rendering

Supported:

* `META-INF/container.xml`
* OPF rootfile / manifest / spine parsing
* spine-order Markdown aggregation
* XHTML / HTML spine item conversion
* EPUB3 nav detection with conservative TOC emission
* EPUB2 NCX minimal fallback support on the checked-in subset:
  * OPF `spine toc="<id>"`
  * manifest `application/x-dtbncx+xml`
  * `navMap` / `navPoint` / `navLabel/text` / `content src`
* cover-image detection with conservative top-of-document cover emission
* guide-cover image fallback
* same-archive local images through a safe extracted tree
* archive-style asset namespace/remap
* OPF title / creator / language / identifier / publisher / date / modified
  document metadata
* missing spine-manifest-item warning blocks with continue-on-next-chapter
* unsupported spine-item warning blocks
* `linear="no"` spine items are skipped in the current H1 path

Conservative behavior:

* EPUB reading order comes from OPF spine, not ZIP entry order
* EPUB3 nav wins over NCX fallback when both exist
* unsupported spine items degrade per item
* missing manifest spine references degrade per item instead of aborting the
  whole book
* local assets are remapped into archive-scoped `assets/archive/...`
* remote/data images are not fetched or materialized

Known limits:

* no DRM / encryption support
* no CSS rendering
* no JS
* no remote fetch
* NCX support is intentionally minimal:
  * no `pageList`
  * no `navList`
  * no landmarks / SMIL
  * no promise of full tree fidelity on arbitrary NCX files
* no advanced media / font / SVG spine handling
* no nested archive recursion

Important boundary:

* EPUB uses XML internally for container/OPF files, but EPUB support is its own
  package/spine pipeline and is not the same thing as standalone XML conversion
* EPUB is not a ZIP dump: current quality assumes OPF package, spine order,
  TOC policy, cover policy, and archive-local assets are respected

Current evidence scope:

* current EPUB H2++ quality conclusions come from checked-in EPUB quality
  comparison records only
* current EPUB H3++ performance conclusions come from the checked-in native
  EPUB corpus and meaningful local overlap rows only

## Shared Metadata / Asset Notes

Current shared rules:

* metadata schema is additive and intentionally sparse
* origin fields are additive and sparse
* block provenance and asset provenance are lightweight, not fine-grained
* `ImageBlock` / `ImageData` is the current shared image contract
* sample validation checks the core sidecar contract rather than pinning every
  optional field for every format

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
* separate from any cloud / Document Intelligence / LLM-style path discussion
