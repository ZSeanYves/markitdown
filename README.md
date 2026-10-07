# markitdown-mb

`markitdown-mb` is a MoonBit document-to-Markdown converter for document
ingestion, RAG, and automation pipelines. It follows Microsoft MarkItDown's
observable document-extraction behavior where a reviewed compatibility contract
exists, but it is an independent implementation rather than a source port.

The repository is on the unreleased `0.8.0` development line. The stable 0.8
library contract is shared by Native and Wasm. Native may expose additional
FFI-backed capabilities; local archives and benchmark runs are development
evidence, not published releases.

Start with the [documentation index](./docs/README.md). The most useful entry
points are the [CLI guide](./docs/cli-usage-guide.md), [capability matrix](./docs/capabilities-and-limitations.md),
[stable API](./docs/api-v0.8.md), [benchmark environment](./docs/environment-dependencies.md),
and [current performance evidence](./docs/performance.md).

## Install and build

Balanced readers for text, structured data, mail, containers, Office/ODF,
EPUB, and text-layer PDF require no Python or external converter.

```bash
moon build --target native --release --package ZSeanYves/markitdown
./_build/native/release/build/markitdown.exe --help
```

The conversion product has no optional runtime installation. Python is used
only by the benchmark oracle:

```bash
./tools/env/installers/install_bench_baseline_deps.sh
```

Use a Python version in the supported `>=3.10,<3.14` range when the active
`python3` is newer:

```bash
./tools/env/installers/install_bench_baseline_deps.sh --python /path/to/python3.11
```

## CLI quick start

The default mode is `balance`:

```bash
CLI=./_build/native/release/build/markitdown.exe
$CLI samples/fixtures/contracts/txt/txt_plain.txt .tmp/manual/plain.md
$CLI balance --format html input.html output.md
$CLI balance --rag input.docx output.json
$CLI balance --provenance-out .tmp/manual/provenance.json input.pdf output.md
$CLI batch balance samples/fixtures/contracts .tmp/manual/batch
```

`accurate` and `stream` are explicit routes, not quality flags accepted by every
format. Unsupported requests fail closed. Batch mode always writes
`manifest.json`; `--provenance-out` is single-file only.

## Stable library API

`ZSeanYves/markitdown/lib` is the sole compatibility-stable 0.8 package. It
supports Path, Text, Bytes, and caller-owned Reader inputs plus Markdown,
Debug, and RAG outputs.

```mbt
async fn convert_example() -> Result[@lib.Output, @lib.ConvertError] {
  let input = @lib.Input::from_path("document.docx")
  let options = @lib.ConvertOptions::default()
    .with_output_mode(Markdown)
  @lib.convert(input, options~)
}
```

The conversion façade is asynchronous on both targets; the same function is
used from `moonx` and from a native executable.

Parser, reader, pipeline, renderer, runtime, and provider packages are internal
or extension contracts. See the [API reference](./docs/api-v0.8.md) and
[0.8 migration guide](./docs/migration-0.8.md).

## Capability summary

- Text and delimited: `txt`, `csv`, `tsv`, `srt`, `vtt`.
- Structured and markup: `json`, `jsonl`, `ndjson`, `yaml`, `toml`, `xml`,
  `html`, `markdown`, `ipynb`, `tex`, `rst`, `asciidoc`.
- Mail and containers: `eml`, `zip`, `epub`. `msg` is an RFC822/EML alias,
  not native Outlook binary MSG support.
- Office and ODF: `docx`, `xlsx`, `pptx`, `odt`, `ods`, `odp`.
- PDF: bounded text-layer extraction with page geometry and embedded assets;
  scanned pages fail with an explicit diagnostic.
- Images and audio are detected inputs and return `UnsupportedCapability`.

No core reader performs network access, executes document scripts/macros, or
loads remote includes. See [capabilities and limitations](./docs/capabilities-and-limitations.md)
for the structures and modes supported by each format.

## Current performance evidence

The latest complete formal measurement was recorded on 2026-08-07 using an
Apple M4/16 GiB host, native release binaries, Microsoft MarkItDown 0.1.7 on
Python 3.11.15, and one warmup plus five samples per row.

External run `run-1786101654079-0f0c773a82`:

- 25/25 comparable rows and 75/75 trusted tool cases;
- MoonBit CLI median of row medians: **63.941 ms**;
- MarkItDown median of row medians: **699.717 ms**;
- every row passed the 2x gate and every format passed the 3x geometric-mean
  gate;
- every evaluated MoonBit CLI row passed its configured RSS budget.

Self run `run-1786102949457-9591fe380a` covered 53 ODF and technical-text
non-external-comparison rows: 106/106 CLI/engine cases were trusted and all RSS
budgets passed. It is a candidate observation, not an
approved regression delta, because the existing self baseline has different
tool and runner fingerprints.

See [performance evidence](./docs/performance.md) for the format table,
methodology, caveats, reproduction commands, and committed runner summaries.

## Repository layout

The executable root is intentionally thin. The public `lib/` package owns the
stable façade and shared product domain, while `internal/` contains CLI,
readers, parsers, runtime adapters, and verification packages. `preferred_target
= "wasm"` makes the portable product the default for `moonx` consumers; Native
adds only target-isolated host extensions.

```text
main.mbt  one executable composition root
lib/      public stable package and shared product/domain packages
internal/ CLI, readers, parsers, runtime adapters, tests, benchmark runner
bench/    benchmark policy and reviewed result summaries
samples/  deterministic fixtures and showcase outputs
tools/    environment, regression, governance, and release tooling
docs/     maintained documentation, architecture, governance, ADRs, and RFCs
```

## Development verification

```bash
moon info && moon fmt
moon fmt --check
moon check --target all --warn-list +73
moon test --target all
python3 tools/governance/check_documentation.py
./tools/regression/check_coverage.sh --enforce
```

External regression and formal performance runs additionally require the
quality-lab commit pinned in the Phase 0 baseline:

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git \
  markitdown-quality-lab
bash tools/regression/check_balance.sh
bash tools/regression/check_balance_quality.sh
bash tools/regression/check_accurate.sh
```

Contribution rules and risk-specific verification are in
[CONTRIBUTING.md](./CONTRIBUTING.md).
