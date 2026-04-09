# markitdown-mb (MoonBit)

A **MoonBit** (markitdown-like) document conversion tool that turns **.docx / .pdf / .xlsx / .pptx / .html** into structured **Markdown**.

> Current status: the project has moved well beyond the initial MVP stage and now provides a stable multi-format **document → IR → Markdown** pipeline with sample-based regression coverage across **docx / pdf / xlsx / pptx / html**. Recent PPTX work has also completed a full round of layout-oriented heuristic stabilization plus new regression-sample expansion, and the full suite is currently green.

---

## Features

* ✅ **Docx → Markdown**: headings, paragraphs, tables, image extraction & references, style/numbering-driven list structure recovery, paragraph line-break preservation, and code-like paragraph recovery under the current heuristic rules
* ✅ **PDF (text-based) → Markdown**: extract text via external tools (Poppler / MuPDF), select the best candidate output heuristically, then apply page-noise cleanup, repeated header/footer removal, heading/paragraph boundary recovery, cross-page paragraph merging, and basic list-item recovery
* ✅ **XLSX → Markdown**: extract workbook sheets as Markdown tables, with multi-sheet output, sparse-table trimming, minimal non-empty bounding-box cropping, empty-sheet handling, basic cell-type support, and lightweight date/time formatting for style-marked numeric cells
* ✅ **PPTX → Markdown**: extract slide text by shape, preserve real slide order via `presentation.xml`, recover title/body structure, restore bullet lists with nesting levels, restore ordered lists from numbering-aware bullet properties, merge multi-paragraph title shapes, clean up empty / duplicate paragraph noise, apply shape-layout reading-order recovery, keep note-like / caption-like text regions more stable in output order, stabilize local table-like / grid-like text regions before Markdown emission, use tighter table-like candidate heuristics backed by both positive and negative regression samples, let accepted table-like regions absorb aligned edge/header candidate cells through existing row/column buckets, and now cover callout / scatter / negative-card / row-jitter layout boundaries through expanded PPTX regression samples
* ✅ **HTML → Markdown**: extract headings / paragraphs / list items / block quotes / code blocks / tables, preserve common `<br>` variants, preserve ordered / unordered / nested list structure, avoid swallowing nested list text in parent items, add lightweight inline modeling for HTML text spans and explicit break semantics, and recover multi-block structure inside block quotes and list items
* ✅ **IR (Intermediate Representation) + Markdown emitter**: a unified output structure that makes future format/layout extensions easier

> Note: this project intentionally avoids unstable or opaque parsing dependencies where practical, keeps format handling in small MoonBit packages with explicit heuristics, and uses external system tools when that is the most reliable current engineering trade-off.

---

## Project Status

The project is no longer just a minimal proof of concept.

Current state:

* ✅ **Unified multi-format pipeline**: **docx / pdf / xlsx / pptx / html → IR → Markdown** is implemented and regression-tested
* ✅ **Sample-based regression suite** is in place and used as the primary behavior guardrail
* ✅ **DOCX / XLSX / HTML** are already at relatively high completeness for the current project scope
* ✅ **PDF / PPTX** have moved beyond simple text extraction and now include structure-oriented recovery heuristics
* ✅ **PPTX** has completed a major round of layout-oriented stabilization, including shape-order recovery, conservative title fallback, noise cleanup, note-like grouping, two-column-aware reading-order recovery, local table-like/grid-like text-region stabilization, tighter table-like candidate filtering checked by both positive and negative samples, conservative accepted-region expansion for missed edge/header table-like candidate cells, and new regression-backed coverage for callout / scatter / negative-card / row-jitter layouts
* ✅ **HTML** has moved beyond a flat text-only block model and now includes lightweight inline modeling plus local container recovery for block quotes and list items
* ✅ **Recent package cleanup**: DOCX and PPTX source layout has been reorganized into smaller MoonBit modules so the format-specific logic is easier to maintain and extend

---

## Repository Layout (current)

The source tree is organized into small MoonBit packages, with conversion logic split by format and shared infrastructure kept in `core`.

* `src/cli/`: command-line entry package

  * `cli_app.mbt`: top-level CLI app flow
  * `cli_args.mbt`: argument parsing / option decoding
  * `main.mbt`: executable entry
  * `moon.pkg`: package definition
* `src/convert/`: conversion dispatch package

  * `dispatcher.mbt`: routes input files to the correct parser by format / extension
  * `moon.pkg`: package definition
