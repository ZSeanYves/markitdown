# pdfmerge

Merge multiple PDF documents into one.

## Overview

The `pdfmerge` package provides functionality to:

- Combine multiple PDF documents
- Merge selected page ranges
- Handle bookmarks, named destinations, and form fields
- Remove duplicate fonts for optimization

## Basic Merge

### Merge All Pages

```mbt nocheck
///|
let merged = @pdfmerge.PdfMerger::new(
  ["doc1.pdf", "doc2.pdf"], // source names
  [pdf1, pdf2], // PDF documents
  [ilist(1, pages1), ilist(1, pages2)], // page ranges
).merge_pdfs(
  false, // retain_numbering
   false, // remove_duplicate_fonts
)
```

### Merge with Options

```mbt nocheck
///|
let merged = @pdfmerge.PdfMerger::new(names~, pdfs~, ranges~).merge_pdfs(
  true, // retain_numbering - keep original page labels
  true, // remove_duplicate_fonts
  process_struct_trees=true, // process accessibility trees
  add_toplevel_document=false, // add document-level bookmarks
)
```

## Page Ranges

Page ranges are 1-indexed arrays:

```mbt nocheck
// All pages from document with 10 pages

///|
let all_pages = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

// First 3 pages

///|
let first_three = [1, 2, 3]

// Pages in reverse order

///|
let reversed = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]

// Specific pages

///|
let selection = [1, 3, 5, 7, 9]
```

## Font Optimization

Remove duplicate embedded fonts to reduce file size:

```mbt nocheck
@pdfmerge.PdfMergeDoc::new(pdf).remove_duplicate_fonts()
```

This compares font streams and removes duplicates, updating all references.

## What Gets Merged

The merge operation handles:

### Page Content
- Page objects and content streams
- Resources (fonts, images, color spaces)
- MediaBox, CropBox, and other page boxes

### Document Structure
- Bookmarks/outlines with correct page references
- Named destinations
- Page labels (optional)
- Document information dictionary

### Interactive Elements
- AcroForm fields
- Annotations with proper page links
- Optional content groups (layers)

### Metadata
- PDF version (uses maximum of inputs)
- Document catalog items
- Structure trees (accessibility)

## Example: Merge Two Documents

```mbt nocheck
///|
async fn merge_two_files(
  file1 : String,
  file2 : String,
  output : String,
) -> Unit {
  let pdf1 = @pdfreadfs.PdfReadFs::new().pdf_of_file(
    user_password=None,
    owner_password=None,
    filename=file1,
  )
  let pdf2 = @pdfreadfs.PdfReadFs::new().pdf_of_file(
    user_password=None,
    owner_password=None,
    filename=file2,
  )
  let pages1 = @pdfpage.PdfPageDoc::new(pdf1).endpage_fast()
  let pages2 = @pdfpage.PdfPageDoc::new(pdf2).endpage_fast()
  let merged = @pdfmerge.PdfMerger::new([file1, file2], [pdf1, pdf2], [
    ilist(1, pages1),
    ilist(1, pages2),
  ]).merge_pdfs(false, true)
  @pdfwritefs.PdfWriteFs::new().pdf_to_file(merged, output)
}
```

## Example: Interleave Pages

```mbt nocheck
// Merge odd pages from doc1, even pages from doc2

///|
let merged = @pdfmerge.PdfMerger::new(
  ["odd.pdf", "even.pdf"],
  [odd_pdf, even_pdf],
  [[1, 3, 5, 7, 9], [2, 4, 6, 8, 10]],
).merge_pdfs(false, false)
```

## PdfMerger

Construct a merge context from inputs.

```mbt nocheck
pub struct PdfMerger { ... }
pub fn PdfMerger::new(
  names : Array[String],
  pdfs : Array[@pdf.Pdf],
  ranges : Array[Array[Int]]
) -> PdfMerger
```

## PdfMergeDoc

Document-level utilities for merged PDFs.

```mbt nocheck
pub struct PdfMergeDoc { ... }
pub fn PdfMergeDoc::new(pdf : @pdf.Pdf) -> PdfMergeDoc
```

## Parameters

### retain_numbering
When `true`, preserves the original page labels from source documents. When `false`, pages are numbered sequentially.

### do_remove_duplicate_fonts
When `true`, scans for identical font streams and removes duplicates. Can significantly reduce file size when merging documents that use the same fonts.

### process_struct_trees
When `true`, processes PDF/UA structure trees for accessibility. Set to `false` for faster merging if accessibility is not needed.

### add_toplevel_document
When `true`, adds top-level bookmark entries for each source document.

### names
Array of source document names (used for bookmark generation). Provided to `PdfMerger::new`.

### pdfs
Array of `Pdf` documents to merge. Provided to `PdfMerger::new`.

### ranges
Array of page ranges, one per input document. Each range is an array of 1-indexed page numbers. Provided to `PdfMerger::new`.
