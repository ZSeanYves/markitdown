# @bobzhang/mbtpdf/graphics/pdfspace

PDF color space handling.

## Overview

This package parses and represents PDF color spaces, which define how color values are interpreted. It supports all standard PDF color spaces including device colors, calibrated colors, ICC profiles, and special spaces like indexed and separation.

## Types

### Point

Tristimulus color value (X, Y, Z or similar).

```moonbit nocheck
///|
pub type Point = (Double, Double, Double)
```

### ColourSpace

All PDF color space variants.

```moonbit nocheck
///|
pub(all) enum ColourSpace {
  DeviceGray
  DeviceRGB
  DeviceCMYK
  CalGray(Point, Point, Double)
  CalRGB(Point, Point, Array[Double], Array[Double])
  Lab(Point, Point, Array[Double])
  ICCBased(ICCBased)
  Indexed(ColourSpace, Map[Int, Array[Int]])
  Pattern
  PatternWithBaseColourspace(ColourSpace)
  Separation(String, ColourSpace, @pdffun.PdfFunction)
  DeviceN(Array[String], ColourSpace, @pdffun.PdfFunction, @pdf.PdfObject)
}
```

- `DeviceGray`: Grayscale
- `DeviceRGB`: RGB
- `DeviceCMYK`: CMYK
- `CalGray`: Calibrated gray (whitepoint, blackpoint, gamma)
- `CalRGB`: Calibrated RGB (whitepoint, blackpoint, gamma, matrix)
- `Lab`: CIE L\*a\*b\* (whitepoint, blackpoint, range)
- `ICCBased`: ICC profile-based
- `Indexed`: Palette/indexed colors
- `Pattern`: Pattern space
- `PatternWithBaseColourspace`: Pattern with underlying colorspace
- `Separation`: Spot color
- `DeviceN`: Multi-colorant

### ICCBased

ICC profile color space details.

```moonbit nocheck
///|
pub(all) struct ICCBased {
  icc_n : Int
  icc_alternate : ColourSpace
  icc_range : Array[Double]
  icc_metadata : @pdf.PdfObject?
  icc_stream : @pdf.PdfObject
}
```

- `icc_n`: Number of components
- `icc_alternate`: Alternate color space
- `icc_range`: Component ranges
- `icc_metadata`: Optional metadata
- `icc_stream`: ICC profile stream

## Functions

### ColourSpace::read

Parse a color space from a PDF object.

```moonbit nocheck
pub fn ColourSpace::read(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  obj : @pdf.PdfObject
) -> ColourSpace raise
```

- `resources`: Page resources dictionary
- `obj`: Color space specification

### ColourSpace::to_pdf_object

Convert a color space back to a PDF object.

```moonbit nocheck
pub fn ColourSpace::to_pdf_object(self : ColourSpace, pdf : @pdf.Pdf) -> @pdf.PdfObject
```

### ColourSpace::to_string

Get a debug string for a color space.

```moonbit nocheck
pub fn ColourSpace::to_string(self : ColourSpace) -> String
```

### ColourSpace::name

Get the name of a color space (for Separation colors).

```moonbit nocheck
pub fn ColourSpace::name(self : ColourSpace) -> String?
```

## Color Space Components

| Color Space | Components |
|------------|-----------|
| DeviceGray | 1 (gray) |
| DeviceRGB | 3 (R, G, B) |
| DeviceCMYK | 4 (C, M, Y, K) |
| CalGray | 1 |
| CalRGB | 3 |
| Lab | 3 (L*, a*, b*) |
| ICCBased | N (defined by profile) |
| Indexed | 1 (index into palette) |
| Separation | 1 (tint) |
| DeviceN | N (tints) |
