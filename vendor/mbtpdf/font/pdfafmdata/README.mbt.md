# @bobzhang/mbtpdf/font/pdfafmdata

Compressed AFM data for the 14 standard PDF fonts.

## Overview

This package contains FLATE-compressed Adobe Font Metrics (AFM) data for all 14 standard PDF fonts. The data includes character widths and kerning information needed for text layout calculations.

## Types

### PdfAfmData

AFM data lookup context.

```moonbit nocheck
pub struct PdfAfmData { ... }
pub fn PdfAfmData::new() -> PdfAfmData
```

## Methods

Each function returns the compressed AFM data as a byte array. Decompress with FLATE to get the AFM text.

### Times Family

```moonbit nocheck
pub fn PdfAfmData::times_roman_afm(self : PdfAfmData) -> Array[Byte]
pub fn PdfAfmData::times_bold_afm(self : PdfAfmData) -> Array[Byte]
pub fn PdfAfmData::times_italic_afm(self : PdfAfmData) -> Array[Byte]
pub fn PdfAfmData::times_bold_italic_afm(self : PdfAfmData) -> Array[Byte]
```

### Helvetica Family

```moonbit nocheck
pub fn PdfAfmData::helvetica_afm(self : PdfAfmData) -> Array[Byte]
pub fn PdfAfmData::helvetica_bold_afm(self : PdfAfmData) -> Array[Byte]
pub fn PdfAfmData::helvetica_oblique_afm(self : PdfAfmData) -> Array[Byte]
pub fn PdfAfmData::helvetica_bold_oblique_afm(self : PdfAfmData) -> Array[Byte]
```

### Courier Family

```moonbit nocheck
pub fn PdfAfmData::courier_afm(self : PdfAfmData) -> Array[Byte]
pub fn PdfAfmData::courier_bold_afm(self : PdfAfmData) -> Array[Byte]
pub fn PdfAfmData::courier_oblique_afm(self : PdfAfmData) -> Array[Byte]
pub fn PdfAfmData::courier_bold_oblique_afm(self : PdfAfmData) -> Array[Byte]
```

### Symbol Fonts

```moonbit nocheck
pub fn PdfAfmData::symbol_afm(self : PdfAfmData) -> Array[Byte]
pub fn PdfAfmData::zapf_dingbats_afm(self : PdfAfmData) -> Array[Byte]
```

## Data Format

The compressed data contains standard AFM file content including:
- Font header information (FontName, FullName, etc.)
- Character metrics (width by code and name)
- Kerning pairs for typography
