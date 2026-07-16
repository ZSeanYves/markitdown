# Environment and Optional Dependencies

The native balanced readers are dependency-free. External runtimes are optional
enhancements with explicit boundaries: top-level image OCR, audio transcription,
PDF/direct-image accurate, and Microsoft MarkItDown benchmark comparison.

## One entrypoint

Use only `tools/env/optional_deps.sh` in documentation and automation:

```bash
./tools/env/optional_deps.sh install core
./tools/env/optional_deps.sh install balance
./tools/env/optional_deps.sh install audio
./tools/env/optional_deps.sh install accurate
./tools/env/optional_deps.sh install bench
./tools/env/optional_deps.sh install all

./tools/env/optional_deps.sh check all
```

Options after the profile are forwarded to the managed installer, including
`--force`, `--python PATH`, `--no-sudo`, and audio `--model cn-small`.

The four historical installer scripts remain under `tools/env/installers/` for
compatibility only. They are not public setup entrypoints.

## Profile boundaries

### `core`

Installs nothing. It documents and verifies that TXT, structured text, markup,
mail, containers, Office/ODF, EPUB, and native balanced PDF do not require an
external runtime.

### `balance`

Installs Tesseract for top-level pure-image OCR and unreferenced standalone
image children inside balance-mode ZIP files. Images embedded in documents are
assets and never enter OCR. ZIP supports balance only.

```bash
./tools/env/optional_deps.sh install balance
./tools/env/optional_deps.sh check balance
```

### `audio`

Installs the repo-local Vosk environment, one checked model, and ffmpeg for
compressed audio normalization. It supports optional `wav`, `mp3`, and `m4a`
transcription on the balance path.

```bash
./tools/env/optional_deps.sh install audio
./tools/env/optional_deps.sh install audio --model cn-small
./tools/env/optional_deps.sh check audio
```

The official wrapper establishes `TZ`, locale, hash, and thread controls inside
its child process. Normal repo-root CLI use does not require sourcing an env
file.

### `accurate`

Installs PaddleOCR, managed models, and `pdftoppm`. Direct accurate image OCR may
fall back to Tesseract within the same supported OCR route. PDF accurate uses
complete-page `pdftoppm` rasterization followed by PaddleOCR; it is not the
native PDF reader and does not OCR embedded PDF assets.

```bash
./tools/env/optional_deps.sh install accurate
./tools/env/optional_deps.sh check accurate
```

Encrypted/password-protected PDFs and documents remain unsupported. Missing
required dependencies fail closed with installation guidance.

### `bench`

Creates the isolated Microsoft MarkItDown reference environment used by
`external_compare`. It is development tooling, not a product dependency.

```bash
./tools/env/optional_deps.sh install bench
./tools/env/optional_deps.sh check bench
```

## Managed state

Generated state lives under ignored `env/`:

- profile virtual environments;
- managed tool paths;
- downloaded and verified models;
- fingerprints and metadata;
- optional shell export files.

Installers are serialized with a lock and update managed records atomically.
Model archives are checksum-verified. A failed or interrupted install must not
be accepted by `check` as complete state.

Model downloads use four resumable HTTP range segments by default when the
server advertises range support. Stable partial files remain under
`env/downloads/models/` after an interruption, and the next `install` resumes
each segment. Set `MARKITDOWN_DOWNLOAD_SEGMENTS=1` to use one connection, or a
value up to `8` to adjust concurrency.

To prefer an internal or regional mirror, provide one or more comma-separated
base URLs. The archive filename is appended to each base and the configured
upstream remains the final fallback:

```bash
MARKITDOWN_MODEL_MIRROR_BASE_URLS=https://mirror.example/models \
  ./tools/env/optional_deps.sh install audio
```

Mirror bytes are never trusted by location: every completed archive must match
the SHA-256 locked in `tools/env/config/models.json` before it enters the cache.

To audit a clean machine:

```bash
./tools/env/reset_test_env.sh
./tools/env/optional_deps.sh check core
./tools/env/optional_deps.sh install <profile>
./tools/env/optional_deps.sh check <profile>
```

`reset_test_env.sh` deletes only ignored repo-managed `env/` state and reports
ambient tools still visible on `PATH`.

## External corpus

Formal regression and benchmark commands also require the pinned quality repo:

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git \
  markitdown-quality-lab
```

CI pins its exact commit with `MARKITDOWN_QUALITY_LAB_SHA`. The quality repo is
test evidence and is never packaged into the runtime or release archive.

## Local packaging

`tools/release/package.py` produces deterministic development archives,
SHA-256 files, and SPDX 2.3 SBOMs for Linux x64 and macOS arm64 binaries. It
does not upload artifacts, create tags, or publish releases. Keep generated
packages under an ignored local directory such as
`.tmp/local-optimization/0.7/release/`.
