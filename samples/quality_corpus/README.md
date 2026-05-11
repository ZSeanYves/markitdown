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
  check.sh
  compare_tools.sh
  schemas/signals.tsv
  private/
    README.md
    manifest.example.tsv
    manifest.local.tsv   # optional, gitignored
    files/               # optional, gitignored
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

The checked-in public manifest is intentionally empty until rows are manually
curated from:

* public datasets
* upstream tool fixtures
* manually reviewed self-real/public samples

## Commands

Run the intake checker:

```bash
./samples/quality_corpus/check.sh
```

Run only public rows:

```bash
./samples/quality_corpus/check.sh --public-only
```

Run only private local rows:

```bash
./samples/quality_corpus/check.sh --private-only
```

Optional comparison against local tools if installed:

```bash
./samples/quality_corpus/compare_tools.sh
```

## Private Local Samples

Private local samples are supported through:

* `samples/quality_corpus/private/manifest.local.tsv`
* `samples/quality_corpus/private/files/`

That file is optional and should not be committed.

Use it for:

* local real PDFs
* local PPTX/DOCX/XLSX/HTML samples
* customer or internal files that cannot enter the repository

Do not commit:

* private source files
* private manifests with sensitive paths
* generated outputs from private runs

All generated outputs go under `.tmp/quality_corpus/`.

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
