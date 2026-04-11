# markitdown-mb (MoonBit)

`markitdown-mb` is a MoonBit-based document conversion project focused on a single pipeline:

```text
DOCX / PDF / XLSX / PPTX / HTML -> IR -> Markdown
```

This project is **already beyond MVP**. The current stage is:

- stable end-to-end conversion across five formats,
- sample-based regression and format-specific checks,
- continued targeted improvements (especially PDF + PPTX heuristics),
- ongoing infrastructure ownership (self-managed OOXML/ZIP foundation).

---

## 1) Project Introduction

### What this project is

`markitdown-mb` converts multiple office/web document types into a shared internal IR (`core/ir.mbt`) and then emits Markdown (`core/emitter_markdown.mbt`).

### Current maturity

This is not a prototype-only repository anymore. It has:

- a production-like CLI entry (`cli/`),
- per-format conversion packages under `convert/`,
- owned parsing layers under `doc_parse/` (including `pdf_core` and OOXML/ZIP),
- sample and expected-output regression assets under `samples/`.

---

## 2) Current Capabilities (by format)

## DOCX

Current DOCX conversion includes:

- paragraph and heading extraction,
- heading recovery from styles metadata,
- list recovery from numbering metadata,
- ordered / unordered / nested / mixed list patterns,
- blockquote and code-like paragraph scenarios (heuristic-driven, sample-constrained),
- table extraction including multiline cell cases,
- inline line-break / tab scenarios,
- media relationship resolution and image export to output assets directory.

Notes:

- Some semantic decisions (especially code-like paragraph interpretation) are still heuristic and validated by sample regression.

## PDF

### A) Current PDF capability (user-facing)

- Text-based PDF conversion is supported and is the current primary path.
- Structure recovery works for many practical cases (headings, paragraphs, list-like content, page-noise cleanup, cross-page merge heuristics), but remains heuristic.
- OCR is present as an optional fallback path (`--ocr`) but **is not the primary project direction**.
- Hard layouts (complex multi-column reading order, heavy typography variance, difficult encoding/font maps) still have known limits.

### B) Current PDF architecture (developer-facing)

PDF is split into two layers with explicit responsibility boundaries:

1. `doc_parse/pdf_core` (parse + signal layer)
   - parses PDF objects/streams/fonts and emits event-level text signals,
   - produces page/document stats (`is_empty`, `is_low_signal`, `is_fatal`, stream/page health),
   - now serves as a reusable event-based base for future converter work.

2. `convert/pdf` (conversion + structure recovery layer)
   - consumes extracted text/events and performs cleanup + block reconstruction,
   - applies heading/list/paragraph and page-level heuristics,
   - emits IR blocks for Markdown output.

Validation focus has shifted:

- legacy flattened Markdown regression is still useful as reference,
- but `pdf_core_check` (`check-pdf-core`, `check-pdf-core-set`) is now a key signal-quality gate.

Current `pdf_core` status:

- healthy and usable,
- event granularity and provenance are much better than earlier phases,
- still not a perfect "all information faithfully preserved" layer,
- intended as the foundation for the next `pdf_convert` iteration.

## XLSX

Current XLSX conversion includes:

- workbook/sheet discovery,
- multi-sheet output,
- sparse sheet trimming and table bounding behavior,
- basic cell types (shared string, inline string, number, bool, string result, error),
- lightweight date/time/datetime formatting for common built-in/custom number formats.

Known boundaries:

- no formula evaluation engine,
- merged-cell semantics are limited.

## HTML

Current HTML conversion includes:

- heading / paragraph / list / quote / code / table block recovery,
- `<br>` variants and related block/inline boundary cases,
- nested list scenarios,
- ragged-row table handling,
- mixed-content sample coverage for paragraph/list/quote/table boundaries.

Known boundaries:

- some mixed block-content and nuanced `<br>` semantics still have room for refinement.

## PPTX

PPTX is one of the most actively heuristic modules and has undergone substantial modularization.

Current capabilities include:

- slide-order recovery from presentation relationships,
- title/body split and title promotion heuristics,
- bullet-property-first list recovery (with textual bullet fallback),
- ordered/nested list handling,
- paragraph cleanup and noise filtering,
- shape-based reading-order recovery,
- note-like / caption-like grouping,
- local table-like/grid-like stabilization,
- tightened table-like candidate and region heuristics,
- boundary control via both positive and negative samples.

This module is fairly capable but intentionally conservative in hard ambiguous layouts.

---

## 3) Architecture and Package Layout

Current repository layout (top-level):

```text
cli/                  # CLI app and checks
core/                 # IR + markdown emitter + shared app-level types
convert/
  convert/            # dispatcher (extension -> format parser)
  docx/
  pdf/
  xlsx/
  html/
  pptx/
doc_parse/
  zip/                # self-managed ZIP reader/codec layer
  ooxml/              # OOXML package abstraction on top of zip
  pdf_core/           # native PDF parse/signal extraction
doc_parse/*/tests/    # parser-focused tests
samples/              # cross-format input and expected markdown regression assets
```

