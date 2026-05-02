# markitdown-mb

`markitdown-mb` is a MoonBit-native multi-format document-to-Markdown
converter for local document structure extraction, RAG ingestion, and
knowledge-base import.

It follows the broad product direction of Microsoft MarkItDown, but focuses on
native local execution, conservative degradation, explainable provenance, and
checked-in quality and benchmark evidence.

Current pipeline:

**multi-format input -> unified IR -> Markdown / assets / metadata sidecar**

## Current Status

| Format | Status | Quality scope | Performance evidence | Key boundaries |
| --- | --- | --- | --- | --- |
| DOCX | H2++ complete | checked-in native overlap records | H3++ evidence-backed on checked-in native overlap corpus | not a Word layout engine; no full tracked-changes UI |
| PPTX | H2++ complete | checked-in native overlap records | H3++ evidence-backed on checked-in native overlap corpus | not a PowerPoint layout engine; no animations, SmartArt, chart, or OLE rendering |
| XLSX | H2++ complete | checked-in native overlap records | H3++ evidence-backed on checked-in native overlap corpus | no full Excel formula engine; no visual merged-cell reconstruction |
| PDF | H2++ complete for native text-PDF scope | checked-in native text-PDF records | H3++ evidence-backed on checked-in native text-PDF corpus | no scanned/OCR default claim; no full PDF layout engine |
| HTML / HTM | H2++ complete | checked-in native overlap records | H3++ evidence-backed on checked-in native overlap corpus | not browser-grade; no JS, CSS layout, or remote fetch |
| ZIP | H2++ complete | checked-in native corpus records | H3++ evidence-backed on checked-in native corpus | no nested archive recursion; no ZIP64/encrypted/data-descriptor support |
| EPUB | H2++ complete | checked-in native EPUB records | H3++ evidence-backed on checked-in native EPUB corpus | no DRM, CSS, JS, or remote fetch |
| CSV / TSV | H2 main-path quality | checked-in main-path regression | smoke and batch evidence only | no streaming or huge-table performance claim |
| JSON | H2 main-path quality | checked-in main-path regression | smoke and batch evidence only | conservative structured-data lowering |
| YAML / YML | subset-H2 | conservative subset only | smoke evidence only | not full YAML 1.2 |
| XML | source-preserving H1/H2 partial | safe fenced-source contract | smoke evidence only | not a semantic XML-family converter |
| Markdown | H2 main-path quality | passthrough contract | smoke evidence only | not a Markdown AST semantic converter |
| TXT | H2 main-path quality | literal-safe text path | smoke evidence only | no inferred heading/list/table semantics |

Benchmark and quality conclusions are always limited to the checked-in corpora
named in the relevant docs. They are not blanket claims about all documents of
that format.

## Core Capabilities

* unified IR across document families
* Markdown main output
* `assets/` export for materialized local images
* metadata sidecar via `--with-metadata`
* batch conversion with isolated per-document roots
* checked-in quality comparison records
* benchmark governance and checked-in benchmark corpora
* prebuilt-native runner preference for validation and benchmark work

## CLI

Build the native product-path binary:

```bash
moon build --target native
```

Recommended invocation:

```bash
./_build/native/debug/build/cli/cli.exe normal <input> [output]
```

With metadata sidecar:

```bash
./_build/native/debug/build/cli/cli.exe normal --with-metadata <input> <output.md>
```

Batch conversion:

```bash
./_build/native/debug/build/cli/cli.exe batch <input_dir> <output_dir>
./_build/native/debug/build/cli/cli.exe batch --with-metadata <input_dir> <output_dir>
```

Debug and OCR entrypoints remain explicit non-default paths:

```bash
./_build/native/debug/build/cli/cli.exe debug <all|extract|raw|pipeline> <input> [output]
./_build/native/debug/build/cli/cli.exe ocr <input> [output]
```

Development fallback:

```bash
moon run cli -- normal <input> [output]
```

`moon run` is a functional fallback for development. It is not the preferred
runner for H3++ performance conclusions.

## Validation

Recommended repository verification:

```bash
moon build --target native
moon check
moon test
./samples/check.sh
./samples/scripts/bench_smoke.sh --kind smoke
```

Useful additional checks:

```bash
./samples/check_main_process.sh
./samples/check_metadata.sh
./samples/check_assets.sh
./samples/scripts/check_cli_contract.sh
./samples/scripts/check_batch_contract.sh
./samples/scripts/check_corpus_manifest.sh
```

## Benchmark Notes

* prebuilt native CLI is the product performance path
* `moon run` is fallback and should be read as wrapper-inflated timing
* raw benchmark facts live in `results.jsonl`
* TSV summaries are generated per suite
* overlap comparison with Microsoft MarkItDown is sample-scoped and may be
  `not_comparable`
* OCR, cloud, plugin, and scanned-PDF paths are outside the default local H3++
  story

See [samples/benchmark/README.md](./samples/benchmark/README.md) and
[docs/benchmark-governance.md](./docs/benchmark-governance.md) for corpus,
runner, and comparability rules.

## Documentation

* [Support and Limits](./docs/support-and-limits.md)
* [Second-Round Summary](./docs/second-round-summary.md)
* [Format Excellence Roadmap](./docs/format-excellence-roadmap.md)
* [Second-Round Hardening Audit](./docs/second-round-hardening-audit.md)
* [PDF H2++ Readiness Audit](./docs/pdf-h2pp-readiness-audit.md)
* [Benchmark Governance](./docs/benchmark-governance.md)
* [Quality Comparisons](./docs/quality-comparisons/README.md)
* [Benchmark Corpus Policy](./samples/benchmark/README.md)
* [Progress Summary](./docs/progress.md)
* [Architecture Overview](./docs/architecture.md)
* [Development Guide](./docs/development.md)

## Non-goals

`markitdown-mb` does not aim to be:

* a Word, PowerPoint, or PDF visual layout engine
* a browser-grade HTML renderer
* an OCR-first default converter
* a DRM/CSS/JS/remote-fetch pipeline
* a full Excel formula engine
* a benchmark claim beyond the checked-in corpora
