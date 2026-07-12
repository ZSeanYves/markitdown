# Formats

`formats/` owns product-level format parsers and lowering logic. Each subpackage connects one reader output to the unified parser contract and decides how it should enter the canonical `DocumentIR` path.

## Responsibilities

- Register built-in parsers and expose the unified registry upward
- Implement parser, lowering, and format-specific diagnostics behavior
- Consume prepared or source-model outputs from `format_readers/*`
- Keep format behavior aligned with product capabilities, route contracts, and fail-closed boundaries

## Key Entry Points

- `registry.mbt`
  Registration and construction entry points for the built-in parser registry
- `pdf/`
  PDF native-text and OCR routes plus IR lowering
- `ocr/`
  Direct-image OCR parser plus provider/runtime protocol
- `docx/`, `pptx/`, `xlsx/`
  Office parsers and semantic lowering
- `html/`, `markdown/`, `json/`, `yaml/`, `xml/`
  Text and structured-data parsers plus document or streaming lowering
- `shared/`
  Shared lowering helpers reused by multiple formats

## Key Types And Functions

- `register_builtin_parsers`
  Registers every formally supported format into the shared `ParserRegistry`
- `*_parser` functions in `parser.mbt`
  Public parser entry points exposed through the registry
- `lower_*` / `*_to_ir`
  Lower reader outputs into canonical block, event, or document structures

## Maintenance Rules

- A new format should complete the reader, parser, registry, and contract story together instead of landing as a parser entry point only
- Fail-closed boundaries must stay explicit, especially around OCR, container recursion, and large-object degradation
- `formats/*` owns product semantics, not low-level decoders; raw parse details should stay in `format_readers/*`
- Embedded document images are assets, not OCR requests. Only top-level pure
  images and standalone unreferenced ZIP image children use the balance OCR
  provider.

## Validation

```bash
moon test
bash tools/regression/check_balance.sh
```