### Core/common

- `core/ir.mbt`: unified block-level IR (`Heading`, `Paragraph`, `ListItem`, `Table`, `Image`, etc.).
- `core/emitter_markdown.mbt`: IR -> Markdown rendering.
- `core/errors.mbt`, `core/tool.mbt`: shared error/util behavior used by CLI and converters.

### OOXML foundation

- `doc_parse/zip`: internal ZIP access implementation.
- `doc_parse/ooxml`: OOXML package/part abstraction.
- `convert/docx`, `convert/xlsx`, `convert/pptx` all import `doc_parse/ooxml`.

This means DOCX/XLSX/PPTX currently run on repository-owned OOXML/ZIP layers (not an external zipmin package in this tree).

### PDF split

- `doc_parse/pdf_core`: low-level/native parsing + event extraction + stats.
- `convert/pdf`: cleanup/enhancement/structure reconstruction.

### PPTX modularized subareas (selected)

- geometry and shape collection (`pptx_geom`, `pptx_shape_collect`),
- grouping and candidates (`pptx_group_candidates`, `pptx_grouping`),
- reading-order and table-like heuristics (`pptx_reading_order`, `pptx_table_like`),
- paragraph metadata/classification (`pptx_paragraph_meta`, `pptx_classify`).

### CLI

- `cli/main.mbt`: command registration and argument parsing.
- `cli/cli_app.mbt`: command execution, conversion orchestration, pdf_core checks.

---

## 4) Sample / Regression / Check System

## A) What the sample system is for

The `samples/` system is the practical quality baseline:

- `samples/<format>/` stores input fixtures,
- `samples/expected/<format>/` stores expected Markdown,
- scripts validate enrollment consistency and conversion diffs.

This provides stable regression guardrails during heuristic evolution.

## B) Current sample coverage

Below are representative covered scenarios by format (from current fixture names).

### DOCX sample coverage

- headings (`docx_heading_levels`),
- list variants: basic/mixed/nested/ordered (`docx_list_*`),
- paragraph edge cases: line-break / tab (`docx_paragraph_linebreak`, `docx_paragraph_tab`),
- blockquote and code-like paragraphs (`docx_blockquote_basic`, `docx_codeblock_basic`, `docx_not_code_*`),
- tables and multiline cells (`docx_table_multiline_cell`),
- golden integrated sample (`golden.docx`).

### PDF sample coverage

Two validation tracks coexist:

1. Conversion-side markdown regression (`samples/pdf/*.pdf` + `samples/expected/pdf/*.md`), including:
   - `text_simple`, `text_multipage`, `text_hardwrap`,
   - `hardwrap_en`, `hardwrap_zh`,
   - `heading_basic`, `heading_vs_short_sentence`, `not_heading_sentence`,
   - repeated header/footer variants,
   - cross-page merge positive/negative cases,
   - table/two-column negative and other phase fixtures.

2. Core signal checks (`pdf_core_check`) with grouped sets:
   - `smoke`,
   - `decode`,
   - `signal`.

Important: legacy PDF markdown regression remains useful, but `pdf_core_check` is now a primary signal-quality entry for native extraction health.

### XLSX sample coverage

- simple sheet,
- multi-sheet mixed content,
- sparse edges / sparse trimming,
- empty sheet,
- cell type matrix,
- date/time/datetime and built-in format variants.

### HTML sample coverage

- basic paragraphs/headings,
- quote/blockquote families,
- ordered and nested lists,
- `<br>` variants (including quote/table interactions),
- mixed inline/block boundaries,
- basic and ragged tables.

### PPTX sample coverage

Includes broad positive and negative sets:

- slide ordering, title/body split, title multiline/bullets,
- bullet-property and bullet-level behavior,
- two-column and two-body layouts,
- note clusters / side notes / footer page-number cases,
- callout/caption scatter patterns,
- card-pair patterns (including two-group and side-note variants),
- table-like strong positives (`2x3`, `3x3_header`, regional/local cases),
- candidate/region negatives (`keyword_grid`, `timeline`, `icon_caption_grid`, `cards_*`, `two_column_*`, etc.).

This positive+negative design is intentional to constrain over-generalization.

## C) Check commands

General sample consistency + full conversion diff:

```bash
bash samples/check_samples.sh
bash samples/diff.sh
```

PDF conversion regression only:

```bash
bash samples/pdf_regression_check.sh
```

PDF core grouped checks:

```bash
bash samples/pdf_core_check.sh
# internally runs: smoke / decode / signal
```

---

## 5) CLI Usage

## Basic conversion

```bash
moon run cli -- convert <input-file> [-o output.md] [--out-dir out]
```

Supported input extensions at dispatch layer:

