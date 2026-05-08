# EPUB Package Layer

## Positioning

`doc_parse/epub` is the repository's lower-layer EPUB package parser.

It sits below `convert/epub` and is responsible for EPUB container/package
signal such as:

* `META-INF/container.xml`
* OPF rootfile resolution
* manifest items
* spine order
* nav / NCX discovery
* cover candidates
* lightweight package metadata

It is not a reading-system renderer and it does not emit final Markdown.

## Supported Scope

Current supported scope:

* open EPUB packages from `Bytes`
* normalize and inventory archive entry paths
* read `mimetype`
* parse `META-INF/container.xml`
* resolve the active OPF rootfile
* parse OPF metadata, manifest, and spine
* preserve missing-manifest spine items as lower-layer warning candidates
* discover EPUB3 nav documents
* fall back to minimal EPUB2 NCX discovery where supported
* detect cover-image candidates, including conservative guide fallback
* expose lightweight inspect summaries for package/spine action review
* read package parts safely by normalized path

## Non-goals

This package intentionally does not:

* perform final Markdown aggregation
* act like a generic ZIP dump
* render CSS
* execute JavaScript
* fetch remote resources
* implement a reading-system layout engine
* claim DRM support
* claim complete EPUB spec coverage

Those responsibilities belong above this layer, mainly in `convert/epub`.

## Public APIs

Package facade:

* `open_epub_package(bytes, source_name)`
* `has_part(pkg, part_name)`
* `read_part_bytes(pkg, part_name)`
* `list_parts(pkg)`

Inspection:

* `inspect_epub_package(pkg)`
* `read_nav_document(pkg)`

Public models:

* `EpubPackage`
* `EpubMetadata`
* `EpubManifestItem`
* `EpubSpineItem`
* `EpubNavPoint`
* `EpubInspectReport`

## Safety Boundaries

Current package-safety rules:

* archive entry paths are normalized before use
* parent-escape paths are rejected
* normalized path collisions are rejected
* `META-INF/encryption.xml` is treated as unsupported
* malformed XML fails closed through `EpubError`
* remote/data resources are not fetched by this layer

## Design Principles

* keep this layer package/spine/nav oriented
* preserve reading order from the OPF spine, not archive order
* keep unsupported media and missing manifest items explicit
* prefer deterministic inspection output
* keep debug/inspect summaries lower-layer and converter-independent

## Relationship To `convert/epub`

`convert/epub` is the main consumer of this package.

The lower layer provides:

* normalized package inventory
* OPF metadata
* manifest/spine structure
* nav/NCX signal
* cover candidates
* safe part-byte access

`convert/epub` remains responsible for:

* XHTML/HTML body conversion
* warning-block policy
* asset materialization
* final Markdown ordering/output
* metadata sidecar shaping

## Tests

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

## Current Limits

* XML handling is intentionally lightweight and scoped to current EPUB package
  helpers
* NCX support is minimal and conservative
* guide handling is only used for conservative cover fallback
* no CSS/JS/remote-fetch/rendering behavior
* no DRM support
* inspect summaries are for debugging and may evolve; they are not a stable
  interchange format
