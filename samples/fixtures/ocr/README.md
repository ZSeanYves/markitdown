# OCR Fixtures

This directory is reserved for tiny, license-clean OCR fixtures that are safe
to keep in the main repository.

These fixtures are policy/dev fixtures for the shipped image OCR path. They
are not evidence of scanned-PDF OCR support or broader OCR quality guarantees.

Current policy:

* prefer self-generated tiny text images
* keep fixtures provider-independent where possible
* keep each checked-in OCR fixture at or below 500KB
* require `source=self-generated` and `license=project-license` for the
  current main-repo fixture policy
* do not require Tesseract, tessdata, or any OCR runtime in the default
  repo-local validation path
* do not store real-world or large OCR corpora in the main repo
* current release builds now ship product image OCR through the main CLI
* product image OCR depends on local `tesseract` and language data
* `--ocr-lang <LANG>` now selects the Tesseract language value for the main
  CLI image-OCR path when matching tessdata is installed
* optional OCR diagnostics are still not part of the default native quality gate

`manifest.tsv` currently records:

* `id`
* `path`
* `expected_text_path`
* `source`
* `license`
* `purpose`
* `provider_required`
* `notes`

Recommended metadata to record for any future checked-in OCR fixture:

* source URL or `local-generated`
* license
* author/source
* retrieval or generation date
* expected text
* why it is safe for the main repo

Preferred first main-repo OCR fixture shape:

* a self-generated tiny PNG such as:
  `MoonBit OCR`
  `Sample 123`

Current checked-in tiny fixture:

* `tiny_ocr_sample.png`
* expected text: `MoonBit OCR` / `Sample 123`
* source: self-generated
* license: project-license
* provider requirement: false in default validation, optional in tesseract
  smoke
* expected text file: `tiny_ocr_sample.expected.txt`

Generation note:

* the checked-in PNG was generated locally with Python + Pillow and then
  committed as a static fixture
* Pillow is not a runtime dependency of the repository
* `samples/helpers/validation/check_ocr_fixtures.sh` validates manifest
  structure, path safety, size limits, and license/source policy without
  running OCR
* these fixtures support the shipped image OCR path, but they are still not a
  broad OCR accuracy gate
* the real OCR corpus, expected preview baselines, and provider outputs live in
  `markitdown-quality-lab`

Real-world OCR rows, multilingual scans, noisy captures, and larger benchmark
payloads should live in `markitdown-quality-lab`.

Recommended external OCR corpus scaffold:

* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/README.md`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/manifest.tsv`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/source_catalog.tsv`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/images/`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/expected_text/`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/expected_markdown/`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/provider_outputs/tesseract_tsv/`
* `markitdown-quality-lab/external_quality/ocr/_legacy_samples/provider_outputs/layout_preview/`
