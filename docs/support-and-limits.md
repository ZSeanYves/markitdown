# Support Scope And Known Limits

This is the repository’s detailed support contract. When README or older
historical/progress notes differ, this document should be treated as the
detailed source of truth for format behavior and limits.

For current benchmark commands, performance caveats, and measured baseline, use
[docs/benchmarking.md](./benchmarking.md) and
[docs/performance.md](./performance.md).

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

Current validation layering:

* `./samples/check.sh` remains the exact regression and contract gate
* `samples/quality_corpus/` is the signal-level external/private intake path
* the legacy checked `samples/real_world/` corpus has been removed because it
  was synthetic/regression-like rather than reliable real-world quality
  evidence
* private local quality samples must remain uncommitted
* external quality rows must stay locally curated until license review is
  approved
* upstream tool fixtures and public datasets are references, not oracles

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
* `doc_parse/*` packages are lower-layer parsing substrates and should expose
  container/document/package/page/part signal rather than final Markdown
  semantics
* shared text normalization is profile-based rather than globally aggressive:
  output text, comparison/heuristic text, and literal/raw text preservation are
  explicitly separated
* origin metadata is best-effort provenance, not a full anchoring system
* metadata schema stays additive and sparse
* asset export only happens for formats that materially emit image files

Lower-layer package contract:

* `doc_parse/*` is now treated as an in-tree parser/model/error/inspect/
  validation/provenance/safety foundation line rather than as a
  converter-only helper layer
* current package/container foundation candidate line is:
  * `doc_parse/zip`: external-decoder-backed ZIP foundation candidate
  * `doc_parse/ooxml`: OOXML package foundation candidate
  * `doc_parse/epub`: EPUB package/spine/nav foundation candidate
  * `doc_parse/pdf`: native text-PDF foundation candidate
* current simple-format parser candidate line is:
  * `doc_parse/csv`: simple-format parser foundation candidate
  * `doc_parse/tsv`: simple-format parser foundation candidate
  * `doc_parse/json`: simple-format parser foundation candidate
  * `doc_parse/yaml`: YAML-subset parser foundation candidate
  * `doc_parse/text`: plain-text parser foundation candidate
  * `doc_parse/xml`: XML parser foundation candidate
* current markup/scanner candidate line also includes:
  * `doc_parse/html`: HTML DOM-ish parser foundation candidate with tolerant
    tokenizer/parser/model/inspect/validation and explicit no-fetch /
    no-script-execution boundary
  * `doc_parse/markdown`: Markdown lightweight scanner foundation candidate
    with raw block inventory, frontmatter detection, fenced code detection,
    and no renderer / no output mutation boundary
* current OOXML semantic candidate line is:
  * `doc_parse/xlsx`: XLSX semantic foundation candidate with
    workbook/sheet/cell/shared-string/style/merged-range/conservative-formula
    model plus inspect/validation, while `convert/xlsx` still owns RichTable /
    IR / Markdown / product output policy
  * `doc_parse/docx`: DOCX semantic foundation candidate with
    WordprocessingML body/inline/table/relationship/style/numbering/note/media
    model plus inspect/validation/classifier, while `convert/docx` still owns
    the current normal output path
  * `doc_parse/pptx`: PPTX semantic foundation candidate with PresentationML
    presentation/slide/raw-shape/text/table/notes/media/hyperlink model plus
    inspect/validation/classifier, while `convert/pptx` still owns the
    current normal output path
* current delivery remains importable subpackages under
  `ZSeanYves/markitdown`; they are not yet separately split MoonBit modules
* they should fail closed or surface structured errors on malformed or unsafe
  input
* they should expose inspect/debug-friendly summaries that do not depend on
  final Markdown conversion, and where helpful should also provide structured
  inspect/report objects plus classifier-friendly error metadata
* they should not absorb converter-only semantic policy
* current convert normal-path integration status is:
  * integrated: `csv` / `tsv` / `json` / `yaml` / `text` / `xlsx`
  * not switched intentionally: `xml` / `html` / `markdown` / `docx` / `pptx`
* simple-format parser candidates still keep `convert/*` in place for
  file-I/O seams, IR shaping, Markdown policy, and product-facing metadata
  wiring
* current simple-format packages now also carry in-tree package README
  documentation for API, limits, and converter-boundary notes
