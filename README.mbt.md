# markitdown-mb for MoonBit Developers

This file is the short developer entrypoint for the active repository layout.
The canonical architecture reference is
[docs/architecture/mb-markitdown-architecture.md](./docs/architecture/mb-markitdown-architecture.md).

## Start Here

- Product overview: [README.md](./README.md)
- Architecture book:
  [docs/architecture/mb-markitdown-architecture.md](./docs/architecture/mb-markitdown-architecture.md)
- Repo-local samples: [samples/README.md](./samples/README.md)
- Test package notes: [tests/README.md](./tests/README.md)

## Current Pipeline

The active product path is:

```text
input -> FormatDetector -> ParserRegistry -> ParseResult -> Core IR -> Renderer
```

Key boundaries:

- `input` owns source loading and format detection.
- `parser` owns parser contracts such as `ParserMode`, `ParseContext`, and
  `ParserRegistry`.
- `formats` exposes product parsers.
- `format_readers` stays below the parser layer and does not render Markdown.
- `runtime` lowers `ParseResult` into IR input and supports child dispatch.
- `pipeline` owns Core IR passes.
- `render` owns Markdown and debug JSON output.
- `convert` orchestrates the full conversion flow.

## Supported Main-CLI Formats

The current main CLI supports:

- `txt`, `csv`, `tsv`
- `json`, `jsonl`, `ndjson`
- `xml`, `yaml`, `html`, `markdown`
- `zip`, `epub`
- `docx`, `xlsx`, `pptx`
- `pdf` for native-text PDFs

Fail-closed boundaries:

- scanned or image-only PDFs
- `pdf --ocr`
- unsupported formats
- default image inputs without explicit `--ocr`

## Core Commands

```bash
moon fmt
moon info
moon check
moon build
moon test
moon test tests
bash samples/check.sh
bash samples/check.sh --check-inventory
bash samples/check_quality.sh
bash samples/helpers/contracts/check_root_contracts.sh
```

## Package Map

| Package | Responsibility |
| --- | --- |
| `core` | Core IR, diagnostics, source refs, assets |
| `input` | `InputSource` and format detection |
| `parser` | parser contracts and registry |
| `format_readers` | low-level readers and shared foundations |
| `formats` | registry-facing product parsers |
| `container` | container guardrails and helper contracts |
| `runtime` | parse-result lowering and child conversion helpers |
| `pipeline` | IR builder and pass pipeline |
| `render` | renderers |
| `convert` | end-to-end conversion orchestration |
| `cli` | product CLI shell |

## Notes

- `Renderer` owns Markdown syntax. Parsers do not emit final Markdown.
- `Core IR` is the stable interchange point between parsing and rendering.
- `samples/check.sh` is the main repo-local regression entrypoint.
- `samples/check_quality.sh` is the external quality bridge and expects the
  optional repo-root `markitdown-quality-lab/`.
