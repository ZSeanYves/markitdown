# Regression Tooling

`tools/regression/` contains release-facing validation entrypoints. Unit tests
remain self-contained in the main repository; formal regression and benchmark
payloads live in the pinned `markitdown-quality-lab/` checkout.

## Gates

```bash
moon build cli --target native
./tools/regression/check_balance.sh
./tools/regression/check_balance_quality.sh
./tools/regression/check_accurate.sh
./tools/regression/check_coverage.sh --enforce
python3 tools/regression/mutation_smoke.py
```

This debug/native build is intentional for development regression turnaround;
end-user examples use the release CLI.

- `check_balance.sh`: main product contracts across Markdown, RAG, assets, and
  explicit OCR lanes.
- `check_balance_quality.sh`: larger real-world, provenance-backed quality set.
- `check_accurate.sh`: functional accurate capability gate. Accurate is not
  included in formal performance benchmarks.
- `check_coverage.sh`: tiered core/formats/tools coverage thresholds.
- `mutation_smoke.py`: deterministic malformed-input smoke for scheduled CI.
- `self_baseline.py`: capture and enforce fingerprinted self baselines.

`run_with_release_manifest.sh` wraps a command and records repository/runtime
fingerprints plus required artifacts. CI uploads these manifests with the gate
outputs. A non-zero command, missing artifact, skipped row, or failed row must
remain visible to the caller.

The shared implementation lives under `lib/`; callers should use the top-level
entrypoints rather than individual library scripts.
