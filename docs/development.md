# Development Guide

## CLI

The current CLI uses a subcommand-based interface:

```bash
moon run cli -- normal <input> [output]
moon run cli -- ocr <input> [output]
moon run cli -- debug <all|extract|raw|pipeline> <input> [output]
````

To also output a metadata sidecar, use:

```bash
moon run cli -- normal --with-metadata <input> <output.md>
moon run cli -- ocr --with-metadata <input> <output.md>
moon run cli -- debug --with-metadata <all|extract|raw|pipeline> <input> <output.md>
```

Current output rules:

* The Markdown main output follows the `[output]` argument
* If `[output]` behaves like a directory, the main output becomes `<output>/<input_stem>.md`
* The metadata sidecar is always written to:

  * `<markdown_dir>/metadata/<markdown_stem>.metadata.json`
* If no output file is provided (stdout mode), the sidecar is not written to disk

## Debug Modes

The current supported debug scopes are:

* `all`
* `extract`
* `raw`
* `pipeline`

Approximate meanings:

* `debug all`: enables the full PDF debug chain
* `debug extract`: shows extraction-stage debug information
* `debug raw`: dumps the selected raw text
* `debug pipeline`: shows debug information for the full PDF processing pipeline

For the current native PDF path, `debug pipeline` is the most useful
architecture-facing inspect entry. It surfaces `pdf_core`-derived information
such as page geometry, raw refs, image summaries, annotation summaries, and
text block statistics without changing normal conversion output.

## Regression System

The current regression system has been split into three independent validation chains:

* `samples/main_process`: mainflow structural recovery
* `samples/metadata`: origin / image-context / caption / nearby-caption
* `samples/assets`: asset export and Markdown asset-reference validity

In addition, `samples/test` provides a compact five-format demo set for acceptance walkthrough and quick manual inspection.

## Support Matrix Discipline

When landing a new format or materially expanding an existing one, update the
product-facing support contract at the same time:

* Add or revise the format entry in `README.mbt.md` so the short support matrix
  stays aligned with the implementation.
* Update `docs/support-and-limits.md` using the repository-wide template:
  `Currently supported`, `Partially supported`, `Graceful degradation`,
  `Metadata / assets / origin`, `Link support`, `Image context`, and
  `Explicitly unsupported / out of scope`.
* Update `docs/architecture.md` if the change affects converter-layer
  degradation strategy, provenance semantics, or shared IR contracts.
* Update `docs/metadata-sidecar.md` if the change affects verifiable origin or
  image-context fill ranges.

Every new parser or converter path should also explicitly declare which
degradation model it follows:

* `fail-closed`: invalid or unsupported syntax should raise and stop conversion
  instead of guessing a lossy structure
* `soft-degrade`: partial recovery is acceptable, but fallback behavior must be
  explainable and stable
* `source-preserving`: preserve the input body and avoid semantic reinterpretation

New regression coverage should include:

* at least one positive example that demonstrates the intended supported path
* at least one negative or unsupported example that proves unsupported features
  are not accidentally overclaimed
* at least one degradation example when the format supports conservative
  fallback behavior rather than hard failure

## Current Origin / Source Location Status

The current G2 Origin / Source Location stage is complete without changing the
sidecar schema or the Markdown main output contract. It consists of:

* additive origin schema extension
* sparse additive-field emission
* OOXML origin refinement
* structured/text origin refinement
* HTML image `source_path` refinement

Current sidecar origin field surface:

* `blocks[].origin`: `source_name`, `format`, `page`, `slide`, `sheet`,
  `block_index`, `heading_path`, `line_start`, `line_end`, `row_index`,
  `column_index`, `object_ref`, `relationship_id`, `key_path`
* `assets[].origin`: `source_name`, `format`, `page`, `slide`, `sheet`,
  `origin_id`, `object_ref`, `relationship_id`, `source_path`, `row_index`,
  `column_index`, `key_path`, `nearby_caption`

Current fill matrix to keep in mind during development:

* PDF assets: `object_ref`
* PPTX assets: `relationship_id` / `source_path`
* DOCX assets: `relationship_id` / `source_path`
* XLSX blocks: source row/column span plus `relationship_id`
* CSV / TSV blocks: physical `line_start` / `line_end` plus
  `row_index` / `column_index`
* JSON / YAML blocks: root `key_path = "$"`
* Markdown blocks: conservative `line_start` / `line_end`
* HTML image assets: `source_path` from normalized `<img src>`

Current explicit non-goals:

* default sidecar emission of PDF full `source_refs`
* default sidecar emission of bbox
* HTML DOM path / block line range
* table cell-level provenance
* table alignment, rowspan/colspan, merged-cell reconstruction, and
  table-cell origin
* JSON / YAML nested key path
* PDF annotation link Markdown emission

## Current Image Context Status

The current shared image-context contract should be treated as stable at the
current stage:

* `ImageBlock` / `ImageData` carries `path`, `alt_text`, `title`, `caption`,
  and `origin`
* `blocks[].image` serializes `path`, `alt_text`, `title`, and `caption`
* `assets[].alt_text`, `assets[].title`, and `assets[].caption` are filled by
  joining exported asset `path` back to the corresponding `ImageBlock`
* `nearby_caption` remains the asset-origin mirror of the primary caption value,
  not a second caption-inference slot

Current format image-context fill ranges:

* HTML: `<img alt>`, `<img title>`, `<figure>`, `<figcaption>`, and local
  `source_path`
* DOCX: `ImageBlock` plus source-native drawing `descr/title`
* PPTX: `ImageBlock` plus source-native picture `descr/title`, with synthetic
  alt only as fallback
* PDF: `ImageBlock`, `object_ref`, and conservative single-image caption pairing
* XLSX: no image conversion path yet

Current image-context non-goals:

* PDF / PPTX multi-image caption pairing
* using OOXML `name` as image caption or title
* default sidecar emission of PDF bbox / full `source_refs`
* XLSX image support
* remote HTML image fetch

## Current Format Expansion Stage

The currently landed text-format expansion stages are:

* F1: CSV / TSV
* F2: JSON
* F3: Markdown passthrough
* F4: YAML

Development positioning:

* CSV / TSV are delimited-table text converters that map source content into unified IR `Table`
* JSON / YAML are structured-data converters that conservatively map source content into unified IR table / `List` / `CodeBlock`
* Markdown is intentionally different: it is a low-loss passthrough path whose main output preserves the original Markdown source body

## Current Table IR Status

The current table IR has two compatibility tiers:

* Legacy `Block::Table(Array[Array[String]])` remains supported. Its Markdown
  output contract is unchanged: the first row is emitted as the Markdown table
  header.
* `Block::RichTable(TableData)` carries `rows` and `header_rows` for converters
  that have explicit source header semantics.

Markdown emitter behavior:

* `Table`: first row is the Markdown header.
* `RichTable(header_rows >= 1)`: first row is the Markdown header.
* `RichTable(header_rows = 0)`: synthetic `Column N` headers are emitted and all
  source rows become body rows.
* `RichTable(header_rows > 1)`: only the first header row is represented as the
  Markdown header today; additional header rows are emitted as body rows.

Current converter wiring:

* HTML uses `RichTable(header_rows = 1)` only when `<th>` or `<thead>` is
  explicitly present.
* JSON object tables and array-of-objects tables use
  `RichTable(header_rows = 1)`.
* YAML mapping tables and sequence-of-mappings tables use
  `RichTable(header_rows = 1)`.
* CSV / TSV / XLSX / DOCX continue to emit legacy `Table` to avoid changing
  output for sources without explicit header semantics.
* PDF / PPTX table-like heuristics are not promoted to semantic Table IR.

Current table non-goals:

* no metadata version bump for `header_rows`
* metadata snapshots for `RichTable` blocks include additive `table` data
* no cell-level metadata
* no alignment model
* no rowspan / colspan semantics
* no merged-cell reconstruction
* no table-cell origin

Current Markdown passthrough contract:

* Supports `.md` and `.markdown`
* Reads UTF-8 text
* Stores the original body in `passthrough_markdown`
* `core/emitter_markdown.mbt` prefers `passthrough_markdown` when present
* Only normalizes the final tail to exactly one trailing newline
* Does not perform Markdown AST parsing
* Does not rewrite link / image / table / code-fence / frontmatter semantics
* Does not change the metadata sidecar schema

Current YAML convert contract:

* Supports `.yaml` and `.yml`
* Reads UTF-8 text
* Supports a simple subset: top-level mapping, indentation-based nested mapping,
  scalar sequences, sequence of mappings, booleans, nulls, and quoted strings
* Maps structured data conservatively into table / `List` / `CodeBlock` IR
* Keeps the existing metadata sidecar schema unchanged
* Does not support anchors / aliases / tags / block scalar / flow style /
  multi-document input

### Temporary Output Directories

All automated tests and regression scripts should write temporary output under a
single temp root:

```bash
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
```

Rules:

* Default temp output goes to `$ROOT/.tmp/`
* `MARKITDOWN_TMP_DIR` may be used to override the temp root
* The following subdirectories are the standard layout and should be reused under
  the selected temp root:
  * `.tmp/samples/diff`
  * `.tmp/samples/assets`
  * `.tmp/samples/metadata`
  * `.tmp/samples/check`
  * `.tmp/bench/smoke`
  * `.tmp/origin`
  * `.tmp/pdf_core`
  * `.tmp/scratch/mbtpdf`
* Do not introduce new root-level temp directories such as
  `.tmp_test_out`, `.tmp_assets_test`, `.tmp_metadata_test`,
  `tmp-origin-tests`, or `tmp`
* New test scripts must reuse the `MARKITDOWN_TMP_DIR` convention instead of
  inventing a separate temp root

### Run internal smoke benchmark

```bash
./samples/bench_smoke.sh
./samples/bench_smoke.sh --kind image
./samples/bench_smoke.sh --kind all
./samples/bench_smoke.sh --iterations 3 --warmup 1
BENCH_KIND=image BENCH_ITERATIONS=3 BENCH_WARMUP=1 ./samples/bench_smoke.sh
```

Current smoke benchmark behavior:

* Uses `MARKITDOWN_TMP_DIR` when provided, otherwise writes under `$ROOT/.tmp`
* Supports `--kind KIND` / `BENCH_KIND=KIND`, where `KIND` is one of
  `smoke`, `image`, `metadata`, `extended`, or `all`
* Defaults to `--kind smoke` so daily benchmark cost stays low
* Supports `--iterations N` / `BENCH_ITERATIONS=N` and `--warmup N` /
  `BENCH_WARMUP=N`
* Resolves the benchmark root as:

```bash
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
BENCH_ROOT="$TMP_ROOT/bench/smoke"
```

* Writes warmup outputs under `.tmp/bench/smoke/<format>/<sample>/warmup-N/`
* Writes measured outputs under `.tmp/bench/smoke/<format>/<sample>/iter-N/`
* Writes run records to `.tmp/bench/smoke/results.jsonl`
* Writes aggregate sample metrics to `.tmp/bench/smoke/summary.tsv`
* Uses the checked-in `samples/benchmark/corpus.tsv` corpus and filters rows by
  `run_kind`
* `--kind all` runs every non-comment row in the benchmark corpus
* Avoids stdout mode so asset-exporting formats do not fall back to the repo-root
  `out/` directory

`results.jsonl` fields:

* `runner`: current benchmark runner id, currently `markitdown-mb`
* `mode`: CLI mode used for the run, currently `normal`
* `run_kind`: corpus tier for the sample, such as `smoke` or `image`
* `format`: detected input family in the corpus row
* `sample`: benchmark sample id from the corpus row
* `input_path`: repo-relative input file path from the corpus row
* `file_size`: input file size in bytes
* `metadata_enabled`: requested benchmark mode from the corpus row
* `iteration`: 1-based measured iteration number
* `warmup`: `false` for measured rows; warmup runs are not emitted to
  `results.jsonl`
* `elapsed_ms`: wall-clock elapsed milliseconds for that measured run
* `output_bytes`: generated markdown file size in bytes for that run
* `asset_count`: number of exported files under that run's `assets/` directory
* `exit_status`: CLI process exit code
* `timestamp`: UTC timestamp captured after the run
* `git_rev`: current repository short revision
* `tmp_root`: temp root used for the run
* `timer_precision`: timer mode used by the shell helper, currently `ms` or `s`

`summary.tsv` fields:

* `format`: format column copied from the corpus row
* `sample`: benchmark sample id
* `runs`: number of measured iterations included in the summary
* `failed`: number of measured runs with non-zero exit status
* `min_ms`: minimum measured elapsed time
* `median_ms`: median measured elapsed time
* `max_ms`: maximum measured elapsed time
* `avg_ms`: arithmetic mean of measured elapsed times
* `output_bytes_last`: markdown file size from the last measured iteration
* `asset_count_last`: exported asset count from the last measured iteration

### Run overlap-only comparison benchmark

```bash
./samples/bench_compare_markitdown.sh --help
./samples/bench_compare_markitdown.sh
BENCH_ITERATIONS=3 BENCH_WARMUP=1 ./samples/bench_compare_markitdown.sh
```

Current comparison benchmark behavior:

* Uses `MARKITDOWN_TMP_DIR` when provided, otherwise writes under `$ROOT/.tmp`
* Resolves the comparison root as:

```bash
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
COMPARE_ROOT="$TMP_ROOT/bench/compare"
```

* Uses the checked-in overlap-only corpus at
  `samples/benchmark/compare_corpus.tsv`
* Compares only overlapping text-oriented formats in the first phase:
  DOCX, PPTX, XLSX, PDF, HTML, and CSV
* Does not compare YAML, Markdown passthrough, TSV, metadata semantics, asset
  semantics, image-context behavior, or Markdown content similarity
* Does not enable OCR, Azure Document Intelligence, or plugin-driven paths
* Writes runner-separated outputs under:
  * `.tmp/bench/compare/mb/...`
  * `.tmp/bench/compare/python/...`
* Writes measured rows to `.tmp/bench/compare/results.jsonl`
* Writes aggregate runner/sample metrics to `.tmp/bench/compare/summary.tsv`
* Requires a user-prepared Python environment for Microsoft MarkItDown; the
  script does not auto-install dependencies

Recommended Python environment preparation:

```bash
python -m venv .venv-markitdown-compare
. .venv-markitdown-compare/bin/activate
pip install 'markitdown[all]==0.1.5'
```

Python runner resolution order:

* `MARKITDOWN_COMPARE_CMD`
* `MARKITDOWN_COMPARE_PY_BIN` via `python -m markitdown`
* default `.venv-markitdown-compare/bin/markitdown`

Comparison benchmark `results.jsonl` fields:

* `runner`: `markitdown-mb` or `markitdown-python`
* `version`: runner version string; current repo runner uses repo revision, the
  Python runner tries `markitdown --version`
* `format`: corpus format
* `sample`: corpus sample id
* `input_path`: repo-relative input file path
* `file_size`: input file size in bytes
* `iteration`: 1-based measured iteration number
* `warmup`: always `false` in measured rows; warmup runs are not emitted
* `elapsed_ms`: wall-clock elapsed milliseconds
* `output_bytes`: generated markdown file size in bytes
* `stderr_bytes`: stderr file size in bytes
* `exit_status`: runner process exit code
* `output_path`: explicit markdown output path for that run
* `stderr_path`: stderr capture file path for that run
* `timestamp`: UTC timestamp captured after the run
* `git_rev`: current repository short revision
* `tmp_root`: temp root used for the run
* `timer_precision`: timer mode used by the shell helper

Comparison benchmark `summary.tsv` fields:

* `runner`: `markitdown-mb` or `markitdown-python`
* `format`: corpus format
* `sample`: corpus sample id
* `runs`: number of measured iterations
* `failed`: number of measured runs with non-zero exit status
* `min_ms`: minimum measured elapsed time
* `median_ms`: median measured elapsed time
* `max_ms`: maximum measured elapsed time
* `avg_ms`: arithmetic mean of measured elapsed times
* `output_bytes_last`: markdown file size from the last measured iteration
* `stderr_bytes_last`: stderr file size from the last measured iteration

### Check sample enrollment consistency

```bash
./samples/check_samples.sh
```

### Run full main regression

```bash
./samples/diff.sh
```

### Run metadata regression independently

```bash
./samples/check_metadata.sh
```

### Run assets regression independently

```bash
./samples/check_assets.sh
```

## How to Choose Regression Scope During Development

### When modifying mainflow structural recovery logic

If you modify any of the following, you should at least run:

```bash
./samples/diff.sh
```

Typical cases include:

* `convert/*`
* `core/emitter_markdown.mbt`
* `core/ir.mbt`
* mainflow-related samples and expected outputs

Notes for Markdown passthrough work:

* Changes under `convert/markdown/` should preserve source Markdown body stability
* If you touch `passthrough_markdown` or emitter fallback order, re-run Markdown samples in `samples/main_process/markdown`
* Do not update Markdown expected outputs unless the intended contract itself changes

### When modifying metadata / provenance / image-context logic

If you modify any of the following, you should at least run:

```bash
./samples/check_metadata.sh
```

Typical cases include:

* `core/metadata.mbt`
* `core/ir.mbt`
* image caption / nearby-caption / origin related logic
* `samples/metadata/*`

Markdown-specific note:

* Markdown metadata currently uses conservative block slicing and keeps `document = null`
* Do not change the metadata schema when adjusting Markdown passthrough behavior unless the schema change is explicitly planned and accepted

YAML-specific note:

* YAML metadata currently keeps `document = null` and only uses the shared sidecar schema
* Changes under `convert/yaml/` should preserve the current conservative subset and fallback strategy
* Do not update YAML expected outputs unless the intended `Table` / `List` / `CodeBlock` contract itself changes

Origin-specific note:

* G2 field population is intentionally sparse; do not backfill additive fields
  with default `null` values
* Do not change `samples/main_process/expected/*` for metadata-only work
* Prefer `samples/metadata/*`, `samples/test/metadata/*`, and
  `convert/convert/test/origin_metadata_test.mbt` when adjusting origin logic

### When modifying ZIP container conversion

ZIP is a container converter, not a raw unzip feature. Keep these constraints
explicit in code and tests:

* validate and normalize archive entry paths before writing temporary files
* keep entry extraction under `MARKITDOWN_TMP_DIR` when set, otherwise `.tmp`
* process entries in normalized path order
* keep nested asset remap under `assets/archive/<entry-id>/...` so same-name
  converter outputs such as `image01.*` never collide across entries
* keep unsupported entries as blockquote warnings rather than failing the whole
  archive
* fail closed on normalized-path collisions before building any shared
  extracted tree
* keep HTML local-image materialization inside a safe extracted tree rooted
  under the ZIP temp directory
* preserve ZIP-level provenance on remapped assets: `source_name = zip
  filename`, `source_path/key_path = normalized entry path`, while keeping
  inner `relationship_id` / `object_ref` when present
* keep low-level ZIP reader fail-closed behavior for unsupported archive
  features such as encrypted inputs, ZIP64, data descriptors, or duplicate raw
  entry names
* do not claim remote fetch, `data:`, absolute/root-relative/parent/
  scheme-like/backslash HTML image support, nested archive recursion, or
  unchecked full archive extraction unless those paths are implemented and
  covered by samples
* do not add a separate metadata field for inner HTML image `src` without an
  explicit schema change

Image-context-specific note:

* Preserve the current `ImageBlock` contract: `path`, `alt_text`, `title`,
  `caption`, `origin`
* Preserve the current sidecar reuse rule:
  `assets[].alt_text/title/caption` come from `ImageBlock` path join
* Treat `nearby_caption` as the mirrored asset-origin field, not a second
  independent caption slot
* Do not repurpose OOXML `name` into caption or title without an explicit
  contract change
* Do not enable PDF / PPTX multi-image caption pairing as part of incidental
  image-context work

### When modifying asset export / asset reference logic

If you modify any of the following, you should at least run:

```bash
./samples/check_assets.sh
```

Typical cases include:

* image export logic for any format
* asset naming rules
* `samples/assets/*`

Image-context note:

* PPTX / DOCX / HTML image export changes can affect both `samples/assets/*`
  and `samples/metadata/*`
* If source-native alt/title changes Markdown image text, update the affected
  expected outputs intentionally rather than treating it as incidental churn

### When modifying PDF-related lower-level or recovery logic

If you modify any of the following, it is recommended to run at least:

```bash
./samples/diff.sh
./samples/check_metadata.sh
```

Typical cases include:

* `doc_parse/pdf_core/`
* `convert/pdf/`
* `core/emitter_markdown.mbt`
* PDF-related samples / expected outputs / metadata samples

The reason is that PDF currently affects not only the mainflow, but also image context and lightweight provenance.

## External Dependencies

### OCR plugin path

At the moment, only the OCR path depends on external tooling:

* `ocrmypdf`

Notes:

* OCR remains a dedicated plugin-style path, not the default `normal` mainflow
* The normal PDF path on `main` no longer depends on `pdftotext` or `mutool`
* The current normal PDF mainflow is driven by the repository’s native recovery chain

## How to Understand the Current Engineering Structure

The current project can be roughly understood as the following layers:

* `cli/`: command-line entry and output path coordination
* `convert/*`: upper-level structural recovery and semantic mapping
* `doc_parse/*`: lower-level parsing infrastructure (ZIP / OOXML / PDF)
* `core/*`: unified IR, Markdown emitter, metadata sidecar emitter
* `samples/*`: mainflow / metadata / assets regression and acceptance demo samples

Within `doc_parse/*`, the current lower-level package split is:

* `doc_parse/zip`: ZIP container handling used by OOXML readers
* `doc_parse/ooxml`: shared OOXML package/relationship/media/docProps/debug-dump infrastructure
* `doc_parse/pdf_core`: native PDF parsing substrate including page geometry, source refs, raw images/annotations, and inspect helpers

When developing, you should try to determine clearly which layer your change belongs to:

* raw format parsing problems: check `doc_parse/*` first
* structural recovery problems: check `convert/*` first
* output form and sidecar problems: check `core/*` first
* acceptance or regression issues: check `samples/*` first

## Completed Stabilization Phase

This phase consolidated the OOXML infrastructure, native PDF parsing
substrate, and PDF conversion pipeline without changing the public metadata
sidecar schema or the expected Markdown sample outputs.

### OOXML infrastructure

The shared OOXML layer now provides:

* package query helpers for opening packages, listing parts, checking part
  existence, reading part bytes, and querying content types
* typed relationship parsing with internal/external target handling and
  relationship lookup helpers
* media asset indexing for `word/media`, `ppt/media`, and `xl/media`
* lightweight `docProps/core.xml` and `docProps/app.xml` extraction
* read-only package dump APIs for inspection
* document-property propagation into the metadata sidecar `document` section
* README and package-level responsibility documentation that separates ZIP,
  OOXML shared infrastructure, and format-specific recovery code

### Link IR constraints

HTML, DOCX, and PPTX external hyperlink preservation should converge on the
same IR and emitter contract:

* Preserved hyperlinks use `Inline::Link(text, href)`.
* The Markdown emitter renders link IR as `[text](href)`.
* Supported sources are HTML `<a href>`, DOCX external `w:hyperlink r:id`
  document relationships, PPTX run-level `a:hlinkClick r:id` slide
  relationships, and PPTX basic shape-level hyperlink fallback.
* Missing `href`, missing `r:id`, missing relationships, empty targets,
  internal anchors/bookmarks, actions, macros, and media links must downgrade to
  plain text when text is available.
* Relationship parsing must be cached at the document/slide boundary. Do not
  re-read `.rels` per hyperlink node.
* PDF annotation/link records are available through `pdf_core` and convert
  debug/inspection surfaces, but default PDF Markdown output must not emit
  annotation links until bbox/text matching is designed and validated.

### DOCX conversion constraints

DOCX conversion is implemented in `convert/docx` on top of the shared OOXML
package and relationship infrastructure. Keep the following constraints in
place when changing that path:

* External DOCX hyperlinks are represented in the unified IR as
  `Inline::Link(text, href)`. Markdown emission should flow through the normal
  rich-inline path rather than ad-hoc string rendering.
* `word/_rels/document.xml.rels` must be read at most once per document parse.
  Build a document relationship context once and pass it through paragraph,
  inline, image, and hyperlink recovery.
* Hyperlink parsing must not re-read `document.xml.rels` per hyperlink node.
  Relationship lookup should use the cached document relationship context.
* The paragraph inline scanner should remain approximately linear in the
  paragraph XML size. Avoid nested full-paragraph rescans per inline node or per
  hyperlink.
* `scan_paragraph` should not do both a rich-inline scan and a separate
  `collect_wt_text` pass for the same paragraph. The rich-inline scanner should
  return both inline nodes and plain text when both are needed.
* `word/styles.xml` is lazy/gated: read and parse it only when `document.xml`
  contains `<w:pStyle`. Documents with no paragraph style markers should use an
  empty/default styles context and must not fail because styles were skipped.

### PPTX conversion constraints

PPTX conversion is implemented in `convert/pptx` on top of the shared OOXML
package and relationship infrastructure. Keep the following constraints in
place when changing that path:

* External PPTX run-level hyperlinks are represented as
  `Inline::Link(text, href)` from `a:hlinkClick r:id`.
* Basic shape-level hyperlink fallback may wrap the whole shape text only when
  the shape has one clear external hyperlink and no run-level link was already
  recovered.
* `ppt/slides/_rels/slideN.xml.rels` must be read at most once per slide parse.
  Build a slide relationship context once and pass it to text, shape, image,
  and hyperlink recovery.
* Hyperlink parsing must not re-read slide relationships per run or per shape.
  Relationship lookup should use the cached slide relationship context.
* Internal anchors/bookmarks, actions, macros, media links, missing
  relationships, and empty targets should stay as plain text.

### PDF Core infrastructure

The native PDF substrate now provides:

* vendored `mbtpdf` backend integration behind `doc_parse/pdf_core/api`
* source-aware operator parsing and source reference propagation
* page geometry exposure including media box, inherited crop box, rotation,
  raw page refs, and raw content stream refs
* raw image extraction with payload, placement bbox, object refs, filters, and
  source refs
* raw annotation/link extraction with URI, destination, bbox, object ref, and
  source refs
* raw adapter decomposition so text, images, and annotations remain inspectable
  without forcing final Markdown semantics in the parsing layer
* debug inspect output for document, page, text, image, annotation, and geometry
  diagnostics

### PDF Convert pipeline

The default PDF conversion path now has explicit stage boundaries:

* heading recovery is finalized in `classify`, so `to_ir` no longer re-opens
  the heading/noise/paragraph classification decision
* cross-page paragraph merge is layered through hard blockers, positive text
  continuation, layout compatibility, and core-derived continuation support
* repeated edge noise cleanup uses repeated head/tail detection with page box
  top/bottom zones
* `PdfConvertBlock` retains source core block provenance and block-level flags
  for debug and future enhancement work while preserving the default line-seed
  one-line-one-block strategy
* image provenance is available in PDF pipeline debug, including image filter,
  object ref, inline-image marker, dimensions, placement bbox, and source-ref
  count
* annotation/link records are visible in PDF pipeline debug, but are not emitted
  as Markdown links by default
* single-image caption pairing is bbox-gated and remains conservative; ambiguous
  cases are intentionally left unmatched

## Current Boundaries

The following remain unsupported or intentionally disabled by default:

* PDF multi-image caption pairing
* PDF annotation/link Markdown emission
* PDF outline/bookmark extraction into Markdown or metadata output
* PDF complex table recovery
* OCR as a formally closed default path
* broad new-format expansion beyond the current docx/pdf/xlsx/pptx/html/csv/tsv/json/markdown/yaml set

## Next Candidate Routes

Recommended order for the next expansion phase:

1. EPUB
2. RTF
3. ODT / ODS / ODP

Rationale:

* EPUB is valuable but requires package/navigation/content stitching.
* RTF and OpenDocument formats are broader parser investments and should follow
  after the lighter routes.

```
