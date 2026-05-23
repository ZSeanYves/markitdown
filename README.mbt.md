# markitdown-mb for MoonBit Developers

`markitdown-mb` is a MoonBit-native multi-format document-to-Markdown project.
This file is the short MoonBit-oriented entrypoint; the broader product-facing
overview lives in [README.md](./README.md).

## Start Here

| If you are here for | Start here |
| --- | --- |
| Build / validate the repo | [Core Commands](#core-commands) |
| Converter work | [Package Shape](#package-shape) |
| OCR boundary | [Current OCR boundary](#current-ocr-boundary) |
| Detailed docs map | [docs/README.md](./docs/README.md) |
| Product behavior overview | [README.md](./README.md) |

## Five-Minute Orientation

For a new contributor, the shortest accurate summary is:

* the product CLI converts common document formats into Markdown-first output
* shipped OCR currently means image OCR through the main CLI only
* image OCR depends on local `tesseract` plus installed language data
* main-CLI OCR flags are `--ocr`, `--no-ocr`, and `--ocr-lang <LANG>`
* normal document conversion still stays no-OCR
* PDF OCR is not wired; `pdf --ocr` remains future explicit provider work
* repo-local validation is
  `moon check`,
  `bash samples/check.sh`,
  `bash samples/check_quality.sh`,
  `bash samples/bench.sh`,
  and `bash samples/bench.sh --help`
* `debug`, `bench`, PDF scan diagnostics, and layout-model tooling are
  developer surfaces, not the normal product entrypoint

If you need the detailed boundaries, read in this order:

* [docs/README.md](./docs/README.md)
* [README.md](./README.md)
* [docs/supported-formats.md](./docs/supported-formats.md)
* [docs/pdf.md](./docs/pdf.md)
* [docs/quality-and-release.md](./docs/quality-and-release.md)
* [docs/architecture.md](./docs/architecture.md)

## Core Commands

Build the main product binaries:

```bash
moon build cli --target native
moon build pdf --target native
moon build zip --target native
```

Optional internal/dev binaries:

* `moon build debug --target native`
* `moon build bench --target native`

Recommended validation entrypoints:

* `moon check`
* `moon test`
* `bash samples/check.sh`
* `bash samples/check_quality.sh`
* `bash samples/check_quality.sh --format pdf`
* `bash samples/bench.sh`
* `bash samples/bench.sh --help`

Public sample entrypoints:

* `bash samples/check.sh` runs the full repo-local validation suite.
* `bash samples/check_quality.sh` runs only the external quality corpus from
  `markitdown-quality-lab/external_quality/` and fails clearly if that repo is
  missing or incomplete.
* `bash samples/check_quality.sh --format pdf` runs the focused PDF quality
  slice from that same external corpus.
* `bash samples/bench.sh` runs the default smoke benchmark suite and writes
  results under `.tmp/bench/`.
* `bash samples/bench.sh --help` shows additional suites and targeted options.

The main repo is self-contained for:

* runtime
* `moon test`
* `bash samples/check.sh`

`bash samples/check_quality.sh` is the optional full quality gate and expects
the repo-local quality-lab:

```bash
git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

That entrypoint:

* expects `markitdown-quality-lab/external_quality/`
* fails clearly when the external corpus is missing or incomplete
* does not fall back to repo-local quality rows

Current OCR boundary:

* normal conversion never OCRs and never probes OCR providers.
* main-CLI OCR policy flags `--ocr`, `--no-ocr`, and `--ocr-lang <LANG>` are
  supported.
* image inputs now auto-OCR through `convert/vision`.
* product image OCR depends on local `tesseract` and language data; if they
  are missing, image OCR fails clearly.
* `--ocr-lang <LANG>` passes a Tesseract language value such as `eng` or
  `eng+chi_sim` to image OCR only; there is no language auto-detection.
* normal document conversion still stays no-OCR outside explicit image inputs.
* PDF OCR is not wired in this build.
* debug/report helpers are diagnostics, not the product entrypoint.
* repo-root `markitdown-quality-lab/` is an optional external corpus/artifact
  repo, not a runtime dependency.
* see [docs/roadmap.md](./docs/roadmap.md) and
  [docs/quality-and-release.md](./docs/quality-and-release.md) for rebuild
  status and optional diagnostics.

## Package Shape

High-level boundaries:

* `cli`: lightweight product entrypoint
* `pdf`, `zip`: bundled product components
* `debug`, `bench`: developer tools
* `core`: shared document/metadata/emitter layer
* `convert/*`: format-to-IR conversion policy
* `doc_parse/*`: lower-layer parser/model/inspect foundations
* `convert/vision`: provider-independent OCRPageModel scaffold and future OCR
  implementation path
* `doc_parse/pdf/layout_model_tool`: PDF layout export/infer tool

Important current facts:

* normal runtime does not read quality-lab assets
* normal runtime does not read model JSON
* PDF layout normal behavior is distilled into MoonBit rules/gates
* `cli` stays out of the vendored PDF closure and should remain `mbtpdf=0`
* normal conversion never OCRs and never probes OCR providers
* main-CLI OCR policy flags `--ocr`, `--no-ocr`, and `--ocr-lang <LANG>` are
  supported in this build
* image inputs now auto-OCR through `convert/vision`
* image OCR requires local `tesseract`; missing runtime support fails clearly
* normal document conversion still stays no-OCR outside explicit image inputs
* debug/report helpers are diagnostics, not product entrypoints
* PDF OCR is not wired in this build

## Current Checked Facts

* `moon test`: `1579 passed`
* `bash samples/check.sh`: `444` markdown / `85` metadata / `90` assets / `0`
  failures
* `bash samples/check_quality.sh`: external-corpus-only gate; row counts depend
  on the checked-out `markitdown-quality-lab` contents

## Primary Docs

* [docs/architecture.md](./docs/architecture.md)
* [docs/supported-formats.md](./docs/supported-formats.md)
* [docs/quality-and-release.md](./docs/quality-and-release.md)
* [docs/pdf.md](./docs/pdf.md)
* [docs/performance.md](./docs/performance.md)
* [docs/roadmap.md](./docs/roadmap.md)
