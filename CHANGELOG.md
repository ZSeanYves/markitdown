# Changelog

## Unreleased

### Documentation and evidence governance

- Rebuilt the documentation entry points around `docs/README.md`; removed the
  obsolete unreleased 0.7 migration note and separated maintained narrative
  documentation from fixture, showcase, interface, and benchmark evidence.
- Rewrote the root README and updated every package/tool README to use the
  `src/` layout, current release artifact paths, explicit stability boundaries,
  and reproducible verification commands.
- Added a blocking documentation check for local links, retired documents,
  mirrored root READMEs, stale benchmark paths/claims, and performance values
  that drift from committed trusted summaries.
- Re-ran the complete formal benchmark on Apple M4/macOS arm64 against
  Microsoft MarkItDown 0.1.7. External run
  `run-1786101654079-0f0c773a82` passed all truth, performance, and CLI RSS
  gates; self run `run-1786102949457-9591fe380a` passed all truth and CLI RSS
  gates. The self result remains a candidate because the approved baseline has
  incompatible fingerprints.

### Phase 1.5 source layout

- Made `src/` the sole MoonBit source root while preserving logical functional
  package names.
- Moved the benchmark runner to `internal/bench_runner` and cross-package tests
  to `internal/integration_tests`.
- Added an architecture gate that rejects any `moon.pkg` outside `src/` and
  updated CI, CODEOWNERS, coverage, release, environment, and governance paths.

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
- Current verified local baseline: native C and new-native each pass `907/907`;
  JS, Wasm, and Wasm-GC pass
  `481/481` each. The main balance regression passes `535/535` with no skip or
  failure.
- Current aggregate coverage gates pass at core `90.16%`, formats `82.08%`,
  and tools `72.34%`.
- `tools/release/package.py` creates deterministic local Linux/macOS archives,
  SHA-256 files, and SPDX SBOMs. The unreleased 0.8 line does not publish those
  artifacts or provide a remote release workflow.

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
- Audited Apple M4/macOS arm64 external run
  `run-1786101654079-0f0c773a82` has 25/25 comparable rows and 75/75 trusted
  tool cases. Microsoft MarkItDown 0.1.7 completed 24 rows, with five censored
  timeout samples. Performance and MoonBit CLI RSS gates both pass.
- Self run `run-1786102949457-9591fe380a` has 53/53 rows and 106/106 trusted
  CLI/engine cases. It is not compared to the existing approved baseline
  because the tool, corpus, OS/runner, and runtime fingerprints differ.

### Evidence ownership

- Small deterministic contracts remain under `samples/fixtures/contracts/`.
- Large third-party quality and benchmark inputs live in the pinned
  `markitdown-quality-lab/` repository with license, SHA-256, provenance, source
  catalog, and manifest signals.
- The external quality repository and generated runtime environments are not
  release artifacts.
