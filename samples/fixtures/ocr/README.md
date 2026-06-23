# samples/fixtures/ocr

Role:
  tiny OCR fixtures for fail-closed checks and explicit image `--ocr` boundary tests

Owns:
  self-contained fixture images
  expected text for tiny OCR samples

Does not own:
  large OCR corpora
  multilingual quality evaluation
  PDF OCR coverage
  default repo-local validation requirements

Current policy:
  keep fixtures small and license-clean
  prefer self-generated images
  do not make Tesseract or tessdata a requirement for the default sample gate
  explicit image `--ocr` may use these fixtures, but image input is still outside the normal supported-format set

External OCR corpora belong in:
  `markitdown-quality-lab`
