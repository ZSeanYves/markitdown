# Samples

The `samples/` tree contains repo-local regression samples and the public
validation entrypoints for the MoonBit `markitdown` repository. It is the place
to check shipped product behavior, not a storage area for large external
corpora.

## Directory Roles

| Path | Role |
| --- | --- |
| `samples/main_process/` | repo-tracked product regression samples and expected Markdown, metadata, and asset outputs |
| `samples/fixtures/` | small lower-layer fixtures and fail-closed fixtures |
| `samples/helpers/validation/` | internal implementation for repo-local sample checks |
| `samples/helpers/quality/` | internal implementation for external quality runs |
| `samples/helpers/bench/` | internal benchmark layer helpers |
| `samples/helpers/contracts/` | focused internal CLI, PDF, ZIP, batch, debug, and OCR contract checks |
| `samples/helpers/release/` | release-candidate and release-summary helpers |
| `samples/helpers/shared/` | shared shell libraries for temp dirs, progress output, and runner resolution |

Large external quality and benchmark corpora live in `markitdown-quality-lab/`,
not in `samples/`.

## Public Entrypoints

The public sample entrypoints are:

```bash
bash samples/check.sh
bash samples/check_quality.sh
bash samples/bench.sh
```

`samples/check.sh` validates repo-local product behavior from
`samples/main_process/`.

```bash
bash samples/check.sh
bash samples/check.sh --format yaml
bash samples/check.sh --markdown-only
bash samples/check.sh --metadata-only --format txt
bash samples/check.sh --assets-only --format pdf
```

Supported options:

- `--format FMT`
- `--markdown-only`
- `--metadata-only`
- `--assets-only`
- `-h` / `--help`

The focused `--markdown-only`, `--metadata-only`, and `--assets-only` modes are
mutually exclusive. With no focused mode, the script runs Markdown, metadata,
and asset checks for all applicable formats.

`samples/check_quality.sh` validates the optional external quality corpus:

```text
markitdown-quality-lab/external_quality/MANIFEST.tsv
```

```bash
bash samples/check_quality.sh
bash samples/check_quality.sh --format pdf
MARKITDOWN_QUALITY_LAB=/path/to/markitdown-quality-lab bash samples/check_quality.sh --format docx
```

Supported options:

- `--format FMT`
- `-h` / `--help`

If `markitdown-quality-lab/`, `external_quality/`, or `MANIFEST.tsv` is missing,
the script reports the expected path and exits clearly. Repo-local samples are
not used as external quality data.

`samples/bench.sh` validates the optional external benchmark corpus:

```text
markitdown-quality-lab/external_bench/MANIFEST.tsv
```

```bash
bash samples/bench.sh --format html --iterations 1 --warmup 0
bash samples/bench.sh --layer parser --format html --iterations 1 --warmup 0
bash samples/bench.sh --layer cli --profile normal --format pdf --iterations 1 --warmup 0
MARKITDOWN_BENCH_LAB=/path/to/markitdown-quality-lab bash samples/bench.sh --layer compare --format txt --iterations 1 --warmup 0
bash samples/bench.sh --help
```

Supported options:

- `--layer parser|convert|cli|compare`
- `--format FMT[,FMT...]`
- `--manifest PATH`
- `--iterations N`
- `--warmup N`
- `--output PATH`
- `--output-dir DIR`
- `--profile PROFILE`
- `-h` / `--help`

Benchmark input rows come from `external_bench/`. Repo-local samples are not a
benchmark corpus. Benchmark results are same-machine, same-corpus,
same-parameters feedback.

## Temporary Output Layout

Public entrypoints write ignored run output under:

```text
.tmp/check/runs/<run-id>/
.tmp/quality/runs/<run-id>/
.tmp/bench/runs/<run-id>/
```

Each run directory may contain:

```text
logs/entrypoint.log
summary.tsv
summary.md
diff/
workspace/
raw/
reports/
```

The short terminal output always prints the run directory, summary path, and
details path. The Markdown summary gives a human-readable run record. The TSV
summary is the stable machine-readable run summary.

`.tmp` is ignored and disposable. Do not store the only copy of a sample,
expected output, manifest, source catalog, license evidence, or benchmark row
under `.tmp`.

## CLI Examples

Build native product binaries:

```bash
moon build cli --target native
moon build pdf --target native
moon build zip --target native
```

Run normal conversion:

```bash
./_build/native/debug/build/cli/cli.exe normal samples/main_process/txt/txt_plain.txt .tmp/manual/txt_plain.md
./_build/native/debug/build/cli/cli.exe normal --with-metadata samples/main_process/pdf/text_simple.pdf .tmp/manual/text_simple.md
./_build/native/debug/build/cli/cli.exe batch samples/main_process/txt .tmp/manual/txt_batch
```

Run image OCR when local `tesseract` and language data are installed:

```bash
./_build/native/debug/build/cli/cli.exe normal --ocr-lang eng samples/fixtures/ocr/tiny_ocr_sample.png .tmp/manual/tiny_ocr_sample.md
```

## TTY and Non-TTY Output

Progress output is compact and environment-aware:

- interactive TTY runs show a single updating progress line
- `CI=1` or `NO_PROGRESS=1` disables the updating progress line
- non-TTY runs avoid carriage-return progress output and keep logs stable
- `SAMPLES_VERBOSE=1` prints explicit progress lines for debugging
- detailed output is written to `logs/entrypoint.log` inside the run directory

The entrypoints print concise final lines such as:

```text
run: .tmp/check/runs/all-...
result: pass ...
summary: .tmp/check/runs/all-.../summary.md
details: .tmp/check/runs/all-...
```

Use `summary.md` for a quick human review, `summary.tsv` for scripting, and
`logs/entrypoint.log` for the complete command log.

## Native Runner Resolution

Sample helpers use the same prebuilt-first, missing-only strategy as the main
repository validation flow:

- explicit overrides such as `MARKITDOWN_CLI`, `MARKITDOWN_PDF_CLI`,
  `MARKITDOWN_ZIP_CLI`, `MARKITDOWN_DEBUG_CLI`, and `MARKITDOWN_BENCH_CLI`
  are honored first
- existing native binaries under `_build/` or `target/` are probed before a
  build is attempted
- when a required runner is missing, the helper builds that package once with
  `moon build <package> --target native`
- `moon run` is disabled by default and is enabled only with
  `MARKITDOWN_ALLOW_MOON_RUN=1`

Benchmark layer helpers use existing native layer runners when available and
build only the missing runner for the selected layer.

## External Corpus Consumption

`samples/check_quality.sh` consumes only:

```text
markitdown-quality-lab/external_quality/MANIFEST.tsv
```

`samples/bench.sh` consumes only:

```text
markitdown-quality-lab/external_bench/MANIFEST.tsv
```

Formal external corpus rows require manifest coverage, source catalog coverage,
and provenance and license evidence. Temporary tools, audit reports, generated
reports, and local caches are not formal corpus inputs.

The external lab is optional for repo-local validation. Use `samples/check.sh`
when you need the self-contained product regression gate.

## Non-goals

The `samples/` tree does not:

- own large external quality or benchmark corpora
- make the external lab required for `moon check`, `moon test`, or
  `samples/check.sh`
- use repo-local samples as benchmark corpus
- store durable corpus data under `.tmp`
- define product runtime, parser, converter, or IR architecture
- provide legal advice about external corpus licenses
- expose legacy validation modes
- make benchmark results universal performance claims
