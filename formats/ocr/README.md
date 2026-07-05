# OCR

`formats/ocr/` owns the formal direct-image OCR path and also provides the shared provider contract and OCR data model reused by PDF OCR.

Main responsibilities:

- direct-image OCR parser
- provider selection and dependency guidance
- wrapper runtime protocol
- Tesseract / Paddle runtime integration

Main files:

- `parser.mbt`
- `provider.mbt`
- `runtime.mbt`
- `tesseract*.mbt`

Maintenance rules:

- new OCR providers should implement the shared provider contract
- provider fallback, dependency guidance, and fail-closed behavior must stay explainable and regression-testable

Validation:

```bash
moon test
```
