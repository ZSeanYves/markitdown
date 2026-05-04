# Upstream Notes

## Source

This directory vendors `bobzhang/mbtpdf` version `0.1.2`, copied from the
MoonBit package cache previously resolved for this project:

```text
.mooncakes/bobzhang/mbtpdf
```

The vendored module keeps the upstream package name `bobzhang/mbtpdf` so
existing imports continue to resolve without changing adapter code.

## Purpose

`vendor/mbtpdf` is used as the local backend for `doc_parse/pdf/raw`.
Keeping it in the repository allows controlled local changes to PDF parsing
behavior in future phases.

## Boundary

Phase V0 is vendoring only:

- Do not change PDF conversion behavior.
- Do not add new PDF features.
- Keep `doc_parse/pdf/raw/mbtpdf_text_adapter.mbt` as the adapter boundary
  to mbtpdf internals.
- Higher layers should depend on `doc_parse/pdf` types instead of mbtpdf
  types.

## License and README

The upstream `LICENSE`, `README.md`, and `README.mbt.md` are preserved in this
directory.
