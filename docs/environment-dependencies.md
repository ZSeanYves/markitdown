# Environment Dependencies

This repo now provides stable setup scripts for the three runtime dependency groups we actually use.

Python dependencies are installed into a repo-local virtualenv under `./env/`.
Native tools such as `tesseract`, `pdftoppm`, and `ffmpeg` still come from your
system package manager because markitdown invokes those binaries directly.

Pick the script that matches the capability you want:

## 1. Balanced OCR / Balanced PDF OCR

Use this when you need:

- direct image OCR in `balance`
- PDF OCR in `balance`

Run:

```bash
./samples/env/install_ocr_pdf_balance_deps.sh
```

This installs the local runtime pieces needed for:

- `tesseract`
- `pdftoppm`

No extra markitdown environment variable is required after it finishes.

## 2. Accurate OCR / Accurate PDF OCR

Use this when you need:

- direct image OCR in `accurate`
- PDF OCR in `accurate`

Run:

```bash
./samples/env/install_ocr_pdf_accurate_deps.sh
```

If you run `markitdown` from the repo root, that is enough: the runtime auto-detects the repo-local virtualenv and wrapper.
Use `source ./env/accurate-ocr-pdf.env.sh` only when you want those paths exported into another shell.

This installs:

- `pdftoppm`
- `paddlepaddle`
- `paddleocr`
- `pillow`

The Python packages above are installed into the repo-local virtualenv at
`./env/.venv-markitdown-runtime`, not into your global Python environment.

It also writes a stable env file that exports:

- `MARKITDOWN_PADDLE_OCR_CMD`

## 3. Audio

Use this when you need:

- `wav`
- `mp3`
- `m4a`

Run:

```bash
./samples/env/install_audio_deps.sh
```

If you specifically want the small Chinese Vosk model instead of the default small English model:

```bash
./samples/env/install_audio_deps.sh --model cn-small
```

If you run `markitdown` from the repo root, that is enough: the runtime prefers the repo-local virtualenv automatically.
Use `source ./env/audio.env.sh` only when you want those paths exported into another shell.

This installs:

- `ffmpeg`
- `unzip`
- `vosk`
- one local Vosk model

The Python packages above are installed into the repo-local virtualenv at
`./env/.venv-markitdown-runtime`, not into your global Python environment.

It also writes a stable env file that exports:

- `MARKITDOWN_AUDIO_CMD`
- `MARKITDOWN_AUDIO_MODEL_PATH`

## 4. External Regression Corpus

If you need `samples/check_balance.sh`, `samples/check_balance_quality.sh`, or `samples/check_accurate.sh` against the external lab corpora:

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

## 5. Benchmark Baseline

If you need formal `bench`, also install the baseline Python `markitdown` CLI:

```bash
python3 -m pip install --upgrade pip
python3 -m pip install 'markitdown[all]'
which markitdown
```

If that binary lives inside a virtual environment, pass it explicitly later through `MARKITDOWN_BIN` or `--markitdown-path`.

## 6. Build Before Checks

Before `samples/check_balance.sh`, `samples/check_balance_quality.sh`, or `samples/check_accurate.sh`, build the native CLI:

```bash
moon build cli --target native
```
