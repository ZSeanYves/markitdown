# PDF v2 Pre-Model-Training Readiness

Date: 2026-06-13

Baseline commit inspected: `9c2b2e4 pdf_v2: audit header footer repetition evidence`

## Scope

This pass intentionally targeted:

- non-semantic PDF parity cleanup that can be fixed or audited with typed evidence
- sample-check runner/reporting cleanup
- PDF v2 signal/export stabilization for future model training
- debug/export scaffolding cleanup by keeping export opt-in and out of product runtime

This pass intentionally did not:

- train any model
- load or run any model in product runtime
- add runtime inference
- add phrase-specific, sample-specific, or normalizer string patches
- patch frozen semantic-rule-owned heading/title/list failures
- change sample expected files for partial or ambiguous improvements

## Baseline Sample Status

Authoritative baseline was taken from:

- `samples/check.sh --format pdf`
- run log: `.tmp/check/runs/pdf-20260613-195805-6660/logs/markdown-only.entrypoint.log`

Baseline wrapper problem:

- the top-level wrapper reported `rows=0 checked=0 failed=0`
- the authoritative markdown-only log reported `30 samples, 9 failures`

Baseline failing sample ids:

1. `assets/pdf_image_form_xobject`
2. `assets/pdf_image_inline`
3. `assets/pdf_image_xobject`
4. `pdf_cross_page_should_merge_phase15`
5. `pdf_cross_page_should_not_merge_phase15`
6. `pdf_header_footer_variants_phase15`
7. `pdf_heading_false_positive_phase15`
8. `pdf_heading_vs_short_sentence`
9. `pdf_two_column_negative_phase15`

## Failure Taxonomy

### Frozen semantic-rule-owned

These remain intentionally deferred to later model-backed semantic arbitration:

1. `pdf_cross_page_should_merge_phase15`
   visible diff: title/body remains collapsed into one plain line
   owner: semantic arbitration
2. `pdf_cross_page_should_not_merge_phase15`
   visible diff: title and section heading stay plain text
   owner: semantic arbitration
3. `pdf_header_footer_variants_phase15`
   visible diff: heading levels and final page body/title split still differ
   owner: semantic arbitration
4. `pdf_heading_false_positive_phase15`
   visible diff: broader heading/list/body ownership remains collapsed
   owner: semantic arbitration
5. `pdf_heading_vs_short_sentence`
   visible diff: list ownership remains unresolved
   owner: semantic arbitration
6. `assets/pdf_image_inline`
   visible diff: opener line stays paragraph instead of heading
   owner: semantic arbitration
7. `assets/pdf_image_xobject`
   visible diff: opener line stays paragraph instead of heading
   owner: semantic arbitration

### Deferred layout / evidence-insufficient

1. `pdf_two_column_negative_phase15`
   visible diff: content order still reflects parser/source order without reliable column reconstruction
   owner: reading order / geometry
   action: defer to later layout recovery helper model or stronger geometry evidence

2. `assets/pdf_image_form_xobject`
   visible diff: `Image inside Form XObject` is still absent before the image
   owner: parser/model or image-text evidence availability
   evidence status: current v2 output keeps heading, paragraph, and image asset, but does not surface typed evidence proving that the missing line should be emitted as caption or body text in the product path
   action: audit-only; defer rather than patch with handwritten ownership rules

## Changes Made

### 1. Sample-check runner and reporting

Files:

- `samples/check.sh`
- `samples/helpers/shared/validation_helpers.sh`
- `samples/helpers/contracts/check_samples_check_contract.sh`

What changed:

- wrapper summary parsing now understands failure logs of the form
  `FAILED ... (30 samples, 9 failures)`
- wrapper `summary.md`, `summary.tsv`, and terminal result now report real PDF totals
- native CLI auto-probe no longer depends on `pptx_hidden_slide_basic` parity; this removed a false `runner=none` / `rows=0` failure mode for PDF sample checks
- added a focused shell contract that asserts:
  - `runner=prebuilt`
  - `rows=30`
  - `failed=9`
  - authoritative markdown-only log still reports `30 samples, 9 failures`

