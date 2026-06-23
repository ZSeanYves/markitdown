# Benchmark Corpus

`samples/bench/` is the main-repository benchmark corpus for MoonBit markitdown.
It is intentionally data-only: this tree provides tracked payloads and metadata, but it does not include a benchmark runner, `samples/bench.sh`, `samples/helpers/bench/`, a `bench/` MoonBit package, or external compare tooling.

## Corpus Rules

- Every payload under `samples/bench/` must be tracked in git.
- Local-only, ignored, or huge-local-only benchmark payloads are not allowed here.
- `markitdown-quality-lab/external_bench/` is a read-only source pool, not a runtime dependency.
- `samples/check.sh` remains the correctness gate for `samples/main_process/`; it is not the benchmark runner.
- Benchmark harness and external compare tooling now live under tracked `bench/` packages, with `bench/runner/` as the process-level benchmark entrypoint.
- This round does not restore retired `samples/bench.sh` or `samples/helpers/bench/`.

## Default Scope

The default tracked benchmark corpus covers:

- `txt`, `csv`, `tsv`, `json`, `yaml`, `xml`, `markdown`, `html`
- `zip`, `epub`, `pdf`, `docx`, `pptx`, `xlsx`

The default corpus does not include OCR/image-only payloads, scanned PDF OCR baselines, PDF rasterization, layout-model assets, or audio/video/email inputs.
PDF payloads here are native-text-only by policy.

## Size Classes

- `tiny`: under 10 KiB, fixed-overhead benchmark payloads
- `small`: 10 KiB to 100 KiB, small but representative payloads
- `medium`: 100 KiB to 1 MiB, mid-size benchmark payloads
- `large`: 1 MiB to 10 MiB, release-tier large payloads
- `huge`: 10 MiB to 50 MiB, tracked stress payloads that remain under the single-file cap

For container and OOXML formats, content scale also matters alongside bytes: chapter count, slide count, sheet count, entry count, tables, notes, and assets can influence the selected class.

## Enabled Tiers

- `smoke`: tiny/small defaults intended for very fast runs
- `regular`: common local benchmark rows, usually tiny through medium
- `release`: broader pre-release rows, usually tiny through large
- `stress`: full stress rows, including tracked huge payloads
- `disabled`: declared but currently missing or intentionally not selected for execution

## Manifest Contract

`MANIFEST.tsv` is the benchmark corpus contract for future runners. Each accepted row points at one tracked payload. Rows marked `missing_candidate` reserve known gaps without pretending the payload exists.

## Provenance

Payloads come from three approved sources only:

- copied from `markitdown-quality-lab/external_bench/`
- copied from existing tracked repo samples under `samples/main_process/`
- generated deterministically and tracked directly in `samples/bench/`
