# Benchmark Corpus Policy

This directory holds the repository's checked-in benchmark manifests, synthetic
benchmark samples, and warning-policy files.

It is intentionally not a dumping ground for every interesting local document.

## Corpus Tiers

### Tier 0: Regression samples

Location:

* `samples/main_process`
* `samples/metadata`
* `samples/assets`

Purpose:

* correctness and golden-output regression
* H2/H3 behavior protection

Rules:

* checked in
* small and explainable
* every sample should have a clear intent

### Tier 1: Benchmark smoke corpus

Location:

* `samples/benchmark/corpus.tsv`
* files under `samples/benchmark/<format>/...`

Purpose:

* stable same-machine smoke signals
* conservative warning coverage through `bench_warn`

Rules:

* checked in
* size-conscious
* optimized for stable signals, not for full real-world coverage

### Tier 2: Synthetic stress corpus

Typical shape:

* generated large rows
* many-entry archives
* large sheets
* nested structured data

Preferred storage policy:

* keep generators, manifests, or documented parameters where possible
* avoid checking in large binary artifacts unless they are clearly justified
* record generation seed/parameters when a synthetic sample matters to a
  benchmark story

### Tier 3: Real-world public corpus

Preferred shape:

* external/manual corpus manifest
* public provenance and license clarity
* locally downloaded and manually managed

Recommended manifest shape:

* `samples/benchmark/external_corpus.tsv` or a local derivative of
  `corpus_manifest.example.tsv`

Rules:

* do not commit large public corpora casually
* keep license and provenance explicit
* decide daily/pre-release participation intentionally

### Tier 4: Private/manual corpus

Purpose:

* local profiling on confidential or customer-shaped inputs
* one-off investigations

Rules:

* do not commit private corpora
* do not write private benchmark conclusions as universal claims
* summarize findings in docs without shipping sensitive inputs

## Checked-in Files

Current checked-in benchmark control files:

* `corpus.tsv`
* `compare_corpus.tsv`
* `perf_thresholds.tsv`
* `corpus_manifest.example.tsv`
* `../scripts/check_corpus_manifest.sh`

## Manifest Checker

Validate the checked-in example manifest:

```bash
./samples/scripts/check_corpus_manifest.sh
./samples/scripts/check_corpus_manifest.sh samples/benchmark/corpus_manifest.example.tsv
```

The checker is intentionally a light governance helper:

* offline
* local-only
* not part of the default `samples/check.sh` contract today
* suitable for validating future public/private/manual manifest additions

Manifest fields:

```text
id	format	tier	path_or_uri	size_bytes	license	provenance	include_daily	include_pre_release	notes
```

Field notes:

* `id`: unique stable manifest id
* `format`: repository format family or `mixed`
* `tier`: `regression`, `smoke`, `synthetic`, `public`, `private`, `manual`
* `path_or_uri`: repo path, local path, or URL depending on the tier
* `size_bytes`: optional non-negative integer when known
* `license`: explicit provenance/license marker
* `provenance`: how the row entered the workflow
* `include_daily` / `include_pre_release`: governance-only booleans
* `notes`: optional human context

## How To Add A Benchmark Sample

1. Decide which corpus tier the sample belongs to.
2. Prefer a small, stable checked-in sample for Tier 1.
3. If the sample is large or synthetic, record how it was produced.
4. If the sample is real-world or sensitive, keep it out of the repository and
   use a manifest or local notes instead.
5. Update warning thresholds only when repeated native measurements justify it.

For checked-in smoke samples:

* add the file under `samples/benchmark/<format>/...`
* add or update the row in `corpus.tsv`
* update the example manifest only if it remains a useful checked-in example
* run `./samples/scripts/check_corpus_manifest.sh`

For public/private/manual corpora:

* do not add the real files to the repository
* use a local or external manifest derived from `corpus_manifest.example.tsv`
* keep private paths out of checked-in files

## Warning Policy Reminder

Thresholds in `perf_thresholds.tsv` are conservative manual warnings:

* not a formal SLA
* not a blanket CI hard gate
* intended for native-preferred local runs with local-machine caveats