* `src/core/`: shared core infrastructure

  * `ir.mbt`: shared IR definitions (`Document` / `Block`)
  * `emitter_markdown.mbt`: IR → Markdown emission
  * `errors.mbt`: shared error definitions
  * `tool.mbt`: shared utilities
  * `zip_min.mbt`: minimal ZIP reader / ZIP helpers used by Office-family handling
  * `moon.pkg`: package definition
* `src/docx/`: DOCX parsing package

  * `docx_parser.mbt`: orchestrated `parse_docx()` entry
  * `docx_document.mbt`: document-level scan / assembly into IR
  * `docx_package.mbt`: DOCX package/ZIP access helpers
  * `docx_rels.mbt`: relationship parsing (`rId → Target`)
  * `docx_styles.mbt`: `word/styles.xml` parsing for heading-level resolution and paragraph-style name lookup
  * `docx_numbering.mbt`: `word/numbering.xml` parsing for ordered / unordered / nested lists
  * `docx_table.mbt`: table extraction logic
  * `docx_xml.mbt`: lower-level XML scanning helpers
  * `docx_types.mbt`: DOCX-local shared types used across document / numbering / styles / table logic
  * `moon.pkg`: package definition
* `src/html/`: HTML parsing package

  * `html_parser.mbt`: top-level HTML parse entry
  * `html_bytes.mbt`: byte-level HTML traversal helpers
  * `html_dom.mbt`: lightweight HTML structure / inline / local-container recovery layer
  * `html_to_ir.mbt`: HTML structure → shared IR
  * `moon.pkg`: package definition
* `src/pdf/`: PDF parsing package

  * `pdf_parser.mbt`: top-level PDF parse entry
  * `pdf_extract.mbt`: external-tool text extraction orchestration
  * `pdf_extract_score.mbt`: extractor candidate scoring and best-output selection
  * `pdf_page.mbt`: page splitting / page-break marker / cleaned-page merging helpers
  * `pdf_noise.mbt`: page-number detection, repeated header/footer detection, and page-noise stripping
  * `pdf_block.mbt`: block splitting and block-level recovery flow
  * `pdf_heading.mbt`: heading heuristics and heading-level inference
  * `pdf_list.mbt`: PDF list-item detection and list-item parsing helpers
  * `pdf_text.mbt`: shared PDF text utilities and normalization helpers
  * `pdf_to_ir.mbt`: PDF pipeline orchestration and shared IR mapping
  * `moon.pkg`: package definition
* `src/pptx/`: PPTX parsing package

  * `pptx_parser.mbt`: top-level PPTX parse entry
  * `pptx_package.mbt`: PPTX package/ZIP access helpers
  * `pptx_rels.mbt`: presentation / relationship helpers
  * `pptx_bytes.mbt`: byte / XML scanning helpers
  * `pptx_text.mbt`: text-run extraction helpers
  * `pptx_types.mbt`: PPTX-local shared types (`SlideShape` / `LayoutShape` / group / paragraph metadata)
  * `pptx_geom.mbt`: shared shape-geometry helpers (gap / overlap / min-max utilities)
  * `pptx_shape_collect.mbt`: `<p:sp>` collection, geometry extraction, and layout-shape enrichment
  * `pptx_layout_base.mbt`: baseline layout helpers, title-shape split, fallback title promotion, and simple geometric ordering
  * `pptx_group_candidates.mbt`: candidate heuristics for small grouping / caption-like / table-like shape selection
  * `pptx_table_like.mbt`: local table-like / grid-like region detection and stabilization
  * `pptx_grouping.mbt`: body-shape grouping into normal / caption-like / table-like regions
  * `pptx_reading_order.mbt`: reading-order orchestration, two-column handling, row clustering, and final shape-order flattening
  * `pptx_paragraph_meta.mbt`: paragraph-level metadata parsing such as bullet-kind and nesting-level extraction
  * `pptx_slide.mbt`: shape-level paragraph extraction
  * `pptx_classify.mbt`: paragraph classification into heading / paragraph / list-like output structures
  * `pptx_noise.mbt`: conservative page-number / corner-label noise filtering
  * `moon.pkg`: package definition
* `src/xlsx/`: XLSX parsing package

  * `xlsx_parser.mbt`: top-level XLSX parse entry
  * `xlsx_package.mbt`: XLSX package/ZIP access helpers
  * `xlsx_shared_strings.mbt`: shared strings parsing
  * `xlsx_sheet.mbt`: sheet-level extraction
  * `xlsx_styles.mbt`: `xl/styles.xml` parsing for style-index / `numFmtId` / `formatCode`-driven lightweight date/time interpretation
  * `xlsx_datetime.mbt`: shared date / time / datetime formatting helpers used by style-driven XLSX cell interpretation
  * `xlsx_xml.mbt`: XML scanning helpers
  * `moon.pkg`: package definition
