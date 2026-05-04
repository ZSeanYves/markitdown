# Full-format H2 Completion

This document records the repository-wide H2 completion cleanup after every
primary format reached an H2-complete support contract.

It is the compact milestone summary for:

* final H2 status
* format-level highlights
* known limitations that remain explicit
* validation and benchmark tool status
* documentation and test-structure cleanup outcomes

## H2 completion summary

The repository now treats the following primary formats as **H2 complete**:

* TXT
* Markdown
* CSV / TSV
* JSON
* YAML / YML
* XML
* HTML / HTM
* XLSX
* ZIP
* EPUB
* DOCX
* PPTX
* PDF

This means:

* the format is usable as a stable product contract
* checked-in regression coverage exists for the main supported behavior
* support/limits wording is explicit
* remaining harder cases are documented limitations, not hidden blockers

It does **not** mean every advanced format-specific feature is implemented or
that the repository has become a pixel-faithful layout engine.

## Format status table

| Format | Status | H2 highlights | Known limitations |
| --- | --- | --- | --- |
| TXT | H2 complete | literal-safe paragraph conversion, metadata/origin | no semantic Markdown inference, UTF-8-only conservative policy |
| Markdown | H2 complete | source-preserving passthrough, metadata | not a full Markdown AST normalizer |
| CSV / TSV | H2 complete | stable table conversion, `RichTable` metadata | H3 streaming/memory work remains |
| JSON | H2 complete | conservative structured-data conversion | H3 large-nesting/streaming work remains |
| YAML / YML | H2 complete | supported-subset, fail-closed policy | not a full YAML feature-complete engine |
| XML | H2 complete | safe tokenizer base, source-preserving fenced output | not a semantic XML-family renderer |
| HTML / HTM | H2 complete | text/tables/links/images, `RichTable` metadata | no CSS/JS execution, no rowspan/colspan reconstruction |
| XLSX | H2 complete | workbook/sheet/cell lower layer, metadata, datetime handling | no charts/comments/pivots, no merged-cell visual reconstruction |
| ZIP | H2 complete | safe-entry conversion, inspect surface, nested asset remap | no recursive nested archive conversion, deeper ZIP64/data-descriptor work deferred |
| EPUB | H2 complete | OPF/spine/nav/cover/assets pipeline, metadata | richer NCX/internal-anchor semantics deferred |
| DOCX | H2 complete | lists/tables/notes/comments/headers/footers/textboxes, metadata | no full tracked-change UI, no full run-style fidelity, no complex visual table reconstruction |
| PPTX | H2 complete | grouped shapes, explicit tables, speaker notes, hidden slides | no charts/SmartArt/OLE/action links/animations, no full merged-table visual reconstruction |
| PDF | H2 complete | text structure, edge-noise cleanup, URI links, simple tables, captions | no complex table engine, no outlines/internal Dest emission, no OCR-default or positive multi-column recovery |

## Per-format H2 highlights

### Shared cross-format outcome

Across the repository, H2 completion now includes:

* dispatcher-based stable mainflow coverage
* Markdown emitter and metadata sidecar integration
* assets regression where formats materially emit images
* support/limits wording that distinguishes supported behavior from
  limitations/non-goals

### Office formats

* DOCX now covers deeper content slices such as notes/comments,
  headers/footers, and text boxes with conservative append-section policies.
* PPTX now covers grouped text/image/table recovery, explicit table XML,
  hidden slides, and speaker notes.
* XLSX now exposes a reusable lower layer and explicit `RichTable` metadata
  semantics.

### Container / ebook formats

* ZIP and EPUB both have stable H2 support contracts and isolated temp-dir
  handling for repeated validation runs.

### PDF

* PDF now crosses the H2 bar with conservative tables, conservative image
  captions, and late page-number scoping that preserves numeric table cells
  without weakening edge-noise cleanup.

## Known limitations by format

The detailed support contract remains in
[docs/support-and-limits.md](./support-and-limits.md). The important H2
milestone rule is:

* limitations remain explicit
* limitations are **not** hidden as if the format were fully solved

Examples:

* PDF still does not claim complex table reconstruction, positive multi-column
  reading-order recovery, outlines/internal-destination emission, tagged PDF
  semantics, or OCR-default behavior.
