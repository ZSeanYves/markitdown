# Changelog

## Unreleased

### Phase 1 API and package boundaries

- Added the native-only `ZSeanYves/markitdown/api` façade as the sole stable
  0.8 library surface, with abstract Path/Text/Bytes/Reader input, immutable
  options, Markdown/Debug/RAG output, projected diagnostics/provenance/chunks
  and capability discovery.
- Added typed conversion errors, versioned `MID-*` codes and stable CLI exit
  classes (`2` usage, `3` input/detect, `4` conversion, `5` resource, `6`
  render/write).
- Frozen the generated 0.8 API golden and added CI checks for internal type
  leaks, dependency drift, deep-format coupling and `pub(all)` growth.
- Removed unused direct dependencies `TheWaWaR/clap` and
  `tonyfettes/unicode`; the reviewed direct dependency set is now five.
- Marked parser registries, format-reader models, pipeline contexts, IR,
  renderers and native/external runtime providers as internal or extension
  contracts, with an explicit 0.8 migration guide and ADR.

### Phase 0 governance

- Frozen the MarkItDown `v0.1.7` compatibility reference and benchmark lock.
- Added a deterministic Phase 0 inventory for MoonBit packages, public
  declarations, native FFI, generated interfaces and local fixture hashes.
- Added toolchain consistency checks, PR policy templates, CODEOWNERS, ADR/RFC
  templates, security policy, release checklist and risk register.
- Replaced legacy executable argument/process usage with
  `moonbitlang/core/env` plus native-only `runtime/process`; the complete
  `MOONBIT_NEW_NATIVE=1` suite no longer references `_moonbit_get_cli_args` and
  is a blocking macOS/Linux CI matrix.

### Product surface

- Added parser pull-stream sinks for TXT, CSV/TSV, SRT/VTT, and
  JSONL/NDJSON, plus incremental block/event Markdown rendering for all
  format families.
- Added an unbuffered sink API and native atomic CLI file writer so successful
  file output is committed only after conversion finishes. Fail-closed XML
  fences commit after sink output while true empty failures still roll back.
- `InputSource` now carries a tagged Path/Text/Bytes/Reader payload and exposes
  bounded `SourceCursor` range access for seekable PDF and package readers.
- The public conversion chain remains
  `input -> detect -> probe -> planner -> ParseResult -> pipeline or controlled
  pull stream -> renderer -> collected output or OutputSink` for CLI and
  library callers.
- Unsupported `accurate` and `stream` requests now fail closed instead of
  silently selecting a balanced/canonical route. ZIP supports balance only.
- Batch writes every task to `manifest.json`, rejects unknown formats like the
  single-file path, and returns non-zero when any task fails.
- Stdout conversion no longer emits local asset links that cannot be written;
  it emits readable placeholders and stderr diagnostics.
- `msg` remains an EML/RFC822 alias, not a native Outlook MSG implementation.

### Format and asset coverage

- Balanced parsers cover text, subtitles, delimited/structured data, notebooks,
  web/technical markup, mail, ZIP/EPUB, OOXML, ODF, and native PDF.
- Document images remain exportable assets and never enter OCR. Output-boundary
  validation covers safe paths, missing payloads, duplicate references, magic,
  hashes, and write failures.
- Native PDF exports DCT JPEG and deterministic PNG for supported decoded image
  models, with masks/alpha and resource budgets; unsupported encodings remain
  explicit diagnostics rather than fake PNG files.
- ZIP dispatch distinguishes referenced assets from standalone images. It can
  dispatch bounded native PDF/audio children and OCR standalone image children
  while preserving original assets; nested archives remain a non-goal.
- Direct image OCR supports `png/jpg/jpeg/bmp/webp/tif/tiff`. PDF accurate uses
  complete-page `pdftoppm` plus PaddleOCR and is separate from embedded assets.

### Optional runtimes

- `tools/env/optional_deps.sh` is the only recommended dependency entrypoint for
  `core`, `balance`, `audio`, `accurate`, `bench`, and `all` profiles.
- Historical profile installers moved to `tools/env/installers/` as internal
  compatibility entrypoints.
- Managed installs are locked, atomic, fingerprinted, checksum-verified, and
  stored under ignored `env/`.
- Official audio and PaddleOCR wrappers establish their deterministic child
  environment, so normal repo-root use does not require sourcing generated env
  files.

### Validation and release

- CI starts with a dependency-free MoonBit gate on Linux and macOS:
  `moon fmt --check`, `moon info && git diff --exit-code`, `moon check`, and
  `moon test`.
- Shell/Python tooling validation runs only after the core gate. Coverage,
  dependency installation, regressions, benchmarks, and self baselines run in
  later jobs.
- Current verified local baseline: native C and new-native each `901/901`;
  JS, Wasm, and Wasm-GC
  `485/485` each; `535/535` main, `409/409` quality, `21/21` accurate, and
  `54/54` deterministic mutation cases, with zero unexpected skips.
- Coverage against baseline `7be6dfbd96f93af237c37aafdd67ad126c3f85b9`
  passes at core `90.09%`, formats `81.92%`, and tools `72.21%`; changed
  production code is `82.79%` covered.
- `tools/release/package.py` creates deterministic local Linux/macOS archives,
  SHA-256 files, and SPDX SBOMs. The `0.7.0` development line does not publish
  those artifacts or provide a remote release workflow.

### Benchmark policy

- Formal benchmark presets measure balance only.
- `official-external-compare` contains semantically comparable native cases and
  enforces `2x` per case plus `3x` per-format geometric mean, route/provenance
  truth, semantic signals, and RSS budgets.
- `official-self-baseline` covers ODT/ODS/ODP and optional dependency-backed
  balance cases without a valid external comparison. Fingerprints must match and
  time/RSS may not regress beyond the configured tolerance.
- Runs support JSONL progress, atomic sample logs, checkpoints/resume, output
  retention policy, and disk budgets.
- Audited macOS 15.3 arm64 run `run-1784263977642-7cf3b18a38` has 25/25
  comparable rows and 75/75 trusted tool cases. Microsoft MarkItDown completed
  24 rows; XLSX huge is a censored timeout row. Performance and MoonBit CLI RSS
  gates both pass.

### Evidence ownership

- Small deterministic contracts remain under `samples/fixtures/contracts/`.
- Large third-party quality and benchmark inputs live in the pinned
  `markitdown-quality-lab/` repository with license, SHA-256, provenance, source
  catalog, and manifest signals.
- The external quality repository and generated runtime environments are not
  release artifacts.
