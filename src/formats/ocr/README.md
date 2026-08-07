# OCR

> Internal optional-runtime package. Consumer-facing OCR support is reported by
> `@api.capabilities()` and configured through stable API options.

Logical package `ZSeanYves/markitdown/formats/ocr` owns the formal direct-image
OCR parser path, provider protocol, runtime selection, and OCR data model.

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
- OCR accepts only top-level image payloads or explicitly dispatched standalone
  ZIP children. Provider requests and returned `AssetPayload` values remain
  subject to product byte/page budgets and bounded command output.

## Validation

```bash
./tools/env/optional_deps.sh install balance
moon test --package ZSeanYves/markitdown/formats/ocr --target native
./tools/regression/check_balance.sh --ocr
```
