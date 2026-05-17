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

Recommended next-step labels for new manual rows:

Block labels:

* `paragraph`
* `heading`
* `table_like`
* `form_row`
* `list_item`
* `caption`
* `footer_header_noise`
* `separator`
* `link_text`
* `keep_as_text`

Boundary labels:

* `cross_page_merge`
* `cross_page_keep_split`
* `column_boundary`
* `paragraph_continuation`

Legacy mapping guide:

* `BodyText` -> `paragraph` or `keep_as_text`
* `Heading` -> `heading`
* `Noise` / `HeaderFooter` / `PageNumber` -> `footer_header_noise` or `separator`
* `Caption` -> `caption`
* `TableLike` -> `table_like`
* `CrossPageMerge` -> `cross_page_merge`
* `CrossPageNoMerge` -> `cross_page_keep_split`

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
* The first local-only external-corpus ablation currently learns only
  `caption`, `footer_header_noise`, `form_row`, `heading`, `keep_as_text`,
  `paragraph`, `separator`, and `table_like`.
* The current best report-only expanded held-out run now uses the round-15
  paragraph-boundary feature pass on the harder `223 / 195` split, keeps
  `link_text` and `caption` stable, improves receipt/form-row and
  figure-reference paragraph boundaries, and still keeps
  normal-path activation off.
* A later real-support expansion pushed held-out support to `link_text = 9`
  and `caption = 8` on a harder `195`-row held-out slice while keeping
  regressions at `0`.
* A later residual feature pass then improved the same harder split again
  without adding labels first, but `Summary`, a visible-URL boundary row, and
  a receipt/body boundary row still remain.
* Before any future gated-normal trial, add more unique-source real labels for
  `link_text`, `caption`, short-title `heading` boundaries, and
  receipt/footer-style literal-text negatives.