* all OOXML semantic sublayers now exist in-tree, and `doc_parse/xlsx`,
  `doc_parse/docx`, and `doc_parse/pptx` are semantic foundation candidates

See [docs/doc-parse-foundation.md](./doc-parse-foundation.md).

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
* shared cleanup is rule-driven inside those stages:
  each rule has an explicit id, scope, profile/policy gating, centralized
  order, and summary entry for debug aggregation
* current high-value subset covers line endings, NBSP/unicode spaces,
  `U+200B` / `U+FEFF`, `U+00AD`, common ligatures, PDF compatibility glyph
  fallback, and profile-gated PDF output-safe spacing repair
* output-safe spacing repair currently includes rule-gated CJK internal
  spacing cleanup, CJK punctuation-adjacent spacing cleanup, ASCII
  punctuation spacing cleanup, bullet-marker spacing, and numbered-marker
  spacing where the active profile/policy allows them
* smart-quote normalization, dash normalization, fullwidth folding, and CJK
  punctuation rewriting are explicit opt-in behaviors and are not default
  output policy
* explicit canonical normalization APIs now exist through the project facade,
  backed by `tonyfettes/unicode`, including `normalize_nfd/nfc/nfkd/nfkc` and
  `is_normalized_*`
* default converter behavior still does not enable canonical normalization
* the repository does not claim full ICU/UAX #15 or
  `NormalizationTest.txt`-verified conformance yet
* this substrate is deterministic preprocessing, not OCR, not a layout engine,
  and not a semantic classifier
* PDF-only artifact cleanup, line-wrap repair, and other geometry-dependent
  decisions stay in PDF layers and are not default text-normalization rules
* the native PDF main path no longer depends on known-phrase replacement,
  known split-word lists, global `replace_all("- ", "")`, or global slash
  artifact cleanup as its default text-quality mechanism
* literal contexts such as Markdown passthrough, fenced code output, HTML
  `pre/code`, XML source-preserving fallback, JSON/YAML/XML literal code
  paths, CSV/TSV value text, and TXT literal-safe lowering do not opt into
  aggressive normalization by default
* debug/inspect surfaces, validation reports, and typed issue signals do not
  change default normal conversion behavior by themselves

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
* `doc_parse/docx` now exists as a source-native semantic foundation
  candidate for body/inline/table/relationship/style/numbering/note discovery,
  but `convert/docx` still owns the current normal heading/list/table/caption/
  code/image output policy
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
* `doc_parse/pptx` now exists as a PresentationML semantic foundation
  candidate, while `convert/pptx` still owns the current normal conversion
  path

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
* per-slide comments/commentAuthors extraction with conservative author/text
  appendix output
* cached chart-data extraction from PresentationML chart-part XML cache
* hidden slide annotation with content-preserving output
* exported images through unified `ImageBlock`
* OOXML document properties in the explicit `--with-metadata` sidecar path
* relationship/source provenance for hyperlinks, tables, images, notes, and
  comments

Conservative behavior:

* each slide gets a synthetic slide-boundary heading in workbook order
* hidden slides are preserved with a `(hidden)` heading marker
* explicit table objects emit `RichTable` with first-row header semantics unless
  `a:tblPr firstRow="0|false"` disables it
* speaker notes are emitted under the owning slide as a conservative append
  subsection
* comments are emitted under the owning slide as a conservative append
  subsection with minimal `author: text` lines rather than inline bubble
  reconstruction
* aligned cached chart-data can lower to `RichTable`, while irregular cache
  falls back to conservative text
* heuristic "table-like" recovery still exists for non-table shape layouts
* grouped shapes preserve conservative `object_ref` provenance through
  reading-order text lowering when lower-layer shape identity is available
* image caption attachment stays conservative
* layout heuristics favor readable downgrade over aggressive reconstruction

Known limits:

* no advanced multi-image caption pairing
* no semantic table IR for heuristic table-like regions
* no visual merged-table reconstruction
* no internal/action/media hyperlink promotion
* no chart rendering or embedded-workbook chart fallback
* no chart style/color/axis/legend/layout semantics
* no comment bubble positioning, shape-anchor recovery, or threaded/modern
  comments semantics
* no SmartArt / OLE / embedded-media semantics
* no pixel-perfect grouped-layout or z-order reconstruction
* not a PowerPoint layout engine
* no animations / transitions
* `doc_parse/pptx` does not claim reading-order recovery, layout grouping,
  image export, final Speaker Notes / Comments section policy, or final
  heading/list classification ownership

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

