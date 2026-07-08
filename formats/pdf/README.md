# PDF

`formats/pdf/` owns the formal PDF path, including native-text extraction, OCR routes, and PDF-specific lowering logic.

Main responsibilities:

- native PDF extraction
- scanned-like probing
- PDF OCR routes
- PDF-specific IR lowering

Main files:

- `parser.mbt`
- `backend.mbt`
- `to_ir.mbt`
- `ocr_runtime.mbt`

Maintenance rules:

- new PDF capabilities should converge into canonical parser paths first
- native-text, OCR, and lowering logic should stay clearly layered for long-term maintenance

Validation:

```bash
moon test
bash samples/check_balance.sh --format pdf
```
