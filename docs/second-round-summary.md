# Second-Round Summary

This document summarizes the repository's second-round `H2++ / H3++` closure
state.

It is the concise project-level companion to:

* [docs/support-and-limits.md](./support-and-limits.md)
* [docs/benchmark-governance.md](./benchmark-governance.md)
* [docs/quality-comparisons/README.md](./quality-comparisons/README.md)
* [docs/second-round-hardening-audit.md](./second-round-hardening-audit.md)

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
[docs/benchmark-governance.md](./benchmark-governance.md).

## Validation Surface

The repository's checked-in validation chains are:

* `samples/check.sh`
* `samples/check_main_process.sh`
* `samples/check_metadata.sh`
* `samples/check_assets.sh`
* `samples/scripts/check_cli_contract.sh`
* `samples/scripts/check_batch_contract.sh`
* `samples/scripts/check_corpus_manifest.sh`

The checked-in benchmark chains are:

* `samples/scripts/bench_smoke.sh --kind smoke`
* `samples/scripts/bench_compare_markitdown.sh`
* `samples/scripts/bench_batch_profile.sh`

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

Recent substrate hardening after second-round seal:

* shared text normalization now lives in a profile-driven Text Normalization v2
  substrate rather than scattered PDF-only character fixes
* the native PDF path uses `PdfText` for output cleanup and `PdfCompareText`
  for comparison/heuristic normalization
* normalization is now staged and explainable:
  line-ending, compatibility, whitespace, invisible-char, soft-hyphen, PDF
  glyph fallback, and compare-cleanup stages all flow through one shared entry
  point
* canonical `NFC` / `NFKC` are explicit non-default policy hooks, but the
  repository does not claim full ICU/UAX #15 support on the current MoonBit
  stdlib path
* literal-safe paths remain conservative and do not inherit aggressive
  normalization by default

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
