# ADR 0003: Complete Phase 1 Boundaries and Consolidate Packages

- Status: accepted
- Date: 2026-08-07
- Owners: @ZSeanYves
- Related: Phase 0-1 completion audit

## Context

The first Phase 0-1 delivery introduced a stable `api` facade but left 108
MoonBit packages, 223 `pub(all)` declarations, independently compiled test
packages, and legacy parser/reader/pipeline surfaces that remained importable.
The audit also found that resource and RAG options could not be customized by
external callers, CLI exit codes depended on human-readable messages, and
reader callbacks were not checked consistently on cursor paths.

Keeping the existing package topology would preserve obsolete deep imports at
the cost of continuing the maintenance problem Phase 1 was intended to solve.
This repository is still pre-1.0, and the accepted maintenance plan explicitly
allows a concentrated breaking reorganization in 0.8.

## Options considered

1. Keep all packages and document them as unstable. This leaves compilation,
   interface generation, ownership, and dependency costs unchanged.
2. Introduce compatibility wrappers for every old package. This preserves the
   same package count and public surface for at least another release.
3. Consolidate packages by domain, move implementation packages behind an
   internal boundary, and preserve only the 0.8 facade as a stable contract.

## Decision

Choose option 3.

- `ZSeanYves/markitdown/api` remains the sole stable library package.
- Legacy deep-package imports may break in 0.8 and receive migration guidance,
  but no compatibility wrapper is retained solely to preserve package count.
- Standalone test packages move into black-box test files owned by the package
  under test.
- Benchmark command, manifest, measurement, and tool helpers become files in a
  single benchmark runner package.
- Closely coupled reader and lowering packages are consolidated by format or
  format family. PDF, OOXML, ODF, ZIP, runtime, and FFI boundaries remain split
  unless their dependency and safety contracts justify a later merge.
- The completed Phase 1 baseline contains 68 MoonBit packages, at most 210
  `pub(all)` declarations, and at most 22 mutable `pub(all)` records. The
  mutable-record ceiling is separate so enums required for cross-package
  matching cannot hide a widening constructible record surface.
- Stable options use immutable builders, CLI exits derive from typed errors,
  and reader length/size contracts are enforced at the input boundary.
- Governance records package, public-surface, FFI, command, network, resource,
  dependency-license, coverage, and generated-interface inventories.

## Consequences

Deep implementation imports are intentionally source-incompatible. Stable API
consumers continue to use the same package and receive additive builders and
more precise error contracts. Fewer compilation units and generated interfaces
reduce build graph and review overhead. Consolidated packages may contain more
files, but files remain grouped by syntax, lowering, and tests and must stay
below the existing per-file size guideline.

Each domain merge is validated independently before the architecture migration
commit is created. Rollback of the package topology uses that commit; the
stable API and governance changes remain separately reviewable in the diff.

## Verification and rollback

```bash
python3 tools/governance/collect_baseline.py --check
python3 tools/governance/check_architecture.py
moon check --target all --warn-list +73 --deny-warn
moon test --target all
MOONBIT_NEW_NATIVE=1 moon test --target native --no-parallelize
./tools/regression/check_coverage.sh --enforce
```

The PR must also pass the full remote CI matrix on Linux and macOS. Rollback is
performed per logical commit; the pre-change release remains `0.8.0` at commit
`b49212c`.
