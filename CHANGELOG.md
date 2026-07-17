# Changelog

- Added parser pull-stream sinks for TXT, CSV/TSV, SRT/VTT, and
  JSONL/NDJSON, plus incremental block/event Markdown rendering for all
  format families.
- Added an unbuffered sink API and native atomic CLI file writer so successful
  file output is committed only after conversion finishes.

## Unreleased

### Product surface

- The public conversion chain remains
  `input -> detect -> probe -> planner -> parse -> pipeline -> render` for CLI
  and library callers.
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
- Current verified local baseline: native `855/855`; JS, Wasm, and Wasm-GC
  `472/472` each; `535/535` main, `380/380` quality, and `21/21` accurate
  regression rows, with zero unexpected skips.
- Coverage thresholds currently pass at core `90.09%`, formats `81.78%`, and
  tools `72.26%`; changed production code is `82.73%` covered.
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

### Evidence ownership

- Small deterministic contracts remain under `samples/fixtures/contracts/`.
- Large third-party quality and benchmark inputs live in the pinned
  `markitdown-quality-lab/` repository with license, SHA-256, provenance, source
  catalog, and manifest signals.
- The external quality repository and generated runtime environments are not
  release artifacts.
