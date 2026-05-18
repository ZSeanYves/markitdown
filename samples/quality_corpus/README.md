# Quality Corpus

This directory contains a signal-level quality corpus for repository-local
quality intake.

It is intentionally different from the existing sample surfaces:

* `./samples/check.sh` remains the exact regression gate
* `samples/quality_corpus/` is signal-level intake, not an exact diff

Purpose:

* provide a framework for external/public/private real quality samples
* express real-world quality expectations as signals instead of full-output oracles
* support private local samples that must not be committed
* allow optional tool comparison without treating external tools as oracles

Current scope:

* public `manifest.tsv` is intentionally empty until external rows are manually curated
* private local rows are supported through `private/manifest.local.tsv`
* external source candidates are tracked in `external_sources.tsv`
* local external rows are supported through `external_manifest.local.tsv`
* local caches are expected under `.external/quality_corpus/...`

Current limitations:

* this intake surface does not currently prove any repository-wide quality level
* signals are intentionally lightweight and incomplete
* no global quality percentage is claimed
* signal-level passes are not full-output oracles
* current local hardening remains ongoing for heavier PDF, DOCX, XLSX, and
  PPTX boundary samples

## Layout

```text
samples/quality_corpus/
  README.md
  manifest.tsv
  external_sources.tsv
  external_manifest.example.tsv
  external_manifest.local.tsv  # optional, gitignored
  check.sh
  compare_tools.sh
  external/
    README.md
  schemas/signals.tsv
  private/
    README.md
    manifest.example.tsv
    manifest.local.tsv   # optional, gitignored
    files/               # optional, gitignored
  tools/
    fetch_external_samples.sh
    curate_external_sample.sh
```

## Manifest

`manifest.tsv` columns are still stable even when the public file is empty:

* `id`
* `format`
* `path`
* `source_type`
* `license_status`
* `privacy`
* `size_class`
* `features`
* `expected_signals`
* `quality_tier`
* `notes`

Signal syntax lives in [`schemas/signals.tsv`](./schemas/signals.tsv).

Multiple signals are separated with `;`.

Useful signal patterns for early external intake:

* `contains_all:a|b|c` for multiple required anchors
* `exact_count:text=1` to require an exact non-overlapping substring count
* `min_count:text=2` to require at least N non-overlapping occurrences
* `max_count:text=1` to guard against duplicate appendix/headings/rows
* `not_contains:text` for obvious bad artifacts
* `max_long_token_len:n` for token-join / spacing regressions
* `review_note:text` for non-blocking reviewer notes

Useful `quality_tier` values:

* `gate`, `reference`, `stress`: normal pass/fail behavior
* `known_bad`: keep a real boundary sample visible without failing the whole run

For `known_bad` rows:

* conversion failure or signal failure is recorded as `expected_fail`
* a full green run is recorded as `unexpected_pass`
* both outcomes stay visible in summary output

The checked-in public manifest is intentionally empty until rows are manually
curated from:

* public datasets
* upstream tool fixtures
* manually reviewed self-real/public samples

Local external rows belong in `external_manifest.local.tsv`.

That local manifest adds:

* `source_id`
* `original_url`
* `local_cache_path`
* `license_review_status`

Only `license_review_status=approved` external rows are executed.

Pending or missing external rows are recorded as skipped rather than causing CI
failure.

Example local boundary row:

* `pandoc_biblio_yaml`
  * `quality_tier=known_bad`
  * `notes=true multi-document YAML stream remains unsupported`

Current local source status:

* `microsoft_markitdown_tests`: fixed `known_bad` rows have been retired; the
  current locally approved set passes
* `pandoc_tests`: still keeps `pandoc_biblio_yaml` as the one active
  `known_bad` row because true multi-document YAML streams remain unsupported
* `python_pptx_tests`: currently exercises small PPTX notes and visible
  hyperlink rows
* `openxml_sdk_tests`: currently exercises a small PPTX comments/commentAuthors
  row
* `pdfjs_tests`: currently exercises `/ToUnicode` Unicode positives plus
  retained PDF CJK/Type0 no-`/ToUnicode` boundaries

Current locally exercised PDF reference rows include:

* `pdf_tounicode_unicode_markitdown_test`
* `pdf_tounicode_unicode_pdfjs_arabic_cidtruetype`
* `pdf_scan_boundary_markitdown_medrpt` as a scan/image-only boundary note row

Current scan-only row strategy:

* scan-only/image-only PDF rows can stay `reference` when the default native
  contract is to emit page images/assets rather than OCR text
* `pdf_scan_boundary_markitdown_medrpt` records this default native behavior
  through `image_ref`-style signals
* these rows should not be promoted to `known_bad` unless an OCR-specific suite
  intentionally expects body text
* future OCR quality work should stay in a separate OCR suite or OCR-specific
  gate rather than changing the native text-PDF gate semantics

Current retained PDF `known_bad` rows include:

* `pdf_cjk_text_pdfjs_simfang_variant`
  * simple `TrueType` / `WinAnsiEncoding` / no `/ToUnicode` / raw-GBK boundary
* `pdf_type0_identity_no_tounicode_pdfjs_arial_unicode_en_cidfont`
  * `Type0 / CIDFontType2 / Identity-H` / no `/ToUnicode` / `CIDToGIDMap`
    stream boundary