* `samples/`: sample files & regression scripts

  * `docx/` / `pdf/` / `xlsx/` / `pptx/` / `html/`: format-specific samples
  * `expected/<format>/`: golden Markdown outputs
  * `diff.sh`: regression script (writes outputs to `.tmp_test_out/<format>/` and diffs against `samples/expected/<format>/`)

---

## What Works (current)

### ✅ Core

* IR definitions and `push` work as expected
* Markdown emitter supports:

  * headings
  * paragraphs
  * ordered / unordered list items
  * nested list indentation
  * block quotes
  * code blocks
  * tables
  * image references
* Markdown output tail is normalized consistently across formats (non-empty output ends with a single trailing newline)

### ✅ Docx Pipeline

* Reads from `.docx`:

  * `word/document.xml`
  * `word/_rels/document.xml.rels`
  * `word/styles.xml`
  * `word/numbering.xml`
  * `word/media/*` (images)
* Exports images to `out/assets/` and references them in Markdown like `![image](assets/xxx.png)`
* Resolves heading levels through style mapping instead of only hard-coded style names
* Recovers list structure using numbering metadata:

  * unordered lists
  * ordered lists
  * nested lists
  * mixed list structures (current Markdown emission preserves level + ordered/unordered shape)
* Preserves paragraph-level manual line breaks into Markdown-friendly output
* Preserves table-cell internal manual line breaks into Markdown-friendly `<br>` output
* Recovers code-like paragraphs under the current conservative rules:

  * paragraph-style name match when available
  * fallback: multi-line text plus explicit code-like token patterns
* Keeps a style-driven blockquote recovery entry point in the parser
* Uses a local DOCX types module to reduce coupling between document / numbering / styles / table logic

> Note: DOCX blockquote recovery is wired into the parsing pipeline, but **real DOCX blockquote-style samples have not been validated yet**. Current list / heading / table / code-like paragraph coverage is backed by regression samples; blockquote-style recovery is not yet backed by a true source-document sample.

### ✅ ZIP / Office-package handling

* A minimal ZIP reader/helper layer is kept in the project for Office-family package access
* The current Office-family handling is intentionally pragmatic:

  * **DOCX** currently works through the in-project package path already used by the parser
  * **XLSX** and **PPTX** currently rely on **external system tools / system unzip behavior** in the current implementation path where needed, because the current decompressed-result shape conflicts with the representation the parser wants to consume directly
* This is an implementation trade-off rather than a long-term architectural preference; future cleanup may further unify Office-package handling once the internal package/decompression representation is aligned with parser needs

### ✅ PDF (text-based)

* Extracts text via external tools and selects the output that best matches reading order / text integrity using a scoring function:

  * `pdftotext` (Poppler): default / `-layout` / `-raw`
  * fallback: `mutool draw -F txt` (MuPDF)
* Applies lightweight normalization and structure recovery:

  * normalize line endings
  * split pages by form-feed and keep page boundaries internal to normalization
  * split paragraphs by blank lines and merge hard wraps
  * recover basic headings under current heuristic rules
  * reduce short-line false positives in heading detection
  * avoid merging obvious new blocks into the previous paragraph
  * recover basic bullet-list items into shared IR list blocks
  * filter page-number noise and repeated page-header/page-footer noise under the current sample set
  * merge cross-page paragraph continuations when the next page starts with continuation text rather than a new block
* Current regression coverage includes:

  * simple text
  * hard-wrap recovery (English / Chinese)
  * heading recovery
  * short-sentence non-heading cases
  * multi-page text
  * repeated header/footer cleanup
  * page-noise cleanup
  * cross-page paragraph merging
  * heading-vs-short-sentence boundary recovery
  * repeated header/footer variants

> Note: `mutool` may print progress info to stderr (for example `page ...`). This project separates stdout/stderr to avoid contaminating extracted text.

### ✅ XLSX

