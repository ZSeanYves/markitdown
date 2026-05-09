# EPUB Package Layer

`doc_parse/epub` is a MoonBit EPUB package parser for ZIP-based EPUB
containers.

It is intended to be a reusable lower-layer package: it opens EPUB archives,
normalizes and inventories package entries, resolves container rootfiles,
parses OPF metadata/manifest/spine, discovers EPUB3 nav and EPUB2 NCX
candidates, tracks conservative cover candidates, and exposes structured
inspect and validation reports.

It is not a reading-system renderer and it does not emit final Markdown.

## Candidate Status

Current status:

- `doc_parse/epub` is treated as an EPUB package/spine/nav foundation
  candidate within the current repository scope
- current delivery remains the importable subpackage
  `ZSeanYves/markitdown/doc_parse/epub`, not a separately split MoonBit module
- this candidate status does not claim full EPUB spec coverage, reading-system
  rendering, or DRM support

## Purpose

`doc_parse/epub` sits below `convert/epub`.

This package is responsible for:

- opening EPUB packages from `Bytes`
- normalizing archive entry paths
- reading `META-INF/container.xml`
- resolving primary OPF rootfiles
- exposing rootfile, manifest, spine, nav, NCX, and cover-package signal
- exposing lightweight package metadata
- reading package parts safely by normalized path
- exposing structured inspect/debug-friendly reports
- surfacing lower-layer errors and explicit validation issues

It intentionally does not own:

- final Markdown aggregation
- XHTML/HTML semantic conversion
- CSS rendering
- JavaScript execution
- reading-system layout behavior
- remote fetch
- DRM support

## Supported Scope

Current supported lower-layer scope:

- open EPUB packages from `Bytes`
- reject normalized path collisions and unsafe archive paths
- read `mimetype`
- parse `META-INF/container.xml`
- list container rootfiles and identify the selected primary rootfile
- parse OPF metadata, manifest, and spine
- preserve missing-manifest spine references as explicit validation findings
- discover EPUB3 nav documents
- fall back to minimal EPUB2 NCX discovery where supported
- detect cover-image candidates, including conservative guide fallback
- expose structured package inventory and inspect reports
- expose explicit validation reports for lower-layer hygiene issues
- read package parts safely by normalized path

## Non-Goals

This package intentionally does not:

- perform final Markdown aggregation
- behave like a generic ZIP dump API
- render CSS
- execute JavaScript
- fetch remote resources
- implement a reading-system layout engine
- claim DRM/encryption support
- claim full EPUB spec coverage
- claim full XHTML semantic conversion

Those responsibilities belong above this layer, mainly in `convert/epub`.

## Public API

Usage note:

- Add `ZSeanYves/markitdown/doc_parse/epub` as a dependency in your MoonBit
  package.
- Open EPUB bytes with `open_epub_package(bytes, source_name)`.
- Consume package, spine, nav, and inspect data from this layer.

Package facade:

- `open_epub_package(bytes, source_name)`
- `has_part(pkg, part_name)`
- `read_part_bytes(pkg, part_name)`
- `read_part_text(pkg, part_name)`
- `list_parts(pkg)`

Rootfile and package model:

- `list_epub_rootfiles(pkg)`
- `get_epub_primary_rootfile(pkg)`
- `list_epub_metadata(pkg)`
- `list_epub_manifest_items(pkg)`
- `find_epub_manifest_item(pkg, id)`
- `list_epub_spine_items(pkg)`
- `list_epub_spine_reading_order(pkg)`
- `find_epub_nav_item(pkg)`
- `find_epub_ncx_item(pkg)`
- `find_epub_cover_candidates(pkg)`
- `read_nav_document(pkg)`

Structured inspect and validation:

- `inspect_epub_inventory(pkg)`
- `inspect_epub_package(pkg)`
- `classify_epub_error(err)`
- `collect_epub_validation_issues(pkg)`
- `validate_epub_package(pkg)`

Public models:

- `EpubPackage`
- `EpubRootfileInfo`
- `EpubMetadata`
- `EpubMetadataEntry`
- `EpubManifestItem`
- `EpubSpineItem`
- `EpubNavPoint`
- `EpubCoverCandidate`
- `EpubPackageInventory`
- `EpubInspectReport`
- `EpubErrorInfo`
- `EpubValidationIssue`
- `EpubValidationReport`

## Minimal Examples

Open a package and inspect the selected rootfile:

```moonbit
let pkg = @epub.open_epub_package(bytes, "book.epub")
let primary = @epub.get_epub_primary_rootfile(pkg)
ignore(primary.full_path)
```

List manifest items and spine reading order:

```moonbit
let manifest = @epub.list_epub_manifest_items(pkg)
let reading_order = @epub.list_epub_spine_reading_order(pkg)
```

Inspect nav and NCX candidates:

```moonbit
let nav_item = @epub.find_epub_nav_item(pkg)
let ncx_item = @epub.find_epub_ncx_item(pkg)
```

Inspect cover candidates:

```moonbit
let candidates = @epub.find_epub_cover_candidates(pkg)
for candidate in candidates {
  ignore(candidate.source)
}
```

Read structured inventory:

```moonbit
let inventory = @epub.inspect_epub_inventory(pkg)
let part_count = inventory.part_count
let nav_path = inventory.nav_path
```

Classify lower-layer errors:

```moonbit
match try? @epub.open_epub_package(bytes, "book.epub") {
  Ok(pkg) => ignore(pkg)
  Err(err) => {
    let info = @epub.classify_epub_error(err)
    ignore(info.kind)
  }
}
```

Collect explicit validation issues:

```moonbit
let report = @epub.validate_epub_package(pkg)
for issue in report.issues {
  ignore(issue.kind)
}
```

