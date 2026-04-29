# Architecture Overview

This module implements a PDF toolchain in MoonBit, centered on an in-memory
PDF object model with packages for parsing, writing, content manipulation, and
document-level features (merge, text extraction, encryption, etc.).

## High-level Flow

Package paths below are shown relative to the module root (for example,
`core/pdfio`), and import aliases default to the last path segment (so
`bobzhang/mbtpdf/core/pdfio` is used as `@pdfio`).

```
Input bytes (core/pdfio)
  <- io/pdfiofs (native file/channel adapters)
  -> io/pdfread (xref + object streams + encryption)
    -> syntax/pdfsyntax + syntax/pdfgenlex (lex/parse)
      -> Pdf object graph (core/pdf)
        -> operations (document/pdfpage, graphics/pdfops, text/pdftext, graphics/pdfimage, ...)
          -> io/pdfwrite (serialize + xref + filters + encryption)
            -> Output bytes (core/pdfio)
```

## Layered Architecture

The codebase follows a layered architecture with downward-only dependencies:

```
Layer 0: Base utilities
  core/pdfutil, core/pdfe

Layer 1: IO primitives
  core/pdfio (in-memory Input/Output + byte utilities)
  io/pdfiofs (native-only file/channel adapters)

Layer 2: Core model + geometry
  core/pdf, core/pdftransform, core/pdfunits, document/pdfpaper, core/pdfdate

Layer 3: Syntax + lexing
  syntax/pdfgenlex, syntax/pdfsyntax

Layer 4: Codecs + crypto
  codec/pdfflate, codec/pdfcodec, codec/pdfjpeg, core/pdfcryptprimitives, crypto/pdfcrypt

Layer 5: Fonts + encodings data
  font/pdfafm, font/pdfafmdata, font/pdfglyphlist, font/pdfcmap, font/pdffont, font/pdfstandard14

Layer 6: Content stream + functions
  graphics/pdfops, graphics/pdffun, graphics/pdfspace

Layer 7: Read/Write services
  io/pdfread, io/pdfwrite

Layer 8: Document structure
  document/pdftree, document/pdfpage, document/pdfpagelabels, document/pdfdest,
  document/pdfannot, document/pdfocg, document/pdfst, document/pdfmarks

Layer 9: Features
  text/pdftext, graphics/pdfimage, document/pdfmerge

Layer 10: CLI
  cmd/*
```

Key design principles:
- Mid-layer packages (graphics/pdfops, document/pdfpage, etc.) do not depend on IO services (io/pdfread/io/pdfwrite)
- Font types live in `font/pdffont`, allowing `font/pdfstandard14` to avoid depending on `text/pdftext`

## Package Dependency Map (High Level)

```
cmd/*
  |-> io/pdfread -----> syntax/pdfsyntax + syntax/pdfgenlex
  |-> io/pdfwrite ----> codec/pdfcodec + codec/pdfflate (+ crypto/pdfcrypt)
  |-> document/pdfmerge + document/pdfpage + graphics/pdfops + text/pdftext + graphics/pdfimage + ...
        |-> core/pdf (core object graph)
        |-> core/pdftransform + graphics/pdfspace + core/pdfunits + document/pdfpaper
        |-> font/pdffont + font/pdfstandard14 + font/pdfafm + font/pdfafmdata + font/pdfglyphlist + font/pdfcmap

Base utilities used across most packages:
  core/pdfio + core/pdfutil + core/pdfe + core/pdfcryptprimitives
```

## Core Layer

- `core/pdf`: central data model (`Pdf`, `PdfObject`, streams, object map).
  - Supports lazy streams via `Stream::ToGet`, materialized via `Stream::Got`.
  - Provides `string_of_pdfobj` for object serialization.
  - Trait helpers:
    - `@pdf.ToPdfNumber`: converts `Int`/`Double` to `PdfObject` numeric nodes
      (`Integer`/`Real`). This avoids ad-hoc helpers like `mkint`/`mkreal` across
      packages, while keeping conversion intentionally narrow (numbers only).
- `core/pdfio`: byte-level Input/Output abstractions used across the stack.
- `io/pdfiofs`: filesystem/channel adapters that build `@pdfio.Input`/`@pdfio.Output`
  from native `@fs.File` handles (kept out of `core/` to preserve a mostly-pure core).
- `core/pdfutil`: shared helpers (hash tables, memoization, logging helpers).
- `core/pdfe`: logging hook for error/debug output, debug flags.
  - Example:
    ```mbt
    let pdf = @pdf.Pdf::empty()
    let objnum = pdf.addobj(@pdf.PdfObject::Integer(42))
    let _ = pdf.lookup_obj(objnum)
    ```

## Parsing and Reading

- `syntax/pdfgenlex`: token stream definition and token helpers.
- `syntax/pdfsyntax`: lexer/parser from bytes to `PdfObject`.
- `io/pdfread`: orchestrates header/xref parsing, object streams, encryption,
  and lazy loading; entry point for `pdf_of_file`, `pdf_of_input`, etc.
- `codec/pdfcodec` + `codec/pdfflate` + `codec/pdfjpeg`: stream filter decoding and compression.
- `crypto/pdfcrypt` + `core/pdfcryptprimitives`: decryption and encryption primitives.
  - Example:
    ```mbt
    async fn load() -> @pdf.Pdf {
      let pdf = @pdfreadfs.PdfReadFs::new().pdf_of_file(None, None, "input.pdf")
      let _ = @pdfread.PdfRead::new().what_encryption(pdf)
      pdf
    }
    ```

