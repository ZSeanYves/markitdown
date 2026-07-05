# Benchmark Guide

`bench` is the only formal benchmark entry point in this repository.

It does one job: run release binaries against the real product path and persist performance, trust, and comparability together.

## Ground Rules

- Do not use `moon bench`
- Do not use `moon run`
- The runner must be the release binary:
  `_build/native/release/build/bench/runner/runner.exe`
- The CLI must be the release binary:
  `_build/native/release/build/cli/cli.exe`
- `official-*` presets only measure formal product-default paths

## Before You Start

Build the release binaries first:

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
moon build --target native --release --package ZSeanYves/markitdown/bench/runner
```

Run the contract check first:

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
_build/native/release/build/bench/runner/runner.exe doctor
```

The official corpus location is `./markitdown-quality-lab` under the main repository root.

Corpus discovery rules:

- by default:
  `./markitdown-quality-lab/external_bench/`
- `MARKITDOWN_BENCH_ROOT` is only an explicit override

## Common Commands

Use the release runner path shown below as one full command prefix:

```bash
RUNNER="_build/native/release/build/bench/runner/runner.exe"
```

Then run the common operations like this:

```bash
"$RUNNER" catalog scenarios
"$RUNNER" catalog rows --tiers regular,release,stress
"$RUNNER" run --preset official-internal
"$RUNNER" run --preset official-compare
"$RUNNER" run --scenario diagnostic.html --bench-id html_huge_synthetic_articles_v1
"$RUNNER" report --run <run_id> [--baseline <run_id>]
```

Important copy-paste note:

- `official-internal` and `official-compare` are values passed to `--preset`
- they are not standalone shell commands
- if you run `"$RUNNER" run --preset` by itself, the runner will correctly fail with `missing value for --preset`
- `official-compare` resolves the baseline `markitdown` CLI from `--markitdown-path`, then `MARKITDOWN_BIN`, then `PATH`

If you need to point at a specific `markitdown` binary, use either form below:

```bash
MARKITDOWN_BIN="/absolute/path/to/markitdown" "$RUNNER" run --preset official-compare
"$RUNNER" run --preset official-compare --markitdown-path /absolute/path/to/markitdown
```

Common flags:

- `--preset <name>`
- `--scenario <scenario_id>`
- `--tiers regular,release,stress`
- `--bench-id <id[,more]>`
- `--format <fmt[,more]>`
- `--limit <N>`
- `--repeat <N>`
- `--warmup <N>`
- `--timeout-ms <N>`
- `--markitdown-path <path>`
- `--baseline <run_id>`

Notes:

- `--preset` and `--scenario` are mutually exclusive
- `run --preset ...` expands all `scenario_ids` inside that preset
- one run may contain multiple scenarios

## Presets

| preset | scenarios | tools | purpose |
| --- | --- | --- | --- |
| `official-internal` | `product.official_internal` + `diagnostic.markdown/html/xml/xlsx/epub/zip/ipynb/toml/odt/ods/odp/ocr` | `moonbit-cli`, `moonbit-engine` | internal performance, route proof, targeted format diagnostics |
| `official-compare` | `compare.official_compare` | `moonbit-cli`, `moonbit-engine`, `markitdown` | external performance comparison |
| `doctor` | `doctor.binary_contract` | `moonbit-cli`, `moonbit-engine`, `markitdown` | binary contract verification |

Current scenarios:

- `product.official_internal`
- `compare.official_compare`
- `doctor.binary_contract`
- `diagnostic.markdown`
- `diagnostic.html`
- `diagnostic.xml`
- `diagnostic.xlsx`
- `diagnostic.epub`
- `diagnostic.zip`
- `diagnostic.ipynb`
- `diagnostic.toml`
- `diagnostic.odt`
- `diagnostic.ods`
- `diagnostic.odp`
- `diagnostic.ocr`

Default parameters:

- official presets:
  `tiers=regular,release,stress`
- `repeat=3`
- `warmup=1`
- `timeout_ms=60000`
- order:
  `row_major_interleaved`

## Coverage

Formal coverage currently includes:

- `txt`
- `csv`
- `tsv`
- `srt`
- `vtt`
- `json`
- `jsonl`
- `ndjson`
- `ipynb`
- `yaml`
- `toml`
- `xml`
- `markdown`
- `html`
- `eml`
- `tex`
- `rst`
- `asciidoc`
- `zip`
- `epub`
- `odt`
- `ods`
- `odp`
- `pdf`
- `docx`
- `pptx`
- `xlsx`
- `ocr`

Role split:

- `official-internal`
  product view + CLI/engine comparison + route proof
- `official-compare`
  three-way performance comparison on the same formal corpus
- `diagnostic.*`
  targeted format diagnostics

`catalog rows` returns fields such as:

- `bench_id`
- `format`
- `size_class`
- `enabled_tier`
- `input_bytes`
- `sha256`
- `bench_layers`
- `tags`
- `source_kind`
- `source_ref`

## Output Layout

Each run writes to:

```text
.tmp/bench/runs/<run_id>/
```

Main files:

- `results/samples.jsonl`
  raw per-sample data
- `results/cases.jsonl`
  aggregated case-level data
- `results/summary.json`
  main machine-readable result
- `reports/report.md`
  main human-readable result

## How To Read Results

Start with `summary.json`:

- `trust_status`
  whether this run is trustworthy
- `gate_summary`
  whether a comparable set was formed
- `route_coverage_summary`
  whether expected routes were actually covered
- `truth_summary`
  why the run is trusted, or why it failed
- `tools`
  row count, success count, and medians for each tool
- `by_format`
  comparable coverage and speedup by format

For `official-compare`, focus on:

- `cli_geomean_speedup`
- `engine_geomean_speedup`

Both mean:
`markitdown time / MoonBit time`

Higher means the MoonBit implementation is faster.

## Trust Rules

If any of the following fail, a MoonBit case is marked `trust_status=failed`:

- the runner is not the release `runner.exe`
- the CLI is not the release `cli.exe`
- the dispatch path uses `moon` as an extra trampoline
- the MoonBit row is missing full provenance
- `route_fidelity_status != matched`
- `expected_route != actual_route`
- a large structured row triggers the low-density guard

Minimum required MoonBit provenance:

- `route_plan.selected_route`
- `route_plan.route_reason`
