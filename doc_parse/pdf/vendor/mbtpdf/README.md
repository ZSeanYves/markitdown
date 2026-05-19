# Local PDF Support: `mbtpdf`

This directory contains repository-local PDF support code for `markitdown-mb`.
It began as a copy of the upstream MoonBit package `bobzhang/mbtpdf`, but it is
now maintained here as a trimmed local subtree rather than as a full external
package mirror.

## Role in this repository

The active dependency boundary is:

* `doc_parse/pdf/raw` imports the packages in this subtree directly.
* `doc_parse/pdf` exposes repository-owned raw/model/api types.
* `convert/pdf` depends on `doc_parse/pdf`, not on internal `mbtpdf` package
  paths.

There is no repository runtime dependency on a broad `@mbtpdf` root facade.
The root directory only keeps a small test-only package shell so
`moon test doc_parse/pdf/vendor/mbtpdf` continues to exercise local fs read/write
helpers without pulling a convenience facade into product code.

Within that boundary, this subtree remains responsible for low-level PDF
parsing concerns such as object reading, stream decoding, glyph mapping, CMap
handling, annotation extraction, and raw text extraction.

## Local maintenance policy

This directory is maintained for the needs of `markitdown-mb`, not as a
complete upstream package checkout. We may:

* trim unused packages, tests, scripts, and documentation residue
* keep only the package surface required by repository runtime and tests
* make repository-specific fixes for parsing behavior

We should not remove provenance or license information when trimming files from
this subtree.

## Validation

Changes in this subtree should be validated through the repository's PDF-facing
entry points, including:

```bash
moon test doc_parse/pdf/raw --target native
moon test doc_parse/pdf/test --target native
moon test convert/pdf --target native
bash samples/helpers/check_pdf_contract.sh
```

## Provenance and license

See [NOTICE](./NOTICE) for upstream provenance and local maintenance notes.
The upstream [LICENSE](./LICENSE) is intentionally preserved.
