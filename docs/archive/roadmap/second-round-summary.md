# Second-Round Summary

This document summarizes the repository's second-round `H2++ / H3++` closure
state.

The repository now sits on top of that sealed baseline with a unified public
validation surface and a checked-in complex-only `samples/real_world` corpus.

It is the concise project-level companion to:

* [CHANGELOG.md](../../CHANGELOG.md)
* [docs/support-and-limits.md](../../support-and-limits.md)
* [docs/archive/benchmark/benchmark-governance.md](../benchmark/benchmark-governance.md)
* [docs/archive/performance/validation-and-benchmark-summary.md](../performance/validation-and-benchmark-summary.md)
* [docs/quality-comparisons/README.md](../../quality-comparisons/README.md)
* [docs/archive/audits/second-round-hardening-audit.md](../audits/second-round-hardening-audit.md)

## Goal

The second round focused on moving core formats from basic main-path
availability to:

* explicit support boundaries
* checked-in regression coverage
* metadata/assets validation
* checked-in quality comparison records
* checked-in benchmark evidence

This was a format-by-format evidence program, not a blanket support inflation
pass.

## Sealed Formats

| Format | Current status | H2++ quality evidence | H3++ performance evidence |
| --- | --- | --- | --- |
| XLSX | H2++ complete | checked-in native overlap quality records | checked-in native overlap corpus |
| HTML | H2++ complete | checked-in native overlap quality records | checked-in native overlap corpus |
| ZIP | H2++ complete | checked-in native corpus quality records | checked-in native corpus |
| EPUB | H2++ complete | checked-in native EPUB quality records | checked-in native EPUB corpus |
| DOCX | H2++ complete | checked-in native overlap quality records | checked-in native overlap corpus |
| PPTX | H2++ complete | checked-in native overlap quality records | checked-in native overlap corpus |
| PDF | H2++ complete for native text-PDF scope | checked-in native text-PDF quality records | checked-in native text-PDF corpus |

## Remaining Non-sealed Families

| Format family | Current status | Current contract |
| --- | --- | --- |
| CSV / TSV | H2 main-path quality | stable table lowering and checked-in regression, but not a second-round sealed corpus story |
| JSON | H2 main-path quality | conservative structured-data lowering and checked-in regression |
| YAML / YML | subset-H2 | conservative supported subset only |
| XML | source-preserving H1/H2 partial | safe fenced-source preservation, not semantic XML-family conversion |
| Markdown | H2 main-path quality | passthrough contract |
| TXT | H2 main-path quality | literal-safe text contract |

## Quality Evidence Rules

Second-round quality conclusions are admitted only when:

* the sample is checked in
* the comparison scope is explicitly named
* verdict is one of `win`, `close`, `loss`, or `not_comparable`
* `not_comparable` is not counted as a win
* non-goals are kept outside the verdict claim

Quality records live in
[docs/quality-comparisons/README.md](./quality-comparisons/README.md).

## Performance Evidence Rules

Second-round H3++ conclusions are admitted only when:

* the runner is a prebuilt native binary
* the execution path is explicit
* the corpus is checked in and named
* compare rows are overlap-only and fair
* OCR, cloud, plugin, and fallback paths are not mixed into the default local
  speed story

Performance governance lives in
[docs/archive/benchmark/benchmark-governance.md](../benchmark/benchmark-governance.md).

## Validation Surface

The repository's checked-in validation chains are:

* `samples/check.sh`
* `samples/check.sh --markdown-only`
* `samples/check.sh --metadata-only`
* `samples/check.sh --assets-only`
* `samples/check.sh --contracts-only`
* `samples/check.sh --manifest-only`

The checked-in benchmark chains are:

* `samples/bench.sh --suite smoke --kind smoke`
* `samples/bench.sh --suite compare`
* `samples/bench.sh --suite batch-profile`

Detailed validation counts, current run totals, and representative benchmark
examples live in
[docs/archive/performance/validation-and-benchmark-summary.md](../performance/validation-and-benchmark-summary.md).

The checked-in `samples/real_world` corpus now provides richer
complex-scenario coverage across the core formats. It complements the smaller
feature-focused `main_process` regressions, and it now keeps only the
long-form complex layer. It still does not change the sealed H2++ / H3++
evidence basis and is not counted as benchmark evidence by default.

## Current Boundaries

Across sealed formats, the repository stays intentionally conservative:

* no Word, PowerPoint, or PDF layout engine claims
* no browser-grade HTML claims
* no recursive ZIP archive conversion
* no EPUB DRM/CSS/JS/reading-system claims
* no OCR-default PDF claim
* no globally aggressive text rewriting policy across literal or structured
  paths
* no benchmark claim beyond the checked-in corpora

## Recent Engineering Hardening

Recent substrate hardening after second-round seal:

* shared text normalization now lives in a profile-driven, rule-driven
  substrate rather than scattered PDF-only character fixes
* the native PDF path uses `PdfText` for output cleanup and `PdfCompareText`
  for comparison/heuristic normalization
* normalization is staged and explainable:
  line-ending, compatibility, whitespace, invisible-char, soft-hyphen, PDF
  glyph fallback, and compare-cleanup stages all flow through one shared entry
  point with explicit rule ids/scopes and debug summaries
* output-safe pure-string cleanup such as CJK spacing, punctuation spacing,
  and marker spacing now flows through shared policy instead of ad hoc PDF
  post-text replacement chains
* canonical `NFC` / `NFKC` are explicit non-default policy hooks, but the
  repository does not claim full ICU/UAX #15 support on the current MoonBit
  stdlib path
* literal-safe paths remain conservative and do not inherit aggressive
  normalization by default

## Post-seal Engineering Hardening

These follow-up changes happened after the second-round closure itself. They
do not rewrite the historical second-round story, but they do affect the
current implementation state:

* the native PDF path no longer relies on known-phrase replacement, known
  split-word lists, global `replace_all("- ", "")`, or global slash cleanup as
  its default text-quality mechanism
* PDF output-safe cleanup now runs through the shared rule pipeline, while
  span/line/layout-aware repair stays in PDF-local layers
* PDF no-context glue fallback has been tightened so normal short-word
  boundaries such as `the + first` and `to + flow` do not merge by guesswork
* wrapped-prefix continuation and ligature-fragment repair now depend on PDF
  context signals rather than word lists
* recent whitepaper regression fixes were absorbed without reopening sealed
  scope language or widening benchmark claims

Recent engineering hardening after normalization v2:

* CLI debug inspect is now a unified multi-format report path instead of a
  PDF-only developer entrypoint
* `debug <input>` works across dispatcher-supported formats and reports format,
  structure, assets, metadata availability, and selected format-specific stats
* `debug --json` provides a stable script-facing output contract
* PDF debug inspect additionally exposes structured `pdf_backend`,
  `pdf_pages`, `pdf_text_model`, `pdf_images`, `pdf_annotations`, `pdf_links`,
  `pdf_pipeline`, and aggregated `PdfText` / `PdfCompareText`
  normalization summary
* legacy `debug <all|extract|raw|pipeline> ...` is now a deprecated alias over
  the unified PDF inspect path rather than a separately maintained report path
* debug inspect does not change normal or batch conversion semantics and does
  not write sidecars by default

## Future Work

Second-round closure does not eliminate future work. It narrows it.

Typical future expansion themes now include:

* richer provenance fields where current sidecars are coarse
* stronger metadata-on benchmark coverage for non-sealed text/structured
  families
* optional OCR/scanned-PDF work outside the default PDF scope
* optional richer table/layout models where current formats are intentionally
  conservative
* optional memory/RSS baselines where platform support is stable
