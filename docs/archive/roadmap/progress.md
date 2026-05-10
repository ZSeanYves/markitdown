# Progress Summary

Status: historical snapshot retained for traceability.

Current source of truth for project state now lives in:

* [README](../../README.md)
* [docs/support-and-limits.md](../../support-and-limits.md)
* [docs/archive/performance/validation-and-benchmark-summary.md](../performance/validation-and-benchmark-summary.md)
* [docs/archive/roadmap/second-round-summary.md](./second-round-summary.md)

This document summarizes the repository's current project state.

For detailed per-format behavior, use
[docs/support-and-limits.md](../../support-and-limits.md).

For the current document map and primary current-state entrypoints, use
[docs/README.md](../../README.md).

For checked validation counts and benchmark examples, use
[docs/archive/performance/validation-and-benchmark-summary.md](../performance/validation-and-benchmark-summary.md).

## Snapshot

The repository is in a stable post-second-round state:

* the main multi-format product path is consolidated around a native-preferred
  CLI, unified IR, Markdown emitter, metadata sidecar, and asset export
* repository-level CLI and batch contracts are explicitly validated
* benchmark and quality conclusions are checked-in-corpus scoped
* sealed formats now carry explicit H2++ / H3++ status language
* non-sealed text and structured-data formats retain conservative, narrower
  support claims

## Sealed Formats

The following formats are currently sealed for second-round quality/performance
status within their documented scope:

* XLSX: `H2++ complete`, `H3++ evidence-backed on checked-in native overlap corpus`
* HTML: `H2++ complete`, `H3++ evidence-backed on checked-in native overlap corpus`
* ZIP: `H2++ complete`, `H3++ evidence-backed on checked-in native corpus`
* EPUB: `H2++ complete`, `H3++ evidence-backed on checked-in native EPUB corpus`
* DOCX: `H2++ complete`, `H3++ evidence-backed on checked-in native overlap corpus`
* PPTX: `H2++ complete`, `H3++ evidence-backed on checked-in native overlap corpus`
* PDF: `H2++ complete for native text-PDF scope`, `H3++ evidence-backed on checked-in native text-PDF corpus`

These are evidence-scoped claims, not universal format-completeness claims.

## Validation Surface

The repository's default validation bar is:

```bash
moon build --target native
moon check
moon test
./samples/check.sh
```

Supporting validation chains:

* `./samples/check.sh --markdown-only`
* `./samples/check.sh --metadata-only`
* `./samples/check.sh --assets-only`
* `./samples/check.sh --contracts-only`
* `./samples/check.sh --manifest-only`

## Benchmark Surface

The benchmark surface is organized around:

* smoke: checked-in local corpus
* overlap comparison: sample-scoped comparison against Microsoft MarkItDown
* batch profile: repeated `normal` vs `batch`

Default performance conclusions should be read only from:

* prebuilt native runner
* checked-in named corpus
* explicit execution path

`moon run` remains a supported fallback, but not the preferred H3++ proof
point.

## Current Priorities

The current repository focus is project hygiene and reproducibility:

* keep documentation and status language consistent
* keep scripts and benchmark outputs reviewable
* keep sample families clearly separated by responsibility
* keep future work explicit without reopening sealed format claims

## Current Shared Text Cleanup Rollout

Current rollout status:

* shared document cleanup is already reused by PDF, TXT, HTML, DOCX, and PPTX
* explicit canonical `NFD/NFC/NFKD/NFKC` facade APIs are available
* default converter behavior still does not enable canonical normalization
* full `NormalizationTest.txt` conformance is still pending

For the detailed rollout boundary, use
[docs/archive/normalization/text-normalization-migration-plan.md](../normalization/text-normalization-migration-plan.md)
and
[docs/text-normalization-conformance.md](./text-normalization-conformance.md).
