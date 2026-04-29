# @bobzhang/mbtpdf/font/pdfafm

Adobe Font Metrics (AFM) file parser.

## Overview

This package parses AFM files, which contain font metrics information including character widths, kerning pairs, and font properties. AFM data is used for the 14 standard PDF fonts.

## Types

### PdfAfm

AFM parsing context.

```moonbit nocheck
pub struct PdfAfm { ... }
pub fn PdfAfm::new() -> PdfAfm
```

## Methods

### PdfAfm::read

Parse an AFM file from an input stream.

```moonbit nocheck
pub fn PdfAfm::read(self : PdfAfm, input : @pdfio.Input) -> (
  Array[(String, String)], // Header key-value pairs
  Array[(Int, Int)], // Character code to width mappings
  Array[(Int, Int, Int)], // Kerning: (char1, char2, adjustment)
  Array[(String, Int)] // Glyph name to width mappings
) raise
```

## AFM File Format

AFM files contain:
- **Headers**: Font metadata (FontName, FullName, FamilyName, etc.)
- **CharMetrics**: Character widths indexed by character code (C) and name (N)
- **KernPairs**: Kerning adjustments between character pairs

## Usage

This package is typically used internally by `pdfstandard14` to load metrics for standard fonts.
