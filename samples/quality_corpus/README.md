# Quality Corpus

This directory contains a signal-level quality corpus for repository-local
quality intake.

It is intentionally different from the existing sample surfaces:

* `./samples/check.sh` remains the exact regression gate
* `samples/quality_corpus/` is signal-level intake, not an exact diff

Purpose:

* provide a framework for checked-in public quality rows plus lab-managed real quality samples
* express real-world quality expectations as signals instead of full-output oracles
* allow optional tool comparison without treating external tools as oracles

Current scope:

* public `manifest.tsv` now carries a small checked-in repo-tracked baseline for stable local samples
* external source candidates are tracked in `markitdown-quality-lab/quality_rows/source_catalog.tsv`
* tracked lab quality rows are loaded from `markitdown-quality-lab/quality_rows/manifest.tsv`
* `samples/quality_corpus/external_manifest.local.tsv` remains only as a legacy local fallback during the migration window
* local caches are resolved from a corpus root, in this order:
  `--corpus-root`, `MARKITDOWN_QUALITY_CORPUS`,
  `MARKITDOWN_QUALITY_LAB/corpus`,
  `markitdown-quality-lab/corpus`,
  optional sibling fallback `../markitdown-quality-lab/corpus`,
  optional legacy sibling corpus `../markitdown-quality-corpus`,
  then the legacy `.external/quality_corpus/...` fallback

Current limitations:

* this intake surface does not currently prove any repository-wide quality level
* signals are intentionally lightweight and incomplete
* no global quality percentage is claimed
* signal-level passes are not full-output oracles
* `0 expected_fail` does not mean every format boundary is universally covered
* OCR/scanned behavior remains explicit-only unless an OCR-specific suite says
  otherwise

Current local quality snapshot:

* current pass status: `330` rows, `1` skipped, `0` expected_fail
* focused PDF rows: `PDF 101`, public-only checked-in `PDF 24`
* focused Office rows: `DOCX 60`, `PPTX 55`, `XLSX 51`
* focused horizontal rows: `ZIP 15`, `EPUB 16`, `XML 9`, `CSV 15`, `HTML 5`
* this is a local-only external corpus snapshot, not a release artifact
* the recommended external-corpus home is repo-local:
  `markitdown-quality-lab/corpus`
* the recommended tracked full/local row manifest is:
  `markitdown-quality-lab/quality_rows/manifest.tsv`
* the recommended clone command is:

```bash
git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

* the recommended environment setup, when you want explicit non-default roots, is:

```bash
export MARKITDOWN_QUALITY_LAB="$(pwd)/markitdown-quality-lab"
export MARKITDOWN_QUALITY_CORPUS="$MARKITDOWN_QUALITY_LAB/corpus"
export MARKITDOWN_LAYOUT_LAB="$MARKITDOWN_QUALITY_LAB/pdf_layout_classifier"
```

* runner/tool lookup now auto-discovers `markitdown-quality-lab/` at the repo root
* the quality-lab is a nested independent Git repository, not a submodule
* the main repository `.gitignore` ignores `markitdown-quality-lab/`
* public-only checks do not require cloning the quality-lab
* normal product/runtime paths do not read the quality-lab
* local external manifests should now prefer corpus-root-relative canonical
  payload paths under `sources/...`
* legacy `.external/quality_corpus/...` paths remain fallback-only during the
  migration window and should not be reintroduced as the canonical path style
* current corpus expansion is external-fixture-driven, not synthetic-only
* checked-in public rows remain intentionally separate from local-only
  external rows
* known policy boundaries remain documented separately
* current local-only hardening covers PDF external second-pass
  CJK/`/ToUnicode`/annotations/forms/links/images, Office second-cycle
  comments/merged/images/media boundaries, and horizontal EPUB/ZIP/XML/CSV
  tails

Migration-window fallback lifecycle:

* current primary workflow is:
  * `markitdown-quality-lab/corpus`
  * `markitdown-quality-lab/quality_rows/manifest.tsv`
* the remaining legacy fallbacks are:
  * `samples/quality_corpus/external_manifest.local.tsv`
  * legacy `.external/quality_corpus/...` row-path resolution
  * optional sibling `../markitdown-quality-lab/corpus`
* remove those fallbacks only after all of the following are true:
  * repo-root quality-lab full quality passes `330 / 1 / 0`
  * public-only still passes `24 / 0 / 0`
  * `moon test` and `./samples/check.sh` pass on the same cycle
  * no non-doc runtime/product reference depends on `.external/...`
  * no active workflow still depends on `external_manifest.local.tsv`
  * quality-lab continues to track `quality_rows/manifest.tsv` and
    `corpus/MANIFEST.tsv`
  * at least one full post-migration cycle has completed

## Layout

```text
samples/quality_corpus/
  README.md
  manifest.tsv
  check.sh
  compare_tools.sh
  schemas/signals.tsv
  tools/
    fetch_external_samples.sh
    curate_external_sample.sh