* Parses workbook + sheet XML and emits one Markdown table per sheet
* Supports shared strings, inline strings, numeric/default cells, booleans (`t="b"`), string results (`t="str"`), and error cells (`t="e"`)
* Supports multi-sheet output
* Emits `(empty sheet)` for empty worksheets
* Trims sparse trailing empty rows / columns in current regression samples
* Crops sparse sheets to the minimal non-empty bounding box before Markdown emission
* Decodes XML entities (including numeric entities)
* Interprets style-marked numeric date/time-like cells through `xl/styles.xml`:

  * built-in date/time-like `numFmtId` handling
  * custom `formatCode`-driven lightweight date/time-like detection
  * stable output formatting for date / time / datetime cells under the current regression samples

> Note: XLSX support is already stable at the current project scope, but the package/decompression path still uses external system-tool behavior in the current implementation where the internal decompressed-result representation does not yet match the parser’s preferred input shape.

### ✅ PPTX

* Extracts slide text by shape (`<p:sp>`) and emits one section per slide
* Resolves real slide order through `ppt/presentation.xml` + `presentation.xml.rels`, instead of relying only on slide file name order
* Prefers title placeholders for slide headings, with conservative fallback when needed
* Uses paragraph bullet properties before text-prefix heuristics for list detection
* Restores unordered and ordered list semantics from bullet properties / numbering-aware bullet metadata
* Restores list nesting from `<a:pPr lvl="N">`
* Merges multi-paragraph title-shape text into one heading under the current heuristic rules
* Removes empty paragraphs, bullet-only shells, and adjacent duplicate text
* Decodes XML entities; non-BMP characters are normalized consistently via the shared entity decode path
* Recovers shape-level reading order using layout heuristics:

  * default row-first reading order
  * conservative two-column detection with column-first traversal when appropriate
  * conservative fallback title promotion for non-placeholder top title-like shapes
* Applies conservative PPTX-specific noise filtering:

  * bottom page-number removal
  * corner short-label filtering (`Draft` / `Internal` / `Confidential`-like cases)
* Groups local note-like / caption-like small text shapes to keep them from being fragmented by the main body flow
* Detects simple table-like / grid-like text regions and keeps them stable as one body region during output ordering
* Tightens table-like candidate detection with local neighbor-support checks so isolated short text boxes are less likely to be misclassified as table-like regions
* Accepted table-like regions now run a conservative stabilization pass that absorbs aligned edge/header candidate cells using existing row/column buckets
* Regression coverage for PPTX now includes stronger positives, stronger negatives, and newer layout-oriented boundaries such as:

  * callout blocks
  * mixed-width callout layouts
  * row-jitter callout layouts
  * scatter caption layouts
  * negative card layouts
  * dense negative card grids
* Uses a more explicit internal module split for shape collection, layout base logic, grouping candidates, table-like region detection, grouping, reading-order recovery, and paragraph metadata parsing

> Note: PPTX support is no longer just a basic text-dump path. It now includes shape-order recovery, title/body heuristics, paragraph cleanup, note-like grouping, table-like text-region stabilization, negative-sample-backed tightening around table-like candidate selection, and a broader regression-backed layout heuristic set around callout / scatter / dense-card boundaries. Like XLSX, parts of the current PPTX package/decompression path still rely on external system-tool behavior where the current internal decompressed-result representation conflicts with the parser’s preferred working form.

### ✅ HTML

* Bytes-based parsing to avoid UTF-8 indexing issues
* Extracts headings / paragraphs / list items
* Supports block quotes and preformatted/code blocks
* Supports basic HTML table extraction (`<table>` → IR `Table` → Markdown table)
* Preserves common `<br>` variants as explicit inline break semantics in the HTML-local model and renders them back to stable Markdown/HTML output
* Preserves ordered / unordered / nested list structure under current regression coverage
* Prevents parent `<li>` text from swallowing nested list text in current regression cases
* Uses a lightweight HTML-local inline model so text spans and explicit breaks are no longer carried only as flat strings
* Recovers block-quote containers as local child-block structures instead of flattening them immediately into one text blob
* Recovers list-item containers as local child-block structures so multi-paragraph items, mixed text, and nested lists are handled more conservatively
* Normalizes ragged table rows
* Decodes entities (including numeric entities)

---

## External Dependencies

### PDF

The PDF pipeline relies on at least one of the following command-line tools installed on your system:

* `pdftotext` (Poppler)
* `mutool` (MuPDF toolset)

If neither is available, the program will show a unified error message.

Install examples:

* macOS (Homebrew): `brew install poppler mupdf`
* Ubuntu/Debian: `sudo apt-get install poppler-utils mupdf-tools`
* Arch: `sudo pacman -S poppler mupdf-tools`

### XLSX / PPTX

The current XLSX / PPTX implementation path may also rely on **system unzip / package-extraction behavior** in the working environment.

