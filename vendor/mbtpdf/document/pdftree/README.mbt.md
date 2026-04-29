# @bobzhang/mbtpdf/document/pdftree

Name tree and number tree operations for PDF documents.

## Overview

This package handles PDF name trees and number trees, which are balanced tree structures used to efficiently store key-value mappings. Name trees use string keys (e.g., named destinations, embedded files), while number trees use integer keys (e.g., page labels, structure parent tree).

## PdfTree

Construct a tree context bound to a specific `Pdf`.

```moonbit nocheck
pub struct PdfTree { ... }
pub fn PdfTree::new(pdf : @pdf.Pdf) -> PdfTree
```

## Methods

### PdfTree::read_name_tree

Read a name tree as a flat array of (key, value) pairs.

```moonbit nocheck
pub fn PdfTree::read_name_tree(
  self : PdfTree,
  tree : @pdf.PdfObject
) -> Array[(String, @pdf.PdfObject)]
```

### PdfTree::read_number_tree

Read a number tree as a flat array of (key, value) pairs. Keys are returned as strings for uniformity.

```moonbit nocheck
pub fn PdfTree::read_number_tree(
  self : PdfTree,
  tree : @pdf.PdfObject
) -> Array[(String, @pdf.PdfObject)]
```

### PdfTree::build_name_tree

Build a name or number tree from a flat array of entries.

```moonbit nocheck
pub fn PdfTree::build_name_tree(
  self : PdfTree,
  isnum : Bool,
  entries : Array[(String, @pdf.PdfObject)]
) -> @pdf.PdfObject
```

- `isnum`: true for number tree, false for name tree

### PdfTree::merge_name_trees_no_clash

Merge multiple name trees assuming no duplicate keys.

```moonbit nocheck
pub fn PdfTree::merge_name_trees_no_clash(
  self : PdfTree,
  trees : Array[@pdf.PdfObject]
) -> @pdf.PdfObject
```

### PdfTree::merge_number_trees_no_clash

Merge multiple number trees assuming no duplicate keys.

```moonbit nocheck
pub fn PdfTree::merge_number_trees_no_clash(
  self : PdfTree,
  trees : Array[@pdf.PdfObject]
) -> @pdf.PdfObject
```

## Tree Structure

PDF trees consist of:
- **Root node**: Contains /Names or /Nums array, or /Kids for intermediate nodes
- **Intermediate nodes**: /Kids array pointing to child nodes, /Limits for key range
- **Leaf nodes**: /Names or /Nums array with key-value pairs

The implementation automatically balances trees with a maximum of 10 entries per leaf node.
