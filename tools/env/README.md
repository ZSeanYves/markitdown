# Managed Env

`tools/env/` owns the repository-managed runtime setup for optional OCR, audio,
and benchmark dependencies.

Primary entrypoints:

```bash
./tools/env/install_ocr_balance_deps.sh
./tools/env/install_audio_deps.sh
./tools/env/install_ocr_pdf_accurate_deps.sh
./tools/env/install_bench_baseline_deps.sh
```

What this toolchain manages:

- system tools such as `tesseract`, `pdftoppm`, and `ffmpeg`
- profile-specific repo-local virtualenvs under `./env/`
- pinned Python lockfiles under `tools/env/config/python/`
- managed model downloads with checksum and metadata validation
- generated env files and structured fingerprints under `./env/`

Useful helpers:

```bash
bash ./tools/env/share/test_env_preflight.sh
./tools/env/install_audio_deps.sh --check
./tools/env/install_ocr_pdf_accurate_deps.sh --check
```

Generated state remains under `./env/`; `tools/env/` only contains source and
configuration.
