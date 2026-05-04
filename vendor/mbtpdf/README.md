# ZSeanYves/markitdown/vendor/mbtpdf

This directory contains a repository-local maintained fork of the upstream
MoonBit PDF project originally published as `bobzhang/mbtpdf`.

It is vendored into `markitdown-mb` and maintained here because the PDF
lower-layer parser depends on local modifications that are not treated as a
drop-in mirror of upstream.

## Status in this repository

`vendor/mbtpdf` is used as an in-repository package tree under the root module.
It is not referenced through a path-only external dependency in the root
`moon.mod.json`.

The active lower-layer boundary is:

* `doc_parse/pdf/raw` imports `vendor/mbtpdf` packages directly
* `doc_parse/pdf` exposes repository-owned raw/model/api types
* `convert/pdf` depends on `doc_parse/pdf`, not on `vendor/mbtpdf` internals

## Upstream provenance

Original upstream project:

* `bobzhang/mbtpdf`

See also:

* [UPSTREAM.md](./UPSTREAM.md)
* preserved upstream `LICENSE`
* preserved upstream `README.mbt.md`

## Local modification scope

This vendored fork is maintained for `markitdown-mb` PDF parsing needs,
including repository-local changes in areas such as:

* PDF text extraction and text-state signals
* page/object/image/annotation hooks needed by the PDF lower layer
* APIs relied on by `doc_parse/pdf/raw` and PDF tests

The repository should assume this tree may differ materially from upstream.
Changes here should be reviewed as part of the PDF lower-layer implementation,
not as a passive mirror refresh.

## License / notices

Upstream provenance and licensing files are intentionally preserved in this
directory. Do not remove them when updating the vendored fork.
