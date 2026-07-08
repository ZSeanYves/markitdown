#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./samples/env/share/install_audio_vosk_model.sh [--model MODEL]

Install one official Vosk model into markitdown's default local cache path.

Supported models:
  en-us-small   -> vosk-model-small-en-us-0.15
  cn-small      -> vosk-model-small-cn-0.22

Default:
  --model en-us-small
EOF
}

log_note() {
  printf '[vosk-model] %s\n' "$*"
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    exit 1
  fi
}

MODEL_KEY="en-us-small"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      [[ $# -ge 2 ]] || {
        echo "missing value for --model" >&2
        exit 2
      }
      MODEL_KEY="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unexpected argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$MODEL_KEY" in
  en-us-small)
    MODEL_ID="vosk-model-small-en-us-0.15"
    ;;
  cn-small)
    MODEL_ID="vosk-model-small-cn-0.22"
    ;;
  *)
    echo "unsupported model key: $MODEL_KEY" >&2
    usage >&2
    exit 2
    ;;
esac

require_command curl
require_command unzip

CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
VOSK_ROOT="$CACHE_HOME/markitdown/vosk"
TARGET_DIR="$VOSK_ROOT/model"
MODEL_URL="https://alphacephei.com/vosk/models/$MODEL_ID.zip"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/markitdown-vosk-model.XXXXXX")"
ARCHIVE_PATH="$TMP_DIR/$MODEL_ID.zip"
EXTRACT_DIR="$TMP_DIR/extract"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$VOSK_ROOT" "$EXTRACT_DIR"

if [[ -f "$TARGET_DIR/am/final.mdl" || -f "$TARGET_DIR/conf/model.conf" ]]; then
  log_note "Model already exists at $TARGET_DIR"
  cat <<EOF
Installed $MODEL_ID to:
  $TARGET_DIR

This is markitdown's default audio model path, so no extra environment variable is required.
If you intentionally move it elsewhere later, set:
  export MARKITDOWN_AUDIO_MODEL_PATH="/absolute/path/to/model"
EOF
  exit 0
fi

echo "Downloading $MODEL_ID ..."
curl -L "$MODEL_URL" -o "$ARCHIVE_PATH"

echo "Extracting $MODEL_ID ..."
unzip -q "$ARCHIVE_PATH" -d "$EXTRACT_DIR"

if [[ ! -d "$EXTRACT_DIR/$MODEL_ID" ]]; then
  echo "archive did not contain expected directory: $MODEL_ID" >&2
  exit 1
fi

rm -rf "$TARGET_DIR"
mv "$EXTRACT_DIR/$MODEL_ID" "$TARGET_DIR"

cat <<EOF
Installed $MODEL_ID to:
  $TARGET_DIR

This is markitdown's default audio model path, so no extra environment variable is required.
If you intentionally move it elsewhere later, set:
  export MARKITDOWN_AUDIO_MODEL_PATH="/absolute/path/to/model"
EOF
