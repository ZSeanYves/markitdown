# @bobzhang/mbtpdf/font/pdfglyphlist

Glyph name to Unicode mapping tables for PDF text extraction.

## Overview

This package provides the Adobe Glyph List (AGL) mappings that convert PostScript glyph names to Unicode codepoints, plus encoding tables for various PDF standard encodings. These mappings are essential for extracting readable text from PDF documents.

## Types

### PdfGlyphList

Glyph list lookup context.

```moonbit nocheck
pub struct PdfGlyphList { ... }
pub fn PdfGlyphList::new() -> PdfGlyphList
```

## Methods

### PdfGlyphList::glyph_hashes

Get a map from glyph names to Unicode codepoints.

```moonbit nocheck
pub fn PdfGlyphList::glyph_hashes(self : PdfGlyphList) -> Map[String, Array[Int]] raise
```

### PdfGlyphList::reverse_glyph_hashes

Get a map from Unicode codepoints back to glyph names.

```moonbit nocheck
pub fn PdfGlyphList::reverse_glyph_hashes(self : PdfGlyphList) -> Map[Array[Int], String] raise
```

### PdfGlyphList::glyphmap

Get the raw glyph list as an array of (name, codepoints) pairs.

```moonbit nocheck
pub fn PdfGlyphList::glyphmap(self : PdfGlyphList) -> Array[(String, Array[Int])] raise
```

### PdfGlyphList::glyphlist_src

Get the compressed glyph list data (FLATE compressed).

```moonbit nocheck
pub fn PdfGlyphList::glyphlist_src(self : PdfGlyphList) -> Array[Byte]
```

## Encoding Tables

Pre-built arrays mapping glyph names to character codes for standard PDF encodings:

```moonbit nocheck
pub let name_to_pdf : Array[(String, Int)] // PDFDocEncoding
pub let name_to_standard : Array[(String, Int)] // StandardEncoding
pub let name_to_macroman : Array[(String, Int)] // MacRomanEncoding
pub let name_to_win : Array[(String, Int)] // WinAnsiEncoding
pub let name_to_macexpert : Array[(String, Int)] // MacExpertEncoding
pub let name_to_symbol : Array[(String, Int)] // Symbol font encoding
pub let name_to_dingbats : Array[(String, Int)] // ZapfDingbats encoding
```

## Hash Tables

Pre-computed hash tables for fast lookup:

```moonbit nocheck
pub let name_to_pdf_hashes : Map[String, Int]
pub let reverse_name_to_pdf_hashes : Map[Int, String]
```
