# OCR

`formats/ocr/` owns the formal direct-image OCR parser path and also provides the provider protocol, runtime selection logic, and OCR data model reused by PDF OCR.

## Responsibilities

- Provide the image OCR parser and its fail-closed boundaries
- Define OCR provider request, result, error, and dependency-diagnostic contracts
- Manage local runtime integrations such as Tesseract and Paddle OCR
- Lower OCR page, block, line, and word models into unified block structures

## Key Entry Points

- `parser.mbt`
  `image_ocr_parser`, `image_ocr_parser_result*`
- `provider.mbt`
  `OcrProviderRequest`, `OcrProviderResult`, dependency diagnostics, and provider selection targets
- `runtime.mbt`
  Provider selection, fallback, and Paddle OCR runtime execution
- `model.mbt`
  `OcrPageModel`, `OcrBlock`, `OcrLine`, `OcrWord`
- `tesseract.mbt` / `tesseract_tsv.mbt`
  Tesseract invocation and TSV parsing

## Key Types

- `OcrProviderRequest`
  A unified description of single-image or batch-image OCR requests
- `OcrProviderResult`
  A unified description of provider page results, version info, and diagnostics
- `OcrDocumentModel`
  The stable provider-neutral OCR document model

## Maintenance Rules

- New providers should implement the shared provider contract before being wired into parser/runtime layers
- Dependency-missing, fallback, and fail-closed diagnostics should remain explainable
- Keep OCR geometry and text models provider-neutral so upper layers do not become tied to one tool's private output shape

## Validation

```bash
moon test
```
