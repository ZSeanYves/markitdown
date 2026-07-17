# OOXML Readers

`format_readers/ooxml/` handles OOXML container reading and Office source-model preparation. It is the low-level input layer for DOCX, PPTX, and XLSX parsers.

## Responsibilities

- Read parts, relationships, and content types from zip-based OOXML packages
- Perform safety validation for OOXML paths, relationships, and external references
- Build reusable prepared or source models for DOCX, PPTX, and XLSX
- Expose debuggable package inventory and inspection output

## Main Subtrees

- `package/`
  OOXML package handling, part cache, relationships, content types, validation, and assets
- `shared/`
  Shared Office models, constructors, and cross-document constraints
- `docx/`
  Body, inline, auxiliary-part, and source-model parsing
- `pptx/`
  Presentation, slide, shape, table, media, and notes/comments parsing
- `xlsx/`
  Spreadsheet preparation entry points

## Key Types And Functions

- `OoxmlPackage` / `OoxmlPackageInventory`
  The unified representation of an OOXML container and its readable inventory
- `OoxmlRelationship`, `OoxmlContentTypeInfo`
  Core package relationship and content-type routing structures
- `prepare_*_from_source`
  Preparation entry points for Office formats from `InputSource`
- `inspect_ooxml_inventory`
  A stable inventory view for tests and debugging

OOXML packages are opened through the shared seekable ZIP reader. XML parts may
be read transiently; media payloads are materialized only after per-asset and
total Office budgets are reserved. External relationships remain metadata and
never become implicit network or filesystem reads.

## Maintenance Rules

- Shared container logic should converge in `package/` and `shared/` instead of being reimplemented in DOCX/PPTX/XLSX subtrees
- New Office semantic extensions should clearly separate package-level information from document-level information
- External relationships, dangerous paths, and unsafe resource references should continue to fail closed

## Validation

```bash
moon test
```
