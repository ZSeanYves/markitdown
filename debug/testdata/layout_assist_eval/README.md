# PDF Layout Assist Eval Testdata

This directory now keeps three manifest surfaces on purpose.

Files:

* `manifest.tsv`
  * compatibility alias for the historical mixed manifest
  * keeps existing debug/test consumers stable
* `manifest.legacy.mixed.tsv`
  * legacy mixed surface
  * contains both block-assist rows and boundary-assist rows
  * do not add new samples here unless the goal is explicit backward
    compatibility coverage
* `block_assist_manifest.tsv`
  * `Task A` debug eval surface
  * only block-semantic rows for convert-layer assist behavior
  * examples: heading, caption, footer/header noise, paragraph-like negatives
* `boundary_assist_manifest.tsv`
  * `Task B` debug eval surface
  * only parser/layout boundary rows
  * examples: cross-page merge / no-merge samples

Boundary note:

* `block_assist_manifest.tsv` belongs to text block semantics
* `boundary_assist_manifest.tsv` belongs to parser/layout boundary recovery
* new tests and new samples should prefer one of the split manifests instead of
  extending the legacy mixed manifest
