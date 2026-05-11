# PDF Layout Classifier Label Schema

This directory contains the local-only training spike assets for the
text-layer PDF layout classifier experiment.

Current labels:

* `BodyText`
* `Heading`
* `Noise`
* `PageNumber`
* `HeaderFooter`
* `Caption`
* `TableLike`
* `CrossPageMerge`
* `CrossPageNoMerge`
* `ColumnBoundary`
* `Unknown`

Notes:

* This is a training spike, not a production output policy.
* Not every label currently has enough samples for real training.
* Phase 1 focuses on `Heading`, `Noise` / `PageNumber` / `HeaderFooter`,
  `Caption`, and `BodyText`.
* `TableLike`, `CrossPageMerge`, `CrossPageNoMerge`, and `ColumnBoundary`
  currently act as export-ready placeholders with only small local coverage.