This is a pragmatic temporary choice: the current in-project decompressed-result representation conflicts with the parser’s preferred internal working shape for these formats, so the implementation currently uses external system-tool behavior where appropriate instead of forcing an unnatural intermediate representation.

---

## Usage

### 1) `demo`: sanity-check the core pipeline

```bash
moon run src/cli -- demo
```

Prints a demo Markdown document (no input required).

### 2) `convert`: convert documents → Markdown

Docx example:

```bash
moon run --target native src/cli -- \
  convert samples/docx/golden.docx \
  -o out/golden.md \
  --out-dir out
```

PDF example:

```bash
moon run --target native src/cli -- \
  convert samples/pdf/text_simple.pdf \
  -o out/text_simple.md \
  --out-dir out
```

XLSX example:

```bash
moon run --target native src/cli -- \
  convert samples/xlsx/sheet_simple.xlsx \
  -o out/sheet_simple.md \
  --out-dir out
```

PPTX example:

```bash
moon run --target native src/cli -- \
  convert samples/pptx/pptx_simple.pptx \
  -o out/pptx_simple.md \
  --out-dir out
```

HTML example:

```bash
moon run --target native src/cli -- \
  convert samples/html/html_simple.html \
  -o out/html_simple.md \
  --out-dir out
```

Options:

* `-o out/xxx.md`: output Markdown path (default: stdout)
* `--out-dir out`: asset output directory (docx images go to `out/assets/`)
* `--max-heading N`: maximum heading level (`1–6`)

---

## Regression Tests (samples)

The script writes conversion outputs to **`.tmp_test_out/`** (grouped by format) and diffs against `samples/expected/<format>/`.

```bash
chmod +x samples/diff.sh
rm -rf .tmp_test_out
./samples/diff.sh
```

Recent regression coverage includes:

* **DOCX**

  * heading levels
  * basic lists
  * ordered lists
  * nested lists
  * mixed lists
  * paragraph manual line breaks
  * table-cell manual line breaks
  * code-like paragraph positive / negative cases
  * images / tables / general golden sample
* **PDF**

  * simple text
  * hard-wrap recovery (English / Chinese)
  * heading recovery
  * short-sentence non-heading cases
  * multi-page text
  * repeated header/footer cleanup
  * page-noise cleanup
  * cross-page paragraph merging
  * heading-vs-short-sentence boundary recovery
  * repeated header/footer variants
* **PPTX**

  * basic slides
  * title + bullets
  * presentation-order slide sequence sample
  * shape-aware title/body handling
  * bullet-property list detection
  * ordered-list recovery from numbering-aware bullet properties
  * bullet levels / cleanup behavior
  * multi-paragraph title-shape merge behavior
  * top-title + multi-box layout behavior
  * note-like grouping behavior
  * table-like/grid-like text-region stabilization
  * local table-like region behavior with surrounding body text
  * `pptx_table_like_local_edge_cell`
  * `pptx_table_like_local_with_side_note`
  * `pptx_table_like_strong_2x3`
  * `pptx_table_like_strong_3x3_header`
  * negative keyword-grid layout
  * negative icon-caption-card-grid layout
  * `pptx_table_like_negative_cards_2x2`
  * `pptx_table_like_negative_cards_2x3_dense`
  * `pptx_table_like_negative_two_column_explainer`
  * negative short two-column label layout
  * page-number / corner-label cleanup behavior
  * `pptx_callout_blocks_basic`
  * `pptx_callout_blocks_mixed_widths`
  * `pptx_callout_blocks_row_jitter`
  * `pptx_caption_scatter_one_real_pair`
  * `pptx_caption_scatter_two_real_pairs`
  * `pptx_caption_scatter_pair_plus_footer_note`
* **HTML**

  * simple content
  * mixed block content
  * block quotes
  * block-quote multi-paragraph / nested / mixed-text container cases
  * pre/code blocks
  * basic tables
  * `<br>` variants
  * ordered lists
  * nested lists
  * mixed nested ordered/unordered lists
  * list-item multi-paragraph / mixed-text / nested-list / quote-in-item cases
  * ragged table rows
* **XLSX**

  * simple sheet
  * sparse trimming
  * cell types
  * multi-sheet mixed workbook
  * empty sheet behavior
  * sparse-edge / bounding-box trimming
  * custom-format date / time / datetime cells
  * built-in date/time-like style handling under current sample coverage

If you update the implementation and confirm the new output is correct, refresh the golden outputs for the corresponding format.

