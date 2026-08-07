# ADR 0004: Normalize the MoonBit Source Root

- Status: accepted
- Date: 2026-08-07
- Owners: @ZSeanYves
- Related: Phase 1.5 repository layout normalization

## Context

Phase 1 reduced the package graph from 108 packages at audit time to 68 and
established `ZSeanYves/markitdown/api` as the stable facade. The repository
root nevertheless still exposed every functional package beside documentation,
samples, benchmark assets, and engineering tools. Phase 2 will add compatibility
corpora and laboratory automation, which would make that mixed root harder to
navigate and govern.

MoonBit supports a module-level source directory. Setting `source = "src"`
makes package paths relative to `src/`, so moving `api/` to `src/api/` preserves
the logical package name `ZSeanYves/markitdown/api`.

## Decision

- `src/` is the sole MoonBit package root and every `moon.pkg` must live below
  it.
- Product packages retain their relative package paths beneath `src/`; the
  stable facade and all existing functional imports therefore keep their names.
- The cross-package test package becomes `internal/integration_tests`.
- The MoonBit benchmark executable becomes `internal/bench_runner`; root
  `bench/` contains only benchmark policy, documentation, manifests, baselines,
  and reports.
- Root directories are limited to source, documentation, benchmark/sample
  assets, engineering tools, and repository metadata.
- This change does not combine packages or redesign implementation APIs.
  Further logical consolidation is a separate reviewable change.

## Consequences

Contributor-facing filesystem paths now begin with `src/`, while MoonBit import
paths do not. Governance, coverage, CODEOWNERS, runtime inventory, CLI freshness
checks, and generated-file policy must distinguish physical paths from logical
package paths. The benchmark runner has a new internal package and artifact
path, but retains its commands, policies, and legacy argument aliases.

The package count, public declaration counts, behavior, and stable API golden
must remain unchanged. No MoonBit package may be added outside `src/`.

## Verification and rollback

```bash
find . -name moon.pkg -not -path './src/*'
moon info && moon fmt
moon check --target all --warn-list +73 --deny-warn
moon test --target all
MOONBIT_NEW_NATIVE=1 moon test --target native --no-parallelize
./tools/regression/check_coverage.sh --enforce
python3 tools/governance/check_architecture.py
```

The first command must produce no tracked project package. Generated interfaces
other than the renamed internal benchmark/test packages must be content-identical.
Rollback reverts the source-root commit as a unit.
