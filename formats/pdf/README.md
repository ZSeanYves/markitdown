# PDF

`formats/pdf/` owns the formal PDF parser path, including native-text recovery, the explicit accurate scanned-PDF route, and PDF-specific IR lowering. Low-level PDF decoding, font handling, and geometry models still live in `format_readers/pdf/` and `internal/formats/pdf/`.

The accurate scanned-PDF route is a PDF-specific external-tool boundary:
`pdftoppm` rasterizes complete pages and the PaddleOCR wrapper recognizes those
page artifacts. It is separate from the main product OCR path, which only
accepts top-level pure-image inputs. Embedded images are never independently
dispatched to OCR.

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

Balanced native PDF opens a `SourceCursor`, resolves supported xref/object
ranges lazily, and falls back to bounded full-payload parsing only when the
cursor path cannot safely recover the file. Accurate PDF is a separate external
boundary that rasterizes complete pages; neither route OCRs embedded assets.

## Maintenance Rules

- Keep native-text, OCR, and lowering responsibilities clearly layered instead of pushing reader details back into parser orchestration
- Missing `pdftoppm` or OCR providers must continue to surface explainable fail-closed diagnostics
- Before adding a new PDF enhancement, decide whether it belongs in the parser, OCR runtime, or lowering layer to avoid responsibility drift
- Keep image decode working sets and exported asset payloads inside the shared
  resource budgets; command time/output limits apply to every raster page

## Validation

```bash
moon test
bash tools/regression/check_balance.sh --format pdf
bash tools/regression/check_accurate.sh --pdf
```
