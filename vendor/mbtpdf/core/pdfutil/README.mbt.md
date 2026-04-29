# @bobzhang/mbtpdf/core/pdfutil

Small utility helpers used across the PDF library.

## Overview

This package provides general-purpose utility functions for output buffering, memoization, and hash table operations used throughout the PDF processing modules.

## PdfUtil

Construct a utility context that uses shared stdout/stderr buffers.

```moonbit nocheck
pub struct PdfUtil { ... }
pub fn PdfUtil::new() -> PdfUtil
```

## Values

### quiet

When `true`, `PdfUtil::flprint` / `PdfUtil::fleprint` are suppressed (useful for keeping tests quiet).

```moonbit nocheck
pub let quiet : Ref[Bool]
```

## Methods

### PdfUtil::flprint

Print a message to stdout with line-buffered flushing.

```moonbit nocheck
pub fn PdfUtil::flprint(self : PdfUtil, message : String) -> Unit
```

### PdfUtil::fleprint

Print a message to stderr with line-buffered flushing.

```moonbit nocheck
pub fn PdfUtil::fleprint(self : PdfUtil, message : String) -> Unit
```

### PdfUtil::memoize

Memoize a nullary function, caching the first computed value for subsequent calls.

```moonbit nocheck
pub fn PdfUtil::memoize[T](self : PdfUtil, f : () -> T raise) -> (() -> T raise)
```

### PdfUtil::hashtable_of_dictionary

Build a hash map from an array of key/value pairs.

```moonbit nocheck
pub fn PdfUtil::hashtable_of_dictionary[K : Hash + Eq, V](
  self : PdfUtil,
  pairs : Array[(K, V)]
) -> Map[K, V]
```

### PdfUtil::null_hash

Construct an empty hash table.

```moonbit nocheck
pub fn PdfUtil::null_hash[K, V](self : PdfUtil) -> Map[K, V]
```

### PdfUtil::list_of_hashtbl

Extract all key/value pairs from a hash table as an array.

```moonbit nocheck
pub fn PdfUtil::list_of_hashtbl[K, V](
  self : PdfUtil,
  table : Map[K, V]
) -> Array[(K, V)]
```
