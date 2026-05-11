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
* current PDF and PPTX quality remain active hardening work

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
* `not_contains:text` for obvious bad artifacts
* `max_long_token_len:n` for token-join / spacing regressions
* `review_note:text` for non-blocking reviewer notes

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
