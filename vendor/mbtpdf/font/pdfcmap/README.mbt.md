# @bobzhang/mbtpdf/font/pdfcmap

ToUnicode CMap parser for PDF text extraction.

## Overview

This package parses /ToUnicode CMap streams that map character codes to Unicode values. ToUnicode CMaps are essential for extracting readable text from PDF documents, especially those using CID fonts or custom encodings.

## Types

### CMap

Parsed CMap data.

```moonbit nocheck
///|
pub struct CMap {
  map : Array[(String, String)]
  wmode : Int?
}
```

- `map`: (character code, Unicode value) pairs
- `wmode`: Writing mode (0=horizontal, 1=vertical)

## Methods

### CMap::parse

Parse a /ToUnicode CMap stream.

```moonbit nocheck
pub fn CMap::parse(pdf : @pdf.Pdf, cmap : @pdf.PdfObject) -> CMap raise
```

## CMap Format

ToUnicode CMaps contain:

**bfchar sections** - Map individual character codes to Unicode values:
```
beginbfchar
<0041> <0041>
<0042> <0042>
endbfchar
```

**bfrange sections** - Map ranges of character codes:
```
beginbfrange
<0000> <005E> <0020>
<005F> <0061> [<00660069> <0066006C> <00660066>]
endbfrange
```

## Usage

ToUnicode CMaps are automatically used by `pdftext` for text extraction.
