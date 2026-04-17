# markitdown-mb

A **MoonBit-based content processing infrastructure project**, originally inspired by Microsoft **markitdown**.

It is no longer best described as just a “document-to-Markdown conversion tool”. Instead, it is evolving into a reusable foundation for:

* multi-format content parsing
* structural recovery
* unified IR modeling
* asset extraction and indexing
* lightweight provenance tracking
* downstream content workflows built on top of a stable intermediate representation

The project currently supports **DOCX / PDF / XLSX / PPTX / HTML** and can turn them into structured content with extracted assets when needed.

Supports **macOS** and **Linux**.

The project is built around a unified pipeline:

**multi-format content -> unified IR -> Markdown / assets / provenance**

This means the repository should be understood not only as a converter, but as a general-purpose base for content engineering workflows.

## Current Status

The project is no longer in an early MVP stage. The current `main` branch already provides a fairly complete multi-format mainflow and is steadily moving from a “conversion utility” toward a **general-purpose content engineering foundation**.

Current capabilities include:

* **DOCX**: heading, list, table, image, blockquote, and code-like paragraph recovery, plus hyperlink recovery in paragraphs, headings, and list items
* **PDF**: the default mainflow on `main` has been **fully replaced by a native structural recovery pipeline** based on event / span / line / block / IR reconstruction, with lightweight page-level image origin and conservative nearby-caption attachment in single-caption-like cases
* **XLSX**: worksheet-to-table output, datetime formatting, sparse-region trimming, and multi-sheet output
* **PPTX**: reading-order recovery, title/body separation, list recovery, table-like / caption-like / callout-like region handling, conservative caption-like/nearby text attachment for single-image slides (ambiguous multi-image scenes stay unmatched), plus basic run-level and shape-level hyperlink recovery
* **HTML**: lightweight DOM parsing with list / table / quote / code-block / local-container structure recovery, inline hyperlink recovery, and image context retention (`<img alt>`, `<img title>`, `<figure>`, `<figcaption>`)

The repository now provides a stable workflow built around:

**multi-format input -> unified IR -> Markdown output / asset extraction / regression validation**

## Origin Metadata (Lightweight Provenance)

The unified IR now includes a lightweight provenance layer for both blocks and exported assets:

* `Document.block_origins`: minimal block-level provenance (for example source name, page / slide / sheet, and block index)
* `Document.asset_origins`: minimal asset-level provenance (for example source name, page / slide / sheet, origin id, and nearby caption)

The current scope is intentionally lightweight traceability rather than precise anchoring. It does **not** yet include bbox / char range / source object id level metadata, and it does **not** change the Markdown main output behavior.

## Why This Project Exists

From an engineering perspective, `markitdown-mb` is increasingly suitable as a foundation for:

* multi-format content ingestion
* structured Markdown generation
* asset extraction and management
* RAG / chunking preprocessing
* lightweight provenance-aware content pipelines
* future JSON / chunk / index / audit style downstream outputs

In other words, the project is not trying to be a pixel-perfect visual reproduction engine. Its goal is to become a **reusable, testable, and extensible content processing foundation**.

## Quick Links

* [Architecture](./docs/architecture.md)
* [Format Support](./docs/format-support.md)
* [Known Limitations](./docs/limitations.md)
* [Sample Coverage](./docs/sample-coverage.md)
* [Development Guide](./docs/development.md)

## Environment Setup

### External dependencies

The normal conversion mainflow no longer depends on `pdftotext` or `mutool`.

External dependencies are currently only required for the OCR plugin path.

#### macOS (Homebrew)

```bash
brew install ocrmypdf
```

#### Linux (Ubuntu / Debian)

```bash
sudo apt update
sudo apt install -y ocrmypdf
```

### Verify

```bash
ocrmypdf --version
```

## Usage

### Normal conversion

```bash
moon run cli -- normal <input> [output]
```

### OCR conversion

```bash
moon run cli -- ocr <input> [output]
```

### Debug

```bash
moon run cli -- debug <all|extract|raw|pipeline> <input> [output]
```

## Regression

### Check sample enrollment

```bash
./samples/check_samples.sh
```

### Run full regression

```bash
./samples/diff.sh
```

### Run image regression

```bash
./samples/check_assets.sh
```


## PDF Mainflow

The PDF description on `main` should now be understood as follows:

* The default PDF mainflow is **fully native**, not “native-first” and not “external text-first”
* The normal path no longer depends on `pdftotext` or `mutool`
* The current PDF mainflow includes:

  * span normalization
  * line recovery
  * block classification
  * repeated header/footer cleanup
  * heading / paragraph boundary recovery
  * hardwrap recovery
  * pseudo two-column negative protection
* OCR remains a **plugin-style path** and is not the default `normal` flow
* External tooling is currently retained only for the OCR plugin path

## Notes

* The goal of the project is **structured content recovery and unified representation**, not pixel-perfect visual reproduction
* The PDF mainflow on `main` has already been fully replaced by native recovery logic, but complex layouts remain an active area of ongoing improvement
* Hyperlink support now covers HTML / DOCX / PPTX, where PPTX currently provides run-level plus basic single-link shape-level handling
* PPTX, HTML, and PDF are still being improved in terms of structural precision and boundary handling
* Structural changes should always be validated through regression samples before being merged

