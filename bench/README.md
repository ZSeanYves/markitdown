# Benchmark Guide

`bench` is the formal benchmark entry point in this repository.

It is manifest-driven, measures release-grade product paths, and persists raw samples, aggregated cases, trust status, gate status, and a readable report together.

## Ground Rules

- Do not use `moon bench`
- Do not use `moon run`
- Formal benchmark runs must use the release runner:
  `_build/native/release/build/bench/runner/runner.exe`
- The `moonbit-cli` process baseline must be the release CLI:
  `_build/native/release/build/cli/cli.exe`
- `official-*` presets only measure formal product-default paths
- `doctor` only checks the release binary contract; it does not walk the external corpus or run tool comparisons

## Before You Start

Build the release binaries first:

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
moon build --target native --release --package ZSeanYves/markitdown/bench/runner
```

If the external benchmark corpus is not already present under the repo root, clone it first:

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

Run the binary contract check before formal benchmark work:

```bash
_build/native/release/build/bench/runner/runner.exe doctor
```

If you plan to use `official-compare`, install the comparison baseline once per repo clone:

```bash
./tools/env/install_bench_baseline_deps.sh
```

If you run the release runner from the repo root, `official-compare` auto-detects:

```text
./env/.venv-markitdown-bench/bin/markitdown
```

`source ./env/bench-baseline.env.sh` is only needed when you want `MARKITDOWN_BIN` exported into another shell.

Corpus discovery rules:

- default location:
  `./markitdown-quality-lab/external_bench/`
- explicit override:
  `MARKITDOWN_BENCH_ROOT=/absolute/path/to/external_bench`

Baseline `markitdown` resolution order for `official-compare`:

1. `--markitdown-path <path>`
2. repo-local `./env/.venv-markitdown-bench/bin/markitdown`
3. `MARKITDOWN_BIN`
4. `PATH`
5. fallback paths such as `/usr/local/bin/markitdown` and `/opt/homebrew/bin/markitdown`

If no usable baseline is found, `official-compare` fails closed.

## Common Commands

Use the release runner path shown below as one full command prefix:

```bash
RUNNER="_build/native/release/build/bench/runner/runner.exe"
```

Then run common operations like this:

```bash
"$RUNNER" doctor
"$RUNNER" catalog scenarios
"$RUNNER" catalog rows --tiers regular,release,stress
"$RUNNER" catalog rows --tiers release --format pdf --limit 5
"$RUNNER" run --preset official-internal
"$RUNNER" run --preset official-compare
"$RUNNER" run --scenario diagnostic.html --bench-id html_huge_synthetic_articles_v1
"$RUNNER" report --run <run_id>
"$RUNNER" report --run <run_id> --baseline <baseline_run_id>
```

Important copy-paste notes:

- `official-internal` and `official-compare` are values passed to `--preset`
- they are not standalone shell commands
- `run` requires `--preset` or `--scenario`
- if both are present, the current implementation resolves `--scenario` first
- if you run `"$RUNNER" run --preset` by itself, the runner correctly fails with `missing value for --preset`
- `catalog rows` emits one JSON object per selected row
- `report` regenerates `cases.jsonl`, `summary.json`, and `report.md` from the stored `samples.jsonl`

If you need to point at a specific baseline binary, use either form below:

```bash
MARKITDOWN_BIN="/absolute/path/to/markitdown" "$RUNNER" run --preset official-compare
"$RUNNER" run --preset official-compare --markitdown-path /absolute/path/to/markitdown
```

## Main Flags

Run filters and measurement knobs:

- `--preset <name>`
- `--scenario <scenario_id>`
- `--tiers <tier[,more]>`
- `--bench-id <id[,more]>`
- `--format <fmt[,more]>`
- `--limit <N>`
- `--repeat <N>`
- `--warmup <N>`
- `--timeout-ms <N>`
- `--markitdown-path <path>`

Report flags:

- `--run <run_id>`
- `--baseline <run_id>`

Notes:

- `--tiers` is an exact filter, not a cumulative tier filter; pass a comma list if you want multiple tiers
- one run may expand into multiple scenarios
- `run --preset ...` expands all scenario IDs inside that preset

## Presets

| preset | scenarios | tools | purpose |
| --- | --- | --- | --- |
| `official-internal` | `product.official_internal` plus the `diagnostic.*` scenarios listed below | `moonbit-cli`, `moonbit-engine` | internal performance observation, route proof, and targeted format diagnostics |
| `official-compare` | `compare.official_compare` | `moonbit-cli`, `moonbit-engine`, `markitdown` | external comparison on the same formal corpus |
| `doctor` | `doctor.binary_contract` in policy | `moonbit-cli`, `moonbit-engine`, `markitdown` | policy-level binary contract scenario; use the `doctor` subcommand for the normal workflow |

Current scenario IDs:

- `product.official_internal`
- `compare.official_compare`
- `doctor.binary_contract`
- `diagnostic.markdown`
- `diagnostic.html`
- `diagnostic.xml`
- `diagnostic.pdf`
- `diagnostic.docx`
- `diagnostic.pptx`
- `diagnostic.xlsx`
- `diagnostic.epub`
- `diagnostic.zip`
- `diagnostic.ipynb`
- `diagnostic.toml`
- `diagnostic.srt`
- `diagnostic.vtt`
- `diagnostic.jsonl`
- `diagnostic.ndjson`
- `diagnostic.eml`
- `diagnostic.tex`
- `diagnostic.rst`
- `diagnostic.asciidoc`
- `diagnostic.odt`
- `diagnostic.ods`
- `diagnostic.odp`
- `diagnostic.ocr`

If you want the source-of-truth list from the current code, run:

```bash
"$RUNNER" catalog scenarios
```

## Default Run Policy

The default policy for `official-internal` and `official-compare` is:

- `tiers=regular,release,stress`
- `repeat=3`
- `warmup=1`
- `timeout_ms=60000`
- order:
  `row_major_interleaved`

The `doctor` subcommand is different: it only validates the binary contract and does not execute the corpus.

## Output Layout

Each run writes to:

```text
.tmp/bench/runs/<run_id>/
```

Main files:

- `results/samples.jsonl`
  raw per-sample measurements
- `results/cases.jsonl`
  case aggregates grouped by `scenario x tool x bench_id`
- `results/summary.json`
  the main machine-readable summary
- `reports/report.md`
  the main human-readable report

Each run also writes:

- `outputs/<scenario>/<tool>/*.md`
  conversion outputs
- `outputs/<scenario>/<tool>/*.provenance.json`
  provenance emitted by `moonbit-cli`
- `outputs/<scenario>/<tool>/*.stdout.log`
- `outputs/<scenario>/<tool>/*.stderr.log`

## How To Read Results

Start with `summary.json`:

- `trust_status`
  whether the overall run remained trustworthy
- `gate_summary`
  whether a fully comparable set was formed
- `route_coverage_summary`
  whether the expected product routes were actually covered
- `truth_summary`
  why MoonBit cases are treated as trusted, or why they failed
- `scenarios`
  selected rows, comparable rows, trust, and gate per scenario
- `tools`
  row count, success count, and median wall time per tool
- `by_format`
  comparable coverage and speedup by format

For `official-compare`, the most useful fields to scan first are:

- `cli_geomean_speedup`
- `engine_geomean_speedup`

Both fields mean:

```text
markitdown time / MoonBit time
```

Higher means the MoonBit implementation is faster.

`gate_status` uses the following meanings:

- `ok`
  every selected row formed a complete comparable set
- `partial`
  only part of the selected set formed a comparable set
- `failed`
  no selected row formed a comparable set

## Trust Rules

Formal benchmark runs fail closed in two layers.

Binary contract layer:

- the runner must be the release `runner.exe`
- `_build/native/release/build/cli/cli.exe` must exist
- extra `moon` delegation is forbidden

Case-trust layer for `moonbit-cli` and `moonbit-engine`:

- route provenance must be complete
- `route_fidelity_status` must be `matched`
- if the case has a route expectation, `expected_route` must equal `actual_route`
- large structured-text rows are subject to the low-density guard

The current low-density guard applies to `json`, `yaml`, and `xml` when:

- output bytes are below `256`
- and `output_bytes / input_bytes < 0.001`

Minimum required MoonBit provenance fields:

- `route_plan.selected_route`
- `route_plan.route_reason`
- `route_plan.route_probe_summary`
- `effective_parser_mode`
- `parse_result_kind`
- `pipeline_output_kind`
- `render_input_kind`
- `route_fidelity_status`
