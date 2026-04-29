# @bobzhang/mbtpdf/document/pdfmarks

PDF bookmarks (document outline) reading and writing.

## Overview

This package handles PDF bookmarks (also known as outlines), which provide a hierarchical table of contents for PDF documents. It supports reading, writing, and transforming bookmarks.

## Types

### Bookmark

A single bookmark entry in the document outline.

```moonbit nocheck
///|
pub(all) struct Bookmark {
  level : Int
  text : String
  target : @pdfdest.Destination
  isopen : Bool
  colour : (Double, Double, Double)
  flags : Int
}
```

- `level`: Nesting level (0 = top level)
- `colour`: RGB color (0.0-1.0)
- `flags`: Style flags (bit 0 = italic, bit 1 = bold)

## PdfMarks

Construct a bookmarks context bound to a specific `Pdf`.

```moonbit nocheck
pub struct PdfMarks { ... }
pub fn PdfMarks::new(pdf : @pdf.Pdf) -> PdfMarks
```

## Methods

### PdfMarks::read_bookmarks

Read all bookmarks from a PDF document.

```moonbit nocheck
pub fn PdfMarks::read_bookmarks(
  self : PdfMarks,
  preserve_actions? : Bool
) -> Array[Bookmark] raise
```

- `preserve_actions`: Keep action dictionaries as-is (default: false)

### PdfMarks::add_bookmarks

Add bookmarks to a document, replacing any existing bookmarks.

```moonbit nocheck
pub fn PdfMarks::add_bookmarks(
  self : PdfMarks,
  parsed : Array[Bookmark]
) -> @pdf.Pdf raise
```

### PdfMarks::remove_bookmarks

Remove all bookmarks from the document.

```moonbit nocheck
pub fn PdfMarks::remove_bookmarks(self : PdfMarks) -> @pdf.Pdf raise
```

### Bookmark::transform

Apply a transformation matrix to a bookmark's destination coordinates.

```moonbit nocheck
pub fn Bookmark::transform(
  self : Bookmark,
  pdf : @pdf.Pdf,
  tr : @pdftransform.TransformMatrix
) -> Bookmark raise
```

### Bookmark::to_string

Pretty-print a bookmark for debugging.

```moonbit nocheck
pub fn Bookmark::to_string(self : Bookmark) -> String
```
