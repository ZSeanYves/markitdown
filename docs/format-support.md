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

Current boundaries:

* quote-like / code-like detection for multilingual or non-standard style names is still conservative
* some style generalization still depends mainly on heuristic naming rules

---

## PDF

The current PDF pipeline on `main` is still:

**external text-first**

Current capabilities include:

* multi-backend text extraction and selection
* page-noise cleanup
* repeated header/footer cleanup
* heading / short-sentence boundary recovery
* paragraph / block recovery
* basic list-item recovery
* cross-page paragraph merging
* hardwrap recovery
* conservative handling of pseudo two-column negative cases

Current boundaries:

* the main path is still text-first rather than an event/line/block-native structure-recovery chain
* OCR is not the default normal path
* more complex layouts still depend mainly on heuristic post-processing

---

## XLSX

Current capabilities include:

* multi-sheet output
* shared string / inline string / bool / error / number cell handling
* sparse table trimming
* sparse-edge bounding-box tightening
* built-in and custom datetime formatting
* table-width normalization

Current boundaries:

* no formula evaluation
* merged cells are not yet treated as richer structural recovery targets

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

Current boundaries:

* negative cases are still conservatively downgraded to ordered paragraphs
* table-like stabilization currently focuses more on region/order recovery than full table-level IR semantics

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

Current boundaries:

* still a lightweight DOM-like model rather than a browser-grade full HTML semantic model
* more complex containers and deeply nested cases are still handled conservatively
