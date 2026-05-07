# Text Normalization Conformance Plan

This document records the conformance-validation plan for the explicit
canonical normalization facade in
[`core/text_normalization.mbt`](/Users/winter/Documents/Moonbit/markitdown/core/text_normalization.mbt:1).

It is intentionally a planning document, not a claim that full Unicode
normalization conformance is already complete.

## Current Status

Current repository status:

* `tonyfettes/unicode` is wired behind the project facade
* explicit APIs exist for:
  * `normalize_nfd`
  * `normalize_nfc`
  * `normalize_nfkd`
  * `normalize_nfkc`
  * `is_normalized_nfd`
  * `is_normalized_nfc`
  * `is_normalized_nfkd`
  * `is_normalized_nfkc`
* shared document-text cleanup is already reused by PDF, TXT, HTML, and DOCX
* default converter behavior still does not enable canonical normalization
* canonical normalization remains separate from shared document cleanup
* full standards-conformance validation is still pending

Current smoke coverage already includes:

* composed/decomposed accent cases such as `é` and `e + combining acute`
* compatibility ligature case such as `ﬃ -> ffi` under `NFKC`
* fullwidth compatibility case such as `Ａ -> A` under `NFKC`
* `is_normalized_*` positive and negative checks for basic examples

These tests are useful, but they are not full conformance evidence.

## Why Current Coverage Is Not Enough

The existing unit tests prove that the facade is connected and that several
important examples behave correctly. They do not yet prove:

* broad canonical composition/decomposition correctness
* combining-mark canonical ordering behavior across multiple marks
* Hangul algorithmic composition/decomposition coverage
* behavior across a fixed Unicode data version
* standards-level agreement with the Unicode normalization conformance corpus

So the project should continue describing current support as:

* explicit canonical normalization facade available
* promising backend in place
* conformance still pending

It should not yet claim full Unicode normalization standards conformance.

## Reference Corpus

The intended full conformance reference is Unicode
`NormalizationTest.txt`.

Planned controls for that future step:

* fix the Unicode version used by the project
* record the exact source location and revision of the conformance file
* keep the project-side runner reproducible
* separate always-on unit coverage from opt-in larger conformance coverage

This avoids mixing fast day-to-day regression tests with a heavier standards
validation path.

## Three-Layer Test Strategy

### A. Smoke Tests

Purpose:

* prove the facade is wired
* catch obvious regressions quickly
* stay in normal `moon test`

Scope:

* a few representative canonical and compatibility examples
* `is_normalized_*` positive and negative checks
* explicit proof that default cleanup APIs do not implicitly enable canonical
  normalization

Current status:

* already present in `core/test/text_normalization_test.mbt`

### B. Curated Tests

Purpose:

* expand coverage with a small hand-picked set of high-value cases
* still remain fast enough for normal `moon test`

Recommended case families:

* canonical composition/decomposition
* compatibility ligatures
* fullwidth compatibility
* Hangul normalization
* combining-mark ordering
* `is_normalized_*` positive and negative cases

Recommended size:

* dozens of cases at most
* no downloaded corpus
* no large checked-in fixture file

Current P7 scope:

* small curated additions are acceptable if they remain lightweight

### C. Full Conformance

Purpose:

* validate against the official Unicode normalization conformance corpus

Recommended source:

* `NormalizationTest.txt`

Recommended execution model:

* opt-in script or explicit validation entry
* not required for every default `moon test` run

Why keep it opt-in:

* fixture size may be larger than normal unit tests should carry
* runtime may be higher than normal edit-compile-test loops should assume
* version pinning and update process need explicit governance

## Proposed Future Inputs

When the project is ready for broader curated coverage, prioritize:

1. canonical accent composition/decomposition cases
2. multiple combining-mark reordering cases
3. Hangul decomposition/composition cases
4. compatibility decomposition cases for ligatures and fullwidth forms
5. `is_normalized_*` truth-table style checks around those same examples

When the project is ready for full conformance, define:

1. Unicode version pin
2. exact fixture source
3. local runner entrypoint
4. expected CI policy
5. update process when Unicode version changes

## Current Recommendation

Recommended next step after P10:

* keep smoke tests in normal `moon test`
* add only a very small curated layer in-tree
* defer full `NormalizationTest.txt` integration to a separate opt-in
  validation task

This keeps the project honest about standards claims while still improving
confidence in the explicit canonical normalization facade.
