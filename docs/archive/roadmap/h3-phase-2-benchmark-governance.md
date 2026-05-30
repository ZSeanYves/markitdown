# H3 Phase-2 Benchmark Governance

Status: historical phase-planning reference.

For the current benchmark governance and current benchmark command menu, use:

* [docs/archive/benchmark/benchmark-governance.md](../benchmark/benchmark-governance.md)
* [docs/performance.md](../../performance.md)

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
bash samples/check.sh
bash samples/scripts/bench_warn.sh --all
```

Optional targeted fast rerun:

```bash
bash samples/bench.sh --suite smoke --kind smoke --format <format>
```

Daily notes:

* this tier should stay quick and low-noise
* it is for catching obvious regressions, not for re-proving every benchmark
  story on every edit
* warnings remain manual warnings, not hard SLAs

### Pre-release benchmark suite

Use before releases or performance-significant changes:

```bash
moon fmt
moon info
moon check
moon test
bash samples/check.sh
bash samples/bench.sh --suite smoke
bash samples/bench.sh --suite compare
bash samples/bench.sh --suite batch-profile
bash samples/scripts/bench_warn.sh --all
moon publish
```

Pre-release notes:

* compare depends on Python MarkItDown availability
* memory / RSS observation may vary by platform
* `moon publish` may be gated by network or auth state rather than repository
  correctness alone

### Manual / investigation suite

Use for profiling or targeted residual work:

```bash
MARKITDOWN_PROFILE_XLSX=1 ...
MARKITDOWN_PROFILE_JSON=1 ...
MARKITDOWN_PROFILE_TXT=1 ...
MARKITDOWN_PROFILE_CSV=1 ...
MARKITDOWN_PROFILE_YAML=1 ...
MARKITDOWN_PROFILE_ZIP=1 ...
bash samples/bench.sh --suite smoke --kind smoke --format yaml --warmup 3 --iterations 10
```

Manual notes:

* local corpus experiments outside the checked-in baseline
* single local runs should not be over-interpreted as universal truth
* profile output stays local under `.tmp`; only summarized conclusions belong
  in docs

These are intentionally investigation tools, not default release gates.

## 3. Warning Policy

Current policy:

* warnings are conservative and advisory first
* smoke warnings are runner-aware
* compare warning policy remains future work
* one noisy local run should not be treated as a product regression by itself
* default warning mode exits `0`
* `--strict` upgrades warnings to exit `1` when intentionally requested

Future direction:

* keep warnings lightweight and interpretable
* only harden toward CI gating after signal quality is stable

Threshold-setting principles:

* use native-preferred measurements
* prefer repeated measurements over one-off spikes
* treat local-machine results as local-machine results
* do not treat `moon run` timings as native product-path proof
* keep compare warning policy separate until it is implemented deliberately

## 4. Corpus Policy

Phase 2 uses a tiered corpus model.

### Tier 0: regression samples

Location:

* `samples/main_process`
* `samples/main_process/<format>/expected`

Use:

* golden-output correctness protection
* H2/H3 behavior regression coverage

### Tier 1: benchmark smoke corpus

Location:

* `samples/benchmark`
* `samples/benchmark/corpus.tsv`

Use:

* stable same-machine smoke signals
* `bench_smoke` and `bench_warn`

### Tier 2: synthetic stress corpus

Typical use:

* very large rows
* many-entry archives
* large sheets
* nested structured data

Preferred policy:

* keep generators, seeds, manifests, or documented parameters when possible
* avoid checking in large binaries casually

### Tier 3: real-world public corpus

Preferred shape:

* manifest-driven, locally downloaded public documents
* clear provenance and license

### Tier 4: private/manual corpus

Use:

* local-only confidential or customer-shaped investigations

Rules:

* never commit private corpora
* summarize outcomes without shipping sensitive files

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

See [samples/benchmark/README.md](../../../samples/benchmark/README.md) and
[samples/benchmark/corpus_manifest.example.tsv](../../../samples/benchmark/corpus_manifest.example.tsv)
for the checked-in policy/template entry point.

Checker entry point:

```bash
bash samples/check.sh --manifest-only
```

The lower-level `samples/scripts/check_corpus_manifest.sh` helper remains
available for maintainer-only direct checks, but the public entrypoint is now
`bash samples/check.sh --manifest-only`.

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
