# Camlpdf -> MoonBit port plan (Phase 0)

## Scope and constraints
- Feature parity with the camlpdf sources under `camlpdf/`.
- Native target only.
- Prefer pure MoonBit implementations for compression and crypto.
- API parity is not required, but naming should stay close to camlpdf where practical.

## Package layout (grouped hierarchy)

Packages are grouped by domain (core/codec/crypto/syntax/font/graphics/text/document/io),
while leaf package names still map closely to camlpdf module names. Paths below
are module-relative (for example, `core/pdfio`), and import aliases default to
the last path segment (so `bobzhang/mbtpdf/core/pdfio` is used as `@pdfio`).

| Package path | camlpdf module(s) | Notes |
| --- | --- | --- |
| `core/pdf` | `pdf` | Core object model, document type, object map, lookup helpers |
| `core/pdfutil` | `pdfutil` | List/string helpers used across the codebase |
| `core/pdfio` | `pdfio` | Input/output abstractions, byte helpers |
| `codec/pdfcodec` | `pdfcodec` | Stream decode/encode dispatch |
| `codec/pdfflate` | `pdfflate` | Flate (zlib/deflate) codec, pure implementation |
| `syntax/pdfgenlex` | `pdfgenlex` | PDF lexical scanner |
| `io/pdfread` | `pdfread` | Parser, xref, object streams |
| `core/pdfe` | `pdfe` | Error logging hook |
| `io/pdfwrite` | `pdfwrite` | Serialization and xref writing |
| `document/pdftree` | `pdftree` | Page tree operations |
| `document/pdfpage` | `pdfpage` | Page manipulation helpers |
| `document/pdfpagelabels` | `pdfpagelabels` | Page labels |
| `document/pdfdest` | `pdfdest` | Destinations |
| `document/pdfpaper` | `pdfpaper` | Paper sizes |
| `core/pdfunits` | `pdfunits` | Unit conversions |
| `graphics/pdfops` | `pdfops` | Content stream operators |
| `graphics/pdfspace` | `pdfspace` | Color spaces |
| `core/pdftransform` | `pdftransform` | Matrices and transforms |
| `text/pdftext` | `pdftext` | Text extraction/layout helpers |
| `graphics/pdffun` | `pdffun` | PDF function objects |
| `font/pdfafm` | `pdfafm` | AFM parsing |
| `font/pdfafmdata` | `pdfafmdata` | Built-in AFM data tables |
| `font/pdfglyphlist` | `pdfglyphlist` | Glyph name to Unicode mapping |
| `font/pdfcmap` | `pdfcmap` | CMap parsing |
| `font/pdffont` | `pdffont` | Font encodings and shared types |
| `font/pdfstandard14` | `pdfstandard14` | Standard 14 fonts |
| `graphics/pdfimage` | `pdfimage` | Image XObjects |
| `codec/pdfjpeg` | `pdfjpeg` | JPEG support |
| `document/pdfannot` | `pdfannot` | Annotations |
| `document/pdfmarks` | `pdfmarks` | Bookmarks/marks |
| `document/pdfocg` | `pdfocg` | Optional content groups |
| `document/pdfmerge` | `pdfmerge` | Merge/split helpers |
| `document/pdfst` | `pdfst` | Structure tree |
| `core/pdfcryptprimitives` | `pdfcryptprimitives` | AES/SHA2/etc primitives |
| `crypto/pdfcrypt` | `pdfcrypt` | Encryption/decryption |
| `core/pdfdate` | `pdfdate` | PDF date parsing/formatting |

## Dependency notes (high level)
- Almost everything depends on `core/pdfutil`, many depend on `core/pdfio`.
- `io/pdfread` depends on `syntax/pdfgenlex` and codec packages.
- `io/pdfwrite` depends on core + io + util + codec.
- `crypto/pdfcrypt` depends on `core/pdfcryptprimitives` plus core/io/util.
- Font/text packages are mostly independent once core object access is in place.

## Naming and compatibility notes

MoonBit types must be UpperCamel. The plan is to keep package names close to
OCaml module names, and apply light renaming for types.

Examples (proposed):
- `Pdf.t` -> `@pdf.Pdf`
- `pdfobject` -> `@pdf.PdfObject`
- `stream` -> `@pdf.Stream`
- `PDFError` -> `suberror PdfError String`
- `Pdfio.input` -> `@pdfio.Input` (from `core/pdfio`)
- `Pdfio.bytes` -> `@pdfio.Bytes` (from `core/pdfio`)

Function names should stay close to camlpdf where possible, using MoonBit
snake_case. Optional arguments map to labeled optional parameters.

## Data-only modules

`font/pdfafmdata`, `font/pdfglyphlist`, and `font/pdfstandard14` embed large tables. These
should be generated or stored as dedicated MoonBit data files to keep the main
logic readable and to avoid huge diffs during refactors.

## Resolution Notes

The Phase 0 port is complete. Key decisions made:

- **`core/pdfutil`**: Minimized public API to essential helpers only (memoization,
  debug utilities). OCaml-specific compatibility functions were removed.
- **Compat package**: Not implemented. Direct package imports with `@` aliases
  (e.g., `@pdf`, `@pdfio`) provide clear naming without a compatibility layer.
- **Lazy streams**: Preserved `Got`/`ToGet` pattern in `core/pdf` for lazy stream
  materialization, which works well with the object graph model.