## Design Principles

- keep this layer package/spine/nav oriented
- preserve OPF reading order rather than archive order
- keep unsupported media and missing manifest references explicit
- prefer deterministic inventory, inspect, and validation ordering
- keep inspect/report surfaces structured rather than dump-string only
- keep debug/inspect surfaces converter-independent
- keep remote/data resources blocked rather than fetched

## API Stability

Stable-candidate surface:

- `open_epub_package`
- `has_part`
- `read_part_bytes`
- `read_part_text`
- `list_parts`
- `list_epub_rootfiles`
- `get_epub_primary_rootfile`
- `list_epub_metadata`
- `list_epub_manifest_items`
- `find_epub_manifest_item`
- `list_epub_spine_items`
- `list_epub_spine_reading_order`
- `find_epub_nav_item`
- `find_epub_ncx_item`
- `find_epub_cover_candidates`
- `read_nav_document`
- `inspect_epub_inventory`
- `inspect_epub_package`
- `classify_epub_error`
- `collect_epub_validation_issues`
- `validate_epub_package`

Compatibility surface, but not ideal for external long-term reliance:

- `EpubPackage.archive`
- `EpubPackage.entries`
- `EpubPackage.entry_index`
- `EpubPackage.rootfile_path`
- `EpubPackage.rootfiles`
- `EpubPackage.manifest`
- `EpubPackage.spine`
- `EpubPackage.nav_item`
- `EpubPackage.nav_document_item`
- `EpubPackage.ncx_item`
- `EpubPackage.cover_item`
- `EpubPackage.guide_cover_path`
- `EpubPackage.cover_candidates`
- `EpubPackage.nav_points`

These remain public today because in-repo converter consumers still touch them
directly. Tightening them should be treated as a future versioned API change,
not as a silent refactor.

Versioning note:

- additive facade and inspect helpers are the preferred evolution path
- compatibility-preserving behavior wins over aggressive breakage in the
  current repository line
- any future field-visibility tightening should be treated as a release-policy
  change

## Safety Boundaries

- archive entry paths are normalized before use
- parent-escape paths are rejected
- normalized path collisions are rejected
- remote/data/scheme-like hrefs are blocked rather than fetched
- `META-INF/encryption.xml` is treated as unsupported
- malformed XML fails closed through `EpubError`
- guide fallback is conservative and package-local
- this package does not claim DRM support

## Errors vs Validation Issues

- `EpubError` represents open/read/parse failures
- `EpubValidationIssue` represents explicit package-hygiene findings collected
  after a package opens successfully
- use `classify_epub_error` for failure analysis
- use `validate_epub_package` when you want lower-layer package hygiene
  reporting without changing normal package opening behavior

Current validation focus:

- multiple rootfiles are reported explicitly while default open keeps choosing
  the first usable rootfile deterministically
- missing manifest items referenced by spine
- missing resolved spine targets
- duplicate spine `idref` values
- missing navigation documents when neither EPUB3 nav nor NCX is available
- unsupported spine item media types for lower-layer reading-order consumers

Default compatibility policy:

- `open_epub_package` keeps current converter-facing behavior
- explicit validation is additive and opt-in through
  `collect_epub_validation_issues` / `validate_epub_package`
- non-fatal package hygiene findings do not automatically become open failures

## Rootfile Selection Policy

- all declared rootfiles from `META-INF/container.xml` are exposed through
  `list_epub_rootfiles`
- the first usable normalized rootfile is selected deterministically
- multiple rootfiles are not fatal by default; they are reported as validation
  issues
- missing or unusable rootfiles still fail closed during package open

## Navigation Policy

- EPUB3 nav documents outrank NCX when both are present
- NCX remains a conservative fallback when no EPUB3 nav is available
- missing both nav and NCX is not fatal by default
- missing navigation signal is surfaced as an explicit validation warning

## Cover Candidate Policy

- cover-image manifest properties outrank metadata and guide fallback
- metadata `name="cover"` stays a package-level candidate source
- guide references stay conservative and package-local
- guide cover pages are preserved as signal, but not promoted to image covers
  unless they resolve to a manifest image

## Remote Resource Policy

- remote/data/scheme-like hrefs are blocked rather than fetched when this layer
  is asked to normalize package paths
- lower-layer package open does not try to act like a reading system or remote
  asset fetcher
- remote-resource fallback behavior above package open remains the
  responsibility of `convert/epub`

## read_part_text Boundary

- `read_part_text` is a package-local XML/text helper for EPUB parts
- it is not a converter-level text policy surface
- it does not imply XHTML semantic conversion or shared normalization policy

## Known Limits

- this package does not implement full EPUB specification coverage
- this package does not render CSS/JS or behave like a reading system
- this package does not fetch remote resources
- this package does not expose DRM support
- XML handling is intentionally lightweight and scoped to package-level helpers
- NCX support is minimal and conservative
- guide handling is only used for conservative cover fallback
- validation taxonomy is additive and may grow without changing default open
  behavior
- inspect reports are structured and useful for tooling, but they are still a
  lower-layer package contract rather than a final interchange schema

## Relationship to `convert/epub`

`convert/epub` is a consumer of this package.

The lower layer provides:

- normalized package inventory
- rootfile/OPF metadata
- manifest/spine structure
- nav/NCX discovery
- cover candidates
- safe part reads

`convert/epub` remains responsible for:

- XHTML/HTML body conversion
- asset materialization
- warning-block policy
- final Markdown ordering and output
- metadata sidecar shaping

## Testing

The primary lower-layer tests live in `doc_parse/epub/test`.

Run:

```bash
moon test doc_parse/epub/test --target native
```

Broader repository verification:

```bash
moon check
moon test
./samples/check.sh
```
