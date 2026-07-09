# Text Markup Readers

`format_readers/text_markup/` contains the shared low-level parsing stack for technical markup languages such as TeX, reStructuredText, and AsciiDoc. Its goal is not to emit product IR directly, but to build stable intermediate document models that upper-layer `formats/*` parsers can consume.

## Responsibilities

- Provide shared lexical, block, inline, and table parsing infrastructure
- Implement language-specific entry points for TeX, RST, and AsciiDoc
- Produce a unified `PreparedTextMarkupDocument` and shared block/inline models

## Key Entry Points

- `shared/prepare.mbt`
  Unified preparation entry point
- `shared/text_markup_parser.mbt`
  Shared main parsing orchestration
- `shared/text_markup_block_parser.mbt`
  Paragraph, list, heading, and other block-level recovery
- `shared/text_markup_inline_parser.mbt`
  Link, emphasis, code, and other inline recovery
- `shared/text_markup_table_parser.mbt`
  Table recognition and structuring
- `tex/tex_parser.mbt`
  TeX entry point
- `rst/rst_parser.mbt`
  RST entry point
- `asciidoc/asciidoc_parser.mbt`
  AsciiDoc entry point

## Key Types

- `PreparedTextMarkupDocument`
  The standard result of the shared preparation stage
- `TextMarkup*` families
  Shared intermediate models for blocks, inlines, and tables

## Maintenance Rules

- Keep shared lexical and semantic recovery logic in `shared/` whenever possible to avoid duplicating near-identical logic across the three languages
- Language-specific rules may extend the behavior, but should not pollute the shared semantic layer
- When adding another text-markup format, prefer reusing the shared model first and adding only the language-specific parser surface

## Validation

```bash
moon test
```
