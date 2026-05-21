# Roadmap

This page tracks the current forward-looking direction for the repository.

## Current Baseline

Current checked baseline:

* `moon test`: `1579 passed`
* `bash samples/check.sh`: `444` markdown / `85` metadata / `90` assets / `0`
  failures
* public-only quality: `24 / 0 / 0`
* full quality with quality-lab: `330 / 1 / 0`
* focused PDF quality with quality-lab: `101 / 1 / 0`

Current structural baseline:

* runtime/test/public-only flow is self-contained in the main repo
* repo-root `markitdown-quality-lab/` carries external corpus, full quality
  rows, and offline training/eval assets
* normal PDF layout behavior is distilled into MoonBit rules/gates
* no runtime model JSON dependency exists today

## Near-Term Direction

Current priorities:

* keep docs aligned with the current release-state workflow
* keep PDF layout work narrow, explicit, and evidence-led
* continue failure-driven hardening across Office and horizontal formats
* keep performance claims sample-scoped and reproducible

## Legacy Fallback Exit Criteria

Legacy fallback removal should wait until all of the following stay true on the
same cycle:

1. repo-root quality-lab full quality still passes `330 / 1 / 0`
2. public-only still passes `24 / 0 / 0`
3. `moon test` and `bash samples/check.sh` still pass
4. no non-doc runtime/product path depends on `.external/...`
5. no active workflow still depends on `external_manifest.local.tsv`
6. quality-lab still tracks `quality_rows/manifest.tsv` and `corpus/MANIFEST.tsv`
7. at least one full post-migration cycle has completed

## Legacy Fallback Removal Plan

Current staged removal plan:

* Phase 1: remove legacy examples from user-facing docs while keeping lifecycle notes
* Phase 2: remove sibling `../markitdown-quality-lab` lookup
* Phase 3: remove legacy `samples/quality_corpus/external_manifest.local.tsv` runner fallback
* Phase 4: remove legacy `.external/quality_corpus/...` resolution from runner/helpers
* Phase 5: remove legacy `.external/layout_model/...` debug/layout-assist mapping

## Long-Term Direction

Long-term direction remains:

* main repo for runtime, tests, samples, and public baseline
* quality-lab for external corpus, full quality rows, and offline training/eval/model/report assets
* narrow, explicit, evidence-backed normal-path changes only
