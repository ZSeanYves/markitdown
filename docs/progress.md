# Progress Summary

This document is a current-state summary, not a full chronological log.

For detailed format behavior, use
[docs/support-and-limits.md](./support-and-limits.md).

For second-round support/benchmark/parser-gap planning, use
[docs/second-round-hardening-audit.md](./second-round-hardening-audit.md).

For the current benchmark corpus/runner/comparability contract, use
[docs/benchmark-governance.md](./benchmark-governance.md).

For checked-in Markdown quality comparison records, use
[docs/quality-comparisons/README.md](./quality-comparisons/README.md).

## Current State

The repository is currently in a stable post-initial-H2, post-H3-phase-1
state:

* dispatcher coverage spans all primary format families, but maturity is split
  across `H2 main-path quality`, `subset-H2`, `source-preserving H1/H2 partial`,
  and second-round sealed `H2++ / H3++` formats
* documented limitations remain explicit rather than hidden behind milestone
  labels
* unified IR / Markdown emitter / metadata sidecar are stable repository
  contracts
* sample validation is organized around integrity, main output, metadata
  sidecars, and assets
* `./samples/check_metadata.sh` now explicitly exercises `--with-metadata` and
  validates the core sidecar contract
* repository-level CLI contract checks now explicitly verify that metadata
  sidecars are opt-in, stdout is side-effect-free, and batch/no-batch metadata
  behavior stays aligned with the documented product contract
* benchmark harnesses for smoke, overlap comparison, batch profiling, and
  warnings are in place
* benchmark governance now distinguishes runner class, execution path,
  overlap-only comparison, and not-comparable cases more explicitly
* the first checked-in quality comparison seed records now exist for selected
  DOCX / PPTX / XLSX / HTML / CSV / Markdown / TXT / PDF overlap samples
* the first second-round format excellence sprint is now sealed at
  `XLSX H2++ complete`, with `H3++` performance evidence backed on the
  checked-in native overlap corpus
* XLSX formula/merged/type/sheet-state policy is now backed by additional
  samples, sidecar hints, lightweight formula-evaluation-v1 coverage, and
  checked-in metadata policy fixtures
* the current second-round HTML sprint now has green validation after HTML
  provenance/object-ref/key-path enhancements and the corresponding HTML +
  ZIP/EPUB nested HTML metadata snapshot refresh
* checked-in HTML quality comparison coverage now includes base structure,
  ragged-row tables, local figure/image asset behavior, semantic containers,
  and unsafe-link fail-closed boundaries
* checked-in HTML benchmark coverage now includes `small`, `medium`, `large`,
  `table-heavy`, `link-heavy`, `asset-heavy local`, `malformed/common`, and
  metadata-on rows on the native-preferred path
* HTML is now treated as `H2++ complete`, with `H3++` evidence backed on the
  checked-in native overlap corpus
* ZIP now has checked-in second-round regression/metadata/quality evidence for
  mixed supported entries, unsupported-entry warnings, nested-archive
  boundaries, hidden-entry policy, and archive asset remap
* ZIP native benchmark coverage now includes small, medium, large/many-entry,
  mixed-supported, assets-heavy, unsupported/degrade, metadata-on, and batch
  profile rows
* ZIP is now treated as `H2++ complete`, with `H3++` evidence backed on the
  checked-in native ZIP corpus rather than an external overlap benchmark story
* EPUB now has checked-in second-round regression/metadata/quality evidence
  for OPF package metadata, spine ordering, EPUB3 nav, NCX fallback, cover
  assets, duplicate asset-name remap, and warning/degrade behavior
* EPUB native benchmark coverage now includes small, medium, chapter-heavy,
  asset-heavy, metadata-on, unsupported/degrade, and NCX rows, with local
  overlap compare rows against Microsoft MarkItDown on meaningful samples
* EPUB is now treated as `H2++ complete`, with `H3++` evidence backed on the
  checked-in native EPUB corpus
