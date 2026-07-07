# CLI Usage Guide

This document covers the day-to-day usage of the main CLI. Read [environment-dependencies.md](./environment-dependencies.md) first.

> `pdf --accurate` is still dependency-heavy. `audio` remains available on the main CLI, but it now depends on an optional local transcript backend with a deliberately narrow support contract.

## 1. Build And Help

```bash
moon build cli --target native
./_build/native/debug/build/cli/cli.exe --help
```

## 2. Basic Usage

Single file:

```bash
./_build/native/debug/build/cli/cli.exe normal samples/fixtures/contracts/txt/txt_plain.txt .tmp/manual/out.md
```

Batch:

```bash
./_build/native/debug/build/cli/cli.exe batch samples/fixtures/contracts .tmp/batch-out
```

Explicit format:

```bash
./_build/native/debug/build/cli/cli.exe normal --format pdf samples/fixtures/contracts/pdf/text_simple.pdf .tmp/manual/pdf.md
```

Write provenance:

```bash
./_build/native/debug/build/cli/cli.exe normal --provenance-out .tmp/manual/result.provenance.json samples/fixtures/contracts/txt/txt_plain.txt .tmp/manual/out.md
```

## 3. Output Modes

Default output is Markdown.

Debug JSON:

```bash
./_build/native/debug/build/cli/cli.exe normal --debug samples/fixtures/contracts/html/html_simple.html
```

RAG JSON:

```bash
./_build/native/debug/build/cli/cli.exe normal --rag samples/fixtures/contracts/html/html_simple.html
```

## 4. `balance`, `accurate`, And `stream`

- The default mode is `balance`
- `--accurate` requests higher-fidelity behavior
- `--stream` requests a streaming or block-streaming route

Examples:

```bash
./_build/native/debug/build/cli/cli.exe normal --accurate samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf .tmp/manual/pdf-accurate.md
./_build/native/debug/build/cli/cli.exe normal --stream samples/fixtures/contracts/html/html_semantic_sectioning.html .tmp/manual/html-stream.md
```

Current behavior:

- If a format does not support `--accurate`, the CLI emits a warning and falls back to `balance`
- If a format does not support `--stream`, the CLI emits a warning and falls back to the canonical route
- Provenance keeps both the requested behavior and the effective route

## 5. PDF

Normal PDF conversion:

```bash
./_build/native/debug/build/cli/cli.exe normal samples/fixtures/contracts/pdf/text_simple.pdf .tmp/manual/pdf.md
```

Explicit Balanced PDF OCR:

```bash
./_build/native/debug/build/cli/cli.exe normal --ocr samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf .tmp/manual/pdf-ocr.md
./_build/native/debug/build/cli/cli.exe normal --pdf-ocr explicit samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf .tmp/manual/pdf-ocr-explicit.md
```

OCR only for scanned-like pages:

```bash
./_build/native/debug/build/cli/cli.exe normal --pdf-ocr auto-scanned samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf .tmp/manual/pdf-auto-scanned.md
```

Request Accurate PDF:

```bash
./_build/native/debug/build/cli/cli.exe normal --accurate samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf .tmp/manual/pdf-accurate.md
```

Current behavior:

- `pdf --accurate` first runs scanned-like probing and only enters Accurate PDF OCR when the upgrade is justified
- If Accurate PDF OCR is missing Paddle dependencies, it reports the missing dependency
- It then falls back to Balanced PDF OCR
- Balanced PDF OCR still requires local `pdftoppm` and `tesseract`

Optional PDF knobs:

```bash
./_build/native/debug/build/cli/cli.exe normal --pdf-cleanup conservative samples/fixtures/contracts/pdf/text_simple.pdf .tmp/manual/pdf-cleanup.md
./_build/native/debug/build/cli/cli.exe normal --pdf-tables simple samples/fixtures/contracts/pdf/text_simple.pdf .tmp/manual/pdf-tables.md
```

## 6. Direct Image OCR

Image input uses OCR by default:

```bash
./_build/native/debug/build/cli/cli.exe normal samples/fixtures/contracts/ocr/ocr_tiny_png.png .tmp/manual/ocr.md
```

Disable OCR:

```bash
./_build/native/debug/build/cli/cli.exe normal --no-ocr samples/fixtures/contracts/ocr/ocr_tiny_png.png .tmp/manual/ocr-disabled.md
```

Set OCR language:

```bash
./_build/native/debug/build/cli/cli.exe normal --ocr-lang chi_sim samples/fixtures/contracts/ocr/ocr_tiny_png.png .tmp/manual/ocr-chi.md
```

Notes:

- Balanced image OCR uses local `tesseract`
- Accurate image OCR is still experimental
- If Accurate image OCR is missing Paddle dependencies, it reports the missing dependency and falls back to Balanced image OCR

## 7. Audio

Audio input currently supports `wav/mp3/m4a`:

```bash
./_build/native/debug/build/cli/cli.exe normal samples/fixtures/contracts/audio/contract.wav .tmp/manual/audio.md
./_build/native/debug/build/cli/cli.exe normal --audio-lang zh samples/fixtures/contracts/audio/contract.mp3 .tmp/manual/audio-zh.md
```

Notes:

- `audio` stays on the main CLI, but it now runs through an optional local transcript backend with a deliberately narrow contract
- By default the runtime uses `samples/helpers/audio_transcribe_wrapper.py`; set `MARKITDOWN_AUDIO_CMD` only when you need to override that wrapper
- Set `MARKITDOWN_AUDIO_MODEL_PATH` to the extracted local Vosk model directory
- Compressed audio may depend on local `ffmpeg`
- `audio` does not support `--accurate` today; if requested, it emits a warning and falls back to `balance`

## 8. Common Examples

DOCX:

```bash
./_build/native/debug/build/cli/cli.exe normal samples/fixtures/contracts/docx/docx_textbox_basic.docx .tmp/manual/docx.md
```

XLSX:

```bash
./_build/native/debug/build/cli/cli.exe normal samples/fixtures/contracts/xlsx/sheet_simple.xlsx .tmp/manual/xlsx.md
```

HTML debug:

```bash
./_build/native/debug/build/cli/cli.exe normal --debug samples/fixtures/contracts/html/html_simple.html
```

Batch:

```bash
./_build/native/debug/build/cli/cli.exe batch samples/fixtures/contracts .tmp/batch-out
```

## 9. What To Check First When Something Fails

- First confirm dependencies are installed as described in [environment-dependencies.md](./environment-dependencies.md)
- Then check CLI stderr
- If you need the real execution route, add `--provenance-out`
- For Accurate PDF OCR or Accurate image OCR, check `MARKITDOWN_PADDLE_OCR_CMD` first
- For audio, check `MARKITDOWN_AUDIO_CMD`, the local Vosk model directory configured through `MARKITDOWN_AUDIO_MODEL_PATH`, and `ffmpeg` when compressed audio needs normalization
