# Samples

`samples/` contains repo-local regression data and the public validation
entrypoints for the active product pipeline.

## Directory Roles

| Path | Role |
| --- | --- |
| `samples/main_process/` | tracked product samples plus expected Markdown, metadata, and asset outputs |
| `samples/fixtures/` | small fixtures for lower-layer or fail-closed checks |
| `samples/helpers/validation/` | internal implementation for repo-local sample runs |
| `samples/helpers/shared/` | shared shell helpers for temp dirs, runner discovery, and validation output |
| `samples/helpers/contracts/` | focused shell contract gates plus a one-shot aggregator |
| `samples/helpers/quality/` | internal implementation for the external quality bridge |

Large external corpora do not live here. They live in
`markitdown-quality-lab/`.

## Public Entrypoints

Repo-local sample validation:

```bash
bash samples/check.sh
bash samples/check.sh --format txt
bash samples/check.sh --format csv
bash samples/check.sh --format tsv
bash samples/check.sh --format json
bash samples/check.sh --format jsonl
bash samples/check.sh --format ndjson
bash samples/check.sh --format xml
bash samples/check.sh --format yaml
bash samples/check.sh --format html
bash samples/check.sh --format markdown
bash samples/check.sh --format zip
bash samples/check.sh --format epub
bash samples/check.sh --format docx
bash samples/check.sh --format xlsx
bash samples/check.sh --format pptx
bash samples/check.sh --format pdf
bash samples/check.sh --markdown-only
bash samples/check.sh --check-inventory
bash samples/check.sh --list-inventory
```

External quality bridge:

```bash
bash samples/check_quality.sh
bash samples/check_quality.sh --format pdf
```

Run artifact policy:

- `samples/check.sh` keeps only failure artifacts under each run directory.
- `samples/check.sh` uses `workspace/` as scratch only.
- `samples/check_quality.sh` keeps executed row outputs under `raw/outputs/`.
- `samples/check_quality.sh` writes executed non-pass row reports under `reports/`.

Contract aggregation:

```bash
bash samples/helpers/contracts/check_root_contracts.sh
```

Implementation notes:

- `zip` is backed by `format_readers/zip`.
- The ZIP reader keeps `bikallem/compress/flate` inside the lower-level reader
  package.

## Current Gate Scope

The repo-local main CLI gate covers:

- `txt`
- `csv`
- `tsv`
- `json`
- `jsonl`
- `ndjson`
- `xml`
- `yaml`
- `html`
- `markdown`
- `zip`
- `epub`
- `docx`
- `xlsx`
- `pptx`
- `pdf`

Current policy:

- `pdf` coverage is limited to the native-text baseline.
- Scanned or image-only PDFs still fail closed.
- `pdf --ocr` still fails closed.
- Unsupported formats fail closed.

## Expected Output Policy

- Most formats use `samples/main_process/<format>/expected/`.
- `xlsx` and `pptx` use `expected_next/` because those directories are the
  current product baselines for those formats.
- `.tmp` output is disposable and must not become the only durable copy of a
  sample, manifest, or expected artifact.

## Quality Lab

`samples/check_quality.sh` reads only the external corpus from
`markitdown-quality-lab/external_quality/`.

Expected paths:

```text
markitdown-quality-lab/external_quality/
markitdown-quality-lab/external_quality/MANIFEST.tsv
```

Repo-local samples are not used as external quality rows.

## Contract Gates

The contract aggregator keeps the active shell guard surface in one place:

- `check_cli_contract.sh`
- `check_samples_check_contract.sh`
- `check_zip_contract.sh`
- `check_epub_contract.sh`
- `check_docx_contract.sh`
- `check_xlsx_contract.sh`
- `check_pptx_contract.sh`
- `check_ocr_contract.sh`
- `check_pdf_signal_contract.sh`

Use the focused scripts when you need format-specific failure localization.

See:
  [docs/architecture/mb-markitdown-architecture.md](../docs/architecture/mb-markitdown-architecture.md)
