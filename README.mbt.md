# markitdown-mb

A document conversion tool implemented in **MoonBit**, inspired by Microsoft **markitdown**, for converting **DOCX / PDF / XLSX / PPTX / HTML** into structured **Markdown** with extracted assets.

Supports **macOS** and **Linux**.

The project is built around a unified:

**document -> IR -> Markdown**

pipeline, with format-specific parsers and sample-based regression coverage.

## Quick Links

* [Format Support](./docs/format-support.md)
* [Architecture](./docs/architecture.md)
* [Sample Coverage](./docs/sample-coverage.md)
* [Known Limitations](./docs/limitations.md)
* [Development Guide](./docs/development.md)

## Environment Setup

### External dependencies

#### macOS (Homebrew)

```bash
brew install poppler mupdf-tools ocrmypdf
```

#### Linux (Ubuntu / Debian)

```bash
sudo apt update
sudo apt install -y poppler-utils mupdf-tools ocrmypdf
```

#### Verify

```bash
pdftotext -v
mutool -v
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

## Notes

* PDF on `main` currently uses an **external text-first pipeline**
* OCR is a **dedicated path**, not the default normal flow
* Detailed format behavior, coverage, and boundaries are documented in the files linke
