# ADR 0001: Freeze the Phase 0 Baseline

- Status: accepted
- Date: 2026-08-05
- Owners: @ZSeanYves
- Related: Phase 0 maintenance plan

## Context

The project has a large generated public surface and a mixed local MoonBit
installation. The previous benchmark lock referred to MarkItDown 0.1.6 while
the current upstream release is 0.1.7.

## Decision

The formal Phase 0 baseline is MarkItDown `v0.1.7` at the recorded commit,
Python 3.11 with the checked-in benchmark lock, MoonBit components recorded in
`tools/governance/toolchain.json`, and the C native backend with
`MOONBIT_NEW_NATIVE=0`. The semantic core remains checked on wasm, wasm-gc, js
and native. The new native backend originally had only a passing CLI canary
because the full suite linked the obsolete `_moonbit_get_cli_args` symbol
through `moonbitlang/x/sys`. Phase 0 completion moved executable argument
access to `moonbitlang/core/env` and process exit to the native-only
`runtime/process` package. The full new-native suite is now a blocking CI
matrix on macOS and Linux.

## Consequences

Native release evidence is comparable and currently reproducible. The
new-native backend is a full-suite release gate. Any upstream,
toolchain, lock or fixture change requires an explicit baseline update and
review.

## Verification

```bash
python3 tools/governance/collect_baseline.py --check
MOONBIT_NEW_NATIVE=0 moon test --target native
MOONBIT_NEW_NATIVE=1 moon test --target native --no-parallelize
moon check --target all --warn-list +73 --deny-warn
```
