# Text Markup Readers

Logical package `ZSeanYves/markitdown/internal/readers/text_markup` contains the
consolidated low-level parsing stack for TeX, reStructuredText, and AsciiDoc.
It builds a shared intermediate model consumed by the corresponding
`formats/text_markup` lowering package.

## Responsibilities

- Provide shared lexical, block, inline, and table parsing infrastructure
- Implement language-specific entry points for TeX, RST, and AsciiDoc
- Produce a unified `PreparedTextMarkupDocument` and shared block/inline models

## Key Entry Points

- `prepare.mbt`
  Source preparation and format dispatch
- `parser.mbt`
  Shared parse orchestration and language entry points
- `block_parser.mbt` / `rst_blocks.mbt` / `asciidoc_tex_blocks.mbt`
  Common and language-specific block recovery
- `inline_parser.mbt`
  Links, emphasis, code, references, and inline recovery
- `table_parser.mbt`
  Table recognition and structuring
- `types.mbt`
  Shared prepared document, block, inline, and table models

## Key Types

- `PreparedTextMarkupDocument`
  The standard result of the shared preparation stage
- `TextMarkup*` families
  Shared intermediate models for blocks, inlines, and tables

## Maintenance Rules

- Keep shared lexical and semantic recovery in this package and isolate only
  genuinely language-specific blocks to avoid duplicating near-identical logic
- Language-specific rules may extend the behavior, but should not pollute the shared semantic layer
- When adding another text-markup format, prefer reusing the shared model first and adding only the language-specific parser surface
- Includes, directives, and image references remain declarative. Reader code
  must not execute plugins, fetch remote content, or bypass product resource
  limits while recovering readable structure.

## Validation

```bash
moon test --package ZSeanYves/markitdown/internal/readers/text_markup --target native
```
