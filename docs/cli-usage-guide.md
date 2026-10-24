# Native CLI usage guide

The CLI supports Linux x86_64 and macOS arm64. Install with `moon install`;
the product does not run as a Wasm/MoonX package. See
[environment requirements](environment-dependencies.md).

## Install and inspect

From a checkout:

```text
moon install --path .
markitdown --help
markitdown --version
markitdown --capabilities
```

A source build for local development is also available:

```text
moon build --target native --release .
./_build/native/release/build/markitdown.exe --help
```

For installation from a fixed Git SHA or a published exact version, see the
[README](../README.md). Local builds, installed candidates and published
versions provide different acceptance evidence.

## Syntax

Single file:

```text
markitdown [balance|accurate|stream] [--format <format>] [--debug|--rag] [--provenance-out <path>] [--max-temporary-bytes <bytes>] <input> [output]
```

Batch:

```text
markitdown batch [balance|accurate|stream] [--format <format>] [--debug|--rag] [--max-temporary-bytes <bytes>] <input> <output_dir>
```

Omitting the mode selects `balance`. Use `-` as input with an explicit
`--format` for stdin. Removed `convert`, `normal`, `--accurate`,
`--stream` and recognition flags are usage errors.

## Examples

```text
markitdown balance input.docx output.md
markitdown balance --format pdf input.pdf output.md
markitdown accurate input.xlsx output.md
markitdown balance --debug input.html output.debug.json
markitdown balance --rag input.html output.rag.json
markitdown balance --provenance-out provenance.json input.txt output.md
markitdown balance --format txt - output.md
markitdown batch balance input-directory output-directory
```

`--debug` and `--rag` are mutually exclusive. `--provenance-out` is
single-file only; batch writes `manifest.json`.

`--max-temporary-bytes N` enables a finite JSONL/NDJSON parser-spool ceiling for
each conversion. N must be nonnegative decimal Int64 bytes; both space and
`--max-temporary-bytes=N` forms are accepted. There is no suffix/hex/underscore
grammar. A negative value, overflow or missing value is usage exit2; actual
temporary exhaustion is resource exit5 with kind `temporary_bytes`. Zero allows
empty storage but forbids payload growth. Omit the option for the compatibility
route. Batch applies the same requested value separately to each input's account,
not to the whole batch total.

This ceiling counts registered parser-spool UTF8/frame bytes, not all disk
activity. The atomic-output temporary sibling described below is not yet charged
to it. Ordinary malformed-grammar recovery can still collect full raw text;
input/encoding/budget/cleanup failures cannot use that fallback. Final IR/RAG and
metadata may remain resident. This transitional option does not establish full
P2 bounded memory or finite production defaults.

## Output and assets

Omitting the single-file output path writes to stdout. Stdout has no asset
directory, so unresolved local image references become readable placeholders
with diagnostics on stderr. File output materializes safe recoverable assets;
do not discard its stderr/provenance when checking extraction quality.

The existing Markdown file Sink applies to TXT, CSV/TSV, SRT/VTT,
JSON/JSONL/NDJSON, XML, YAML and TOML. It writes a temporary sibling and commits
by rename after conversion and Sink completion. Write, asset and empty-failure
paths abort the temporary file. Other paths may collect before persistence.
This existing route does not certify end-to-end bounded memory or completion
of P2's public Sink and resource-lifetime work.

Batch is serial, records every task outcome in its manifest and returns
nonzero if a task fails. Outputs use `.md`, `.debug.json` or `.rag.json`
for the selected view. Single-file write/commit or asset-persistence failures
also return nonzero.

## Modes and PDF

- `balance` is the default semantic route.
- `accurate` enables declared additional Office/ODF semantics and PDF text
  policies.
- `stream` is available only where the format declares it and preserves
  promised output meaning.
- Unsupported mode/format combinations fail explicitly. Provenance records
  the requested mode and effective route.

See the [capability matrix](capabilities-and-limitations.md) for exact formats.
ZIP accepts balance only. PDF requires recoverable text and never starts OCR.
Image-only pages, encrypted input and unsupported content retain explicit
diagnostics. Top-level recognition inputs return an unsupported capability.

## Troubleshooting and validation

Read stderr and the per-file/batch outcome before interpreting an output.
Use `--provenance-out` to inspect routing, or Debug/RAG views to inspect
structure. A small readable Markdown result does not prove full extraction.

Run [Native regression tooling](../tools/regression/README.md) against the
actual installed executable. It records output channels and asset hashes
separately. The old `moonx_benchmark.mbtx` is retired.

The [Native plan](architecture/native-performance-plan.md) still requires
P2–P4 implementation gates, P5 full cross-platform quality/performance/load
acceptance and P6 exact-version post-publication confirmation. CLI smoke and
current local unit tests do not complete those gates.
