# 0.8 release-candidate acceptance

The release-candidate gate is defined by
`.github/workflows/rc.yml`. It runs on Ubuntu 24.04 and macOS 15, checks every
declared target, builds the root Native and Wasm products, exercises the
capability entry point, runs the governance and regression unit gates, and
publishes checksummed artifacts. Each platform runs twice (`rc1` and `rc2`);
the round is part of every artifact name. The Linux performance job checks out
quality-lab at the pinned `MARKITDOWN_QUALITY_LAB_SHA`, installs the benchmark
reference, and runs `official-external-compare` against the release binaries.
RC acceptance requires trusted truth, passing RSS, a non-empty comparison and
`gate_summary.performance.status == "pass"`. `not_applicable` is a valid
state for normal change-risk CI only; it never closes an RC gate.

The local equivalent is:

```bash
moon fmt --check
moon info
moon check --target all --warn-list +73
moon test --target all --no-parallelize
moon build --target native --release --package ZSeanYves/markitdown
moon build --target wasm --release --package ZSeanYves/markitdown
moon run --target wasm . -- --capabilities
python3 tools/governance/check_architecture.py
python3 tools/governance/check_documentation.py
```

The release artifacts are `_build/native/release/build/markitdown.exe` and
`_build/wasm/release/build/markitdown.wasm`; the workflow checks both files
are non-empty before checksumming them. The root package is the Moonx
executable. Registry validation is a separate post-publication gate:

```bash
moonx tools/regression/run_moonx_regression.mbtx ZSeanYves/markitdown@<version>
```

This command must consume the exact published coordinate and its Wasm prebuilt
asset. A local build, cache, or `.mbtx` probe that does not invoke the published
package does not satisfy that gate. Native Moonx compatibility is verified
separately from the default Wasm artifact. The MoonX consumer gate reuses the
same balance, quality, and accurate manifests as the source gate and stores
separate evidence under `.tmp/moonx-regression/`.

The performance evidence in `performance.md` is historical until both RC
rounds produce same-fingerprint comparisons. A macOS run cannot close the
Linux acceptance gate; the Ubuntu job in `rc.yml` is the authoritative Linux
check. Missing quality-lab data, an unavailable reference executable, a
fingerprint mismatch, an empty comparison, or `not_applicable` fails closed.

The release owner attaches both round artifacts, the pinned quality-lab
revision, and a rollback record containing the previous verified archive,
checksum and install command. The workflow records the previous Git revision
as a minimum rollback reference; publication still requires a fresh-machine
rollback smoke test documented in the release checklist.

Warnings are not silently grandfathered. The pinned toolchain now passes
`moon check --target all --warn-list +73 --deny-warn` with zero diagnostics on
the local Native/Wasm/all-target runs. The reviewed evidence, toolchain
versions and rerun rule are recorded in
`tools/governance/warning-baseline.json`. The ODS/ODF white-box ZIP fixtures
use the shared target-neutral test helper, so the build plan has no remaining
target notices either.
