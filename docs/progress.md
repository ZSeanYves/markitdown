# Progress Summary

This document is a current-state summary, not a full chronological log.

For detailed format behavior, use
[docs/support-and-limits.md](./support-and-limits.md).

For second-round support/benchmark/parser-gap planning, use
[docs/second-round-hardening-audit.md](./second-round-hardening-audit.md).

## Current State

The repository is currently in a stable post-initial-H2, post-H3-phase-1
state:

* dispatcher coverage spans all primary format families, but maturity is split
  across `H2 main-path quality`, `H2 partial`, `subset-H2`,
  `source-preserving H1/H2 partial`, and `container/ebook H2 partial`
* documented limitations remain explicit rather than hidden behind milestone
  labels
* unified IR / Markdown emitter / metadata sidecar are stable repository
  contracts
* sample validation is organized around integrity, main output, metadata
  sidecars, and assets
* `./samples/check_metadata.sh` now explicitly exercises `--with-metadata` and
  validates the core sidecar contract
* benchmark harnesses for smoke, overlap comparison, batch profiling, and
  warnings are in place
* vendored `mbtpdf` is treated as a repository-local maintained dependency,
  with optional/manual upstream-style e2e isolated from the default root test
  story

## Stable Milestone Status

Current stable milestone docs are:

* [docs/full-format-h2-completion.md](./full-format-h2-completion.md)
* [docs/h3-phase-1-summary.md](./h3-phase-1-summary.md)
* [docs/h3-phase-2-benchmark-governance.md](./h3-phase-2-benchmark-governance.md)

In short:

* the repository is past its initial full-format H2 expansion phase, but
  several format families remain intentionally partial, subset-oriented, or
  source-preserving
* H3 phase 1 performance optimization is done as a milestone artifact
* broader speed conclusions still require benchmark evidence by runner, mode,
  and corpus
* the next H3 step is benchmark governance and broader corpus discipline, not
  another urgent converter hot-path cut

## Validation Contract

The repository currently expects these checks to be the normal stability bar:

```bash
moon check
moon test
./samples/check.sh
```

`./samples/check.sh` aggregates integrity, main output, metadata-sidecar, and
asset checks; metadata validation is no longer just a Markdown smoke path.

Useful benchmark and warning commands remain:

```bash
./samples/scripts/bench_smoke.sh
./samples/scripts/bench_compare_markitdown.sh
./samples/scripts/bench_batch_profile.sh
./samples/scripts/bench_warn.sh --all
```

## Current Priorities

The current next-stage priorities are:

* H3 phase 2 benchmark governance
* broader representative corpora, including larger real-world documents
* optional memory / RSS observation where platform support exists
* release/documentation polish
* selective H2.1 quality work where product value is clear
* corpus manifest validation tooling for future public/private/manual corpus
  tracking without checking sensitive paths into the repository

## Current Product Position

The project should now be read as:

* a MoonBit-native multi-format document-to-Markdown tool
* conservative and auditable rather than visually reconstructive
* past the first full-format milestone sweep, with second-round hardening now
  focused on stricter support boundaries and stronger evidence
* no longer in an "H2 in progress" or "first H3 hotspot triage" state
* currently focused on long-term benchmark governance and broader-corpus
  discipline rather than on ad-hoc micro-optimization
