# markitdown-mb for MoonBit Developers

`markitdown-mb` is a MoonBit-native multi-format document-to-Markdown project.
This file is the short MoonBit-oriented entrypoint; the broader product-facing
overview lives in [README.md](./README.md).

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
* `moon build ocr --target native` builds the current OCR rebuild stub, not a
  product OCR CLI

Recommended validation entrypoints:

* `moon check`
* `moon test`
* `bash samples/check.sh --manifest-only`
* `bash samples/check_quality.sh --public-only`
* `bash samples/bench.sh --suite smoke --kind smoke`

Public sample entrypoints:

* `bash samples/check.sh` runs the full repo-local validation suite.
* `bash samples/check.sh --manifest-only` runs the lightweight manifest-only
  quick check.
* `bash samples/check_quality.sh --public-only` runs the checked-in public
  quality baseline without `markitdown-quality-lab/`.
* `bash samples/check_quality.sh` runs the optional full quality gate and
  expects the repo-local quality-lab.
* `bash samples/bench.sh --suite smoke --kind smoke` runs the benchmark smoke
  suite.
* `bash samples/bench.sh --help` shows available benchmark suites.

The main repo is self-contained for:

* runtime
* `moon test`
* `bash samples/check.sh --manifest-only`
* public-only quality validation

`bash samples/check_quality.sh` is the optional full quality gate and expects
the repo-local quality-lab:

```bash
git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

Current OCR boundary:

* OCR product execution is currently not wired in this build.
* normal conversion never OCRs and never probes OCR providers.
* Vision/OCR work is being rebuilt around provider-independent
  `OCRPageModel`.
* current OCR/Vision work is internal/dev scaffold, not a product OCR CLI.
* repo-root `markitdown-quality-lab/` is an optional external corpus/artifact
  repo, not a runtime dependency.
* see [docs/roadmap.md](./docs/roadmap.md) and
  [docs/quality-and-release.md](./docs/quality-and-release.md) for rebuild
  status and optional local helpers.

## Package Shape

High-level boundaries:

* `cli`: lightweight product entrypoint
* `pdf`, `zip`: bundled product components
* `debug`, `bench`: developer tools
* `core`: shared document/metadata/emitter layer
* `convert/*`: format-to-IR conversion policy
* `doc_parse/*`: lower-layer parser/model/inspect foundations
* `convert/vision`: provider-independent OCRPageModel scaffold
* `ocr/*`: explicit OCR rebuild stub and future OCR entry surface
* `doc_parse/pdf/layout_model_tool`: PDF layout export/infer tool

Important current facts:

* normal runtime does not read quality-lab assets
* normal runtime does not read model JSON
* PDF layout normal behavior is distilled into MoonBit rules/gates
* `cli` stays out of the vendored PDF closure and should remain `mbtpdf=0`
* normal conversion never OCRs and never probes OCR providers
* previous text-only OCR prototype has been retired
* OCR is being rebuilt around provider-independent `OCRPageModel`
* current OCR product execution is not wired in this build
* current OCR/Vision work is internal/dev scaffold, not a product OCR CLI
* PDF OCR is not wired in this build and remains future explicit provider work

## Current Checked Facts

* `moon test`: `1579 passed`
* `bash samples/check.sh`: `444` markdown / `85` metadata / `90` assets / `0`
  failures
* public-only quality: `24 / 0 / 0`
* full optional quality with quality-lab: `330 / 1 / 0`

## Primary Docs

* [docs/architecture.md](./docs/architecture.md)
* [docs/supported-formats.md](./docs/supported-formats.md)
* [docs/quality-and-release.md](./docs/quality-and-release.md)
* [docs/pdf.md](./docs/pdf.md)
* [docs/performance.md](./docs/performance.md)
* [docs/roadmap.md](./docs/roadmap.md)
