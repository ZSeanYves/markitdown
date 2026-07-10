# Environment Dependencies

This repository now provides script-based setup for runtime dependencies. In most cases, you only need to run the matching script from the repo root, and it will prepare the environment automatically.

These scripts do a few things:

- Install local command dependencies through the system package manager.
- Create or reuse a repo-local Python virtual environment under `./env/`.
- Record repo-managed absolute paths under `./env/managed-paths/` so repo-root runs can prefer those paths first.
- Generate optional `env/*.env.sh` files; if you run the CLI from the repo root, you usually do not need to `source` them manually.

The current install scripts support Homebrew and `apt-get`.

## 1. Direct Image OCR (`balance`)

Use this when you need:

- direct image OCR on the main product path

Run:

```bash
./tools/env/install_ocr_balance_deps.sh
```

This script installs or records:

- `tesseract`
- `./env/managed-paths/tesseract`

No extra environment variables are usually required after it finishes.

## 2. Accurate Image OCR And Accurate PDF OCR

Use this when you need:

- direct image OCR in `accurate`
- PDF OCR in `accurate`

Run:

```bash
./tools/env/install_ocr_pdf_accurate_deps.sh
```

This script automatically prepares:

- `tesseract`
- `pdftoppm` from `poppler` / `poppler-utils`
- a repo-local Python runtime and virtual environment
- `paddlepaddle`
- `paddleocr`
- `pillow`

It also writes:

- `./env/managed-paths/tesseract`
- `./env/managed-paths/pdftoppm`
- `./env/accurate-ocr-pdf.env.sh`

If you run the CLI from the repo root, running the script is usually enough. Only `source` the env file when you want to export those paths into another shell:

```bash
source ./env/accurate-ocr-pdf.env.sh
```

## 3. Audio / Media

Use this when you need:

- `wav`
- `mp3`
- `m4a`

Run:

```bash
./tools/env/install_audio_deps.sh
```

If you want the small Chinese model:

```bash
./tools/env/install_audio_deps.sh --model cn-small
```

This script automatically prepares:

- `ffmpeg`
- `unzip`
- a repo-local Python runtime and virtual environment
- `vosk`
- one local Vosk model

It also writes:

- `./env/managed-paths/ffmpeg`
- `./env/audio.env.sh`

If you run the CLI from the repo root, running the script is usually enough. Only `source` the env file when you want to export those paths into another shell:

```bash
source ./env/audio.env.sh
```

## 4. Official `markitdown` For Benchmark Comparison

If you need formal benchmark runs, or you need a local baseline `markitdown` CLI:

```bash
./tools/env/install_bench_baseline_deps.sh
```

This script installs the following under `./env/`:

- `markitdown[all]`

It also writes:

- `./env/bench-baseline.env.sh`
- the repo-local `markitdown` executable path exported through `MARKITDOWN_BIN`

If you run the benchmark runner from the repo root, it will usually auto-detect this repo-local `markitdown` without extra manual setup.

## 5. External Corpus And Benchmark Sample Repository

If you need external-corpus validation scripts, or if you need formal benchmark runs, clone the external repository:

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

To be explicit, `markitdown-quality-lab` is not only the home of external regression corpora; it also carries the sample payloads and manifests used by formal bench runs.

It currently serves both of these purposes:

- main regression and quality-regression scripts such as `tools/regression/check_balance.sh`, `tools/regression/check_balance_quality.sh`, and `tools/regression/check_accurate.sh`
- external benchmark samples and manifests used by formal benchmark runs

When running from the repo root, the official expected location is:

```text
./markitdown-quality-lab/
```

## 6. Build The CLI Before Checks

Before running the various validation scripts, build the native CLI first:

```bash
moon build cli --target native
```

## 7. Custom Installation Notes

Besides the provided setup scripts, users can still install and configure dependencies manually by following the relevant official documentation. If you do that, make sure the CLI can discover the required commands or paths through the expected runtime conventions or environment variables.
