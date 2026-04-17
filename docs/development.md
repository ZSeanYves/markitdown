# Development Guide

## CLI

The current CLI uses a subcommand-based interface:

```bash
moon run cli -- normal <input> [output]
moon run cli -- ocr <input> [output]
moon run cli -- debug <all|extract|raw|pipeline> <input> [output]
```

## Debug Modes

Supported debug scopes:

* `all`
* `extract`
* `raw`
* `pipeline`

Approximate meaning:

* `debug all`: enables the full PDF debug chain
* `debug extract`: shows extraction-stage debug information
* `debug raw`: dumps the selected raw text
* `debug pipeline`: shows debug information for the full PDF pipeline

## Regression

### Check input / expected enrollment

```bash
./samples/check_samples.sh
```

### Run full diff regression

```bash
./samples/diff.sh
```

### Run PDF-focused regression

```bash
./samples/pdf_regression_check.sh
```

If you modify any of the following, you should at least run the PDF regression suite:

* `doc_parse/pdf_core/`
* `convert/pdf/`
* `core/emitter_markdown.mbt`
* PDF-related samples / expected files

## External Dependencies

### OCR plugin

Requires:

* `ocrmypdf`

Notes:

* OCR remains a dedicated plugin-style path and is not the default `normal` flow
* The normal PDF path on `main` no longer depends on `pdftotext` or `mutool`
* The normal PDF mainflow is now fully driven by the repository’s native recovery chain

## Current Engineering Direction

### Near-term priorities

1. Stabilize and document the native PDF mainflow on `main`
2. Continue strengthening PPTX layout recovery and richer structural expression
3. Continue improving HTML local-container structure recovery
4. Continue improving consistency across formats through the unified IR

### Mid-term directions

1. Continue strengthening complex PDF layout recovery
2. Promote more high-confidence layouts into richer IR semantics
3. Continue improving consistency and maintainability in OOXML and lower-level parsing infrastructure
