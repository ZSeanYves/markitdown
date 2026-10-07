# Build and benchmark environment

The product conversion path is pure MoonBit and does not install Python, OCR/audio models, Tesseract, FFmpeg or Poppler. Retired multimodal installers and wrappers were removed in the 0.8 text-only migration.

Python is permitted only for reproducible build or benchmark tooling when a specific experiment records its lock file. It is never a runtime dependency.

The only managed profile is the benchmark oracle environment:

```bash
./tools/env/installers/install_bench_baseline_deps.sh [--check]
```

It installs the pinned Python package set from `config/python/bench.lock` into
`env/.venv-markitdown-bench`. The generated environment file is consumed by
benchmark comparison jobs only. OCR, audio, PDF rasterization, model download,
and system-tool profiles were retired with the text-only product boundary.