Result:

- current wrapper status is fixed
- current authoritative run:
  - wrapper summary: `.tmp/check/runs/pdf-20260613-202655-8571/summary.md`
  - authoritative log: `.tmp/check/runs/pdf-20260613-202655-8571/logs/markdown-only.entrypoint.log`

### 2. PDF v2 export/schema strengthening

Files:

- `convert/pdf_v2/pdf_v2_dataset_export.mbt`
- `convert/pdf_v2/tests/pdf_v2_dataset_export_test.mbt`
- `convert/pdf_v2/pkg.generated.mbti`

What changed:

- kept dataset export opt-in and out of product runtime
- added explicit `EvidenceRow` export family for parity/model-training prework
- preserved existing `TextFlowRow`, `BoundaryRow`, `ArtifactRow`, `AdjacencyRow`
- evidence rows now cover:
  - cross-page boundary evidence
  - image-text boundary evidence
  - header/footer variant evidence
  - heading-boundary evidence
  - column-layout evidence
- flat TSV/JSONL schema now includes explicit fields for:
  - `evidence_kind`
  - `subject_id`
  - `related_id`
  - `blockers`
- audit helper now counts:
  - `evidence_row_count`
  - image/heading/column/artifact evidence row sub-counts

Schema readiness status:

- deterministic row ids: yes
- deterministic JSONL: yes
- fixed TSV header: yes
- blank gold labels by default: yes
- weak labels clearly marked: yes
- `label_source` explicit: yes
- `reason_tags` exported: yes
- `blockers` exported: yes
- page index explicit: yes
- source refs exported: yes
- dataset export remains opt-in, not runtime path: yes

## Validation

All `moon` commands were run sequentially only.

Validation commands run:

1. `moon info && moon fmt`
2. `moon check`
3. `moon test convert/pdf_v2/tests`
4. `moon test doc_parse/pdf_v2/tests`
5. `moon test doc_parse/pdf_v2`
6. `moon test convert/pdf_v2`
7. `./samples/check.sh --format pdf`
8. `bash samples/helpers/contracts/check_samples_check_contract.sh`
9. `git diff --check`

Results:

- all commands passed
- `moon check` emitted existing vendor-package unused warnings only
- `samples/check.sh --format pdf` now reports:
  - `runner=prebuilt`
  - `rows=30`
  - `checked=30`
  - `failed=9`

## Final Sample Status

Final failing PDF markdown sample ids remain:

1. `assets/pdf_image_form_xobject`
2. `assets/pdf_image_inline`
3. `assets/pdf_image_xobject`
4. `pdf_cross_page_should_merge_phase15`
5. `pdf_cross_page_should_not_merge_phase15`
6. `pdf_header_footer_variants_phase15`
7. `pdf_heading_false_positive_phase15`
8. `pdf_heading_vs_short_sentence`
9. `pdf_two_column_negative_phase15`

Interpretation:

- no frozen semantic-rule-owned failures were patched
- no sample expected files were changed
- non-semantic cleanup in this pass was concentrated on runner/reporting correctness and training-readiness signal export

## Repo Status

Main repo changes:

- `convert/pdf_v2/pdf_v2_dataset_export.mbt`
- `convert/pdf_v2/pkg.generated.mbti`
- `convert/pdf_v2/tests/pdf_v2_dataset_export_test.mbt`
- `samples/check.sh`
- `samples/helpers/shared/validation_helpers.sh`
- `samples/helpers/contracts/check_samples_check_contract.sh`

Quality-lab status:

- not modified
- no quality-lab datasets or artifacts were generated or committed

## Next Step

Recommended next phase:

- model-training phase preparation can now consume stable exported evidence rows
- frozen semantic ownership failures should move to later semantic arbitration helper training
- `pdf_two_column_negative_phase15` should remain deferred until layout-recovery evidence or a dedicated layout helper model is available

## Explicit Confirmations

- no model training was performed
- no model runtime inference was added
- no fallback to PDF v1 was added
- no `moon` commands were run in parallel