```

## Manifest

`manifest.tsv` columns are stable for checked-in public rows:

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

The checked-in public manifest is intended for manually curated rows from:

* repository-tracked local samples
* public datasets
* upstream tool fixtures
* manually reviewed self-real/public samples

The tracked full/local lab manifest lives in the repo-local quality-lab:

* `markitdown-quality-lab/quality_rows/manifest.tsv`

That manifest adds:

* `source_id`
* `original_url`
* `local_cache_path`
* `license_review_status`

Only `license_review_status=approved` lab rows are executed.

Pending or missing lab rows are recorded as skipped rather than causing CI
failure.

Typical quality-lab-backed validation:

```bash
bash samples/quality_corpus/check.sh --public-only
bash samples/quality_corpus/check.sh --public-only --format pdf
bash samples/quality_corpus/check.sh --corpus-root "$MARKITDOWN_QUALITY_CORPUS" --format pdf
bash samples/quality_corpus/check.sh --corpus-root "$MARKITDOWN_QUALITY_CORPUS"
```

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

Current Office expansion focus includes:

* DOCX: comments, footnotes, endnotes, images, SVG, hyperlinks, body order,
  and paragraph/table interleaving
* PPTX: notes, comments, charts, tables, hyperlinks, alignment, and grouped
  content
* XLSX: tables, formulas, hidden sheets, hidden rows, comments, multi-sheet
  ordering, and table boundaries

Current horizontal expansion focus includes:

* ZIP: metadata, assets, entry-origin headings, asset remap, and container
  boundaries
* EPUB: nav/spine, layout-flow, multimedia, styling, and chapter/section order
* XML: namespaces, long attributes, pronunciation lexicons, and encoding
  boundaries
* CSV: quoted-field structure plus cp932/mskanji fallback coverage

Current PDF expansion focus includes:

* repo-tracked public guards for text, layout, heading, table-like, link, and
  image boundaries
* local-only external second-pass coverage for CJK / `/ToUnicode` /
  annotations / forms / links / images
* scan-only/image-only rows that stay explicit rather than silently becoming
  OCR-text expectations

The current local corpus relies heavily on signal assertions such as:

* `exact_count`
* `min_count`
* `max_count`
* `order`
* `not_contains`
* `table_marker`
* asset / image guards such as `image_ref` and `asset_count_min:n`

Current locally exercised PDF reference rows include:

* `pdf_heading_basic_repo_sample`
* `pdf_cross_page_merge_repo_sample`
* `pdf_cross_page_no_merge_repo_sample`
* `pdf_two_column_negative_repo_sample`
* `pdf_image_caption_repo_sample`
* `pdf_repeated_header_footer_repo_sample`
* `pdf_tounicode_unicode_markitdown_test`
* `pdf_tounicode_unicode_pdfjs_arabic_cidtruetype`
* `pdf_scan_boundary_markitdown_medrpt` as a scan/image-only boundary note row
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

* notes and speaker notes
* comments / commentAuthors
* charts and cached chart data
* tables
* grouped shapes
* visible hyperlinks
* image / alt / caption paths

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

Run only legacy local fallback rows:

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

## Lab-Managed Quality Rows

Tracked full/local quality rows now live in the repo-local quality-lab:

* `markitdown-quality-lab/quality_rows/manifest.tsv`
* `markitdown-quality-lab/quality_rows/source_catalog.tsv`

The main repository keeps only:

* checked-in public rows in [`manifest.tsv`](./manifest.tsv)
* the runner and helper scripts in this directory

Ignored legacy local files:

* `samples/quality_corpus/external_manifest.local.tsv`
* `.external/quality_corpus/...`

Current policy:

* quality-lab `quality_rows/manifest.tsv` is the tracked source of truth for
  external/full local quality rows
* canonical payload paths should use corpus-root-relative `sources/...`
* source-catalog curation lives in quality-lab, not in the main repository
* external rows require manual license review before execution
* tool and dataset outputs are references, not oracles
* large datasets such as PubLayNet, CDLA, and TableBank should still be
  sampled manually rather than mirrored wholesale
* layout/table datasets remain structural references, not direct text-PDF
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

## Source Catalog

The quality-lab source catalog tracks candidate intake sources only.

It does not mean:

* the source has been downloaded
* the source has been reviewed
* the source has been integrated
* the source is safe to redistribute

Code license, data license, and model-weight license must be reviewed
separately before any future vendoring decision.
