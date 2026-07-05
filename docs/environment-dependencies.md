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
chmod +x samples/helpers/paddle_ocr_wrapper.py
export MARKITDOWN_PADDLE_OCR_CMD="$PWD/samples/helpers/paddle_ocr_wrapper.py"

# Ubuntu / Debian
sudo apt update
sudo apt install -y python3 python3-pip python3-venv poppler-utils
python3 -m pip install paddlepaddle paddleocr pillow
chmod +x samples/helpers/paddle_ocr_wrapper.py
export MARKITDOWN_PADDLE_OCR_CMD="$PWD/samples/helpers/paddle_ocr_wrapper.py"
```

- If you need `audio`, install `ffmpeg`, build local `whisper.cpp`, download `ggml-base.bin`, and configure `MARKITDOWN_AUDIO_CMD`:

```bash
# macOS
brew install ffmpeg cmake
git clone https://github.com/ggml-org/whisper.cpp.git
cd whisper.cpp
sh ./models/download-ggml-model.sh base
cmake -B build
cmake --build build -j --config Release
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/markitdown/whisper.cpp"
cp models/ggml-base.bin "${XDG_CACHE_HOME:-$HOME/.cache}/markitdown/whisper.cpp/ggml-base.bin"
export PATH="$PWD/build/bin:$PATH"
cd ..
chmod +x samples/helpers/audio_transcribe_wrapper.py
export MARKITDOWN_AUDIO_CMD="$PWD/samples/helpers/audio_transcribe_wrapper.py"

# Ubuntu / Debian
sudo apt update
sudo apt install -y ffmpeg cmake
git clone https://github.com/ggml-org/whisper.cpp.git
cd whisper.cpp
sh ./models/download-ggml-model.sh base
cmake -B build
cmake --build build -j --config Release
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/markitdown/whisper.cpp"
cp models/ggml-base.bin "${XDG_CACHE_HOME:-$HOME/.cache}/markitdown/whisper.cpp/ggml-base.bin"
export PATH="$PWD/build/bin:$PATH"
cd ..
chmod +x samples/helpers/audio_transcribe_wrapper.py
export MARKITDOWN_AUDIO_CMD="$PWD/samples/helpers/audio_transcribe_wrapper.py"
```

- If you need to run `samples/check.sh`, `samples/check_quality.sh`, or formal `bench`, also prepare the external corpus repo:

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

- Before `samples/check.sh` or `samples/check_quality.sh`, build the native CLI explicitly:

```bash
moon build cli --target native
```
