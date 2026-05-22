# markitdown-mb

[![CI](https://github.com/ZSeanYves/markitdown/actions/workflows/ci.yml/badge.svg)](https://github.com/ZSeanYves/markitdown/actions/workflows/ci.yml)
![MoonBit](https://img.shields.io/badge/MoonBit-native-2563eb)
![CLI](https://img.shields.io/badge/CLI-prebuilt--native-16a34a)
![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20Linux%20%7C%20macOS-6b7280)
![Formats](https://img.shields.io/badge/formats-14%2B-0ea5e9)
![Validation](https://img.shields.io/badge/validation-passing-16a34a)
![License](https://img.shields.io/badge/license-Apache--2.0-f59e0b)

`markitdown-mb` is a MoonBit-first, lightweight multi-format
document-to-Markdown CLI for local structure extraction, RAG ingestion, and
knowledge-base import.

It is inspired by Microsoft MarkItDown, but the repository is intentionally
organized around:

* native execution
* conservative output contracts
* explicit component boundaries
* checked sample validation
* optional external quality-lab assets instead of checked-in large corpora

Current pipeline:

**multi-format input -> unified IR -> Markdown / assets / metadata sidecar**

## Quick Start

Build the product binaries:

```bash
moon build cli --target native
moon build pdf --target native
moon build zip --target native
```

Optional developer binaries:

```bash
moon build debug --target native
moon build bench --target native
```

Use the product CLI:

```bash
./_build/native/debug/build/cli/cli.exe --help
./_build/native/debug/build/cli/cli.exe <input> [output]
./_build/native/debug/build/cli/cli.exe normal --with-metadata <input> <output.md>
./_build/native/debug/build/cli/cli.exe batch <input_dir> <output_dir>
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
  [docs/quality-and-release.md](./docs/quality-and-release.md) for the
  current rebuild status and optional local helpers.

Recommended validation entrypoints:

The public sample entrypoints are `samples/check.sh`,
`samples/check_quality.sh`, and `samples/bench.sh`.

Recommended copy-paste-safe commands:

* `bash samples/check.sh --manifest-only` runs a lightweight manifest-only
  quick check.
* `bash samples/check_quality.sh --public-only` runs the checked-in public
  quality baseline without `markitdown-quality-lab/`.
* `bash samples/bench.sh --suite smoke --kind smoke` runs the benchmark smoke
  suite.

Other public entrypoints:

* `bash samples/check.sh` runs the full repo-local validation suite and is
  heavier than the quick check above.
* `bash samples/check_quality.sh` runs optional full quality when
  `markitdown-quality-lab/` is available.
* `bash samples/bench.sh --help` shows available benchmark suites.

## Current Support

| Format | Current scope |
| --- | --- |
| DOCX | conservative document structure, links, notes, images, tables, and text boxes |
| PPTX | conservative presentation structure, notes, links, tables, grouped content, and images |
| XLSX | workbook/sheet/cell extraction with conservative formula and merged-cell policy |
| PDF | native text-PDF path with explicit OCR boundary and narrow gated-normal layout cleanup |
| ZIP | archive/container conversion with nested dispatch and delegated PDF handling |
| EPUB | ZIP + OPF + spine + nav/NCX + XHTML chapter lowering |
| HTML / HTM | lightweight safe parser; no browser engine or JS execution |
| CSV / TSV | structured table lowering with conservative encoding/dialect handling |
| JSON / YAML / XML / TXT / Markdown | source-preserving or conservative structured/text paths |

Use [docs/supported-formats.md](./docs/supported-formats.md) for the detailed
support matrix and explicit limits.

## Validation Snapshot

Main-repo validation is currently green:

* `moon test`: `1579 passed`
* `bash samples/check.sh`: `444` markdown / `85` metadata / `90` assets / `0`
  failures
* public-only quality: `24 rows / 0 skipped / 0 expected_fail`

Optional full quality, when the repo-local quality-lab is present:

* full quality: `330 rows / 1 skipped / 0 expected_fail`
* focused PDF quality: `101 rows / 1 skipped / 0 expected_fail`

Interpretation:

* these are checked local validation snapshots, not repository-wide quality percentages
* `0 expected_fail` does not mean every format boundary is universally covered
* OCR and scanned-document behavior remain explicit-only
* benchmark and compare numbers are sample-scoped, not universal performance guarantees

## Quality-Lab Boundary

The main repository is self-contained for:

* runtime
* `moon test`
* `bash samples/check.sh --manifest-only` for the lightweight repo-local quick
  check
* public-only quality validation

Optional external assets live in a separate repo cloned into the project root:

```bash
git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

That repo carries:

* `markitdown-quality-lab/corpus`
* `markitdown-quality-lab/quality_rows/manifest.tsv`
* `markitdown-quality-lab/pdf_layout_classifier`
* `markitdown-quality-lab/scripts/encoding/generate_cp936_blob.py`

It is an independent Git repository, not a submodule, and it is not part of
the release artifact set.

## Product And Tool Boundary

Current user-facing binaries:

* `cli`: normal product entrypoint
* `pdf`: bundled PDF runtime component
* `zip`: bundled ZIP runtime component

Current developer binaries:

* `debug`: inspect/report surface
* `bench`: benchmark surface
* `ocr`: explicit OCR rebuild stub
* `doc_parse/pdf/layout_model_tool`: PDF layout export/infer tool
* `convert/vision`: provider-independent OCRPageModel scaffold

Important limits:

* normal runtime does not read quality-lab assets
* normal runtime does not read model JSON
* PDF layout behavior in the normal path is distilled into MoonBit rules/gates
* normal conversion never OCRs and never probes OCR providers
* previous text-only OCR prototype has been retired
* OCR is being rebuilt around provider-independent `OCRPageModel`
* current OCR product execution is not wired in this build
* current OCR/Vision work is internal/dev scaffold rather than a product CLI
* future path is provider signal -> `OCRPageModel` -> MoonBit layout recovery ->
  unified IR -> Markdown
* PDF OCR is not wired in this build; future PDF OCR must stay on an explicit
  provider path
* main-repo OCR fixtures are tiny fixture-policy groundwork, not a current OCR
  accuracy gate
* PDF and ZIP stay on the product surface without pulling the full PDF closure into lightweight `cli`

## Performance Snapshot

Current local clean native build snapshot:

* `cli build`: `64.06s`
* `pdf build`: `69.07s`
* `zip build`: `63.48s`
* `ocr build`: `54.72s`
* `cli.exe`: `3,790,168`
* `pdf.exe`: `4,354,040`
* `zip.exe`: `3,601,656`
* `ocr.exe`: `1,644,328`
* `cli.c`: `401,407`
* `pdf.c`: `450,869`
* `zip.c`: `378,571`
* `ocr.c`: `154,425`
* `cli mbtpdf count`: `0`
* `zip mbtpdf count`: `0`
* `pdf mbtpdf count`: `23339`

Current overlap-only compare timing against Microsoft MarkItDown `0.1.5`:

* total runs: `282`
* overlap rows per runner: `47`
* `markitdown-mb`: `11.009 ms`
* `markitdown-python`: `421.715 ms`

Do not treat that compare run as a universal speed claim. It is a local,
sample-scoped timing snapshot on a named overlap corpus.

Use [docs/performance.md](./docs/performance.md) for measured build and
benchmark facts plus interpretation notes.

## Where To Go Next

* [docs/architecture.md](./docs/architecture.md): package, binary, and repository boundaries
* [docs/supported-formats.md](./docs/supported-formats.md): supported formats and explicit limits
* [docs/quality-and-release.md](./docs/quality-and-release.md): validation layers, quality-lab boundary, and release workflow
* [docs/pdf.md](./docs/pdf.md): PDF text/layout/OCR boundary
* [docs/performance.md](./docs/performance.md): measured build, benchmark, and interpretation notes
* [docs/roadmap.md](./docs/roadmap.md): current direction and legacy fallback removal plan
