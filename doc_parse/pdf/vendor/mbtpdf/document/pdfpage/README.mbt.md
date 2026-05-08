# pdfpage

Page manipulation for PDF documents.

## Overview

The `pdfpage` package provides operations for:

- Reading page trees and extracting pages
- Creating new pages and page trees
- Manipulating page content operators
- Combining and transforming pages
- Resource management and prefix handling

## Core Types

### Page

Represents a single PDF page:

```mbt nocheck
///|
pub(all) struct Page {
  content : @pdf.PdfObject // Page content stream
  mediabox : @pdf.PdfObject // Page dimensions
  resources : @pdf.PdfObject // Font, color, etc. resources
  rotate : Rotation // Page rotation
  rest : @pdf.PdfObject // Other page attributes
}
```

### Rotation

```mbt nocheck
///|
pub(all) enum Rotation {
  Rotate0
  Rotate90
  Rotate180
  Rotate270
}
```

## PdfPageDoc

Construct a page context bound to a specific `Pdf`.

```mbt nocheck
pub struct PdfPageDoc { ... }
pub fn PdfPageDoc::new(pdf : @pdf.Pdf) -> PdfPageDoc
```

## Reading Pages

### Extract All Pages

```mbt nocheck
let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
for i, page in pages {
  println("Page \{i + 1}: \{page.mediabox}")
}
```

### Count Pages (Fast)

```mbt nocheck
// Fast count without parsing all pages

///|
let count = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree_quick()
```

### Last Page Number

```mbt nocheck
///|
let lastpage = @pdfpage.PdfPageDoc::new(pdf).endpage()
// Or the faster variant

///|
let lastpage = @pdfpage.PdfPageDoc::new(pdf).endpage_fast()
```

## Creating Pages

### Blank Page

```mbt nocheck
// Create blank A4 page

///|
let page = @pdfpage.Page::blank(@pdfpaper.Paper::A4Portrait)
```

### Custom Page

```mbt nocheck
// Create page with custom dimensions

///|
let rect = @pdf.PdfObject::Array([
  @pdf.PdfObject::Real(0.0),
  @pdf.PdfObject::Real(0.0),
  @pdf.PdfObject::Real(612.0),
  @pdf.PdfObject::Real(792.0),
])

///|
let page = @pdfpage.Page::custom(rect)
```

### Minimum Valid PDF

```mbt nocheck
// Create minimal valid PDF document

///|
let pdf = @pdfpage.PdfPageDoc::minimum_valid()
```

## Building Page Trees

### Add Pages to PDF

```mbt nocheck
let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(pdf).add_pagetree(pages)
let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])
```

### Extract Pages by Range

```mbt nocheck
// Extract pages 1-5 from document

///|
let range = [1, 2, 3, 4, 5]

///|
let new_pdf = @pdfpage.PdfPageDoc::new(basepdf).pdf_of_pages(range)

// With structure tree processing

///|
let new_pdf = @pdfpage.PdfPageDoc::new(basepdf).pdf_of_pages(
  range,
  retain_numbering=true,
  process_struct_tree=true,
)
```

## Content Manipulation

### Prepend Operators

```mbt nocheck
// Add operators before page content

///|
let modified_page = page.prepend_operators(pdf, ops)
```

### Append Operators

```mbt nocheck
// Add operators after page content

///|
let modified_page = page.postpend_operators(pdf, ops)
```

### Protect Content

Wrap operators in save/restore:

```mbt nocheck
///|
let protected_ops = @pdfpage.protect(ops)
// Results in: q ... Q
```

## Page Tree Manipulation

### Change Pages

Replace pages in a document:

```mbt nocheck
///|
let new_pdf = @pdfpage.PdfPageDoc::new(basepdf).change_pages(
  true, // Change references
   new_pages,
)
```

### Renumber Resources

Avoid name collisions when combining pages:

```mbt nocheck
///|
let renumbered = @pdfpage.PdfPageDoc::new(pdf).renumber_pages(pages)
```

## Resource Handling

### Add Prefix

Add prefix to all resource names to avoid collisions:

```mbt nocheck
@pdfpage.PdfPageDoc::new(pdf).add_prefix("P1_")
```

### Shortest Unused Prefix

Find shortest available prefix:

```mbt nocheck
///|
let prefix = @pdfpage.PdfPageDoc::new(pdf).shortest_unused_prefix()
```

### Combine Resources

```mbt nocheck
///|
let combined = @pdfpage.PdfPageDoc::new(pdf).combine_pdf_resources(
  resources_a, resources_b,
)
```

## XObject Processing

### Process XObjects

Apply function to all XObjects on a page:

```mbt nocheck
page.process_xobjects!(pdf, fn(pdf, resources, ops) {
  // Transform content
  ops
})
```

## Fixups

### Fix Duplicate Pages

```mbt nocheck
@pdfpage.PdfPageDoc::new(pdf).fixup_duplicate_pages()
```

### Fix Parent References

```mbt nocheck
@pdfpage.PdfPageDoc::new(pdf).fixup_parents()
```

### Fix Duplicate Annotations

```mbt nocheck
@pdfpage.PdfPageDoc::new(pdf).fixup_duplicate_annots()
```

### Fix Destinations

```mbt nocheck
@pdfpage.PdfPageDoc::new(pdf).fixup_destinations()
```

## Navigation

### Page Number from Destination

```mbt nocheck
///|
let pagenum = @pdfpage.PdfPageDoc::new(pdf).pagenumber_of_target(destination)
```

### Destination from Page Number

```mbt nocheck
///|
let dest = @pdfpage.PdfPageDoc::new(pdf).target_of_pagenumber(1)
```

### Page Object Number

```mbt nocheck
///|
let objnum = @pdfpage.PdfPageDoc::new(pdf).page_object_number(1)
```

## Rotation Utilities

```mbt check
///|
test "rotation conversions" {
  inspect(@pdfpage.Rotation::Rotate90.to_int(), content="90")
  guard @pdfpage.Rotation::from_int(180) is Rotate180 else {
    fail("expected Rotate180")
  }
}
```
