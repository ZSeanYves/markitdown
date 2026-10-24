# markitdown

Native document-to-Markdown conversion in MoonBit for text extraction, content
ingestion and RAG preparation. Supports Linux x86_64 and macOS arm64, with a
command-line tool and the `ZSeanYves/markitdown/lib` library.

## Features

- [x] Text and data: TXT, CSV/TSV, JSON/JSONL/NDJSON, YAML, TOML, IPYNB and
  SRT/VTT subtitles.
- [x] Markup: Markdown, HTML, XML, TeX, RST and AsciiDoc.
- [x] Office documents: DOCX, XLSX, PPTX, ODT, ODS and ODP.
- [x] Containers and messages: ZIP, EPUB and MIME/EML.
- [x] PDF text-layer extraction, layout information, links and supported
  document image assets.
- [x] Markdown, debug JSON and RAG output, with metadata, source locations,
  provenance and recoverable image assets.
- [x] Single-file, batch and stdin conversion; asynchronous library conversion
  from paths, text, bytes and readers.

`balance` is the default mode. `accurate` enables additional Office/ODF
semantics and PDF text processing. `stream` is available only for formats with
a supported streaming route; ZIP accepts `balance` only. OCR, scanned-page
recognition, audio transcription and image recognition are not supported.

## Install and use

Requires MoonBit `0.1.20261021` (`moonc v0.10.17+093cb8f9c`) and a C compiler.
Install the Native CLI:

```sh
moon install ZSeanYves/markitdown@0.8.0
```

Ensure MoonBit's executable directory is on your `PATH`, then convert a file:

```sh
markitdown input.docx output.md
markitdown accurate input.pdf output.md
markitdown --rag input.pdf chunks.json
markitdown batch balance input_dir output_dir
cat input.jsonl | markitdown --format jsonl - output.md
```

Omit the output path to write to stdout. Use `--format` to specify the input
format, `--provenance-out provenance.json` to save single-file provenance,
and `--max-temporary-bytes <bytes>` to cap conversion spool storage.

```sh
markitdown --help
markitdown --capabilities
```

### Library usage

Add the library dependency from your consumer directory:

```sh
moon add ZSeanYves/markitdown@0.8.0
```

Set `preferred_target = "native"` in `moon.mod` and import
`ZSeanYves/markitdown/lib` in `moon.pkg`:

```mbt
async fn convert_example() -> Result[@lib.Output, @lib.ConvertError] {
  let input = @lib.Input::from_path("document.docx")
  @lib.convert(input)
}
```
