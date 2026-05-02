# EPUB H1/H2 Ebook Review

This document records the current EPUB H1/H2 ebook review status for
`markitdown-mb`.

It is an audit and planning document. The detailed support contract remains
[docs/support-and-limits.md](./support-and-limits.md).

## Current implementation map

### Converter and lower layer

* converter entry: `convert/epub/epub_parser.mbt`
* package / OPF / manifest / spine model: `doc_parse/epub/epub_package.mbt`
* EPUB XML helpers: `doc_parse/epub/epub_xml.mbt`
* EPUB typed model: `doc_parse/epub/epub_types.mbt`
* EPUB reuses the shared ZIP lower layer for safe archive access

### Dispatch and container wiring

* `.epub` is routed through the shared dispatcher
* ZIP also treats `.epub` as a nested archive boundary, not as a recursive
  conversion target
* EPUB conversion is package-driven, not ZIP-entry-dump-driven

### Metadata / provenance

* metadata format is `epub`
* container archive name is preserved as `source_name`
* OPF title / creator / date / modified are surfaced as document metadata when available
* every spine heading / converted block is rewritten with EPUB container origin
* asset origins are remapped to archive-scoped paths and keep EPUB provenance
* warning blocks keep the offending spine entry path

## Current H1 status

### Supported and stable in H1

* `META-INF/container.xml` resolution
* OPF rootfile lookup
* OPF manifest / spine parsing
* spine-order aggregation from OPF spine, not ZIP order
* XHTML / HTML spine item conversion through the HTML converter path
* same-archive local images through a safe extracted tree
* archive-scoped asset namespace/remap
* OPF document metadata through the shared metadata sidecar
* unsupported spine items degrade per item
* `linear="no"` spine items are skipped in the current H1 path

### Current policy fixed by regression

* unsafe rootfile paths fail closed
* unsafe manifest hrefs fail closed
* normalized archive collisions fail closed
* duplicate manifest ids fail closed
* missing manifest items referenced by spine fail closed
* `META-INF/encryption.xml` fails closed as unsupported DRM/encryption
* remote resources are not fetched
* EPUB does not recurse into nested archives

### Known H1 limits

* no nav/NCX semantic reconstruction
* no CSS rendering
* no DRM handling
* no browser-like reader semantics
* no audio/video/font/SVG spine rendering
* no percent-decoded href normalization beyond current safe path model
* no explicit cover/landmarks/guide semantics
* no standalone EPUB reading-order UI

## H2 gap table

| Area | Current behavior | Market expectation | Gap | Bottom-layer needed? | Suggested action |
| --- | --- | --- | --- | --- | --- |
| nav.xhtml / NCX | Not reconstructed | Basic TOC/reading-navigation preservation | Large | Yes | Add EPUB navigation model after package layer grows |
| OPF metadata completeness | Title/creator/date/modified only | Richer metadata and cover hints | Moderate | Yes | Extend EPUB package model before converter polish |
| Cover image semantics | Not explicit | Cover detection or annotation | Moderate | Yes | Model cover metadata and manifest properties |
| `linear=no` | Skipped | Explicit policy plus optional annotation | Small | Partly | Keep skip behavior but document it clearly |
| Landmarks / guide | Not used | Better structural cues | Moderate | Yes | Parse and preserve guide/landmarks where safe |
| CSS semantics | Ignored | Better readability in complex ebooks | Large | No | Keep non-goal for H2 |
| Footnotes / endnotes | Not specialized | Better ebook note recovery | Moderate | Yes | Improve XHTML/HTML lower layer first |
| Internal links / anchors | Basic through HTML path | More stable anchor preservation | Moderate | Partly | Add real-world anchor cases and review HTML lower layer |
| Fragment / percent-encoded hrefs | Safe path model only | Broader href compatibility | Moderate | Yes | Extend EPUB href model carefully |
| Duplicate manifest hrefs | Not modeled specially | Clearer policy and diagnostics | Moderate | Yes | Preserve inventory in package model |
| Media overlays / audio/video | Unsupported warnings | Optional graceful annotation | Small | Partly | Keep warning/fallback policy for now |
| SVG / font spine items | Unsupported warnings | Better explicit unsupported handling | Small | Partly | Keep warning blocks and improve docs only |
| Remote resources | Not fetched | No fetch, but better diagnostics | Small | No | Keep no-fetch policy |
| DRM/encryption | Fail closed | Strong unsupported detection | Small | No | Keep fail-closed |
| Large ebook performance | Smoke coverage only | Small / medium / large / batch visibility | Moderate | Partly | Expand benchmark tiers and inspect package overhead |
| Assets remap robustness | Works for local images | Better collision-stress coverage | Moderate | Partly | Add more asset-heavy EPUB cases |
| Per-spine-item provenance | Stable but lightweight | Richer entry-level provenance | Moderate | Yes | Extend EPUB package/debug model if needed |

## EPUB lower-layer gaps

The EPUB path is already package-driven and reusable, but the H2 blockers are
mostly in package/model depth rather than in converter-only logic.

### Stable enough today

* container.xml lookup works
* OPF manifest and spine parsing work
* safe archive path handling is already in place via ZIP substrate
* safe extracted tree materialization exists for XHTML local-image resolution
* asset remapping preserves EPUB provenance at the archive level

### Lower-layer gaps that likely gate H2 quality

* no dedicated nav.xhtml / NCX model
* no explicit cover / landmark / guide model
* no richer manifest property model
* no anchor / fragment dependency graph
* no package-level inventory/debug surface for real ebooks
* no explicit media-type policy model beyond current supported/unsupported split

### Recommendation

If EPUB H2 work stalls, strengthen the EPUB package layer first:

* preserve more OPF manifest / spine metadata
* add navigation / cover / landmarks models
* expose clearer per-spine-item inventory/debug surfaces
* keep XHTML conversion inside the existing HTML path rather than rebuilding it
* avoid adding converter-local string patches to imitate missing ebook signals

## Suggested next actions

* add real-world EPUB samples with multiple spine chapters and local images
* add navigation / cover-related package tests once the package model can hold them
* benchmark short vs long spine books separately
* keep unsupported media as warning blocks for now
* review XHTML/HTML spine behavior separately from generic XML

## Non-goals for now

* browser-grade CSS rendering
* DRM handling
* ebook-reader UI semantics
* full nav/TOC semantic reconstruction
* recursive nested archive traversal