These retained rows are healthy local evidence, not regressions:

* `known_bad` means the boundary is intentionally kept visible
* `expected_fail` is the healthy status while that boundary remains unsupported
* `unexpected_pass` means a real implementation may now cover the case and the
  row should be reviewed for retiering

Current locally exercised PPTX coverage includes:

* image / alt / caption
* table
* grouped shapes
* cached chart data
* speaker notes
* visible hyperlinks
* comments / commentAuthors

Typical row lifecycle for a real boundary sample:

* `known_bad` while the unsupported boundary is being tracked
* `unexpected_pass` once a real fix lands
* local retier to `reference` after the row is rechecked and passes cleanly

## Commands

Run the intake checker:

```bash
./samples/quality_corpus/check.sh
```

List merged rows after filters without running conversion:

```bash
bash samples/quality_corpus/check.sh --list
```

Run only public rows:

```bash
./samples/quality_corpus/check.sh --public-only
```

Run only private local rows:

```bash
./samples/quality_corpus/check.sh --private-only
```

Run one specific row:

```bash
bash samples/quality_corpus/check.sh --id pandoc_usersguide_docx
```

Run one specific row without metadata sidecar generation:

```bash
bash samples/quality_corpus/check.sh --id pandoc_usersguide_docx --no-metadata
```

Run one specific row with timing diagnostics:

```bash
bash samples/quality_corpus/check.sh --id pandoc_usersguide_docx --no-metadata --profile
cat .tmp/quality_corpus/profile.tsv
```

`--profile` records both `signal_start:<kind>` and `signal:<kind>`; `signal_start`
helps identify a long-running signal even if the row does not finish.

`no_empty_output` uses a file-level non-whitespace check, so `--profile` will
show `signal_start:no_empty_output` / `signal:no_empty_output` instead of the
generic `unknown` marker for that first check.

Current dashboard artifacts under `.tmp/quality_corpus/` include:

* `summary.tsv`
* `summary.md`
* `rows.tsv`
* `summary.by_format.tsv`
* `summary.by_source.tsv`
* `summary.by_tier.tsv`
* `known_bad.tsv`
* `unexpected_pass.tsv`
* `skipped_license.tsv`

These are reporting aids, not new gate semantics:

* `known_bad.tsv` is a retained-boundary view, not a regression list
* `unexpected_pass.tsv` highlights rows that may now deserve retiering
* scan-only/image-only native rows should stay in the native dashboard and
  only move to OCR-specific expectations in a future OCR suite

Profile signal-level diagnostics on a larger EPUB row:

```bash
bash samples/quality_corpus/check.sh --id pandoc_manual_epub --no-metadata --profile
cat .tmp/quality_corpus/profile.tsv
```

Run one external source:

```bash
bash samples/quality_corpus/check.sh --source pandoc_tests
```

Combine filters:

```bash
bash samples/quality_corpus/check.sh --source pandoc_tests --format epub
```

Print the external source catalog:

```bash
bash ./samples/quality_corpus/tools/fetch_external_samples.sh --list-sources
```

Prepare local external cache roots:

```bash
bash ./samples/quality_corpus/tools/fetch_external_samples.sh --prepare-cache
```

Optional comparison against local tools if installed:

```bash
./samples/quality_corpus/compare_tools.sh
```

## Private Local Samples

Private local samples are supported through:

* `samples/quality_corpus/private/manifest.local.tsv`
* `samples/quality_corpus/private/files/`

That manifest is optional and should not be committed.

Use it for:

* local real PDFs
* local PPTX/DOCX/XLSX/HTML samples
* customer or internal files that cannot enter the repository

Do not commit:

* private source files
* private manifests with sensitive paths
* generated outputs from private runs

All generated outputs go under `.tmp/quality_corpus/`.

## External Intake

External intake is manual-curated and local-only.

Tracked files:

* [`external_sources.tsv`](./external_sources.tsv): source catalog only
* [`external_manifest.example.tsv`](./external_manifest.example.tsv): local row example
* [`external/README.md`](./external/README.md): cache convention

Ignored local files:

* `samples/quality_corpus/external_manifest.local.tsv`
* `.external/quality_corpus/...`

Rules:

* `external_sources.tsv` is not an integrated corpus
* external rows require manual license review before execution
* tool and dataset outputs are references, not oracles
* local external rows live in ignored manifests and should not be committed
* external files stay outside git under local cache roots
* large datasets such as PubLayNet, CDLA, and TableBank should be sampled
  manually rather than mirrored wholesale
* layout/table datasets are mainly structural references, not direct text-PDF
  Markdown gold

Practical priority today:

* MarkItDown tool fixtures are `p0`
* Pandoc tool fixtures are `p1`
* PaddleOCR PP-Structure samples are `p1` reference material only
* TableBank and CDLA are `p2`
* PubLayNet is `p3`

## Tool Comparison

`compare_tools.sh` treats external tools as reference points only.

Current optional probes:

* `markitdown`
* `pandoc`
* `python -m unstructured`
* `paddleocr`

Missing tools are skipped and do not fail the script.

## External Sources

`external_sources.tsv` tracks candidate intake sources only.

It does not mean:

* the source has been downloaded
* the source has been reviewed
* the source has been integrated
* the source is safe to redistribute

Code license, data license, and model-weight license must be reviewed
separately before any future vendoring decision.
