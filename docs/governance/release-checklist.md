# Release checklist

Use this checklist for the unreleased 0.8 line.

## Source

- [ ] Version, changelog, migration guide, and capability declaration agree.
- [ ] Quality-lab revision and exact package coordinate are recorded.
- [ ] Dependency and FFI changes have a reviewed reason and removal condition.
- [ ] OCR, audio, and scanned-page recognition remain absent from the product.

## Checkout checks

- [ ] `moon fmt --check` and `moon info` pass with reviewed interface changes.
- [ ] `moon check --target all --warn-list +73 --deny-warn` passes.
- [ ] Native and Wasm tests pass independently.
- [ ] Native and Wasm release artifacts build from a clean checkout.

## MoonX consumer checks

- [ ] `moonx_smoke.mbtx` passes for the exact published coordinate.
- [ ] Main, quality, accurate, and PDF rows pass through
      `run_moonx_regression.mbtx` with zero failed rows.
- [ ] `moonx_benchmark.mbtx` produces complete Wasm and Native summaries.
- [ ] Public capability output matches the package artifact and declared
      Native extensions.

## Evidence and rollback

- [ ] Quality-lab revision, target, host, toolchain, summaries, and logs are
      attached from `.tmp/moonx-*`.
- [ ] Previous verified package version and rollback instructions are recorded.
- [ ] Missing registry assets, missing outputs, and incomplete evidence are
      treated as release blockers.
