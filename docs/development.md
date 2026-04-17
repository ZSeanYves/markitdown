# Development Guide

## CLI

The current CLI uses a subcommand-based interface:

```bash
moon run cli -- normal <input> [output]
moon run cli -- ocr <input> [output]
moon run cli -- debug <all|extract|raw|pipeline> <input> [output]
````

To also output a metadata sidecar, use:

```bash
moon run cli -- normal --with-metadata <input> <output.md>
moon run cli -- ocr --with-metadata <input> <output.md>
moon run cli -- debug --with-metadata <all|extract|raw|pipeline> <input> <output.md>
```

Current output rules:

* The Markdown main output follows the `[output]` argument
* If `[output]` behaves like a directory, the main output becomes `<output>/<input_stem>.md`
* The metadata sidecar is always written to:

  * `<markdown_dir>/metadata/<markdown_stem>.metadata.json`
* If no output file is provided (stdout mode), the sidecar is not written to disk

## Debug Modes

The current supported debug scopes are:

* `all`
* `extract`
* `raw`
* `pipeline`

Approximate meanings:

* `debug all`: enables the full PDF debug chain
* `debug extract`: shows extraction-stage debug information
* `debug raw`: dumps the selected raw text
* `debug pipeline`: shows debug information for the full PDF processing pipeline

## Regression System

The current regression system has been split into three independent validation chains:

* `samples/main_process`: mainflow structural recovery
* `samples/metadata`: origin / image-context / caption / nearby-caption
* `samples/assets`: asset export and Markdown asset-reference validity

In addition, `samples/test` provides a compact five-format demo set for acceptance walkthrough and quick manual inspection.

### Check sample enrollment consistency

```bash
./samples/check_samples.sh
```

### Run full main regression

```bash
./samples/diff.sh
```

### Run metadata regression independently

```bash
./samples/check_metadata.sh
```

### Run assets regression independently

```bash
./samples/check_assets.sh
```

## How to Choose Regression Scope During Development

### When modifying mainflow structural recovery logic

If you modify any of the following, you should at least run:

```bash
./samples/diff.sh
```

Typical cases include:

* `convert/*`
* `core/emitter_markdown.mbt`
* `core/ir.mbt`
* mainflow-related samples and expected outputs

### When modifying metadata / provenance / image-context logic

If you modify any of the following, you should at least run:

```bash
./samples/check_metadata.sh
```

Typical cases include:

* `core/metadata.mbt`
* `core/ir.mbt`
* image caption / nearby-caption / origin related logic
* `samples/metadata/*`

### When modifying asset export / asset reference logic

If you modify any of the following, you should at least run:

```bash
./samples/check_assets.sh
```

Typical cases include:

* image export logic for any format
* asset naming rules
* `samples/assets/*`

### When modifying PDF-related lower-level or recovery logic

If you modify any of the following, it is recommended to run at least:

```bash
./samples/diff.sh
./samples/check_metadata.sh
```

Typical cases include:

* `doc_parse/pdf_core/`
* `convert/pdf/`
* `core/emitter_markdown.mbt`
* PDF-related samples / expected outputs / metadata samples

The reason is that PDF currently affects not only the mainflow, but also image context and lightweight provenance.

## External Dependencies

### OCR plugin path

At the moment, only the OCR path depends on external tooling:

* `ocrmypdf`

Notes:

* OCR remains a dedicated plugin-style path, not the default `normal` mainflow
* The normal PDF path on `main` no longer depends on `pdftotext` or `mutool`
* The current normal PDF mainflow is driven by the repository’s native recovery chain

## How to Understand the Current Engineering Structure

The current project can be roughly understood as the following layers:

* `cli/`: command-line entry and output path coordination
* `convert/*`: upper-level structural recovery and semantic mapping
* `doc_parse/*`: lower-level parsing infrastructure (ZIP / OOXML / PDF)
* `core/*`: unified IR, Markdown emitter, metadata sidecar emitter
* `samples/*`: mainflow / metadata / assets regression and acceptance demo samples

When developing, you should try to determine clearly which layer your change belongs to:

* raw format parsing problems: check `doc_parse/*` first
* structural recovery problems: check `convert/*` first
* output form and sidecar problems: check `core/*` first
* acceptance or regression issues: check `samples/*` first

## Current Engineering Direction

### Near-term priorities

1. Continue stabilizing and documenting the current native PDF mainflow
2. Continue strengthening the engineering contract of metadata sidecar and lightweight provenance
3. Continue improving PPTX structural recovery and image-context expression
4. Continue improving HTML local structural recovery and image-context expression
5. Continue improving cross-format consistency through the unified IR

### Mid-term directions

1. Continue strengthening complex PDF layout recovery
2. Promote more high-confidence structures into richer IR semantics
3. Continue improving consistency, maintainability, and explainability in OOXML and lower-level parsing infrastructure
4. Gradually enhance the expressiveness of metadata while preserving the current lightweight contract

```