Example: refresh DOCX list golden outputs:

```bash
cp .tmp_test_out/docx/docx_list_ordered.md samples/expected/docx/docx_list_ordered.md
cp .tmp_test_out/docx/docx_list_nested.md  samples/expected/docx/docx_list_nested.md
cp .tmp_test_out/docx/docx_list_mixed.md   samples/expected/docx/docx_list_mixed.md
```

Example: refresh one HTML / XLSX / PPTX / PDF golden file:

```bash
cp .tmp_test_out/html/html_table_basic.md              samples/expected/html/html_table_basic.md
cp .tmp_test_out/xlsx/xlsx_multi_sheet_mixed.md        samples/expected/xlsx/xlsx_multi_sheet_mixed.md
cp .tmp_test_out/pptx/pptx_slide_order.md              samples/expected/pptx/pptx_slide_order.md
cp .tmp_test_out/pdf/pdf_page_noise_cleanup.md         samples/expected/pdf/pdf_page_noise_cleanup.md
```

Then re-run:

```bash
./samples/diff.sh
```

---


## Progress Dashboard (snapshot: 2026-04-09)

### Repository-level quantitative snapshot

* Total MoonBit source files (`*.mbt` under `src/`): **55**
* Package split:

  * `src/cli`: 3
  * `src/convert`: 1
  * `src/core`: 5
  * `src/docx`: 9
  * `src/pdf`: 9
  * `src/xlsx`: 7
  * `src/pptx`: 17
  * `src/html`: 4
* Tooling helpers:

  * `tools/`: 3 Python generators (all for PPTX sample generation)
* Regression assets under `samples/`:

  * input files total: **113**
  * expected markdown total: **115**
  * input/expected parity by format:

    * `docx`: 12 input / 13 expected (`docx_blockquote_basic` currently expected-only)
    * `pdf`: 12 / 12
    * `xlsx`: 12 / 12
    * `pptx`: 45 / 46 (`pptx_right_side_notes` currently expected-only)
    * `html`: 32 / 32

### Coverage completion interpretation (current)

* **DOCX**: high completion for heading/list/table/code-like paragraph and line-break behavior; quote-style validation still needs a true source sample.
* **PDF**: robust text-PDF path with extractor arbitration + noise cleanup + block recovery; still intentionally not OCR/scanned-PDF scope.
* **XLSX**: stable worksheet-table extraction with style-guided date/time handling; broad enough for common export/report workbooks.
* **PPTX**: most actively expanded area in recent history; now has dense positive/negative layout heuristics and broad sample-backed reading-order stabilization.
* **HTML**: from flat text extraction upgraded to local container + inline modeling; nested structures and `<br>` variants are well covered.

## Sample Catalog (what each sample validates)

> Rule of thumb: filename = assertion target. Each sample is a regression contract for one behavior boundary.

### DOCX samples

* `golden`: end-to-end comprehensive baseline (paragraph/list/table/image mix).
* `docx_heading_levels`: heading level mapping from styles.
* `docx_list_basic`: unordered list recovery.
* `docx_list_ordered`: ordered list recovery.
* `docx_list_nested`: nested list levels.
* `docx_list_mixed`: mixed ordered/unordered nesting.
* `docx_paragraph_linebreak`: in-paragraph manual line breaks.
* `docx_paragraph_tab`: tab behavior normalization.
* `docx_table_multiline_cell`: multiline cell rendering with `<br>`.
* `docx_codeblock_basic`: code-like paragraph detection (positive case).
* `docx_not_code_steps`: prevent false-positive code block (step-like text).
* `docx_not_code_multiline`: prevent false-positive code block (multiline normal text).
* `docx_blockquote_basic` (expected-only): reserved contract for quote-style output validation.

### PDF samples

* `text_simple`: basic block extraction.
* `text_hardwrap`: hard-wrap merge baseline.
* `hardwrap_en`: English hard-wrap merge boundary.
* `hardwrap_zh`: Chinese hard-wrap merge boundary.
* `heading_basic`: heading recognition baseline.
* `not_heading_sentence`: avoid treating short sentence as heading.
* `text_multipage`: multi-page continuity baseline.
* `pdf_repeated_header_footer`: repeated header/footer cleanup baseline.
* `pdf_repeated_header_footer_variants`: repeated header/footer variant robustness.
* `pdf_page_noise_cleanup`: page-number / noise cleanup.
* `pdf_cross_page_paragraph`: paragraph continuation across page breaks.
* `pdf_heading_vs_short_sentence`: heading-vs-normal-short-line decision boundary.

