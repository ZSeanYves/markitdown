# Contributing

Use the rolling MoonBit toolchain supported by the repository. Do not pin a
historical MoonBit release in project metadata.

Before submitting any change, run the self-contained checks:

```bash
moon fmt --check
moon info && git diff --exit-code
moon check --target all --warn-list +73
moon test --target all --no-parallelize
moon build --target native --release --package ZSeanYves/markitdown
moon build --target wasm --release --package ZSeanYves/markitdown
python3 tools/governance/check_documentation.py
MARKITDOWN_COVERAGE_BASELINE_REF=<base-sha> \
  moon run tools/regression/check_coverage.mbtx --enforce
```

Changes to format behavior, routing, assets, optional runtimes, or release
infrastructure must also run the external regression suites. Check out the
quality repository at `./markitdown-quality-lab`, build the native CLI, and
prepare only the optional profiles required by the affected formats:

Use the quality repository commit pinned by `MARKITDOWN_QUALITY_LAB_SHA` in
`.github/workflows/ci.yml` when producing formal evidence.

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git \
  markitdown-quality-lab
moon build --target native --release --package ZSeanYves/markitdown

# The conversion product has no OCR/audio/model installer. Install only the
# pinned benchmark comparison environment when the affected evidence requires
# the external reference.
./tools/env/installers/install_bench_baseline_deps.sh --python /path/to/python3.11

./tools/regression/check_balance.sh
./tools/regression/check_balance_quality.sh
./tools/regression/check_accurate.sh
python3 tools/regression/lib/quality/intake_lint.py \
  --lab-root markitdown-quality-lab --strict
python3 tools/regression/mutation_smoke.py
```

The root build above is the user-facing CLI. Release artifacts use the
optimized binary under
`_build/native/release/build/markitdown.exe`.

After a version is published, verify the package-consumer path separately with
the exact MoonX coordinate:

```bash
moonx tools/regression/run_moonx_regression.mbtx ZSeanYves/markitdown@<exact-version>
```

This post-publication gate is required for MoonX compatibility evidence; a
local prebuilt binary or an unpublished worktree cannot satisfy it.

All formal regression runs must finish with zero skipped and zero failed rows.
Use format filters documented by each command while iterating, then run the
complete affected suite before submission. Accurate capability regression is a
functional gate; formal performance benchmarks measure balance mode only.

Normal pushes and pull requests run the benchmark runner with
`--preset change-risk`; its performance status may be `not_applicable`, but
truth and RSS must pass. Scheduled CI runs mutation smoke and the full
`official-external-compare` preset. Before publishing benchmark numbers, build
the release CLI and runner, run `doctor`, and retain the identified run under
`.tmp/bench/runs/<run_id>/`. Published numbers must update
`docs/performance.md` and the generated summaries under `bench/results/` in the
same PR; cross-fingerprint self-baseline comparisons are not valid evidence.

Changes to format behavior should add a self-contained contract fixture first.
Large or third-party inputs belong in `markitdown-quality-lab` with license,
SHA-256, provenance, and manifest signals. Never update a golden output merely
to hide information loss.

Keep the public conversion API, route provenance, source references, and asset
semantics compatible unless the change is explicitly documented. OCR and audio
are retired capabilities in 0.8; PDF accurate remains a bounded native
text-layer mode and must not acquire an external recognizer dependency.
