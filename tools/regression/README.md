# Regression Entrypoints

`tools/regression/` owns the formal repository regression surfaces and their
shared helper scripts.

Primary entrypoints:

```bash
./tools/regression/check_balance.sh
./tools/regression/check_balance_quality.sh
./tools/regression/check_accurate.sh
```

These entrypoints depend on:

- a built native CLI: `moon build cli --target native`
- repo-managed optional runtimes from `tools/env/` when OCR or audio are used
- the external `markitdown-quality-lab` repository at the repo root

Internal support code lives under `tools/regression/lib/`:

- `shared/` common shell helpers
- `quality/` external quality signal evaluation
- `validation/` main regression validation pipeline
- `mocks/` deterministic local test doubles
- `smoke/` and `verify/` lightweight auxiliary checks

Run artifacts continue to be written under `./.tmp/`.
