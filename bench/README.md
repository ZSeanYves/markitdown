# Benchmark System

`bench/` measures the released balance path. It is a binary-only harness: the
runner invokes built MoonBit CLI/engine binaries and, where appropriate, the
repo-managed Microsoft MarkItDown reference environment. Accurate routes are
functional capabilities and never enter benchmark presets.

## Comparison classes

- `external_compare`: native balance cases that Microsoft MarkItDown supports
  with comparable semantics. Both outputs must pass minimum semantic signals
  before a speed ratio is trusted.
- `self_baseline`: native formats without a valid external comparison, plus
  optional dependency-backed balance capabilities such as OCR/audio. Results
  are compared only with an approved, fingerprint-compatible platform baseline.

ODT, ODS, and ODP remain core native formats; they use `self_baseline` because
the external tool does not provide a valid comparison. PDF accurate is excluded
entirely because benchmarks measure balance only.

## Setup

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git \
  markitdown-quality-lab
./tools/env/optional_deps.sh install bench
moon build --target native --release --package ZSeanYves/markitdown/cli
moon build --target native --release --package ZSeanYves/markitdown/bench/runner
```

Inputs and manifests are loaded from
`markitdown-quality-lab/external_bench/`; the main repository does not contain a
fallback benchmark corpus. Reviewed internal-comparison baselines are loaded
from `markitdown-quality-lab/performance_baselines/`; the quality-lab currently
tracks approved macOS arm64 and Linux x64 baselines with 106 CLI/engine cases
per platform.

## Commands

```bash
RUNNER=_build/native/release/build/bench/runner/runner.exe

$RUNNER doctor
$RUNNER catalog scenarios
$RUNNER catalog rows --comparison-class external_compare
$RUNNER run --preset official-external-compare --progress=json
$RUNNER run --preset official-self-baseline --progress=json
$RUNNER report --run <run_id>
```

`official-compare` remains a compatibility alias for
`official-external-compare`; new automation should use the explicit name.

## Run controls

- `--progress=auto|json|off`: TTY progress, JSONL events, or silence.
- `--keep-outputs=failures|all|none`: retain diagnostic outputs; default is
  failures.
- `--resume <run_id>`: reuse completed samples only when input SHA, scenario,
  and tool fingerprints still match.
- `--max-disk-mb <N>`: enforce the run disk budget.
- `--limit <N>`: development smoke only; it is not formal evidence.

Samples are appended atomically to `samples.jsonl`; checkpoints make interrupted
runs resumable. Reports retain hashes, byte counts, timing, RSS, provenance,
resource summaries, and resume state. Successful outputs are removed by default
to prevent unbounded disk growth.

## Hard gates

For every trusted external case:

- MoonBit CLI and engine must succeed.
- semantic signals, route fidelity, provenance, and output density must pass.
- `external_time / moonbit_time >= 2.0` per case.
- each format geometric mean must be at least `3.0x`.

Self-baseline cases require matching OS, architecture, runner, MoonBit/Python,
runtime, input, and tool fingerprints. Matching baselines permit at most 10%
time or RSS regression. Fingerprint changes produce a candidate for explicit
review instead of silently accepting the old baseline.

Use the baseline matching the controlled runner:

```bash
python3 tools/regression/self_baseline.py capture \
  --run .tmp/bench/runs/<run_id> \
  --output .tmp/bench/<platform>-candidate.json \
  --platform-key <platform> \
  --runner-class <runner-class>
python3 tools/regression/self_baseline.py enforce \
  --candidate .tmp/bench/<platform>-candidate.json \
  --baseline markitdown-quality-lab/performance_baselines/<platform>.json
```

Current RSS budgets are enforced from benchmark policy rather than duplicated
in this document. Inspect `bench/config/policy.json` and the generated summary
for the exact evaluated limits.

## Audited snapshot

The root README performance table is backed by macOS 15.3 arm64 run
`run-1784263977642-7cf3b18a38` from 2026-07-17 against the repo-locked
Microsoft MarkItDown `0.1.6` baseline. All 25 rows were comparable and all 75
tool cases were trusted. The baseline completed 24 rows; the XLSX huge row is a
censored lower-bound comparison because all five baseline samples reached the
60-second timeout. Replace published numbers only with another complete formal
run under the locked environment.

## Evidence and storage

Runs live under `.tmp/bench/runs/<run_id>/` and normally contain:

```text
results/samples.jsonl
results/summary.json
reports/report.md
checkpoint.json
```

Normal push and pull-request CI runs `change-risk`: truth and RSS are mandatory,
while performance may be `not_applicable` because the preset does not execute
the external baseline. Scheduled CI alone runs `official-external-compare` and
mutation smoke. Self baselines are captured and enforced only on controlled,
fingerprint-matched machines; hosted CI timing variance is too large for the
10% per-case regression threshold.

See [runner/README.md](./runner/README.md) for package ownership and
[benchmark-architecture.md](../docs/architecture/benchmark-architecture.md)
for the trust model.
