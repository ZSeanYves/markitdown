# Environment Dependencies

This document only lists the environment commands needed for runtime use and regression checks. Pick the section that matches the capability you want to use.

- If you only need normal `balance` conversion without `audio`, install:

```bash
# macOS
xcode-select --install
brew install git python

# Ubuntu / Debian
sudo apt update
sudo apt install -y build-essential git python3 python3-pip python3-venv
```

  If you also need direct image OCR, install `tesseract`. If you also need Balanced PDF OCR, install `pdftoppm` too:

```bash
# macOS
brew install poppler tesseract tesseract-lang

# Ubuntu / Debian
sudo apt install -y poppler-utils tesseract-ocr tesseract-ocr-eng
```

- If you need `pdf --accurate`, also install `pdftoppm`, Paddle Python dependencies, and configure `MARKITDOWN_PADDLE_OCR_CMD`:

```bash
# macOS
brew install poppler
brew install python
python3 -m pip install paddlepaddle paddleocr pillow
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Run this from inside the markitdown repo."
  return 1 2>/dev/null || exit 1
}
chmod +x "$REPO_ROOT/samples/helpers/paddle_ocr_wrapper.py"
export MARKITDOWN_PADDLE_OCR_CMD="$REPO_ROOT/samples/helpers/paddle_ocr_wrapper.py"

# Ubuntu / Debian
sudo apt update
sudo apt install -y python3 python3-pip python3-venv poppler-utils
python3 -m pip install paddlepaddle paddleocr pillow
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Run this from inside the markitdown repo."
  return 1 2>/dev/null || exit 1
}
chmod +x "$REPO_ROOT/samples/helpers/paddle_ocr_wrapper.py"
export MARKITDOWN_PADDLE_OCR_CMD="$REPO_ROOT/samples/helpers/paddle_ocr_wrapper.py"
```

- If you need `audio`, install `python3`, `vosk`, one extracted local Vosk model directory, and configure the official wrapper. `wav` is the lightest path; compressed audio may also need local `ffmpeg` normalization:

```bash
# macOS
brew install ffmpeg python
python3 -m pip install vosk
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/markitdown/vosk"
# Download and extract one official Vosk model into the directory below.
mv /path/to/extracted-vosk-model "${XDG_CACHE_HOME:-$HOME/.cache}/markitdown/vosk/model"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Run this from inside the markitdown repo."
  return 1 2>/dev/null || exit 1
}
chmod +x "$REPO_ROOT/samples/helpers/audio_transcribe_wrapper.py"
export MARKITDOWN_AUDIO_CMD="$REPO_ROOT/samples/helpers/audio_transcribe_wrapper.py"
export MARKITDOWN_AUDIO_MODEL_PATH="${XDG_CACHE_HOME:-$HOME/.cache}/markitdown/vosk/model"

# Ubuntu / Debian
sudo apt update
sudo apt install -y ffmpeg python3 python3-pip python3-venv
python3 -m pip install vosk
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/markitdown/vosk"
# Download and extract one official Vosk model into the directory below.
mv /path/to/extracted-vosk-model "${XDG_CACHE_HOME:-$HOME/.cache}/markitdown/vosk/model"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Run this from inside the markitdown repo."
  return 1 2>/dev/null || exit 1
}
chmod +x "$REPO_ROOT/samples/helpers/audio_transcribe_wrapper.py"
export MARKITDOWN_AUDIO_CMD="$REPO_ROOT/samples/helpers/audio_transcribe_wrapper.py"
export MARKITDOWN_AUDIO_MODEL_PATH="${XDG_CACHE_HOME:-$HOME/.cache}/markitdown/vosk/model"
```

- If you need to run `samples/check.sh`, `samples/check_quality.sh`, or formal `bench`, also prepare the external corpus repo:

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

- If you need formal `bench`, also install the baseline `markitdown` CLI used by `official-compare`:

```bash
python3 -m pip install --upgrade pip
python3 -m pip install 'markitdown[all]'
which markitdown
```

  If you install `markitdown` inside a virtual environment, pass the binary path explicitly when you run the benchmark, for example `.venv-markitdown/bin/markitdown` via `MARKITDOWN_BIN` or `--markitdown-path`.

- Before `samples/check.sh` or `samples/check_quality.sh`, build the native CLI explicitly:

```bash
moon build cli --target native
```
