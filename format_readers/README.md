# Format Readers

`format_readers/` owns low-level source-format understanding and preparation. Its job is to read raw files into stable intermediate models and then hand those results to `formats/*` so they can join the product-level parser contract.

## Responsibilities

- Read raw text, container, and package formats
- Build stable format-private source models or prepared documents
- Isolate low-level zip, OOXML, ODF, PDF, HTML, XML, YAML, and similar reader details

## Main Subtrees

- `source_io/`
  Shared source reading helpers
- `zip/`, `zip_source/`
  Zip decoding, security checks, and archive preparation
- `pdf/`
  Native PDF reading, text restoration, font handling, and geometry models
- `ooxml/`
  Office container, relationship, content-type, and DOCX/PPTX/XLSX preparation
- `odf/`
  ODT/ODS/ODP compatibility and prepared wrappers
- `epub/`
  EPUB package, navigation, cover, and spine preparation
- `html/`, `xml/`, `markdown/`, `json/`, `yaml/`, `toml/`, `txt/`
  Tokenizers, parsers, inspectors, and prepare entry points for text-based formats
- `text_markup/`
  Shared parsing infrastructure for TeX, RST, and AsciiDoc

## Key Types And Functions

- `Prepared*` families
  Intermediate results that are ready for upper-layer format parsers
- `SourceCursor` consumers
  Seekable PDF/ZIP/package readers use bounded `read_at` access and avoid
  materializing the complete input when their format permits indexed reads
- `prepare_*_from_source`
  The standard preparation entry points from `InputSource`
- `inspect_*`
  Stable, human-readable inspection helpers for debugging and regression work

## Maintenance Rules

- Readers should focus on understanding raw source formats correctly; upper-layer parsers decide how those results enter the unified product path
- New low-level logic should be added to the matching reader subtree instead of being pushed up into `formats/*`
- Keep `Prepared*` field semantics stable because upper-layer lowering and snapshot tests depend on them
- Package readers must enforce compressed/decompressed size, entry count,
  range, and transient payload budgets before returning source models

## Validation

```bash
moon test
```
