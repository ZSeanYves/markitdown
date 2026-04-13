# Development Guide

## CLI

Current CLI uses a subcommand-based interface:

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

* `debug all`: enables all PDF debugging capabilities
* `debug extract`: shows extraction-stage debug information
* `debug raw`: dumps the selected raw text
* `debug pipeline`: shows debug information for the full PDF pipeline

## Regression

### Check input/expected enrollment

```bash
./samples/check_samples.sh
```

### Run full diff regression

```bash
./samples/diff.sh
```

## External Dependencies

### PDF text extraction

Recommended:

* `pdftotext`
* `mutool`

### OCR

Requires:

* `ocrmypdf`

## Current Engineering Direction

### Near-term priorities

1. Continue strengthening PPTX layout-recovery capabilities
2. Continue improving HTML local-container and inline semantic recovery
3. Continue strengthening PDF OCR coverage and documentation of complex layout boundaries

### Mid-term directions

1. Continue extending cross-format structural capabilities through the unified IR
2. Continue improving support for more complex PDF layouts
3. Continue moving PPTX from stable ordering toward richer structural expression
4. Continue improving consistency in OOXML and lower-level parser infrastructure without sacrificing maintainability
