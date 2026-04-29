# @bobzhang/mbtpdf/document/pdfocg

Optional Content Groups (layers) for PDF documents.

## Overview

This package handles Optional Content Groups (OCGs), which allow PDF content to be selectively shown or hidden. OCGs are commonly used for layers in technical drawings, multilingual documents, or print/screen variations.

## Types

### PdfOcg

Optional content group context.

```moonbit nocheck
pub struct PdfOcg { ... }
pub fn PdfOcg::new(pdf : @pdf.Pdf) -> PdfOcg
```

### Ocg

An Optional Content Group definition.

```moonbit nocheck
///|
pub(all) struct Ocg {
  ocg_name : String
  ocg_intent : Array[String]
  ocg_usage : OcgUsage?
}
```

- `ocg_name`: Display name
- `ocg_intent`: Intent (e.g., "/View", "/Design")

### OcgState

Visibility state for an OCG.

```moonbit nocheck
///|
pub(all) enum OcgState {
  On // Visible
  Off // Hidden
  Unchanged // Preserve current state
}
```

### OcgConfig

Configuration for OCG visibility.

```moonbit nocheck
///|
pub(all) struct OcgConfig {
  ocgconfig_name : String?
  ocgconfig_creator : String?
  ocgconfig_basestate : OcgState
  ocgconfig_on : Array[Int]?
  ocgconfig_off : Array[Int]?
  ocgconfig_intent : Array[String]
  ocgconfig_listmode : OcgListMode
  ocgconfig_rbgroups : Array[Array[Int]]
  ocgconfig_locked : Array[Int]
  // ...
}
```

### OcgProperties

Complete OCG properties for a document.

```moonbit nocheck
///|
pub(all) struct OcgProperties {
  ocgs : Array[(Int, Ocg)]
  ocg_default_config : OcgConfig
  ocg_configs : Array[OcgConfig]
}
```

## Methods

### read_ocg

Read optional content data from a document.

```moonbit nocheck
pub fn OcgProperties::read(pdf : @pdf.Pdf) -> OcgProperties? raise
```

### write_ocg

Write optional content data to a document (placeholder).

```moonbit nocheck
pub fn OcgProperties::write(self : OcgProperties, pdf : @pdf.Pdf) -> Unit
```

### PdfOcg::print_document

Print OCG information for debugging.

```moonbit nocheck
pub fn PdfOcg::print_document(self : PdfOcg) -> Unit raise
```
