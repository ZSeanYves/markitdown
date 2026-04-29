# @bobzhang/mbtpdf/document/pdfpagelabels

Page label handling for PDF documents.

## Overview

This package handles PDF page labels, which define how page numbers are displayed. Page labels support different numbering styles (arabic, roman, letters) and can include prefixes.

## Types

### LabelStyle

Page numbering styles.

```moonbit nocheck
///|
pub(all) enum LabelStyle {
  DecimalArabic // 1, 2, 3, ...
  UppercaseRoman // I, II, III, ...
  LowercaseRoman // i, ii, iii, ...
  UppercaseLetters // A, B, C, ...
  LowercaseLetters // a, b, c, ...
  NoLabelPrefixOnly // Prefix only, no number
}
```

### PageLabel

A page label definition.

```moonbit nocheck
///|
pub(all) struct PageLabel {
  labelstyle : LabelStyle
  labelprefix : String?
  startpage : Int
  startvalue : Int
}
```

- `labelprefix`: Optional prefix (e.g., "Chapter ")
- `startpage`: First page this label applies to
- `startvalue`: Starting number value

## Variables

### basic_label

Default page label starting at page 1 with decimal arabic numbering.

```moonbit nocheck
pub let basic_label : PageLabel
```

## Types

### PdfPageLabels

Page label utility context.

```moonbit nocheck
pub struct PdfPageLabels { ... }
pub fn PdfPageLabels::new() -> PdfPageLabels
```

## Methods

### PageLabel::read_all

Read page labels from a document.

```moonbit nocheck
pub fn PageLabel::read_all(pdf : @pdf.Pdf) -> Array[PageLabel] raise
```

### PageLabel::write_all

Write page labels to a document, replacing any existing labels.

```moonbit nocheck
pub fn PageLabel::write_all(labels : Array[PageLabel], pdf : @pdf.Pdf) -> Unit raise
```

### PageLabel::remove_all

Remove all page labels from a document.

```moonbit nocheck
pub fn PageLabel::remove_all(pdf : @pdf.Pdf) -> Unit raise
```

### PdfPageLabels::complete

Ensure the label array covers all pages (adds a default label at page 1 if needed).

```moonbit nocheck
pub fn PdfPageLabels::complete(
  self : PdfPageLabels,
  labels : Array[PageLabel]
) -> Array[PageLabel]
```

### PdfPageLabels::coalesce

Optimize page labels by removing redundant entries.

```moonbit nocheck
pub fn PdfPageLabels::coalesce(
  self : PdfPageLabels,
  labels : Array[PageLabel]
) -> Array[PageLabel]
```

### PdfPageLabels::pagelabeltext_of_pagenumber

Get the display text for a specific page number.

```moonbit nocheck
pub fn PdfPageLabels::pagelabeltext_of_pagenumber(
  self : PdfPageLabels,
  n : Int,
  labels : Array[PageLabel]
) -> String raise
```

### PdfPageLabels::pagelabel_of_pagenumber

Get the page label definition for a specific page.

```moonbit nocheck
pub fn PdfPageLabels::pagelabel_of_pagenumber(
  self : PdfPageLabels,
  n : Int,
  labels : Array[PageLabel]
) -> PageLabel raise
```

### PdfPageLabels::add_label

Add a label range, properly handling overlaps with existing labels.

```moonbit nocheck
pub fn PdfPageLabels::add_label(
  self : PdfPageLabels,
  endpage : Int,
  labels : Array[PageLabel],
  label : PageLabel,
  range_end : Int
) -> Array[PageLabel]
```

### PdfPageLabels::merge_pagelabels

Merge page labels when combining multiple PDFs.

```moonbit nocheck
pub fn PdfPageLabels::merge_pagelabels(
  self : PdfPageLabels,
  pdfs : Array[@pdf.Pdf],
  ranges : Array[Array[Int]]
) -> Array[PageLabel] raise
```

### LabelStyle::to_string / PageLabel::to_string

Debug string representations.
