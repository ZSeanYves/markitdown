# @bobzhang/mbtpdf/codec/pdfflate

FLATE/zlib compression and decompression for PDF streams.

## Overview

This package implements the DEFLATE algorithm (RFC 1951) used by the FlateDecode filter in PDF documents. It supports both compression and decompression with optional zlib headers.

## Errors

### FlateError

Raised on compression or decompression errors.

```moonbit nocheck
///|
pub suberror FlateError {
  Error(String, String) // (operation, message)
}
```

## Types

### PdfFlate

Compression/decompression context.

```moonbit nocheck
pub struct PdfFlate { ... }
pub fn PdfFlate::new() -> PdfFlate
```

## Methods

### PdfFlate::compress

Compress data using the DEFLATE algorithm with a streaming interface.

```moonbit nocheck
pub fn PdfFlate::compress(
  self : PdfFlate,
  level? : Int,
  header? : Bool,
  input : (@pdfio.MutableBytes) -> Int,
  output : (@pdfio.MutableBytes, Int) -> Unit
) -> Unit
```

- `level`: Compression level (currently ignored, uses stored blocks)
- `header`: Include zlib header/trailer (default: true)
- `input`: Read callback returning bytes read (0 for EOF)
- `output`: Write callback for compressed data

### PdfFlate::uncompress

Decompress DEFLATE data using a streaming interface. Supports all DEFLATE block types: stored, fixed Huffman, and dynamic Huffman.

```moonbit nocheck
pub fn PdfFlate::uncompress(
  self : PdfFlate,
  header? : Bool,
  input : (@pdfio.MutableBytes) -> Int,
  output : (@pdfio.MutableBytes, Int) -> Unit
) -> Unit raise FlateError
```

- `header`: Expect zlib header (default: true)

## Usage

The streaming interface uses callbacks for input and output:
- **input**: Called to read data into a buffer, returns number of bytes read (0 for EOF)
- **output**: Called to write decompressed/compressed data

This package is used internally by PDF stream decoders when handling FlateDecode filters.
