# Format Excellence Roadmap

This document defines the repository's second-round format hardening model.

It is not a sprint log. It records:

* what `H2++` means
* what `H3++` means
* which formats are sealed
* how future format work should be scoped

## Second-Round Positioning

The project has already completed its first broad format-availability round.

Second-round work is about:

* explicit support boundaries
* regression coverage for important structures and failure boundaries
* metadata and asset validation where applicable
* checked-in quality records
* checked-in benchmark evidence

Second-round work is not about:

* inflating support claims without evidence
* treating every partial parser path as market-complete support
* turning lightweight converters into layout engines

## H2++ Completion Standard

A format reaches `H2++ complete` only when all of the following are true:

* support scope is explicit
* non-goals and degradation boundaries are explicit
* regression samples cover both main-path and important boundary cases
* metadata and assets behavior are validated where applicable
* checked-in quality comparison records exist
* README and support docs do not overstate maturity

## H3++ Completion Standard

A format reaches `H3++ evidence-backed` only when all of the following are
true:

* the benchmark runner is a prebuilt native binary
* the corpus is checked in and named
* compare rows are overlap-only and fair
* metadata-on coverage exists where relevant
* batch behavior is measured where product-path batch exists
* conclusions stay within the named corpus scope

## Current Sealed Formats

| Format | Current second-round status |
| --- | --- |
| XLSX | H2++ complete / H3++ evidence-backed on checked-in native overlap corpus |
| HTML | H2++ complete / H3++ evidence-backed on checked-in native overlap corpus |
| ZIP | H2++ complete / H3++ evidence-backed on checked-in native corpus |
| EPUB | H2++ complete / H3++ evidence-backed on checked-in native EPUB corpus |
| DOCX | H2++ complete / H3++ evidence-backed on checked-in native overlap corpus |
| PPTX | H2++ complete / H3++ evidence-backed on checked-in native overlap corpus |
| PDF | H2++ complete for native text-PDF scope / H3++ evidence-backed on checked-in native text-PDF corpus |

## Current Non-sealed Families

The following families remain intentionally narrower in current scope:

* CSV / TSV
* JSON
* YAML / YML
* XML
* Markdown
* TXT

Their current support level should be read from
[docs/support-and-limits.md](./support-and-limits.md), not inferred from the
sealed-format table above.

## Future Work Guidance

Future format work should prefer:

1. audit
2. boundary definition
3. regression and metadata evidence
4. quality records
5. benchmark evidence
6. support-doc closure

Future format work should avoid:

* large converter rewrites without evidence gaps
* benchmark claims before corpus/comparability discipline
* broad parity language without checked-in support

## Related Documents

* [docs/second-round-summary.md](./second-round-summary.md)
* [docs/support-and-limits.md](./support-and-limits.md)
* [docs/benchmark-governance.md](./benchmark-governance.md)
* [docs/quality-comparisons/README.md](./quality-comparisons/README.md)
* [docs/second-round-hardening-audit.md](./second-round-hardening-audit.md)
