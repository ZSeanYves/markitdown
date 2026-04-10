# PDF phase-1.5 sample manifest (generated, do not commit binaries)

Use:

```bash
python3 samples/tools/gen_phase15_pdf_samples.py
```

Generated files:

- `samples/pdf/pdf_two_column_negative_phase15.pdf`
  - guards: pseudo two-column reading-order negative (avoid left/right stitching)
- `samples/pdf/pdf_header_footer_variants_phase15.pdf`
  - guards: repeated-but-not-identical header/footer noise filtering (keep body)
- `samples/pdf/pdf_heading_false_positive_phase15.pdf`
  - guards: heading false positives (short line, ALL CAPS, numbered non-heading)
- `samples/pdf/pdf_cross_page_should_merge_phase15.pdf`
  - guards: cross-page continuation should merge
- `samples/pdf/pdf_cross_page_should_not_merge_phase15.pdf`
  - guards: cross-page new-section should not merge
- `samples/ocr_pdf/ocr_clear_baseline_phase15.pdf`
  - guards: OCR fallback clear scan baseline (manual/experimental track)
- `samples/ocr_pdf/ocr_medium_baseline_phase15.pdf`
  - guards: OCR fallback medium-quality baseline (manual/experimental track)

Notes:

- OCR baseline PDFs are intentionally stored under `samples/ocr_pdf` and are not enrolled in `samples/diff.sh` by default.
- For text-PDF samples, add matching expected files under `samples/expected/pdf/*.md` after generating PDFs and reviewing converter output.
