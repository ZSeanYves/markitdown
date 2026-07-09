# PDF

`formats/pdf/` owns the formal PDF parser path, including native-text recovery, PDF OCR routing, and PDF-specific IR lowering. Low-level PDF decoding, font handling, and geometry models still live in `format_readers/pdf/` and `internal/formats/pdf/`.

## Responsibilities

- Expose the formal native-text and OCR parser routes
- Preserve explicit PDF fail-closed rules in balanced and accurate modes
- Lower native PDF document models into blocks, signals, source refs, and appendix structures
- Coordinate the runtime boundary between `pdftoppm` and OCR providers

## Key Entry Points

- `parser.mbt`
  `pdf_native_parser`, `pdf_ocr_parser`, and their matching capabilities and diagnostics
- `to_ir.mbt`
  `pdf_native_document_to_ir*`, `pdf_native_appendix_blocks`
- `ocr_runtime.mbt`
  `PdfRasterResult`, `rasterize_pdf_with_pdftoppm*`
- `parser_test.mbt` / `to_ir_test.mbt`
  Contract-style regression coverage for native-text parsing and lowering

## Key Types

- `PdfRasterPageArtifact`
  A per-page rasterization artifact plus diagnostics summary
- `PdfRasterResult`
  The overall page count, backend name, and page-level results from one rasterization run
- `ParserCapability`
  The shared contract through which native-text and OCR PDF routes are exposed to the registry

## Maintenance Rules

- Keep native-text, OCR, and lowering responsibilities clearly layered instead of pushing reader details back into parser orchestration
- Missing `pdftoppm` or OCR providers must continue to surface explainable fail-closed diagnostics
- Before adding a new PDF enhancement, decide whether it belongs in the parser, OCR runtime, or lowering layer to avoid responsibility drift

## Validation

```bash
moon test
bash samples/check_balance.sh --format pdf
```