* the default native PDF path extracts embedded text plus page/image assets
* native text-oriented structural recovery
* Level 1 `/ToUnicode` CMap text decoding
* text PDFs whose fonts expose usable `/ToUnicode`, including conservative
  Type0/CIDFont positive paths when the native text layer is already recoverable
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
* pure string cleanup is handled by the shared core rule pipeline, while
  span/line/model glue and line-wrap repair stay PDF-local
* table recovery only triggers for compact, aligned, high-confidence text grids
* table lowering supports both explicit header-like first rows and conservative
  `header_rows = 0` headerless numeric tables
* page-number-like numeric candidates survive core/early-block construction and
  are resolved later by edge-aware noise policy so middle-body numeric table
  cells are still available to the conservative table detector
* image caption attachment only triggers for short, figure-like nearby text
* PDF annotation links only emit for a narrow, high-confidence URI subset; all
  other annotation/link cases remain conservative and debug-visible
* no-context text glue fallback is intentionally narrow and now prefers same
  line / adjacent-span context, source-ref adjacency, font/font-size/style
  consistency, gap/baseline proximity, punctuation boundaries, and casing
  signals over pure short-word guessing
* `/ToUnicode` decoding currently supports `codespacerange`, `bfchar`, and
  conservative `bfrange` handling, including multi-byte source-code matching
  and UTF-16BE destinations
* Type0/CIDFont text recovery is expected to prefer `/ToUnicode` whenever the
  source PDF provides it; current Arabic and other non-ASCII positive rows are
  evidence for this path, not a claim of full bidi/typography fidelity
* image-only or scan-only PDFs in `normal` mode currently degrade to exported
  page/image assets rather than synthesized OCR text
* inspect/debug now exposes report-only PDF text-signal diagnostics such as
  `text_signal_level`, `image_only`, `ocr_recommended`, and native text/image
  counts without changing Markdown output
* the checked-in `samples/pdf_layout_classifier` training spike is export/train/
  infer tooling only; it does not change default PDF Markdown output, does not
  enable OCR, and does not connect a visual layout runtime into the normal path

Known limits:

* no internal-destination / GoTo link emission
* no multiline or ambiguous PDF link emission
* no general PDF table engine or complex table reconstruction
* no outlines / bookmarks emission
* no tagged-PDF semantic interpretation contract
* no full predefined-CMap coverage for Type0/CIDFont PDFs that rely on
  `UniGB-UCS2-H`, `UniJIS-UCS2-H`, `UniCNS-UCS2-H`, `UniKS-UCS2-H`, or similar
  predefined mappings without `/ToUnicode`
* no embedded TrueType/OpenType `cmap` fallback for Type0/CIDFont PDFs with
  `/Identity-H` and no `/ToUnicode`
* no reliable general extraction contract for `/Identity-H` no-`/ToUnicode`
  PDFs; current local external evidence keeps these as retained boundaries
* no GBK/GB18030 fallback strategy for simple raw-GBK, no-`/ToUnicode`
  simple-font PDFs
* no default smart-quote/dash/fullwidth/CJK-punctuation rewriting policy
* no OCR-first default path
* no full complex-layout or advanced multi-column reconstruction
* H3++ performance claims apply only to the checked-in native text-PDF corpus
* OCR remains an explicit separate path; OCR cleanup has not been rolled into
  the shared default normalization policy
* scan-only/image-only PDFs may surface as OCR candidates in debug/inspect or
  quality-report workflows, but that does not change the default `normal` mode
  output contract
* OCR and layout-assist backends are expected to stay behind explicit provider
  or plugin routes rather than broad hidden fallbacks in `normal`
* lightweight OCR/layout-assist provider skeletons may exist for lazy
  descriptor/probe/report wiring, but they do not imply bundled OCR engines,
  bundled model files, or normal-path activation
* layout-assist advisory predictions may surface in PDF debug/inspect reports,
  but they do not participate in the normal conversion decision path
* the explicit `tesseract-cli` provider is optional and external: it can probe
  availability and OCR page images when users explicitly choose it, but it is
  not bundled and is not part of the default `normal` path
* debug-only provider listing/probe surfaces may expose provider availability
  state, but availability does not mean OCR has been run
