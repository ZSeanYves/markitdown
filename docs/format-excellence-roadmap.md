# Format Excellence Roadmap

## Second-Round Positioning

The first H1/H2/H3 baseline round is already complete. The project is now in a
second-round `H2++ / H3++` phase.

This round is not about:

* restarting H1 closure
* inflating the number of supported formats
* writing broad “done” claims without evidence

This round is about format-by-format excellence sprints:

* push each existing format toward market-parity or market-leading Markdown
  quality on the default local path
* make support range, conservative degradation, and non-goals explicit
* turn parser/core capability into a first-class deliverable rather than a
  converter-local patch pile
* attach every quality and performance claim to checked-in samples, metadata
  validation, quality comparison records, and benchmark results

## H2++ Completion Standard

A format reaches `H2++` only when all of the following exist:

* support range is explicit
* non-goals and conservative boundaries are explicit
* parser/core gaps are either resolved or registered as concrete TODOs
* regression samples cover main-path and complex boundary cases
* metadata/origin/assets behavior is validated where applicable
* quality comparison records exist against Microsoft MarkItDown or another
  comparable lightweight baseline
* the record set includes real `win`, `close`, `loss`, or
  `not_comparable` outcomes rather than one-sided marketing snapshots
* `docs/support-and-limits.md` is updated
* `README.mbt.md` does not overstate maturity

## H3++ Completion Standard

A format reaches `H3++` only when all of the following exist:

* native binary benchmark coverage
* `small / medium / large / batch` corpus coverage
* `metadata on/off` coverage
* `assets-heavy` coverage when the format can emit assets
* Microsoft MarkItDown or another mainstream overlap comparison where fair
* raw JSONL benchmark output
* summary TSV or Markdown output
* `runner_kind`, `execution_path`, and `not_comparable` status are recorded
* performance conclusions are limited to actually comparable corpora
* if performance is not leading, there is a bottleneck note and a next-step
  optimization plan

## Recommended Second-Round Order

1. XLSX
2. HTML
3. ZIP
4. EPUB
5. DOCX
6. PPTX
7. PDF
8. CSV / TSV
9. JSON
10. YAML
11. XML
12. Markdown
13. TXT

Why this order:

* XLSX / HTML / ZIP / EPUB can show the second-round model quickly: lower-layer
  capability, product quality, metadata behavior, and benchmark evidence all
  move together.
* DOCX / PPTX remain core OOXML formats but are broader and more expensive, so
  they are better after the first few sprints have hardened the workflow.
* PDF is still a deep-water format and is better handled after more of the
  project-wide evidence chain is in place.
* TXT / Markdown matter, but their second-round upside is mostly performance
  proof and boundary clarity rather than large semantic recovery gains.

## Single-Format Sprint Template

Every second-round format sprint should follow the same sequence:

1. Current capability audit
2. Market-parity gap list
3. Parser/core gap list
4. H2++ implementation
5. Regression samples
6. Metadata/origin/assets validation
7. Quality comparison records
8. H3++ benchmark corpus
9. Performance run
10. Bottleneck analysis
11. Support docs update
12. Validation
13. Commit

## Current Sprint

The first second-round excellence sprint is `XLSX`, and it is now treated as
`H2++ complete` plus `H3++ evidence-backed on the checked-in native overlap
corpus`.

Focus:

* formula cached-value policy and missing-cache degradation
* lightweight formula evaluation v1 for safe missing-cache cases
* merged-cell policy without misleading visual reconstruction
* typed-cell semantics
* visible / hidden / veryHidden sheet-state policy
* metadata/debug evidence for the above
* overlap quality comparison records
* overlap and batch-oriented benchmark evidence
* explicit non-goals: no full Excel engine, no cross-sheet/lookup/array/dynamic
  formula support in evaluator v1

The second second-round excellence sprint is `HTML`.

Current HTML sprint state:

* parser/resource safety boundaries have been hardened without moving toward a
  browser-grade engine
* unsafe-link fail-closed behavior, local-image asset behavior, table span
  hints, and HTML provenance are now backed by checked-in regression and
  metadata samples
* nested ZIP/EPUB HTML metadata snapshots now intentionally reflect lower-layer
  HTML provenance improvements
* checked-in HTML quality records and benchmark rows now exist, and the sprint
  is now treated as `HTML H2++ complete` plus `H3++ evidence-backed on the
  checked-in native overlap corpus`
* those conclusions remain intentionally scoped to the checked-in HTML quality
  records and native overlap/batch corpus; they are not browser-grade blanket
  web claims