* DOCX now has checked-in second-round regression/metadata/quality evidence
  for nested/style-linked lists, hyperlink spacing and multi-run links,
  multiline/merged-boundary tables, notes/comments ordering, headers/footers,
  text boxes, and local image asset behavior
* DOCX native benchmark coverage now includes table-heavy, link-heavy,
  image-heavy, notes/comments-heavy, metadata-on, batch-profile, and overlap
  compare rows against Microsoft MarkItDown on meaningful local samples
* PPTX now has checked-in second-round regression/metadata/quality evidence
  for slide order, bullets, grouped-shape reading order, speaker notes, hidden
  slides, explicit tables, local image assets, and caption-like image pairing
* PPTX native benchmark coverage now includes link-heavy, notes-heavy,
  layout-heavy, metadata-on, batch-profile, and overlap compare rows against
  Microsoft MarkItDown on selected local samples
* PPTX is now treated as `H2++ complete`, with `H3++` evidence backed on the
  checked-in native overlap corpus
* DOCX is now treated as `H2++ complete`, with `H3++` evidence backed on the
  checked-in native overlap corpus
* vendored `mbtpdf` is treated as a repository-local maintained dependency,
  with optional/manual upstream-style e2e isolated from the default root test
  story
* PDF is now treated as `H2++ complete` for the native text-PDF scope, with
  `H3++` evidence backed on the checked-in native text-PDF corpus; OCR and
  scanned-PDF paths remain explicitly separate

## Stable Milestone Status

Current stable milestone docs are:

* [docs/full-format-h2-completion.md](./full-format-h2-completion.md)
* [docs/h3-phase-1-summary.md](./h3-phase-1-summary.md)
* [docs/h3-phase-2-benchmark-governance.md](./h3-phase-2-benchmark-governance.md)

In short:

* the repository is past its initial full-format H2 expansion phase, but
  several format families remain intentionally partial, subset-oriented, or
  source-preserving
* H3 phase 1 performance optimization is done as a milestone artifact
* broader speed conclusions still require benchmark evidence by runner, mode,
  and corpus
* current quality records are a seed evidence set, not a final all-format H2
  parity conclusion
* the format-excellence workflow is now explicit in
  [docs/format-excellence-roadmap.md](./format-excellence-roadmap.md)
* current HTML quality conclusions are limited to the checked-in HTML overlap
  records in [docs/quality-comparisons/README.md](./quality-comparisons/README.md)
* current HTML H3 observations are limited to the checked-in native smoke,
  overlap, and batch-profile corpus; they are not browser-scale or blanket web
  claims
* the next H3 step is benchmark governance and broader corpus discipline, not
  another urgent converter hot-path cut

## Validation Contract

The repository currently expects these checks to be the normal stability bar:

```bash
moon check
moon test
./samples/check.sh
```

`./samples/check.sh` aggregates integrity, main output, metadata-sidecar, and
asset checks; metadata validation is no longer just a Markdown smoke path, and
CLI/batch contract checks now guard output-path behavior explicitly.

Useful benchmark and warning commands remain:

```bash
./samples/scripts/bench_smoke.sh
./samples/scripts/bench_compare_markitdown.sh
./samples/scripts/bench_batch_profile.sh
./samples/scripts/bench_warn.sh --all
```

## Current Priorities

The current next-stage priorities are:

* H3 phase 2 benchmark governance
* carry the same second-round excellence workflow into the next format without
  relaxing the HTML benchmark/quality evidence bar
* broader representative corpora, including larger real-world documents
* optional memory / RSS observation where platform support exists
* release/documentation polish
* selective H2.1 quality work where product value is clear
* corpus manifest validation tooling for future public/private/manual corpus
  tracking without checking sensitive paths into the repository

## Current Product Position

The project should now be read as:

* a MoonBit-native multi-format document-to-Markdown tool
* conservative and auditable rather than visually reconstructive
* past the first full-format milestone sweep, with second-round hardening now
  focused on stricter support boundaries and stronger evidence
* no longer in an "H2 in progress" or "first H3 hotspot triage" state
* currently focused on long-term benchmark governance and broader-corpus
  discipline rather than on ad-hoc micro-optimization