* the current lightweight layout classifier spike is local-corpus-only and is
  not wired into the default conversion decision path
* bad `/ToUnicode` maps can still legitimately yield replacement characters or
  other low-value output; the repository does not currently promise rescue
  beyond the declared Level 1 parser behavior

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
* `doc_parse/html` now provides a DOM-ish parser foundation candidate, but
  `convert/html` still owns the current normal HTML conversion path

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
* single-document leading `---` and trailing `...` marker compatibility
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
* no block scalar / flow style
* no true multi-document input stream support
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
* `doc_parse/markdown` now provides a lightweight source scanner / raw block
  inventory / inspect candidate surface for Markdown source structure

Conservative behavior:

* original Markdown body is preserved instead of re-rendered from an AST
* metadata summary uses lightweight conservative blocks instead of full Markdown
  semantics
* scanner findings do not mutate passthrough output or normalization policy
* `convert/markdown` still owns the normal passthrough/product path; the
  lightweight scanner foundation is not the normal converter path yet

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
* literal-safe TXT lowering does not opt into PDF-specific artifact cleanup or
  aggressive spacing repair

Known limits:

* no heading/list/table/code recognition
* no complex encoding auto-detection
* no asset export

### XML

Status label:

* `source-preserving`
* safe XML handling with an internal parser foundation candidate

Supported:

* `.xml` routing
* UTF-8 BOM removal
* CRLF / CR normalization
* source-preserving fenced `xml` code-block output
* XML declaration / processing instruction / comments / CDATA / attributes /
  doctype text preserved literally
* fence-width growth when source contains backticks
* `doc_parse/xml` tokenizer / parser / inspect / validation candidate for
  declarations, processing instructions, tags, comments, CDATA, doctype, and
  safe text/entity handling

Conservative behavior:

* XML is preserved as normalized source text rather than semantically rebuilt
* metadata treats the whole source as one conservative `CodeBlock` summary block
* parser-layer XML inspection now exists, but the normal converter still keeps
  source-preserving fenced output
* XML does not opt into PDF-specific artifact cleanup or aggressive text
  rewriting beyond conservative source cleanup

Known limits:

* no XML semantic recovery
* no namespace interpretation
* no external entity loading
* no DTD expansion
* no custom entity expansion; only predefined XML entities are decoded in the
  parser foundation
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
* Level 1 bit-3 data-descriptor handling when central-directory sizes/CRC are
  available
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
* no ZIP64 / encrypted-ZIP / multi-disk ZIP support
* no full streaming data-descriptor parser beyond the current Level 1
  central-directory-known-size case

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
* now accompanied by lightweight provider skeletons and design docs
* currently includes an explicit `tesseract-cli` page-image provider route
* the `ocr` CLI path can now route explicit image inputs through
  `--provider tesseract-cli` and `--lang ...`
* the checked-in OCR image suite verifies explicit CLI/provider boundary
  behavior such as unknown providers, unsupported extensions, lazy
  unavailable-provider messages, and image-path routing without turning OCR
  into a normal-path gate
* an optional local `tesseract-cli` smoke can be run manually when external
  tooling is present, but it is not part of the default CI/sample gate and is
  not treated as an OCR quality benchmark
* the repository also carries an OCRmyPDF provider audit/design document for a
  future explicit PDF OCR route, but OCRmyPDF is not implemented as a runtime
  path yet
* the repository also treats PaddleOCR / PP-Structure as a future heavy
  provider boundary only: it is not implemented, not bundled, and not part of
  the default OCR contract
* not the default `normal` mainflow
* not a claim that the repository is OCR-first by default
* separate from any cloud / Document Intelligence / LLM-style path discussion
* provider availability/probing should remain explicit and lazy rather than
  part of normal CLI startup
* direct PDF OCR through the provider layer is still out of scope here;
  `tesseract-cli` is page-image OCR only
* any future OCRmyPDF path must remain explicit, external, and
  provenance-tagged: OCR sidecar text is OCR output rather than native
  embedded PDF text, and normal PDF conversion must continue to avoid provider
  probing or hidden OCR fallback
* any future PaddleOCR route must also remain explicit, external, and
  heavy-provider-only: Python/runtime/model installation is user-managed,
  model downloads are not automatic, and layout/table/document-analysis output
  must not be mixed into normal Markdown by default
