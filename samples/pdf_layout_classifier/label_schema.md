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
* The current held-out pass mainly exercises `Heading`, `BodyText`, `Caption`,
  `TableLike`, `CrossPageMerge`, `CrossPageNoMerge`, and `Unknown`.
* `Noise`, `PageNumber`, `HeaderFooter`, and `ColumnBoundary` remain
  export-ready labels, but the current local corpus does not yet provide
  enough reliable labeled rows to treat them as evaluated.
* Held-out results from this directory are small-sample checks only and should
  not be written up as generalized model quality claims.
