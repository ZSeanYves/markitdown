# Upstream Notes

## Source

This directory was originally copied from the upstream MoonBit package
`bobzhang/mbtpdf` version `0.1.2`, sourced from a previously resolved local
MoonBit package cache:

```text
.mooncakes/bobzhang/mbtpdf
```

## Current status

The vendored tree is now maintained as a repository-local package subtree under
`ZSeanYves/markitdown/vendor/mbtpdf/...`.

That means:

* the root repository no longer depends on `bobzhang/mbtpdf` through a
  path-only external dependency in `moon.mod.json`
* active imports resolve to repository-local package paths
* this tree should be treated as a maintained fork, not a transparent upstream
  mirror

## Purpose

`vendor/mbtpdf` is used as the local backend for `doc_parse/pdf/raw`.
Keeping it in the repository allows controlled local changes to PDF parsing
behavior while preserving a narrow adapter boundary.

## Boundary

The intended dependency boundary remains:

* `doc_parse/pdf/raw` may import vendored mbtpdf packages directly
* higher `doc_parse/pdf` layers expose repository-owned raw/model/api types
* `convert/pdf` should depend on `doc_parse/pdf` types rather than vendored
  mbtpdf types

## License and README

The upstream `LICENSE`, `README.md`, and `README.mbt.md` are preserved in this
directory and should remain preserved when the vendored fork is updated.
