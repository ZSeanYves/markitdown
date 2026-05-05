# H3 Phase-2 Benchmark Governance

This document records the next H3 benchmark phase after the first performance
wave was closed out.

Phase 2 is about governance and corpus discipline, not about chasing every
remaining local `20-40 ms` row.

## 1. Scope

Phase 2 focuses on:

* benchmark suite layering
* warning-policy governance
* corpus expansion strategy
* optional memory / RSS observation
* investigation workflow discipline

It does not imply universal performance claims or blanket parity claims.

## 2. Suite Layers

### Daily / local fast suite

Use for routine development confidence:

```bash
moon check
moon test
./samples/check.sh
./samples/scripts/bench_warn.sh --all
```

### Pre-release benchmark suite

Use before releases or performance-significant changes:

```bash
./samples/scripts/bench_smoke.sh
./samples/scripts/bench_compare_markitdown.sh
./samples/scripts/bench_batch_profile.sh
./samples/scripts/bench_warn.sh --all
```

### Manual / investigation suite

Use for profiling or targeted residual work:

* targeted smoke reruns such as `--format zip` or `--format yaml`
* opt-in profiler flags like `MARKITDOWN_PROFILE_XLSX=1`
* local corpus experiments outside the checked-in baseline

These are intentionally investigation tools, not default release gates.

## 3. Warning Policy

Current policy:

* warnings are conservative and advisory first
* smoke warnings are runner-aware
* compare warning policy remains future work
* one noisy local run should not be treated as a product regression by itself

Future direction:

* keep warnings lightweight and interpretable
* only harden toward CI gating after signal quality is stable

## 4. Corpus Policy

Public checked-in corpora should aim for:

* small / medium / large representative cases
* capability-focused edge cases
* stable local reruns

Local or private investigation corpora may be used for:

* larger real-world documents
* confidential customer-shaped documents
* one-off profiling passes

Those corpora should inform decisions without being confused with the public
checked-in baseline contract.

## 5. Memory / RSS

Phase 2 keeps memory observation optional:

* use it when platform support exists
* keep it out of the required fast local contract for now
* document unavailable states explicitly rather than faking precision

## 6. Non-goals

Phase 2 does not try to:

* turn local benchmark numbers into universal claims
* keep every historical profiling note as a first-class document
* force all benchmark investigation workflows into a hard CI gate
* imply that every remaining local residual row needs immediate optimization