* PPTX still does not claim chart / SmartArt / OLE / animation semantics.
* DOCX still does not claim full tracked-changes UI or full visual table
  reconstruction.

## Test / validation matrix

H2-complete status is backed by the repository validation chain:

```bash
moon fmt
moon info
moon check
moon test
./samples/scripts/check_samples.sh
./samples/diff.sh
./samples/check_metadata.sh
./samples/check_assets.sh
```

Format-specific `test/` subpackages are used for blackbox/package tests where
package APIs are the right seam.

MoonBit whitebox tests remain a separate mechanism:

* `*_wbtest.mbt` files live in the package directory
* they are still appropriate when a test must exercise package-internal helper
  logic that is intentionally not part of the package's public contract

That distinction is deliberate and remains part of the repository's testing
discipline.

## Test architecture cleanup summary

The repository now treats test placement as a semantic choice rather than a
directory-uniformity exercise.

### Black-box / package tests

`test/` subpackages are the default home for:

* public/package API tests
* fixture-driven converter behavior tests
* parser package tests that should import the parent package through its normal
  package seam

Current examples include:

* `convert/*/test`
* `convert/convert/test`
* `doc_parse/pdf/api/test`
* `doc_parse/pdf/test`
* `doc_parse/epub/test`
* `doc_parse/zip/tests`

### White-box helper tests

Root-level `*_wbtest.mbt` files remain correct when they test package-private
helpers or internal decision surfaces. They were intentionally **not**
mechanically moved into `test/` subpackages, because doing so would require
widening APIs that are not meant to be public.

Current examples include:

* PDF heading / noise / merge / link-match / table-caption helper tests
* PPTX group-tree / notes / explicit-table helper tests
* DOCX hyperlink / notes / header-footer / textbox helper tests
* ZIP safe-path / asset-namespace helper tests

### Coverage outcome

By the end of the H2 milestone, the repository has all three layers working
together:

* black-box package tests for externally visible behavior
* white-box helper tests for high-risk internal heuristics
* integration/sample chains for mainflow, metadata, and assets

One concrete post-H2 cleanup improvement was adding explicit black-box PDF
caption coverage in `convert/pdf/test`, so conservative caption behavior is no
longer only guarded by white-box helper tests and metadata-chain assertions.

Another post-H2 cleanup was validation UX normalization:

* sample validation now has one shared runner-resolution path; it prefers a
  probe-validated native CLI, falls back to `moon run` when the discovered
  binary is stale, and still allows
  `MARKITDOWN_CLI=/abs/path/to/cli` for explicit native pinning
* `diff.sh`, `check_metadata.sh`, and `check_assets.sh` now share one compact
  progress/failure-summary style instead of per-sample convert/diff spam
* sample integrity, main Markdown, metadata, and assets remain separate script
  responsibilities rather than one noisy all-in-one shell path

Another repository-hygiene cleanup after H2 completion was normalizing the PDF
backend dependency story:

* the native PDF lower layer remains `doc_parse/pdf`
* the backend implementation is a repository-local maintained fork under
  `vendor/mbtpdf`
* the root module no longer relies on a path-only external
  `bobzhang/mbtpdf` dependency in `moon.mod.json`

## Benchmark / profiling status

The benchmark toolchain is now a stable next-stage H3 foundation:

* smoke benchmark
* overlap-only comparison benchmark
* batch profiling harness
* manual regression-warning tooling

Selected overlap cases already show same-machine speed wins for the native
runner, but these remain selected-case observations rather than blanket claims.

## Documentation cleanup summary

The repository now prefers a smaller stable document set for current product
status:

* `README.mbt.md`
* `docs/support-and-limits.md`
* `docs/progress.md`
* `docs/development.md`
* `docs/full-format-hardening-milestone.md`
* benchmark docs

Most per-format process/readiness notes have now been folded into the stable
documentation set above, and the redundant transition-era docs were removed.
The stable support contract should now be read primarily from those documents
rather than from older implementation-pass notes.

## Next stage

The next stage after full-format H2 completion is no longer "make one more
format usable". It is:

* H3 benchmark discipline
* larger corpus profiling
* memory profiling
* release/documentation polish
* selective H2.1 quality upgrades where product value is clear