### XLSX samples

* `sheet_simple`: one-sheet baseline table extraction.
* `xlsx_multi_sheet_mixed`: multi-sheet ordering and emission.
* `xlsx_cell_types`: cell type matrix (string/number/bool/error/etc.).
* `xlsx_empty_sheet`: explicit empty-sheet output.
* `xlsx_trim_sparse`: sparse trailing row/column trimming.
* `xlsx_sparse_edges`: minimal non-empty bounding-box crop.
* `xlsx_date_basic`: custom-format date output.
* `xlsx_time_basic`: custom-format time output.
* `xlsx_datetime_basic`: custom-format datetime output.
* `xlsx_builtin_date_14`: built-in date `numFmtId` path.
* `xlsx_builtin_time_20`: built-in time `numFmtId` path.
* `xlsx_builtin_datetime_22`: built-in datetime `numFmtId` path.

### HTML samples

* `html_simple`: baseline heading/paragraph/list extraction.
* `html_mixed`: mixed block composition baseline.
* `html_quote`: blockquote baseline.
* `html_pre`: pre/code block baseline.
* `html_table_basic`: basic table extraction.
* `html_table_ragged_rows`: ragged-row normalization.
* `html_br_variants`: `<br>` variant normalization.
* `html_br_double`: consecutive `<br>` behavior.
* `html_br_table`: `<br>` inside table context.
* `html_br_blockquote`: `<br>` inside blockquote context.
* `html_blockquote_list_basic`: list inside blockquote.
* `html_blockquote_multi_paragraph`: multi-paragraph blockquote container.
* `html_blockquote_nested_blockquote`: nested blockquote handling.
* `html_blockquote_mixed_text_and_paragraph`: mixed text + paragraph in blockquote.
* `html_blockquote_mixed_tail`: blockquote tail text handling.
* `html_blockquote_br_inside_paragraph`: `<br>` in blockquote paragraph.
* `html_ordered_list`: ordered list baseline.
* `html_nested_list_basic`: nested list baseline.
* `html_nested_list_mixed`: mixed ordered/unordered nesting.
* `html_listitem_multi_paragraph`: multi-paragraph list item.
* `html_listitem_mixed_text_and_paragraph`: list item mixed inline/block text.
* `html_listitem_with_blockquote`: blockquote embedded in list item.
* `html_list_item_mixed_tail`: list item tail text boundary.
* `html_list_item_inline_split_noise`: inline split/noise robustness in list item.
* `html_inline_mixed_paragraph`: inline span mixing inside paragraph.
* `html_inline_mixed_list`: inline span mixing inside list item.
* `html_inline_mixed_table`: inline span mixing inside table cell.
* `html_inline_boundary_paragraph`: inline boundary normalization for paragraph.
* `html_block_boundary_pre`: block boundary around pre/code.
* `html_block_boundary_quote`: block boundary around blockquote.
* `html_block_boundary_table`: block boundary around table.
* `html_block_boundary_paragraph_list`: paragraph/list boundary behavior.

### PPTX samples

#### Core structure / reading-order

* `pptx_simple`: single-slide baseline.
* `pptx_slide_order`: real presentation order vs filename order.
* `pptx_title_multiline`: multi-paragraph title merge.
* `pptx_title_bullets`: title + bullet body baseline.
* `pptx_title_body_split`: title/body segmentation.
* `pptx_top_title_multi_boxes`: top-title with multi-box body order.
* `pptx_two_columns`: two-column reading-order behavior.
* `pptx_two_body_left_right`: left-right two-body layout.
* `pptx_two_body_top_bottom`: top-bottom two-body layout.
* `pptx_two_note_clusters`: multiple note clusters ordering.
* `pptx_small_grouped_notes`: small note-like grouping behavior.
* `pptx_right_side_notes` (expected-only): right-side note-region stabilization contract.

#### Lists / bullets / numbering

* `pptx_bullet_levels`: nested bullet level recovery.
* `pptx_bullet_property`: bullet-property-driven classification.
* `pptx_ordered_list`: ordered list recovery from numbering metadata.

#### Callout / caption / scatter layouts

* `pptx_callout_blocks_basic`: regular callout block grouping.
* `pptx_callout_blocks_mixed_widths`: uneven-width callout rows.
* `pptx_callout_blocks_row_jitter`: row jitter tolerance for callouts.
* `pptx_caption_scatter_one_real_pair`: sparse caption scatter with one true pair.
* `pptx_caption_scatter_two_real_pairs`: scatter with two true pairs.
* `pptx_caption_scatter_pair_plus_footer_note`: scatter pair plus footer-note separation.
* `pptx_negative_caption_scatter`: negative sample for scatter mis-detection.