- `.docx`
- `.pdf`
- `.xlsx`
- `.pptx`
- `.html` / `.htm`

## Common options

For `convert`:

- `-o <file>`: write markdown to file (default stdout).
- `--out-dir <dir>`: output directory for assets/debug files (default `out`).
- `--max-heading <1..6>`: maximum heading level emitted (default `3`, clamped to `1..6`).
- `--ocr [1|true|on|yes]`: optional OCR enhancement mode for PDF (compat/fallback path, not primary direction).
- `--debug <modes>`: debug modes (`extract`, `dump-raw`, `pipeline`, `all`; comma-separated supported).

## PDF-specific CLI commands

- `debug-pdf-events <input.pdf>`
  - dumps text-op -> event -> pretty text layers per page.
- `check-pdf-core <input.pdf>`
  - runs single-file native signal health checks.
- `check-pdf-core-set <smoke|decode|signal>`
  - runs grouped sample checks.

Helper script:

- `samples/pdf_core_check.sh` runs all three groups in sequence.

## Example commands

```bash
# 1) Regular conversion
moon run cli -- convert samples/docx/golden.docx -o out/golden.md --out-dir out

# 2) PDF conversion with pipeline debugging
moon run cli -- convert samples/pdf/text_simple.pdf -o out/text_simple.md --debug extract,pipeline --out-dir out

# 3) Full sample diff regression
bash samples/diff.sh

# 4) Single-file pdf_core signal check
moon run cli -- check-pdf-core samples/pdf/text_simple.pdf

```

---

## 6) Current Stage and Maturity Summary

Current practical status:

- **DOCX / XLSX / HTML**: broadly stable for covered scenarios.
- **PPTX**: strong progress with modular heuristics and extensive scenario coverage; still an active optimization area.
- **PDF**: `pdf_core` native signal layer is now established and usable; conversion layer continues evolving and should be iterated with `pdf_core` as input base.

Project-level summary:

- beyond MVP,
- stable mainline conversion,
- focused iterative enhancement,
- continued parser infrastructure ownership and cleanup.

---

## 7) Known Limits and Current Boundaries

## PDF

- OCR is optional and not the main strategic path.
- Complex font/encoding/ToUnicode edge cases still exist.
- Complex layouts (dense multi-column, unusual reading order, heavily mixed objects) can degrade structure quality.
- New `pdf_convert` direction is still under active iteration.

## PPTX

- table-like detection is heuristic (not full semantic table understanding).
- highly irregular slide layouts may still need additional sample constraints.

## DOCX

- style/numbering-dependent recovery can vary on non-standard authoring patterns.
- code-like paragraph recognition is heuristic, not a full semantic code detector.

## XLSX

- no formula recalculation.
- merged-cell semantics and advanced Excel rendering behaviors are limited.

## HTML

- some complex mixed block/inline nesting and nuanced `<br>` interpretation still need refinement.

---

## 8) Roadmap

## Short-term

- continue `pdf_convert` rework on top of `pdf_core` event signals,
- incrementally enrich `pdf_core` high-value signals without destabilizing mainline,
- keep README/sample/check documentation synchronized with actual behavior,
- continue HTML mixed-content / `<br>` semantics refinement,
- continue PPTX region/block heuristics and negative-case hardening.

## Mid-term

- broaden native text-PDF coverage to reduce fallback dependence,
- continue reducing legacy/compat complexity around PDF flow,
- improve richer structure reconstruction into IR while preserving stability.

---

## 9) Development and Validation Workflow

Recommended baseline before commit:

```bash
moon info
moon fmt
moon check
moon test
```

When behavior changes intentionally:

```bash
moon test --update
```

Regression/check workflow:

```bash
# 1) enrollment consistency
bash samples/check_samples.sh

# 2) all-format regression
bash samples/diff.sh

# 3) pdf markdown regression
bash samples/pdf_regression_check.sh

# 4) pdf native/core signal checks
bash samples/pdf_core_check.sh
```

Format-focused validation hints:

- DOCX changes: start with `samples/docx/` list/heading/table/paragraph-edge fixtures.
- PDF changes:
  - conversion heuristics -> `samples/pdf_regression_check.sh`,
  - signal/extraction layer -> `check-pdf-core` and `check-pdf-core-set`.
- XLSX changes: verify sparse/cell-type/date-time fixtures.
- HTML changes: verify `<br>`, nested list, quote/table mixed boundary fixtures.
- PPTX changes: run positive + negative table-like and reading-order fixtures together.

---

## 10) Notes for Hand-off

If you are taking over this codebase:

1. Treat `samples/` as the first-line contract.
2. Keep PDF layer boundaries explicit (`pdf_core` vs `convert/pdf`).
3. Keep PPTX heuristics constrained by both positive and negative fixtures.
4. Update this README whenever command behavior, architecture boundaries, or sample/check workflows change.
