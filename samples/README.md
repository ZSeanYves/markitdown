# Regression Samples and Validation Entry Points

`samples/` contains the regression samples and validation entry points for this
repository.

There are three main regression surfaces here:

- Main regression:
  validates that the default product conversion path stays stable
- Quality regression:
  validates output quality against the external quality corpus
- Accurate regression:
  validates accurate-only behavior, route upgrades, and OCR/provider evidence
  against the external accurate corpus

The main repository keeps only lightweight functional fixtures for unit-level
coverage and shell contracts. Formal main regression, quality regression, and
benchmark runs all depend on `./markitdown-quality-lab/` at the repository
root. Benchmark usage is documented in [bench/README.md](../bench/README.md).

The current main regression for `rst / asciidoc / tex` also includes a
lightweight semantic inventory set beyond basic heading / paragraph / code /
table coverage. These rows help keep field-or-attribute metadata,
definition-style inventory, quote / admonition / include behavior, and TeX
metadata / environment output stable.

## Main Regression

Entry point:

```bash
moon build cli --target native
./samples/check_balance.sh
```

By default, it runs the main product formats through:

- Markdown regression
- RAG regression
- Assets regression
- Explicit OCR lane regression

This is not a pure repo-local check. The formal corpus comes from
`markitdown-quality-lab/external_main_process/`.

Supported formats:

`txt, csv, tsv, json, jsonl, ndjson, xml, yaml, html, markdown, zip, epub, docx, xlsx, pptx, pdf, wav, mp3, m4a, ocr`

Common commands:

```bash
moon build cli --target native
./samples/check_balance.sh
./samples/check_balance.sh --format pdf
./samples/check_balance.sh --markdown --format docx
./samples/check_balance.sh --rag --format html
./samples/check_balance.sh --assets --format epub
./samples/check_balance.sh --check-inventory
./samples/check_balance.sh --list-inventory
```

Directory conventions:

- `samples/fixtures/contracts/<format>/`:
  minimal fixtures needed by repo-local tests and lightweight shell
  smoke/verify helpers
- `samples/fixtures/boundaries/<format>/`:
  high-value malformed / fail-closed / safety fixtures
- `markitdown-quality-lab/external_main_process/<format>/<lane>/`:
  external main-regression input corpus
- `markitdown-quality-lab/external_main_process/<format>/expected/<lane>/`:
  external expected outputs
- `markitdown-quality-lab/external_main_process/MANIFEST.tsv`:
  the only enrollment manifest for main regression

Run outputs are written to `.tmp/check/runs/<run_id>/`. The most useful files are:

- `summary.md`
- `summary.tsv`
- `reports/failures/`
- `diff/`
- `raw/`

Notes:

- This suite only validates the product default path on the external main
  corpus
- `./samples/check_balance.sh` first validates the external manifest,
  enrollment, and run workspace, so a short preparation phase before row
  execution is expected
- Unsupported formats fail closed here as well; they do not silently switch to
  another route
- The `ocr` gate covers supported direct-image OCR input:
  `png/jpg/jpeg/bmp/webp/tif/tiff`
- The `pdf/ocr` lane covers both `pdf --accurate` and explicit `pdf --ocr`
  OCR paths without changing the default native-text PDF gate
- The `wav/mp3/m4a` gate covers the current audio wrapper integration around
  local `Vosk`; `wav` is the lightest route, and compressed audio may also
  depend on local `ffmpeg`
- `workspace/` is only a temporary working area and is not the main place to
  inspect failures

## Quality Regression

Entry point:

```bash
moon build cli --target native
./samples/check_balance_quality.sh
```

This suite only uses the external quality corpus under
`./markitdown-quality-lab`. It does not fall back to repo-local samples.

Prepare the corpus:

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

The official location is `./markitdown-quality-lab` under the main repository root.

Common commands:

```bash
moon build cli --target native
./samples/check_balance_quality.sh
./samples/check_balance_quality.sh --formats pdf
```

Run outputs are written to `.tmp/quality/runs/<run_id>/`. The most useful files are:

- `summary.md`
- `summary.tsv`
- `reports/`
- `diff/`
- `raw/`

Notes:

- This suite is an external quality signal. It does not replace main
  regression
- `workspace/` is still only a temporary working directory
- Benchmark corpus and quality corpus are different things; formal benchmark
  runs use `./markitdown-quality-lab/external_bench/`
- ZIP-related rows and the main ZIP path build on `format_readers/zip`, with
  decompression still relying on `bikallem/compress/flate`

## Accurate Regression

Entry point:

```bash
moon build cli --target native
./samples/check_accurate.sh
```

This suite only uses the accurate corpus under `./markitdown-quality-lab/external_accurate/`.

Common commands:

```bash
moon build cli --target native
./samples/check_accurate.sh
./samples/check_accurate.sh --formats pdf
./samples/check_accurate.sh --id pdf_niosh_scanned_like_debug
```

Notes:

- This suite performs an accurate runtime preflight before row execution
- Validation is mixed across Markdown, debug JSON, and provenance sidecars
- OCR rows fail if the accurate path falls back away from PaddleOCR
- This suite is separate from `check_balance_quality.sh` so accurate-only
  behavior can evolve without weakening the broader quality surface

## Coverage Scope

Main regression covers:

- the default conversion path for supported product formats
- Markdown output stability
- RAG structure and content contracts
- lightweight assets output contracts
- sample inventory and enrollment completeness

Quality regression covers:

- actual output quality on the external quality corpus
- pass / fail / skipped quality signals by format
- how the external corpus aligns with current CLI capability boundaries

Accurate regression covers:

- format-specific accurate behavior differences on the external accurate corpus
- provider-truth and route-upgrade evidence for direct-image OCR and PDF OCR
- mixed Markdown / debug / provenance assertions for accurate-only features

In short:

- Run `moon build cli --target native && ./samples/check_balance.sh` to see
  whether the main product path regressed
- Run `moon build cli --target native && ./samples/check_balance_quality.sh`
  to see how the current build behaves on the external balance-quality corpus
- Run `moon build cli --target native && ./samples/check_accurate.sh` to
  validate the dedicated accurate regression surface
