# Format Support

## DOCX

Current capabilities include:

* heading recovery
* ordered / unordered / nested list recovery
* table parsing
* image export and Markdown references
* blockquote detection
* code-like paragraph recovery
* line-break handling in paragraphs and table cells
* hyperlink recovery in paragraph / heading / list contexts
* lightweight block-level origin metadata on document output
* lightweight image asset origin metadata on exported assets

Current boundaries:

* quote-like / code-like detection for multilingual or non-standard style names is still conservative
* some style generalization still depends mainly on heuristic naming rules

---

## PDF

The PDF mainflow on `main` is now:

**fully native structural recovery**

The normal PDF path has been fully replaced by the native recovery chain rather than an external text-first pipeline.

Current capabilities include:

* native character / span / line / block recovery
* text normalization and fragmented-English-word recovery
* page-noise cleanup
* repeated header/footer cleanup
* heading / short-sentence boundary recovery
* paragraph / block recovery
* basic bullet / list-item recovery
* cross-page paragraph merging
* hardwrap recovery
* conservative pseudo two-column negative protection
* lightweight page-level block origin metadata
* lightweight image asset origin metadata
* conservative nearby-caption attachment for images when a page has a single high-confidence caption-like text

Current boundaries:

* OCR is still not the default normal path
* OCR currently works as a plugin path driven by external tooling
* more complex multi-column, mixed graphic-text, and extreme extractor-level anomalies are still being improved
* some complex layouts still rely on heuristic rules rather than full layout-semantic reconstruction

---

## XLSX

Current capabilities include:

* multi-sheet output
* shared string / inline string / bool / error / number cell handling
* sparse table trimming
* sparse-edge bounding-box tightening
* built-in and custom datetime formatting
* table-width normalization
* lightweight sheet-level block origin metadata

Current boundaries:

* no formula evaluation
* merged cells are not yet upgraded into richer structural recovery targets

---

## PPTX

Current capabilities include:

* real slide-order recovery
* title / body separation
* bullet-property-first list recovery
* ordered / unordered / nested list recovery
* shape-aware reading order
* conservative two-column handling
* note-like / caption-like / callout-like grouping
* table-like / grid-like region detection and stabilization
* conservative page-number / corner-label noise filtering
* hyperlink recovery for run-level links and basic shape-level links
* conservative image caption-like attachment for single-image slides
* lightweight slide-level block origin metadata
* lightweight slide-level asset origin metadata

Current boundaries:

* negative cases may still be conservatively downgraded to ordered paragraphs
* table-like stabilization currently focuses more on region / order recovery than on full table-level IR semantics

---

## HTML

Current capabilities include:

* headings / paragraphs / list items
* ordered / unordered / nested lists
* block quotes
* pre / code blocks
* tables
* explicit `<br>` preservation
* lightweight inline model
* local structure recovery inside list-item containers
* local structure recovery inside blockquote containers
* hyperlink recovery for paragraph / heading / list-item / blockquote inline text
* lightweight document-level block origin metadata
* lightweight image/figure asset origin metadata
* image context retention for `<img alt>`, `<img title>`, `<figure>`, and `<figcaption>`

Current boundaries:

* the current model is still lightweight and DOM-like rather than browser-grade HTML semantics
* more complex containers and deeply nested cases are still handled conservatively
* table cell hyperlink currently stays on string-render path (not yet rich-inline IR)
* remote / unsupported image sources are still handled conservatively and are not force-exported
