# @bobzhang/mbtpdf/codec/pdfjpeg

JPEG data extraction helpers for PDF streams.

## Overview

This package provides utilities for extracting JPEG image data from PDF streams. PDF documents often embed JPEG images directly in content streams using the DCTDecode filter.

## Types

### PdfJpeg

JPEG extraction context.

```moonbit nocheck
pub struct PdfJpeg { ... }
pub fn PdfJpeg::new() -> PdfJpeg
```

## Methods

### PdfJpeg::get_jpeg_data

Read JPEG data from an input stream, scanning for the JPEG end-of-image marker (FFD9).

```moonbit nocheck
pub fn PdfJpeg::get_jpeg_data(
  self : PdfJpeg,
  input : @pdfio.Input
) -> @pdfio.MutableBytes raise
```

The function:
1. Reads bytes from the input stream
2. Scans for the JPEG EOI marker (0xFF 0xD9)
3. Returns all bytes up to and including the marker
4. Leaves the input positioned after the JPEG data

This is used when extracting embedded JPEG images from PDF documents.
