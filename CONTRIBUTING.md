# Contributing

Product code and repository automation use MoonBit. Write automation in
`.mbtx`; use structured process arguments instead of shell scripts. The product
targets Linux x86_64 and macOS arm64 with the Native backend.

## Development checks

Use MoonBit `0.1.20261021` / `moonc v0.10.17+093cb8f9c` and a C compiler.
Run MoonBit commands serially because the repository shares its build lock:

```text
moon check --target native --warn-list +73 --deny-warn
moon test --target native --no-parallelize
moon test --target native --release --no-parallelize
moon build --target native .
moon build --target native --release .
moon info
moon fmt
```

Review generated `.mbti` diffs; do not edit generated interfaces manually.
These checks cover the checkout and its artifacts. Installation, independent
library consumption, full quality regression and performance have separate
gates in the [upgrade plan](docs/architecture/native-performance-plan.md).

## Native consumer and regression validation

Use `tools/regression/native_install.mbtx` to check installation and an
independent module that imports only the public façade. See the
[tooling guide](tools/regression/README.md) for its arguments. Validate local
source and a fixed Git commit before publication; verify the exact registry
version after publication. The checks must not publish a package.

```text
moon run --target native tools/regression/native_install.mbtx --source local --root /absolute/path/to/markitdown --evidence /absolute/path/to/new-install-evidence
```

Run affected corpus cases against the actual Native executable, using the
pinned sibling `markitdown-quality-lab` checkout:

```text
moon run tools/regression/run_native_regression.mbtx --binary /absolute/path/to/installed/markitdown --lab /absolute/path/to/markitdown-quality-lab --suite all --evidence /absolute/path/to/new-regression-evidence
```

Use `--suite quality`, `--suite accurate`, `--format FORMAT`, or `--case ID`
for diagnosis, then run every affected valid contract. Preserve existing
quality-lab changes and save failed-run summaries. A fake runner validates
the harness only. A missing registry version is a missing publication, not a
passed consumer gate.

## Format changes

Every format change should explain:

1. The public capability, output, resource limit or diagnostic that changes.
2. The deterministic fixture or quality-lab case that proves the behavior.
3. How text, structure, order, sources, metadata, diagnostics and assets are
   preserved across collecting and Sink delivery where supported.

Never update a golden to hide lost content or bypass integrity/resource
checks. Add third-party samples with license, hash, provenance and manifest
entries. Evaluate performance only after quality passes, on the same input,
mode, limits, assets and output target.

## Scope and target rules

The product converts text and preserves document images as assets. OCR,
audio transcription, scanned-page recognition, image recognition, rendering
engines and formula recalculation are outside the product boundary.

Keep the thin root `main.mbt`, public `lib`, and private `internal` split.
There is one Native conversion chain. Small FFI boundaries must record their
necessity, ownership, transitive dependencies and removal condition in the
[FFI inventory](docs/ffi-inventory.md).

Wasm, Wasm-GC and JavaScript product distributions and their compatibility
implementations are retired. Repository `.mbtx` scripts may use the toolchain's
script runtime, but must invoke actual Native product artifacts for acceptance.

## Documentation

Update the nearest maintained document when behavior changes. Keep product
installation examples on `moon install` and script examples on `.mbtx`.
Do not describe candidate, hosted-platform or post-publication gates as passed
until their saved evidence exists.
