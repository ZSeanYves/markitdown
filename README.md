# markitdown

Native document-to-Markdown conversion in MoonBit for text extraction, content
ingestion, and RAG preparation. The supported product platforms are Linux
x86_64 and macOS arm64. The CLI and `ZSeanYves/markitdown/lib` share the same
readers, format semantics, pipeline, and output models.

The product preserves text, structure, metadata, source locations, and document
image assets. OCR, scanned-page recognition, audio transcription, and image
recognition remain outside the text-conversion contract.

> The 0.8 candidate is unreleased. Registry installation examples apply only
> after the matching version is published and its installation is verified.
> See the [upgrade plan](docs/architecture/native-performance-plan.md) for
> remaining acceptance gates.

## Install

Use MoonBit `0.1.20261021` with `moonc v0.10.17+093cb8f9c` and a C compiler.
Install the Native CLI from a checkout:

```text
moon install --path .
markitdown balance input.docx output.md
```

For a source installation at a fixed Git commit:

```text
moon install https://github.com/ZSeanYves/markitdown.git . --rev <full-40-character-commit-sha>
```

After publication, install the exact registry version:

```text
moon install ZSeanYves/markitdown@0.8.0
```

`moon install` builds the Native executable. No separate prebuilt download is
provided. `moonx` may launch repository `.mbtx` validation scripts; product
installation and execution use the installed Native CLI. See the
[official Moon manual](https://moonbitlang.github.io/moon/commands.html#moon-install).

## Library quick start

After publication, add the exact dependency to a Native MoonBit module:

```text
moon add ZSeanYves/markitdown@0.8.0
```

Set `preferred_target = "native"` in the consumer's `moon.mod`, and import
`ZSeanYves/markitdown/lib` in its `moon.pkg`:

```mbt
async fn convert_example() -> Result[@lib.Output, @lib.ConvertError] {
  let input = @lib.Input::from_path("document.docx")
  @lib.convert(input, options=@lib.ConvertOptions::default())
}
```

The asynchronous façade accepts paths, text, bytes, and caller-owned readers.
Its output, diagnostics, provenance, source maps, assets, and RAG chunks use
façade-owned types. Reader internals, parser records, community ASTs, IR and FFI
handles remain implementation details.

## Capabilities

| Input family | Native conversion contract |
| --- | --- |
| Plain and structured text | TXT, CSV/TSV, JSON/JSONL, YAML and TOML |
| Markup | Markdown, HTML, XML, TeX, RST and AsciiDoc |
| Containers and messages | MIME/EML, ZIP and EPUB |
| Office and ODF | DOCX, XLSX, PPTX, ODT, ODS and ODP |
| PDF | Bounded text-layer extraction, geometry, links and supported image assets |
| Document images | Exported assets when safely recoverable |

The complete format matrix, mode boundaries, existing resource limits and
failure diagnostics are in [Capabilities and limitations](docs/capabilities-and-limitations.md).
A PDF without a recoverable text layer returns an explicit diagnostic.

- `balance` is the default conversion mode.
- `accurate` enables additional Office/ODF semantic recovery and declared PDF
  text policies.
- `stream` is accepted only by formats with a declared streaming route; it
  preserves the format's promised meaning.
- Markdown is the default output. Debug, RAG, provenance, source maps and
  materialized assets are available at the output boundary.

Unsupported formats and modes return domain errors. No conversion launches an
external recognizer or downloads a model.

## Native migration

Consumers upgrading to this candidate must select the Native backend and build
on Linux x86_64 or macOS arm64. Wasm, Wasm-GC and JavaScript product targets are
retired. Replace product `moonx` invocations with `moon install` followed by the
installed CLI. The public asynchronous `lib` façade and existing input
constructors remain the integration boundary. CP932 decoding uses host iconv;
missing encoding support produces an error.

## Validation

Run checkout checks in serialized order:

```text
moon check --target native --warn-list +73 --deny-warn
moon test --target native --no-parallelize
moon test --target native --release --no-parallelize
moon build --target native --release .
moon info
moon fmt
```

The Native regression runner tests an actual installed or frozen executable
against the pinned quality-lab corpus. Each run needs a new evidence directory:

```text
moon run tools/regression/run_native_regression.mbtx --binary /absolute/path/to/markitdown --lab /absolute/path/to/markitdown-quality-lab --suite all --evidence /absolute/path/to/new-evidence
```

`tools/regression/native_install.mbtx` checks installation and an independent
module importing the public library:

```text
moon run --target native tools/regression/native_install.mbtx --source local --root /absolute/path/to/markitdown --evidence /absolute/path/to/new-install-evidence
```

See [regression tooling](tools/regression/README.md) for pinned Git and exact
published-version checks and saved evidence.

These commands produce evidence when executed; source configuration alone is
not an installation, platform, performance or release acceptance result.
Repository automation is `.mbtx`; see [Contributing](CONTRIBUTING.md).

## Repository layout

```text
main.mbt       thin executable composition root
lib/           stable façade and shared product packages
internal/      CLI, readers, registry, pipeline, runtime, and tests
tools/         regression and benchmark entrypoints (.mbtx only)
samples/       deterministic fixtures and reviewed examples
docs/          capabilities, API, architecture, migration, and release docs
```

See the [CLI guide](docs/cli-usage-guide.md), [showcase](samples/showcase/README.md),
[API example](docs/api-v0.8.md), and [documentation index](docs/README.md).

## License

Apache-2.0. See [LICENSE](LICENSE).