## Writing and Serialization

- `io/pdfwrite`: serializes `Pdf` to bytes, builds xref tables/streams, optional
  object stream generation, and encryption.
- `codec/pdfcodec`/`codec/pdfflate`: stream encoding for compressed output.
- `crypto/pdfcrypt`: encryption settings for output.
  - Example:
    ```mbt
    async fn save(pdf : @pdf.Pdf) -> Unit {
      @pdfwritefs.PdfWriteFs::new().pdf_to_file(pdf, "output.pdf")
    }
    ```

## Document Structure and Content

- `document/pdfpage` + `document/pdftree`: page tree construction/reading and page operations.
- `graphics/pdfops`: parse and emit content stream operators (pure, no IO dependencies).
- `text/pdftext`: text extraction and text operators; uses `graphics/pdfops` and font data.
- `graphics/pdfimage`: image XObject extraction/decoding.
- `document/pdfdest`, `document/pdfannot`, `document/pdfmarks`, `document/pdfocg`,
  `document/pdfpagelabels`, `document/pdfst`:
  destinations, annotations, bookmarks, optional content, page labels,
  and structure tree support.
- `document/pdfmerge`: merges documents and reconciles cross-document structures.
  - Example:
    ```mbt
    let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
    let text = @pdftext.PdfText::new(pdf).extract_text()
    let _ = pages.length()
    ```

## Fonts, Encodings, and Layout Data

- `font/pdffont`: font type definitions (`Font`, `Encoding`, `StandardFont`, etc.)
  shared across packages without creating circular dependencies.
- `font/pdfstandard14`, `font/pdfafm`, `font/pdfafmdata`: built-in font metrics and AFM parsing.
- `font/pdfglyphlist`: glyph name to Unicode mapping.
- `font/pdfcmap`: CMap parsing for composite fonts.
- `text/pdftext`: font reading/writing and text extraction.
  - Example:
    ```mbt
    let width = @pdfstandard14.PdfStandard14::new().textwidth(
      true,
      @pdffont.Encoding::WinAnsiEncoding,
      @pdffont.StandardFont::Helvetica,
      "Hello",
    )
    ```

## Geometry, Units, and Utilities

- `core/pdftransform`: affine transformation matrices.
- `graphics/pdfspace`: color space utilities.
- `core/pdfunits` + `document/pdfpaper`: unit conversion and standard paper sizes.
- `core/pdfdate`: PDF date parsing/formatting helpers.
  - Example:
    ```mbt
    let paper = @pdfpaper.a4
    let rect = @pdfpage.rectangle_of_paper(paper)
    ```

## Entry Points and Tests

## Traits Used For Refactoring

MoonBit traits are used as "typeclass-style" abstractions to remove duplicated
glue code without introducing runtime plugin systems.

### Numeric `PdfObject` Conversion (`@pdf.ToPdfNumber`)

Many packages need to build PDF dictionaries and arrays containing numeric
objects. Instead of sprinkling local helpers (`mkint`/`mkreal`) everywhere,
use:

```mbt
let n0 : @pdf.PdfObject = @pdf.ToPdfNumber::to_pdf_number(42)
let n1 : @pdf.PdfObject = @pdf.ToPdfNumber::to_pdf_number(3.14)
```

This intentionally does *not* try to convert `String` because PDF has multiple
string-like node types (`String` vs `Name`) and implicit conversion would be
ambiguous.

### Filter Name Decoding (`@pdfcodec.PdfFilterNameDecode`)

PDF stream decoding chooses filters dynamically by name (`/Filter` entries like
`/FlateDecode`, `/LZW`, `/CCITTFaxDecode`, ...). To keep the supported filter
set and parameter handling in one place, `codec/pdfcodec` defines:

- `@pdfcodec.PdfFilterNameDecode` (implemented for `String`), which decodes a
  *single* filter stage given the filter name, the associated `/DecodeParms`
  entry (if any), and the input bytes.

This is reused by both:
- `PdfCodec::decode_pdfstream_onestage` (mutating a `Stream` object), and
- `PdfCodec::decode_from_bytes` (pure bytes-to-bytes decoding).

Unsupported filters (notably `/JBIG2Decode` in the sync path) raise
`CodecError::DecodeNotSupported` so callers can decide whether to stop or
continue.

### Encryption Helpers (`@pdfcryptprimitives`)

The encryption layer also has small “centralize the branching” helpers to avoid
duplicating `match Encryption` logic across packages:

- `Encryption::r_and_keylength()` returns the PDF security handler revision
  (`/R`) and the key length in bits implied by the variant.
- `PdfCryptPrimitives::decrypt_stream_data(...)` performs both encryption and
  decryption for string/stream payload bytes once you have the right keys.

### CLI Tools (`cmd/`)

| Tool | Description |
|------|-------------|
| `main` | General-purpose PDF utility |
| `pdftext` | Extract text content from PDFs |
| `pdfmergeexample` | Merge multiple PDF documents |
| `pdfencrypt` | Encrypt PDFs with password protection |
| `pdfdraft` | Create draft/preview versions of PDFs |
| `pdfdecomp` | Decompress PDF streams for inspection |
| `pdfhello` | Simple "hello world" PDF generation example |
| `pdftest` | Test utilities for development |

### Tests

- `e2e/*`: End-to-end roundtrip tests (merge, split, annotate, encrypt, etc.)
- Per-package `*_test.mbt` files: Unit tests for individual packages
- See `docs/e2e-tests.md` for detailed test coverage information
