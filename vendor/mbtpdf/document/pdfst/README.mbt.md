# @bobzhang/mbtpdf/document/pdfst

PDF structure tree operations for tagged PDFs.

## Overview

This package handles the structure tree in tagged PDF documents. Tagged PDFs contain semantic structure information that maps content to logical document elements (paragraphs, headings, tables, etc.), enabling accessibility features and content reflow.

## PdfStructTree

Construct a structure-tree context bound to a specific `Pdf`.

```moonbit nocheck
pub struct PdfStructTree { ... }
pub fn PdfStructTree::new(pdf : @pdf.Pdf) -> PdfStructTree
```

## PdfStructTrees

Batch context for operations across multiple PDFs.

```moonbit nocheck
pub struct PdfStructTrees { ... }
pub fn PdfStructTrees::new(pdfs : Array[@pdf.Pdf]) -> PdfStructTrees
```

## Methods

### PdfStructTree::trim_structure_tree

Remove structure tree entries for pages not in the specified range.

```moonbit nocheck
pub fn PdfStructTree::trim_structure_tree(
  self : PdfStructTree,
  range : Array[Int]
) -> Unit raise
```

### PdfStructTrees::renumber_parent_trees

Renumber /ParentTree entries when merging multiple PDFs. Updates /StructParent and /StructParents references to maintain consistency.

```moonbit nocheck
pub fn PdfStructTrees::renumber_parent_trees(self : PdfStructTrees) -> Unit raise
```

### PdfStructTree::merge_structure_trees

Merge structure trees from multiple PDFs into a single document.

```moonbit nocheck
pub fn PdfStructTree::merge_structure_trees(
  self : PdfStructTree,
  pdfs : Array[@pdf.Pdf],
  add_toplevel_document? : Bool
) -> Int? raise
```

- `add_toplevel_document`: Wrap in /Document element (default: false)
- Returns the merged StructTreeRoot object number

## Notes

This package computes page counts directly via `@pdfpage.PdfPageDoc` (no global
cross-package hooks).

## Tagged PDF Structure

A structure tree contains:
- **/StructTreeRoot**: Root of the structure hierarchy
- **/K**: Children (structure elements)
- **/ParentTree**: Maps marked content to structure elements
- **/IDTree**: Maps element IDs to structure elements
- **/RoleMap**: Custom element type mappings
- **/ClassMap**: Attribute class definitions
