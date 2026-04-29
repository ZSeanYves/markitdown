# pdfpaper

Standard paper sizes for PDF documents.

## Overview

The `pdfpaper` package provides predefined paper sizes in standard formats (ISO A-series, US Letter/Legal) with support for portrait and landscape orientations.

## Paper Struct

```mbt nocheck
///|
pub struct Paper {
  unit : @pdfunits.LengthUnit
  width : Double
  height : Double
}
```

## Predefined Sizes

### ISO A-Series

```mbt nocheck
@pdfpaper.a0   // 841 x 1189 mm
@pdfpaper.a1   // 594 x 841 mm
@pdfpaper.a2   // 420 x 594 mm
@pdfpaper.a3   // 297 x 420 mm
@pdfpaper.a4   // 210 x 297 mm (most common)
@pdfpaper.a5   // 148 x 210 mm
@pdfpaper.a6   // 105 x 148 mm
@pdfpaper.a7   // 74 x 105 mm
@pdfpaper.a8   // 52 x 74 mm
@pdfpaper.a9   // 37 x 52 mm
@pdfpaper.a10  // 26 x 37 mm
```

### US Sizes

```mbt nocheck
@pdfpaper.usletter  // 8.5 x 11 inches
@pdfpaper.uslegal   // 8.5 x 14 inches
```

## Orientation

### Landscape

Convert any paper to landscape orientation:

```mbt check
///|
test "landscape swaps dimensions" {
  let portrait = @pdfpaper.a4
  let landscape = portrait.landscape()
  // Width and height are swapped
  assert_true(landscape.width() > landscape.height())
}
```

## Accessors

```mbt check
///|
test "paper accessors" {
  let paper = @pdfpaper.a4
  // Get unit (millimeters for ISO sizes)
  let u = paper.unit()
  match u {
    @pdfunits.LengthUnit::Millimetre => ()
    _ => fail("expected millimetre unit")
  }
  // Get dimensions
  let w = paper.width()
  let h = paper.height()
  assert_true(w < h) // Portrait
  debug_inspect((u, w, h), content="(Millimetre, 210, 297)")
}
```

## Creating Custom Sizes

```mbt nocheck
///|
let custom = @pdfpaper.Paper::new(
  @pdfunits.LengthUnit::Inch,
  8.5, // width
  11.0, // height
)
```

## Usage with Pages

```mbt nocheck
// Create blank page with A4 size

///|
let page = @pdfpage.Page::blank(@pdfpaper.a4)

// Get rectangle for paper

///|
let rect = @pdfpaper.usletter.rectangle()
```
