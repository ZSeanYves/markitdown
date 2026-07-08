# markitdown-mb

`markitdown-mb` is an engineering-focused document-to-Markdown tool built in MoonBit.

The project is inspired by Microsoft's `MarkItDown`, but this implementation puts more emphasis on long-term maintainability, consistent product paths, traceable results, and better behavior under complex formats and engineering-scale workloads. It is not a port of `MarkItDown`.

It is designed for document ingestion pipelines, RAG, content processing, and automation scenarios where route fidelity, provenance, and predictable failure behavior matter as much as raw conversion output.

> Important:
> `accurate` PDF OCR and `audio` are still experimental. They are not recommended for production use today.

Read these two documents first:

- Environment setup and install commands: [docs/environment-dependencies.md](./docs/environment-dependencies.md)
- Main architecture overview: [docs/architecture/mb-markitdown-architecture.md](./docs/architecture/mb-markitdown-architecture.md)

If the runtime dependencies are not prepared first, many later examples and commands will not behave as expected.

## Performance Snapshot

Official performance claims come from `bench` only. The current representative results can be summarized as:

| Format | CLI speedup vs `markitdown` |
| --- | --- |
| `docx` | `80.81x` |
| `xlsx` | `21.12x` |
| `epub` | `16.37x` |
| `pdf` | `15.11x` |

On the same representative sample set, median peak memory is about `15,344 KB` for `moonbit-cli` and about `217,424 KB` for `markitdown`.

We also see more stable behavior on some medium-to-heavy rows near practical limits. For example, on a representative high-pressure `json` row, `moonbit-cli` completed `3/3` runs while `markitdown` did not produce a comparable success set.

For full benchmark usage, see [bench/README.md](./bench/README.md). For benchmark architecture, see [docs/architecture/benchmark-architecture.md](./docs/architecture/benchmark-architecture.md).

## Supported Inputs

The main CLI currently supports common text, structured text, web and markup formats, mail, containers, Office documents, PDF, direct image OCR, and audio input. For the full boundary and maturity matrix, see [docs/capabilities-and-limitations.md](./docs/capabilities-and-limitations.md).

A short view is:

- Main document path:
  `txt/csv/tsv/json/jsonl/ndjson/ipynb/xml/yaml/toml/html/markdown/eml/tex/rst/asciidoc/zip/epub/odt/ods/odp/docx/xlsx/pptx/pdf`
- Direct image OCR:
  `png/jpg/jpeg/bmp/webp/tif/tiff`
- Audio:
  `wav/mp3/m4a`

## Quick Start

Build the CLI:

```bash
moon build cli --target native
```

Show help:

```bash
./_build/native/debug/build/cli/cli.exe --help
```

Minimal example:

```bash
./_build/native/debug/build/cli/cli.exe balance samples/fixtures/contracts/txt/txt_plain.txt .tmp/manual/out.md
```

PDF example:

```bash
./_build/native/debug/build/cli/cli.exe balance samples/fixtures/contracts/pdf/root_native_text_baseline.pdf .tmp/manual/pdf.md
```

For more CLI options, modes, batch usage, provenance output, and OCR / PDF / audio examples, see [docs/cli-usage-guide.md](./docs/cli-usage-guide.md).

## Behavior Notes

- `accurate` is not productized for every format. Unsupported formats emit a warning and falls back to `balance`.
- `stream` follows the same rule. Unsupported formats emit a warning and falls back to that format's canonical route.
- `accurate` on PDF only enters Accurate PDF OCR when scanned-like probe evidence upgrades the PDF.
- If `accurate` PDF OCR is missing Paddle dependencies, it reports the missing dependency and falls back to Balanced PDF OCR.
- If `accurate` direct image OCR is missing Paddle dependencies, it reports the missing dependency and falls back to Balanced image OCR.
- Unsupported formats and out-of-bound feature requests fail closed. The product does not hide unsupported behavior behind silent side paths.

## Development And Verification

These are the daily commands most contributors need:

```bash
moon fmt
moon info
moon test
moon check
```

The main repository test suite does not depend on the external corpus repository. The external corpus is only required for `samples/check*.sh` and formal benchmark runs.

If the external corpus repo is not present locally, fetch it first:

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

Common regression scripts:

```bash
bash samples/check_balance.sh
bash samples/check_balance_quality.sh
```

For formal benchmark runs:

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
moon build --target native --release --package ZSeanYves/markitdown/bench/runner
_build/native/release/build/bench/runner/runner.exe doctor
_build/native/release/build/bench/runner/runner.exe run --preset official-compare
```

The last line is one complete command. `official-compare` is the value of `--preset`, not a standalone shell command.

If you want the safest copy-paste form, use:

```bash
RUNNER="_build/native/release/build/bench/runner/runner.exe"
"$RUNNER" doctor
"$RUNNER" run --preset official-compare
```

If `markitdown` is not already on `PATH`, export `MARKITDOWN_BIN=/absolute/path/to/markitdown` or pass `--markitdown-path /absolute/path/to/markitdown`.

Main regression, quality regression, and benchmark runs expect the external repo at `./markitdown-quality-lab/` under the main repository root.