#### Table-like / grid-like region heuristics

* `pptx_table_like_region_basic`: table-like region baseline.
* `pptx_table_like_region_local_basic`: local table-like region baseline.
* `pptx_table_like_region_local_with_intro_outro`: local region with intro/outro text.
* `pptx_table_like_local_with_side_note`: local table-like with side note.
* `pptx_table_like_local_edge_cell`: edge-cell absorption behavior.
* `pptx_table_like_header_edge_basic`: header-edge candidate inclusion baseline.
* `pptx_table_like_header_edge_with_note`: header-edge with note interference.
* `pptx_table_like_strong_2x3`: strong positive 2x3 grid.
* `pptx_table_like_strong_3x3_header`: strong positive 3x3+header grid.
* `pptx_table_like_negative_keyword_grid`: keyword wall should not be table.
* `pptx_table_like_negative_icon_caption_grid`: icon-caption card grid negative case.
* `pptx_table_like_negative_header_cards`: header + cards negative case.
* `pptx_table_like_negative_cards_with_badge`: badge cards negative case.
* `pptx_table_like_negative_cards_2x2`: dense card matrix negative 2x2.
* `pptx_table_like_negative_cards_2x3_dense`: dense card matrix negative 2x3.
* `pptx_table_like_negative_two_column_explainer`: two-column explainer negative case.
* `pptx_table_like_negative_two_column_labels`: short two-column labels negative case.
* `pptx_table_like_negative_timeline`: timeline layout negative case.

#### Card/group pattern heuristics

* `pptx_card_pairs_basic`: basic card-pair grouping.
* `pptx_card_pairs_two_groups`: multi-group card pairs.
* `pptx_card_pairs_two_rows_three_cols`: dense card pairs in 2-row/3-col layout.
* `pptx_card_pairs_with_side_note`: card pairs with side-note interference.
* `pptx_negative_dense_keyword_wall`: dense keyword wall negative grouping case.

#### Noise filtering

* `pptx_footer_page_number`: page-number/footer noise filtering.


## Roadmap

### Near-term

1. Shift the next round of work from PPTX to **HTML mixed block content / `<br>` semantics**
2. Continue strengthening HTML body-scope handling and local container rendering around block quotes / list items without regressing current behavior
3. Extend XLSX validation coverage for built-in date/time `numFmtId` cases and more real-world workbook samples
4. Extend DOCX style-driven block recovery beyond headings/lists with true source-document validation for quote-like styles
5. Continue widening PDF validation coverage for difficult but still text-based layouts

### Mid-term

1. Unify more structure-aware behavior across formats through the shared IR
2. Improve PDF handling for more difficult layouts
3. Revisit Office-package extraction unification once the internal decompressed-result representation can better match parser needs for XLSX / PPTX
4. Later: scanned PDFs (OCR + basic layout recovery), likely still via external tools first

---

## Status

* ✅ **docx**: stable structured conversion with style-driven headings, numbering-driven lists, paragraph/table-cell line-break preservation, image export, conservative code-like paragraph recovery, and a cleaner local package split with shared DOCX types
* ✅ **pdf (text-based)**: stable extractor-selection pipeline with heading/paragraph cleanup, list-item recovery, repeated header/footer removal, page-noise filtering, cross-page paragraph merging, and heuristic block-boundary recovery
* ✅ **xlsx**: stable table-oriented workbook conversion with multiple cell types, multi-sheet support, empty-sheet handling, sparse bounding-box trimming, and lightweight style-driven date/time interpretation
* ✅ **pptx**: stable shape-oriented conversion with real presentation-order traversal, title/body handling, ordered/unordered list recovery, nested list levels, multi-paragraph title merge, paragraph cleanup, layout-based reading-order recovery, conservative noise filtering, note-like grouping, table-like text-region stabilization, tighter candidate filtering guarded by positive/negative layout samples, and a broader regression-backed layout heuristic set around callout / scatter / dense-card boundaries
* ✅ **html**: stable bytes-based HTML conversion with lists / quotes / code blocks / tables, explicit `<br>` break preservation, lightweight inline modeling, local blockquote/list-item container recovery, ordered/nested-list structure recovery, parent-item protection, and ragged-row table normalization
* ✅ **IR + Markdown emitter**: shared structured output path across formats
