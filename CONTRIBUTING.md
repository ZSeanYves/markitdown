# Contributing

Use the rolling MoonBit toolchain supported by the repository. Do not pin a
historical MoonBit release in project metadata.

Before submitting any change, run the self-contained checks:

```bash
moon fmt --check
moon info && git diff --exit-code
moon check
moon test
./tools/regression/check_coverage.sh --enforce
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
moon build cli --target native

# Required when the affected rows use image OCR, audio, or accurate OCR/PDF.
./tools/env/optional_deps.sh install balance
./tools/env/optional_deps.sh install audio
./tools/env/optional_deps.sh install accurate
./tools/env/optional_deps.sh check all

./tools/regression/check_balance.sh
./tools/regression/check_balance_quality.sh
./tools/regression/check_accurate.sh
```

The non-release build above is the development regression runner. User-facing
documentation and release artifacts use the optimized release binary under
`_build/native/release/build/cli/cli.exe`.

All formal regression runs must finish with zero skipped and zero failed rows.
Use format filters documented by each command while iterating, then run the
complete affected suite before submission. Accurate capability regression is a
functional gate; formal performance benchmarks measure balance mode only.

Changes to format behavior should add a self-contained contract fixture first.
Large or third-party inputs belong in `markitdown-quality-lab` with license,
SHA-256, provenance, and manifest signals. Never update a golden output merely
to hide information loss.

Keep the public conversion API, route provenance, source references, and asset
semantics compatible unless the change is explicitly documented. Optional OCR,
audio, and PDF accurate behavior must not become a hidden dependency of core
native readers.
